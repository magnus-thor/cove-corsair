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
	print("  TESTING SLOOP CANNONBALL HITBOX VS BARRICADE (SOLO)   ")
	print("========================================================\n")

	# 1. Setup Solo Sloop (0 fleet followers)
	var player_scene: PackedScene = load("res://src/gameplay/player/player_boat.tscn") as PackedScene
	var player: PlayerSwerve = player_scene.instantiate() as PlayerSwerve
	add_child(player)
	player.global_position = Vector3(0.0, 0.0, 0.0)

	var sloop_res: ShipData = load("res://src/data/resources/user_vessels/sloop_ship.tres") as ShipData
	assert_test(sloop_res != null, "sloop_ship.tres loads")
	player.apply_ship_data(sloop_res)
	player.apply_tier(1)

	assert_test(player.equipped_weapons.has("BowMount"), "Sloop equips BowMount")
	var bow_chaser: AttachedWeapon = player.equipped_weapons["BowMount"] as AttachedWeapon
	assert_test(bow_chaser != null, "BowMount is active AttachedWeapon")

	# Confirm 0 fleet followers
	var follower_count: int = player._fleet.get_follower_count() if player._fleet else 0
	assert_test(follower_count == 0, "Flagship Sloop is strictly solo (0 follower fleet vessels)")

	# 2. Place Barricade directly in lane ahead (Z = -5.0)
	var barricade_scene: PackedScene = load("res://src/gameplay/obstacles/barricade_segment.tscn") as PackedScene
	assert_test(barricade_scene != null, "barricade_segment.tscn loads")
	var barricade: BarricadeSegment = barricade_scene.instantiate() as BarricadeSegment
	add_child(barricade)
	barricade.global_position = Vector3(0.0, 0.0, -5.0)

	var initial_hp: int = barricade.hp

	# 3. Fire Sloop cannons
	var world_node: Node3D = Node3D.new()
	world_node.name = "WorldSim"
	add_child(world_node)

	bow_chaser.projectile_scene = load("res://src/gameplay/projectiles/cannonball.tscn") as PackedScene
	bow_chaser._execute_fire(bow_chaser.projectile_scene, world_node)

	var cannonballs: Array[Cannonball] = []
	for child: Node in world_node.get_children():
		if child is Cannonball:
			cannonballs.append(child as Cannonball)

	assert_test(cannonballs.size() == 2, "Sloop fired 2 cannonballs forward")

	# 4. Simulate cannonballs traveling forward toward barricade
	var hit_detected: bool = false
	var sim_step: float = 0.02
	for _i: int in range(25):
		for ball: Cannonball in cannonballs:
			if is_instance_valid(ball) and not ball.is_queued_for_deletion():
				ball._physics_process(sim_step)
				# Check Area3D intersection manually if engine physics loop is not running ticks
				if is_instance_valid(barricade) and not barricade.is_queued_for_deletion():
					var dist: float = ball.global_position.distance_to(barricade.global_position)
					if dist < 1.0:
						ball._on_hit(barricade)
						hit_detected = true
						break
		if hit_detected or barricade.hp < initial_hp:
			break

	assert_test(barricade.hp < initial_hp or barricade.is_queued_for_deletion(), "Sloop cannonballs successfully hit and damaged barricade segment without needing fleet vessels (HP was %d, now %d)" % [initial_hp, barricade.hp])

	# Cleanup
	world_node.queue_free()
	barricade.queue_free()
	player.queue_free()

	print("\n========================================================")
	print("  TEST RESULTS: %d / %d PASSED" % [passed_count, total_count])
	print("========================================================\n")
	get_tree().quit(0 if passed_count == total_count else 1)
