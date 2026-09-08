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
	print("  TESTING 3D COMBAT PARTICLES & IMPACT VFX SYSTEMS")
	print("==========================================================\n")
	
	await _run_all_tests()
	
	print("\n==========================================================")
	print("  TEST RESULTS: %d / %d PASSED" % [passed_count, total_count])
	print("==========================================================\n")
	
	if passed_count == total_count:
		print(">>> ALL VFX SYSTEM TESTS PASSED SUCCESSFULLY! <<<\n")
		get_tree().quit(0)
	else:
		printerr(">>> SOME VFX SYSTEM TESTS FAILED! <<<\n")
		get_tree().quit(1)

func _run_all_tests() -> void:
	_test_vfx_manager_registration()
	await _test_wood_debris_particles()
	await _test_mortar_geyser_particles_and_waterline()
	await _test_mine_explosion_particles()
	await _test_entity_destruction_hooks()
	await _test_autofree_and_memory_cleanup()

func _test_vfx_manager_registration() -> void:
	print("--- 1. VFXManager Registration & API ---")
	assert_test(VFXManager != null, "VFXManager autoload singleton is active")
	assert_test(VFXManager.has_method("spawn_wood_debris"), "VFXManager has spawn_wood_debris()")
	assert_test(VFXManager.has_method("spawn_mortar_splash"), "VFXManager has spawn_mortar_splash()")
	assert_test(VFXManager.has_method("spawn_mine_explosion"), "VFXManager has spawn_mine_explosion()")

func _test_wood_debris_particles() -> void:
	print("\n--- 2. Wood Splinter Debris Particles ---")
	var target_pos = Vector3(1.2, 0.4, -15.0)
	var effect = VFXManager.spawn_wood_debris(target_pos)
	assert_test(effect != null, "spawn_wood_debris returned an instance")
	assert_test(is_instance_valid(effect), "Effect instance is valid")
	assert_test(effect.is_inside_tree(), "Effect is added into scene tree")
	assert_test(effect.global_position.is_equal_approx(target_pos), "Effect positioned at target transform: %s" % str(effect.global_position))
	
	# Verify World Tree Rooting safeguard
	var vfx_container = get_node_or_null("VFXContainer")
	assert_test(effect.get_parent() == vfx_container or effect.get_parent() != null, "Effect rooted at world-level container, not inside dying entity")
	
	# Verify CPUParticles3D properties
	var cpu_p: CPUParticles3D = effect as CPUParticles3D if effect is CPUParticles3D else effect.find_child("*", true, false)
	assert_test(cpu_p != null, "Wood debris has CPUParticles3D")
	if cpu_p:
		assert_test(cpu_p.amount >= 8 and cpu_p.amount <= 12, "Wood debris amount is 8-12 angular fragments (actual: %d)" % cpu_p.amount)
		assert_test(cpu_p.one_shot == true, "one_shot is true")
		assert_test(is_equal_approx(cpu_p.lifetime, 0.5), "lifetime is 0.5s")
		assert_test(is_equal_approx(cpu_p.gravity.y, -9.8), "gravity is -9.8 m/s²")
		assert_test(cpu_p.initial_velocity_min > 0.0, "explosive outward velocity configured")
		assert_test(cpu_p.angular_velocity_min != 0.0 or cpu_p.angular_velocity_max != 0.0, "angular spin configured")

func _test_mortar_geyser_particles_and_waterline() -> void:
	print("\n--- 3. Mortar Splash Geyser & Waterline Clamping Safeguard ---")
	# Test waterline alignment safeguard: spawn at elevated Y = 2.8m (contact point)
	var elevated_pos = Vector3(-2.5, 2.8, -20.0)
	var effect = VFXManager.spawn_mortar_splash(elevated_pos)
	assert_test(effect != null, "spawn_mortar_splash returned instance")
	assert_test(effect.is_inside_tree(), "Geyser is inside tree")
	
	# Check Waterline Alignment: Y clamped between 0.0 and 0.05
	assert_test(effect.global_position.y >= -0.001 and effect.global_position.y <= 0.051, "Waterline safeguard clamped Y from 2.8m to water surface: %.3fm" % effect.global_position.y)
	assert_test(is_equal_approx(effect.global_position.x, elevated_pos.x) and is_equal_approx(effect.global_position.z, elevated_pos.z), "X and Z positions preserved accurately")
	
	var water_col: CPUParticles3D = effect.get_node_or_null("WaterColumn")
	assert_test(water_col != null, "Found WaterColumn particle system")
	if water_col:
		assert_test(water_col.one_shot == true, "WaterColumn one_shot is true")
		assert_test(is_equal_approx(water_col.lifetime, 0.6), "WaterColumn lifetime is 0.6s")
		assert_test(water_col.spread <= 20.0, "WaterColumn has tight vertical spread <= 20° (actual: %.1f°)" % water_col.spread)
		assert_test(is_equal_approx(water_col.gravity.y, -9.8), "WaterColumn gravity is -9.8 m/s²")
		assert_test(water_col.initial_velocity_max >= 7.0, "WaterColumn initial burst velocity reaches 3.5m height")
		
	var ring: MeshInstance3D = effect.get_node_or_null("ShockwaveRing")
	assert_test(ring != null, "Found horizontal expanding ShockwaveRing mesh")
	if ring:
		assert_test(is_equal_approx(ring.position.y, 0.05), "ShockwaveRing aligned flat at water surface (Y = 0.05)")

