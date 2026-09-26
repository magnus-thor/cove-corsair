class_name DeckPlayerController
extends CharacterBody3D

## Player pirate captain defending the deck against boarding swarms.
## Supports free deck movement, zone snapping, blunderbuss cone cleaves,
## and heavy breaker axe rope cutting with full audiovisual feedback.

signal weapon_fired(weapon_type: String)
signal cooldown_updated(current_cd: float, max_cd: float)

@export var targeting_system: DeckTargetingSystem = null
@export var reticle_visual: Node3D = null
@export var station_markers: Dictionary = {} # Dictionary of String -> Marker3D

@export var move_speed: float = 8.0
@export var blunderbuss_damage: float = 18.0
@export var blunderbuss_cone_angle_deg: float = 40.0
@export var blunderbuss_range: float = 10.0
@export var blunderbuss_cooldown: float = 0.55

@export var axe_sever_damage: float = 35.0
@export var axe_cooldown: float = 2.2

var current_target_node: Node3D = null
var aim_target_point: Vector3 = Vector3.ZERO
var target_station_position: Vector3 = Vector3.ZERO
var is_moving_to_station: bool = false

var fire_timer: float = 0.0
var heavy_timer: float = 0.0

@onready var deck_marker: Marker3D = (get_node_or_null("DeckMarker") as Marker3D)
@onready var model_container: Node3D = ($DeckMarker/ModelContainer if has_node("DeckMarker/ModelContainer") else get_node_or_null("ModelContainer")) as Node3D
@onready var placeholder_mesh: MeshInstance3D = ($DeckMarker/MeshInstance3D if has_node("DeckMarker/MeshInstance3D") else get_node_or_null("MeshInstance3D")) as MeshInstance3D
@onready var muzzle_point: Marker3D = %MuzzlePoint
@onready var muzzle_light: OmniLight3D = %MuzzleLight

@export var crew_scale: Vector3 = Vector3(0.55, 0.55, 0.55)

const CREW_MODELS: Dictionary = {
	"monkey_bomber": "res://assets/models/user/crew/monkey_crew.glb",
	"skeleton_tosser": "res://assets/models/user/crew/skeleton_crew.glb",
	"grease_monkey": "res://assets/models/user/crew/artillery_grease__monkey.glb",
	"deckhand_sniper": "res://assets/models/user/crew/weapon_deckhand_sniper.glb"
}
const PLAYER_MODEL_PATH: String = "res://assets/models/user/crew/weapon_deckhand_sniper.glb"

func _ready() -> void:
	if is_instance_valid(targeting_system):
		targeting_system.target_acquired.connect(_on_target_acquired)
		targeting_system.zone_focused.connect(_on_zone_focused)
	target_station_position = global_position
	_load_player_model()

func setup_defender_model(crew_id: String) -> void:
	var glb_path: String = CREW_MODELS.get(crew_id, "") as String
	if glb_path.is_empty():
		glb_path = PLAYER_MODEL_PATH
	_load_player_model(glb_path)

func _load_player_model(glb_path: String = "") -> void:
	if glb_path.is_empty():
		glb_path = PLAYER_MODEL_PATH
	if not is_instance_valid(model_container):
		return
	for child: Node in model_container.get_children():
		child.queue_free()
	if ResourceLoader.exists(glb_path):
		var scene: PackedScene = load(glb_path) as PackedScene
		if scene:
			var model: Node3D = scene.instantiate() as Node3D
			model.scale = crew_scale
			model_container.add_child(model)
			if is_instance_valid(placeholder_mesh):
				placeholder_mesh.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(targeting_system):
		targeting_system.process_input_event(event)
		
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
			fire_heavy_breaker()

func _physics_process(delta: float) -> void:
	_update_timers(delta)
	_update_movement(delta)
	_update_rotation(delta)

func _update_timers(delta: float) -> void:
	if fire_timer > 0.0:
		fire_timer = maxf(fire_timer - delta, 0.0)
	if heavy_timer > 0.0:
		heavy_timer = maxf(heavy_timer - delta, 0.0)
		cooldown_updated.emit(heavy_timer, axe_cooldown)

func _update_movement(delta: float) -> void:
	if not is_moving_to_station:
		return
		
	var dist: float = global_position.distance_to(target_station_position)
	if dist < 0.25:
		global_position = target_station_position
		velocity = Vector3.ZERO
		is_moving_to_station = false
	else:
		var dir: Vector3 = (target_station_position - global_position).normalized()
		velocity = dir * move_speed
		move_and_slide()

