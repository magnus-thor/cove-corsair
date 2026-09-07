extends Node

## Comprehensive Headless Test Suite for Campaign Expansion
## Tests Vessel Economics, Levels 1-45 Resources, Tactical Bottlenecks,
## Chunk Assembler Lifecycle, and River Map 15,000px Expansion.

const ChunkAssemblerScript = preload("res://src/gameplay/world/chunk_assembler.gd")

func _ready() -> void:
	print("==================================================")
	print("   STARTING CAMPAIGN EXPANSION TEST SUITE         ")
	print("==================================================")
	
	test_vessel_economics()
	test_all_45_level_resources()
	test_tactical_bottlenecks_and_milestones()
	test_chunk_assembler_samples()
	test_river_map_expansion()
	
	print("==================================================")
	print("   ALL CAMPAIGN EXPANSION TESTS PASSED!           ")
	print("==================================================")
	get_tree().quit(0)

func test_vessel_economics() -> void:
	print("\n--- TEST 1: Calibrated Vessel Economics ---")
	
	var expected_economics = {
		"dinghy": {
			"res_path": "res://src/data/resources/user_vessels/dinghy_ship.tres",
			"unlock": 0,
			"costs": [0, 300, 750],
			"tier_prices": {2: 300, 3: 750}
		},
		"sloop": {
			"res_path": "res://src/data/resources/user_vessels/sloop_ship.tres",
			"unlock": 600,
			"costs": [600, 800, 1500],
			"tier_prices": {2: 800, 3: 1500}
		},
		"bombard_skiff": {
			"res_path": "res://src/data/resources/user_vessels/bombard_skiff_ship.tres",
			"unlock": 1000,
			"costs": [1000, 1200, 2200],
			"tier_prices": {2: 1200, 3: 2200}
		},
		"ironclad": {
			"res_path": "res://src/data/resources/user_vessels/ironclad_ship.tres",
			"unlock": 1400,
			"costs": [1400, 1800, 3000],
			"tier_prices": {2: 1800, 3: 3000}
		}
	}
	
	for v_id in expected_economics:
		var exp = expected_economics[v_id]
		# 1. Check ShipData resource
		var ship_res = load(exp["res_path"]) as ShipData
		assert(ship_res != null, "ShipData resource must exist for %s" % v_id)
		var exp_costs: Array = exp["costs"]
		assert(ship_res.upgrade_costs.size() == exp_costs.size(), "%s upgrade_costs size mismatch" % v_id)
		for c_i in range(exp_costs.size()):
			assert(ship_res.upgrade_costs[c_i] == exp_costs[c_i], "%s upgrade_cost[%d] mismatch" % [v_id, c_i])
		
		# 2. Check GameState.VESSEL_CATALOG
		assert(GameState.VESSEL_CATALOG.has(v_id), "Catalog must contain %s" % v_id)
		var cat = GameState.VESSEL_CATALOG[v_id]
		assert(cat["purchase_price"] == exp["unlock"], 
			"%s unlock price mismatch: expected %d, got %d" % [v_id, exp["unlock"], cat["purchase_price"]])
		for tier in exp["tier_prices"]:
			assert(cat["tier_prices"].get(tier) == exp["tier_prices"][tier],
				"%s tier %d price mismatch" % [v_id, tier])
				
		# 3. Check GameState.get_upgrade_cost helper
		for t_idx in range(1, 4):
			var expected_cost = exp["costs"][t_idx - 1]
			var actual_cost = GameState.get_upgrade_cost(v_id, t_idx)
			assert(actual_cost == expected_cost, 
				"%s get_upgrade_cost(%d) mismatch: expected %d, got %d" % [v_id, t_idx, expected_cost, actual_cost])
				
		print("[PASS] %s economics calibrated (Unlock: %d, T2: %d, T3: %d)" % [
			v_id, exp["unlock"], exp["costs"][1], exp["costs"][2]
		])

