class_name Cannonball
extends Area3D

## Speed of the cannonball moving forward
@export var speed: float = 50.0

## Total time the cannonball remains active before self-destruction
@export var lifetime: float = 3.0

func _ready() -> void:
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
			area.take_damage(1)
		queue_free()