func _update_rotation(delta: float) -> void:
	var look_target: Vector3 = aim_target_point
	if is_moving_to_station and velocity.length_squared() > 0.01:
		look_target = global_position + velocity
		
	if look_target == Vector3.ZERO:
		return
		
	var flat_look: Vector3 = Vector3(look_target.x, global_position.y, look_target.z)
	if global_position.is_equal_approx(flat_look):
		return
		
	var target_transform: Transform3D = transform.looking_at(flat_look, Vector3.UP)
	transform.basis = transform.basis.slerp(target_transform.basis, clampf(14.0 * delta, 0.0, 1.0))

func fire_blunderbuss() -> void:
	if fire_timer > 0.0:
		return
		
	fire_timer = blunderbuss_cooldown
	weapon_fired.emit("blunderbuss")
	
	# Audio and Sensory Juice
	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("sfx_scattershot", 0.92, 1.15)
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera and camera.has_method("add_trauma"):
		camera.call("add_trauma", 0.22)
		
	_spawn_muzzle_flash()
	
	var forward: Vector3 = -global_transform.basis.z
	var enemies: Array[Node] = get_tree().get_nodes_in_group("boarder")
	
	for node: Node in enemies:
		var enemy: BoarderEnemy = node as BoarderEnemy
		if not is_instance_valid(enemy) or enemy.is_falling:
			continue
			
		var to_enemy: Vector3 = enemy.global_position - global_position
		var dist: float = to_enemy.length()
		
		if dist <= blunderbuss_range:
			var angle_deg: float = rad_to_deg(forward.angle_to(to_enemy.normalized()))
			if angle_deg <= (blunderbuss_cone_angle_deg * 0.5):
				var falloff: float = 1.0 - (dist / blunderbuss_range) * 0.4
				enemy.take_damage(blunderbuss_damage * falloff)

func fire_heavy_breaker() -> void:
	if heavy_timer > 0.0:
		return
		
	heavy_timer = axe_cooldown
	weapon_fired.emit("heavy_breaker")
	
	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("sfx_wood_smash", 0.85, 1.05)
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera and camera.has_method("add_trauma"):
		camera.call("add_trauma", 0.4)
	
	if is_instance_valid(current_target_node):
		if current_target_node is BoardingPlank:
			var plank: BoardingPlank = current_target_node as BoardingPlank
			plank.take_damage(axe_sever_damage)
		elif current_target_node is BoarderEnemy:
			var enemy: BoarderEnemy = current_target_node as BoarderEnemy
			enemy.take_damage(axe_sever_damage * 2.0)
		elif current_target_node.get_parent() is BoardingPlank:
			var p_plank: BoardingPlank = current_target_node.get_parent() as BoardingPlank
			p_plank.take_damage(axe_sever_damage)

func _on_target_acquired(target_node: Node3D, world_pos: Vector3) -> void:
	current_target_node = target_node
	aim_target_point = world_pos
	
	if is_instance_valid(reticle_visual):
		reticle_visual.global_position = world_pos
		reticle_visual.visible = true
		
	if is_instance_valid(target_node):
		# Target is plank or enemy -> swivel and fire immediately
		var flat_pos: Vector3 = Vector3(world_pos.x, global_position.y, world_pos.z)
		if not global_position.is_equal_approx(flat_pos):
			look_at(flat_pos, Vector3.UP)
			
		if target_node is BoardingPlank or target_node.get_parent() is BoardingPlank:
			fire_heavy_breaker()
		else:
			fire_blunderbuss()
	else:
		# Clicked on floor/deck: jog to position AND swivel to fire
		target_station_position = Vector3(world_pos.x, global_position.y, world_pos.z)
		is_moving_to_station = true
		fire_blunderbuss()

func _on_zone_focused(zone_id: String) -> void:
	if station_markers.has(zone_id):
		var marker: Marker3D = station_markers[zone_id] as Marker3D
		if is_instance_valid(marker):
			target_station_position = marker.global_position
			is_moving_to_station = true

func _spawn_muzzle_flash() -> void:
	if is_instance_valid(muzzle_light):
		muzzle_light.visible = true
		muzzle_light.light_energy = 3.0
		var tw: Tween = create_tween()
		tw.tween_property(muzzle_light, "light_energy", 0.0, 0.08)
		tw.tween_callback(func() -> void:
			if is_instance_valid(muzzle_light):
				muzzle_light.visible = false
		)
