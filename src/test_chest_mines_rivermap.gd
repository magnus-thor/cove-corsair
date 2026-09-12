extends Node3D

const ChestPickupScript = preload("res://src/gameplay/collectibles/chest_pickup.gd")
const ChestSpawnMarkerScript = preload("res://src/gameplay/chunks/chest_spawn_marker.gd")

var passed_count: int = 0
var failed_count: int = 0

func assert_test(condition: bool, message: String) -> void:
	if condition:
		passed_count += 1
		print("  [PASS] %s" % message)
	else:
		failed_count += 1
		printerr("  [FAIL] %s" % message)

func _ready() -> void:
	print("==========================================================")
	print("  TESTING RIVER MAP CLICKS, SEA MINES & 3D CHEST PICKUPS  ")
	print("==========================================================")
	
	_test_river_map_button_interceptions()
	_test_sea_mine_detonation_coordinates()
	_test_3d_chest_and_pickup_vfx()
	_test_hazard_pocket_chest_spawners()
	
	print("==========================================================")
	print("  TEST RESULTS: %d PASSED, %d FAILED" % [passed_count, failed_count])
	print("==========================================================")
	if failed_count == 0:
		print(">>> ALL TESTS PASSED SUCCESSFULLY! <<<\n")
		get_tree().quit(0)
	else:
		printerr(">>> SOME TESTS FAILED! <<<\n")
		get_tree().quit(1)

func _test_river_map_button_interceptions() -> void:
	print("\n--- 1. River Map Inner-Button Click Interception ---")
	var river_map_scene = load("res://src/ui/river_map.tscn") as PackedScene
	assert_test(river_map_scene != null, "river_map.tscn loads successfully")
	
	var river_map = river_map_scene.instantiate() as RiverMap
	add_child(river_map)
	
	# Verify MiniVesselIcon mouse filter
	var mini_vessel_icon = river_map.get_node_or_null("%MiniVesselIcon") as TextureRect
	assert_test(mini_vessel_icon != null, "MiniVesselIcon found")
	assert_test(mini_vessel_icon.mouse_filter == Control.MOUSE_FILTER_IGNORE, "MiniVesselIcon mouse_filter is Control.MOUSE_FILTER_IGNORE")
	
	# Verify milestone nodes (test node 1 normal, node 5 boss)
	var nodes_layer = river_map.get_node_or_null("%NodesLayer") as Control
	assert_test(nodes_layer != null, "NodesLayer exists")
	
	var tested_levels = [1, 5, 10, 45]
	for lvl in tested_levels:
		var container = nodes_layer.get_node_or_null("Node_%d" % lvl) as Control
		assert_test(container != null, "Node container for level %d exists" % lvl)
		if not container:
			continue
			
		var touch_btn = container.get_node_or_null("TouchButton") as Button
		assert_test(touch_btn != null, "Level %d TouchButton exists" % lvl)
		assert_test(touch_btn.mouse_filter == Control.MOUSE_FILTER_STOP, "Level %d TouchButton mouse_filter is MOUSE_FILTER_STOP" % lvl)
		assert_test(touch_btn.size.x >= 96 and touch_btn.size.y >= 96, "Level %d TouchButton size covers full diameter (>=96x96)" % lvl)
		
		# Inspect all non-button descendants
		var all_children_ignored = true
		for child in container.get_children():
			if child != touch_btn:
				if not _check_mouse_filter_recursive(child, Control.MOUSE_FILTER_IGNORE):
					all_children_ignored = false
					printerr("    Child %s in Node_%d has interception active!" % [child.name, lvl])
		assert_test(all_children_ignored, "Level %d: all overlapping child nodes set to MOUSE_FILTER_IGNORE" % lvl)
	
	river_map.queue_free()

func _check_mouse_filter_recursive(node: Node, target_mode: Control.MouseFilter) -> bool:
	if node is Control:
		if node.mouse_filter != target_mode:
			return false
	for c in node.get_children():
		if not _check_mouse_filter_recursive(c, target_mode):
			return false
	return true

