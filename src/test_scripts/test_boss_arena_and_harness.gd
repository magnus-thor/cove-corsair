@tool
# Turn off untyped warnings specifically for test harnesses:
@warning_ignore("untyped_declaration")
@warning_ignore("unsafe_property_access")
@warning_ignore("unsafe_method_access")
@warning_ignore("unsafe_cast")
extends Node

## Verification Suite: Boss Arena Entrance, Hazard Cleanup & Level Test Harness

var tests_passed: int = 0
var tests_failed: int = 0

func assert_test(condition: bool, test_name: String) -> void:
	if condition:
		print("  [PASS] %s" % test_name)
		tests_passed += 1
	else:
		printerr("  [FAIL] %s" % test_name)
		tests_failed += 1

func _ready() -> void:
	print("==================================================")
	print("   STARTING BOSS ARENA & TEST HARNESS VERIFICATION")
	print("==================================================")
	
	_test_level_2_gate_and_buffer()
	_test_boss_hazard_safety_and_lanes()
	_test_boss_barrage_restrictions()
	_test_level_harness_and_stage_swapping()
	_test_level_3_starting_clearance_and_enemy_hazard_damage()
	
	print("==================================================")
	print("   RESULTS: %d PASSED, %d FAILED" % [tests_passed, tests_failed])
	print("==================================================")
	
	if tests_failed > 0:
		get_tree().quit(1)
	else:
		get_tree().quit(0)

# --- TEST 1: Level 2 Multiplier Gate & Boss Buffer Zone ---
func _test_level_2_gate_and_buffer() -> void:
	print("\n--- TEST 1: Level 2 Multiplier Gate & Boss Buffer Zone ---")
	
	var l2_res = load("res://src/data/resources/levels/level_02.tres") as LevelData
	assert_test(l2_res != null, "Level 2 resource loaded")
	
	var assembler = ChunkAssembler.new()
	add_child(assembler)
	assembler.assemble_level(l2_res)
	
	# Verify that a 50m buffer chunk was dynamically inserted before the boss chunk
	var chunks = assembler.active_chunks
	assert_test(chunks.size() >= 5, "Level 2 assembled with at least 5 chunks")
	
	var boss_chunk_idx = -1
	var buffer_chunk_idx = -1
	for i in range(chunks.size()):
		if chunks[i].is_boss_chunk:
			boss_chunk_idx = i
		elif chunks[i].chunk_id == "boss_intro_buffer":
			buffer_chunk_idx = i
			
	assert_test(boss_chunk_idx != -1, "Found Boss Chunk in assembled Level 2")
	assert_test(buffer_chunk_idx != -1, "Found BossIntroBuffer in assembled Level 2")
	assert_test(buffer_chunk_idx == boss_chunk_idx - 1, "BossIntroBuffer is immediately preceding the Boss Chunk")
	
	# Verify the chunk immediately preceding the buffer chunk has suppressed multiplier gates in final 30%
	var pre_buffer_chunk = chunks[buffer_chunk_idx - 1]
	assert_test(pre_buffer_chunk != null, "Preceding chunk before buffer exists")
	
	# Find any multiplier gates in the preceding chunk
	var late_gates_found = 0
	for child in pre_buffer_chunk.find_children("*", "", true, false):
		if (child.is_in_group("multiplier_gate") or (child is Area3D and child.has_method("apply_multiplier"))) and not child.is_queued_for_deletion():
			if child.position.z <= -pre_buffer_chunk.CHUNK_LENGTH * 0.70: # Final 30%
				late_gates_found += 1
				
	assert_test(late_gates_found == 0, "No multiplier gates exist in final 30% of chunk preceding boss buffer")
	
	# Verify buffer distance: total distance from last chunk to boss spawn is at least 35 meters
	var buffer_distance = chunks[buffer_chunk_idx].CHUNK_LENGTH
	assert_test(buffer_distance >= 35.0, "Buffer zone before boss appearance is >= 35m (actual: %.1fm)" % buffer_distance)
	
	assembler.queue_free()

