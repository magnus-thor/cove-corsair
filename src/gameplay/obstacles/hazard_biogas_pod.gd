class_name HazardBiogasPod
extends Area3D

@export var hp: int = 1
@export var cloud_duration: float = 2.5
@export var cloud_radius: float = 4.2
@export var damage_per_tick: int = 3
@export var tick_interval: float = 0.4

@export var forward_speed: float = 3.0

var _is_popped: bool = false
var _pulse_time: float = 0.0
## Per-cloud player damage cooldown (seconds). Prevents fleet-wipe on first tick.
var _player_damage_cooldown: float = 0.0

@onready var pod_mesh: MeshInstance3D = get_node_or_null("PodMesh")
@onready var pod_sprite: Sprite3D = get_node_or_null("PodSprite") as Sprite3D
@onready var collision_shape: CollisionShape3D = get_node_or_null("CollisionShape3D")

func _ready() -> void:
	add_to_group("destructible")
	add_to_group("hazards")
	_pulse_time = randf_range(0.0, TAU)

func _physics_process(delta: float) -> void:
	if _is_popped:
		return
	if forward_speed != 0.0:
		global_position.z += forward_speed * delta
		var player := get_tree().get_first_node_in_group("player")
		var player_z: float = player.global_position.z if player else 0.0
		if global_position.z > (player_z + 8.0):
			queue_free()
			return

	_pulse_time += delta * 4.0
	var scale_factor := 1.0 + sin(_pulse_time) * 0.12
	if pod_sprite:
		pod_sprite.scale = Vector3(scale_factor, scale_factor * 1.1, scale_factor)
	elif pod_mesh:
		pod_mesh.scale = Vector3(scale_factor, scale_factor * 1.1, scale_factor)

func take_damage(amount: int) -> void:
	if _is_popped:
		return
	hp -= amount
	if hp <= 0:
		explode_corrosive_cloud()

func explode_corrosive_cloud() -> void:
	if _is_popped:
		return
	_is_popped = true
	
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	if pod_sprite:
		pod_sprite.visible = false
	if pod_mesh:
		pod_mesh.visible = false

		
	AudioManager.play_sfx("barrel_breaks", 1.2, 1.5, 2.0)
	AudioManager.play_sfx("water_splashes", 0.7, 0.9, 1.0)
	
	# Spawn Floating Alert
	var ft_script := load("res://src/vfx/floating_text.gd")
	if ft_script:
		var fct: Variant = ft_script.new()
		var root := get_tree().current_scene
		if root:
			root.add_child(fct)
			fct.global_position = global_position + Vector3(0, 1.4, 0)
			fct.setup("BIO-GAS EXPLOSION!", Color(0.2, 1.0, 0.4))
			
	# Camera shake
	var camera := get_tree().get_first_node_in_group("game_camera")
	if camera and camera.has_method("shake"):
		camera.shake(0.2, 0.18)

	_spawn_gas_cloud_area()

func _spawn_gas_cloud_area() -> void:
	var cloud_root := Node3D.new()
	var root := get_tree().current_scene
	if root:
		root.add_child(cloud_root)
	else:
		get_parent().add_child(cloud_root)
	cloud_root.global_position = global_position

	# Toxic Green Cloud Visual Sphere
	var cloud_mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = cloud_radius
	sphere.height = cloud_radius * 1.6
	cloud_mesh.mesh = sphere
	
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.15, 0.85, 0.25, 0.4)
	cloud_mesh.material_override = mat
	cloud_root.add_child(cloud_mesh)
	
	# Cloud pulse animation
	var tween := cloud_root.create_tween()
	tween.tween_property(cloud_mesh, "scale", Vector3(1.1, 0.9, 1.1), cloud_duration * 0.5).set_trans(Tween.TRANS_SINE)
	tween.tween_property(mat, "albedo_color:a", 0.0, cloud_duration * 0.5)

	# Active ticking damage timer
	var tracker: Dictionary = {"elapsed": 0.0}
	var timer := Timer.new()
	timer.wait_time = tick_interval
	timer.autostart = true
	cloud_root.add_child(timer)
	
	timer.timeout.connect(func() -> void:
		tracker["elapsed"] += tick_interval
		_player_damage_cooldown = max(0.0, _player_damage_cooldown - tick_interval)
		_damage_enemies_in_cloud(cloud_root.global_position, cloud_radius)
		if tracker["elapsed"] >= cloud_duration:
			timer.stop()
			cloud_root.queue_free()
	)
	
	# Initial tick
	_damage_enemies_in_cloud(cloud_root.global_position, cloud_radius)
	
	queue_free()

func _damage_enemies_in_cloud(center: Vector3, radius: float) -> void:
	var targets: Array[Node] = []
	targets.append_array(get_tree().get_nodes_in_group("enemies"))
	targets.append_array(get_tree().get_nodes_in_group("destructible"))
	
	var processed: Dictionary = {}
	for obj in targets:
		if obj != null and is_instance_valid(obj) and not processed.has(obj):
			processed[obj] = true
			if obj is Node3D:
				var dist := (obj as Node3D).global_position.distance_to(center)
				if dist <= radius and obj.has_method("take_damage"):
					obj.take_damage(damage_per_tick)
	
	# Damage the player fleet with a 1.0 s cooldown to prevent instant fleet-wipe.
	var player := get_tree().get_first_node_in_group("player")
	if player and is_instance_valid(player) and _player_damage_cooldown <= 0.0:
		var player_dist := (player as Node3D).global_position.distance_to(center)
		if player_dist <= radius:
			_player_damage_cooldown = 1.0
			if player.has_method("leak_threat"):
				player.leak_threat(self)
