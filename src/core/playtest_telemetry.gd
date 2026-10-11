class_name PlaytestTelemetryClass
extends Node

## PlaytestTelemetry
## Captures granular gameplay, economy, and difficulty metrics during local playtests.
## Logs real-time formatted feedback to Godot output console and writes structured
## summary telemetry to user://playtest_session.json and res://playtest_session.json.

const TELEMETRY_FILE_USER: String = "user://playtest_session.json"
const TELEMETRY_FILE_PROJECT: String = "res://playtest_session.json"
const TELEMETRY_LATEST_USER: String = "user://playtest_session_latest.json"
const TELEMETRY_LATEST_PROJECT: String = "res://playtest_session_latest.json"

var session_index: int = 1
var session_file_user: String = TELEMETRY_FILE_USER
var session_file_project: String = TELEMETRY_FILE_PROJECT

var session_start_epoch: int = 0
var session_start_time_str: String = ""
var runs: Array[Dictionary] = []
var current_run: Dictionary = {}
var is_run_active: bool = false
var run_start_ticks: float = 0.0

# Frame rate performance metrics
var run_fps_accum: float = 0.0
var run_fps_samples: int = 0
var run_min_fps: float = 999.0
var run_max_fps: float = 0.0
var _fps_sample_timer: float = 0.0

var shipyard_events: Array[Dictionary] = []
var lifetime_damage_sources: Dictionary = {}
var lifetime_coins_by_source: Dictionary = {}
var total_doubloons_earned_session: int = 0
var total_doubloons_spent_session: int = 0

var is_telemetry_enabled: bool = true
var _session_initialized: bool = false

func _init_session_files() -> void:
	var base_exists := false
	if FileAccess.file_exists(TELEMETRY_FILE_USER):
		var f := FileAccess.open(TELEMETRY_FILE_USER, FileAccess.READ)
		if f and f.get_length() > 5:
			base_exists = true
	if not base_exists and FileAccess.file_exists(TELEMETRY_FILE_PROJECT):
		var f := FileAccess.open(TELEMETRY_FILE_PROJECT, FileAccess.READ)
		if f and f.get_length() > 5:
			base_exists = true
			
	if base_exists:
		var idx: int = 2
		while idx < 1000:
			var u_cand: String = "user://playtest_session_%d.json" % idx
			var p_cand: String = "res://playtest_session_%d.json" % idx
			var cand_exists := false
			if FileAccess.file_exists(u_cand):
				var f := FileAccess.open(u_cand, FileAccess.READ)
				if f and f.get_length() > 5:
					cand_exists = true
			if not cand_exists and FileAccess.file_exists(p_cand):
				var f := FileAccess.open(p_cand, FileAccess.READ)
				if f and f.get_length() > 5:
					cand_exists = true
			if not cand_exists:
				session_index = idx
				session_file_user = u_cand
				session_file_project = p_cand
				break
			idx += 1
	else:
		session_index = 1
		session_file_user = TELEMETRY_FILE_USER
		session_file_project = TELEMETRY_FILE_PROJECT

func _is_testing_environment() -> bool:
	var args: PackedStringArray = OS.get_cmdline_args()
	for arg: String in args:
		var a_lower: String = arg.to_lower()
		if a_lower.contains("test_scripts") or a_lower.contains("test_") or a_lower.contains("--headless") or a_lower.contains("sandbox") or a_lower.contains("harness"):
			return true
			
	var uargs: PackedStringArray = OS.get_cmdline_user_args()
	for uarg: String in uargs:
		var u_lower: String = uarg.to_lower()
		if u_lower.contains("test_scripts") or u_lower.contains("test_") or u_lower.contains("--headless") or u_lower.contains("sandbox"):
			return true

	var cur_scene: Node = get_tree().current_scene if get_tree() else null
	if is_instance_valid(cur_scene) and _is_test_scene_path(cur_scene.scene_file_path):
		return true

	return false

func _is_test_scene_path(path: String) -> bool:
	var p_lower: String = path.to_lower()
	if p_lower.is_empty():
		return false
	if p_lower.contains("/test_scripts/") or p_lower.contains("/tests/") or p_lower.contains("test_"):
		return true
	if p_lower.contains("sandbox") or p_lower.contains("level_test_harness") or p_lower.contains("build_chunks"):
		return true
	if p_lower.contains("boarding_defense_arena.tscn"):
		return true
	return false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	session_start_epoch = int(Time.get_unix_time_from_system())
	session_start_time_str = Time.get_datetime_string_from_system(false, true)
	
	if _is_testing_environment():
		is_telemetry_enabled = false
		return
		
	call_deferred("_evaluate_and_init_session")

