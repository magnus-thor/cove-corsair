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

func _ready() -> void:
	add_to_group("cannonballs")
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	# Move forward along the negative Z-axis
	global_position.z -= speed * delta
	
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

func _on_area_entered(area: Area3D) -> void:
	if area.is_in_group("destructible"):
		if area.has_method("take_damage"):
			area.take_damage(damage)
			
			# Apply splash AoE to nearby destructibles if boosted
			if splash_radius_multiplier > 1.0:
				_apply_splash_damage()
				
		queue_free()

func _apply_splash_damage() -> void:
	var radius = 2.5 * splash_radius_multiplier
	var destructibles = get_tree().get_nodes_in_group("destructible")
	for obj in destructibles:
		if obj != null and is_instance_valid(obj) and obj != self:
			if obj is Area3D:
				var dist = obj.global_position.distance_to(global_position)
				if dist <= radius and obj.has_method("take_damage"):
					obj.take_damage(damage)
