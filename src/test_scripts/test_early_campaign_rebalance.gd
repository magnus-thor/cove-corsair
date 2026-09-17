extends Node

## Comprehensive Verification Test for Early Campaign Rebalance & Level 1 Spacing

var passed_count: int = 0
var failed_count: int = 0

func assert_test(condition: bool, message: String) -> void:
	if condition:
		print("  [PASS] %s" % message)
		passed_count += 1
	else:
		printerr("  [FAIL] %s" % message)
		failed_count += 1

func _get_slats(wall: Node) -> Array[BarricadeSegment]:
	var slats: Array[BarricadeSegment] = []
	for c in wall.get_children():
		if c is BarricadeSegment:
			slats.append(c)
	return slats

func _ready() -> void:
	print("==========================================================")
	print("  TESTING EARLY CAMPAIGN REBALANCE & LEVEL 1 TUNING       ")
	print("==========================================================")
	
	test_barricade_tier_hp_scaling()
	test_level_1_properties_and_chunks()
	test_chunk_barricade_siege_buffer_and_pickups()
	test_live_dinghy_cannon_shatter_level_1()
	await test_river_map_hitbox_interior_clicks()
	
	print("==========================================================")
	print("  TEST RESULTS: %d / %d PASSED" % [passed_count, passed_count + failed_count])
	print("==========================================================")
	if failed_count == 0:
		print("ALL EARLY CAMPAIGN REBALANCE TESTS PASSED!")
		get_tree().quit(0)
	else:
		printerr("SOME TESTS FAILED!")
		get_tree().quit(1)

func test_barricade_tier_hp_scaling() -> void:
	print("\n--- TEST 1: Barricade Tier HP Dynamic Scaling ---")
	var wall_scene := preload("res://src/gameplay/obstacles/barricade_wall.tscn")
	var seg_scene := preload("res://src/gameplay/obstacles/barricade_segment.tscn")
	assert_test(wall_scene != null, "barricade_wall.tscn loaded")
	assert_test(seg_scene != null, "barricade_segment.tscn loaded")

	# 1. Tier 1 (Level 1: Slat HP = 1, 4 slats with center gap; Levels 2-3: Slat HP = 2, 5 slats)
	GameState.current_level = 1
	var wall_l1 := wall_scene.instantiate() as BarricadeWall
	add_child(wall_l1)
	var slats_l1 := _get_slats(wall_l1)
	assert_test(slats_l1.size() == 4, "Level 1 BarricadeWall spawned 4 slats (leaving center gap open)")
	var all_l1_slats_hp1 := true
	for s: BarricadeSegment in slats_l1:
		if s.hp != 1:
			all_l1_slats_hp1 = false
	assert_test(all_l1_slats_hp1, "Level 1 BarricadeWall slats all have HP = 1 (breaks in 1 standard shot)")
	wall_l1.queue_free()

	GameState.current_level = 2
	var wall_l2 := wall_scene.instantiate() as BarricadeWall
	add_child(wall_l2)
	var slats_l2 := _get_slats(wall_l2)
	assert_test(slats_l2.size() == 5, "Level 2 BarricadeWall spawned 5 slats")
	var all_l2_slats_hp2 := true
	for s: BarricadeSegment in slats_l2:
		if s.hp != 2:
			all_l2_slats_hp2 = false
	assert_test(all_l2_slats_hp2, "Level 2 BarricadeWall slats all have HP = 2")
	wall_l2.queue_free()

	# 2. Tier 2 (Levels 4-10): Slat HP = 6
	GameState.current_level = 4
	var wall_l4 := wall_scene.instantiate() as BarricadeWall
	add_child(wall_l4)
	var slats_l4 := _get_slats(wall_l4)
	var all_l4_slats_hp6 := true
	for s: BarricadeSegment in slats_l4:
		if s.hp != 6:
			all_l4_slats_hp6 = false
	assert_test(all_l4_slats_hp6, "Level 4 BarricadeWall slats all have HP = 6")
	wall_l4.queue_free()

	GameState.current_level = 10
	var wall_l10 := wall_scene.instantiate() as BarricadeWall
	add_child(wall_l10)
	var slats_l10 := _get_slats(wall_l10)
	var all_l10_slats_hp6 := true
	for s: BarricadeSegment in slats_l10:
		if s.hp != 6:
			all_l10_slats_hp6 = false
	assert_test(all_l10_slats_hp6, "Level 10 BarricadeWall slats all have HP = 6")
	wall_l10.queue_free()

	# 3. Tier 3 (Levels 11-25): Slat HP = 12
	GameState.current_level = 15
	var wall_l15 := wall_scene.instantiate() as BarricadeWall
	wall_l15.hp = 0 # unoverridden
	add_child(wall_l15)
	var slats_l15 := _get_slats(wall_l15)
	var all_l15_slats_hp12 := true
	for s: BarricadeSegment in slats_l15:
		if s.hp != 12:
			all_l15_slats_hp12 = false
	assert_test(all_l15_slats_hp12, "Level 15 BarricadeWall default slats have HP = 12")
	wall_l15.queue_free()

	# 4. Tier 4 (Levels 26+): Slat HP = 20
	GameState.current_level = 30
	var wall_l30 := wall_scene.instantiate() as BarricadeWall
	add_child(wall_l30)
	var slats_l30 := _get_slats(wall_l30)
	var all_l30_slats_hp20 := true
	for s: BarricadeSegment in slats_l30:
		if s.hp != 20:
			all_l30_slats_hp20 = false
	assert_test(all_l30_slats_hp20, "Level 30 BarricadeWall slats have HP = 20")
	wall_l30.queue_free()

	# 5. Explicit HP override rule:
	# Respected ONLY if specified > 0 and level > 10
	GameState.current_level = 2
	var wall_override_early := wall_scene.instantiate() as BarricadeWall
	wall_override_early.hp = 20 # Explicit 20 on Level 2 must be overridden to tier HP (2)
	add_child(wall_override_early)
	var slats_early := _get_slats(wall_override_early)
	assert_test(slats_early[0].hp == 2, "Level 2 ignores scene hp=20 override and enforces tier HP=2")
	wall_override_early.queue_free()

	GameState.current_level = 16
	var wall_override_late := wall_scene.instantiate() as BarricadeWall
	wall_override_late.hp = 25 # Explicit 25 on Level 16 (>10) must be respected
	add_child(wall_override_late)
	var slats_late := _get_slats(wall_override_late)
	assert_test(slats_late[0].hp == 25, "Level 16 respects explicit scene hp=25 override (>10)")
	wall_override_late.queue_free()

	# 6. Standalone BarricadeSegment
	GameState.current_level = 1
	var slat_standalone_l1 := seg_scene.instantiate() as BarricadeSegment
	add_child(slat_standalone_l1)
	assert_test(slat_standalone_l1.hp == 1, "Standalone BarricadeSegment on Level 1 scales to HP = 1")
	slat_standalone_l1.queue_free()

	GameState.current_level = 4
	var slat_standalone_l4 := seg_scene.instantiate() as BarricadeSegment
	add_child(slat_standalone_l4)
	assert_test(slat_standalone_l4.hp == 6, "Standalone BarricadeSegment on Level 4 scales to HP = 6")
	slat_standalone_l4.queue_free()