func _evaluate_and_init_session() -> void:
	if not is_telemetry_enabled:
		return
	var cur_scene: Node = get_tree().current_scene if get_tree() else null
	if is_instance_valid(cur_scene) and _is_test_scene_path(cur_scene.scene_file_path):
		is_telemetry_enabled = false
		return
	_init_session_if_needed()

func _init_session_if_needed() -> void:
	if _session_initialized or not is_telemetry_enabled:
		return
	_session_initialized = true
	_init_session_files()
	_connect_event_bus()
	
	print("================================================================================")
	print("🏴‍☠️ [COVE CORSAIR] PLAYTEST TELEMETRY RECORDER INITIALIZED")
	print("   Session #     : %d" % session_index)
	print("   Session Start : %s" % session_start_time_str)
	print("   User Output   : %s" % session_file_user)
	print("   Project Mirror: %s" % session_file_project)
	print("================================================================================")

func _process(delta: float) -> void:
	if not is_telemetry_enabled or not is_run_active:
		return
	_fps_sample_timer += delta
	if _fps_sample_timer >= 0.1:
		_fps_sample_timer = 0.0
		var current_fps := Engine.get_frames_per_second()
		if current_fps > 0:
			run_fps_accum += float(current_fps)
			run_fps_samples += 1
			if float(current_fps) < run_min_fps:
				run_min_fps = float(current_fps)
			if float(current_fps) > run_max_fps:
				run_max_fps = float(current_fps)


func _notification(what: int) -> void:
	if not is_telemetry_enabled:
		return
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		_finalize_active_run_if_any("ABORTED_ON_EXIT")
		save_telemetry_to_disk()

func _connect_event_bus() -> void:
	if not EventBus:
		return
		
	if EventBus.has_signal("level_started") and not EventBus.level_started.is_connected(_on_level_started):
		EventBus.level_started.connect(_on_level_started)
		
	if EventBus.has_signal("level_completed") and not EventBus.level_completed.is_connected(_on_level_completed):
		EventBus.level_completed.connect(_on_level_completed)
		
	if EventBus.has_signal("run_failed") and not EventBus.run_failed.is_connected(_on_run_failed):
		EventBus.run_failed.connect(_on_run_failed)
		
	if EventBus.has_signal("player_hit_taken") and not EventBus.player_hit_taken.is_connected(_on_player_hit_taken):
		EventBus.player_hit_taken.connect(_on_player_hit_taken)
		
	if EventBus.has_signal("doubloon_awarded") and not EventBus.doubloon_awarded.is_connected(_on_doubloon_awarded):
		EventBus.doubloon_awarded.connect(_on_doubloon_awarded)
		
	if EventBus.has_signal("mob_escaped") and not EventBus.mob_escaped.is_connected(_on_mob_escaped):
		EventBus.mob_escaped.connect(_on_mob_escaped)
		
	if EventBus.has_signal("shipyard_item_action") and not EventBus.shipyard_item_action.is_connected(_on_shipyard_item_action):
		EventBus.shipyard_item_action.connect(_on_shipyard_item_action)
		
	if EventBus.has_signal("boss_spawned_event") and not EventBus.boss_spawned_event.is_connected(_on_boss_spawned):
		EventBus.boss_spawned_event.connect(_on_boss_spawned)
		
	if EventBus.has_signal("boss_health_changed") and not EventBus.boss_health_changed.is_connected(_on_boss_health_changed):
		EventBus.boss_health_changed.connect(_on_boss_health_changed)

	if EventBus.has_signal("mob_killed") and not EventBus.mob_killed.is_connected(_on_mob_killed):
		EventBus.mob_killed.connect(_on_mob_killed)

	if EventBus.has_signal("chunk_activated") and not EventBus.chunk_activated.is_connected(_on_chunk_activated):
		EventBus.chunk_activated.connect(_on_chunk_activated)

	if EventBus.has_signal("obstacle_destroyed_telemetry") and not EventBus.obstacle_destroyed_telemetry.is_connected(_on_obstacle_destroyed):
		EventBus.obstacle_destroyed_telemetry.connect(_on_obstacle_destroyed)

	if EventBus.has_signal("shot_expired_at_distance") and not EventBus.shot_expired_at_distance.is_connected(_on_shot_expired):
		EventBus.shot_expired_at_distance.connect(_on_shot_expired)

	if EventBus.has_signal("boarding_encounter_started") and not EventBus.boarding_encounter_started.is_connected(_on_boarding_encounter_started):
		EventBus.boarding_encounter_started.connect(_on_boarding_encounter_started)

	if EventBus.has_signal("boarding_encounter_ended") and not EventBus.boarding_encounter_ended.is_connected(_on_boarding_encounter_ended):
		EventBus.boarding_encounter_ended.connect(_on_boarding_encounter_ended)

