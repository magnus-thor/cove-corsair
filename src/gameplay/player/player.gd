class_name PlayerSwerve
extends CharacterBody3D

signal health_changed(current: int, max_hp: int)
signal score_changed(new_score: int)
signal doubloons_changed(new_doubloons: int)

enum ShipTier {RAFT, SLOOP, GALLEON}

@export var ship_data: ShipData:
	set(val):
		if ship_data == val:
			return
		ship_data = val
		if is_node_ready() and ship_data:
			apply_ship_data(ship_data)

@export_group("Ship Data Tier Presets")
@export var dinghy_ship_data: ShipData = preload("res://src/data/resources/dinghy_ship.tres")
@export var sloop_ship_data: ShipData = preload("res://src/data/resources/sloop_ship.tres")
@export var ironclad_ship_data: ShipData = preload("res://src/data/resources/ironclad_ship.tres")

## Width of the river channel boundaries. The boat can move within [-river_width/2, river_width/2]
@export var river_width: float = 11.0

## Touch/drag input sensitivity scaling factor.
@export var sensitivity: float = 0.015

## Keyboard movement speed in units per second.
@export var keyboard_speed: float = 15.0

## Interpolation speed for the horizontal translation. Higher values make the swerve more immediate.
@export var lerp_speed: float = 12.0

## Configurable floating and bobbing parameters
@export var bob_frequency: float = 2.2
@export var min_hover_height: float = 0.04
@export var max_hover_height: float = 0.08
@export var yaw_lerp_speed: float = 10.0

## The active ship tier
@export var current_tier: ShipTier = ShipTier.RAFT

## Cooldown duration between automatic shots in seconds
@export var shoot_cooldown: float = 0.45

## The penalty to power_level when colliding with an obstacle
@export var collision_penalty: int = 10

## The cannonball prefab scene to spawn
@export var cannonball_scene: PackedScene = preload("res://src/gameplay/projectiles/cannonball.tscn")

@onready var visuals: Node3D = $BoatVisuals

var dragging: bool = false
var target_x: float = 0.0
var half_width: float = 0.0

var max_health: int = 3
var current_health: int = 3

@export var target_score: int = 50

var power_level: int = 0
var evolution_xp: float = 0.0
var equipped_weapons: Dictionary = {}
var active_weapons: Array[Node] = []
var shoot_timer: float = 0.0
var score: int = 0
var doubloons: int = 0
var is_game_over: bool = false
var float_time: float = 0.0

@export var is_shooting_enabled: bool = false
@export var end_game_ui_scene: PackedScene = preload("res://src/ui/end_game_ui.tscn")

@export_group("Player Ship Orientation")
@export var player_pitch_deg: float = -60.0

@export_group("Calibration Mode")
@export var is_calibration_mode: bool = false

func _ready() -> void:
	add_to_group("player")
	target_x = global_position.x
	half_width = river_width / 2.0
	
	# Dynamically construct collision area to detect overlapping Area3D obstacles
	var detection_area = Area3D.new()
	detection_area.name = "CollisionArea"
	add_child(detection_area)
	
	var col_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(1.6, 1.4, 2.8)
	col_shape.shape = box_shape
	detection_area.add_child(col_shape)
	col_shape.position = Vector3(0, 0.6, 0)
	
	detection_area.area_entered.connect(_on_area_entered)
	
	# Dynamically construct MagnetArea to attract Layer 4 Collectibles
	var magnet_area = get_node_or_null("MagnetArea") as Area3D
	if not magnet_area:
		magnet_area = Area3D.new()
		magnet_area.name = "MagnetArea"
		add_child(magnet_area)
		
	magnet_area.collision_layer = 0
	magnet_area.collision_mask = 8 # Layer 4 (Collectibles)
	magnet_area.monitoring = true
	magnet_area.monitorable = false

	var mag_shape = magnet_area.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if not mag_shape:
		mag_shape = CollisionShape3D.new()
		magnet_area.add_child(mag_shape)

	var sphere = SphereShape3D.new()
	sphere.radius = 4.5
	mag_shape.shape = sphere
	mag_shape.position = Vector3(0, 0.5, 0)
	
	magnet_area.area_entered.connect(_on_magnet_area_entered)
	
	evolution_xp = 0.0
	if ship_data:
		apply_ship_data(ship_data)
	
	equip_weapon_to_socket("BowMount", preload("res://src/data/resources/weapon_bow_chaser.tres"))
	
	if is_calibration_mode:
		_setup_calibration_mode()

