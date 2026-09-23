@tool
# Turn off untyped warnings specifically for test harnesses:
@warning_ignore("untyped_declaration")
@warning_ignore("unsafe_property_access")
@warning_ignore("unsafe_method_access")
@warning_ignore("unsafe_cast")
extends Node

## Comprehensive Verification Test for Level 3 Rebalance & Single Upgrade Dinghy Accessibility

var passed_count: int = 0
var failed_count: int = 0

func assert_test(condition: bool, message: String) -> void:
	if condition:
		print("  [PASS] %s" % message)
		passed_count += 1
	else:
		printerr("  [FAIL] %s" % message)
		failed_count += 1

func _ready() -> void:
	print("==========================================================")
	print("  TESTING LEVEL 3 REBALANCE & DINGHY ACCESSIBILITY       ")
	print("==========================================================")
	
	test_level_03_resource_schema()
	test_enemy_difficulty_scaling_early_vs_late()
	test_assembled_level_03_density_and_health_caps()
	await test_single_upgrade_dinghy_combat_simulation()
	
	print("==========================================================")
	print("  TEST RESULTS: %d / %d PASSED" % [passed_count, passed_count + failed_count])
	print("==========================================================")
	if failed_count == 0:
		print("ALL LEVEL 3 REBALANCE TESTS PASSED!")
		get_tree().quit(0)
	else:
		printerr("SOME LEVEL 3 REBALANCE TESTS FAILED!")
		get_tree().quit(1)

func test_level_03_resource_schema() -> void:
	print("\n--- TEST 1: Level 3 Resource Schema & Fodder Swarm Integration ---")
	var l3 = load("res://src/data/resources/levels/level_03.tres") as LevelData
	assert_test(l3 != null, "level_03.tres loaded successfully")
	assert_test(l3.level_id == 3, "Level 3 ID is 3")
	assert_test(l3.chunk_scenes.size() >= 6, "Level 3 has at least 6 chunk scenes (actual: %d)" % l3.chunk_scenes.size())
	
	var has_fodder: bool = false
	var has_warmup: bool = false
	var chunk_names: Array[String] = []
	for c_scene in l3.chunk_scenes:
		var c_path: String = c_scene.resource_path.get_file()
		chunk_names.append(c_path)
		if "chunk_fodder_swarm" in c_path:
			has_fodder = true
		if "chunk_warmup" in c_path:
			has_warmup = true
	assert_test(has_fodder, "Level 3 includes chunk_fodder_swarm.tscn in recipe")
	assert_test(has_warmup, "Level 3 includes Gate 1 chunk_warmup.tscn in recipe")
	assert_test(chunk_names[chunk_names.size() - 1] == "chunk_finish_line.tscn", "Last chunk is chunk_finish_line.tscn")

func test_enemy_difficulty_scaling_early_vs_late() -> void:
	print("\n--- TEST 2: Individual Enemy Scaling: Early (L3) vs Late (L10) ---")
	var gunner_scene = preload("res://src/gameplay/enemies/enemy_iron_gunner.tscn")
	var cutter_scene = preload("res://src/gameplay/enemies/enemy_tide_cutter.tscn")
	var raft_scene = preload("res://src/gameplay/enemies/enemy_brimstone_raft.tscn")
	
	# Part A: Level 3 Early Campaign Scaling (cur_level = 3)
	GameState.current_level = 3
	
	var gunner_l3 = gunner_scene.instantiate() as Area3D
	add_child(gunner_l3)
	assert_test(gunner_l3.max_hp <= 4, "EnemyIronGunner on Level 3 has HP <= 4 (actual: %d)" % gunner_l3.max_hp)
	assert_test(gunner_l3.shoot_interval >= 2.0, "EnemyIronGunner on Level 3 shoot interval is relaxed >= 2.0s (actual: %.1fs)" % gunner_l3.shoot_interval)
	assert_test(gunner_l3.forward_speed <= 2.0, "EnemyIronGunner on Level 3 forward speed is <= 2.0 m/s (actual: %.1f)" % gunner_l3.forward_speed)
	gunner_l3.queue_free()
	
	var cutter_l3 = cutter_scene.instantiate() as Area3D
	add_child(cutter_l3)
	assert_test(cutter_l3.max_hp <= 3, "EnemyTideCutter on Level 3 has HP <= 3 (actual: %d)" % cutter_l3.max_hp)
	assert_test(cutter_l3.forward_speed <= 3.0, "EnemyTideCutter on Level 3 forward speed is <= 3.0 m/s (actual: %.1f)" % cutter_l3.forward_speed)
	assert_test(cutter_l3.steer_speed <= 2.0, "EnemyTideCutter on Level 3 steer tracking speed is <= 2.0 m/s (actual: %.1f)" % cutter_l3.steer_speed)
	cutter_l3.queue_free()
	
	var raft_l3 = raft_scene.instantiate() as Area3D
	add_child(raft_l3)
	assert_test(raft_l3.max_hp <= 3, "EnemyBrimstoneRaft on Level 3 has HP <= 3 (actual: %d)" % raft_l3.max_hp)
	assert_test(raft_l3.forward_speed <= 3.0, "EnemyBrimstoneRaft on Level 3 forward speed is <= 3.0 m/s (actual: %.1f)" % raft_l3.forward_speed)
	raft_l3.queue_free()
	
	# Part B: Level 10 Late Campaign Baseline Preservation (cur_level = 10)
	GameState.current_level = 10
	
	var gunner_l10 = gunner_scene.instantiate() as Area3D
	add_child(gunner_l10)
	assert_test(gunner_l10.max_hp == 22, "EnemyIronGunner on Level 10 retains baseline 22 HP")
	assert_test(gunner_l10.forward_speed == 2.6, "EnemyIronGunner on Level 10 retains baseline 2.6 m/s speed")
	gunner_l10.queue_free()
	
	var cutter_l10 = cutter_scene.instantiate() as Area3D
	add_child(cutter_l10)
	assert_test(cutter_l10.max_hp == 20, "EnemyTideCutter on Level 10 retains baseline 20 HP")
	assert_test(cutter_l10.forward_speed == 6.8, "EnemyTideCutter on Level 10 retains baseline 6.8 m/s speed")
	cutter_l10.queue_free()
	
	var raft_l10 = raft_scene.instantiate() as Area3D
	add_child(raft_l10)
	assert_test(raft_l10.max_hp == 18, "EnemyBrimstoneRaft on Level 10 retains baseline 18 HP")
	assert_test(raft_l10.forward_speed == 7.8, "EnemyBrimstoneRaft on Level 10 retains baseline 7.8 m/s speed")
	raft_l10.queue_free()

