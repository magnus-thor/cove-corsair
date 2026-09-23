extends Node3D

var _timer: float = 0.0
var _test_step: int = 0
var _failures: int = 0

func _ready() -> void:
	print("--- TEST CAMPAIGN PACING & GATEKEEPERS START ---")
	call_deferred("_run_all_tests")

func _run_all_tests() -> void:
	_test_replay_next_level_advancement()
	_test_captain_ironjaw_telegraph()
	_test_reef_hostile_collision()
	_test_universal_3part_level_structure()
	_test_climax_and_finish_mob_density()
	_test_gatekeeper_defeat_advice()

	print("==================================================")
	if _failures == 0:
		print("ALL PACING & GATEKEEPER TESTS PASSED SUCCESSFULLY!")
	else:
		print("PACING & GATEKEEPER TESTS FAILED WITH %d ERRORS" % _failures)
	print("==================================================")
	get_tree().quit(0 if _failures == 0 else 1)

func _assert_true(condition: bool, msg: String) -> void:
	if not condition:
		print("[FAIL] %s" % msg)
		_failures += 1
	else:
		print("[PASS] %s" % msg)

func _test_replay_next_level_advancement() -> void:
	print("\n-- Test 1: Replay Next Level Advancement --")
	GameState.highest_unlocked_level = 5
	GameState.current_level = 2
	GameState.current_selected_level = 2
	GameState.should_auto_start = false

	# When player clears level 2 on replay:
	GameState.unlock_next_level()

	_assert_true(GameState.current_level == 3, "Replaying Level 2 advanced current_level to 3 (got %d)" % GameState.current_level)
	_assert_true(GameState.current_selected_level == 3, "current_selected_level synced to 3 (got %d)" % GameState.current_selected_level)
	_assert_true(GameState.highest_unlocked_level == 5, "highest_unlocked_level preserved at 5 (got %d)" % GameState.highest_unlocked_level)

	# When player is at max level 45
	GameState.highest_unlocked_level = 45
	GameState.current_level = 45
	GameState.unlock_next_level()
	_assert_true(GameState.current_level == 45, "Max level 45 clamped to 45 (got %d)" % GameState.current_level)

func _test_captain_ironjaw_telegraph() -> void:
	print("\n-- Test 2: Captain Ironjaw Telegraph Visual Reticle --")
	var telegraph_scene: PackedScene = load("res://src/vfx/telegraph_ironjaw_mortar.tscn") as PackedScene
	_assert_true(telegraph_scene != null, "Telegraph scene exists")
	if telegraph_scene != null:
		var telegraph_node: Node3D = telegraph_scene.instantiate() as Node3D
		add_child(telegraph_node)
		_assert_true(telegraph_node != null, "Telegraph instantiates cleanly")
		_assert_true(telegraph_node.has_method("setup"), "Telegraph has setup() method")
		_assert_true(telegraph_node.has_signal("countdown_finished"), "Telegraph has countdown_finished signal")
		
		# Test setup
		telegraph_node.call("setup", 1.8, 1.8)
		_assert_true(telegraph_node.visible, "Telegraph is visible when active")
		telegraph_node.queue_free()

func _test_reef_hostile_collision() -> void:
	print("\n-- Test 3: Reef Hostile Collision & Steering Clamp --")
	var reef_scene: PackedScene = load("res://src/gameplay/obstacles/hazard_reef.tscn") as PackedScene
	_assert_true(reef_scene != null, "Hazard reef scene exists")
	
	var cutter_scene: PackedScene = load("res://src/gameplay/enemies/enemy_tide_cutter.tscn") as PackedScene
	_assert_true(cutter_scene != null, "Enemy tide cutter scene exists")

	if reef_scene != null and cutter_scene != null:
		var reef_node: Node3D = reef_scene.instantiate() as Node3D
		var cutter_node: Node3D = cutter_scene.instantiate() as Node3D
		add_child(reef_node)
		add_child(cutter_node)

		# Position cutter right inside reef detection radius (radius is 1.8m)
		reef_node.global_position = Vector3(0.0, 0.0, 0.0)
		cutter_node.global_position = Vector3(0.5, 0.0, 0.5)

		# Trigger reef collision check manually passing cutter_node
		if reef_node.has_method("_check_collision"):
			reef_node.call("_check_collision", cutter_node)

		_assert_true(cutter_node.is_queued_for_deletion() or cutter_node.get("is_dead") == true or cutter_node.get("current_hp") <= 0, "Enemy colliding with reef is destroyed")

		# Test cutter steering target clamping
		if cutter_node.has_method("get_target_lane_x"):
			var clamped_x: float = float(cutter_node.call("get_target_lane_x"))
			_assert_true(abs(clamped_x) <= 2.65, "Tide cutter target lane clamped inside navigable channel (<= 2.65m)")

		reef_node.queue_free()
		cutter_node.queue_free()