func apply_ship_data(data: ShipData) -> void:
	if not data:
		return
	if ship_data != data:
		ship_data = data
		return
	max_health = data.max_health
	current_health = data.max_health
	shoot_cooldown = data.fire_rate
	keyboard_speed = data.move_speed
	lerp_speed = data.move_speed * 1.3
	
	if not visuals:
		return
		
	var sprite = visuals.get_node_or_null("BoatSprite") as Sprite3D
	if not sprite:
		for child in visuals.get_children():
			if not child.name.begins_with("Cal_"):
				child.queue_free()
		sprite = Sprite3D.new()
		sprite.name = "BoatSprite"
		visuals.add_child(sprite)
		
	sprite.visible = true
	sprite.texture = data.sprite_texture
	sprite.pixel_size = data.pixel_size
	sprite.rotation_degrees = Vector3(player_pitch_deg, 0, 0)
	sprite.position = Vector3(0, data.y_offset, 0)
	sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	
	# Update main character collision shape
	var body_col = get_node_or_null("CollisionShape3D") as CollisionShape3D
	if body_col:
		var box = body_col.shape as BoxShape3D
		if not box:
			box = BoxShape3D.new()
			body_col.shape = box
		box.size = data.collision_size
		body_col.position = Vector3(0, data.collision_size.y * 0.5, 0)
		
	# Update detection area collision shape
	var area_col = get_node_or_null("CollisionArea/CollisionShape3D") as CollisionShape3D
	if area_col:
		var area_box = area_col.shape as BoxShape3D
		if not area_box:
			area_box = BoxShape3D.new()
			area_col.shape = area_box
		area_box.size = Vector3(data.collision_size.x, data.collision_size.y + 0.2, data.collision_size.z)
		area_col.position = Vector3(0, (data.collision_size.y + 0.2) * 0.5, 0)
		
	# Dynamically position hardpoint sockets on Y to align with the slanted deck
	var hardpoints = get_node_or_null("Hardpoints")
	if hardpoints:
		for socket in hardpoints.get_children():
			if socket is Node3D:
				var z_pos = socket.position.z
				# y_offset is the height of the boat sprite center
				# slant slope is tan(30 deg) = 0.57735
				socket.position.y = data.y_offset - 0.57735 * z_pos
		
	health_changed.emit(current_health, max_health)

func _unhandled_input(event: InputEvent) -> void:
	if is_game_over:
		return
		
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
	elif event is InputEventScreenTouch:
		dragging = event.pressed
	elif event is InputEventMouseMotion and dragging:
		target_x += event.relative.x * sensitivity
		target_x = clamp(target_x, -half_width, half_width)
	elif event is InputEventScreenDrag:
		target_x += event.relative.x * sensitivity
		target_x = clamp(target_x, -half_width, half_width)

