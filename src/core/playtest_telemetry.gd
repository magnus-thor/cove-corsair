class_name PlaytestTelemetryClass
extends Node

## PlaytestTelemetry
## Captures granular gameplay, economy, and difficulty metrics during local playtests.
## Logs real-time formatted feedback to Godot output console and writes structured
## summary telemetry to user://playtest_session.json and res://playtest_session.json.

const TELEMETRY_FILE_USER: String = "user://playtest_session.json"
const TELEMETRY_FILE_PROJECT: String = "res://playtest_session.json"

var session_start_epoch: int = 0
var session_start_time_str: String = ""
var runs: Array[Dictionary] = []
var current_run: Dictionary = {}
var is_run_active: bool = false
var run_start_ticks: float = 0.0

var shipyard_events: Array[Dictionary] = []
var lifetime_damage_sources: Dictionary = {}
var lifetime_coins_by_source: Dictionary = {}
var total_doubloons_earned_session: int = 0
var total_doubloons_spent_session: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	session_start_epoch = int(Time.get_unix_time_from_system())
	session_start_time_str = Time.get_datetime_string_from_system(false, true)
	
	_connect_event_bus()
	
	print("================================================================================")
	print("🏴‍☠️ [COVE CORSAIR] PLAYTEST TELEMETRY RECORDER INITIALIZED")
	print("   Session Start : %s" % session_start_time_str)
	print("   Output Path   : %s" % TELEMETRY_FILE_USER)
	print("================================================================================")

func _notification(what: int) -> void:
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

func start_level_run(level_index: int) -> void:
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
		}
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
	
	current_run["status"] = "VICTORY"
	current_run["duration_seconds"] = snappedf(run_duration, 0.1)
	current_run["distance_reached"] = snappedf(dist, 0.1)
	current_run["coins_collected"] = run_coins
	current_run["completion_bonus"] = bonus
	current_run["total_earned"] = total_earned
	current_run["stars_awarded"] = stars
	
	runs.append(current_run)
	is_run_active = false
	
	print("\n================================================================================")
	print("[TELEMETRY:RUN_END] 🏁 VICTORY! Level %d Cleared!" % lvl_idx)
	print("   Duration    : %.1fs" % run_duration)
	print("   Distance    : %.1fm" % dist)
	print("   Star Rating : %s (%d Stars)" % ["★".repeat(stars) + "☆".repeat(3 - stars), stars])
	print("   Earnings    : %d in-run + %d clear bonus = %d 🪙 total" % [run_coins, bonus, total_earned])
	print("   Vault Total : %d 🪙" % (GameState.doubloons if GameState else 0))
	print("   Hits Taken  : %d (%d dmg total)" % [hits_count, int(current_run.get("total_damage_received", 0))])
	print("   Mobs Leaked : %d" % leaks)
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
	
	current_run["status"] = "DEFEAT"
	current_run["duration_seconds"] = snappedf(run_duration, 0.1)
	current_run["distance_reached"] = snappedf(distance_reached, 0.1)
	current_run["coins_collected"] = coins_collected
	current_run["completion_bonus"] = 0
	current_run["total_earned"] = coins_collected
	current_run["fatal_source"] = last_hit_source
	current_run["stars_awarded"] = 0
	
	runs.append(current_run)
	is_run_active = false
	
	print("\n================================================================================")
	print("[TELEMETRY:RUN_END] ☠️ SHIP SUNK! Level %d Failed" % lvl_idx)
	print("   Fatal Cause : %s" % last_hit_source)
	print("   Distance    : %.1fm / %s" % [distance_reached, str(GameState.level_distance_target if GameState else 250.0)])
	print("   Duration    : %.1fs" % run_duration)
	print("   Coins Saved : %d 🪙" % coins_collected)
	print("   Vault Total : %d 🪙" % (GameState.doubloons if GameState else 0))
	print("================================================================================\n")
	
	save_telemetry_to_disk()

func _finalize_active_run_if_any(exit_status: String) -> void:
	if is_run_active:
		var run_duration: float = (float(Time.get_ticks_msec()) / 1000.0) - run_start_ticks
		current_run["status"] = exit_status
		current_run["duration_seconds"] = snappedf(run_duration, 0.1)
		runs.append(current_run)
		is_run_active = false

func generate_session_summary() -> Dictionary:
	var total_runs_count: int = runs.size()
	var victories: int = 0
	var defeats: int = 0
	var level_outcomes: Dictionary = {}
	
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

	return {
		"session_metadata": {
			"session_start": session_start_time_str,
			"last_updated": Time.get_datetime_string_from_system(false, true),
			"total_attempts": total_runs_count,
			"victories": victories,
			"defeats": defeats,
			"win_rate_pct": snappedf((float(victories) / float(max(1, total_runs_count))) * 100.0, 0.1)
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
	var payload: Dictionary = generate_session_summary()
	var json_str: String = JSON.stringify(payload, "  ")
	
	var user_file := FileAccess.open(TELEMETRY_FILE_USER, FileAccess.WRITE)
	if user_file:
		user_file.store_string(json_str)
		user_file.close()
		
	# Mirror to workspace for convenient instant agent review
	var proj_file := FileAccess.open(TELEMETRY_FILE_PROJECT, FileAccess.WRITE)
	if proj_file:
		proj_file.store_string(json_str)
		proj_file.close()
