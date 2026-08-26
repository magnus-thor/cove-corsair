class_name PlayerSwerve
extends CharacterBody3D

signal health_changed(current: int, max_hp: int)
signal score_changed(new_score: int)
signal doubloons_changed(new_doubloons: int)

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
var doubloons: int = 0
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
	
	if is_calibration_mode:
		_setup_calibration_mode()

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
		
	if is_calibration_mode:
		position = Vector3.ZERO
		float_time += delta
		if visuals:
			var float_t = (sin(float_time * bob_frequency) * 0.5 + 0.5)
			visuals.position.y = lerp(min_hover_height, max_hover_height, float_t)
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

func add_doubloons(amount: int) -> void:
	if is_game_over:
		return
	doubloons += amount
	doubloons_changed.emit(doubloons)
	upgrade_ship(amount)

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
		
	if area.is_in_group("destructible") or area.is_in_group("enemies"):
		current_health -= 1
		health_changed.emit(current_health, max_health)
		
		# Defeat condition
		if current_health <= 0:
			game_over(false)
			
		# Destroy the collided obstacle or enemy
		if area.has_method("die"):
			area.die()
		else:
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

@export_group("Player Ship Sprite Options")
@export var dinghy_sprite_tex: Texture2D = preload("res://assets/sprites/The Dinghy.png")
@export var sloop_sprite_tex: Texture2D = preload("res://assets/sprites/The Sloop.png")
@export var ironclad_sprite_tex: Texture2D = preload("res://assets/sprites/The Ironclad.png")
@export var use_sprite_boat: bool = true

@export_group("Player Ship Pixel Sizes")
@export var dinghy_pixel_size: float = 0.0021
@export var sloop_pixel_size: float = 0.0038
@export var ironclad_pixel_size: float = 0.0041

@export_group("Player Ship Y Offsets")
@export var dinghy_y_offset: float = 0.485
@export var sloop_y_offset: float = 1.025
@export var ironclad_y_offset: float = 1.125

@export_group("Player Ship Orientation")
@export var player_pitch_deg: float = -60.0

@export_group("Player Ship Collision Sizes")
@export var dinghy_collision_size: Vector3 = Vector3(1.6, 1.0, 2.8)
@export var sloop_collision_size: Vector3 = Vector3(2.0, 1.2, 3.4)
@export var ironclad_collision_size: Vector3 = Vector3(2.4, 1.4, 3.8)

@export_group("Calibration Mode")
@export var is_calibration_mode: bool = false

func _update_ship_mesh() -> void:
	if not visuals:
		return
		
	var sprite = visuals.get_node_or_null("BoatSprite") as Sprite3D
	if use_sprite_boat:
		if not sprite:
			for child in visuals.get_children():
				if not child.name.begins_with("Cal_"):
					child.queue_free()
			sprite = Sprite3D.new()
			sprite.name = "BoatSprite"
			visuals.add_child(sprite)
			
		sprite.visible = true
		sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		sprite.rotation_degrees = Vector3(player_pitch_deg, 0, 0)
		
		var col_size := Vector3(1.6, 1.0, 2.8)
		var y_pos: float = dinghy_y_offset
		
		match current_tier:
			ShipTier.RAFT:
				sprite.texture = dinghy_sprite_tex
				sprite.pixel_size = dinghy_pixel_size
				col_size = dinghy_collision_size
				y_pos = dinghy_y_offset
			ShipTier.SLOOP:
				sprite.texture = sloop_sprite_tex
				sprite.pixel_size = sloop_pixel_size
				col_size = sloop_collision_size
				y_pos = sloop_y_offset
			ShipTier.GALLEON:
				sprite.texture = ironclad_sprite_tex
				sprite.pixel_size = ironclad_pixel_size
				col_size = ironclad_collision_size
				y_pos = ironclad_y_offset
				
		sprite.position = Vector3(0, y_pos, 0)
				
		# Update main character collision shape
		var body_col = get_node_or_null("CollisionShape3D") as CollisionShape3D
		if body_col:
			var box = body_col.shape as BoxShape3D
			if not box:
				box = BoxShape3D.new()
				body_col.shape = box
			box.size = col_size
			body_col.position = Vector3(0, col_size.y * 0.5, 0)
			
		# Update detection area collision shape
		var area_col = get_node_or_null("CollisionArea/CollisionShape3D") as CollisionShape3D
		if area_col:
			var area_box = area_col.shape as BoxShape3D
			if not area_box:
				area_box = BoxShape3D.new()
				area_col.shape = area_box
			area_box.size = Vector3(col_size.x, col_size.y + 0.2, col_size.z)
			area_col.position = Vector3(0, (col_size.y + 0.2) * 0.5, 0)
		return
	else:
		if sprite:
			sprite.visible = false
			
		for child in visuals.get_children():
			if child != sprite and not child.name.begins_with("Cal_"):
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

