class_name DeckPlayerController
extends CharacterBody3D

## Player crew defender defending the deck against boarding swarms.
## Supports tap-to-move repositioning, autonomous auto-attacks on approaching
## boarders, and unique crew-specific Special Attacks with cooldowns.

signal weapon_fired(weapon_type: String)
signal cooldown_updated(current_cd: float, max_cd: float)
signal special_cooldown_updated(current_cd: float, max_cd: float)
signal crew_role_changed(role_name: String, ability_name: String)
signal health_changed(current_hp: float, max_hp: float)
signal player_defeated()

@export var targeting_system: DeckTargetingSystem = null
@export var reticle_visual: Node3D = null
@export var station_markers: Dictionary = {} # Dictionary of String -> Marker3D

@export var move_speed: float = 7.5
@export var blunderbuss_damage: float = 18.0
@export var blunderbuss_cone_angle_deg: float = 50.0
@export var blunderbuss_range: float = 7.0
@export var blunderbuss_cooldown: float = 0.55

@export var auto_attack_range: float = 6.0
@export var auto_attack_cooldown: float = 0.65
@export var auto_attack_damage: float = 16.0

@export var axe_sever_damage: float = 35.0
@export var axe_cooldown: float = 2.2

@export var special_cooldown: float = 6.0
var special_timer: float = 0.0

var current_target_node: Node3D = null
var selected_plank: BoardingPlank = null
var aim_target_point: Vector3 = Vector3.ZERO
var target_station_position: Vector3 = Vector3.ZERO
var is_moving_to_station: bool = false
var initial_deck_position: Vector3 = Vector3.ZERO
var initial_deck_local_position: Vector3 = Vector3.ZERO

@export var max_health: float = 100.0
var current_health: float = 100.0

var fire_timer: float = 0.0
var heavy_timer: float = 0.0
var auto_attack_timer: float = 0.0

var current_crew_id: String = ""
var crew_role: String = "" # "bomber", "sniper", "swordsman", "mechanic"
var special_ability_name: String = ""
var has_crew: bool = false

@onready var deck_marker: Marker3D = (get_node_or_null("DeckMarker") as Marker3D)
@onready var model_container: Node3D = ($DeckMarker/ModelContainer if has_node("DeckMarker/ModelContainer") else get_node_or_null("ModelContainer")) as Node3D
@onready var placeholder_mesh: MeshInstance3D = ($DeckMarker/MeshInstance3D if has_node("DeckMarker/MeshInstance3D") else get_node_or_null("MeshInstance3D")) as MeshInstance3D
@onready var muzzle_point: Marker3D = %MuzzlePoint
@onready var muzzle_light: OmniLight3D = %MuzzleLight

@export var crew_scale: Vector3 = Vector3(0.55, 0.55, 0.55)

@export_group("Deck Clamping")
@export var deck_half_width: float = 1.6
@export var deck_half_length: float = 4.5
var _initial_deck_x: float = 0.0
var _initial_deck_z: float = 0.0

const CREW_MODELS: Dictionary = {
	"monkey_bomber": "res://assets/models/user/crew/monkey_crew.glb",
	"skeleton_tosser": "res://assets/models/user/crew/skeleton_crew.glb",
	"grease_monkey": "res://assets/models/user/crew/artillery_grease__monkey.glb",
	"deckhand_sniper": "res://assets/models/user/crew/weapon_deckhand_sniper.glb"
}
const PLAYER_MODEL_PATH: String = "res://assets/models/user/crew/weapon_deckhand_sniper.glb"

func _ready() -> void:
	add_to_group("crew_defender")
	add_to_group("player")
	current_health = max_health
	initial_deck_local_position = position
	initial_deck_position = global_position
	_initial_deck_x = global_position.x
	_initial_deck_z = global_position.z
	target_station_position = global_position
	is_moving_to_station = false
	rotation.x = 0.0
	rotation.z = 0.0
	if is_instance_valid(targeting_system):
		targeting_system.target_acquired.connect(_on_target_acquired)
		targeting_system.zone_focused.connect(_on_zone_focused)
	if not current_crew_id.is_empty():
		_load_player_model()
		_configure_crew_role(current_crew_id)
	else:
		_clear_player_model()
		_configure_crew_role("")

func set_deck_anchor(global_xform: Transform3D) -> void:
	global_transform = global_xform
	initial_deck_local_position = position
	initial_deck_position = global_position
	_initial_deck_x = global_position.x
	_initial_deck_z = global_position.z
	target_station_position = global_position

