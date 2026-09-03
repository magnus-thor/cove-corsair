class_name GameCamera
extends Camera3D

var shake_timer: float = 0.0
var shake_intensity: float = 0.0
var base_position: Vector3
var base_rotation: Vector3
var target_node: Node3D = null
var is_transitioning: bool = false
var transition_t: float = 0.0
var original_transform: Transform3D

func _ready() -> void:
	base_position = position
	base_rotation = rotation_degrees
	add_to_group("game_camera")

func _process(delta: float) -> void:
	if is_transitioning and target_node and is_instance_valid(target_node):
		transition_t = min(1.0, transition_t + delta * 1.2)
		var target_pos = target_node.global_position
		var player = get_tree().get_first_node_in_group("player")
		var player_z = player.global_position.z if (player and is_instance_valid(player)) else 0.0
		
		# Midpoint of the combat arena between player and boss
		var arena_mid_z = (player_z + target_pos.z) * 0.5
		
		# Elevated and pulled back camera position to cleanly frame both player fleet and boss
		var desired_pos = Vector3(0.0, 16.0, player_z + 12.0)
		global_position = global_position.lerp(desired_pos, 2.5 * delta)
		
		# Look at the combat arena so both player and boss are framed with player at lower screen
		var look_target = Vector3(0.0, 0.4, arena_mid_z - 1.0)
		var current_look = global_transform.looking_at(look_target, Vector3.UP)
		global_transform = global_transform.interpolate_with(current_look, 2.5 * delta)
	else:
		if shake_timer > 0.0:
			shake_timer -= delta
			var offset = Vector3(
				randf_range(-1.0, 1.0) * shake_intensity,
				randf_range(-1.0, 1.0) * shake_intensity,
				randf_range(-1.0, 1.0) * shake_intensity
			)
			position = base_position + offset
			if shake_timer <= 0.0:
				position = base_position
		else:
			position = base_position

func shake(duration: float, intensity: float) -> void:
	shake_timer = duration
	shake_intensity = intensity

func start_boss_focus(boss: Node3D) -> void:
	target_node = boss
	is_transitioning = true
	transition_t = 0.0
	original_transform = global_transform
