class_name PlayerSwerve
extends CharacterBody3D

enum ShipTier {RAFT, SLOOP, GALLEON}

## Width of the river channel boundaries. The boat can move within [-river_width/2, river_width/2]
@export var river_width: float = 12.0

## Touch/drag input sensitivity scaling factor.
@export var sensitivity: float = 0.05

## Interpolation speed for the horizontal translation. Higher values make the swerve more immediate.
@export var lerp_speed: float = 12.0

## Factor controlling how much the boat visuals roll and yaw during turns.
@export var tilt_amount: float = 0.25

## Interpolation speed for return-to-center visual tilt stabilization.
@export var tilt_lerp_speed: float = 6.0

## The active ship tier
@export var current_tier: ShipTier = ShipTier.RAFT

## Cooldown duration between automatic shots in seconds
@export var shoot_cooldown: float = 0.15

## The cannonball prefab scene to spawn
@export var cannonball_scene: PackedScene = preload("res://prefabs/cannonball.tscn")

@onready var visuals: Node3D = $BoatVisuals

var dragging: bool = false
var target_x: float = 0.0
var half_width: float = 0.0

var power_level: int = 0
var shoot_timer: float = 0.0

func _ready() -> void:
	add_to_group("player")
	target_x = global_position.x
	half_width = river_width / 2.0
	_update_ship_mesh()

func _unhandled_input(event: InputEvent) -> void:
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
	# Calculate target position and interpolate along the X-axis
	var current_pos = global_position
	current_pos.x = lerp(current_pos.x, target_x, lerp_speed * delta)
	global_position = current_pos
	
	# Polish: Calculate tilting angle based on visual offset delta
	var x_offset = target_x - global_position.x
	
	# Z-Rotation (Roll): Tilts the boat side-to-side when steering
	var target_roll = - x_offset * tilt_amount
	# Y-Rotation (Yaw): Slices the nose of the boat slightly towards the direction of movement
	var target_yaw = x_offset * (tilt_amount * 0.4)
	
	if visuals:
		visuals.rotation.z = lerp(visuals.rotation.z, target_roll, tilt_lerp_speed * delta)
		visuals.rotation.y = lerp(visuals.rotation.y, target_yaw, tilt_lerp_speed * delta)
		
	# Automatic shooting loop
	shoot_timer += delta
	if shoot_timer >= shoot_cooldown:
		shoot_timer = 0.0
		_shoot()

func upgrade_ship(amount: int) -> void:
	power_level += amount
	if power_level >= 10 and current_tier == ShipTier.RAFT:
		current_tier = ShipTier.SLOOP
		_update_ship_mesh()
	if power_level >= 25 and current_tier == ShipTier.SLOOP:
		current_tier = ShipTier.GALLEON
		_update_ship_mesh()

func _update_ship_mesh() -> void:
	if not visuals:
		return
		
	# Free any existing child nodes inside BoatVisuals
	for child in visuals.get_children():
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