func setup_defender_model(new_crew_id: String) -> void:
	current_crew_id = new_crew_id
	if new_crew_id.is_empty():
		has_crew = false
		_clear_player_model()
		_configure_crew_role("")
		return
	has_crew = true
	var glb_path: String = CREW_MODELS.get(new_crew_id, "") as String
	if glb_path.is_empty():
		glb_path = PLAYER_MODEL_PATH
	_load_player_model(glb_path)
	_configure_crew_role(new_crew_id)

func _configure_crew_role(cid: String) -> void:
	if cid.is_empty():
		has_crew = false
		crew_role = ""
		special_ability_name = ""
		crew_role_changed.emit("", "")
		return
	has_crew = true
	var c_lower: String = cid.to_lower()
	if c_lower.contains("bomber") or c_lower.contains("monkey") and not c_lower.contains("grease"):
		crew_role = "bomber"
		special_ability_name = "Powder Keg Blast"
		special_cooldown = 5.5
	elif c_lower.contains("sniper"):
		crew_role = "sniper"
		special_ability_name = "Piercing Flintlock"
		special_cooldown = 4.8
	elif c_lower.contains("skeleton") or c_lower.contains("tosser") or c_lower.contains("sword"):
		crew_role = "swordsman"
		special_ability_name = "Whirlwind Cleave"
		special_cooldown = 4.2
	elif c_lower.contains("grease") or c_lower.contains("artillery") or c_lower.contains("mechanic"):
		crew_role = "mechanic"
		special_ability_name = "Sticky Tar Slick"
		special_cooldown = 6.5
	else:
		crew_role = "sniper"
		special_ability_name = "Piercing Flintlock"
		special_cooldown = 5.0
		
	crew_role_changed.emit(crew_role, special_ability_name)

func _clear_player_model() -> void:
	if is_instance_valid(model_container):
		for child: Node in model_container.get_children():
			child.queue_free()
	if is_instance_valid(placeholder_mesh):
		placeholder_mesh.visible = false

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
			model_container.rotation.y = PI
			if is_instance_valid(placeholder_mesh):
				placeholder_mesh.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(targeting_system):
		targeting_system.process_input_event(event)
		
	if not has_crew:
		return

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
			fire_special_attack()
	elif event is InputEventKey:
		var ek: InputEventKey = event as InputEventKey
		if ek.pressed and (ek.keycode == KEY_SPACE or ek.keycode == KEY_E):
			fire_special_attack()

func _physics_process(delta: float) -> void:
	# Crew member stays in the same place always on the ship deck (anchored to vessel local position)
	position = initial_deck_local_position
	velocity = Vector3.ZERO
	is_moving_to_station = false
	
	_update_timers(delta)
	_update_rotation(delta)
	_process_auto_attack(delta)

func take_damage(amount: float) -> void:
	if current_health <= 0.0:
		return
	current_health = maxf(current_health - amount, 0.0)
	health_changed.emit(current_health, max_health)
	HitFlashComponent.flash_node(self, 0.08)
	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("barrel_hits", 0.95, 1.15)
	if current_health <= 0.0:
		player_defeated.emit()

func _update_timers(delta: float) -> void:
	if fire_timer > 0.0:
		fire_timer = maxf(fire_timer - delta, 0.0)
	if heavy_timer > 0.0:
		heavy_timer = maxf(heavy_timer - delta, 0.0)
		cooldown_updated.emit(heavy_timer, axe_cooldown)
	if special_timer > 0.0:
		special_timer = maxf(special_timer - delta, 0.0)
		special_cooldown_updated.emit(special_timer, special_cooldown)
	if auto_attack_timer > 0.0:
		auto_attack_timer = maxf(auto_attack_timer - delta, 0.0)

func _update_rotation(delta: float) -> void:
	var look_target: Vector3 = aim_target_point
	if is_instance_valid(selected_plank):
		look_target = selected_plank.global_position
		
	if look_target == Vector3.ZERO:
		rotation.x = 0.0
		rotation.z = 0.0
		return
		
	var parent_3d: Node3D = get_parent_node_3d()
	var to_target_local: Vector3
	if is_instance_valid(parent_3d):
		to_target_local = parent_3d.to_local(look_target) - position
	else:
		to_target_local = look_target - position
		
	to_target_local.y = 0.0
	if to_target_local.length_squared() > 0.001:
		var target_yaw: float = atan2(-to_target_local.x, -to_target_local.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, clampf(14.0 * delta, 0.0, 1.0))
		
	rotation.x = 0.0
	rotation.z = 0.0

func _process_auto_attack(_delta: float) -> void:
	if auto_attack_timer > 0.0:
		return

	var nearest_enemy: BoarderEnemy = _find_nearest_boarder(auto_attack_range)
	if is_instance_valid(nearest_enemy):
		auto_attack_timer = auto_attack_cooldown
		_execute_auto_attack(nearest_enemy)