func _setup_calibration_mode() -> void:
	position = Vector3.ZERO
	target_x = 0.0
	
	# Hide normal sprite
	var main_sprite = visuals.get_node_or_null("BoatSprite") as Sprite3D
	if main_sprite:
		main_sprite.visible = false
		
	# Disable normal wake
	var wake = get_node_or_null("BoatWake") as Node3D
	if wake:
		wake.visible = false
		
	# Clean up any existing calibration previews
	for child in visuals.get_children():
		if child != main_sprite and child.name.begins_with("Cal_"):
			child.queue_free()
			
	# Row 1: Player Ships (closer to camera at Z = 0.5)
	var player_ships = [
		{"name": "Dinghy", "tex": dinghy_sprite_tex, "p_size": dinghy_pixel_size, "offset": Vector3(-3.2, dinghy_y_offset, 0.5)},
		{"name": "Sloop", "tex": sloop_sprite_tex, "p_size": sloop_pixel_size, "offset": Vector3(0.0, sloop_y_offset, 0.5)},
		{"name": "Ironclad", "tex": ironclad_sprite_tex, "p_size": ironclad_pixel_size, "offset": Vector3(3.2, ironclad_y_offset, 0.5)}
	]
	
	for ship in player_ships:
		var s = Sprite3D.new()
		s.name = "Cal_" + ship.name
		s.texture = ship.tex
		s.pixel_size = ship.p_size
		s.rotation_degrees = Vector3(player_pitch_deg, 0, 0)
		s.position = ship.offset
		s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		visuals.add_child(s)
		
		var lbl = Label3D.new()
		lbl.name = "Cal_Label_" + ship.name
		lbl.text = ship.name + "\n(" + str(ship.p_size) + ")"
		lbl.font_size = 28
		lbl.outline_size = 8
		lbl.outline_modulate = Color.BLACK
		lbl.modulate = Color(1.0, 0.85, 0.2, 1.0)
		lbl.no_depth_test = true
		lbl.render_priority = 10
		lbl.position = Vector3(ship.offset.x, ship.offset.y + 1.0, ship.offset.z)
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		visuals.add_child(lbl)
		
	# Create a temporary EnemyMob instance to read current configured parameters
	var enemy_mob_prefab = load("res://prefabs/enemy_mob.tscn") as PackedScene
	var enemy_sample = enemy_mob_prefab.instantiate() as EnemyMob if enemy_mob_prefab else EnemyMob.new()
	add_child(enemy_sample)
	enemy_sample.visible = false
	
	# Row 2: Standard Enemy Mobs (mid-distance at Z = -4.5)
	var enemy_mob_defs = [
		{"type": "skeleton_rower", "name": "Skeleton Rower", "x": -4.6, "z": -4.5},
		{"type": "goblin_skiff", "name": "Goblin Skiff", "x": -1.7, "z": -4.5},
		{"type": "turtle_raft", "name": "Turtle-Raft", "x": 1.7, "z": -4.5},
		{"type": "ghost_sloop", "name": "Ghost Sloop", "x": 4.6, "z": -4.5}
	]
	
	for def in enemy_mob_defs:
		enemy_sample.mob_type = def.type
		enemy_sample._apply_mob_type()
		
		var s = Sprite3D.new()
		s.name = "Cal_" + def.type
		var sprite_node = enemy_sample.get_node_or_null("EnemySprite") as Sprite3D
		s.texture = sprite_node.texture if sprite_node else enemy_sample.skeleton_rower_tex
		s.pixel_size = sprite_node.pixel_size if sprite_node else 0.0025
		var mob_y: float = sprite_node.position.y if sprite_node else 1.25
		s.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		s.rotation_degrees = Vector3(enemy_sample.enemy_pitch_deg, 0, 0)
		s.position = Vector3(def.x, mob_y, def.z)
		s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		visuals.add_child(s)
		
		var lbl = Label3D.new()
		lbl.name = "Cal_Label_" + def.type
		lbl.text = def.name + "\n(" + str(s.pixel_size) + ")"
		lbl.font_size = 26
		lbl.outline_size = 8
		lbl.outline_modulate = Color.BLACK
		lbl.modulate = Color(1.0, 0.35, 0.35, 1.0)
		lbl.no_depth_test = true
		lbl.render_priority = 10
		lbl.position = Vector3(def.x, mob_y + 1.1, def.z)
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		visuals.add_child(lbl)

	# Row 3: Boss Ship (further ahead at Z = -10.0, centered)
	enemy_sample.mob_type = "bone_beard"
	enemy_sample._apply_mob_type()
	var boss_sprite = enemy_sample.get_node_or_null("EnemySprite") as Sprite3D
	var boss_y: float = boss_sprite.position.y if boss_sprite else 2.96
	
	var boss = Sprite3D.new()
	boss.name = "Cal_Boss"
	boss.texture = boss_sprite.texture if boss_sprite else enemy_sample.bone_beard_tex
	boss.pixel_size = boss_sprite.pixel_size if boss_sprite else 0.0055
	boss.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	boss.rotation_degrees = Vector3(enemy_sample.enemy_pitch_deg, 0, 0)
	boss.position = Vector3(0.0, boss_y, -10.0)
	boss.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	visuals.add_child(boss)
	
	var boss_lbl = Label3D.new()
	boss_lbl.name = "Cal_Label_Boss"
	boss_lbl.text = "Captain Bone-Beard (Boss)\n(" + str(boss.pixel_size) + ")"
	boss_lbl.font_size = 28
	boss_lbl.outline_size = 8
	boss_lbl.outline_modulate = Color.BLACK
	boss_lbl.modulate = Color(0.9, 0.2, 0.9, 1.0)
	boss_lbl.no_depth_test = true
	boss_lbl.render_priority = 10
	boss_lbl.position = Vector3(0.0, boss_y + 1.8, -10.0)
	boss_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	visuals.add_child(boss_lbl)
	
	enemy_sample.queue_free()
	
	enemy_sample.queue_free()

func _shoot() -> void:
	if is_calibration_mode:
		return
	if not cannonball_scene:
		return
		
	var ball = cannonball_scene.instantiate() as Node3D
	# Add the projectile to the main scene level so it travels independently of the ship
	get_parent().add_child(ball)
	# Position slightly further ahead at the front of the ship to prevent self-collision or lag
	ball.global_position = global_position + Vector3(0, 0.5, -3.0)
	AudioManager.play_sfx("cannon_shots")
