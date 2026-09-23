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

func _ready() -> void:
	print("\n========================================================")
	print("  TESTING ROUTE A BOARDING & ENDLESS BOSS ENCOUNTER")
	print("========================================================\n")
	
	_test_route_a_desperation_threshold_and_clamp()
	_test_boarding_adapter_defeat_flow()
	_test_endless_mode_boss_pool_and_target_distance()
	_test_endless_mode_boss_spawn_at_distance()
	_test_endless_mode_boss_slain_rewards()
	
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
	
	# Deal damage above 25% threshold (HP drops to 50% > 25%)
	var dmg_half: int = int(max_hp * 0.5)
	boss.call("take_damage", dmg_half)
	var hp_after_first: int = int(boss.get("current_hp"))
	assert(hp_after_first > int(max_hp * 0.25), "HP must remain above 25 percent (got %d / %d)" % [hp_after_first, max_hp])
	var has_triggered_1: bool = bool(boss.get("has_triggered_boarding"))
	assert(not has_triggered_1, "Boarding must NOT trigger above 25% HP threshold")
	
	# Deal damage to drop below 25% threshold (HP drops to ~20% <= 25%)
	var dmg_desperation: int = int(max_hp * 0.3)
	boss.call("take_damage", dmg_desperation)
	var hp_after_second: int = int(boss.get("current_hp"))
	assert(hp_after_second <= int(max_hp * 0.25), "HP must be <= 25 percent (got %d / %d)" % [hp_after_second, max_hp])
	var has_triggered_2: bool = bool(boss.get("has_triggered_boarding"))
	assert(has_triggered_2, "Boarding MUST trigger when HP <= 25%% (got %d / %d)" % [hp_after_second, max_hp])
	
	# Deal massive fatal damage (1000) while boarding is active
	boss.call("take_damage", 1000)
	var clamped_hp: int = int(boss.get("current_hp"))
	assert(clamped_hp == 1, "HP must be clamped at 1 during boarding to prevent premature death (got %d)" % clamped_hp)
	var is_defeated: bool = bool(boss.get("_is_defeated"))
	assert(not is_defeated, "Boss must not be defeated prematurely while boarding party is active")
	
	boss.queue_free()
	print("  [PASS] Route A Desperation threshold (<= 25%) and HP clamp at 1 verified.")

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