func _physics_process(delta: float) -> void:
	if is_game_over:
		return
		
	if is_calibration_mode:
		_process_calibration_controls(delta)
		return
		
	# 1. Update global GameState level distance
	var track_mgr = get_tree().get_first_node_in_group("track_manager")
	if track_mgr and "scroll_speed" in track_mgr and GameState.is_game_active:
		GameState.update_distance(track_mgr.scroll_speed * delta)
		
	if not GameState.is_game_active:
		# Floating / Bobbing on water
		float_time += delta * bob_frequency
		var hover_height = lerp(min_hover_height, max_hover_height, (sin(float_time) + 1.0) * 0.5)
		if visuals:
			visuals.position.y = hover_height
			visuals.rotation_degrees.x = sin(float_time * 1.5) * 2.0
			
			var hardpoints = get_node_or_null("Hardpoints")
			if hardpoints:
				hardpoints.position.y = visuals.position.y
				hardpoints.rotation_degrees.x = visuals.rotation_degrees.x
		return

	# 2. Keyboard fallback controls
	var input_dir: float = 0.0
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		input_dir -= 1.0
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		input_dir += 1.0
		
	if input_dir != 0.0:
		target_x += input_dir * keyboard_speed * delta
		target_x = clamp(target_x, -half_width, half_width)
		
	# 3. Smooth swerve horizontal interpolation
	var previous_x = position.x
	position.x = lerp(position.x, target_x, lerp_speed * delta)
	var x_velocity = (position.x - previous_x) / delta if delta > 0.0 else 0.0
	
	# 4. Dynamic Roll and Yaw Banking
	var target_roll_deg = -clamp(x_velocity * 0.9, -15.0, 15.0)
	var target_yaw_deg = -clamp(x_velocity * 0.45, -8.0, 8.0)
	rotation_degrees.z = lerp(rotation_degrees.z, target_roll_deg, yaw_lerp_speed * delta)
	rotation_degrees.y = lerp(rotation_degrees.y, target_yaw_deg, yaw_lerp_speed * delta)
	
	# 5. Floating / Bobbing on water
	float_time += delta * bob_frequency
	var hover_height = lerp(min_hover_height, max_hover_height, (sin(float_time) + 1.0) * 0.5)
	if visuals:
		visuals.position.y = hover_height
		visuals.rotation_degrees.x = sin(float_time * 1.5) * 2.0
		
		var hardpoints = get_node_or_null("Hardpoints")
		if hardpoints:
			hardpoints.position.y = visuals.position.y
			hardpoints.rotation_degrees.x = visuals.rotation_degrees.x
		
	# 6. Automatic periodic cannon shooting
	if is_shooting_enabled:
		for weapon in equipped_weapons.values():
			if is_instance_valid(weapon) and weapon.has_method("try_fire"):
				weapon.try_fire(delta)
			
	move_and_slide()


func _on_magnet_area_entered(area: Area3D) -> void:
	if area and area.is_in_group("doubloons") and area.has_method("attract_to"):
		area.attract_to(self)

func upgrade_ship(amount: int = 1) -> void:
	power_level += amount
	score += amount
	score_changed.emit(score)
	_check_tier_updates()

func add_doubloons(amount: int) -> void:
	doubloons += amount
	doubloons_changed.emit(doubloons)

func add_evolution_xp(amount: float) -> void:
	evolution_xp += amount
	print("Player XP: ", evolution_xp, " / Current Tier: ", current_tier)
	_check_tier_updates()

func _check_tier_updates(force: bool = false) -> void:
	var old_tier = current_tier
	
	if evolution_xp >= 280.0:
		current_tier = ShipTier.GALLEON
	elif evolution_xp >= 120.0:
		current_tier = ShipTier.SLOOP
	else:
		current_tier = ShipTier.RAFT
			
	if current_tier != old_tier or force:
		_apply_weapon_tier_setup()

