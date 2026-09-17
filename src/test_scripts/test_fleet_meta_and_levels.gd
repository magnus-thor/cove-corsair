@tool
# Turn off untyped warnings specifically for test harnesses:
@warning_ignore("untyped_declaration")
@warning_ignore("unsafe_property_access")
@warning_ignore("unsafe_method_access")
@warning_ignore("unsafe_cast")
extends Node3D

var total_tests: int = 0
var passed_tests: int = 0

func assert_test(cond: bool, test_name: String) -> void:
	total_tests += 1
	if cond:
		passed_tests += 1
		print("  [PASS] %s" % test_name)
	else:
		push_error("  [FAIL] %s" % test_name)
		print("  [FAIL] %s" % test_name)

func _ready() -> void:
	print("==================================================")
	print("  TESTING FLEET META TUNING & LEVELS 4-12 EXPANSION")
	print("==================================================")

	_test_vector_a_chokepoints()
	_test_vector_b_dps_bottlenecks()
	_test_levels_4_through_12()
	_test_river_map_integration()

	print("==================================================")
	print("  RESULTS: %d / %d TESTS PASSED" % [passed_tests, total_tests])
	print("==================================================")

	if passed_tests == total_tests:
		print("ALL FLEET META & LEVEL EXPANSION TESTS PASSED!")
		get_tree().quit(0)
	else:
		get_tree().quit(1)

func _test_vector_a_chokepoints() -> void:
	print("\n--- SECTION 1: Vector A Chokepoints (chunk_mine_gauntlet.tscn) ---")
	var scene = load("res://src/gameplay/chunks/chunk_mine_gauntlet.tscn") as PackedScene
	assert_test(scene != null, "chunk_mine_gauntlet.tscn loads successfully")
	if not scene:
		return

	var chunk = scene.instantiate() as BaseTrackChunk
	assert_test(chunk != null, "chunk_mine_gauntlet instantiates as BaseTrackChunk")
	add_child(chunk)

	var entities = chunk.get_node_or_null("Entities")
	assert_test(entities != null, "Entities container exists in mine gauntlet chunk")
	if not entities:
		chunk.queue_free()
		return

	# Collect mine pairs at each gate Z (-12, -24, -36, -46)
	var gates = {
		-12.0: [],
		-24.0: [],
		-36.0: [],
		-46.0: []
	}

	for child in entities.get_children():
		if "mine" in child.name.to_lower() or child.is_in_group("destructible") and child is Area3D:
			for gz in gates.keys():
				if is_equal_approx(child.position.z, gz):
					gates[gz].append(child)

	# Verify each gate has a pair of mines with ~2.1m passage gap
	for gz in gates.keys():
		var mines = gates[gz]
		assert_test(mines.size() >= 2, "Gate at Z=%.1f has at least 2 mines forming passage" % gz)
		if mines.size() >= 2:
			var x1 = minf(mines[0].position.x, mines[1].position.x)
			var x2 = maxf(mines[0].position.x, mines[1].position.x)
			# Mine collision cylinder radius is 0.6m
			var gap = (x2 - 0.6) - (x1 + 0.6)
			print("  [INFO] Gate Z=%.1f mine centers: (%.2f, %.2f), passage gap = %.2fm" % [gz, x1, x2, gap])
			assert_test(absf(gap - 2.1) < 0.15, "Gate Z=%.1f passage gap is ~2.1m (actual: %.2fm)" % [gz, gap])

	# 1. Verify The Dinghy (1.6m hitbox, lateral_speed = 12.0)
	var dinghy_ship = load("res://src/data/resources/user_vessels/dinghy_ship.tres") as ShipData
	assert_test(dinghy_ship != null, "The Dinghy ShipData loaded")
	assert_test(dinghy_ship.max_health == 2, "The Dinghy has 2 HP (fragile skiff)")
	assert_test(dinghy_ship.move_speed == 12.0, "The Dinghy has 12.0 move speed")
	assert_test(is_equal_approx(dinghy_ship.collision_size.x, 1.6), "The Dinghy hitbox width is 1.6m (actual: %.2f)" % dinghy_ship.collision_size.x)

	# Simulate Dinghy slalom through gates
	var dinghy_half_w = dinghy_ship.collision_size.x / 2.0 # 0.8m
	var slalom_targets = {
		-12.0: -1.8,
		-24.0: 0.0,
		-36.0: 1.8,
		-46.0: 0.0
	}
	var dinghy_clipped = false
	for gz in slalom_targets.keys():
		var target_x = slalom_targets[gz]
		var mines = gates[gz]
		for m in mines:
			var m_x = m.position.x
			# Cylinder radius 0.6m vs Dinghy box [-0.8, +0.8]
			var dinghy_min = target_x - dinghy_half_w
			var dinghy_max = target_x + dinghy_half_w
			var mine_min = m_x - 0.6
			var mine_max = m_x + 0.6
			if not (dinghy_max < mine_min or dinghy_min > mine_max):
				dinghy_clipped = true
				print("  [CLIPPED] Dinghy clipped mine at x=%.2f at gate Z=%.1f" % [m_x, gz])
	assert_test(not dinghy_clipped, "The Dinghy cleanly slaloms through all 2.1m gates without clipping")

	# 2. Verify The Ironclad (2.4m hitbox) attempting to steer through center gap (X=0.0) without shooting
	var ironclad_ship = load("res://src/data/resources/user_vessels/ironclad_ship.tres") as ShipData
	assert_test(ironclad_ship != null, "The Ironclad ShipData loaded")
	assert_test(ironclad_ship.max_health == 8, "The Ironclad has 8 HP (armored brawler)")
	assert_test(is_equal_approx(ironclad_ship.collision_size.x, 2.4), "The Ironclad hitbox width is 2.4m (actual: %.2f)" % ironclad_ship.collision_size.x)

	var ironclad_half_w = ironclad_ship.collision_size.x / 2.0 # 1.2m
	var center_mines = gates[-24.0]
	var ironclad_clipped_center = false
	for m in center_mines:
		var m_x = m.position.x
		var ironclad_min = 0.0 - ironclad_half_w # -1.2
		var ironclad_max = 0.0 + ironclad_half_w # +1.2
		var mine_min = m_x - 0.6
		var mine_max = m_x + 0.6
		if not (ironclad_max < mine_min or ironclad_min > mine_max):
			ironclad_clipped_center = true
	assert_test(ironclad_clipped_center, "The Ironclad (2.4m hitbox) clips mines when steering through 2.1m center gap")

	chunk.queue_free()