func test_all_45_level_resources() -> void:
	print("\n--- TEST 2: All 45 Level Resources Loading & Schema ---")
	assert(GameState.LEVEL_RESOURCES.size() == 45, "GameState.LEVEL_RESOURCES must contain 45 levels")
	assert(GameState.LEVEL_SHIPS.size() == 45, "GameState.LEVEL_SHIPS must contain 45 level ship hints")
	
	for lvl in range(1, 46):
		var res_path = GameState.LEVEL_RESOURCES.get(lvl, "")
		assert(res_path != "", "Level %d path must be registered in GameState" % lvl)
		assert(ResourceLoader.exists(res_path), "File must exist: %s" % res_path)
		
		var lvl_res = load(res_path) as LevelData
		assert(lvl_res != null, "Level %d must load as LevelData" % lvl)
		assert(lvl_res.level_id == lvl, "Level %d level_id mismatch (got %d)" % [lvl, lvl_res.level_id])
		assert(lvl_res.chunk_scenes.size() >= 5, "Level %d must have at least 5 chunks" % lvl)
		assert(lvl_res.base_scroll_speed >= 7.0, "Level %d speed must be >= 7.0" % lvl)
		assert(lvl_res.completion_doubloon_reward >= 150, "Level %d doubloon reward must be >= 150" % lvl)
		assert(lvl_res.water_albedo != Color.BLACK, "Level %d water_albedo must be configured" % lvl)
		assert(lvl_res.biome_name in ["tropical", "bayou", "brimstone"], "Level %d invalid biome: %s" % [lvl, lvl_res.biome_name])
		
		# Verify all chunk packed scenes in this level load properly
		for c_idx in range(lvl_res.chunk_scenes.size()):
			var chunk_ps = lvl_res.chunk_scenes[c_idx]
			assert(chunk_ps != null, "Level %d chunk %d PackedScene is null!" % [lvl, c_idx])
			
		# Verify tactical ship pairing hint exists and loads
		var ship_path = GameState.LEVEL_SHIPS.get(lvl, "")
		assert(ship_path != "", "Level %d ship hint path must exist" % lvl)
		assert(ResourceLoader.exists(ship_path), "Ship hint file must exist: %s" % ship_path)
		
	print("[PASS] All 45 LevelData resources and ship pairing hints verified without missing references.")

func test_tactical_bottlenecks_and_milestones() -> void:
	print("\n--- TEST 3: Tactical Bottlenecks & Milestone Bosses ---")
	
	# Tactical Bottleneck L16: "The Iron Wall"
	var l16 = load(GameState.LEVEL_RESOURCES[16]) as LevelData
	assert("The Iron Wall" in l16.level_title, "L16 title must be 'The Iron Wall'")
	assert(l16.biome_name == "bayou", "L16 must be bayou biome")
	assert(l16.chunk_scenes.size() == 7, "L16 must have 7 chunks")
	# Count barricade chunks in L16 (should be heavy barricades: at least 5 out of 7)
	var l16_barricades = 0
	for c in l16.chunk_scenes:
		if "barricade" in c.resource_path:
			l16_barricades += 1
	assert(l16_barricades >= 5, "L16 must have heavy barricade clusters (got %d)" % l16_barricades)
	print("[PASS] Bottleneck L16 'The Iron Wall' verified (%d barricade chunks)." % l16_barricades)
	
	# Tactical Bottleneck L19: "Devil's Slalom"
	var l19 = load(GameState.LEVEL_RESOURCES[19]) as LevelData
	assert("Devil's Slalom" in l19.level_title, "L19 title must be 'Devil's Slalom'")
	assert(l19.biome_name == "bayou", "L19 must be bayou biome")
	assert(l19.chunk_scenes.size() == 8, "L19 must have 8 chunks")
	# Count mine chunks in L19 (should be dense mine gauntlet: at least 5 out of 8)
	var l19_mines = 0
	for c in l19.chunk_scenes:
		if "mine" in c.resource_path:
			l19_mines += 1
	assert(l19_mines >= 5, "L19 must have dense mine gauntlet (got %d)" % l19_mines)
	print("[PASS] Bottleneck L19 'Devil's Slalom' verified (%d mine chunks)." % l19_mines)
	
	# Milestone Bosses: 15, 20, 25, 30, 35, 40, 45
	var milestone_boss_expectations = {
		15: "chunk_boss_bonebeard",
		20: "chunk_boss_siege_fortress",
		25: "chunk_boss_phantom_dredge",
		30: "chunk_boss_bonebeard",
		35: "chunk_boss_ironjaw",
		40: "chunk_boss_siege_fortress",
		45: "chunk_boss_bonebeard"
	}
	
	for mb_lvl in milestone_boss_expectations:
		var expected_boss = milestone_boss_expectations[mb_lvl]
		var mb_res = load(GameState.LEVEL_RESOURCES[mb_lvl]) as LevelData
		var final_chunk = mb_res.chunk_scenes[mb_res.chunk_scenes.size() - 1]
		assert(expected_boss in final_chunk.resource_path, 
			"Level %d final chunk must be %s (got %s)" % [mb_lvl, expected_boss, final_chunk.resource_path])
		print("[PASS] Milestone L%02d boss verified: %s" % [mb_lvl, expected_boss])

