class_name PlayerSwerve
extends CharacterBody3D

signal health_changed(current: int, max_hp: int)
signal score_changed(new_score: int)

enum ShipTier {RAFT, SLOOP, GALLEON}

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
@export var cannonball_scene: PackedScene = preload("res://prefabs/cannonball.tscn")

@onready var visuals: Node3D = $BoatVisuals

var dragging: bool = false
var target_x: float = 0.0
var half_width: float = 0.0

var max_health: int = 3
var current_health: int = 3

@export var target_score: int = 50

var power_level: int = 0
var shoot_timer: float = 0.0
var score: int = 0
var is_game_over: bool = false
var float_time: float = 0.0

@export var end_game_ui_scene: PackedScene = preload("res://prefabs/end_game_ui.tscn")

func _ready() -> void:
	add_to_group("player")
	target_x = global_position.x
	half_width = river_width / 2.0
	_check_tier_updates(true)
	
	# Dynamically construct collision area to detect overlapping Area3D obstacles (like barrels)
	var detection_area = Area3D.new()
	detection_area.name = "CollisionArea"
	add_child(detection_area)
	
	var col_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(1.4, 1.4, 2.7) # Slightly larger than boat collision shape
	col_shape.shape = box_shape
	detection_area.add_child(col_shape)
	col_shape.position = Vector3(0, 0.6, 0)
	
	detection_area.area_entered.connect(_on_area_entered)

func _unhandled_input(event: InputEvent) -> void:
	if is_game_over:
		return
		
	# Handle mouse input
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
	
	# Handle touch input
	elif event is InputEventScreenTouch:
		dragging = event.pressed
	
	# Process drag motion
	if dragging:
		if event is InputEventMouseMotion or event is InputEventScreenDrag:
			target_x += event.relative.x * sensitivity
			target_x = clamp(target_x, -half_width, half_width)

func _physics_process(delta: float) -> void:
	if is_game_over:
		return
		
	# Process keyboard movement controls
	var move_input := 0.0
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		move_input -= 1.0
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		move_input += 1.0
		
	if move_input != 0.0:
		target_x += move_input * keyboard_speed * delta
		target_x = clamp(target_x, -half_width, half_width)
		
	# Calculate target position and interpolate along the X-axis
	var current_pos = global_position
	current_pos.x = lerp(current_pos.x, target_x, lerp_speed * delta)
	global_position = current_pos
	
	# Accumulate floating time accumulator
	float_time += delta
	
	# Polish: Calculate tilting angle based on visual offset delta
	var x_offset = target_x - global_position.x
	
	# Y-Rotation (Yaw): Slices the nose of the boat slightly towards direction of movement
	var target_yaw_deg = x_offset * 8.0
	
	if visuals:
		# 1. Procedural gentle vertical float on position.y (hovering between 0.04 and 0.08 above the water)
		var float_t = (sin(float_time * bob_frequency) * 0.5 + 0.5)
		visuals.position.y = lerp(min_hover_height, max_hover_height, float_t)
		
		# Keep pitch and roll at 0 to keep the 2D sprite parallel above the water plane
		visuals.rotation_degrees.x = 0.0
		visuals.rotation_degrees.z = 0.0
		
		# Y-axis yaw turn stays parallel to water plane
		visuals.rotation_degrees.y = lerp(visuals.rotation_degrees.y, target_yaw_deg, yaw_lerp_speed * delta)
		
	# Automatic shooting loop
	shoot_timer += delta
	if shoot_timer >= shoot_cooldown:
		shoot_timer = 0.0
		_shoot()

func upgrade_ship(amount: int) -> void:
	if is_game_over:
		return
		
	power_level += amount
	if amount > 0:
		score += amount
		score_changed.emit(score)
		if score >= target_score:
			game_over(true)
			
	_check_tier_updates()

