@tool
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
	print("  TESTING BOMBARDIER BOW GUN & FLEET SYNCHRONIZATION     ")
	print("========================================================\n")

	# ── TEST 1: Bombardier Bow Gun Closest Threat Targeting ──
	print("\n--- 1. Testing Bombardier Bow Gun Targeting ---")
	var ship_res: ShipData = load("res://src/data/resources/user_vessels/bombard_skiff_ship.tres") as ShipData
	assert_test(ship_res != null, "bombard_skiff_ship.tres loads")

	var player_scene: PackedScene = load("res://src/gameplay/player/player_boat.tscn") as PackedScene
	var player: PlayerSwerve = player_scene.instantiate() as PlayerSwerve
	add_child(player)
	player.global_position = Vector3(0.0, 0.0, 0.0)
	player.apply_ship_data(ship_res)
	player.apply_tier(1)

	assert_test(player.equipped_weapons.has("BowMortarMount"), "Bombard Skiff equips 'BowMortarMount'")
	var bow_mortar: AttachedWeapon = player.equipped_weapons.get("BowMortarMount") as AttachedWeapon
	assert_test(bow_mortar != null, "BowMortarMount AttachedWeapon instance exists")

	# Spawn an enemy far away (Z = -12.0)
	var far_enemy: Area3D = Area3D.new()
	far_enemy.name = "FarEnemy"
	far_enemy.add_to_group("enemies")
	add_child(far_enemy)
	far_enemy.global_position = Vector3(1.0, 0.4, -12.0)
	var far_col: CollisionShape3D = CollisionShape3D.new()
	var far_box: BoxShape3D = BoxShape3D.new()
	far_box.size = Vector3(1.0, 1.0, 1.0)
	far_col.shape = far_box
	far_enemy.add_child(far_col)

	# Spawn a barricade / barrier close by (Z = -4.0, X = -0.5)
	var close_barrier_scene: PackedScene = load("res://src/gameplay/obstacles/barricade_segment.tscn") as PackedScene
	var close_barrier: BarricadeSegment = close_barrier_scene.instantiate() as BarricadeSegment
	add_child(close_barrier)
	close_barrier.global_position = Vector3(-0.5, 0.22, -4.0)

	# Run targeting update
	bow_mortar._process_targeting(0.016)

	assert_test(bow_mortar.current_target == close_barrier, "Bow mortar locks onto closest threat (close barrier at 4m rather than far enemy at 12m)")
	assert_test(bow_mortar.aim_direction.z < -0.8, "Aim direction points forward toward target")
	assert_test(bow_mortar.aim_direction.x < 0.0, "Aim direction angles toward left lane where close barrier is located")

	# ── TEST 2: Firing Bow Mortar at Close Target ──
	print("\n--- 2. Testing Bow Mortar Dynamic Distance & Detonation ---")
	var world_node: Node3D = Node3D.new()
	world_node.name = "WorldContainer"
	add_child(world_node)

	bow_mortar.projectile_scene = load("res://src/gameplay/projectiles/cannonball.tscn") as PackedScene
	bow_mortar._execute_fire(bow_mortar.projectile_scene, world_node)

	var fired_mortar: Cannonball = null
	for child: Node in world_node.get_children():
		if child is Cannonball:
			fired_mortar = child as Cannonball
			break

	assert_test(fired_mortar != null, "Bow mortar fired a Cannonball instance")
	if fired_mortar:
		assert_test(fired_mortar.target_node == close_barrier, "Fired mortar references close barrier as target_node")
		assert_test(fired_mortar.target_range > 3.0 and fired_mortar.target_range < 6.0, "Fired mortar target_range matches close barrier distance (~4m, not fixed 18m)")
		assert_test(fired_mortar.max_range > 3.0 and fired_mortar.max_range < 6.0, "Fired mortar max_range dynamically clamped to target distance")
		assert_test(fired_mortar.arc_height < 1.5, "Fired mortar arc_height dynamically scaled down for point-blank lob")

		# Simulate flight to landing
		var barrier_hp_before: int = close_barrier.hp
		var sim_delta: float = 0.05
		for _step: int in range(20):
			if not is_instance_valid(fired_mortar) or fired_mortar.is_queued_for_deletion():
				break
			fired_mortar._physics_process(sim_delta)

		assert_test(close_barrier.is_queued_for_deletion() or close_barrier.get("_is_destroyed") == true or close_barrier.hp < barrier_hp_before, "Close barrier received damage/destroyed from dynamic mortar landing")

	# Clean up test combat objects
	far_enemy.queue_free()
	close_barrier.queue_free()
	world_node.queue_free()

	# ── TEST 2B: Mortar Detonation with Instant-Freed Target ──
	print("\n--- 2B. Testing Mortar Detonation with Instant-Freed Target ---")
	var dummy_target: Area3D = Area3D.new()
	dummy_target.name = "DummyTarget"
	dummy_target.add_to_group("destructible")
	add_child(dummy_target)
	
	var dummy_mortar: Cannonball = bow_mortar.projectile_scene.instantiate() as Cannonball
	add_child(dummy_mortar)
	dummy_mortar.set_meta("is_mortar", true)
	dummy_mortar.target_node = dummy_target
	dummy_mortar.setup(Vector3(0, 0, -1), load("res://src/data/resources/user_ammo/ammo_heavy_shot.tres") as AmmoData, bow_mortar.weapon_data)
	
	# Free dummy_target immediately to simulate an object freed before/during hit
	dummy_target.free()
	
	# Execute mortar impact detonation - should safely handle freed target without crashing
	dummy_mortar._detonate_mortar_impact()
	assert_test(true, "_detonate_mortar_impact() completed safely with previously freed target")
	dummy_mortar.queue_free()

	# ── TEST 3: Fleet Follower Vessels Equipping Bombardier Skiff Weapons ──
	print("\n--- 3. Testing Fleet Escort Weapon Synchronization ---")
	var follower_scene: PackedScene = load("res://src/gameplay/player/follower_boat.tscn") as PackedScene
	var follower: Area3D = follower_scene.instantiate() as Area3D
	add_child(follower)

	# Verify follower equipped Bombardier Skiff's BowMortarMount
	var f_equipped: Dictionary = follower.get("equipped_weapons") as Dictionary
	assert_test(f_equipped.has("BowMortarMount"), "Follower boat equips 'BowMortarMount' when player is Bombardier Skiff")
	var f_mortar: AttachedWeapon = f_equipped.get("BowMortarMount") as AttachedWeapon
	assert_test(f_mortar != null and f_mortar.weapon_data != null and f_mortar.weapon_data.weapon_type == "deck_mortar", "Follower BowMortarMount weapon is Heavy Siege Mortar (deck_mortar), not standard bow chaser")

	# Verify follower bow weapon instance is set to mortar
	var f_bow_weapon: Node3D = follower.get("weapon_instance") as Node3D
	assert_test(f_bow_weapon == f_mortar, "Follower primary weapon_instance points to BowMortarMount")

	# ── TEST 4: Fleet Follower Weapons with Sloop ──
	print("\n--- 4. Testing Fleet Escort Weapon Synchronization with Sloop ---")
	var sloop_res: ShipData = load("res://src/data/resources/user_vessels/sloop_ship.tres") as ShipData
	player.apply_ship_data(sloop_res)
	player.apply_tier(1)

	var follower_sloop: Area3D = follower_scene.instantiate() as Area3D
	add_child(follower_sloop)
	var f_sloop_equipped: Dictionary = follower_sloop.get("equipped_weapons") as Dictionary
	assert_test(f_sloop_equipped.has("BowMount"), "Follower boat equips 'BowMount' when player is Sloop")
	var f_chaser: AttachedWeapon = f_sloop_equipped.get("BowMount") as AttachedWeapon
	assert_test(f_chaser != null and f_chaser.weapon_data != null and f_chaser.weapon_data.weapon_name == "Bow Chaser", "Follower BowMount weapon is Sloop's Bow Chaser")

	# Clean up
	follower.queue_free()
	follower_sloop.queue_free()
	player.queue_free()

	print("\n========================================================")
	print("  TEST RESULTS: %d / %d PASSED" % [passed_count, total_count])
	print("========================================================\n")

	if passed_count == total_count:
		print(">>> ALL TESTS PASSED! <<<")
	else:
		printerr(">>> SOME TESTS FAILED! <<<")
		
	get_tree().quit(0 if passed_count == total_count else 1)
