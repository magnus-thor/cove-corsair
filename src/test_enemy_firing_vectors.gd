extends Node3D

var passed_count: int = 0
var total_count: int = 0

func assert_test(condition: bool, message: String) -> void:
	total_count += 1
	if condition:
		passed_count += 1
		print("  [PASS] %s" % message)
	else:
		push_error("  [FAIL] %s" % message)
		print("  [FAIL] %s" % message)

func _ready() -> void:
	print("\n==========================================================")
	print("  TESTING ENEMY FIRING VECTORS & FACING PROTOCOL")
	print("==========================================================\n")
	
	await _run_all_tests()
	
	print("\n==========================================================")
	print("  TEST RESULTS: %d / %d PASSED" % [passed_count, total_count])
	print("==========================================================\n")
	
	if passed_count == total_count:
		print(">>> ALL FIRING VECTOR TESTS PASSED SUCCESSFULLY! <<<\n")
		get_tree().quit(0)
	else:
		printerr(">>> SOME FIRING VECTOR TESTS FAILED! <<<\n")
		get_tree().quit(1)

func _run_all_tests() -> void:
	_test_enemy_cannonball_facing()
	_test_hostile_cannonball_safety()
	_test_enemy_mob_firing()
	_test_ghost_sloop_mob()
	_test_boss_war_barge_firing()
	_test_boss_phantom_dredge_firing()
	_test_player_weapons_facing()
	_test_follower_fleet_firing()
	_test_player_spawn_facing()
	await get_tree().process_frame

func _test_enemy_cannonball_facing() -> void:
	print("--- TEST 1: EnemyCannonball Heading & Safeguard ---")
	var ball_scene = load("res://src/gameplay/projectiles/enemy_cannonball.tscn") as PackedScene
	var ball = ball_scene.instantiate() as EnemyCannonball
	add_child(ball)
	
	assert_test(ball.direction.z > 0.0, "Enemy cannonball default direction is downriver (+Z)")
	
	# Test safeguard against backwards input (-Z)
	ball.setup(Vector3(0, 0, -1))
	assert_test(ball.direction.z > 0.0, "Enemy cannonball reflects backwards vector (-Z) to forward (+Z)")
	
	var start_z = ball.global_position.z
	ball._physics_process(0.1)
	assert_test(ball.global_position.z > start_z, "Enemy cannonball advances downriver in +Z")
	ball.queue_free()

func _test_hostile_cannonball_safety() -> void:
	print("--- TEST 2: Cannonball.gd Hostile Facing & Setup ---")
	var cb_scene = load("res://src/gameplay/projectiles/cannonball.tscn") as PackedScene
	
	# Player ball
	var player_ball = cb_scene.instantiate() as Cannonball
	add_child(player_ball)
	player_ball.is_hostile = false
	player_ball.setup(Vector3(0, 0, -1), null, null)
	assert_test(player_ball.direction.z < 0.0, "Player cannonball travels upriver (-Z)")
	player_ball.queue_free()
	
	# Hostile ball
	var hostile_ball = cb_scene.instantiate() as Cannonball
	add_child(hostile_ball)
	hostile_ball.is_hostile = true
	hostile_ball.setup(Vector3(0, 0, -1), null, null)
	assert_test(hostile_ball.direction.z > 0.0, "Hostile cannonball reflects backwards input to downriver (+Z)")
	hostile_ball.queue_free()

func _test_enemy_mob_firing() -> void:
	print("--- TEST 3: EnemyMob (Skeleton Rower) Firing ---")
	var mob_scene = load("res://src/gameplay/enemies/enemy_mob.tscn") as PackedScene
	
	# Dummy player at Z = 0
	var player_node = Node3D.new()
	player_node.name = "DummyPlayer"
	player_node.add_to_group("player")
	player_node.global_position = Vector3(0, 0, 0)
	add_child(player_node)
	
	# Skeleton Rower at Z = -20
	var rower = mob_scene.instantiate() as EnemyMob
	add_child(rower)
	rower.global_position = Vector3(0, 0, -20.0)
	var rower_data = load("res://src/data/resources/enemy_vessels/skeleton_rower.tres") as EnemyData
	rower.apply_enemy_data(rower_data)
	
	var initial_balls = get_tree().current_scene.get_children().filter(func(c): return c is EnemyCannonball)
	rower._fire_forward_cannonball()
	var new_balls = get_tree().current_scene.get_children().filter(func(c): return c is EnemyCannonball and not initial_balls.has(c))
	
	assert_test(not new_balls.is_empty(), "Skeleton rower successfully spawns EnemyCannonball")
	if not new_balls.is_empty():
		var ball = new_balls[0] as EnemyCannonball
		assert_test(ball.direction.z > 0.0, "Skeleton rower cannonball direction is downriver (+Z) toward player")
		var start_z = ball.global_position.z
		ball._physics_process(0.1)
		assert_test(ball.global_position.z > start_z, "Rower cannonball moves downriver toward player")
		ball.queue_free()
		
	rower.queue_free()
	player_node.queue_free()

