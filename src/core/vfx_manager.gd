extends Node

## Global VFX Spawner managing mobile-optimized combat particles and impacts.

const SCENE_WOOD_SPLINTER: PackedScene = preload("res://src/vfx/vfx_wood_splinter.tscn")
const SCENE_IRON_SPARKS: PackedScene = preload("res://src/vfx/vfx_iron_sparks.tscn")
const SCENE_MORTAR_GEYSER: PackedScene = preload("res://src/vfx/vfx_mortar_geyser.tscn")
const SCENE_MINE_EXPLOSION: PackedScene = preload("res://src/vfx/vfx_mine_explosion.tscn")
const SCENE_COIN_BURST: PackedScene = preload("res://src/vfx/vfx_coin_burst.tscn")
const SCENE_BIOGAS_CLOUD: PackedScene = preload("res://src/vfx/vfx_biogas_cloud.tscn")
const SCENE_FIRE_POOL: PackedScene = preload("res://src/vfx/vfx_fire_pool.tscn")

## Water surface constant
const WATER_SURFACE_MIN_Y: float = 0.0
const WATER_SURFACE_MAX_Y: float = 0.05

func _get_vfx_parent() -> Node:
	var tree: SceneTree = get_tree()
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
	var container: Node = target_scene.get_node_or_null("VFXContainer")
	if container and is_instance_valid(container):
		return container
		
	if target_scene is Node3D:
		var new_container: Node3D = Node3D.new()
		new_container.name = "VFXContainer"
		target_scene.add_child(new_container)
		return new_container
		
	return target_scene

func _spawn_effect(packed_scene: PackedScene, world_pos: Vector3, lifetime: float) -> Node3D:
	if not packed_scene:
		return null
		
	var instance: Node3D = packed_scene.instantiate() as Node3D
	if not instance:
		return null
		
	# Ensure top_level = true and set position to world_pos before add_child
	# so that any child nodes or particle emitters in _ready() execute at the
	# exact world coordinates rather than inheriting parent/scene offsets (e.g. user vessel at Z = -33.36m).
	instance.top_level = true
	instance.position = world_pos
	
	var parent: Node = _get_vfx_parent()
	if parent:
		parent.add_child(instance)
	else:
		instance.queue_free()
		return null
		
	instance.global_position = world_pos
	
	# Start emissions and wire auto-free
	if instance is CPUParticles3D:
		var cpu_p: CPUParticles3D = instance as CPUParticles3D
		cpu_p.restart()
		cpu_p.emitting = true
		cpu_p.finished.connect(cpu_p.queue_free)
	elif instance.has_signal("finished"):
		instance.connect("finished", Callable(instance, "queue_free"))
	else:
		var child_particles: Array[Node] = instance.find_children("*", "CPUParticles3D", true, false)
		for p: Node in child_particles:
			if p is CPUParticles3D:
				var cp: CPUParticles3D = p as CPUParticles3D
				cp.restart()
				cp.emitting = true
				
	# Fallback timer guarantee to prevent memory leaks in all circumstances
	var tree: SceneTree = get_tree()
	if tree:
		var instance_id: int = instance.get_instance_id()
		var timer: SceneTreeTimer = tree.create_timer(lifetime + 0.15)
		timer.timeout.connect(func() -> void:
			var obj: Object = instance_from_id(instance_id)
			if obj and is_instance_valid(obj) and obj is Node and not (obj as Node).is_queued_for_deletion():
				(obj as Node).queue_free()
		)
		
	return instance

## Spawns timber splinters bursting outward with gravity and angular spin.
func spawn_wood_debris(world_pos: Vector3) -> Node3D:
	return _spawn_effect(SCENE_WOOD_SPLINTER, world_pos, 0.5)

## Spawns vertical water geyser and expanding horizontal shockwave ring.
## Waterline Alignment safeguard: Clamps world_pos.y to water surface level (~0.0m - 0.05m).
func spawn_mortar_splash(world_pos: Vector3) -> Node3D:
	var water_aligned_pos: Vector3 = world_pos
	water_aligned_pos.y = clampf(world_pos.y, WATER_SURFACE_MIN_Y, WATER_SURFACE_MAX_Y)
	return _spawn_effect(SCENE_MORTAR_GEYSER, water_aligned_pos, 0.6)

## Spawns fiery sea mine explosion with core flash and smoke shockwave.
func spawn_mine_explosion(world_pos: Vector3) -> Node3D:
	return _spawn_effect(SCENE_MINE_EXPLOSION, world_pos, 0.45)

## Alias for explosion spawning at a world coordinate.
func spawn_explosion(world_pos: Vector3) -> Node3D:
	return spawn_mine_explosion(world_pos)

## Spawns fountain burst of golden coin particles erupting upward upon chest collection.
func spawn_coin_burst(world_pos: Vector3) -> Node3D:
	return _spawn_effect(SCENE_COIN_BURST, world_pos, 0.7)

## Spawns fiery metal spark burst upon hitting armored vessels or obstacles.
func spawn_iron_sparks(world_pos: Vector3) -> Node3D:
	return _spawn_effect(SCENE_IRON_SPARKS, world_pos, 0.35)

## Spawns stylized billowing toxic marsh gas fumes and bubbling water surface particles.
func spawn_biogas_cloud(world_pos: Vector3, duration: float = 2.5, radius: float = 4.2) -> Node3D:
	var effect: Node3D = _spawn_effect(SCENE_BIOGAS_CLOUD, world_pos, duration + 0.5)
	if effect and effect.has_method("start_cloud"):
		effect.call("start_cloud", duration, radius)
	return effect

## Spawns stylized lingering fire pool with licking flames and embers on water surface.
func spawn_fire_pool(world_pos: Vector3, duration: float = 2.0, radius: float = 2.4) -> Node3D:
	var effect: Node3D = _spawn_effect(SCENE_FIRE_POOL, world_pos, duration + 0.5)
	if effect and effect.has_method("start_fire_pool"):
		effect.call("start_fire_pool", duration, radius)
	return effect

var _is_hit_stopping: bool = false

## Arcade micro-freeze frame (hit stop) to give impacts crunch.
## Uses ignore_time_scale so the freeze duration is in unscaled wall-clock time.
func hit_stop(duration_sec: float = 0.045, time_scale: float = 0.05) -> void:
	if _is_hit_stopping:
		return
	var tree: SceneTree = get_tree()
	if not tree:
		return
	_is_hit_stopping = true
	Engine.time_scale = clampf(time_scale, 0.01, 1.0)
	var timer: SceneTreeTimer = tree.create_timer(duration_sec, true, false, true)
	timer.timeout.connect(func() -> void:
		Engine.time_scale = 1.0
		_is_hit_stopping = false
	)
