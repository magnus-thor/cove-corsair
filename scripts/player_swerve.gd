class_name PlayerSwerve
extends CharacterBody3D

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

@onready var visuals: Node3D = $BoatVisuals

var dragging: bool = false
var target_x: float = 0.0
var half_width: float = 0.0

func _ready() -> void:
	target_x = global_position.x
	half_width = river_width / 2.0

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
	var target_roll = -x_offset * tilt_amount
	# Y-Rotation (Yaw): Slices the nose of the boat slightly towards the direction of movement
	var target_yaw = x_offset * (tilt_amount * 0.4)
	
	if visuals:
		visuals.rotation.z = lerp(visuals.rotation.z, target_roll, tilt_lerp_speed * delta)
		visuals.rotation.y = lerp(visuals.rotation.y, target_yaw, tilt_lerp_speed * delta)