func _test_ghost_sloop_mob() -> void:
	print("--- TEST 4: Ghost Sloop EnemyData & Mob Firing ---")
	var sloop_data = load("res://src/data/resources/enemy_vessels/ghost_sloop.tres") as EnemyData
	assert_test(sloop_data != null, "Ghost Sloop EnemyData resource loaded successfully")
	assert_test(sloop_data != null and sloop_data.mob_name == "Ghost Sloop", "Ghost Sloop mob_name is correct")
	
	var mob_scene = load("res://src/gameplay/enemies/enemy_mob.tscn") as PackedScene
	var mob = mob_scene.instantiate() as EnemyMob
	add_child(mob)
	mob.apply_enemy_data(sloop_data)
	mob.global_position = Vector3(1.0, 0, -18.0)
	
	var initial_balls = get_tree().current_scene.get_children().filter(func(c): return c is EnemyCannonball)
	mob._fire_forward_cannonball()
	var new_balls = get_tree().current_scene.get_children().filter(func(c): return c is EnemyCannonball and not initial_balls.has(c))
	
	assert_test(not new_balls.is_empty(), "Ghost Sloop mob spawns EnemyCannonball")
	if not new_balls.is_empty():
		var ball = new_balls[0] as EnemyCannonball
		assert_test(ball.direction.z > 0.0, "Ghost Sloop cannonball travels downriver (+Z)")
		ball.queue_free()
	mob.queue_free()

func _test_boss_war_barge_firing() -> void:
	print("--- TEST 5: Boss War-Barge Cannon Volley Direction ---")
	var boss_scene = load("res://src/gameplay/enemies/boss_war_barge.tscn") as PackedScene
	var boss = boss_scene.instantiate() as BossWarBarge
	add_child(boss)
	boss.global_position = Vector3(0, 0, -25.0)
	
	var initial_balls = get_tree().current_scene.get_children().filter(func(c): return c is EnemyCannonball)
	boss._fire_cannon_volley()
	var new_balls = get_tree().current_scene.get_children().filter(func(c): return c is EnemyCannonball and not initial_balls.has(c))
	
	assert_test(not new_balls.is_empty(), "War-Barge spawns cannonball during volley")
	if not new_balls.is_empty():
		var ball = new_balls[0] as EnemyCannonball
		assert_test(ball.direction.z > 0.0, "War-Barge cannonball travels downriver (+Z) toward player")
		ball.queue_free()
	boss.queue_free()

func _test_boss_phantom_dredge_firing() -> void:
	print("--- TEST 6: Boss Phantom Dredge (Ghost Sloop) Spectral Cannon Volley ---")
	var boss_scene = load("res://src/gameplay/enemies/boss_phantom_dredge.tscn") as PackedScene
	var boss = boss_scene.instantiate() as BossPhantomDredge
	add_child(boss)
	boss.global_position = Vector3(0, 0, -25.0)
	
	var initial_balls = get_tree().current_scene.get_children().filter(func(c): return c is EnemyCannonball)
	boss._fire_spectral_cannon_volley()
	var new_balls = get_tree().current_scene.get_children().filter(func(c): return c is EnemyCannonball and not initial_balls.has(c))
	
	assert_test(not new_balls.is_empty(), "Phantom Dredge spawns spectral cannonballs")
	if not new_balls.is_empty():
		var ball = new_balls[0] as EnemyCannonball
		assert_test(ball.direction.z > 0.0, "Phantom Dredge spectral cannonball travels downriver (+Z) toward player")
		ball.queue_free()
	boss.queue_free()