func _find_nearest_boarder(max_dist: float) -> BoarderEnemy:
	var enemies: Array[Node] = get_tree().get_nodes_in_group("boarder")
	var best_enemy: BoarderEnemy = null
	var best_dist: float = max_dist
	
	if is_instance_valid(selected_plank) and selected_plank.is_queued_for_deletion():
		selected_plank = null
		
	# When a plank is selected, ONLY fire at enemies on that selected plank or its zone
	if is_instance_valid(selected_plank):
		var target_zone: BoardingZone = selected_plank.target_zone
		for node: Node in enemies:
			var enemy: BoarderEnemy = node as BoarderEnemy
			if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or enemy.is_falling or enemy.has_breached or enemy.is_dead:
				continue
			var is_on_this_plank: bool = (enemy.active_plank == selected_plank)
			var is_in_this_zone: bool = (is_instance_valid(target_zone) and enemy.current_zone == target_zone)
			if is_on_this_plank or is_in_this_zone:
				var dist: float = global_position.distance_to(enemy.global_position)
				if dist < best_dist:
					best_dist = dist
					best_enemy = enemy
		return best_enemy
			
	# Fallback only when no plank is selected at all
	for node: Node in enemies:
		var enemy: BoarderEnemy = node as BoarderEnemy
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or enemy.is_falling or enemy.has_breached or enemy.is_dead:
			continue
		var dist: float = global_position.distance_to(enemy.global_position)
		if dist < best_dist:
			best_dist = dist
			best_enemy = enemy
			
	return best_enemy

func _execute_auto_attack(target: BoarderEnemy) -> void:
	if not is_instance_valid(target):
		return
		
	# If no specific plank is selected, aim at target
	if not is_instance_valid(selected_plank):
		aim_target_point = target.global_position
		
	_spawn_muzzle_flash()
	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("sfx_scattershot", 0.95, 1.15)
		
	target.take_damage(auto_attack_damage)
	target.apply_stagger(0.25)

func fire_blunderbuss() -> void:
	if fire_timer > 0.0:
		return
		
	fire_timer = blunderbuss_cooldown
	weapon_fired.emit("blunderbuss")
	
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
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or enemy.is_falling:
			continue
			
		var to_enemy: Vector3 = enemy.global_position - global_position
		var dist: float = to_enemy.length()
		
		if dist <= blunderbuss_range:
			var angle_deg: float = rad_to_deg(forward.angle_to(to_enemy.normalized()))
			if angle_deg <= (blunderbuss_cone_angle_deg * 0.5):
				var falloff: float = 1.0 - (dist / blunderbuss_range) * 0.4
				enemy.take_damage(blunderbuss_damage * falloff)
				enemy.apply_stagger(0.3)

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
			enemy.apply_stagger(0.4)
		elif current_target_node.get_parent() is BoardingPlank:
			var p_plank: BoardingPlank = current_target_node.get_parent() as BoardingPlank
			p_plank.take_damage(axe_sever_damage)

func fire_special_attack() -> void:
	if not has_crew or crew_role.is_empty():
		return
	if special_timer > 0.0:
		return
		
	special_timer = special_cooldown
	special_cooldown_updated.emit(special_timer, special_cooldown)
	weapon_fired.emit("special_%s" % crew_role)
	
	match crew_role:
		"bomber":
			_execute_special_bomber()
		"sniper":
			_execute_special_sniper()
		"swordsman":
			_execute_special_swordsman()
		"mechanic":
			_execute_special_mechanic()
		_:
			_execute_special_sniper()

func _execute_special_bomber() -> void:
	# Powder Keg: Finds enemy cluster or forward spot and nukes with heavy AoE damage
	var target_pos: Vector3 = global_position + (-global_transform.basis.z * 3.5)
	var target_enemy: BoarderEnemy = _find_nearest_boarder(8.0)
	if is_instance_valid(target_enemy):
		target_pos = target_enemy.global_position

	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("sfx_mortar_impact", 0.9, 1.1)
		
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera and camera.has_method("add_trauma"):
		camera.call("add_trauma", 0.45)

	var enemies: Array[Node] = get_tree().get_nodes_in_group("boarder")
	for node: Node in enemies:
		var enemy: BoarderEnemy = node as BoarderEnemy
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion() and not enemy.is_falling:
			var dist: float = target_pos.distance_to(enemy.global_position)
			if dist <= 3.2:
				enemy.take_damage(45.0)
				enemy.apply_stagger(0.6)