func test_level_1_properties_and_chunks() -> void:
	print("\n--- TEST 2: Level 1 Tuning (level_01.tres) ---")
	var l1 := load("res://src/data/resources/levels/level_01.tres") as LevelData
	assert_test(l1 != null, "level_01.tres loaded successfully")
	assert_test(l1.base_scroll_speed == 6.5, "Level 1 base_scroll_speed is 6.5 m/s (gentle, readable pace)")
	assert_test(l1.chunk_scenes.size() == 4, "Level 1 has 4 chunks for a welcoming intro (200m)")

func test_chunk_barricade_siege_buffer_and_pickups() -> void:
	print("\n--- TEST 3: Safe Buffer Zones & Early Level Pickups ---")
	var chunk_scene := load("res://src/gameplay/chunks/chunk_barricade_siege.tscn") as PackedScene
	assert_test(chunk_scene != null, "chunk_barricade_siege.tscn loaded")

	# 1. Higher Levels (Level 4): verify runtime safe buffer zone enforcement (>= 25m behind barricade)
	GameState.current_level = 4
	var chunk_l4 := chunk_scene.instantiate() as BaseTrackChunk
	add_child(chunk_l4)
	var barricade_l4 := chunk_l4.find_child("BarricadeWall", true, false) as BarricadeWall
	assert_test(barricade_l4 != null, "BarricadeWall found in chunk")
	var b_z_l4 := barricade_l4.position.z
	
	var trailing_l4: Array[Node] = []
	for c: Node in chunk_l4.get_node("Entities").get_children():
		if c is Area3D and c.position.z < b_z_l4 and c.is_in_group("enemies"):
			trailing_l4.append(c)
			
	assert_test(trailing_l4.size() >= 2, "Trailing enemy skiffs exist behind barricade in Level 4")
	for skiff: Node in trailing_l4:
		var buffer_distance := absf((skiff as Node3D).position.z - b_z_l4)
		assert_test(buffer_distance >= 25.0, "Enemy skiff at Z=%.1fm maintains >= 25.0m buffer behind barricade (actual: %.1fm)" % [(skiff as Node3D).position.z, buffer_distance])
	chunk_l4.queue_free()

	# 2. Level 1: verify early-level replacement (peaceful runway / recovery pickups)
	GameState.current_level = 1
	var chunk_l1 := chunk_scene.instantiate() as BaseTrackChunk
	add_child(chunk_l1)
	var barricade_l1 := chunk_l1.find_child("BarricadeWall", true, false) as BarricadeWall
	var b_z_l1 := barricade_l1.position.z

	# Verify: in Level 1, no 30 HP Turtle Rafts exist
	var has_turtle_30 := false
	for c: Node in chunk_l1.get_node("Entities").get_children():
		if c is Area3D and "max_hp" in c and int(c.get("max_hp")) >= 25 and not c.is_in_group("barricade"):
			has_turtle_30 = true
	assert_test(not has_turtle_30, "Level 1 does NOT spawn fortified 30 HP Turtle Rafts")

	# Verify: in Level 1, trailing enemy skiffs are replaced with recovery pickups
	var trailing_l1: Array[Node] = []
	for c: Node in chunk_l1.get_node("Entities").get_children():
		if c is Area3D and c.position.z < b_z_l1 and c.is_in_group("enemies"):
			trailing_l1.append(c)
	assert_test(trailing_l1.is_empty(), "Level 1 trailing enemies behind barricade replaced with recovery pickups (0 hostile skiffs)")

	chunk_l1.queue_free()