func start_level_run(level_index: int) -> void:
	if not is_telemetry_enabled:
		return
	_init_session_if_needed()
	_finalize_active_run_if_any("SUPERSEDED")
	
	is_run_active = true
	run_start_ticks = float(Time.get_ticks_msec()) / 1000.0
	
	var active_ship: String = GameState.active_vessel if GameState else "dinghy"
	var ship_tier: int = GameState.get_vessel_tier(active_ship) if GameState else 1
	var active_ammo: String = GameState.get_active_ammo() if GameState else "standard_iron"
	var active_plating: String = GameState.get_active_plating() if GameState else "none"
	var vault: int = GameState.doubloons if GameState else 0
	
	current_run = {
		"run_number": runs.size() + 1,
		"level_index": level_index,
		"status": "IN_PROGRESS",
		"start_time_iso": Time.get_datetime_string_from_system(false, true),
		"ship_id": active_ship,
		"ship_tier": ship_tier,
		"ammo": active_ammo,
		"plating": active_plating,
		"vault_at_start": vault,
		"coins_collected": 0,
		"completion_bonus": 0,
		"total_earned": 0,
		"coins_by_source": {},
		"hits_taken": [],
		"total_damage_received": 0,
		"mobs_leaked": 0,
		"distance_reached": 0.0,
		"duration_seconds": 0.0,
		"stars_awarded": 0,
		"boss_encounter": {
			"boss_name": "",
			"max_health": 0,
			"final_health": 0,
			"defeated": false,
			"fight_duration": 0.0
		},
		"chunks_entered": [],
		"mob_kills": [],
		"obstacles_destroyed": [],
		"shot_expirations": 0,
		"shots_hit_water": 0
	}
	
	print("\n--------------------------------------------------------------------------------")
	print("[TELEMETRY:RUN_START] ▶️ Level %d (%s) | Vessel: %s [T%d] | Ammo: %s | Plating: %s | Vault: %d 🪙" % [
		level_index,
		GameState.get_level_display_name(level_index) if GameState else "",
		active_ship,
		ship_tier,
		active_ammo,
		active_plating,
		vault
	])
	print("--------------------------------------------------------------------------------")

func _on_level_started(level_index: int) -> void:
	start_level_run(level_index)

func _on_player_hit_taken(amount: int, current_hp: int, max_hp: int, source_info: String, distance: float) -> void:
	if not is_run_active:
		return
		
	var run_time: float = (float(Time.get_ticks_msec()) / 1000.0) - run_start_ticks
	var hit_record: Dictionary = {
		"time": snappedf(run_time, 0.1),
		"damage": amount,
		"current_hp": current_hp,
		"max_hp": max_hp,
		"source": source_info,
		"distance": snappedf(distance, 0.1)
	}
	
	var hits_arr: Array = current_run.get("hits_taken", []) as Array
	hits_arr.append(hit_record)
	current_run["total_damage_received"] = int(current_run.get("total_damage_received", 0)) + amount
	
	var count: int = int(lifetime_damage_sources.get(source_info, 0)) + 1
	lifetime_damage_sources[source_info] = count
	
	print("[TELEMETRY:COMBAT] 💥 Took %d DMG from '%s' | HP: %d/%d | Dist: %.1fm | Elapsed: %.1fs" % [
		amount,
		source_info,
		current_hp,
		max_hp,
		distance,
		run_time
	])

func _on_doubloon_awarded(amount: int, source: String, total_run: int) -> void:
	total_doubloons_earned_session += amount
	
	var source_tot: int = int(lifetime_coins_by_source.get(source, 0)) + amount
	lifetime_coins_by_source[source] = source_tot
	
	if is_run_active:
		current_run["coins_collected"] = total_run
		var run_sources: Dictionary = current_run.get("coins_by_source", {}) as Dictionary
		var cur_src: int = int(run_sources.get(source, 0)) + amount
		run_sources[source] = cur_src
		current_run["coins_by_source"] = run_sources
	
	var mult: float = GameState.active_multiplier if GameState else 1.0
	print("[TELEMETRY:ECONOMY] 🪙 +%d [%s] (Mult: %.1fx) | Run Total: %d 🪙" % [
		amount,
		source,
		mult,
		total_run
	])

