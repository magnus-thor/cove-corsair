class_name PlayerMovement
extends Node

## Handles all horizontal swerve input, sinusoidal bobbing, firing recoil pitch,
## and kinetic impact shudder for the player vessel.
## Owned and driven by PlayerSwerve (player.gd).

signal player_swerved

# ── Input ────────────────────────────────────────────────────────────────────
## Touch/drag sensitivity scaling factor.
@export var sensitivity: float = 0.015
## Keyboard movement speed in units per second.
@export var keyboard_speed: float = 15.0
## Horizontal lerp speed. Higher = more snappy swerve.
@export var lerp_speed: float = 12.0
## Hard boundary for playable lane (half-width).
@export var playable_half_width: float = 4.8

# ── Visuals ──────────────────────────────────────────────────────────────────
## Yaw/roll banking interpolation speed.
@export var yaw_lerp_speed: float = 10.0
## Sinusoidal bobbing frequency.
@export var bob_frequency: float = 2.2
## Minimum hover height on water.
@export var min_hover_height: float = 0.04
## Maximum hover height on water.
@export var max_hover_height: float = 0.08

# ── Runtime State ────────────────────────────────────────────────────────────
## Current target horizontal position (swerve destination).
var target_x: float = 0.0
## Instantaneous horizontal velocity for bow spray scaling (read by player.gd).
var x_velocity: float = 0.0
## Accumulated sinusoidal time for bobbing and roll animation.
var float_time: float = 0.0

var _body: CharacterBody3D = null
var _visuals: Node3D = null

var _dragging: bool = false
var _half_width: float = 0.0

# Game Feel
var _recoil_pitch: float = 0.0
var _shudder_timer: float = 0.0
var _shudder_roll: float = 0.0


## Called by PlayerSwerve._ready() immediately after node setup.
func setup(owner_body: CharacterBody3D, visuals_node: Node3D) -> void:
	_body = owner_body
	_visuals = visuals_node
	target_x = _body.global_position.x
	_half_width = playable_half_width if playable_half_width > 0.0 else 6.0


## Forward raw input events from PlayerSwerve._unhandled_input().
func process_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mb.pressed
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		_dragging = st.pressed
	elif event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		target_x += mm.relative.x * sensitivity
		target_x = clamp(target_x, -_half_width, _half_width)
		if absf(mm.relative.x) > 1.0:
			player_swerved.emit()
			if EventBus and EventBus.has_signal("player_swerved"):
				EventBus.player_swerved.emit()
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		target_x += sd.relative.x * sensitivity
		target_x = clamp(target_x, -_half_width, _half_width)
		if absf(sd.relative.x) > 1.0:
			player_swerved.emit()
			if EventBus and EventBus.has_signal("player_swerved"):
				EventBus.player_swerved.emit()


## Tick the idle bobbing animation used when the game is not active (harbor view).
## Returns the hover height for this frame.
func tick_idle(delta: float) -> float:
	float_time += delta * bob_frequency
	return lerp(min_hover_height, max_hover_height, (sin(float_time) + 1.0) * 0.5)


## Tick the full movement physics: swerve, banking, bobbing, recoil, shudder.
## speed_mult: typically 1.0, reduced to 0.5 on reef.
## Returns the computed hover height so PlayerSwerve can position $BoatVisuals.
func tick(delta: float, speed_mult: float) -> float:
	if not _body:
		return min_hover_height

	# Keyboard fallback controls
	var input_dir: float = 0.0
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		input_dir -= 1.0
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		input_dir += 1.0

	if input_dir != 0.0:
		target_x += input_dir * keyboard_speed * speed_mult * delta
		target_x = clamp(target_x, -_half_width, _half_width)
		player_swerved.emit()
		if EventBus and EventBus.has_signal("player_swerved"):
			EventBus.player_swerved.emit()

	# Smooth swerve horizontal interpolation
	var previous_x: float = _body.position.x
	_body.position.x = lerp(_body.position.x, target_x, lerp_speed * speed_mult * delta)
	_body.position.x = clamp(_body.position.x, -_half_width, _half_width)
	x_velocity = (_body.position.x - previous_x) / delta if delta > 0.0 else 0.0

	# Dynamic Roll and Yaw Banking
	var target_roll_deg: float = -clamp(x_velocity * 0.9, -15.0, 15.0)
	var target_yaw_deg: float = -clamp(x_velocity * 0.45, -8.0, 8.0)
	_body.rotation_degrees.z = lerp(_body.rotation_degrees.z, target_roll_deg, yaw_lerp_speed * delta)
	_body.rotation_degrees.y = lerp(_body.rotation_degrees.y, target_yaw_deg, yaw_lerp_speed * delta)

	# Bobbing on water
	float_time += delta * bob_frequency
	var hover_height: float = lerp(min_hover_height, max_hover_height, (sin(float_time) + 1.0) * 0.5)

	# Smoothly decay firing recoil pitch back to neutral
	_recoil_pitch = lerpf(_recoil_pitch, 0.0, delta * 9.0)

	# Process violent kinetic impact shudder
	if _shudder_timer > 0.0:
		_shudder_timer -= delta
		var shudder_prog: float = clampf(_shudder_timer / 0.25, 0.0, 1.0)
		_shudder_roll = sin(_shudder_timer * 50.0) * shudder_prog * 6.5
	else:
		_shudder_roll = 0.0

	return hover_height


## Returns the current recoil pitch offset to be applied to visuals.rotation_degrees.x.
func get_recoil_pitch() -> float:
	return _recoil_pitch


## Returns the current shudder roll offset to be applied to visuals.rotation_degrees.z.
func get_shudder_roll() -> float:
	return _shudder_roll


## Apply a firing recoil impulse to the hull pitch.
## impulse_degrees: degrees to add (accumulates up to cap).
func apply_recoil(impulse_degrees: float = 1.8) -> void:
	_recoil_pitch = clampf(_recoil_pitch + impulse_degrees, -4.0, 7.0)


## Trigger the kinetic impact shudder animation (0.25s duration).
func apply_shudder() -> void:
	_shudder_timer = 0.25


## Sync exported parameters back from PlayerSwerve after ship data is applied.
func sync_from_ship_data(speed: float, new_lerp: float) -> void:
	keyboard_speed = speed
	lerp_speed = new_lerp