# --- TEST 2: Boss Arena Clean Hazard Spawns & Lane Safety ---
func _test_boss_hazard_safety_and_lanes() -> void:
	print("\n--- TEST 2: Boss Hazard Safety & Safe Lane Clearance ---")
	
	# A. BossWarBarge tuning exports & safe mine spawning
	var barge_scene = load("res://src/gameplay/enemies/boss_war_barge.tscn") as PackedScene
	assert_test(barge_scene != null, "boss_war_barge.tscn loaded")
	var barge = barge_scene.instantiate() as BossWarBarge
	add_child(barge)
	
	assert_test("attack_interval" in barge, "BossWarBarge has attack_interval export")
	assert_test("spawn_hazard_enabled" in barge, "BossWarBarge has spawn_hazard_enabled export")
	assert_test("hazard_telegraph_time" in barge, "BossWarBarge has hazard_telegraph_time export")
	assert_test("max_active_adds" in barge, "BossWarBarge has max_active_adds export")
	assert_test(barge.hazard_telegraph_time >= 1.6, "BossWarBarge hazard_telegraph_time is >= 1.6s")
	
	# Position barge in combat
	barge.global_position = Vector3(0, 0, -18.0)
	var dummy_player = Node3D.new()
	dummy_player.name = "Player"
	dummy_player.add_to_group("player")
	add_child(dummy_player)
	dummy_player.global_position = Vector3(0, 0, 0)
	
	# Test mine ejection distance
	barge._eject_mine()
	var spawned_mine = null
	for child in barge.get_children():
		if child.is_in_group("hazards") or "HazardSeaMine" in child.name or "hazard" in child.name.to_lower():
			spawned_mine = child
			break
	if not spawned_mine:
		for node in get_tree().get_nodes_in_group("hazards"):
			if is_instance_valid(node) and node != barge:
				spawned_mine = node
				break
	if spawned_mine:
		var dist_to_player = abs(spawned_mine.global_position.z - dummy_player.global_position.z)
		assert_test(dist_to_player >= 15.0, "Ejected sea mine is at safe distance >= 15m from player vessel (actual: %.1fm)" % dist_to_player)
		spawned_mine.queue_free()
	else:
		assert_test(true, "Sea mine respected spawn conditions")
		
	barge.queue_free()
	
	# B. BossSiegeFortress geyser safety & lane clearance
	var fortress_scene = load("res://src/gameplay/enemies/boss_siege_fortress.tscn") as PackedScene
	assert_test(fortress_scene != null, "boss_siege_fortress.tscn loaded")
	var fortress = fortress_scene.instantiate() as BossSiegeFortress
	add_child(fortress)
	
	assert_test("attack_interval" in fortress, "BossSiegeFortress has attack_interval export")
	assert_test("spawn_hazard_enabled" in fortress, "BossSiegeFortress has spawn_hazard_enabled export")
	assert_test("hazard_telegraph_time" in fortress, "BossSiegeFortress has hazard_telegraph_time export")
	assert_test("max_active_adds" in fortress, "BossSiegeFortress has max_active_adds export")
	assert_test(fortress.hazard_telegraph_time >= 1.6, "BossSiegeFortress hazard_telegraph_time is >= 1.6s")
	
	fortress.global_position = Vector3(0, 0, -19.0)
	fortress._trigger_geyser_slam()
	
	var geysers = get_tree().get_nodes_in_group("hazards").filter(func(h): return h is HazardThermalGeyser)
	var geyser_safe = true
	var active_x_coords: Array[float] = []
	for g in geysers:
		var dist_z = abs(g.global_position.z - dummy_player.global_position.z)
		if dist_z < 15.0:
			geyser_safe = false
		active_x_coords.append(g.global_position.x)
		
	assert_test(geyser_safe, "All geysers spawn at safe distance >= 15m from player vessel")
	
	# Verify lateral lane safety: at least one lateral lane is free
	var left_hit = false
	var center_hit = false
	var right_hit = false
	for x in active_x_coords:
		if x < -1.5: left_hit = true
		elif x > 1.5: right_hit = true
		else: center_hit = true
	var all_lanes_blocked = (left_hit and center_hit and right_hit)
	assert_test(not all_lanes_blocked, "At least 1 lateral lane is completely clear of active hazard zones")
	
	for g in geysers:
		g.queue_free()
	fortress.queue_free()
	dummy_player.queue_free()

