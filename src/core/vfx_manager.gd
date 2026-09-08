extends Node

## Global VFX Spawner managing mobile-optimized combat particles and impacts.

const SCENE_WOOD_SPLINTER: PackedScene = preload("res://src/vfx/vfx_wood_splinter.tscn")
const SCENE_MORTAR_GEYSER: PackedScene = preload("res://src/vfx/vfx_mortar_geyser.tscn")
const SCENE_MINE_EXPLOSION: PackedScene = preload("res://src/vfx/vfx_mine_explosion.tscn")

## Water surface constant
const WATER_SURFACE_MIN_Y: float = 0.0
const WATER_SURFACE_MAX_Y: float = 0.05

func _get_vfx_parent() -> Node:
	var tree = get_tree()
	if not tree:
		return null
		
	var target_scene: Node = null
	if tree.current_scene and is_instance_valid(tree.current_scene):
		target_scene = tree.current_scene
	elif tree.root.get_child_count() > 0:
		target_scene = tree.root.get_child(tree.root.get_child_count() - 1)
	else:
		target_scene = tree.root
		
	if not target_scene or not is_instance_valid(target_scene):
		return null
		
	# World Tree Rooting safeguard: Use a dedicated world-level container
	# so entity queue_free() does not prematurely remove particles.
	var container = target_scene.get_node_or_null("VFXContainer")
	if container and is_instance_valid(container):
		return container
		
	if target_scene is Node3D:
		var new_container = Node3D.new()
		new_container.name = "VFXContainer"
		target_scene.add_child(new_container)
		return new_container
		
	return target_scene

func _spawn_effect(packed_scene: PackedScene, world_pos: Vector3, lifetime: float) -> Node3D:
	if not packed_scene:
		return null
		
	var instance = packed_scene.instantiate() as Node3D
	if not instance:
		return null
		
	var parent = _get_vfx_parent()
	if parent:
		parent.add_child(instance)
	else:
		instance.queue_free()
		return null
		
	instance.global_position = world_pos
	
	# Start emissions and wire auto-free
	if instance is CPUParticles3D:
		var cpu_p = instance as CPUParticles3D
		cpu_p.restart()
		cpu_p.emitting = true
		cpu_p.finished.connect(cpu_p.queue_free)
	elif instance.has_signal("finished"):
		instance.connect("finished", Callable(instance, "queue_free"))
	else:
		var child_particles = instance.find_children("*", "CPUParticles3D", true, false)
		for p in child_particles:
			if p is CPUParticles3D:
				p.restart()
				p.emitting = true
				
	# Fallback timer guarantee to prevent memory leaks in all circumstances
	var tree = get_tree()
	if tree:
		var instance_id: int = instance.get_instance_id()
		var timer = tree.create_timer(lifetime + 0.15)
		timer.timeout.connect(func():
			var obj = instance_from_id(instance_id)
			if obj and is_instance_valid(obj) and not obj.is_queued_for_deletion():
				obj.queue_free()
		)
		
	return instance

## Spawns timber splinters bursting outward with gravity and angular spin.
func spawn_wood_debris(world_pos: Vector3) -> Node3D:
	return _spawn_effect(SCENE_WOOD_SPLINTER, world_pos, 0.5)

## Spawns vertical water geyser and expanding horizontal shockwave ring.
## Waterline Alignment safeguard: Clamps world_pos.y to water surface level (~0.0m - 0.05m).
func spawn_mortar_splash(world_pos: Vector3) -> Node3D:
	var water_aligned_pos = world_pos
	water_aligned_pos.y = clampf(world_pos.y, WATER_SURFACE_MIN_Y, WATER_SURFACE_MAX_Y)
	return _spawn_effect(SCENE_MORTAR_GEYSER, water_aligned_pos, 0.6)

## Spawns fiery orange core flash and expanding dark charcoal smoke cloud.
func spawn_mine_explosion(world_pos: Vector3) -> Node3D:
	return _spawn_effect(SCENE_MINE_EXPLOSION, world_pos, 0.5)
