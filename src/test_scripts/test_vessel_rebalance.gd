@tool
extends Node

# Automated Verification Script for Naval Vessels Rebalance & Multi-Cannon Mechanics

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
	print("  TESTING VESSEL REBALANCE & MULTI-CANNON MECHANICS      ")
	print("========================================================\n")

	# 1. Verify ShipData Resources
	print("\n--- 1. Testing ShipData Resources ---")
	var dinghy_res: ShipData = load("res://src/data/resources/user_vessels/dinghy_ship.tres") as ShipData
	assert_test(dinghy_res != null, "dinghy_ship.tres loads successfully")
	assert_test(dinghy_res.max_health == 2, "Dinghy max_health is 2 HP (fragile starter)")
	assert_test(dinghy_res.move_speed == 10.5, "Dinghy move_speed is 10.5 m/s")

	var sloop_res: ShipData = load("res://src/data/resources/user_vessels/sloop_ship.tres") as ShipData
	assert_test(sloop_res != null, "sloop_ship.tres loads successfully")
	assert_test(sloop_res.max_health == 4, "Sloop max_health is 4 HP")
	assert_test(sloop_res.move_speed == 11.5, "Sloop move_speed is 11.5 m/s (fastest)")
	assert_test(sloop_res.base_cannons == 2, "Sloop base_cannons is 2")
	assert_test(sloop_res.fire_rate == 0.36, "Sloop fire_rate reduced to 0.36s for balanced DPS")

	var ironclad_res: ShipData = load("res://src/data/resources/user_vessels/ironclad_ship.tres") as ShipData
	assert_test(ironclad_res != null, "ironclad_ship.tres loads successfully")
	assert_test(ironclad_res.max_health == 8, "Ironclad max_health is 8 HP (armored brawler)")
	assert_test(ironclad_res.move_speed == 8.5, "Ironclad move_speed is 8.5 m/s (mid-spectrum)")
	assert_test(ironclad_res.base_cannons == 3, "Ironclad base_cannons is 3")

	var bombard_res: ShipData = load("res://src/data/resources/user_vessels/bombard_skiff_ship.tres") as ShipData
	assert_test(bombard_res != null, "bombard_skiff_ship.tres loads successfully")
	assert_test(bombard_res.max_health == 4, "Bombard Skiff max_health is 4 HP")
	assert_test(bombard_res.move_speed == 6.5, "Bombard Skiff move_speed is 6.5 m/s (slowest)")
	assert_test(bombard_res.fire_rate == 1.5, "Bombard Skiff fire_rate is 1.5s")

	# 2. Verify Weapons & Ammo Tuning
	print("\n--- 2. Testing Weapons and Ammo Tuning ---")
	var heavy_shot: AmmoData = load("res://src/data/resources/user_ammo/ammo_heavy_shot.tres") as AmmoData
	assert_test(heavy_shot != null, "ammo_heavy_shot.tres loads successfully")
	assert_test(heavy_shot.damage == 4, "Heavy Shot damage is 4")
	assert_test(heavy_shot.aoe_damage == 2, "Heavy Shot AoE damage tuned to 2")
	assert_test(heavy_shot.splash_radius == 1.6, "Heavy Shot splash radius narrowed to 1.6m single-lane focus")

	var mortar_w: WeaponData = load("res://src/data/resources/user_crew/weapon_bow_mortar.tres") as WeaponData
	assert_test(mortar_w != null, "weapon_bow_mortar.tres loads successfully")
	assert_test(mortar_w.max_range == 18.5, "Heavy Mortar range tuned to 18.5m to reach boss")
	assert_test(mortar_w.fire_rate == 1.5, "Heavy Mortar fire_rate tuned to 1.5s deliberate siege cooldown")

	var ironclad_battery: WeaponData = load("res://src/data/resources/user_crew/weapon_ironclad_battery.tres") as WeaponData
	assert_test(ironclad_battery != null, "weapon_ironclad_battery.tres loads successfully")
	assert_test(ironclad_battery.cannon_count == 3, "Ironclad battery has 3 cannons")
	assert_test(ironclad_battery.max_range == 24.0, "Ironclad battery has 24.0m range")
	assert_test(ironclad_battery.default_ammo != null and ironclad_battery.default_ammo.damage == 2, "Ironclad battery default ammo inflicts 2 damage")

	var sloop_chaser: WeaponData = load("res://src/data/resources/user_crew/weapon_sloop_twin_chaser.tres") as WeaponData
	assert_test(sloop_chaser != null, "weapon_sloop_twin_chaser.tres loads successfully")
	assert_test(sloop_chaser.cannon_count == 2, "Sloop Twin Chasers has 2 cannons")
	assert_test(sloop_chaser.fire_rate == 0.36, "Sloop Twin Chasers fire_rate tuned to 0.36s")
	assert_test(sloop_chaser.max_range == 38.0, "Sloop Twin Chasers has 38.0m long range")

	# 3. Simulate Weapon Volleys in Tree
	print("\n--- 3. Simulating Volley Spawning in Active Tree ---")
	var attached_scene: PackedScene = load("res://src/gameplay/player/attached_weapon.tscn") as PackedScene
	
	# Test Sloop Twin Chaser
	var sloop_weapon_inst: AttachedWeapon = attached_scene.instantiate() as AttachedWeapon
	add_child(sloop_weapon_inst)
	sloop_weapon_inst.setup_weapon(sloop_chaser)
	sloop_weapon_inst.try_fire(sloop_weapon_inst.projectile_scene, self)
	
	var spawned_balls: Array[Node] = []
	for child: Node in get_children():
		if child is Cannonball:
			spawned_balls.append(child)
	
	assert_test(spawned_balls.size() == 2, "Sloop fired exactly 2 parallel cannonballs")
	if spawned_balls.size() == 2:
		var ball0: Cannonball = spawned_balls[0] as Cannonball
		var ball1: Cannonball = spawned_balls[1] as Cannonball
		var lateral_dist: float = absf(ball0.global_position.x - ball1.global_position.x)
		assert_test(lateral_dist > 0.1, "Sloop cannonballs have lateral offset separation: %.2fm" % lateral_dist)

	for b: Node in spawned_balls:
		remove_child(b)
		b.free()
	spawned_balls.clear()
	remove_child(sloop_weapon_inst)
	sloop_weapon_inst.free()

	# Test Ironclad Triple Battery
	var ironclad_weapon_inst: AttachedWeapon = attached_scene.instantiate() as AttachedWeapon
	add_child(ironclad_weapon_inst)
	ironclad_weapon_inst.setup_weapon(ironclad_battery)
	ironclad_weapon_inst.try_fire(ironclad_weapon_inst.projectile_scene, self)

	for child: Node in get_children():
		if child is Cannonball:
			spawned_balls.append(child)

	assert_test(spawned_balls.size() == 3, "Ironclad fired exactly 3 cannonballs in cluster volley")
	if spawned_balls.size() == 3:
		var total_dmg: int = 0
		for b: Node in spawned_balls:
			var cb: Cannonball = b as Cannonball
			total_dmg += cb.damage
		assert_test(total_dmg == 6, "Ironclad triple battery inflicts 6 total forward damage (3x2)")

	for b: Node in spawned_balls:
		remove_child(b)
		b.free()
	remove_child(ironclad_weapon_inst)
	ironclad_weapon_inst.free()

	# 4. Verify Economy & Progression Gating
	print("\n--- 4. Testing Economy & Progression Gating ---")
	assert_test(GameState.VESSEL_CATALOG["sloop"]["purchase_price"] == 400, "Sloop base purchase is accessible at 400 doubloons")
	assert_test(GameState.VESSEL_CATALOG["bombard_skiff"]["purchase_price"] == 800, "Bombard Skiff base purchase is accessible at 800 doubloons")
	assert_test(GameState.VESSEL_CATALOG["ironclad"]["purchase_price"] == 1500, "Ironclad base purchase is accessible at 1500 doubloons")
	assert_test(GameState.get_max_vessel_tier("dinghy") == 3, "Dinghy has max level of 3")
	assert_test(GameState.get_max_vessel_tier("sloop") == 10, "Sloop has max level of 10")
	assert_test(GameState.get_max_vessel_tier("bombard_skiff") == 10, "Bombard Skiff has max level of 10")
	assert_test(GameState.get_max_vessel_tier("ironclad") == 10, "Ironclad has max level of 10")

	# Check exponential upgrade curve
	var sloop_costs: Dictionary = GameState.VESSEL_CATALOG["sloop"]["tier_prices"]
	assert_test(sloop_costs.size() == 9, "Sloop has 9 upgrade tiers (L2-L10)")
	assert_test(sloop_costs[2] == 200, "Sloop L2 upgrade is 200 doubloons")
	assert_test(sloop_costs[5] == 1500, "Sloop L5 upgrade is 1500 doubloons")
	assert_test(sloop_costs[10] == 16000, "Sloop L10 capstone upgrade is 16000 doubloons")

	# Crew progression
	assert_test(GameState.CREW_CATALOG["monkey_bomber"]["unlock_price"] == 350, "Monkey Bomber unlock cost is 350 doubloons")
	assert_test(GameState.get_crew_upgrade_cost("monkey_bomber", 2) == 500, "Monkey Bomber L2 upgrade is 500 doubloons")
	assert_test(GameState.get_crew_upgrade_cost("monkey_bomber", 5) == 5000, "Monkey Bomber L5 upgrade is 5000 doubloons")

	# 5. Verify Mobile Optimizations
	print("\n--- 5. Testing Mobile Optimizations ---")
	var mat_iron1: StandardMaterial3D = Cannonball._get_iron_material()
	var mat_iron2: StandardMaterial3D = Cannonball._get_iron_material()
	assert_test(mat_iron1 == mat_iron2, "Cannonball cast iron material is statically cached and shared")
	var mat_coconut1: StandardMaterial3D = Cannonball._get_coconut_material()
	var mat_coconut2: StandardMaterial3D = Cannonball._get_coconut_material()
	assert_test(mat_coconut1 == mat_coconut2, "Cannonball coconut material is statically cached and shared")
	var mat_fire1: StandardMaterial3D = Cannonball._get_fire_material()
	var mat_fire2: StandardMaterial3D = Cannonball._get_fire_material()
	assert_test(mat_fire1 == mat_fire2, "Cannonball fire material is statically cached and shared")

	var test_cb: Cannonball = Cannonball.new()
	add_child(test_cb)
	test_cb._enable_collisions()
	assert_test(test_cb.collision_mask == 31, "Cannonball collision mask pruned to 31 (layers 1-5)")
	remove_child(test_cb)
	test_cb.free()

	print("\n========================================================")
	print("  TEST RESULTS: %d / %d PASSED" % [passed_count, total_count])
	print("========================================================\n")

	if passed_count == total_count:
		print(">>> ALL TESTS PASSED! <<<")
	else:
		printerr(">>> SOME TESTS FAILED! <<<")

	get_tree().quit(0 if passed_count == total_count else 1)