func _test_sea_mine_detonation_coordinates() -> void:
	print("\n--- 2. Sea Mine Detonation Coordinates ---")
	var mine_scene = load("res://src/gameplay/obstacles/hazard_sea_mine.tscn") as PackedScene
	assert_test(mine_scene != null, "hazard_sea_mine.tscn loads successfully")
	
	var mine = mine_scene.instantiate() as HazardSeaMine
	add_child(mine)
	
	var mine_world_pos = Vector3(3.4, 0.05, -25.0)
	mine.global_position = mine_world_pos
	
	# Verify die() execution
	var vfx_container = get_node_or_null("VFXContainer")
	mine.die()
	assert_test(mine._is_destroyed, "Mine successfully destroyed on die()")
	
	# Verify player collision logic with sea mine
	var player_scene = load("res://src/gameplay/player/player_boat.tscn") as PackedScene
	assert_test(player_scene != null, "player_boat.tscn loads successfully")
	var player = player_scene.instantiate() as Node3D
	add_child(player)
	player.global_position = Vector3(0.0, 0.0, -20.0)
	
	var mine2 = mine_scene.instantiate() as HazardSeaMine
	add_child(mine2)
	mine2.global_position = Vector3(2.5, 0.05, -20.0)
	
	# Simulate player collision
	player._on_area_entered(mine2)
	
	if vfx_container and vfx_container.get_child_count() > 0:
		var last_effect2 = vfx_container.get_child(vfx_container.get_child_count() - 1) as Node3D
		assert_test(last_effect2.global_position.x > 1.5, "Explosion spawned at sea mine coordinate (X=2.5), NOT at player vessel center (X=0.0): %s" % str(last_effect2.global_position))
		
	player.queue_free()

func _test_3d_chest_and_pickup_vfx() -> void:
	print("\n--- 3. 3D Treasure Chest & Pickup VFX ---")
	var chest_scene = load("res://src/gameplay/collectibles/collectible_chest.tscn") as PackedScene
	assert_test(chest_scene != null, "collectible_chest.tscn loads successfully")
	
	var chest = chest_scene.instantiate() as CollectibleChest
	add_child(chest)
	
	# Verify 3D Model presence and absence of 2D billboard sprite
	var visuals = chest.get_node_or_null("Visuals")
	assert_test(visuals != null, "Chest has Visuals container")
	var sprite = visuals.get_node_or_null("ChestSprite")
	assert_test(sprite == null, "2D billboard sprite has been removed")
	var model = visuals.get_node_or_null("ChestModel")
	assert_test(model != null, "3D chest model (ChestModel) is present")
	assert_test(model.scale.x >= 0.7 and model.scale.x <= 0.8, "Chest 3D model scaled ~0.7x - 0.8x (actual: %s)" % str(model.scale))
	assert_test(is_equal_approx(model.position.y, 0.05), "Chest 3D model Y position aligned at 0.05m")
	
	# Verify ChestPickup alias
	var pickup_scene = load("res://src/gameplay/collectibles/chest_pickup.tscn") as PackedScene
	assert_test(pickup_scene != null, "chest_pickup.tscn loads successfully")
	var pickup = pickup_scene.instantiate()
	assert_test(pickup != null, "chest_pickup instantiates as ChestPickup")
	pickup.queue_free()
	
	# Verify Pickup Juice on collection
	var prev_gold = GameState.doubloons
	var chest_target_pos = Vector3(1.5, 0.05, -10.0)
	chest.global_position = chest_target_pos
	chest.chest_value = 25
	
	chest.collect_chest()
	
	# Verify economy addition
	assert_test(GameState.doubloons == prev_gold + 25, "GameState.add_doubloons(25) successfully added +25 doubloons")
	
	# Verify floating Label3D spawned
	var found_label = false
	for child in get_children():
		if child is Label3D:
			found_label = true
			var l = child as Label3D
			assert_test(l.text == "+25 GOLD", "Floating Label3D text matches '+25 GOLD' (actual: %s)" % l.text)
			assert_test(l.billboard == BaseMaterial3D.BILLBOARD_ENABLED, "Floating Label3D is billboarded to camera")
			assert_test(l.modulate.to_html(false).to_upper() == "F5D061", "Floating Label3D text color is Radiant Gold (#F5D061)")
			break
	assert_test(found_label, "Floating Label3D score popup was spawned into world tree")
	
	# Verify coin burst VFX
	var vfx_container = get_node_or_null("VFXContainer")
	assert_test(vfx_container != null and vfx_container.get_child_count() > 0, "Coin burst VFX spawned into VFXContainer")
	if vfx_container:
		var has_coin_burst = false
		for effect in vfx_container.get_children():
			if effect.name.begins_with("VFXCoinBurst"):
				has_coin_burst = true
				break
		assert_test(has_coin_burst, "VFXCoinBurst CPUParticles3D instantiated")

