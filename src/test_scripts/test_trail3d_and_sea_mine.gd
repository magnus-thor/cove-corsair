extends Node3D

const Trail3DScript = preload("res://src/vfx/trail_3d.gd")

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
	print("  TESTING TRAIL3D RIBBON & SEA MINE EXPLOSION COORDINATES")
	print("==========================================================\n")
	
	await _run_all_tests()
	
	print("\n==========================================================")
	print("  TEST RESULTS: %d / %d PASSED" % [passed_count, total_count])
	print("==========================================================\n")
	
	if passed_count == total_count:
		print(">>> ALL TRAIL3D & SEA MINE TESTS PASSED SUCCESSFULLY! <<<\n")
		get_tree().quit(0)
	else:
		printerr(">>> SOME TESTS FAILED! <<<\n")
		get_tree().quit(1)

func _run_all_tests() -> void:
	await _test_sea_mine_explosion_coordinates()
	await _test_trail3d_component_specs()
	await _test_selective_trail_attachment()
	await _test_trail_dissipation_lifecycle()

func _test_sea_mine_explosion_coordinates() -> void:
	print("--- 1. Sea Mine Explosion World Coordinates ---")
	var mine_scene = load("res://src/gameplay/obstacles/hazard_sea_mine.tscn") as PackedScene
	assert_test(mine_scene != null, "hazard_sea_mine.tscn loads successfully")
	
	var mine = mine_scene.instantiate() as HazardSeaMine
	add_child(mine)
	var mine_spawn_pos = Vector3(3.5, 0.05, -18.0)
	mine.global_position = mine_spawn_pos
	
	# Simulate player positioned elsewhere (X=0.0)
	var player_scene = load("res://src/gameplay/player/player_boat.tscn") as PackedScene
	var player = player_scene.instantiate() as Node3D
	add_child(player)
	player.global_position = Vector3(0.0, 0.0, -18.0)
	
	var vfx_container = get_tree().current_scene.get_node_or_null("VFXContainer") if get_tree().current_scene else null
	var count_before = vfx_container.get_child_count() if vfx_container else 0
	
	# Detonate mine
	mine.die()
	
	vfx_container = get_tree().current_scene.get_node_or_null("VFXContainer") if get_tree().current_scene else null
	var count_after = vfx_container.get_child_count() if vfx_container else 0
	assert_test(count_after > count_before, "HazardSeaMine.die() spawned explosion in world VFXContainer")
	
	if vfx_container and count_after > 0:
		var spawned_vfx = vfx_container.get_child(count_after - 1) as Node3D
		assert_test(spawned_vfx != null, "Spawned explosion VFX is a valid Node3D")
		if spawned_vfx:
			assert_test(is_equal_approx(spawned_vfx.global_position.x, 3.5), "Explosion VFX spawned at mine X=3.5, NOT at player vessel center (X=0.0)")
			assert_test(is_equal_approx(spawned_vfx.global_position.z, -18.0), "Explosion VFX spawned at mine Z=-18.0")
			assert_test(spawned_vfx.get_parent() != player, "Explosion VFX is NOT parented to player vessel")
			assert_test(spawned_vfx.top_level == true, "Explosion VFX has top_level = true for world independence")
			var smoke_ring = spawned_vfx.get_node_or_null("SmokeRing")
			assert_test(smoke_ring != null, "Explosion VFX contains SmokeRing shockwave mesh")
			var core_flash = spawned_vfx.get_node_or_null("CoreFlash") as CPUParticles3D
			assert_test(core_flash != null, "Explosion VFX contains CoreFlash fiery particles")
			if core_flash:
				assert_test(core_flash.local_coords == true, "CoreFlash has local_coords = true so particles anchor to mine position")
				assert_test(is_equal_approx(core_flash.global_position.x, 3.5), "CoreFlash emitter at mine X=3.5")
				assert_test(is_equal_approx(core_flash.global_position.z, -18.0), "CoreFlash emitter at mine Z=-18.0")
	
	# Cleanup player
	player.queue_free()

	# Test 1b: Parent node offset scenario (mimicking Main at Z = -33.36m with player at vessel origin)
	var offset_root = Node3D.new()
	offset_root.position = Vector3(0.0, 0.0, -33.35858)
	add_child(offset_root)
	
	var distant_player = player_scene.instantiate() as Node3D
	offset_root.add_child(distant_player)
	distant_player.position = Vector3.ZERO # Global Z is -33.35858
	
	var distant_mine = mine_scene.instantiate() as HazardSeaMine
	offset_root.add_child(distant_mine)
	distant_mine.global_position = Vector3(-2.0, 0.05, -65.0) # 32 meters downriver from player
	
	distant_mine.die()
	
	vfx_container = get_tree().current_scene.get_node_or_null("VFXContainer") if get_tree().current_scene else null
	if vfx_container and vfx_container.get_child_count() > 0:
		var last_vfx = vfx_container.get_child(vfx_container.get_child_count() - 1) as Node3D
		assert_test(last_vfx != null, "Explosion VFX spawned for distant sea mine")
		if last_vfx:
			assert_test(is_equal_approx(last_vfx.global_position.x, -2.0), "Distant mine explosion at X=-2.0")
			assert_test(is_equal_approx(last_vfx.global_position.z, -65.0), "Distant mine explosion at Z=-65.0 (NOT at player Z=-33.36m)")
			var cf = last_vfx.get_node_or_null("CoreFlash") as CPUParticles3D
			if cf:
				assert_test(is_equal_approx(cf.global_position.z, -65.0), "CoreFlash particles emitter at Z=-65.0, NOT at user vessel Z=-33.36m")
	
	offset_root.queue_free()

