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

const GAMEPLAY_POSITION: Vector3 = Vector3(0.0, 14.5, 12.0)
const GAMEPLAY_ROTATION: Vector3 = Vector3(-24.5, 0.0, 0.0)
const HARBOR_POSITION: Vector3 = Vector3(0.0, 2.1, 4.8)
const HARBOR_ROTATION: Vector3 = Vector3(-13.5, 0.0, 0.0)

var is_in_harbor_mode: bool = true
var harbor_tween: Tween

# Procedural Trauma & Perlin Noise Shake System
var trauma: float = 0.0
var trauma_reduction_rate: float = 1.25
var max_offset: Vector3 = Vector3(1.2, 0.8, 0.5)
var max_rotation: Vector3 = Vector3(3.5, 3.5, 2.5) # degrees (pitch, yaw, roll)
var noise: FastNoiseLite
var time_elapsed: float = 0.0

func _ready() -> void:
	current = true
	make_current()
	add_to_group("game_camera")
	# Maximize 24-bit Z-buffer precision to eliminate depth fighting on water/shorelines
	near = 0.1
	far = 200.0
	_setup_noise()
	if not GameState.is_game_active:
		set_harbor_mode(true)
	else:
		set_harbor_mode(false)

func _setup_noise() -> void:
	noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.seed = randi() % 100000
	noise.frequency = 4.0
	noise.fractal_octaves = 2

func set_harbor_mode(enabled: bool) -> void:
	is_in_harbor_mode = enabled
	if enabled:
		position = HARBOR_POSITION
		rotation_degrees = HARBOR_ROTATION
		base_position = HARBOR_POSITION
		base_rotation = HARBOR_ROTATION
	else:
		position = GAMEPLAY_POSITION
		rotation_degrees = GAMEPLAY_ROTATION
		base_position = GAMEPLAY_POSITION
		base_rotation = GAMEPLAY_ROTATION

func transition_to_gameplay(duration: float = 0.85) -> void:
	is_in_harbor_mode = false
	if harbor_tween and harbor_tween.is_valid():
		harbor_tween.kill()
	base_position = GAMEPLAY_POSITION
	base_rotation = GAMEPLAY_ROTATION
	harbor_tween = create_tween().set_parallel(true)
	harbor_tween.tween_property(self, "position", GAMEPLAY_POSITION, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	harbor_tween.tween_property(self, "rotation_degrees", GAMEPLAY_ROTATION, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

## Add trauma (0.0 to 1.0) with quadratic falloff and Perlin noise shake
func add_trauma(amount: float) -> void:
	trauma = clamp(trauma + amount, 0.0, 1.0)

## Legacy adapter for existing shake calls
func shake(_duration: float, intensity: float) -> void:
	add_trauma(clamp(intensity * 1.5, 0.1, 0.6))

func _process(delta: float) -> void:
	# Decay trauma
	if trauma > 0.0:
		trauma = max(0.0, trauma - trauma_reduction_rate * delta)

	if is_transitioning and target_node and is_instance_valid(target_node):
		transition_t = min(1.0, transition_t + delta * 1.2)
		var target_pos = target_node.global_position
		var player = get_tree().get_first_node_in_group("player")
		var player_z = player.global_position.z if (player and is_instance_valid(player)) else 0.0
		
		var arena_mid_z = (player_z + target_pos.z) * 0.5
		var desired_pos = Vector3(0.0, 16.0, player_z + 12.0)
		global_position = global_position.lerp(desired_pos, 2.5 * delta)
		
		var look_target = Vector3(0.0, 0.4, arena_mid_z - 1.0)
		var current_look = global_transform.looking_at(look_target, Vector3.UP)
		global_transform = global_transform.interpolate_with(current_look, 2.5 * delta)
	elif not is_in_harbor_mode:
		if harbor_tween and harbor_tween.is_valid() and harbor_tween.is_running():
			return

		if trauma > 0.0:
			time_elapsed += delta * 25.0
			var shake_sq = trauma * trauma # Quadratic falloff

			if not noise:
				_setup_noise()

			var sample_x = noise.get_noise_2d(time_elapsed, 10.0)
			var sample_y = noise.get_noise_2d(time_elapsed, 25.0)
			var sample_z = noise.get_noise_2d(time_elapsed, 40.0)

			var sample_rx = noise.get_noise_2d(time_elapsed, 55.0)
			var sample_ry = noise.get_noise_2d(time_elapsed, 70.0)
			var sample_rz = noise.get_noise_2d(time_elapsed, 85.0)

			var offset_x = max_offset.x * shake_sq * sample_x
			var offset_y = max_offset.y * shake_sq * sample_y
			var offset_z = max_offset.z * shake_sq * sample_z

			var rot_x = max_rotation.x * shake_sq * sample_rx
			var rot_y = max_rotation.y * shake_sq * sample_ry
			var rot_z = max_rotation.z * shake_sq * sample_rz

			if is_nan(offset_x) or is_nan(offset_y) or is_nan(offset_z) or is_nan(rot_x) or is_nan(rot_y) or is_nan(rot_z) or is_inf(offset_x) or is_inf(offset_y) or is_inf(offset_z):
				position = base_position
				rotation_degrees = base_rotation
			else:
				position = base_position + Vector3(offset_x, offset_y, offset_z)
				rotation_degrees = base_rotation + Vector3(rot_x, rot_y, rot_z)
		elif shake_timer > 0.0:
			shake_timer -= delta
			var offset = Vector3(
				randf_range(-1.0, 1.0) * shake_intensity,
				randf_range(-1.0, 1.0) * shake_intensity,
				randf_range(-1.0, 1.0) * shake_intensity
			)
			position = base_position + offset
			if shake_timer <= 0.0:
				position = base_position
				rotation_degrees = base_rotation
		else:
			position = base_position
			rotation_degrees = base_rotation

func start_boss_focus(boss: Node3D) -> void:
	target_node = boss
	is_transitioning = true
	transition_t = 0.0
	original_transform = global_transform