func test_chunk_assembler_samples() -> void:
	print("\n--- TEST 4: Chunk Assembler Sample Instantiations (L1, L16, L30, L45) ---")
	var test_levels = [1, 16, 30, 45]
	
	for lvl in test_levels:
		var assembler = ChunkAssemblerScript.new()
		add_child(assembler)
		
		var lvl_res = load(GameState.LEVEL_RESOURCES[lvl]) as LevelData
		assembler.assemble_level(lvl_res)
		
		assert(assembler.active_chunks.size() == lvl_res.chunk_scenes.size(), 
			"Level %d assembled chunk count mismatch" % lvl)
		
		var expected_z = 0.0
		for i in range(assembler.active_chunks.size()):
			var chunk = assembler.active_chunks[i]
			assert(is_equal_approx(chunk.position.z, expected_z), 
				"L%d Chunk %d Z alignment error: expected %.1f, got %.1f" % [lvl, i, expected_z, chunk.position.z])
			expected_z -= 50.0
			
		var expected_total_dist: float = 0.0
		for chunk in assembler.active_chunks:
			if not chunk.is_boss_chunk:
				expected_total_dist += 50.0
		assert(is_equal_approx(assembler.total_track_distance, expected_total_dist),
			"L%d total distance mismatch: expected %.1f, got %.1f" % [lvl, expected_total_dist, assembler.total_track_distance])
			
		print("[PASS] Level %d instantiated: %d chunks, total dist %.1fm, seamless Z alignment." % [
			lvl, assembler.active_chunks.size(), assembler.total_track_distance
		])
		
		assembler.queue_free()

