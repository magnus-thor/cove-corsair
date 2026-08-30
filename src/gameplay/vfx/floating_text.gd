class_name FloatingText
extends Label3D

var velocity: Vector3 = Vector3(0, 2.0, 0)
var lifetime: float = 0.8

func _ready() -> void:
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	double_sided = false
	no_depth_test = true
	font_size = 48
	outline_size = 12
	outline_modulate = Color.BLACK
	
func setup(text_val: String, color_val: Color = Color.WHITE, start_velocity: Vector3 = Vector3(0, 2.5, 0)) -> void:
	text = text_val
	modulate = color_val
	velocity = start_velocity

func _process(delta: float) -> void:
	global_position += velocity * delta
	velocity = velocity.lerp(Vector3.ZERO, delta * 2.0)
	
	lifetime -= delta
	if lifetime <= 0.3:
		modulate.a = clamp(lifetime / 0.3, 0.0, 1.0)
	
	if lifetime <= 0.0:
		queue_free()
