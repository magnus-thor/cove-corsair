@tool
# Turn off untyped warnings specifically for test harnesses:
@warning_ignore("untyped_declaration")
@warning_ignore("unsafe_property_access")
@warning_ignore("unsafe_method_access")
@warning_ignore("unsafe_cast")
extends Node

## Comprehensive Verification Test for Gate Overcharge Detonation & Early Campaign Level Tuning

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
	print("  TESTING GATE OVERCHARGE DETONATION & EARLY LEVEL REBALANCE")
	print("==========================================================")

	test_multiplier_gate_overcharge_detonation()
	test_levels_1_to_5_reef_counts_and_flow()
	test_chunk_reef_slalom_geometry()
	test_fodder_skiff_no_leak_damage()

	print("==========================================================")
	print("  TEST RESULTS: %d / %d PASSED" % [passed_count, passed_count + failed_count])
	print("==========================================================")
	if failed_count == 0:
		print("ALL GATE OVERCHARGE & EARLY CAMPAIGN TESTS PASSED!")
		get_tree().quit(0)
	else:
		printerr("SOME TESTS FAILED!")
		get_tree().quit(1)

func test_multiplier_gate_overcharge_detonation() -> void:
	print("\n--- TEST 1: Multiplier Gate Overcharge Detonation ---")
	var gate_scene := preload("res://src/gameplay/obstacles/multiplier_gate.tscn")
	assert_test(gate_scene != null, "multiplier_gate.tscn loaded")

	var player_scene := preload("res://src/gameplay/player/player_boat.tscn")
	assert_test(player_scene != null, "player_boat.tscn loaded")

	var player := player_scene.instantiate() as PlayerSwerve
	add_child(player)
	player.add_to_group("player")
	var initial_escorts: int = player.follower_boats.size()
	var initial_fire_rate: float = player.fire_rate_multiplier

	# 1. Gate under 100: shooting increases value
	var gate := gate_scene.instantiate() as MultiplierGate
	gate.value = 90
	add_child(gate)
	assert_test(gate.value == 90, "Gate initial value is 90")
	assert_test(gate.is_active, "Gate starts active")

	# Mock cannonball shot
	var ball := Node.new()
	ball.set("damage", 1)
	gate.on_shot_hit(ball)
	assert_test(gate.value == 95, "Standard shot (+5) increases value from 90 to 95")
	assert_test(gate.overcharge_hits == 0, "Overcharge hits remain 0 while value < 100")

	# Second shot reaches 100 MAX
	gate.on_shot_hit(ball)
	assert_test(gate.value == 100, "Second shot brings value to 100 MAX")
	assert_test(gate.custom_text == "★ 100 MAX ★", "Gate label updates to ★ 100 MAX ★")
	assert_test(gate.overcharge_hits == 0, "Overcharge hits still 0 on the exact hit that caps at 100")

	# 2. Subsequent hits at 100 MAX trigger overcharge
	gate.on_shot_hit(ball)
	assert_test(gate.overcharge_hits == 1, "First overcharge shot increments overcharge_hits to 1")
	assert_test(gate.is_active, "Gate remains active at 1 hit")

	# Second overcharge shot (hits OVERCHARGE_HITS_NEEDED = 2) -> Detonates!
	gate.on_shot_hit(ball)
	assert_test(gate.is_active == false, "Gate is deactivated on overcharge detonation")
	assert_test(gate.collision_layer == 0 and gate.collision_mask == 0, "Gate collisions cleared on detonation")
	assert_test(player.follower_boats.size() > initial_escorts, "Detonation awarded escort ship(s) to player fleet")
	assert_test(player.fire_rate_multiplier == 2.0, "Detonation activated armada overdrive 2.0x fire rate")

	# Clean up
	gate.queue_free()
	ball.queue_free()
	player.queue_free()