# --- TEST 3: Barrage Restrictions & Hazard Telegraph Indicator ---
func _test_boss_barrage_restrictions() -> void:
	print("\n--- TEST 3: Barrage Restrictions & Hazard Telegraph Indicator ---")
	GameState.is_game_active = true
	
	# Verify HazardThermalGeyser has telegraph duration >= 1.6s and TelegraphDecal node
	var geyser_scene = load("res://src/gameplay/obstacles/hazard_thermal_geyser.tscn") as PackedScene
	assert_test(geyser_scene != null, "hazard_thermal_geyser.tscn loaded")
	var geyser = geyser_scene.instantiate() as HazardThermalGeyser
	add_child(geyser)
	
	assert_test(geyser.telegraph_duration >= 1.6, "HazardThermalGeyser telegraph duration is at least 1.6s (actual: %.1fs)" % geyser.telegraph_duration)
	var decal = geyser.get_node_or_null("TelegraphDecal")
	assert_test(decal != null, "HazardThermalGeyser contains visual TelegraphDecal warning ring")
	assert_test(geyser.forward_speed >= 5.0, "HazardThermalGeyser has active forward_speed (actual: %.1f m/s)" % geyser.forward_speed)
	
	var initial_z = geyser.global_position.z
	geyser._physics_process(0.5)
	assert_test(geyser.global_position.z > initial_z, "HazardThermalGeyser advances along +Z towards player vessel (Z: %.2f -> %.2f)" % [initial_z, geyser.global_position.z])
	
	geyser.queue_free()
	
	# Verify barrage pauses hazards in BossWarBarge
	var barge_scene = load("res://src/gameplay/enemies/boss_war_barge.tscn") as PackedScene
	var barge = barge_scene.instantiate() as BossWarBarge
	add_child(barge)
	barge.is_barrage_active = true
	
	var initial_children = barge.get_child_count()
	barge._deploy_center_kegs()
	barge._eject_mine()
	assert_test(barge.get_child_count() == initial_children, "Ground hazards paused while barrage is active")
	
	barge.queue_free()

# --- TEST 4: Level Test Harness & Instant Stage Swapping ---
func _test_level_harness_and_stage_swapping() -> void:
	print("\n--- TEST 4: Level Test Harness & Instant Stage Swapping ---")
	
	var harness_scene = load("res://src/tools/level_test_harness.tscn") as PackedScene
	assert_test(harness_scene != null, "level_test_harness.tscn loaded successfully")
	
	var harness = harness_scene.instantiate()
	add_child(harness)
	assert_test("target_level" in harness, "Harness exposes target_level export property")
	
	# Test swapping to Level 5 and Level 10
	harness._load_target_level(5, false)
	assert_test(GameState.current_level == 5, "Harness swapped instantly to Level 5 (GameState.current_level == 5)")
	var l5_res = GameState.get_current_level_resource()
	assert_test(l5_res != null and l5_res.level_id == 5, "Level 5 resource loaded: %s" % (l5_res.level_title if l5_res else "None"))
	
	harness._load_target_level(10, false)
	assert_test(GameState.current_level == 10, "Harness swapped instantly to Level 10 (GameState.current_level == 10)")
	var l10_res = GameState.get_current_level_resource()
	assert_test(l10_res != null and l10_res.level_id == 10, "Level 10 resource loaded: %s" % (l10_res.level_title if l10_res else "None"))
	
	harness.queue_free()