func _test_vector_b_dps_bottlenecks() -> void:
	print("\n--- SECTION 2: Vector B DPS Bottlenecks (chunk_barricade_siege.tscn) ---")
	var scene = load("res://src/gameplay/chunks/chunk_barricade_siege.tscn") as PackedScene
	assert_test(scene != null, "chunk_barricade_siege.tscn loads successfully")
	if not scene:
		return

	var chunk = scene.instantiate() as BaseTrackChunk
	assert_test(chunk != null, "chunk_barricade_siege instantiates as BaseTrackChunk")
	add_child(chunk)

	var barricade_wall = chunk.find_child("BarricadeWall", true, false) as BarricadeWall
	assert_test(barricade_wall != null, "BarricadeWall node found in chunk")
	if barricade_wall:
		assert_test(barricade_wall.hp >= 20 and barricade_wall.hp <= 25, "BarricadeWall default HP is between 20 and 25 (actual: %d)" % barricade_wall.hp)

	var turtle_raft_data = load("res://src/data/resources/enemy_vessels/turtle_raft.tres") as EnemyData
	assert_test(turtle_raft_data != null, "turtle_raft.tres loads successfully")
	if turtle_raft_data:
		assert_test(turtle_raft_data.max_hp == 30, "Turtle Raft has 30 HP (actual: %d)" % turtle_raft_data.max_hp)

	# Test collision damage: intact barricade deals 3 damage to player hull
	# and triggers invulnerability guard so multiple adjacent slats in a single frame do not stack
	var player_scene = load("res://src/gameplay/player/player_boat.tscn") as PackedScene
	assert_test(player_scene != null, "player_boat.tscn loads successfully")

	if player_scene:
		GameState.is_game_active = true
		
		# Test 1 HP Dinghy vs Barricade
		var dinghy_player = player_scene.instantiate()
		add_child(dinghy_player)
		var dinghy_data = load("res://src/data/resources/user_vessels/dinghy_ship.tres") as ShipData
		dinghy_player.apply_ship_data(dinghy_data)
		assert_test(dinghy_player.current_health == 2, "Dinghy player starts with 2 HP")

		var slat_mock = Area3D.new()
		slat_mock.set_script(load("res://src/gameplay/obstacles/barricade_segment.gd"))
		add_child(slat_mock)
		slat_mock._ready()

		# Simulate collision
		dinghy_player._on_area_entered(slat_mock)
		assert_test(dinghy_player.current_health == 0, "Dinghy took 3 damage from barricade and health dropped to 0")
		assert_test(dinghy_player.is_game_over, "Dinghy is destroyed instantly by 3 collision damage")
		dinghy_player.queue_free()

		# Test 8 HP Ironclad vs Barricade
		GameState.is_game_active = true
		var ironclad_player = player_scene.instantiate()
		add_child(ironclad_player)
		var ironclad_data = load("res://src/data/resources/user_vessels/ironclad_ship.tres") as ShipData
		ironclad_player.apply_ship_data(ironclad_data)
		assert_test(ironclad_player.current_health == 8, "Ironclad player starts with 8 HP")

		# Simulate collision with first slat
		ironclad_player._on_area_entered(slat_mock)
		assert_test(ironclad_player.current_health == 5, "Ironclad took 3 damage from barricade and survives with 5 HP")
		assert_test(not ironclad_player.is_game_over, "Ironclad survives barricade collision")

		# Simulate collision with adjacent second slat in the same frame/burst
		var slat_mock_2 = Area3D.new()
		slat_mock_2.set_script(load("res://src/gameplay/obstacles/barricade_segment.gd"))
		add_child(slat_mock_2)
		slat_mock_2._ready()
		ironclad_player._on_area_entered(slat_mock_2)
		assert_test(ironclad_player.current_health == 5, "Barricade collision guard prevented second slat from stacking damage (health remains 5)")

		ironclad_player.queue_free()
		slat_mock.queue_free()
		slat_mock_2.queue_free()

	# Verify Bombard Skiff AoE mortar shell hits multiple adjacent slats simultaneously
	var mortar_ammo = load("res://src/data/resources/user_ammo/ammo_heavy_shot.tres") as AmmoData
	assert_test(mortar_ammo != null, "ammo_heavy_shot.tres loads successfully")
	if mortar_ammo:
		assert_test(mortar_ammo.splash_radius >= 3.0, "Mortar ammo splash_radius is >= 3.0m (actual: %.1fm)" % mortar_ammo.splash_radius)
		# Barricade slats are separated by 2.4m (x_points spacing 0.4 * 6.0m = 2.4m)
		var slat_spacing = 2.4
		assert_test(mortar_ammo.splash_radius > slat_spacing, "Mortar splash radius (%.1fm) exceeds slat spacing (%.1fm), hitting multiple adjacent slats" % [mortar_ammo.splash_radius, slat_spacing])

	chunk.queue_free()