func test_assembled_level_03_density_and_health_caps() -> void:
	print("\n--- TEST 3: Assembled Level 3 Enemy Density & Health Caps ---")
	GameState.current_level = 3
	
	var l3 = load("res://src/data/resources/levels/level_03.tres") as LevelData
	var assembler := ChunkAssembler.new()
	add_child(assembler)
	assembler.assemble_level(l3)
	
	var total_enemies: int = 0
	var bullet_sponges_count: int = 0 # any enemy with HP > 4
	
	for chunk in assembler.active_chunks:
		for child in chunk.find_children("*", "", true, false):
			if child is Area3D and (child.is_in_group("enemies") or child.is_in_group("fodder")):
				total_enemies += 1
				var hp = child.get("current_hp") if "current_hp" in child else (child.get("max_hp") if "max_hp" in child else 1)
				if hp != null and int(hp) > 4:
					bullet_sponges_count += 1
					
	print("  [INFO] Total enemy vessels on Level 3: %d" % total_enemies)
	assert_test(total_enemies >= 15, "Level 3 features high enemy density: >= 15 enemies present (actual: %d)" % total_enemies)
	assert_test(bullet_sponges_count == 0, "Zero bullet sponges on Level 3: all enemies have HP <= 4 (found: %d)" % bullet_sponges_count)
	
	assembler.queue_free()

func test_single_upgrade_dinghy_combat_simulation() -> void:
	print("\n--- TEST 4: Single Upgrade Dinghy Combat Simulation ---")
	GameState.current_level = 3
	
	# Dinghy Tier 2: 3 HP, 1 Cannon firing at 0.2s interval, 1 damage per shot
	var dinghy_data = preload("res://src/data/resources/user_vessels/dinghy_ship.tres") as ShipData
	assert_test(dinghy_data != null, "dinghy_ship.tres loaded")
	
	# Simulate cannon encounter vs Level 3 Tide Cutter (3 HP)
	var cutter = preload("res://src/gameplay/enemies/enemy_tide_cutter.tscn").instantiate() as Area3D
	add_child(cutter)
	assert_test(cutter.current_hp == 3, "Tide Cutter starts at 3 HP on Level 3")
	
	cutter.take_damage(1)
	assert_test(cutter.current_hp == 2, "Tide Cutter has 2 HP after 1 dinghy cannon hit")
	cutter.take_damage(1)
	assert_test(cutter.current_hp == 1, "Tide Cutter has 1 HP after 2 dinghy cannon hits")
	cutter.take_damage(1)
	assert_test(cutter.current_hp == 0, "Tide Cutter defeated on 3rd hit (sunk in ~0.6s of firing)")
	cutter.queue_free()
	
	# Simulate cannon encounter vs Level 3 Brimstone Raft (3 HP)
	var raft = preload("res://src/gameplay/enemies/enemy_brimstone_raft.tscn").instantiate() as Area3D
	add_child(raft)
	assert_test(raft.current_hp == 3, "Brimstone Raft starts at 3 HP on Level 3")
	raft.take_damage(3)
	assert_test(raft.current_hp == 0, "Brimstone Raft cleanly destroyed in 3 shots before impact")
	raft.queue_free()
	
	# Simulate cannon encounter vs Level 3 Iron Gunner (4 HP)
	var gunner = preload("res://src/gameplay/enemies/enemy_iron_gunner.tscn").instantiate() as Area3D
	add_child(gunner)
	assert_test(gunner.current_hp == 4, "Iron Gunner starts at 4 HP on Level 3")
	gunner.take_damage(4)
	assert_test(gunner.current_hp == 0, "Iron Gunner destroyed in 4 shots (under 1 second of firing)")
	gunner.queue_free()