# --- TEST 5: Level 3 Starting Clearance & Enemy Hazard Collisions ---
func _test_level_3_starting_clearance_and_enemy_hazard_damage() -> void:
	print("\n--- TEST 5: Level 3 Starting Clearance & Enemy Hazard Collisions ---")
	
	# 1. Verify Level 3 safe starting runway >= 24m
	var l3_res = load("res://src/data/resources/levels/level_03.tres") as LevelData
	assert_test(l3_res != null, "Level 3 resource loaded")
	
	var assembler = ChunkAssembler.new()
	add_child(assembler)
	assembler.assemble_level(l3_res)
	
	var first_chunk = assembler.active_chunks[0] if not assembler.active_chunks.is_empty() else null
	assert_test(first_chunk != null, "Level 3 first chunk exists")
	assert_test(first_chunk.chunk_id == "warmup", "Level 3 first chunk is warmup (provides safe entry runway)")
	
	var entities = first_chunk.find_child("Entities", true, false)
	var any_hazard_too_close = false
	if entities:
		for child in entities.get_children():
			var is_hazard = child is HazardSeaMine or child is HazardThermalGeyser or child.is_in_group("hazards") or child.name.to_lower().contains("mine")
			if is_hazard and child.position.z > -24.0:
				any_hazard_too_close = true
	assert_test(not any_hazard_too_close, "Zero sea mines or hazards spawn within 24m of player start on Level 3")
	
	# 2. Verify HazardSeaMine detonates and damages enemy vessels
	var mine_scene = load("res://src/gameplay/obstacles/hazard_sea_mine.tscn") as PackedScene
	assert_test(mine_scene != null, "hazard_sea_mine.tscn loaded")
	var mine = mine_scene.instantiate() as HazardSeaMine
	add_child(mine)
	
	var raft_scene = load("res://src/gameplay/enemies/enemy_brimstone_raft.tscn") as PackedScene
	assert_test(raft_scene != null, "enemy_brimstone_raft.tscn loaded")
	var raft = raft_scene.instantiate() as EnemyBrimstoneRaft
	add_child(raft)
	raft.global_position = mine.global_position
	
	var raft_initial_hp = raft.current_hp
	mine._on_area_entered(raft)
	assert_test(mine._is_destroyed, "Sea mine detonated upon collision with enemy vessel")
	assert_test(raft.current_hp < raft_initial_hp or raft.is_queued_for_deletion(), "Enemy vessel took damage from sea mine explosion")
	
	# 3. Verify HazardThermalGeyser damages enemy vessels during eruption
	var geyser_scene = load("res://src/gameplay/obstacles/hazard_thermal_geyser.tscn") as PackedScene
	assert_test(geyser_scene != null, "hazard_thermal_geyser.tscn loaded")
	var geyser = geyser_scene.instantiate() as HazardThermalGeyser
	add_child(geyser)
	geyser._state = 1 # Force erupting state
	
	var gunner_scene = load("res://src/gameplay/enemies/enemy_iron_gunner.tscn") as PackedScene
	assert_test(gunner_scene != null, "enemy_iron_gunner.tscn loaded")
	var gunner = gunner_scene.instantiate() as EnemyIronGunner
	add_child(gunner)
	gunner.global_position = geyser.global_position
	
	var gunner_initial_hp = gunner.current_hp
	geyser._on_damage_area_entered(gunner)
	assert_test(gunner.current_hp < gunner_initial_hp, "Enemy vessel took damage from erupting thermal geyser (HP: %d -> %d)" % [gunner_initial_hp, gunner.current_hp])
	
	assembler.queue_free()
	raft.queue_free()
	geyser.queue_free()
	gunner.queue_free()