func _test_levels_4_through_12() -> void:
	print("\n--- SECTION 3: Campaign Levels 4 through 12 Expansion ---")
	var expected_configs = {
		4: {"biome": "tropical", "chunks": 6, "boss_chunk": "boss_ironjaw", "speed": 8.0},
		5: {"biome": "bayou", "chunks": 6, "boss_chunk": "boss_phantom_dredge", "speed": 8.5},
		6: {"biome": "brimstone", "chunks": 6, "boss_chunk": "boss_siege_fortress", "speed": 9.0},
		7: {"biome": "tropical", "chunks": 7, "boss_chunk": "boss_ironjaw", "speed": 9.0},
		8: {"biome": "bayou", "chunks": 7, "boss_chunk": "boss_phantom_dredge", "speed": 9.5},
		9: {"biome": "brimstone", "chunks": 7, "boss_chunk": "boss_siege_fortress", "speed": 10.0},
		10: {"biome": "tropical", "chunks": 8, "boss_chunk": "boss_ironjaw", "speed": 10.0},
		11: {"biome": "bayou", "chunks": 8, "boss_chunk": "boss_phantom_dredge", "speed": 10.5},
		12: {"biome": "brimstone", "chunks": 8, "boss_chunk": "boss_bonebeard", "speed": 11.0}
	}

	for lvl_id in range(4, 13):
		var path = GameState.LEVEL_RESOURCES.get(lvl_id, "")
		assert_test(path != "", "Level %d is registered in GameState.LEVEL_RESOURCES" % lvl_id)
		assert_test(ResourceLoader.exists(path), "Level %d resource file exists at %s" % [lvl_id, path])

		var lvl_data = load(path) as LevelData
		assert_test(lvl_data != null, "Level %d resource loads as LevelData" % lvl_id)
		if not lvl_data:
			continue

		var cfg = expected_configs[lvl_id]
		assert_test(lvl_data.biome_name == cfg["biome"], "Level %d biome is '%s'" % [lvl_id, cfg["biome"]])
		assert_test(lvl_data.chunk_scenes.size() == cfg["chunks"], "Level %d has %d chunks (actual: %d)" % [lvl_id, cfg["chunks"], lvl_data.chunk_scenes.size()])
		assert_test(lvl_data.base_scroll_speed >= cfg["speed"], "Level %d base scroll speed is >= %.1f (actual: %.1f)" % [lvl_id, cfg["speed"], lvl_data.base_scroll_speed])

		# Verify every chunk instantiates without water plane and has valid markers
		var all_chunks_valid = true
		var has_water_plane = false
		for i in range(lvl_data.chunk_scenes.size()):
			var c_scene = lvl_data.chunk_scenes[i]
			if not c_scene:
				all_chunks_valid = false
				continue
			var c_inst = c_scene.instantiate() as BaseTrackChunk
			if not c_inst or not c_inst.get_node_or_null("ChunkStart") or not c_inst.get_node_or_null("ChunkEnd"):
				all_chunks_valid = false
			if c_inst.find_child("WaterPlane", true, false) != null or c_inst.find_child("WaterSurface", true, false) != null:
				has_water_plane = true
			if i == lvl_data.chunk_scenes.size() - 1:
				assert_test(c_inst.chunk_id == cfg["boss_chunk"], "Level %d final boss chunk is '%s' (actual: '%s')" % [lvl_id, cfg["boss_chunk"], c_inst.chunk_id])
			c_inst.queue_free()

		assert_test(all_chunks_valid, "Level %d: all chunks instantiate cleanly with valid markers" % lvl_id)
		assert_test(not has_water_plane, "Level %d: zero water plane geometry inside individual chunk scenes" % lvl_id)

