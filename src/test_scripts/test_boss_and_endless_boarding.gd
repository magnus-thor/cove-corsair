extends Node3D

## Headless test suite for Route A Desperation Boarding & Endless Mode Boss Encounter.
## Verifies:
## 1. Boss HP <= 25% triggers desperation boarding and locks HP at 1.
## 2. InRunBoardingAdapter arena victory cascades to boss defeat.
## 3. Endless mode initializes 4-boss pool with target distance 450m-750m.
## 4. Endless mode triggers random boss spawn at target distance.
## 5. Defeating gauntlet boss awards +250 doubloons and +1.5x multiplier without ending the run.

const WAR_BARGE_SCENE: PackedScene = preload("res://src/gameplay/enemies/boss_war_barge.tscn")
const BONE_BEARD_SCENE: PackedScene = preload("res://src/gameplay/enemies/boss_bone_beard.tscn")
const PHANTOM_DREDGE_SCENE: PackedScene = preload("res://src/gameplay/enemies/boss_phantom_dredge.tscn")
const SIEGE_FORTRESS_SCENE: PackedScene = preload("res://src/gameplay/enemies/boss_siege_fortress.tscn")
const ENDLESS_MODE_SCRIPT: GDScript = preload("res://src/features/modes/endless_mode.gd")
const ARENA_SCENE: PackedScene = preload("res://src/features/boarding/boarding_defense_arena.tscn")

func _ready() -> void:
	print("\n========================================================")
	print("  TESTING ROUTE A BOARDING & ENDLESS BOSS ENCOUNTER")
	print("========================================================\n")
	
	_test_route_a_desperation_threshold_and_clamp()
	_test_boarding_adapter_defeat_flow()
	_test_endless_mode_boss_pool_and_target_distance()
	_test_endless_mode_boss_spawn_at_distance()
	_test_endless_mode_boss_slain_rewards()
	_test_dynamic_vessel_and_gangplank_anchors()
	_test_boarding_wave_scaling_and_telemetry()
	
	print("\n========================================================")
	print("  ALL ROUTE A & ENDLESS BOSS TESTS PASSED SUCCESSFULLY! ")
	print("========================================================\n")
	get_tree().quit(0)

func _test_route_a_desperation_threshold_and_clamp() -> void:
	print("--- 1. Testing Route A Desperation Boarding Threshold & HP Clamping ---")
	var boss: Node3D = WAR_BARGE_SCENE.instantiate() as Node3D
	add_child(boss)
	if boss.has_method("activate_arena"):
		boss.call("activate_arena")
	else:
		boss.set("is_arena_active", true)
	
	# Dynamic max_hp scaled by GameState.current_level in _ready()
	var max_hp: int = int(boss.get("max_hp"))
	assert(max_hp > 0, "War-Barge max_hp must be positive (got %d)" % max_hp)
	
	# Deal damage above 2% threshold (HP drops to 50% > 2%)
	var dmg_half: int = int(max_hp * 0.5)
	boss.call("take_damage", dmg_half)
	var hp_after_first: int = int(boss.get("current_hp"))
	var threshold_2pct: int = max(1, int(round(float(max_hp) * 0.02)))
	assert(hp_after_first > threshold_2pct, "HP must remain above 2 percent (got %d / %d)" % [hp_after_first, max_hp])
	var has_triggered_1: bool = bool(boss.get("has_triggered_boarding"))
	assert(not has_triggered_1, "Boarding must NOT trigger above 2% HP threshold")
	
	# Deal damage to drop below 2% threshold (HP drops to <= 2%)
	var dmg_desperation: int = max(1, hp_after_first - max(1, int(threshold_2pct * 0.5)))
	boss.call("take_damage", dmg_desperation)
	var hp_after_second: int = int(boss.get("current_hp"))
	assert(hp_after_second <= threshold_2pct, "HP must be <= 2 percent (got %d / %d, threshold %d)" % [hp_after_second, max_hp, threshold_2pct])
	var has_triggered_2: bool = bool(boss.get("has_triggered_boarding"))
	assert(has_triggered_2, "Boarding MUST trigger when HP <= 2%% (got %d / %d)" % [hp_after_second, max_hp])
	
	# Deal massive fatal damage (1000) while boarding is active
	boss.call("take_damage", 1000)
	var clamped_hp: int = int(boss.get("current_hp"))
	assert(clamped_hp == 1, "HP must be clamped at 1 during boarding to prevent premature death (got %d)" % clamped_hp)
	var is_defeated: bool = bool(boss.get("_is_defeated"))
	assert(not is_defeated, "Boss must not be defeated prematurely while boarding party is active")
	
	boss.queue_free()
	print("  [PASS] Route A Desperation threshold (<= 2%) and HP clamp at 1 verified.")