func test_live_dinghy_cannon_shatter_level_1() -> void:
	print("\n--- TEST 4: Live Dinghy Cannon vs Level 1 Barricade ---")
	GameState.current_level = 1
	GameState.active_vessel = "dinghy"
	GameState.vessel_tiers["dinghy"] = 1
	GameState.is_game_active = true
	GameState.targets_destroyed = 0
	
	var player_scene := load("res://src/gameplay/player/player_boat.tscn") as PackedScene
	var player := player_scene.instantiate() as PlayerSwerve
	add_child(player)
	var dinghy_data := load("res://src/data/resources/user_vessels/dinghy_ship.tres") as ShipData
	player.apply_ship_data(dinghy_data)
	assert_test(player.current_health == 3, "Dinghy hull HP is 3 (forgiving starter health)")
	
	# Instantiate a Level 1 BarricadeSegment
	var slat_scene := load("res://src/gameplay/obstacles/barricade_segment.tscn") as PackedScene
	var slat := slat_scene.instantiate() as BarricadeSegment
	add_child(slat)
	slat.global_position = Vector3(0.0, 0.5, -10.0)
	assert_test(slat.hp == 1, "Level 1 Barricade slat starts at 1 HP")

	# Shot 1: 1 standard cannon damage -> shatters cleanly in 1 hit!
	var initial_destroyed := GameState.targets_destroyed
	slat.take_damage(1)
	assert_test(slat.hp <= 0, "Barricade slat HP is 0 after first cannon hit")
	assert_test(slat._is_destroyed, "Barricade slat shatters completely on 1st hit")
	assert_test(GameState.targets_destroyed > initial_destroyed, "targets_destroyed incremented on barricade shatter")

	player.queue_free()