func _on_mob_escaped(mob_name: String, total_leaked: int) -> void:
	if is_run_active:
		current_run["mobs_leaked"] = total_leaked
	print("[TELEMETRY:LEAK] ⚠️ Mob Breached River: '%s' | Total Leaks This Run: %d" % [mob_name, total_leaked])

func _on_mob_killed(mob_type: String, mob_max_hp: int, dist_to_player: float, river_distance: float) -> void:
	if not is_run_active:
		return
	var record: Dictionary = {
		"mob": mob_type,
		"max_hp": mob_max_hp,
		"kill_dist_m": snappedf(dist_to_player, 0.1),
		"river_dist_m": snappedf(river_distance, 0.1)
	}
	var kills_arr: Array = current_run.get("mob_kills", []) as Array
	kills_arr.append(record)
	current_run["mob_kills"] = kills_arr
	# Highlight suspiciously easy kills (distance > 30m = killed far away before they get close)
	var range_flag: String = " 🎯 FAR" if dist_to_player > 30.0 else (" ⚡ CLOSE" if dist_to_player < 10.0 else "")
	print("[TELEMETRY:KILL] 💀 %s (HP:%d) | Kill dist: %.1fm | River: %.1fm%s" % [
		mob_type, mob_max_hp, dist_to_player, river_distance, range_flag
	])

func _on_chunk_activated(chunk_id: String, river_distance: float) -> void:
	if not is_run_active:
		return
	var record: Dictionary = {
		"chunk": chunk_id,
		"river_dist_m": snappedf(river_distance, 0.1)
	}
	var chunks_arr: Array = current_run.get("chunks_entered", []) as Array
	chunks_arr.append(record)
	current_run["chunks_entered"] = chunks_arr
	print("[TELEMETRY:CHUNK] 🗺️ Chunk '%s' activated at %.1fm" % [chunk_id, river_distance])

func _on_obstacle_destroyed(obstacle_type: String, shots_taken: int, river_distance: float) -> void:
	if not is_run_active:
		return
	var record: Dictionary = {
		"type": obstacle_type,
		"shots": shots_taken,
		"river_dist_m": snappedf(river_distance, 0.1)
	}
	var obs_arr: Array = current_run.get("obstacles_destroyed", []) as Array
	obs_arr.append(record)
	current_run["obstacles_destroyed"] = obs_arr
	# Flag thin obstacles (1 shot) vs sustained fights (barricades 20+)
	var effort_tag: String = "INSTANT" if shots_taken <= 2 else ("SIEGE" if shots_taken >= 15 else "NORMAL")
	print("[TELEMETRY:OBSTACLE] 💥 %s destroyed | %d shots | %.1fm [%s]" % [
		obstacle_type, shots_taken, river_distance, effort_tag
	])

func _on_shot_expired(_weapon_id: String, max_range_m: float, river_distance: float) -> void:
	if not is_run_active:
		return
	current_run["shot_expirations"] = int(current_run.get("shot_expirations", 0)) + 1
	current_run["shots_hit_water"] = int(current_run.get("shots_hit_water", 0)) + 1
	# Only print every 10th miss to avoid console spam — ratio still captured in JSON
	var miss_count: int = int(current_run.get("shot_expirations", 0))
	if miss_count % 10 == 0:
		print("[TELEMETRY:AMMO] 🌊 %d shots hit water so far (max_range %.1fm) at %.1fm" % [
			miss_count, max_range_m, river_distance
		])

func _on_shipyard_item_action(item_id: String, item_type: String, cost: int, player_vault: int, success: bool, reason: String) -> void:
	var event: Dictionary = {
		"timestamp": Time.get_datetime_string_from_system(false, true),
		"item_id": item_id,
		"item_type": item_type,
		"cost": cost,
		"vault_balance": player_vault,
		"success": success,
		"reason": reason
	}
	shipyard_events.append(event)
	
	if success:
		total_doubloons_spent_session += cost
		print("[TELEMETRY:SHIPYARD] ✅ ACQUIRED %s '%s' for %d 🪙 | Vault Remaining: %d 🪙" % [
			item_type.to_upper(),
			item_id,
			cost,
			player_vault - cost
		])
	else:
		var deficit: int = max(0, cost - player_vault)
		print("[TELEMETRY:SHIPYARD] ❌ SHORT ON FUNDS for %s '%s' | Cost: %d 🪙 | Vault: %d 🪙 | Deficit: %d 🪙 (%s)" % [
			item_type.to_upper(),
			item_id,
			cost,
			player_vault,
			deficit,
			reason
		])
	save_telemetry_to_disk()

