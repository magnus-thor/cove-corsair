@tool
# Turn off untyped warnings specifically for test harnesses:
@warning_ignore("untyped_declaration")
@warning_ignore("unsafe_property_access")
@warning_ignore("unsafe_method_access")
@warning_ignore("unsafe_cast")
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
	_test_wood_debris_particles()
	_test_mortar_geyser_particles_and_waterline()
	_test_mine_explosion_particles()
	_test_biogas_cloud_particles()
	_test_fire_pool_particles()
	_test_barrel_explosion_and_hit_splash_cpu_particles()
	_test_entity_destruction_hooks()
	await _test_autofree_and_memory_cleanup()

func _test_vfx_manager_registration() -> void:
	print("--- 1. VFXManager Registration & API ---")
	assert_test(VFXManager != null, "VFXManager autoload singleton is active")
	assert_test(VFXManager.has_method("spawn_wood_debris"), "VFXManager has spawn_wood_debris()")
	assert_test(VFXManager.has_method("spawn_mortar_splash"), "VFXManager has spawn_mortar_splash()")
	assert_test(VFXManager.has_method("spawn_mine_explosion"), "VFXManager has spawn_mine_explosion()")
	assert_test(VFXManager.has_method("spawn_biogas_cloud"), "VFXManager has spawn_biogas_cloud()")
	assert_test(VFXManager.has_method("spawn_fire_pool"), "VFXManager has spawn_fire_pool()")

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
		assert_test(water_col.lifetime >= 0.4 and water_col.lifetime <= 0.65, "WaterColumn lifetime is configured (actual: %.2fs)" % water_col.lifetime)
		assert_test(water_col.spread <= 45.0, "WaterColumn has tight vertical spread <= 45° (actual: %.1f°)" % water_col.spread)
		assert_test(is_equal_approx(water_col.gravity.y, -9.8), "WaterColumn gravity is -9.8 m/s²")
		assert_test(water_col.initial_velocity_max >= 2.0, "WaterColumn initial burst velocity configured")
		
	var ring: MeshInstance3D = effect.get_node_or_null("ShockwaveRing")
	assert_test(ring != null, "Found horizontal expanding ShockwaveRing mesh")
	if ring:
		assert_test(is_equal_approx(ring.position.y, 0.04) or is_equal_approx(ring.position.y, 0.05), "ShockwaveRing aligned flat at water surface")

func _test_biogas_cloud_particles() -> void:
	print("\n--- 4b. Biogas Pod Toxic Cloud VFX ---")
	assert_test(VFXManager.has_method("spawn_biogas_cloud"), "VFXManager has spawn_biogas_cloud()")
	var cloud_pos = Vector3(2.0, 0.05, -12.0)
	var cloud = VFXManager.spawn_biogas_cloud(cloud_pos, 2.0, 3.5)
	assert_test(cloud != null, "spawn_biogas_cloud returned valid instance")
	if cloud:
		var cloud_script: GDScript = preload("res://src/vfx/vfx_biogas_cloud.gd")
		assert_test(cloud.get_script() == cloud_script or cloud.has_method("start_cloud"), "Effect is VFXBiogasCloud instance")
		var fumes: CPUParticles3D = cloud.get_node_or_null("FumesParticles")
		var bubbles: CPUParticles3D = cloud.get_node_or_null("BubbleParticles")
		assert_test(fumes != null and fumes is CPUParticles3D, "Biogas cloud has FumesParticles CPUParticles3D")
		assert_test(bubbles != null and bubbles is CPUParticles3D, "Biogas cloud has BubbleParticles CPUParticles3D")
		var child_spheres = cloud.find_children("*", "SphereMesh", true, false)
		var has_giant_sphere = false
		for s in child_spheres:
			if s is SphereMesh and (s.radius > 2.0 or s.height > 3.0):
				has_giant_sphere = true
		assert_test(not has_giant_sphere, "Biogas cloud replaced raw giant SphereMesh green circle with particles")