func _apply_weapon_tier_setup() -> void:
	clear_weapons()
	
	var heavy_ammo = preload("res://src/data/resources/ammo_heavy_shot.tres")
	
	match current_tier:
		ShipTier.RAFT:
			var bow_weapon = preload("res://src/data/resources/weapon_bow_chaser.tres")
			equip_weapon_to_socket("BowMount", bow_weapon)
			
		ShipTier.SLOOP:
			var bow_weapon = preload("res://src/data/resources/weapon_bow_chaser.tres")
			var port_weapon = preload("res://src/data/resources/weapon_port_swivel.tres")
			var star_weapon = preload("res://src/data/resources/weapon_starboard_swivel.tres")
			equip_weapon_to_socket("BowMount", bow_weapon)
			equip_weapon_to_socket("PortSwivelMount", port_weapon)
			equip_weapon_to_socket("StarboardSwivelMount", star_weapon)
			
		ShipTier.GALLEON:
			var bow_weapon = preload("res://src/data/resources/weapon_bow_chaser.tres").duplicate()
			bow_weapon.default_ammo = heavy_ammo
			
			var port_weapon = preload("res://src/data/resources/weapon_port_swivel.tres").duplicate()
			port_weapon.default_ammo = heavy_ammo
			
			var star_weapon = preload("res://src/data/resources/weapon_starboard_swivel.tres").duplicate()
			star_weapon.default_ammo = heavy_ammo
			
			var aft_weapon = preload("res://src/data/resources/weapon_deckhand_sniper.tres")
			
			equip_weapon_to_socket("BowMount", bow_weapon)
			equip_weapon_to_socket("PortSwivelMount", port_weapon)
			equip_weapon_to_socket("StarboardSwivelMount", star_weapon)
			equip_weapon_to_socket("AftMortarMount", aft_weapon)


func _on_area_entered(area: Area3D) -> void:
	if is_game_over or not GameState.is_game_active:
		return
		
	# Ignore collectibles and cannonballs
	if area.is_in_group("collectibles") or area.is_in_group("cannonballs") or area.is_in_group("multiplier_gate"):
		return
		
	if area.is_in_group("destructible") or area.is_in_group("enemies"):
		AudioManager.play_sfx("barrel_hits")
		
		# Decrement player health
		current_health -= 1
		health_changed.emit(current_health, max_health)
		
		if current_health <= 0:
			game_over(false)
			
		if area.has_method("die"):
			area.die()
		else:
			area.queue_free()

func game_over(victory: bool) -> void:
	if is_game_over:
		return
	is_game_over = true
	get_tree().paused = true
	
	if end_game_ui_scene:
		var ui = end_game_ui_scene.instantiate()
		get_parent().add_child(ui)
		if ui.has_method("set_result"):
			ui.set_result(victory, score)

func _process_calibration_controls(delta: float) -> void:
	if is_shooting_enabled:
		for weapon in equipped_weapons.values():
			if is_instance_valid(weapon) and weapon.has_method("try_fire"):
				weapon.try_fire(delta)

func _setup_calibration_mode() -> void:
	position = Vector3.ZERO
	target_x = 0.0

func clear_all_weapons() -> void:
	clear_weapons()

func equip_weapon_to_socket(socket_name: String, weapon_data: WeaponData) -> void:
	var hardpoints = get_node_or_null("Hardpoints")
	if not hardpoints:
		return
	var socket = hardpoints.get_node_or_null(socket_name)
	if not socket:
		return
		
	if equipped_weapons.has(socket_name):
		var old_weapon = equipped_weapons[socket_name]
		if is_instance_valid(old_weapon):
			old_weapon.queue_free()
		equipped_weapons.erase(socket_name)
		
	var attached_weapon_scene = load("res://src/gameplay/player/attached_weapon.tscn")
	var weapon_instance = attached_weapon_scene.instantiate() as AttachedWeapon
	if weapon_instance.has_method("setup_weapon"):
		weapon_instance.setup_weapon(weapon_data)
	else:
		weapon_instance.weapon_data = weapon_data
	socket.add_child(weapon_instance)
	equipped_weapons[socket_name] = weapon_instance
	
	var sprite = weapon_instance.get_node_or_null("Sprite3D") as Sprite3D
	if sprite:
		sprite.scale = Vector3.ZERO
		var tween = create_tween()
		tween.tween_property(sprite, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

func clear_weapons() -> void:
	for weapon in equipped_weapons.values():
		if is_instance_valid(weapon):
			weapon.queue_free()
	equipped_weapons.clear()
	
	var hardpoints = get_node_or_null("Hardpoints")
	if hardpoints:
		for socket in hardpoints.get_children():
			for child in socket.get_children():
				child.queue_free()