func test_river_map_expansion() -> void:
	print("\n--- TEST 5: River Map 15,000px Expansion & Boss Emblems ---")
	var river_scene = load("res://src/ui/river_map.tscn") as PackedScene
	assert(river_scene != null, "river_map.tscn must load")
	
	var river_map = river_scene.instantiate() as RiverMap
	add_child(river_map)
	
	# Verify Canvas Height
	var map_canvas = river_map.get_node("%MapCanvas") as Control
	var terrain_layer = river_map.get_node("%TerrainLayer") as Control
	var river_path_layer = river_map.get_node("%RiverPathLayer") as Control
	var nodes_layer = river_map.get_node("%NodesLayer") as Control
	
	assert(map_canvas.custom_minimum_size.y == 15000.0, "MapCanvas must be 15,000px height")
	assert(terrain_layer.custom_minimum_size.y == 15000.0, "TerrainLayer must be 15,000px height")
	assert(river_path_layer.custom_minimum_size.y == 15000.0, "RiverPathLayer must be 15,000px height")
	assert(nodes_layer.custom_minimum_size.y == 15000.0, "NodesLayer must be 15,000px height")
	print("[PASS] 15,000px Canvas and Layers measured.")
	
	# Verify 45 Milestone Nodes
	assert(river_map.MILESTONES.size() == 45, "RiverMap must compute 45 milestones")
	assert(river_map.node_controls.size() == 45, "RiverMap must build 45 node buttons")
	
	# Verify Spline Path Length spans harbor to peak
	var baked_len = river_map.river_curve.get_baked_length()
	assert(baked_len > 14000.0, "River spline length must be > 14,000px (got %.1f)" % baked_len)
	print("[PASS] Continuous 45-node river spline computed (length: %.1fpx)." % baked_len)
	
	# Verify Boss Emblems on nodes 5, 10, 15, 20, 25, 30, 35, 40, 45
	var boss_node_indices = [5, 10, 15, 20, 25, 30, 35, 40, 45]
	for b_lvl in boss_node_indices:
		var node_ctrl = river_map.node_controls.get(b_lvl)
		assert(node_ctrl != null, "Node %d must exist" % b_lvl)
		var banner = node_ctrl.find_child("BossBanner", true, false)
		assert(banner != null, "Node %d must display BossBanner emblem" % b_lvl)
	print("[PASS] Distinct boss emblems verified on nodes 5, 10, 15, 20, 25, 30, 35, 40, 45.")
	
	# Verify non-boss nodes do NOT have boss banner
	for nb_lvl in [1, 2, 7, 16, 19, 31]:
		var node_ctrl = river_map.node_controls.get(nb_lvl)
		var banner = node_ctrl.find_child("BossBanner", true, false)
		assert(banner == null, "Node %d should not have a BossBanner" % nb_lvl)
	print("[PASS] Non-boss nodes confirmed without boss banner.")
	
	# Verify Scroll Anchoring computation across low, mid, and late game
	var scroll_container = river_map.get_node("%ScrollContainer") as ScrollContainer
	var viewport_h = scroll_container.size.y
	if viewport_h <= 0:
		viewport_h = 1000.0
	var canvas_h = 15000.0
	var max_scroll = int(canvas_h - viewport_h)
	
	# Level 1 (bottom): Y=14500, target scroll clamped to max_scroll
	var expected_l1 = clamp(int(14500.0 - viewport_h * 0.5), 0, max_scroll)
	river_map._focus_on_level(1, false)
	assert(river_map.scroll_container.scroll_vertical == expected_l1, 
		"L1 scroll anchoring mismatch: expected %d, got %d" % [expected_l1, river_map.scroll_container.scroll_vertical])
		
	# Level 45 (top peak): Y=500, target scroll = 500 - viewport_h/2 (clamped to 0)
	var expected_l45 = clamp(int(500.0 - viewport_h * 0.5), 0, max_scroll)
	river_map._focus_on_level(45, false)
	assert(river_map.scroll_container.scroll_vertical == expected_l45, 
		"L45 scroll anchoring mismatch: expected %d, got %d" % [expected_l45, river_map.scroll_container.scroll_vertical])
		
	# Level 16 (mid-low): Y ~ 9727 -> target scroll in [8000, 10000]
	river_map._focus_on_level(16, false)
	assert(river_map.scroll_container.scroll_vertical > 7500 and river_map.scroll_container.scroll_vertical < 10500,
		"L16 scroll anchoring in mid-range")
		
	# Level 30 (mid-high): Y ~ 5272 -> target scroll in [4000, 5500]
	river_map._focus_on_level(30, false)
	assert(river_map.scroll_container.scroll_vertical > 3500 and river_map.scroll_container.scroll_vertical < 6000,
		"L30 scroll anchoring in mid-high range")
		
	print("[PASS] Scroll anchoring verified across Low (L1), Mid (L16, L30), and Late (L45) nodes.")
	
	river_map.queue_free()