func _test_player_weapons_facing() -> void:
	print("--- TEST 7: Player Weapons (Starter Bow Chaser & Mortar) Fire Upriver (-Z) ---")
	var weapon_scene = load("res://src/gameplay/player/attached_weapon.tscn") as PackedScene
	
	# Socket matching BowMount (rotated 180 deg around Y)
	var socket = Node3D.new()
	socket.name = "BowMount"
	socket.rotation_degrees = Vector3(0, 180, 0)
	add_child(socket)
	
	var weapon = weapon_scene.instantiate() as AttachedWeapon
	socket.add_child(weapon)
	
	var chaser_data = load("res://src/data/resources/user_crew/weapon_bow_chaser.tres") as WeaponData
	weapon.setup_weapon(chaser_data)
	
	var world_container = Node3D.new()
	add_child(world_container)
	
	weapon.try_fire(weapon.projectile_scene, world_container)
	var player_balls = world_container.get_children().filter(func(c): return c is Cannonball)
	assert_test(not player_balls.is_empty(), "Player Bow Chaser spawns Cannonball")
	if not player_balls.is_empty():
		var ball = player_balls[0] as Cannonball
		assert_test(ball.direction.z < 0.0, "Player Bow Chaser fires upriver (-Z)")
		ball.queue_free()
		
	# Test Mortar
	var mortar_data = load("res://src/data/resources/user_crew/weapon_bow_mortar.tres") as WeaponData
	if mortar_data:
		weapon.setup_weapon(mortar_data)
		weapon.try_fire(weapon.projectile_scene, world_container)
		var mortar_balls = world_container.get_children().filter(func(c): return c is Cannonball)
		assert_test(not mortar_balls.is_empty(), "Player Mortar spawns Cannonball")
		if not mortar_balls.is_empty():
			var ball = mortar_balls[0] as Cannonball
			assert_test(ball.direction.z < 0.0, "Player Mortar fires upriver (-Z)")
			ball.queue_free()
			
	# Test Scattershot
	var scatter_data = load("res://src/data/resources/user_weapons/weapon_scattershot.tres") as WeaponData
	if scatter_data:
		weapon.setup_weapon(scatter_data)
		weapon.fire_scattershot(Vector3.ZERO, world_container)
		var pellets = world_container.get_children().filter(func(c): return c is Cannonball or "pellet" in c.name.to_lower())
		assert_test(not pellets.is_empty(), "Player Scattershot spawns pellets")
		var all_upriver = true
		for p in pellets:
			if "direction" in p and p.direction.z >= 0.0:
				all_upriver = false
			p.queue_free()
		assert_test(all_upriver, "All scattershot pellets fire in upriver (-Z) arcs")
		
	world_container.queue_free()
	socket.queue_free()

func _test_follower_fleet_firing() -> void:
	print("--- TEST 8: Follower Fleet Vessel Firing Vector ---")
	var follower_scene = load("res://src/gameplay/player/follower_boat.tscn") as PackedScene
	var follower = follower_scene.instantiate()
	add_child(follower)
	
	var bow = follower.get_node_or_null("BowMount")
	assert_test(bow != null, "Follower boat has BowMount socket")
	if bow:
		var rot_y = fposmod(bow.rotation_degrees.y, 360.0)
		assert_test(is_equal_approx(rot_y, 180.0), "Follower boat BowMount is rotated 180 degrees")
		
	var world_container = Node3D.new()
	add_child(world_container)
	
	# Simulate player firing with follower attached
	var weapon = follower.weapon_instance as AttachedWeapon
	assert_test(weapon != null, "Follower boat has instantiated weapon")
	if weapon:
		weapon.try_fire(weapon.projectile_scene, world_container)
		var balls = world_container.get_children().filter(func(c): return c is Cannonball)
		assert_test(not balls.is_empty(), "Follower boat successfully fired cannonball")
		if not balls.is_empty():
			var ball = balls[0] as Cannonball
			assert_test(ball.direction.z < 0.0, "Follower boat cannonball direction is upriver (-Z)")
			var start_z = ball.global_position.z
			ball._physics_process(0.1)
			assert_test(ball.global_position.z < start_z, "Follower boat projectile moves upriver in -Z")
			ball.queue_free()
			
	world_container.queue_free()
	follower.queue_free()

func _test_player_spawn_facing() -> void:
	print("--- TEST 9: Player Vessel Starting Facing Direction ---")
	var player_scene = load("res://src/gameplay/player/player_boat.tscn") as PackedScene
	var player = player_scene.instantiate() as PlayerSwerve
	add_child(player)
	
	# In harbor / menu mode (is_game_active = false), visuals must face forward (around 0 deg, NOT 158 deg)
	GameState.is_game_active = false
	player._physics_process(0.1)
	var vis = player.get_node_or_null("BoatVisuals")
	assert_test(vis != null, "Player has BoatVisuals node")
	if vis:
		assert_test(abs(vis.rotation_degrees.y) < 10.0, "Harbor/idle player vessel faces forward (<10 deg bob, was 158 deg)")
		
	# In active game mode (is_game_active = true), visuals must face exactly 0.0
	GameState.is_game_active = true
	player._physics_process(0.1)
	if vis:
		assert_test(is_equal_approx(vis.rotation_degrees.y, 0.0), "Active gameplay player vessel faces forward (0.0 deg)")
	var hp = player.get_node_or_null("Hardpoints")
	if hp:
		assert_test(is_equal_approx(hp.rotation_degrees.y, 0.0), "Active gameplay hardpoints face forward (0.0 deg)")
		
	player.queue_free()