func _test_trail3d_component_specs() -> void:
	print("\n--- 2. Trail3D Component Details & Materials ---")
	var trail_scene = load("res://src/vfx/trail_3d.tscn") as PackedScene
	assert_test(trail_scene != null, "trail_3d.tscn loads successfully")
	
	var trail = trail_scene.instantiate()
	add_child(trail)
	
	assert_test(trail.mesh is ImmediateMesh, "Trail3D uses ImmediateMesh for ribbon rendering")
	assert_test(trail.top_level == true, "Trail3D top_level is true for independent world ribbon")
	
	var mat = trail.material_override as StandardMaterial3D
	assert_test(mat != null, "Trail3D has StandardMaterial3D material override")
	if mat:
		assert_test(mat.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED, "Material is unshaded (SHADING_MODE_UNSHADED)")
		assert_test(mat.blend_mode == BaseMaterial3D.BLEND_MODE_ADD, "Material uses additive blend (BLEND_MODE_ADD)")
		assert_test(mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA, "Material transparency is ALPHA")
		assert_test(mat.cull_mode == BaseMaterial3D.CULL_DISABLED, "Material cull_mode is CULL_DISABLED (double-sided)")
		assert_test(mat.vertex_color_use_as_albedo == true, "Material vertex_color_use_as_albedo is enabled")
		
	assert_test(trail.max_points == 14, "trail_length max_points is ~12-14 (actual: 14)")
	assert_test(is_equal_approx(trail.trail_lifetime, 0.20), "trail_lifetime is 0.20s")
	assert_test(trail.get("COLOR_HEAD") == Color(1.0, 0.7, 0.2, 0.9), "Color profile core is bright yellow-orange Color(1.0, 0.7, 0.2, 0.9)")
	assert_test(trail.get("COLOR_TAIL") == Color(0.8, 0.2, 0.05, 0.0), "Color profile tail is smoky red Color(0.8, 0.2, 0.05, 0.0)")
	
	trail.queue_free()

