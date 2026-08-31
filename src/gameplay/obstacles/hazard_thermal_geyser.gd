class_name HazardThermalGeyser
extends Node3D

@export var telegraph_duration: float = 1.6
@export var eruption_duration: float = 1.4
@export var eruption_radius: float = 2.4
@export var damage: int = 1

@onready var telegraph_mesh: MeshInstance3D = $TelegraphMesh
@onready var geyser_mesh: MeshInstance3D = $GeyserMesh
@onready var damage_area: Area3D = $DamageArea

var _state: int = 0 # 0 = telegraph, 1 = erupting, 2 = done
var _timer: float = 0.0

func _ready() -> void:
	add_to_group("hazards")
	if geyser_mesh:
		geyser_mesh.visible = false
	if damage_area:
		damage_area.monitoring = false
		
	AudioManager.play_sfx("water_splashes", 1.4, 1.8, -2.0)

func _physics_process(delta: float) -> void:
	_timer += delta
	
	if _state == 0:
		# Pulsing telegraph
		if telegraph_mesh and telegraph_mesh.material_override:
			var mat = telegraph_mesh.material_override as StandardMaterial3D
			var pulse = 0.3 + sin(_timer * 12.0) * 0.25
			mat.albedo_color.a = pulse
			
		if _timer >= telegraph_duration:
			_state = 1
			_timer = 0.0
			_erupt()
			
	elif _state == 1:
		if _timer >= eruption_duration:
			_state = 2
			queue_free()

func _erupt() -> void:
	if telegraph_mesh:
		telegraph_mesh.visible = false
	if geyser_mesh:
		geyser_mesh.visible = true
		geyser_mesh.scale = Vector3(0.5, 0.1, 0.5)
		var tween = create_tween()
		tween.tween_property(geyser_mesh, "scale", Vector3(1.2, 5.0, 1.2), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(geyser_mesh, "scale", Vector3(1.0, 4.5, 1.0), eruption_duration - 0.25)
		
	if damage_area:
		damage_area.monitoring = true
		
	AudioManager.play_sfx("barrel_breaks", 0.6, 0.8, 3.0)
	AudioManager.play_sfx("water_splashes", 0.7, 0.9, 2.0)
	
	# Camera shake
	var camera = get_tree().get_first_node_in_group("game_camera")
	if camera and camera.has_method("shake"):
		camera.shake(0.28, 0.25)
		
	_check_eruption_hits()

func _check_eruption_hits() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player or not is_instance_valid(player):
		return
		
	var dist = player.global_position.distance_to(global_position)
	if dist <= eruption_radius:
		if player.has_method("damage_fleet"):
			player.damage_fleet(damage)
		# Horizontal push / knockback
		var push_dir = (player.global_position - global_position).normalized()
		player.global_position.x += push_dir.x * 2.0