func _test_boarding_adapter_defeat_flow() -> void:
	print("--- 2. Testing InRunBoardingAdapter Arena Victory Cascade ---")
	var boss: Node3D = WAR_BARGE_SCENE.instantiate() as Node3D
	add_child(boss)
	
	var adapter: InRunBoardingAdapter = InRunBoardingAdapter.new()
	add_child(adapter)
	adapter.active_boss = boss
	
	# Simulate victory in boarding arena
	adapter._on_arena_won()
	
	var is_defeated: bool = bool(boss.get("_is_defeated"))
	assert(is_defeated, "Boss must be marked as defeated after boarding party cleared")
	var state: int = int(boss.get("current_state"))
	assert(state == 2, "Boss state must be DYING (2) after deck clearance (got %d)" % state)
	
	boss.queue_free()
	print("  [PASS] Arena victory properly cascades to boss defeat.")

func _test_endless_mode_boss_pool_and_target_distance() -> void:
	print("--- 3. Testing Endless Mode 4-Boss Pool & Distance Roll ---")
	var mode: Node = ENDLESS_MODE_SCRIPT.new()
	add_child(mode)
	mode.call("start_run")
	
	var scenes: Array = mode.get("boss_scenes") as Array
	assert(scenes.size() == 4, "Endless mode must have 4 bosses in boss_scenes pool (got %d)" % scenes.size())
	
	var target_dist: float = float(mode.get("random_boss_target_distance"))
	assert(target_dist >= 450.0 and target_dist <= 750.0, "Random boss target distance must be between 450m and 750m (got %.1fm)" % target_dist)
	
	var has_spawned: bool = bool(mode.get("has_spawned_endless_boss"))
	assert(not has_spawned, "Boss must not have spawned at run start")
	
	mode.queue_free()
	print("  [PASS] Endless mode initialized with 4-boss pool and target distance: %.1fm." % target_dist)

func _test_endless_mode_boss_spawn_at_distance() -> void:
	print("--- 4. Testing Endless Mode Boss Spawn at Target Distance ---")
	var mode: Node = ENDLESS_MODE_SCRIPT.new()
	add_child(mode)
	mode.call("start_run")
	
	var target_dist: float = float(mode.get("random_boss_target_distance"))
	
	# Set distance just past the trigger distance
	mode.set("distance_traveled", target_dist + 5.0)
	mode._physics_process(0.016)
	
	var has_spawned: bool = bool(mode.get("has_spawned_endless_boss"))
	assert(has_spawned, "Boss must spawn when distance_traveled >= random_boss_target_distance")
	
	var active_boss: Node3D = mode.get("active_endless_boss") as Node3D
	assert(active_boss != null and is_instance_valid(active_boss), "Active endless boss must be instantiated")
	assert(active_boss.global_position.z == -18.0, "Boss must be positioned at track front Z=-18.0 (got %.1f)" % active_boss.global_position.z)
	
	if is_instance_valid(active_boss):
		active_boss.queue_free()
	mode.queue_free()
	print("  [PASS] Random boss encounter successfully spawned at target distance.")