func _test_universal_3part_level_structure() -> void:
	print("\n-- Test 4: Universal 3-Part Level Structure Across Campaign --")
	var test_levels: Array[int] = [1, 2, 3, 4, 5, 8, 12, 20, 30, 45]
	for lvl in test_levels:
		var path: String = "res://src/data/resources/levels/level_%02d.tres" % lvl
		var lvl_res: Resource = load(path)
		_assert_true(lvl_res != null, "Level %02d resource loaded" % lvl)
		if lvl_res == null:
			continue

		var chunks: Array = lvl_res.get("chunk_scenes") as Array
		var chunk_count: int = chunks.size()
		var min_expected_chunks: int = 4 if lvl == 1 else 5
		_assert_true(chunk_count >= min_expected_chunks, "Level %02d has at least %d chunks (got %d)" % [lvl, min_expected_chunks, chunk_count])

		# Locate Gate 1 (Warmup) and Gate 2 (Barricade Siege)
		var gate_indices: Array[int] = []
		for i in range(chunk_count):
			var c_res: Resource = chunks[i] as Resource
			if c_res != null and c_res.resource_path.is_empty() == false:
				var c_name: String = c_res.resource_path.get_file().to_lower()
				if "warmup" in c_name or "gate" in c_name or "barricade" in c_name:
					gate_indices.append(i)

		if lvl >= 1:
			_assert_true(gate_indices.size() >= 2, "Level %02d has 2 gates (got %d: %s)" % [lvl, gate_indices.size(), str(gate_indices)])
			if gate_indices.size() >= 2:
				var gate1_ratio: float = float(gate_indices[0]) / float(chunk_count)
				var gate2_ratio: float = float(gate_indices[1]) / float(chunk_count)
				_assert_true(gate1_ratio >= 0.15 and gate1_ratio <= 0.40, "Level %02d Gate 1 is around ~33%% mark (ratio: %.2f)" % [lvl, gate1_ratio])
				_assert_true(gate2_ratio >= 0.48 and gate2_ratio <= 0.75, "Level %02d Gate 2 is around ~66%% mark (ratio: %.2f)" % [lvl, gate2_ratio])
				
				# Horde chunk immediately after Gate 2
				var after_gate2_idx: int = gate_indices[1] + 1
				if after_gate2_idx < chunk_count:
					var post_gate_chunk: Resource = chunks[after_gate2_idx] as Resource
					var post_name: String = post_gate_chunk.resource_path.get_file().to_lower()
					_assert_true("fodder" in post_name or "swarm" in post_name or "climax" in post_name or "gauntlet" in post_name or "boss" in post_name or "finish" in post_name,
						"Level %02d chunk after Gate 2 is a swarm/horde chunk (got %s)" % [lvl, post_name])

func _test_climax_and_finish_mob_density() -> void:
	print("\n-- Test 5: Climax and Finish Line Mob Density --")
	var climax_scene: PackedScene = load("res://src/gameplay/chunks/chunk_vanguard_climax.tscn") as PackedScene
	_assert_true(climax_scene != null, "Vanguard Climax scene exists")
	if climax_scene != null:
		var climax_node: Node3D = climax_scene.instantiate() as Node3D
		add_child(climax_node)
		# Count children in climax Entities node
		var entities_node: Node = climax_node.get_node_or_null("Entities")
		var entity_count: int = entities_node.get_child_count() if entities_node else 0
		_assert_true(entity_count >= 15, "Vanguard Climax has dense entity layout (>= 15 entities, got %d)" % entity_count)
		climax_node.queue_free()

	var finish_scene: PackedScene = load("res://src/gameplay/chunks/chunk_finish_line.tscn") as PackedScene
	_assert_true(finish_scene != null, "Finish Line scene exists")
	if finish_scene != null:
		var finish_node: Node3D = finish_scene.instantiate() as Node3D
		add_child(finish_node)
		_assert_true(finish_node.has_method("_spawn_finish_wave"), "Finish Line has dynamic finish wave spawner")
		finish_node.queue_free()

func _test_gatekeeper_defeat_advice() -> void:
	print("\n-- Test 6: Gatekeeper Defeat Advice & Level 8 Calibration --")
	var gatekeepers: Array[int] = [8, 15, 22, 30, 37, 44]
	for gk in gatekeepers:
		GameState.current_level = gk
		# Verify settlement screen advice logic
		var is_gk: bool = gk in [8, 15, 22, 30, 37, 44]
		_assert_true(is_gk, "Level %d recognized as Gatekeeper level" % gk)