func _on_boss_spawned(boss_name: String, max_val: int) -> void:
	if not is_run_active:
		return
	var boss_dict: Dictionary = current_run.get("boss_encounter", {}) as Dictionary
	boss_dict["boss_name"] = boss_name
	boss_dict["max_health"] = max_val
	boss_dict["final_health"] = max_val
	boss_dict["spawn_time"] = float(Time.get_ticks_msec()) / 1000.0
	current_run["boss_encounter"] = boss_dict
	print("[TELEMETRY:BOSS] ⚔️ Boss Engaged: '%s' | HP: %d" % [boss_name, max_val])

func _on_boss_health_changed(current: int, _max_val: int) -> void:
	if not is_run_active:
		return
	var boss_dict: Dictionary = current_run.get("boss_encounter", {}) as Dictionary
	boss_dict["final_health"] = current
	if current <= 0 and not bool(boss_dict.get("defeated", false)):
		boss_dict["defeated"] = true
		var spawn_t: float = float(boss_dict.get("spawn_time", 0.0))
		if spawn_t > 0.0:
			boss_dict["fight_duration"] = snappedf((float(Time.get_ticks_msec()) / 1000.0) - spawn_t, 0.1)
		print("[TELEMETRY:BOSS] 🏆 Boss '%s' SLAIN in %.1fs!" % [
			str(boss_dict.get("boss_name", "Boss")),
			float(boss_dict.get("fight_duration", 0.0))
		])
	current_run["boss_encounter"] = boss_dict

func _on_boarding_encounter_started(boss_name: String, tier: int, total_waves: int, player_vessel: String, crew_role: String) -> void:
	if not is_run_active:
		return
	var b_dict: Dictionary = {
		"boss_name": boss_name,
		"tier": tier,
		"total_waves": total_waves,
		"player_vessel": player_vessel,
		"crew_role": crew_role,
		"start_time": float(Time.get_ticks_msec()) / 1000.0,
		"outcome": "IN_PROGRESS"
	}
	current_run["boarding_encounter"] = b_dict
	print("[TELEMETRY:BOARDING] ⚓ Boarding Engaged vs '%s' (Tier %d) | Waves: %d | Vessel: %s | Crew: %s" % [
		boss_name, tier, total_waves, player_vessel, ("none" if crew_role.is_empty() else crew_role)
	])

func _on_boarding_encounter_ended(boss_name: String, outcome: String, duration_sec: float, waves_cleared: int, total_waves: int, mobs_killed: int, mobs_spawned: int, hull_damage_taken: float, end_reason: String) -> void:
	if not is_run_active:
		return
	var b_dict: Dictionary = current_run.get("boarding_encounter", {}) as Dictionary
	b_dict["boss_name"] = boss_name
	b_dict["outcome"] = outcome
	b_dict["duration_sec"] = snappedf(duration_sec, 0.1)
	b_dict["waves_cleared"] = waves_cleared
	b_dict["total_waves"] = total_waves
	b_dict["mobs_killed"] = mobs_killed
	b_dict["mobs_spawned"] = mobs_spawned
	b_dict["hull_damage_taken"] = snappedf(hull_damage_taken, 0.1)
	b_dict["end_reason"] = end_reason
	current_run["boarding_encounter"] = b_dict

	var status_icon: String = "🏆" if outcome == "VICTORY" else "💀"
	print("[TELEMETRY:BOARDING] %s %s vs '%s' in %.1fs | Waves: %d/%d | Kills: %d/%d | Hull DMG: %.1f [%s]" % [
		status_icon, outcome, boss_name, duration_sec, waves_cleared, total_waves, mobs_killed, mobs_spawned, hull_damage_taken, end_reason
	])

func _calc_run_fps_metrics() -> Dictionary:
	var avg_fps: float = snappedf(run_fps_accum / float(maxi(1, run_fps_samples)), 0.1) if run_fps_samples > 0 else float(Engine.get_frames_per_second())
	var min_fps: int = int(run_min_fps) if (run_fps_samples > 0 and run_min_fps < 900.0) else int(avg_fps)
	var max_fps: int = int(run_max_fps) if run_fps_samples > 0 else int(avg_fps)
	return {
		"avg_fps": avg_fps,
		"min_fps": min_fps,
		"max_fps": max_fps,
		"samples": run_fps_samples
	}