func _check_tier_updates(force_mesh_update: bool = false) -> void:
	var target_tier = ShipTier.RAFT
	if power_level >= 25:
		target_tier = ShipTier.GALLEON
	elif power_level >= 10:
		target_tier = ShipTier.SLOOP
		
	var tier_changed = current_tier != target_tier
	if tier_changed:
		current_tier = target_tier
		
	if tier_changed or force_mesh_update:
		_update_ship_mesh()
		
	# Dynamic shoot cooldown matching active ship tier
	match current_tier:
		ShipTier.RAFT:
			shoot_cooldown = 0.45
		ShipTier.SLOOP:
			shoot_cooldown = 0.3
		ShipTier.GALLEON:
			shoot_cooldown = 0.18

func _on_area_entered(area: Area3D) -> void:
	if is_game_over:
		return
		
	if area.is_in_group("destructible"):
		current_health -= 1
		health_changed.emit(current_health, max_health)
		
		# Defeat condition
		if current_health <= 0:
			game_over(false)
			
		# Despawn the collided barrel so it doesn't trigger damage multiple times
		area.queue_free()

func game_over(victory: bool) -> void:
	if is_game_over:
		return
	is_game_over = true
	
	# Pause the entire gameplay tree
	get_tree().paused = true
	
	# Instantiate and show End-Game UI Overlay
	if end_game_ui_scene:
		var ui = end_game_ui_scene.instantiate()
		get_parent().add_child(ui)
		if ui.has_method("set_result"):
			ui.set_result(victory, score)

@export var dinghy_sprite_tex: Texture2D = preload("res://assets/sprites/The Dinghy.png")
@export var sloop_sprite_tex: Texture2D = preload("res://assets/sprites/The Sloop.png")
@export var ironclad_sprite_tex: Texture2D = preload("res://assets/sprites/The Ironclad.png")
@export var use_sprite_boat: bool = true

func _update_ship_mesh() -> void:
	if not visuals:
		return
		
	var sprite = visuals.get_node_or_null("BoatSprite") as Sprite3D
	if use_sprite_boat:
		if not sprite:
			for child in visuals.get_children():
				child.queue_free()
			sprite = Sprite3D.new()
			sprite.name = "BoatSprite"
			visuals.add_child(sprite)
			
		sprite.visible = true
		sprite.billboard = 0
		sprite.alpha_cut = 1
		sprite.pixel_size = 0.0018
		sprite.rotation_degrees = Vector3(-75, 0, 0)
		sprite.position = Vector3(0, 0.2, 0)
		
		match current_tier:
			ShipTier.RAFT:
				sprite.texture = dinghy_sprite_tex
			ShipTier.SLOOP:
				sprite.texture = sloop_sprite_tex
			ShipTier.GALLEON:
				sprite.texture = ironclad_sprite_tex
		return
	else:
		if sprite:
			sprite.visible = false
			
		for child in visuals.get_children():
			if child != sprite:
				child.queue_free()
				
		var model_path: String = ""
		match current_tier:
			ShipTier.RAFT:
				model_path = "res://assets/models/boat-row-large.glb"
			ShipTier.SLOOP:
				model_path = "res://assets/models/ship-small.glb"
			ShipTier.GALLEON:
				model_path = "res://assets/models/ship-pirate-large.glb"
				
		if model_path != "":
			var scene = load(model_path)
			if scene:
				var inst = scene.instantiate() as Node3D
				visuals.add_child(inst)
				inst.rotation.y = PI
				match current_tier:
					ShipTier.RAFT:
						inst.scale = Vector3(1.0, 1.0, 1.0)
					ShipTier.SLOOP:
						inst.scale = Vector3(0.25, 0.25, 0.25)
					ShipTier.GALLEON:
						inst.scale = Vector3(0.25, 0.25, 0.25)

func _shoot() -> void:
	if not cannonball_scene:
		return
		
	var ball = cannonball_scene.instantiate() as Node3D
	# Add the projectile to the main scene level so it travels independently of the ship
	get_parent().add_child(ball)
	# Position slightly further ahead at the front of the ship to prevent self-collision or lag
	ball.global_position = global_position + Vector3(0, 0.5, -3.0)
	AudioManager.play_sfx("cannon_shots")