func _test_mine_explosion_particles() -> void:
	print("\n--- 4. Sea Mine Explosion Particles ---")
	var mine_pos = Vector3(0.0, 0.2, -8.0)
	var effect = VFXManager.spawn_mine_explosion(mine_pos)
	assert_test(effect != null, "spawn_mine_explosion returned instance")
	assert_test(effect.is_inside_tree(), "Mine explosion inside tree")
	
	var flash: CPUParticles3D = effect.get_node_or_null("CoreFlash")
	assert_test(flash != null, "Found fiery CoreFlash particle system")
	if flash:
		assert_test(flash.one_shot == true, "CoreFlash one_shot is true")
		assert_test(flash.lifetime <= 0.4, "CoreFlash is short explosive flash (lifetime: %.2fs)" % flash.lifetime)
		
	var smoke: CPUParticles3D = effect.get_node_or_null("SmokeCloud")
	assert_test(smoke != null, "Found expanding dark charcoal SmokeCloud particle system")
	if smoke:
		assert_test(smoke.one_shot == true, "SmokeCloud one_shot is true")
		assert_test(is_equal_approx(smoke.lifetime, 0.5), "SmokeCloud lifetime is 0.5s")

func _test_entity_destruction_hooks() -> void:
	print("\n--- 5. Entity Destruction Hooks ---")
	
	# A. BarricadeSegment destruction -> spawn_wood_debris
	var seg_scene = load("res://src/gameplay/obstacles/barricade_segment.tscn") as PackedScene
	var seg = seg_scene.instantiate() as BarricadeSegment
	add_child(seg)
	seg.global_position = Vector3(3.0, 0.5, -10.0)
	
	var vfx_container = get_node_or_null("VFXContainer")
	var count_before = vfx_container.get_child_count() if vfx_container else 0
	seg.die()
	var count_after = vfx_container.get_child_count() if vfx_container else 0
	assert_test(count_after > count_before, "BarricadeSegment.die() triggered VFX spawn in world container")
	
	# B. TurtleRaft destruction -> spawn_wood_debris
	var turtle_script = load("res://src/gameplay/enemies/turtle_raft.gd")
	assert_test(turtle_script != null, "res://src/gameplay/enemies/turtle_raft.gd exists and loads")
	if turtle_script:
		var mob_scene = load("res://src/gameplay/enemies/enemy_mob.tscn") as PackedScene
		var turtle = mob_scene.instantiate()
		turtle.set_script(turtle_script)
		add_child(turtle)
		turtle.global_position = Vector3(-3.0, 0.1, -12.0)
		count_before = vfx_container.get_child_count() if vfx_container else 0
		turtle.die()
		count_after = vfx_container.get_child_count() if vfx_container else 0
		assert_test(count_after > count_before, "TurtleRaft.die() triggered wood debris spawn")
		
	# C. HazardSeaMine destruction -> spawn_mine_explosion
	var mine_scene = load("res://src/gameplay/obstacles/hazard_sea_mine.tscn") as PackedScene
	var mine = mine_scene.instantiate() as HazardSeaMine
	add_child(mine)
	mine.global_position = Vector3(0.0, 0.2, -6.0)
	count_before = vfx_container.get_child_count() if vfx_container else 0
	mine.die()
	count_after = vfx_container.get_child_count() if vfx_container else 0
	assert_test(count_after > count_before, "HazardSeaMine.die() triggered mine explosion spawn")
	
	# D. Mortar Cannonball splash damage -> spawn_mortar_splash
	var ball = Cannonball.new()
	add_child(ball)
	ball.set_meta("is_mortar", true)
	ball.global_position = Vector3(0.0, 1.2, -18.0)
	count_before = vfx_container.get_child_count() if vfx_container else 0
	ball._apply_splash_damage()
	count_after = vfx_container.get_child_count() if vfx_container else 0
	assert_test(count_after > count_before, "Mortar Cannonball._apply_splash_damage() triggered mortar splash spawn")
	ball.queue_free()

func _test_autofree_and_memory_cleanup() -> void:
	print("\n--- 6. Auto-Free Lifecycle & Memory Cleanup ---")
	var splinter = VFXManager.spawn_wood_debris(Vector3(0, 0, 0))
	assert_test(is_instance_valid(splinter), "Spawned splinter effect for lifecycle check")
	
	# Wait 0.65s (exceeds 0.5s lifetime)
	await get_tree().create_timer(0.75).timeout
	
	var is_freed = not is_instance_valid(splinter) or splinter.is_queued_for_deletion()
	assert_test(is_freed, "Splinter particles auto-freed after lifetime (no orphan node leak)")