func _on_level_completed(_doubloons: int, _targets: int) -> void:
	if not is_run_active:
		return
		
	var run_duration: float = (float(Time.get_ticks_msec()) / 1000.0) - run_start_ticks
	var lvl_res := GameState.get_current_level_resource() if GameState else null
	var bonus: int = lvl_res.completion_doubloon_reward if lvl_res else 150
	var run_coins: int = GameState.run_doubloons if GameState else 0
	var stars: int = GameState.calculate_stars() if GameState else 1
	var total_earned: int = run_coins + bonus
	var hits_count: int = (current_run.get("hits_taken", []) as Array).size()
	var leaks: int = int(current_run.get("mobs_leaked", 0))
	var lvl_idx: int = int(current_run.get("level_index", 1))
	var dist: float = GameState.distance_traveled if GameState else 250.0
	var fps_info := _calc_run_fps_metrics()
	
	current_run["status"] = "VICTORY"
	current_run["duration_seconds"] = snappedf(run_duration, 0.1)
	current_run["distance_reached"] = snappedf(dist, 0.1)
	current_run["coins_collected"] = run_coins
	current_run["completion_bonus"] = bonus
	current_run["total_earned"] = total_earned
	current_run["stars_awarded"] = stars
	current_run["fps_metrics"] = fps_info
	current_run["avg_fps"] = fps_info["avg_fps"]
	current_run["min_fps"] = fps_info["min_fps"]
	
	runs.append(current_run)
	is_run_active = false
	
	print("\n================================================================================")
	print("[TELEMETRY:RUN_END] 🏁 VICTORY! Level %d Cleared!" % lvl_idx)
	print("   Duration    : %.1fs" % run_duration)
	print("   Distance    : %.1fm" % dist)
	print("   Star Rating : %s (%d Stars)" % ["★".repeat(stars) + "☆".repeat(3 - stars), stars])
	print("   Earnings    : %d in-run + %d clear bonus = %d 🪙 total" % [run_coins, bonus, total_earned])
	print("   Vault Total : %d 🪙" % (GameState.doubloons if GameState else 0))
	print("   Performance : Avg %.1f FPS (Min %d, Max %d)" % [float(fps_info["avg_fps"]), int(fps_info["min_fps"]), int(fps_info["max_fps"])])
	print("   Hits Taken  : %d (%d dmg total)" % [hits_count, int(current_run.get("total_damage_received", 0))])
	print("   Mobs Leaked : %d" % leaks)
	var mob_kills_arr: Array = current_run.get("mob_kills", []) as Array
	var chunks_arr: Array = current_run.get("chunks_entered", []) as Array
	var obs_arr: Array = current_run.get("obstacles_destroyed", []) as Array
	var water_shots: int = int(current_run.get("shots_hit_water", 0))
	print("   Mob Kills   : %d | Chunks: %d | Obstacles: %d | Wasted Shots: %d" % [
		mob_kills_arr.size(), chunks_arr.size(), obs_arr.size(), water_shots
	])
	if not mob_kills_arr.is_empty():
		var far_kills: int = 0
		var close_kills: int = 0
		var total_kill_dist: float = 0.0
		for mk: Variant in mob_kills_arr:
			var d: float = float((mk as Dictionary).get("kill_dist_m", 0.0))
			total_kill_dist += d
			if d > 30.0:
				far_kills += 1
			elif d < 10.0:
				close_kills += 1
		var avg_kill_dist: float = total_kill_dist / float(mob_kills_arr.size())
		print("   Avg Kill Dist: %.1fm | Far (>30m): %d | Close (<10m): %d" % [avg_kill_dist, far_kills, close_kills])
	if current_run.has("boarding_encounter"):
		var b_info: Dictionary = current_run["boarding_encounter"] as Dictionary
		print("   Boarding    : %s in %.1fs | Waves: %d/%d | Kills: %d/%d | Hull DMG: %.1f [%s]" % [
			str(b_info.get("outcome", "N/A")),
			float(b_info.get("duration_sec", 0.0)),
			int(b_info.get("waves_cleared", 0)),
			int(b_info.get("total_waves", 0)),
			int(b_info.get("mobs_killed", 0)),
			int(b_info.get("mobs_spawned", 0)),
			float(b_info.get("hull_damage_taken", 0.0)),
			str(b_info.get("end_reason", "N/A"))
		])
	print("================================================================================\n")
	
	save_telemetry_to_disk()