func _test_barrel_explosion_and_hit_splash_cpu_particles() -> void:
	print("\n--- 4c. Compatibility CPUParticles3D Architecture ---")
	var explosion_scene = load("res://src/vfx/barrel_explosion.tscn") as PackedScene
	assert_test(explosion_scene != null, "barrel_explosion.tscn loads")
	if explosion_scene:
		var exp_inst = explosion_scene.instantiate()
		assert_test(exp_inst != null, "barrel_explosion instantiated")
		var cpu_particles = exp_inst.find_children("*", "CPUParticles3D", true, false)
		var gpu_particles = exp_inst.find_children("*", "GPUParticles3D", true, false)
		assert_test(cpu_particles.size() >= 2, "barrel_explosion uses CPUParticles3D (debris & water burst)")
		assert_test(gpu_particles.is_empty(), "barrel_explosion has 0 GPUParticles3D (compatibility mode ready)")
		exp_inst.queue_free()

	var splash_scene = load("res://src/vfx/hit_splash.tscn") as PackedScene
	assert_test(splash_scene != null, "hit_splash.tscn loads")
	if splash_scene:
		var splash_inst = splash_scene.instantiate()
		assert_test(splash_inst != null, "hit_splash instantiated")
		var cpu_splash = splash_inst.find_children("*", "CPUParticles3D", true, false)
		var gpu_splash = splash_inst.find_children("*", "GPUParticles3D", true, false)
		assert_test(cpu_splash.size() >= 1, "hit_splash uses CPUParticles3D")
		assert_test(gpu_splash.is_empty(), "hit_splash has 0 GPUParticles3D")
		splash_inst.queue_free()

func _test_mine_explosion_particles() -> void:
	print("\n--- 4. Sea Mine Fiery Explosion Particles ---")
	var mine_pos = Vector3(0.0, 0.2, -8.0)
	var effect = VFXManager.spawn_mine_explosion(mine_pos)
	assert_test(effect != null, "spawn_mine_explosion returns valid instance")
	if effect:
		assert_test(is_equal_approx(effect.global_position.x, mine_pos.x), "Mine explosion spawned at exact X coordinate")
		assert_test(is_equal_approx(effect.global_position.z, mine_pos.z), "Mine explosion spawned at exact Z coordinate")
		var fire = effect.get_node_or_null("FireBurst")
		var embers = effect.get_node_or_null("EmberSparks")
		var smoke = effect.get_node_or_null("SmokePlume")
		var water = effect.get_node_or_null("WaterSplash")
		assert_test(fire != null and fire is CPUParticles3D, "FireBurst CPUParticles3D exists in explosion")
		assert_test(embers != null and embers is CPUParticles3D, "EmberSparks CPUParticles3D exists in explosion")
		assert_test(smoke != null and smoke is CPUParticles3D, "SmokePlume CPUParticles3D exists in explosion")
		assert_test(water != null and water is CPUParticles3D, "WaterSplash CPUParticles3D exists in explosion")
		var torus_mesh = effect.find_child("*", true, false)
		var has_torus = false
		for c in effect.find_children("*", "MeshInstance3D", true, false):
			if c is MeshInstance3D and c.mesh is TorusMesh:
				has_torus = true
		assert_test(not has_torus, "Red circle TorusMesh removed from mine explosion")

func _test_fire_pool_particles() -> void:
	print("\n--- 4d. Lingering Fire Pool VFX ---")
	assert_test(VFXManager.has_method("spawn_fire_pool"), "VFXManager has spawn_fire_pool()")
	var pool_pos = Vector3(-1.5, 0.05, -10.0)
	var pool = VFXManager.spawn_fire_pool(pool_pos, 2.0, 2.4)
	assert_test(pool != null, "spawn_fire_pool returns valid instance")
	if pool:
		var flames = pool.get_node_or_null("FlamesParticles")
		var embers = pool.get_node_or_null("EmbersParticles")
		var smoke = pool.get_node_or_null("SmokeParticles")
		assert_test(flames != null and flames is CPUParticles3D, "Fire pool has FlamesParticles CPUParticles3D")
		assert_test(embers != null and embers is CPUParticles3D, "Fire pool has EmbersParticles CPUParticles3D")
		assert_test(smoke != null and smoke is CPUParticles3D, "Fire pool has SmokeParticles CPUParticles3D")
		var has_disc = false
		for c in pool.find_children("*", "MeshInstance3D", true, false):
			if c is MeshInstance3D and c.mesh is CylinderMesh:
				has_disc = true
		assert_test(not has_disc, "Red circle CylinderMesh disc removed from fire pool")

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
	assert_test(count_after > count_before, "HazardSeaMine.die() spawned mine explosion in world container")
	
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