func _execute_special_sniper() -> void:
	# Piercing Flintlock: Pierces all enemies in a 12m forward line
	_spawn_muzzle_flash()
	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("cannon_shots", 1.0, 1.25)
		
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera and camera.has_method("add_trauma"):
		camera.call("add_trauma", 0.35)

	var forward: Vector3 = -global_transform.basis.z
	var enemies: Array[Node] = get_tree().get_nodes_in_group("boarder")
	for node: Node in enemies:
		var enemy: BoarderEnemy = node as BoarderEnemy
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion() and not enemy.is_falling:
			var to_enemy: Vector3 = enemy.global_position - global_position
			var proj_dist: float = to_enemy.dot(forward)
			if proj_dist > 0.0 and proj_dist <= 12.0:
				var perp_dist: float = (to_enemy - forward * proj_dist).length()
				if perp_dist <= 1.2:
					enemy.take_damage(60.0)
					enemy.apply_stagger(0.4)

func _execute_special_swordsman() -> void:
	# 360 Whirlwind Cleave: Slices all enemies within 3.5m radius around crew member
	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("sfx_wood_smash", 1.1, 1.3)
		
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera and camera.has_method("add_trauma"):
		camera.call("add_trauma", 0.3)

	# Quick spin tween for visual punch
	var spin_tw: Tween = create_tween()
	spin_tw.tween_property(self, "rotation:y", rotation.y + TAU, 0.25)

	var enemies: Array[Node] = get_tree().get_nodes_in_group("boarder")
	for node: Node in enemies:
		var enemy: BoarderEnemy = node as BoarderEnemy
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion() and not enemy.is_falling:
			var dist: float = global_position.distance_to(enemy.global_position)
			if dist <= 3.5:
				enemy.take_damage(35.0)
				enemy.apply_stagger(0.5)

func _execute_special_mechanic() -> void:
	# Sticky Tar Slick: Slows all enemies in 4.5m radius by 75% for 6 seconds
	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("barrel_breaks", 0.85, 1.05)
		
	var enemies: Array[Node] = get_tree().get_nodes_in_group("boarder")
	for node: Node in enemies:
		var enemy: BoarderEnemy = node as BoarderEnemy
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion() and not enemy.is_falling:
			var dist: float = global_position.distance_to(enemy.global_position)
			if dist <= 4.5:
				enemy.apply_slow(0.25, 6.0)
				enemy.take_damage(12.0)

func select_plank(plank: BoardingPlank) -> void:
	if is_instance_valid(selected_plank) and selected_plank != plank:
		if selected_plank.has_method("set_selected"):
			selected_plank.set_selected(false)
	selected_plank = plank
	if is_instance_valid(selected_plank):
		if selected_plank.has_method("set_selected"):
			selected_plank.set_selected(true)
		aim_target_point = selected_plank.global_position
	if is_instance_valid(reticle_visual):
		reticle_visual.visible = false

func _on_target_acquired(target_node: Node3D, world_pos: Vector3) -> void:
	current_target_node = target_node
	
	if is_instance_valid(reticle_visual):
		reticle_visual.visible = false
		
	# If player tapped a boarding plank (or enemy on that plank), turn towards and select that plank
	var plank: BoardingPlank = null
	if is_instance_valid(target_node):
		if target_node is BoardingPlank:
			plank = target_node as BoardingPlank
		elif target_node.get_parent() is BoardingPlank:
			plank = target_node.get_parent() as BoardingPlank
		elif target_node is BoarderEnemy:
			var enemy: BoarderEnemy = target_node as BoarderEnemy
			if is_instance_valid(enemy.active_plank):
				plank = enemy.active_plank
			elif is_instance_valid(enemy.current_zone) and not enemy.current_zone.active_planks.is_empty():
				plank = enemy.current_zone.active_planks[0] as BoardingPlank
		elif target_node is BoardingZone:
			var zone: BoardingZone = target_node as BoardingZone
			if not zone.active_planks.is_empty() and zone.active_planks[0] is BoardingPlank:
				plank = zone.active_planks[0] as BoardingPlank
				
	if is_instance_valid(plank):
		select_plank(plank)
	elif not is_instance_valid(selected_plank):
		aim_target_point = world_pos

func _on_zone_focused(zone_id: String) -> void:
	var zones: Array[Node] = get_tree().get_nodes_in_group("boarding_zone")
	for z_node: Node in zones:
		var z: BoardingZone = z_node as BoardingZone
		if is_instance_valid(z) and z.zone_id == zone_id:
			if not z.active_planks.is_empty() and z.active_planks[0] is BoardingPlank:
				select_plank(z.active_planks[0] as BoardingPlank)
				return
				
	if station_markers.has(zone_id):
		var marker: Marker3D = station_markers[zone_id] as Marker3D
		if is_instance_valid(marker):
			aim_target_point = marker.global_position

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
