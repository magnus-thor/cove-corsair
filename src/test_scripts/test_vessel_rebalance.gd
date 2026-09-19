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

	var ironclad_res: ShipData = load("res://src/data/resources/user_vessels/ironclad_ship.tres") as ShipData
	assert_test(ironclad_res != null, "ironclad_ship.tres loads successfully")
	assert_test(ironclad_res.max_health == 8, "Ironclad max_health is 8 HP (armored brawler)")
	assert_test(ironclad_res.move_speed == 8.5, "Ironclad move_speed is 8.5 m/s (mid-spectrum)")
	assert_test(ironclad_res.base_cannons == 3, "Ironclad base_cannons is 3")

	var bombard_res: ShipData = load("res://src/data/resources/user_vessels/bombard_skiff_ship.tres") as ShipData
	assert_test(bombard_res != null, "bombard_skiff_ship.tres loads successfully")
	assert_test(bombard_res.max_health == 4, "Bombard Skiff max_health is 4 HP")
	assert_test(bombard_res.move_speed == 6.5, "Bombard Skiff move_speed is 6.5 m/s (slowest)")

	# 2. Verify Weapons & Ammo Tuning
	print("\n--- 2. Testing Weapons and Ammo Tuning ---")
	var heavy_shot: AmmoData = load("res://src/data/resources/user_ammo/ammo_heavy_shot.tres") as AmmoData
	assert_test(heavy_shot != null, "ammo_heavy_shot.tres loads successfully")
	assert_test(heavy_shot.damage == 4, "Heavy Shot damage reduced from 8 to 4")
	assert_test(heavy_shot.aoe_damage == 3, "Heavy Shot AoE damage reduced from 5 to 3")
	assert_test(heavy_shot.splash_radius == 3.2, "Heavy Shot splash radius reduced to 3.2m")

	var mortar_w: WeaponData = load("res://src/data/resources/user_crew/weapon_bow_mortar.tres") as WeaponData
	assert_test(mortar_w != null, "weapon_bow_mortar.tres loads successfully")
	assert_test(mortar_w.max_range == 13.0, "Heavy Mortar range reduced to short-range 13.0m")

	var ironclad_battery: WeaponData = load("res://src/data/resources/user_crew/weapon_ironclad_battery.tres") as WeaponData
	assert_test(ironclad_battery != null, "weapon_ironclad_battery.tres loads successfully")
	assert_test(ironclad_battery.cannon_count == 3, "Ironclad battery has 3 cannons")
	assert_test(ironclad_battery.max_range == 24.0, "Ironclad battery has 24.0m range")
	assert_test(ironclad_battery.default_ammo != null and ironclad_battery.default_ammo.damage == 2, "Ironclad battery default ammo inflicts 2 damage")

	var sloop_chaser: WeaponData = load("res://src/data/resources/user_crew/weapon_sloop_twin_chaser.tres") as WeaponData
	assert_test(sloop_chaser != null, "weapon_sloop_twin_chaser.tres loads successfully")
	assert_test(sloop_chaser.cannon_count == 2, "Sloop Twin Chasers has 2 cannons")
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

	print("\n========================================================")
	print("  TEST RESULTS: %d / %d PASSED" % [passed_count, total_count])
	print("========================================================\n")

	if passed_count == total_count:
		print(">>> ALL TESTS PASSED! <<<")
	else:
		printerr(">>> SOME TESTS FAILED! <<<")

	get_tree().quit(0 if passed_count == total_count else 1)