func test_levels_1_to_5_reef_counts_and_flow() -> void:
	print("\n--- TEST 2: Levels 1 to 5 Reef Counts & Progression ---")
	var level_paths: Array[String] = [
		"res://src/data/resources/levels/level_01.tres",
		"res://src/data/resources/levels/level_02.tres",
		"res://src/data/resources/levels/level_03.tres",
		"res://src/data/resources/levels/level_04.tres",
		"res://src/data/resources/levels/level_05.tres"
	]

	for i in range(level_paths.size()):
		var lvl_num: int = i + 1
		var path: String = level_paths[i]
		var lvl: LevelData = load(path) as LevelData
		assert_test(lvl != null, "Level %d resource loaded" % lvl_num)
		assert_test(lvl.chunk_scenes.size() >= 4, "Level %d has at least 4 chunks" % lvl_num)

		# Count total reefs across all chunks in this level
		var total_reefs: int = 0
		for chunk_scene: PackedScene in lvl.chunk_scenes:
			var chunk: Node = chunk_scene.instantiate()
			var reefs: Array[Node] = []
			_find_nodes_of_type_or_name(chunk, "hazard_reef", reefs)
			total_reefs += reefs.size()
			chunk.queue_free()

		print("  Level %d Total Reefs: %d" % [lvl_num, total_reefs])
		if lvl_num == 1:
			assert_test(total_reefs == 0, "Level 1 has 0 reefs (clean welcoming river for Dinghy)")
		elif lvl_num == 2:
			assert_test(total_reefs == 0, "Level 2 has 0 reefs (focus on mine gauntlet & fodder swarm)")
		elif lvl_num == 3:
			assert_test(total_reefs == 0, "Level 3 has 0 reefs (gunner skirmish & mine gauntlet)")
		elif lvl_num == 4:
			assert_test(total_reefs <= 2, "Level 4 has at most 2 margin reefs (actual: %d, no chicanes)" % total_reefs)
		elif lvl_num == 5:
			assert_test(total_reefs == 0, "Level 5 has 0 reefs (Boss Ironjaw arena)")

func test_chunk_reef_slalom_geometry() -> void:
	print("\n--- TEST 3: Chunk Reef Slalom Geometry ---")
	var chunk_scene := preload("res://src/gameplay/chunks/chunk_reef_slalom.tscn")
	assert_test(chunk_scene != null, "chunk_reef_slalom.tscn loaded")

	var chunk := chunk_scene.instantiate() as BaseTrackChunk
	add_child(chunk)

	var reefs: Array[Node] = []
	_find_nodes_of_type_or_name(chunk, "hazard_reef", reefs)
	assert_test(reefs.size() == 2, "chunk_reef_slalom has exactly 2 margin reefs (reduced from 4 chicane reefs)")

	for r: Node in reefs:
		var n3d := r as Node3D
		assert_test(abs(n3d.position.x) >= 3.5, "Reef '%s' placed at outer margin (x = %.1f, >= 3.5m from center)" % [r.name, n3d.position.x])

	# Verify gate is present at end of chunk
	var gate := chunk.find_child("Gate_Modest", true, false) as MultiplierGate
	assert_test(gate != null, "MultiplierGate Gate_Modest is present in chunk")
	if gate:
		assert_test(abs(gate.position.x) <= 0.5, "Gate is centered in river lane (x = %.1f)" % gate.position.x)

	chunk.queue_free()

func test_fodder_skiff_no_leak_damage() -> void:
	print("\n--- TEST 4: Fodder Skiff Leak Fix ---")
	var fodder_scene := preload("res://src/gameplay/enemies/enemy_fodder_skiff.tscn")
	assert_test(fodder_scene != null, "enemy_fodder_skiff.tscn loaded")

	var player_scene := preload("res://src/gameplay/player/player_boat.tscn")
	var player := player_scene.instantiate() as PlayerSwerve
	add_child(player)
	player.add_to_group("player")
	var hp_before: int = player.current_health

	var skiff := fodder_scene.instantiate() as Node3D
	add_child(skiff)
	skiff.global_position = Vector3(3.0, 0.0, 5.0) # Downriver past player

	# Simulate process frame where skiff is past player
	# Before fix, it called player.leak_threat(self) dealing 1 hull damage on pass-by.
	# Now, it records mob leaked without damaging player hull!
	skiff._physics_process(0.1)

	assert_test(player.current_health == hp_before, "Fodder skiff pass-by does NOT deal leak_threat damage (HP remained %d)" % hp_before)

	skiff.queue_free()
	player.queue_free()

func _find_nodes_of_type_or_name(root: Node, search: String, results: Array[Node]) -> void:
	var lsearch := search.to_lower()
	var rname := root.name.to_lower()
	var sname := ""
	if root.get_script() and "resource_path" in root.get_script():
		sname = str(root.get_script().resource_path).to_lower()
	if root.scene_file_path:
		sname += " " + root.scene_file_path.to_lower()

	if lsearch in rname or lsearch in sname:
		results.append(root)

	for child: Node in root.get_children():
		_find_nodes_of_type_or_name(child, search, results)