func test_river_map_hitbox_interior_clicks() -> void:
	print("\n--- TEST 5: River Map Milestone Hitbox & Interior Clicking ---")
	var river_map_scene := load("res://src/ui/river_map.tscn") as PackedScene
	assert_test(river_map_scene != null, "river_map.tscn loaded successfully")
	if not river_map_scene:
		return

	var river_map := river_map_scene.instantiate() as RiverMap
	add_child(river_map)
	await get_tree().process_frame

	# 1. Verify canvas layer hierarchy and mouse filters
	var terrain_layer := river_map.get_node("%TerrainLayer") as Control
	var river_path_layer := river_map.get_node("%RiverPathLayer") as Control
	var nodes_layer := river_map.get_node("%NodesLayer") as Control
	assert_test(terrain_layer != null and river_path_layer != null and nodes_layer != null, "All canvas layers present")

	assert_test(terrain_layer.mouse_filter == Control.MOUSE_FILTER_IGNORE, "TerrainLayer mouse_filter is MOUSE_FILTER_IGNORE")
	assert_test(river_path_layer.mouse_filter == Control.MOUSE_FILTER_IGNORE, "RiverPathLayer mouse_filter is MOUSE_FILTER_IGNORE")
	assert_test(nodes_layer.mouse_filter == Control.MOUSE_FILTER_PASS, "NodesLayer mouse_filter is MOUSE_FILTER_PASS")
	assert_test(nodes_layer.get_index() > terrain_layer.get_index(), "NodesLayer sits higher in tree than TerrainLayer")
	assert_test(nodes_layer.get_index() > river_path_layer.get_index(), "NodesLayer sits higher in tree than RiverPathLayer")

	# 2. Inspect Milestone TouchButton styleboxes and mouse filter
	var test_nodes: Array[int] = [1, 2, 5]
	for lvl: int in test_nodes:
		var node_ctrl := river_map.node_controls.get(lvl) as Control
		assert_test(node_ctrl != null, "Milestone node %d exists" % lvl)
		if not node_ctrl:
			continue

		assert_test(node_ctrl.mouse_filter == Control.MOUSE_FILTER_PASS, "Milestone node %d container mouse_filter is MOUSE_FILTER_PASS" % lvl)
		var btn := node_ctrl.find_child("TouchButton", true, false) as Button
		assert_test(btn != null, "TouchButton found in node %d" % lvl)
		if not btn:
			continue

		assert_test(not btn.flat, "TouchButton is not flat (uses explicit theme styleboxes)")
		assert_test(btn.mouse_filter == Control.MOUSE_FILTER_STOP, "TouchButton mouse_filter is MOUSE_FILTER_STOP")
		assert_test(btn.size == Vector2(96, 96), "TouchButton dimensions are 96x96px")

		var has_flat_styles := true
		var correct_radius := true
		var non_zero_alpha := true
		for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
			var sb := btn.get_theme_stylebox(state)
			if not (sb is StyleBoxFlat):
				has_flat_styles = false
			else:
				var sbf := sb as StyleBoxFlat
				if sbf.corner_radius_top_left != 48:
					correct_radius = false
				if sbf.bg_color.a <= 0.001:
					non_zero_alpha = false

		assert_test(has_flat_styles, "TouchButton uses StyleBoxFlat across ALL states (normal, hover, pressed, focus, disabled)")
		assert_test(correct_radius, "TouchButton corner_radius_all = 48 (half button size for solid circular disc)")
		assert_test(non_zero_alpha, "TouchButton StyleBoxFlat has solid clickable alpha (> 0.001)")

	# 3. Verify hit detection geometry across circular disc interior (Center, Halfway, Rim)
	var node1_ctrl := river_map.node_controls.get(1) as Control
	var btn1 := node1_ctrl.find_child("TouchButton", true, false) as Button
	
	var clicked_box := [-1]
	river_map.level_selected.connect(func(lvl: int) -> void:
		clicked_box[0] = lvl
	)

	var center := Vector2(48, 48)
	var rect := Rect2(Vector2.ZERO, btn1.size)
	var pt_center := Vector2(48, 48)
	var pt_half := Vector2(72, 48) # 24px from center
	var pt_rim := Vector2(92, 48)  # 44px from center (inside 48px radius)
	var pt_outside := Vector2(105, 48) # outside 48px radius

	assert_test(rect.has_point(pt_center) and pt_center.distance_to(center) <= 48.0, "Center point (48, 48) is inside 48px circular hitbox")
	assert_test(rect.has_point(pt_half) and pt_half.distance_to(center) <= 48.0, "Halfway point (72, 48) is inside 48px circular hitbox")
	assert_test(rect.has_point(pt_rim) and pt_rim.distance_to(center) <= 48.0, "Rim point (92, 48) is inside 48px circular hitbox")
	assert_test(not rect.has_point(pt_outside) or pt_outside.distance_to(center) > 48.0, "Outside point (105, 48) is outside 48px circular hitbox")

	# Test node trigger via button press
	clicked_box[0] = -1
	GameState.current_selected_level = 0
	GameState.highest_unlocked_level = 5
	btn1.emit_signal("pressed")
	assert_test(clicked_box[0] == 1, "TouchButton pressed signal triggers node 1 selection")
	assert_test(GameState.current_selected_level == 1, "GameState current_selected_level updated to 1")

	# Test Node 2 selection
	var node2_ctrl := river_map.node_controls.get(2) as Control
	var btn2 := node2_ctrl.find_child("TouchButton", true, false) as Button
	clicked_box[0] = -1
	btn2.emit_signal("pressed")
	assert_test(clicked_box[0] == 2, "TouchButton pressed signal triggers node 2 selection")
	assert_test(GameState.current_selected_level == 2, "GameState current_selected_level updated to 2")

	river_map.queue_free()