func _test_endless_mode_boss_slain_rewards() -> void:
	print("--- 5. Testing Endless Mode Boss Slain Bounties & Run Continuity ---")
	var mode: Node = ENDLESS_MODE_SCRIPT.new()
	add_child(mode)
	mode.call("start_run")
	
	mode.set("has_spawned_endless_boss", true)
	var initial_mult: float = float(mode.get("multiplier"))
	var initial_doubloons: int = int(mode.get("unbanked_doubloons"))
	
	# Simulate boss defeat signal
	mode.call("_on_endless_boss_defeated", 0, 1)
	
	var final_mult: float = float(mode.get("multiplier"))
	var final_doubloons: int = int(mode.get("unbanked_doubloons"))
	
	assert(is_equal_approx(final_mult, initial_mult + 1.5), "Multiplier must increase by +1.5x on boss defeat (got %.2f)" % final_mult)
	assert(final_doubloons == initial_doubloons + 250, "Unbanked doubloons must increase by +250 on boss defeat (got %d)" % final_doubloons)
	assert(GameState.is_game_active, "Game must remain active in Endless Mode after defeating a boss")
	
	var active_boss_ref: Node3D = mode.get("active_endless_boss") as Node3D
	assert(active_boss_ref == null, "active_endless_boss must be cleared on boss defeat")
	
	mode.queue_free()
	print("  [PASS] Gauntlet boss bounty verified: +250 doubloons, +1.5x multiplier, run continues seamlessly.")

func _test_dynamic_vessel_and_gangplank_anchors() -> void:
	print("--- 6. Testing Dynamic Vessel Model Swapping & Gangplank Anchors ---")
	var arena: BoardingDefenseArena = ARENA_SCENE.instantiate() as BoardingDefenseArena
	add_child(arena)
	
	# Test Player Vessel Swapping
	arena.setup_player_vessel("dinghy")
	var dinghy_visual: Node = arena.player_ship_container.find_child("PlayerShipVisual", true, false)
	assert(dinghy_visual != null, "PlayerShipVisual must exist after setup_player_vessel('dinghy')")
	assert(is_equal_approx(arena.zone_bow.plank_anchor.position.x, 2.0 - 0.25), "Dinghy anchor X must be adjusted for narrow beam")
	
	arena.setup_player_vessel("ironclad")
	var ironclad_visual: Node = arena.player_ship_container.find_child("PlayerShipVisual", true, false)
	assert(ironclad_visual != null, "PlayerShipVisual must exist after setup_player_vessel('ironclad')")
	assert(is_equal_approx(arena.zone_bow.plank_anchor.position.x, 2.0 + 0.35), "Ironclad anchor X must be adjusted for wide beam")
	
	# Test Boss 2 (Bone-Beard) Gangplank Anchors & Visual
	arena.setup_enemy_vessel("BossBoneBeard")
	var bone_beard_visual: Node = arena.enemy_ship_container.find_child("EnemyShipVisual", true, false)
	assert(bone_beard_visual != null, "EnemyShipVisual must exist for Bone-Beard")
	assert(arena.enemy_ship_marker_bow.position.is_equal_approx(Vector3(-13.1, 0.55, -1.85)), "Bone-Beard MarkerBow must match calibrated anchor")
	assert(arena.enemy_ship_marker_mid.position.is_equal_approx(Vector3(-13.1, 0.50, -0.05)), "Bone-Beard MarkerMid must match calibrated anchor")
	assert(arena.enemy_ship_marker_stern.position.is_equal_approx(Vector3(-13.1, 0.55, 0.65)), "Bone-Beard MarkerStern must match calibrated anchor")
	
	# Test Siege Fortress
	arena.setup_enemy_vessel("BossSiegeFortress")
	assert(arena.enemy_ship_marker_bow.position.is_equal_approx(Vector3(-13.2, 0.65, -1.90)), "Siege Fortress MarkerBow must match calibrated anchor")
	
	arena.queue_free()
	print("  [PASS] Dynamic player vessel swapping and calibrated boss gangplank anchors verified.")