func _on_run_failed(coins_collected: int, distance_reached: float) -> void:
	if not is_run_active:
		return
		
	var run_duration: float = (float(Time.get_ticks_msec()) / 1000.0) - run_start_ticks
	var lvl_idx: int = int(current_run.get("level_index", 1))
	var hits_arr: Array = current_run.get("hits_taken", []) as Array
	var last_hit_source: String = "Unknown Hazard"
	if not hits_arr.is_empty():
		var last_hit: Dictionary = hits_arr[hits_arr.size() - 1] as Dictionary
		last_hit_source = str(last_hit.get("source", "Unknown"))
	var fps_info := _calc_run_fps_metrics()
	
	current_run["status"] = "DEFEAT"
	current_run["duration_seconds"] = snappedf(run_duration, 0.1)
	current_run["distance_reached"] = snappedf(distance_reached, 0.1)
	current_run["coins_collected"] = coins_collected
	current_run["completion_bonus"] = 0
	current_run["total_earned"] = coins_collected
	current_run["fatal_source"] = last_hit_source
	current_run["stars_awarded"] = 0
	current_run["fps_metrics"] = fps_info
	current_run["avg_fps"] = fps_info["avg_fps"]
	current_run["min_fps"] = fps_info["min_fps"]
	
	runs.append(current_run)
	is_run_active = false
	
	print("\n================================================================================")
	print("[TELEMETRY:RUN_END] ☠️ SHIP SUNK! Level %d Failed" % lvl_idx)
	print("   Fatal Cause : %s" % last_hit_source)
	print("   Distance    : %.1fm / %s" % [distance_reached, str(GameState.level_distance_target if GameState else 250.0)])
	print("   Duration    : %.1fs" % run_duration)
	print("   Coins Saved : %d 🪙" % coins_collected)
	print("   Vault Total : %d 🪙" % (GameState.doubloons if GameState else 0))
	print("   Performance : Avg %.1f FPS (Min %d, Max %d)" % [float(fps_info["avg_fps"]), int(fps_info["min_fps"]), int(fps_info["max_fps"])])
	var mob_kills_arr: Array = current_run.get("mob_kills", []) as Array
	var chunks_arr: Array = current_run.get("chunks_entered", []) as Array
	var obs_arr: Array = current_run.get("obstacles_destroyed", []) as Array
	var water_shots: int = int(current_run.get("shots_hit_water", 0))
	print("   Mob Kills   : %d | Chunks: %d | Obstacles: %d | Wasted Shots: %d" % [
		mob_kills_arr.size(), chunks_arr.size(), obs_arr.size(), water_shots
	])
	if not mob_kills_arr.is_empty():
		var far_kills: int = 0
		var close_kills: int = 0
		var total_kill_dist: float = 0.0
		for mk: Variant in mob_kills_arr:
			var d: float = float((mk as Dictionary).get("kill_dist_m", 0.0))
			total_kill_dist += d
			if d > 30.0:
				far_kills += 1
			elif d < 10.0:
				close_kills += 1
		var avg_kill_dist: float = total_kill_dist / float(mob_kills_arr.size())
		print("   Avg Kill Dist: %.1fm | Far (>30m): %d | Close (<10m): %d" % [avg_kill_dist, far_kills, close_kills])
	if current_run.has("boarding_encounter"):
		var b_info: Dictionary = current_run["boarding_encounter"] as Dictionary
		print("   Boarding    : %s in %.1fs | Waves: %d/%d | Kills: %d/%d | Hull DMG: %.1f [%s]" % [
			str(b_info.get("outcome", "N/A")),
			float(b_info.get("duration_sec", 0.0)),
			int(b_info.get("waves_cleared", 0)),
			int(b_info.get("total_waves", 0)),
			int(b_info.get("mobs_killed", 0)),
			int(b_info.get("mobs_spawned", 0)),
			float(b_info.get("hull_damage_taken", 0.0)),
			str(b_info.get("end_reason", "N/A"))
		])
	print("================================================================================\n")
	
	save_telemetry_to_disk()

func _finalize_active_run_if_any(exit_status: String) -> void:
	if is_run_active:
		var run_duration: float = (float(Time.get_ticks_msec()) / 1000.0) - run_start_ticks
		var fps_info := _calc_run_fps_metrics()
		current_run["status"] = exit_status
		current_run["duration_seconds"] = snappedf(run_duration, 0.1)
		current_run["fps_metrics"] = fps_info
		current_run["avg_fps"] = fps_info["avg_fps"]
		current_run["min_fps"] = fps_info["min_fps"]
		runs.append(current_run)
		is_run_active = false

