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
	await test_live_dinghy_cannon_shatter_level_1()
	
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
	var wall_scene = preload("res://src/gameplay/obstacles/barricade_wall.tscn")
	var seg_scene = preload("res://src/gameplay/obstacles/barricade_segment.tscn")
	assert_test(wall_scene != null, "barricade_wall.tscn loaded")
	assert_test(seg_scene != null, "barricade_segment.tscn loaded")

	# 1. Tier 1 (Levels 1-3): Slat HP = 2
	GameState.current_level = 1
	var wall_l1 = wall_scene.instantiate() as BarricadeWall
	add_child(wall_l1)
	var slats_l1 = _get_slats(wall_l1)
	assert_test(slats_l1.size() > 0, "Level 1 BarricadeWall spawned %d slats" % slats_l1.size())
	var all_l1_slats_hp2 = true
	for s in slats_l1:
		if s.hp != 2:
			all_l1_slats_hp2 = false
	assert_test(all_l1_slats_hp2, "Level 1 BarricadeWall slats all have HP = 2 (breaks in 2 standard shots)")
	wall_l1.queue_free()

	# 2. Tier 2 (Levels 4-10): Slat HP = 6
	GameState.current_level = 4
	var wall_l4 = wall_scene.instantiate() as BarricadeWall
	add_child(wall_l4)
	var slats_l4 = _get_slats(wall_l4)
	var all_l4_slats_hp6 = true
	for s in slats_l4:
		if s.hp != 6:
			all_l4_slats_hp6 = false
	assert_test(all_l4_slats_hp6, "Level 4 BarricadeWall slats all have HP = 6")
	wall_l4.queue_free()

	GameState.current_level = 10
	var wall_l10 = wall_scene.instantiate() as BarricadeWall
	add_child(wall_l10)
	var slats_l10 = _get_slats(wall_l10)
	var all_l10_slats_hp6 = true
	for s in slats_l10:
		if s.hp != 6:
			all_l10_slats_hp6 = false
	assert_test(all_l10_slats_hp6, "Level 10 BarricadeWall slats all have HP = 6")
	wall_l10.queue_free()

	# 3. Tier 3 (Levels 11-25): Slat HP = 12
	GameState.current_level = 15
	var wall_l15 = wall_scene.instantiate() as BarricadeWall
	wall_l15.hp = 0 # unoverridden
	add_child(wall_l15)
	var slats_l15 = _get_slats(wall_l15)
	var all_l15_slats_hp12 = true
	for s in slats_l15:
		if s.hp != 12:
			all_l15_slats_hp12 = false
	assert_test(all_l15_slats_hp12, "Level 15 BarricadeWall default slats have HP = 12")
	wall_l15.queue_free()

	# 4. Tier 4 (Levels 26+): Slat HP = 20
	GameState.current_level = 30
	var wall_l30 = wall_scene.instantiate() as BarricadeWall
	add_child(wall_l30)
	var slats_l30 = _get_slats(wall_l30)
	var all_l30_slats_hp20 = true
	for s in slats_l30:
		if s.hp != 20:
			all_l30_slats_hp20 = false
	assert_test(all_l30_slats_hp20, "Level 30 BarricadeWall slats have HP = 20")
	wall_l30.queue_free()

	# 5. Explicit HP override rule:
	# Respected ONLY if specified > 0 and level > 10
	GameState.current_level = 2
	var wall_override_early = wall_scene.instantiate() as BarricadeWall
	wall_override_early.hp = 20 # Explicit 20 on Level 2 must be overridden to tier HP (2)
	add_child(wall_override_early)
	var slats_early = _get_slats(wall_override_early)
	assert_test(slats_early[0].hp == 2, "Level 2 ignores scene hp=20 override and enforces tier HP=2")
	wall_override_early.queue_free()

	GameState.current_level = 16
	var wall_override_late = wall_scene.instantiate() as BarricadeWall
	wall_override_late.hp = 25 # Explicit 25 on Level 16 (>10) must be respected
	add_child(wall_override_late)
	var slats_late = _get_slats(wall_override_late)
	assert_test(slats_late[0].hp == 25, "Level 16 respects explicit scene hp=25 override (>10)")
	wall_override_late.queue_free()

	# 6. Standalone BarricadeSegment
	GameState.current_level = 1
	var slat_standalone_l1 = seg_scene.instantiate() as BarricadeSegment
	add_child(slat_standalone_l1)
	assert_test(slat_standalone_l1.hp == 2, "Standalone BarricadeSegment on Level 1 scales to HP = 2")
	slat_standalone_l1.queue_free()

	GameState.current_level = 4
	var slat_standalone_l4 = seg_scene.instantiate() as BarricadeSegment
	add_child(slat_standalone_l4)
	assert_test(slat_standalone_l4.hp == 6, "Standalone BarricadeSegment on Level 4 scales to HP = 6")
	slat_standalone_l4.queue_free()