func _test_selective_trail_attachment() -> void:
	print("\n--- 3. Selective Fire/Incendiary Trail Attachment ---")
	var ball_scene = load("res://src/gameplay/projectiles/cannonball.tscn") as PackedScene
	assert_test(ball_scene != null, "cannonball.tscn loads successfully")
	
	# A. Skeleton Tosser fire projectile -> MUST have Trail3D
	var ball_skel = ball_scene.instantiate() as Cannonball
	ball_skel.crew_id = "skeleton_tosser"
	add_child(ball_skel)
	var skel_trail = ball_skel.get_node_or_null("Trail3D")
	assert_test(skel_trail != null, "Skeleton Tosser fire projectile receives Trail3D")
	ball_skel.queue_free()
	
	# B. Explicitly tagged incendiary projectile -> MUST have Trail3D
	var ball_fire = ball_scene.instantiate() as Cannonball
	ball_fire.set_meta("is_incendiary", true)
	add_child(ball_fire)
	var fire_trail = ball_fire.get_node_or_null("Trail3D")
	assert_test(fire_trail != null, "Explicitly tagged is_incendiary projectile receives Trail3D")
	ball_fire.queue_free()
	
	# C. Boss Fire Twin Cannon Salvo -> MUST have Trail3D
	var salvo_scene = load("res://src/gameplay/projectiles/boss_projectile_twin_cannon_salvo.tscn") as PackedScene
	assert_test(salvo_scene != null, "boss_projectile_twin_cannon_salvo.tscn loads")
	var salvo = salvo_scene.instantiate() as BossProjectileTwinCannonSalvo
	add_child(salvo)
	var salvo_trail = salvo.get_node_or_null("Trail3D")
	assert_test(salvo_trail != null, "Boss Fire Twin Cannon Salvo receives Trail3D")
	salvo.queue_free()
	
	# D. Standard iron ball -> MUST NOT have Trail3D
	var ball_standard = ball_scene.instantiate() as Cannonball
	ball_standard.crew_id = ""
	ball_standard.ammo_id = ""
	add_child(ball_standard)
	var std_trail = ball_standard.get_node_or_null("Trail3D")
	assert_test(std_trail == null, "Standard iron cannonball does NOT receive Trail3D")
	ball_standard.queue_free()
	
	# E. Battering shot -> MUST NOT have Trail3D
	var ball_bat = ball_scene.instantiate() as Cannonball
	ball_bat.ammo_id = "battering_shot"
	add_child(ball_bat)
	var bat_trail = ball_bat.get_node_or_null("Trail3D")
	assert_test(bat_trail == null, "Battering shot does NOT receive Trail3D")
	ball_bat.queue_free()
	
	# F. Chain shot -> MUST NOT have Trail3D
	var ball_chain = ball_scene.instantiate() as Cannonball
	ball_chain.ammo_id = "chain_shot"
	add_child(ball_chain)
	var chain_trail = ball_chain.get_node_or_null("Trail3D")
	assert_test(chain_trail == null, "Chain shot does NOT receive Trail3D")
	ball_chain.queue_free()
	
	# G. Monkey Bomber coconut bomb -> MUST NOT have Trail3D
	var ball_monkey = ball_scene.instantiate() as Cannonball
	ball_monkey.crew_id = "monkey_bomber"
	add_child(ball_monkey)
	var monkey_trail = ball_monkey.get_node_or_null("Trail3D")
	assert_test(monkey_trail == null, "Monkey Bomber bomb does NOT receive Trail3D")
	ball_monkey.queue_free()

func _test_trail_dissipation_lifecycle() -> void:
	print("\n--- 4. Trail Dissipation & Auto-Free Lifecycle ---")
	var ball_scene = load("res://src/gameplay/projectiles/cannonball.tscn") as PackedScene
	var ball = ball_scene.instantiate() as Cannonball
	ball.crew_id = "skeleton_tosser"
	add_child(ball)
	ball.global_position = Vector3(0.0, 1.0, -10.0)
	
	var trail = ball.get_node_or_null("Trail3D")
	assert_test(trail != null, "Trail3D instantiated on fire projectile")
	
	# Simulate movement over a couple frames to generate trail points
	for i in range(5):
		ball.global_position.z -= 0.5
		trail._process(0.03)
		
	assert_test(trail._points.size() > 0, "Trail points accumulated during projectile movement")
	
	# Trigger projectile detonation / impact
	var dummy_target = Node3D.new()
	dummy_target.add_to_group("destructible")
	add_child(dummy_target)
	dummy_target.global_position = ball.global_position
	
	# _on_hit should call detach_and_fade() and queue_free() ball
	ball._on_hit(dummy_target)
	
	assert_test(trail.get_parent() != ball, "Trail reparented to scene root on impact (not destroyed with ball)")
	assert_test(trail._is_fading == true, "Trail entered fading state (_is_fading == true)")
	assert_test(is_instance_valid(trail), "Trail remains alive in scene after projectile is freed")
	
	# Advance time past trail_lifetime (0.25s)
	await get_tree().create_timer(0.3).timeout
	
	assert_test(not is_instance_valid(trail) or trail.is_queued_for_deletion(), "Trail smoothly dissipated and auto-freed after 0.2s")
	
	dummy_target.queue_free()