func _test_hazard_pocket_chest_spawners() -> void:
	print("\n--- 4. Risk/Reward Chest Placement in Chunks ---")
	var gauntlet_scene = load("res://src/gameplay/chunks/chunk_mine_gauntlet.tscn") as PackedScene
	assert_test(gauntlet_scene != null, "chunk_mine_gauntlet.tscn loads")
	var gauntlet = gauntlet_scene.instantiate() as BaseTrackChunk
	add_child(gauntlet)
	
	var g_entities = gauntlet.get_node_or_null("Entities")
	assert_test(g_entities != null, "chunk_mine_gauntlet has Entities container")
	
	var marker_left = g_entities.get_node_or_null("ChestSpawnMarker_HazardLeft") as Marker3D
	var marker_right = g_entities.get_node_or_null("ChestSpawnMarker_HazardRight") as Marker3D
	assert_test(marker_left != null, "Found ChestSpawnMarker_HazardLeft at X = -3.4m")
	assert_test(marker_right != null, "Found ChestSpawnMarker_HazardRight at X = +3.4m")
	if marker_left:
		assert_test(marker_left.chest_value == 15, "Marker left chest_value is 15")
		assert_test(is_equal_approx(abs(marker_left.position.x), 3.4), "Marker left X is at ±3.4m")
	if marker_right:
		assert_test(marker_right.chest_value == 20, "Marker right chest_value is 20")
		assert_test(is_equal_approx(abs(marker_right.position.x), 3.4), "Marker right X is at ±3.4m")
		
	# Verify chunk_barricade_siege hazard flank marker
	var siege_scene = load("res://src/gameplay/chunks/chunk_barricade_siege.tscn") as PackedScene
	assert_test(siege_scene != null, "chunk_barricade_siege.tscn loads")
	var siege = siege_scene.instantiate() as BaseTrackChunk
	add_child(siege)
	
	var s_entities = siege.get_node_or_null("Entities")
	assert_test(s_entities != null, "chunk_barricade_siege has Entities container")
	var siege_flank = s_entities.get_node_or_null("ChestSpawnMarker_HazardFlank") as Marker3D
	assert_test(siege_flank != null, "Found ChestSpawnMarker_HazardFlank in chunk_barricade_siege")
	if siege_flank:
		assert_test(is_equal_approx(abs(siege_flank.position.x), 3.4), "Siege flank marker X is at ±3.4m")
		assert_test(siege_flank.chest_value == 15, "Siege flank marker chest_value is 15")
		
	# Verify min_level behavior:
	# At Level 1 (early level 1-5), marker does NOT spawn hazard chest
	GameState.current_level = 1
	marker_left.spawn()
	assert_test(g_entities.get_node_or_null("CollectibleChest") == null, "Level 1: Hazard pocket chest does not spawn early (center lane chest reserved)")
	
	# At Level 6 (mid/late level), marker spawns hazard chest
	GameState.current_level = 6
	marker_right.spawn()
	var spawned_chest = null
	for child in g_entities.get_children():
		if child is CollectibleChest:
			spawned_chest = child
			break
	assert_test(spawned_chest != null, "Level 6: Hazard pocket chest spawned successfully")
	if spawned_chest:
		assert_test(spawned_chest.chest_value == 20, "Spawned hazard pocket chest carries calibrated value (20 coins)")
		
	gauntlet.queue_free()
	siege.queue_free()