func _test_river_map_integration() -> void:
	print("\n--- SECTION 4: River Map Integration & Anchoring ---")
	var river_map_scene = load("res://src/ui/river_map.tscn") as PackedScene
	assert_test(river_map_scene != null, "river_map.tscn loads successfully")
	if not river_map_scene:
		return

	var river_map = river_map_scene.instantiate() as RiverMap
	add_child(river_map)

	# Verify MILESTONES has 45 entries
	assert_test(RiverMap.MILESTONES.size() == 45, "RiverMap.MILESTONES contains all 45 campaign levels")
	assert_test(RiverMap.MILESTONES.has(45), "Level 45 is defined in RiverMap.MILESTONES")
	if RiverMap.MILESTONES.has(45):
		assert_test(RiverMap.MILESTONES[45]["is_boss"] == true, "Level 45 has is_boss = true")
		assert_test(RiverMap.MILESTONES[45]["boss_name"] == "Captain Bone-Beard", "Level 45 boss is Captain Bone-Beard")

	# Verify scroll container height and initial anchoring
	var scroll = river_map.get_node_or_null("%ScrollContainer") as ScrollContainer
	var canvas = river_map.get_node_or_null("%MapCanvas") as Control
	assert_test(canvas != null and canvas.custom_minimum_size.y >= 15000.0, "MapCanvas custom_minimum_size height is >= 15,000px (actual: %.1f)" % (canvas.custom_minimum_size.y if canvas else 0.0))

	# Test scroll anchoring: when current selected level is Level 1, scroll_vertical is anchored to Level 1
	river_map._focus_on_level(1, false)
	assert_test(scroll != null and scroll.scroll_vertical > 10000, "Scroll position automatically anchors near bottom for Level 1 (scroll_vertical: %d)" % (scroll.scroll_vertical if scroll else 0))

	# Test scroll anchoring when selecting Level 45: anchors near top
	river_map._focus_on_level(45, false)
	assert_test(scroll != null and scroll.scroll_vertical < 1000, "Scroll position anchors near top for Level 45 (scroll_vertical: %d)" % (scroll.scroll_vertical if scroll else 0))

	river_map.queue_free()
