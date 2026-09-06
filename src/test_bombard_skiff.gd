extends Node

var passed_count: int = 0
var total_count: int = 0

func assert_test(condition: bool, test_name: String) -> void:
	total_count += 1
	if condition:
		passed_count += 1
		print("[PASS] " + test_name)
	else:
		printerr("[FAIL] " + test_name)
		push_error("Assertion failed: " + test_name)

func _ready() -> void:
	print("\n========================================================")
	print("  STARTING BOMBARD SKIFF & SCATTERSHOT INTEGRATION TESTS  ")
	print("========================================================\n")

	# --- TEST 1: Resource Loading ---
	print("\n--- 1. Testing Resource Loading ---")
	var ship_res: ShipData = load("res://src/data/resources/user_vessels/bombard_skiff_ship.tres") as ShipData
	assert_test(ship_res != null, "bombard_skiff_ship.tres loads successfully as ShipData")
	assert_test(ship_res.ship_id == "bombard_skiff", "ship_id is 'bombard_skiff'")
	assert_test(ship_res.max_health == 3, "max_health is 3 (max_hull_hp)")
	assert_test(ship_res.move_speed == 9.0, "move_speed is 9.0 (lateral_speed)")
	assert_test(ship_res.fire_rate == 1.3, "fire_rate is 1.3 (base_fire_rate)")
	assert_test(ship_res.collision_size == Vector3(1.8, 1.2, 3.0), "collision_size is Vector3(1.8, 1.2, 3.0)")
	assert_test(ship_res.model_scene != null, "model_scene is assigned")
	assert_test(ship_res.upgrade_costs == [800, 500, 1000], "upgrade_costs are [800, 500, 1000]")
	assert_test(ship_res.tier_sockets.size() == 3, "tier_sockets has 3 tiers configured")

	var scatter_res: WeaponData = load("res://src/data/resources/user_crew/weapon_scattershot.tres") as WeaponData
	assert_test(scatter_res != null, "weapon_scattershot.tres loads successfully")
	assert_test(scatter_res.weapon_type == "scattershot", "weapon_type is 'scattershot'")
	assert_test(scatter_res.is_scatter == true, "is_scatter flag is true")
	assert_test(scatter_res.pellet_count == 5, "pellet_count is 5")
	assert_test(scatter_res.scatter_spread_deg == 30.0, "scatter_spread_deg is 30.0 (-15 deg to +15 deg)")
	assert_test(scatter_res.max_range <= 14.0 and scatter_res.max_range >= 12.0, "max_range capped to 12-14m")
	assert_test(scatter_res.model_scene != null, "scattershot model_scene is assigned")

	var pellet_ammo: AmmoData = load("res://src/data/resources/user_ammo/ammo_scatter_pellet.tres") as AmmoData
	assert_test(pellet_ammo != null, "ammo_scatter_pellet.tres loads successfully")
	assert_test(pellet_ammo.damage >= 2, "pellet base damage is high (>= 2)")
	assert_test(pellet_ammo.projectile_speed >= 25.0, "pellet speed is rapid (>= 25.0)")

	var mortar_res: WeaponData = load("res://src/data/resources/user_crew/weapon_bow_mortar.tres") as WeaponData
	assert_test(mortar_res != null, "weapon_bow_mortar.tres loads successfully")
	assert_test(mortar_res.default_ammo != null and mortar_res.default_ammo.splash_radius > 0.0, "mortar ammo has AoE splash radius > 0")

	# --- TEST 2: GameState & Shipyard Registration ---
	print("\n--- 2. Testing GameState & Shipyard Catalog ---")
	assert_test(GameState.VESSEL_CATALOG.has("bombard_skiff"), "VESSEL_CATALOG has 'bombard_skiff'")
	var cat_entry = GameState.VESSEL_CATALOG.get("bombard_skiff", {})
	assert_test(cat_entry.get("purchase_price") == 800, "purchase_price in catalog is 800")
	assert_test(cat_entry.get("tier_prices", {}).get(2) == 500, "tier 2 price is 500")
	assert_test(cat_entry.get("tier_prices", {}).get(3) == 1000, "tier 3 price is 1000")

	# Test purchasing and upgrading logic
	GameState.doubloons = 5000
	if not GameState.is_vessel_owned("bombard_skiff"):
		var buy_ok = GameState.buy_vessel("bombard_skiff")
		assert_test(buy_ok, "buy_vessel('bombard_skiff') succeeds with sufficient funds")
	assert_test(GameState.is_vessel_owned("bombard_skiff"), "bombard_skiff is now owned")
	assert_test(GameState.vessel_tiers.has("bombard_skiff"), "vessel_tiers contains 'bombard_skiff'")
	
	GameState.vessel_tiers["bombard_skiff"] = 1
	var up2_ok = GameState.upgrade_vessel_tier("bombard_skiff")
	assert_test(up2_ok and GameState.get_vessel_tier("bombard_skiff") == 2, "upgrade to Tier 2 succeeds")
	
	var up3_ok = GameState.upgrade_vessel_tier("bombard_skiff")
	assert_test(up3_ok and GameState.get_vessel_tier("bombard_skiff") == 3, "upgrade to Tier 3 succeeds")

	var equip_ok = GameState.equip_vessel("bombard_skiff")
	assert_test(equip_ok and GameState.active_vessel == "bombard_skiff", "equip_vessel('bombard_skiff') succeeds")

	# --- TEST 3: Boat Sockets & Tier 1 Heavy Mortar ---
	print("\n--- 3. Testing Boat Prefab Sockets & Tier 1 Mortar ---")
	var boat_scene = load("res://src/gameplay/player/player_boat.tscn")
	var boat = boat_scene.instantiate()
	add_child(boat)
	
	boat.apply_ship_data(ship_res)
	boat.apply_tier(1)

	assert_test(boat.equipped_weapons.has("BowMortarMount"), "Tier 1 equips 'BowMortarMount'")
	assert_test(!boat.equipped_weapons.has("QuarterdeckCrew"), "Tier 1 does NOT equip 'QuarterdeckCrew'")
	assert_test(!boat.equipped_weapons.has("PortRailMount"), "Tier 1 does NOT equip 'PortRailMount'")
	assert_test(!boat.equipped_weapons.has("StarboardRailMount"), "Tier 1 does NOT equip 'StarboardRailMount'")

	# Test firing Tier 1 Heavy Mortar
	var bow_mortar: AttachedWeapon = boat.equipped_weapons.get("BowMortarMount")
	assert_test(bow_mortar != null, "BowMortarMount weapon instance is valid")
	
	var world_node = Node3D.new()
	world_node.name = "WorldContainer"
	add_child(world_node)

	bow_mortar.projectile_scene = load("res://src/gameplay/projectiles/cannonball.tscn")
	bow_mortar._execute_fire(bow_mortar.projectile_scene, world_node)
	
	var mortar_balls = []
	for child in world_node.get_children():
		if child is Cannonball:
			mortar_balls.append(child)
			
	assert_test(mortar_balls.size() == 1, "BowMortarMount fired exactly 1 heavy mortar ball")
	if mortar_balls.size() > 0:
		var ball: Cannonball = mortar_balls[0]
		assert_test(ball.damage == 3, "Heavy mortar deals 3 base damage")
		assert_test(ball.arc_height >= 2.0, "Heavy mortar has high arc trajectory")
		assert_test(ball.ammo_data != null and ball.ammo_data.splash_radius >= 2.0, "Heavy mortar has 2.0m AoE splash radius")
		print("DEBUG: mortar ball dir = ", ball.direction)
		assert_test(ball.direction.z < -0.9, "Heavy mortar fires directly forward along Z-axis")
		ball.queue_free()

	# --- TEST 4: Tier 3 Full Battery & Scattershot Fan Spread ---
	print("\n--- 4. Testing Tier 3 Battery & Scattershot Carronades ---")
	boat.apply_tier(3)
	assert_test(boat.equipped_weapons.has("BowMortarMount"), "Tier 3 has 'BowMortarMount'")
	assert_test(boat.equipped_weapons.has("QuarterdeckCrew"), "Tier 3 has 'QuarterdeckCrew'")
	assert_test(boat.equipped_weapons.has("PortRailMount"), "Tier 3 has 'PortRailMount'")
	assert_test(boat.equipped_weapons.has("StarboardRailMount"), "Tier 3 has 'StarboardRailMount'")

	var port_w: AttachedWeapon = boat.equipped_weapons.get("PortRailMount")
	var stbd_w: AttachedWeapon = boat.equipped_weapons.get("StarboardRailMount")
	assert_test(port_w != null and port_w.weapon_data == scatter_res, "PortRailMount is equipped with Scattershot Carronade")
	assert_test(stbd_w != null and stbd_w.weapon_data == scatter_res, "StarboardRailMount is equipped with Scattershot Carronade")

	# Test Port Rail Scattershot firing
	for child in world_node.get_children():
		world_node.remove_child(child)
		child.free()

	port_w.projectile_scene = load("res://src/gameplay/projectiles/cannonball.tscn")
	port_w._execute_fire(port_w.projectile_scene, world_node)

	var port_pellets: Array = []
	for child in world_node.get_children():
		if child is Cannonball:
			port_pellets.append(child)

	assert_test(port_pellets.size() == 5, "PortRailMount instantiated exactly 5 pellet projectiles")
	if port_pellets.size() == 5:
		var all_short_range = true
		var all_high_dmg = true
		var all_rapid_speed = true
		var angles_deg: Array[float] = []
		
		for p in port_pellets:
			if p.max_range > 14.0 or p.max_range < 12.0:
				all_short_range = false
			if p.damage < 2:
				all_high_dmg = false
			if p.speed < 25.0:
				all_rapid_speed = false
			var yaw = rad_to_deg(atan2(p.direction.x, -p.direction.z))
			angles_deg.append(yaw)
			
		assert_test(all_short_range, "All 5 pellets have range capped to ~12-14m")
		assert_test(all_high_dmg, "All 5 pellets deal high point-blank damage (>= 2 each, 10 burst total)")
		assert_test(all_rapid_speed, "All 5 pellets travel at rapid speed (>= 25.0 m/s)")
		
		angles_deg.sort()
		var total_spread = angles_deg.back() - angles_deg.front()
		assert_test(abs(total_spread - 30.0) < 1.0, "Pellets span a 30-degree fan spread (-15 to +15 deg)")
		assert_test(port_pellets[0].direction.x < 0.0, "Port pellets fire into the adjacent PORT (left) lane")

	# Test Starboard Rail Scattershot firing
	for child in world_node.get_children():
		world_node.remove_child(child)
		child.free()

	stbd_w.projectile_scene = load("res://src/gameplay/projectiles/cannonball.tscn")
	stbd_w._execute_fire(stbd_w.projectile_scene, world_node)

	var stbd_pellets: Array = []
	for child in world_node.get_children():
		if child is Cannonball:
			stbd_pellets.append(child)

	assert_test(stbd_pellets.size() == 5, "StarboardRailMount instantiated exactly 5 pellet projectiles")
	if stbd_pellets.size() == 5:
		assert_test(stbd_pellets[0].direction.x > 0.0, "Starboard pellets fire into the adjacent STARBOARD (right) lane")

	# Clean up
	boat.queue_free()
	world_node.queue_free()

	print("\n========================================================")
	print("  TEST RESULTS: %d / %d PASSED  " % [passed_count, total_count])
	print("========================================================\n")
	
	if passed_count == total_count:
		print(">>> ALL INTEGRATION TESTS PASSED SUCCESSFULLY! <<<\n")
		get_tree().quit(0)
	else:
		printerr(">>> SOME TESTS FAILED! <<<\n")
		get_tree().quit(1)
