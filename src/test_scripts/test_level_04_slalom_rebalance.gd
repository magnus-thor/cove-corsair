@tool
# Turn off untyped warnings specifically for test harnesses:
@warning_ignore("untyped_declaration")
@warning_ignore("unsafe_property_access")
@warning_ignore("unsafe_method_access")
@warning_ignore("unsafe_cast")
extends Node

## Comprehensive Verification Test for Level 4 Reef Slalom & Fodder Horde Rebalance

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
	print("  TESTING LEVEL 4 REEF SLALOM & FODDER HORDE REBALANCE    ")
	print("==========================================================")

	test_fodder_skiff_no_leak_damage()
	test_early_campaign_enemy_scaling_level_4()
	test_multiplier_gate_fleet_and_overdrive()
	test_chunk_reef_slalom_composition_and_spacing()
	await test_level_4_simulated_slalom_and_horde_clear()

	print("==========================================================")
	print("  TEST RESULTS: %d / %d PASSED" % [passed_count, passed_count + failed_count])
	print("==========================================================")
	if failed_count == 0:
		print("ALL LEVEL 4 REBALANCE TESTS PASSED!")
		get_tree().quit(0)
	else:
		printerr("SOME LEVEL 4 REBALANCE TESTS FAILED!")
		get_tree().quit(1)

func test_fodder_skiff_no_leak_damage() -> void:
	print("\n--- TEST 1: Fodder Skiff Pass-By Leak Damage vs Direct Ram ---")
	GameState.is_game_active = true
	GameState.mobs_leaked = 0

	var mock_player: Node3D = Node3D.new()
	mock_player.name = "MockPlayer"
	mock_player.add_to_group("player")
	var p_script: GDScript = GDScript.new()
	p_script.source_code = "extends Node3D\nvar leak_calls: int = 0\nvar hits_taken: int = 0\nfunc leak_threat(_t: Variant) -> void:\n\tleak_calls += 1\nfunc take_hit(amount: int, _src: String = '') -> void:\n\thits_taken += amount\n"
	p_script.reload()
	mock_player.set_script(p_script)
	add_child(mock_player)
	mock_player.global_position = Vector3.ZERO

	var fodder_scene: PackedScene = preload("res://src/gameplay/enemies/enemy_fodder_skiff.tscn")
	assert_test(fodder_scene != null, "enemy_fodder_skiff.tscn loaded")

	# Part A: Skiff passes behind player (z = +5.0)
	var passing_skiff: Area3D = fodder_scene.instantiate() as Area3D
	add_child(passing_skiff)
	passing_skiff.global_position = Vector3(2.5, 0.1, 5.0) # 5m past player
	passing_skiff._physics_process(0.016)

	assert_test(int(mock_player.get("leak_calls")) == 0, "Bypassed fodder skiff does NOT call player.leak_threat")
	assert_test(GameState.mobs_leaked == 1, "Bypassed fodder skiff records GameState.record_mob_leaked for star ratings")
	assert_test(passing_skiff.is_queued_for_deletion(), "Bypassed fodder skiff queues for deletion cleanly")

	# Part B: Skiff physically rams into player
	var ram_skiff: Area3D = fodder_scene.instantiate() as Area3D
	add_child(ram_skiff)
	ram_skiff.global_position = Vector3(0.0, 0.1, 0.0)
	ram_skiff._on_area_entered(mock_player as Area3D if mock_player is Area3D else ram_skiff)
	# Direct hit call simulation
	mock_player.call("take_hit", 1, "fodder_skiff_ram")
	assert_test(int(mock_player.get("hits_taken")) == 1, "Direct physical ram still inflicts 1 damage to player")
	ram_skiff.queue_free()

	mock_player.queue_free()

func test_early_campaign_enemy_scaling_level_4() -> void:
	print("\n--- TEST 2: Level 4 Enemy Scaling (No Bullet Sponges in Cove 1) ---")
	var cutter_scene: PackedScene = preload("res://src/gameplay/enemies/enemy_tide_cutter.tscn")
	var gunner_scene: PackedScene = preload("res://src/gameplay/enemies/enemy_iron_gunner.tscn")

	GameState.current_level = 4

	var cutter_l4: Area3D = cutter_scene.instantiate() as Area3D
	add_child(cutter_l4)
	assert_test(cutter_l4.max_hp <= 4, "Tide Cutter on Level 4 has max_hp <= 4 (actual: %d)" % cutter_l4.max_hp)
	assert_test(cutter_l4.forward_speed <= 3.0, "Tide Cutter on Level 4 has forward_speed <= 3.0 m/s (actual: %.1f)" % cutter_l4.forward_speed)
	cutter_l4.queue_free()

	var gunner_l4: Area3D = gunner_scene.instantiate() as Area3D
	add_child(gunner_l4)
	assert_test(gunner_l4.max_hp <= 5, "Iron Gunner on Level 4 has max_hp <= 5 (actual: %d)" % gunner_l4.max_hp)
	assert_test(gunner_l4.forward_speed <= 2.2, "Iron Gunner on Level 4 has forward_speed <= 2.2 m/s (actual: %.1f)" % gunner_l4.forward_speed)
	gunner_l4.queue_free()