func generate_session_summary() -> Dictionary:
	var total_runs_count: int = runs.size()
	var victories: int = 0
	var defeats: int = 0
	var level_outcomes: Dictionary = {}
	
	var total_fps_sum: float = 0.0
	var total_fps_runs: int = 0
	var session_min_fps: int = 999
	var session_max_fps: int = 0
	
	for r: Dictionary in runs:
		var st: String = str(r.get("status", ""))
		var lvl: int = int(r.get("level_index", 1))
		if not level_outcomes.has(lvl):
			level_outcomes[lvl] = { "attempts": 0, "clears": 0, "defeats": 0, "total_coins": 0 }
		var outcome: Dictionary = level_outcomes[lvl] as Dictionary
		outcome["attempts"] = int(outcome.get("attempts", 0)) + 1
		if st == "VICTORY":
			victories += 1
			outcome["clears"] = int(outcome.get("clears", 0)) + 1
		elif st == "DEFEAT":
			defeats += 1
			outcome["defeats"] = int(outcome.get("defeats", 0)) + 1
		outcome["total_coins"] = int(outcome.get("total_coins", 0)) + int(r.get("total_earned", 0))
		level_outcomes[lvl] = outcome
		
		# Performance roll-up
		if r.has("avg_fps"):
			var r_fps: float = float(r["avg_fps"])
			if r_fps > 0.0:
				total_fps_sum += r_fps
				total_fps_runs += 1
				var r_min: int = int(r.get("min_fps", 0))
				var r_max: int = int(r.get("max_fps", 0))
				if r_min > 0 and r_min < session_min_fps:
					session_min_fps = r_min
				if r_max > session_max_fps:
					session_max_fps = r_max

	var session_avg_fps: float = snappedf(total_fps_sum / float(maxi(1, total_fps_runs)), 0.1) if total_fps_runs > 0 else 0.0

	return {
		"session_metadata": {
			"session_index": session_index,
			"session_file": session_file_user,
			"session_start": session_start_time_str,
			"last_updated": Time.get_datetime_string_from_system(false, true),
			"total_attempts": total_runs_count,
			"victories": victories,
			"defeats": defeats,
			"win_rate_pct": snappedf((float(victories) / float(max(1, total_runs_count))) * 100.0, 0.1),
			"session_avg_fps": session_avg_fps,
			"session_min_fps": (session_min_fps if session_min_fps < 900 else 0),
			"session_max_fps": session_max_fps
		},
		"performance_overview": {
			"session_avg_fps": session_avg_fps,
			"session_min_fps": (session_min_fps if session_min_fps < 900 else 0),
			"session_max_fps": session_max_fps,
			"target_framerate": Engine.max_fps
		},
		"economy_overview": {
			"total_doubloons_earned": total_doubloons_earned_session,
			"total_doubloons_spent": total_doubloons_spent_session,
			"current_vault": GameState.doubloons if GameState else 0,
			"earnings_by_source": lifetime_coins_by_source
		},
		"combat_overview": {
			"hazard_damage_frequency": lifetime_damage_sources
		},
		"level_progression_summary": level_outcomes,
		"shipyard_activity": shipyard_events,
		"all_runs": runs
	}

func save_telemetry_to_disk() -> void:
	if not is_telemetry_enabled:
		return
	if runs.is_empty() and shipyard_events.is_empty():
		return
	var payload: Dictionary = generate_session_summary()
	var json_str: String = JSON.stringify(payload, "  ")
	
	# 1. Primary indexed session file (preserves all previous session logs)
	var user_file := FileAccess.open(session_file_user, FileAccess.WRITE)
	if user_file:
		user_file.store_string(json_str)
		user_file.close()
		
	var proj_file := FileAccess.open(session_file_project, FileAccess.WRITE)
	if proj_file:
		proj_file.store_string(json_str)
		proj_file.close()
		
	# 2. Latest convenience mirror (always points to most recent play session)
	var latest_user := FileAccess.open(TELEMETRY_LATEST_USER, FileAccess.WRITE)
	if latest_user:
		latest_user.store_string(json_str)
		latest_user.close()
		
	var latest_proj := FileAccess.open(TELEMETRY_LATEST_PROJECT, FileAccess.WRITE)
	if latest_proj:
		latest_proj.store_string(json_str)
		latest_proj.close()

func copy_session_json_to_clipboard() -> void:
	var payload: Dictionary = generate_session_summary()
	var json_str: String = JSON.stringify(payload, "  ")
	DisplayServer.clipboard_set(json_str)
	print("[TELEMETRY] 📋 Copied session telemetry to device clipboard (%d bytes)." % json_str.length())