func _test_boarding_wave_scaling_and_telemetry() -> void:
	print("--- 7. Testing Boarding Wave Scaling & Telemetry Instrumentation ---")
	var arena: BoardingDefenseArena = ARENA_SCENE.instantiate() as BoardingDefenseArena
	add_child(arena)

	# 1. Tier 1 Scaling (Level 5 War Barge)
	arena.setup_encounter_difficulty(5, false, 0.0)
	assert(arena.boss_tier == 1, "Level 5 must scale to Tier 1 (got %d)" % arena.boss_tier)
	assert(arena.total_waves_to_win == 2, "Tier 1 must have 2 waves (got %d)" % arena.total_waves_to_win)
	assert(is_equal_approx(arena.wave_interval_sec, 9.0), "Tier 1 wave interval must be 9.0s (got %.1f)" % arena.wave_interval_sec)
	assert(arena._get_swarm_count_for_tier(1) == 1, "Tier 1 Wave 1 swarm count must be 1")
	assert(arena._get_swarm_count_for_tier(2) == 2, "Tier 1 Wave 2 swarm count must be 2")

	# 2. Tier 2 Scaling (Level 25 Captain Bone-Beard)
	arena.setup_encounter_difficulty(25, false, 0.0)
	assert(arena.boss_tier == 2, "Level 25 must scale to Tier 2 (got %d)" % arena.boss_tier)
	assert(arena.total_waves_to_win == 3, "Tier 2 must have 3 waves (got %d)" % arena.total_waves_to_win)
	assert(is_equal_approx(arena.wave_interval_sec, 8.0), "Tier 2 wave interval must be 8.0s (got %.1f)" % arena.wave_interval_sec)
	assert(arena._get_swarm_count_for_tier(1) == 2, "Tier 2 Wave 1 swarm count must be 2")

	# 3. Tier 3 Scaling (Level 42 Dread Boss)
	arena.setup_encounter_difficulty(42, false, 0.0)
	assert(arena.boss_tier == 3, "Level 42 must scale to Tier 3 (got %d)" % arena.boss_tier)
	assert(arena.total_waves_to_win == 4, "Tier 3 must have 4 waves (got %d)" % arena.total_waves_to_win)
	assert(is_equal_approx(arena.wave_interval_sec, 7.0), "Tier 3 wave interval must be 7.0s (got %.1f)" % arena.wave_interval_sec)
	assert(arena._get_swarm_count_for_tier(3) == 3, "Tier 3 Wave 3 swarm count must be 3")

	# 4. Endless Mode Scaling (Deep Distance > 2500m)
	arena.setup_encounter_difficulty(1, true, 3100.0)
	assert(arena.boss_tier == 4, "Endless > 2500m must scale to Tier 4 (got %d)" % arena.boss_tier)
	assert(arena.total_waves_to_win == 5, "Endless Tier 4 must have 5 waves (got %d)" % arena.total_waves_to_win)
	assert(is_equal_approx(arena.wave_interval_sec, 6.0), "Endless Tier 4 wave interval must be 6.0s (got %.1f)" % arena.wave_interval_sec)

	# 5. Telemetry Signal Emission Verification
	var captured_data: Dictionary = {
		"start_received": false,
		"end_received": false,
		"boss": "",
		"outcome": "",
		"waves_cleared": 0
	}

	var on_start := func(b_name: String, _tier: int, _waves: int, _vessel: String, _crew: String) -> void:
		captured_data["start_received"] = true
		captured_data["boss"] = b_name

	var on_end := func(_b_name: String, outcome: String, _dur: float, waves: int, _tot: int, _kills: int, _spawns: int, _dmg: float, _reason: String) -> void:
		captured_data["end_received"] = true
		captured_data["outcome"] = outcome
		captured_data["waves_cleared"] = waves

	EventBus.boarding_encounter_started.connect(on_start)
	EventBus.boarding_encounter_ended.connect(on_end)

	arena.setup_enemy_vessel("BossWarBarge")
	arena.setup_player_vessel("sloop")
	arena.setup_encounter_difficulty(5, false, 0.0)
	arena.current_wave = 2
	arena.encounter_mobs_spawned = 3

	arena._emit_encounter_started()
	assert(bool(captured_data["start_received"]), "EventBus.boarding_encounter_started must be emitted")
	assert(str(captured_data["boss"]) == "BossWarBarge", "Captured boss name must match setup (got '%s')" % str(captured_data["boss"]))

	arena.encounter_end_reason = "cleared"
	arena._emit_encounter_ended("VICTORY")
	assert(bool(captured_data["end_received"]), "EventBus.boarding_encounter_ended must be emitted")
	assert(str(captured_data["outcome"]) == "VICTORY", "Outcome must be VICTORY (got '%s')" % str(captured_data["outcome"]))
	assert(int(captured_data["waves_cleared"]) == 2, "Waves cleared must match current_wave (got %d)" % int(captured_data["waves_cleared"]))

	EventBus.boarding_encounter_started.disconnect(on_start)
	EventBus.boarding_encounter_ended.disconnect(on_end)

	arena.queue_free()
	print("  [PASS] Boarding wave scaling across 4 tiers and telemetry event emission verified.")