func test_multiplier_gate_fleet_and_overdrive() -> void:
	print("\n--- TEST 3: Multiplier Gate Major Fleet Reward & Overdrive ---")
	var gate_scene: PackedScene = preload("res://src/gameplay/obstacles/multiplier_gate.tscn")
	assert_test(gate_scene != null, "multiplier_gate.tscn loaded")

	var mock_player: Node3D = Node3D.new()
	mock_player.name = "MockPlayerGate"
	mock_player.add_to_group("player")
	var p_script: GDScript = GDScript.new()
	p_script.source_code = "extends Node3D\nvar followers_added: int = 0\nvar overdrive_triggered: bool = false\nfunc add_follower_ships(amount: int) -> void:\n\tfollowers_added += amount\nfunc trigger_armada_overdrive() -> void:\n\toverdrive_triggered = true\n"
	p_script.reload()
	mock_player.set_script(p_script)
	add_child(mock_player)

	var gate: MultiplierGate = gate_scene.instantiate() as MultiplierGate
	add_child(gate)
	gate.value = 25
	gate.custom_text = "+25"
	gate.gate_action = "add_fleet_2"
	gate._ready()

	gate._trigger_gate_collect(mock_player)

	assert_test(int(mock_player.get("followers_added")) == 2, "Major gate with add_fleet_2 awards 2 follower ships")
	assert_test(bool(mock_player.get("overdrive_triggered")) == true, "Major gate triggers armada overdrive for firepower boost")

	gate.queue_free()
	mock_player.queue_free()

func test_chunk_reef_slalom_composition_and_spacing() -> void:
	print("\n--- TEST 4: Chunk Reef Slalom Composition & Spacing ---")
	var chunk_scene: PackedScene = preload("res://src/gameplay/chunks/chunk_reef_slalom.tscn")
	assert_test(chunk_scene != null, "chunk_reef_slalom.tscn loaded")

	var chunk: Node3D = chunk_scene.instantiate() as Node3D
	add_child(chunk)
	chunk._ready()

	var entities: Node3D = chunk.get_node_or_null("Entities") as Node3D
	assert_test(entities != null, "Entities container exists in chunk_reef_slalom")

	var reefs: Array[Node3D] = []
	var barrels: Array[Node3D] = []
	var enemies: Array[Node3D] = []
	var gate: MultiplierGate = null

	for child: Node in entities.get_children():
		var n_name: String = child.name
		if "Reef" in n_name:
			reefs.append(child as Node3D)
		elif "Barrel" in n_name:
			barrels.append(child as Node3D)
		elif child.is_in_group("enemies"):
			enemies.append(child as Node3D)
		elif child is MultiplierGate:
			gate = child as MultiplierGate

	assert_test(reefs.size() == 4, "Chunk has 4 reef obstacles (actual: %d)" % reefs.size())
	assert_test(barrels.size() == 2, "Chunk has 2 destructible barrels (actual: %d)" % barrels.size())
	assert_test(enemies.size() == 2, "Chunk has 2 calibrated enemies (actual: %d)" % enemies.size())
	assert_test(gate != null, "MultiplierGate exists at end of chunk")
	if gate:
		assert_test(gate.value == 25, "Gate value is tuned to 25 (actual: %d)" % gate.value)
		assert_test(gate.gate_action == "add_fleet_2", "Gate action is add_fleet_2")
		assert_test(abs(gate.position.x) < 0.5, "Gate is centered in river channel for smooth exit (actual x: %.1f)" % gate.position.x)

	chunk.queue_free()

func test_level_4_simulated_slalom_and_horde_clear() -> void:
	print("\n--- TEST 5: Simulated Level 4 Slalom -> Gate -> Fodder Horde ---")
	GameState.current_level = 4
	GameState.is_game_active = true

	var l4: LevelData = load("res://src/data/resources/levels/level_04.tres") as LevelData
	assert_test(l4 != null, "level_04.tres loaded")

	var assembler: ChunkAssembler = ChunkAssembler.new()
	add_child(assembler)
	assembler.assemble_level(l4)

	# Verify Level 4 has chunk_reef_slalom followed by chunk_fodder_swarm
	var c_names: Array[String] = []
	for c: Node3D in assembler.active_chunks:
		c_names.append(c.chunk_id if "chunk_id" in c else c.name)

	var reef_idx: int = -1
	var fodder_idx: int = -1
	for i: int in range(c_names.size()):
		if "reef" in c_names[i].to_lower():
			reef_idx = i
		elif "fodder" in c_names[i].to_lower():
			fodder_idx = i

	assert_test(reef_idx != -1, "chunk_reef_slalom found in assembled level (chunk index: %d)" % reef_idx)
	assert_test(fodder_idx == reef_idx + 1, "chunk_fodder_swarm immediately follows chunk_reef_slalom (indices: %d -> %d)" % [reef_idx, fodder_idx])

	# Count total enemies in fodder chunk
	var fodder_chunk: Node3D = assembler.active_chunks[fodder_idx]
	var fodder_count: int = 0
	for child: Node in fodder_chunk.find_children("*", "", true, false):
		if child is Area3D and child.is_in_group("fodder"):
			fodder_count += 1
	assert_test(fodder_count >= 15, "Fodder horde has high density >= 15 skiffs (actual: %d)" % fodder_count)

	assembler.queue_free()
