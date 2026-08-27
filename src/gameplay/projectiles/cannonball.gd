class_name Cannonball
extends Area3D

## Speed of the cannonball moving forward
@export var speed: float = 50.0

## Total time the cannonball remains active before self-destruction
@export var lifetime: float = 3.0

## Base damage dealt to obstacles
@export var damage: int = 1

## Splash radius multiplier applied when cannonballs exceed soft cap
@export var splash_radius_multiplier: float = 1.0

## Hit splash VFX to spawn on impact or expiration
@export var hit_splash_scene: PackedScene = preload("res://src/gameplay/vfx/hit_splash.tscn")

var _is_destroyed: bool = false

func _ready() -> void:
	add_to_group("cannonballs")
	area_entered.connect(_on_hit)
	body_entered.connect(_on_hit)

func _physics_process(delta: float) -> void:
	if _is_destroyed:
		return
	# Move forward along the negative Z-axis
	global_position.z -= speed * delta
	
	lifetime -= delta
	if lifetime <= 0.0:
		_is_destroyed = true
		set_deferred("monitoring", false)
		set_deferred("monitorable", false)
		AudioManager.play_sfx("water_splashes")
		_spawn_splash()
		queue_free()

func _on_hit(target: Node) -> void:
	if _is_destroyed:
		return
		
	if target.is_in_group("destructible") or target.is_in_group("enemies") or target.has_method("take_damage"):
		_is_destroyed = true
		set_deferred("monitoring", false)
		set_deferred("monitorable", false)
		for child in get_children():
			if child is CollisionShape3D:
				child.set_deferred("disabled", true)
				
		AudioManager.play_sfx("barrel_hits")
		if target.has_method("take_damage"):
			target.take_damage(damage)
			
			# Apply splash AoE to nearby destructibles if boosted
			if splash_radius_multiplier > 1.0:
				_apply_splash_damage()
				
		_spawn_splash()
		queue_free()

func _spawn_splash() -> void:
	if hit_splash_scene:
		var splash = hit_splash_scene.instantiate() as Node3D
		var root = get_tree().current_scene
		if root:
			root.add_child(splash)
		elif get_parent():
			get_parent().add_child(splash)
		splash.global_position = global_position

func _apply_splash_damage() -> void:
	var radius = 2.5 * splash_radius_multiplier
	var targets: Array[Node] = []
	targets.append_array(get_tree().get_nodes_in_group("destructible"))
	targets.append_array(get_tree().get_nodes_in_group("enemies"))
	
	var processed: Dictionary = {}
	for obj in targets:
		if obj != null and is_instance_valid(obj) and obj != self and not processed.has(obj):
			processed[obj] = true
			if obj is Node3D:
				var dist = (obj as Node3D).global_position.distance_to(global_position)
				if dist <= radius and obj.has_method("take_damage"):
					obj.take_damage(damage)