func test_level_1_properties_and_chunks() -> void:
	print("\n--- TEST 2: Level 1 Tuning (level_01.tres) ---")
	var l1 = load("res://src/data/resources/levels/level_01.tres") as LevelData
	assert_test(l1 != null, "level_01.tres loaded successfully")
	assert_test(l1.base_scroll_speed == 6.5, "Level 1 base_scroll_speed is 6.5 m/s (gentle, readable pace)")
	
	var l1_smugglers = load("res://src/data/resources/levels/level_01_smugglers_run.tres") as LevelData
	assert_test(l1_smugglers != null, "level_01_smugglers_run.tres loaded successfully")
	assert_test(l1_smugglers.base_scroll_speed == 6.5, "level_01_smugglers_run.tres base_scroll_speed is 6.5 m/s")

func test_chunk_barricade_siege_buffer_and_pickups() -> void:
	print("\n--- TEST 3: Safe Buffer Zones & Early Level Pickups ---")
	var chunk_scene = load("res://src/gameplay/chunks/chunk_barricade_siege.tscn") as PackedScene
	assert_test(chunk_scene != null, "chunk_barricade_siege.tscn loaded")

	var chunk = chunk_scene.instantiate() as BaseTrackChunk
	var barricade = chunk.find_child("BarricadeWall", true, false) as BarricadeWall
	assert_test(barricade != null, "BarricadeWall found in chunk")
	var barricade_z = barricade.position.z
	
	# Inspect raw enemy skiffs in Entities
	var entities = chunk.get_node("Entities")
	var raw_skiffs: Array[Node] = []
	for c in entities.get_children():
		if c is Area3D and c.position.z < barricade_z and c.is_in_group("enemies"):
			raw_skiffs.append(c)
			
	assert_test(raw_skiffs.size() >= 2, "Trailing enemy skiffs exist behind barricade in chunk scene")
	for skiff in raw_skiffs:
		var buffer_distance = absf(skiff.position.z - barricade_z)
		assert_test(buffer_distance >= 25.0, "Enemy skiff at Z=%.1fm maintains >= 25.0m buffer behind barricade (actual: %.1fm)" % [skiff.position.z, buffer_distance])

	# Now add to scene tree with GameState.current_level = 1 to test runtime early-level tuning
	GameState.current_level = 1
	add_child(chunk)

	# Verify: in Level 1, no 30 HP Turtle Rafts exist
	var has_turtle_30 = false
	for c in chunk.get_node("Entities").get_children():
		if c is Area3D and "max_hp" in c and c.max_hp >= 25 and not c.is_in_group("barricade"):
			has_turtle_30 = true
	assert_test(not has_turtle_30, "Level 1 does NOT spawn fortified 30 HP Turtle Rafts")

	# Verify: in Level 1, trailing enemy skiffs are replaced with recovery pickups
	var trailing_enemies: Array[Node] = []
	for c in chunk.get_node("Entities").get_children():
		if c is Area3D and c.position.z < barricade_z and c.is_in_group("enemies"):
			trailing_enemies.append(c)
	assert_test(trailing_enemies.is_empty(), "Level 1 trailing enemies behind barricade replaced with recovery pickups (0 hostile skiffs)")

	chunk.queue_free()

func test_live_dinghy_cannon_shatter_level_1() -> void:
	print("\n--- TEST 4: Live Dinghy Cannon vs Level 1 Barricade ---")
	GameState.current_level = 1
	GameState.is_game_active = true
	GameState.targets_destroyed = 0
	
	var player_scene = load("res://src/gameplay/player/player_boat.tscn") as PackedScene
	var player = player_scene.instantiate() as PlayerSwerve
	add_child(player)
	var dinghy_data = load("res://src/data/resources/user_vessels/dinghy_ship.tres") as ShipData
	player.apply_ship_data(dinghy_data)
	assert_test(player.current_health == 1, "Dinghy hull HP is 1")
	
	# Instantiate a Level 1 BarricadeSegment
	var slat_scene = load("res://src/gameplay/obstacles/barricade_segment.tscn") as PackedScene
	var slat = slat_scene.instantiate() as BarricadeSegment
	add_child(slat)
	slat.global_position = Vector3(0.0, 0.5, -10.0)
	assert_test(slat.hp == 2, "Level 1 Barricade slat starts at 2 HP")

	# Shot 1: 1 standard cannon damage
	slat.take_damage(1)
	assert_test(slat.hp == 1, "Barricade slat HP is 1 after first cannon hit")
	assert_test(not slat._is_destroyed, "Barricade slat survives 1st shot")

	# Shot 2: 1 standard cannon damage -> shatters!
	var initial_destroyed = GameState.targets_destroyed
	slat.take_damage(1)
	assert_test(slat.hp <= 0, "Barricade slat HP is 0 after second cannon hit")
	assert_test(slat._is_destroyed, "Barricade slat shatters completely on 2nd hit")
	assert_test(GameState.targets_destroyed > initial_destroyed, "targets_destroyed incremented on barricade shatter")

	player.queue_free()
