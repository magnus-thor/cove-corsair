class_name MultiplierGate
extends Area3D

enum OperationType { ADD, MULTIPLY }

@export var operation: OperationType = OperationType.ADD:
	set(val):
		operation = val
		if is_node_ready():
			update_visuals()

@export var value: int = 3:
	set(val):
		if operation == OperationType.ADD:
			value = clamp(val, 1, 5)
		else:
			value = clamp(val, 2, 3)
		if is_node_ready():
			update_visuals()

@export var is_active: bool = true
@export var cannonball_scene: PackedScene = preload("res://src/gameplay/projectiles/cannonball.tscn")

@onready var visuals: Node3D = $Visuals
@onready var label_3d: Label3D = $Visuals/Label3D

var _processed_cannonballs: Dictionary = {}

func _ready() -> void:
	add_to_group("multiplier_gate")
	area_entered.connect(_on_area_entered)
	# Enforce value clamping on ready
	if operation == OperationType.ADD:
		value = clamp(value, 1, 5)
	else:
		value = clamp(value, 2, 3)
	update_visuals()

func update_visuals() -> void:
	if label_3d:
		if operation == OperationType.ADD:
			label_3d.text = "+%d" % value
			label_3d.modulate = Color(0.2, 0.85, 1.0)
		else:
			label_3d.text = "x%d" % value
			label_3d.modulate = Color(1.0, 0.8, 0.2)
		label_3d.outline_size = 12
		label_3d.outline_modulate = Color(0.0, 0.0, 0.0, 1.0)

func _on_area_entered(area: Area3D) -> void:
	if not is_active:
		return
		
	# Ensure the entering area is a cannonball
	if not area.is_in_group("cannonballs") and not (area is Cannonball):
		return
		
	_processed_cannonballs[area] = true
	AudioManager.play_sfx("gate_passes")
	
	var mode_str = "+" if operation == OperationType.ADD else "x"
	GameState.set_multiplier(float(value), mode_str)
	
	# Play bounce animation
	_play_bounce_tween()
	
	# Calculate duplication requirements
	# Additive: output = count + value (extra = value)
	# Multiplicative: output = count * value (extra = count * (value - 1))
	var extra_needed: int = 0
	if operation == OperationType.ADD:
		extra_needed = value
	elif operation == OperationType.MULTIPLY:
		extra_needed = max(0, value - 1)
		
	var active_balls = get_tree().get_nodes_in_group("cannonballs")
	var current_count: int = active_balls.size()
	var max_simultaneous: int = 8
	
	var can_spawn: int = max(0, min(extra_needed, max_simultaneous - current_count))
	var overflow: int = extra_needed - can_spawn
	
	# If output exceeds 30, add splash AoE radius multiplier to active projectiles
	if overflow > 0:
		if "splash_radius_multiplier" in area:
			area.splash_radius_multiplier += overflow * 0.35
		for ball in active_balls:
			if is_instance_valid(ball) and "splash_radius_multiplier" in ball:
				ball.splash_radius_multiplier += overflow * 0.15
				
	# Instantiate extra projectiles up to the soft cap
	if cannonball_scene and can_spawn > 0:
		var parent = get_tree().current_scene
		if not parent:
			parent = get_parent()
			
		var origin_pos = area.global_position if (area and is_instance_valid(area) and area.is_inside_tree()) else global_position
		for i in range(can_spawn):
			var new_ball = cannonball_scene.instantiate() as Area3D
			if new_ball:
				var spread_x = randf_range(-0.7, 0.7)
				var spread_y = randf_range(-0.2, 0.2)
				
				if "speed" in area and "speed" in new_ball:
					new_ball.speed = area.speed
				if "lifetime" in area and "lifetime" in new_ball:
					new_ball.lifetime = area.lifetime
				if "splash_radius_multiplier" in area and "splash_radius_multiplier" in new_ball:
					new_ball.splash_radius_multiplier = area.splash_radius_multiplier
					
				_processed_cannonballs[new_ball] = true
				parent.add_child(new_ball)
				new_ball.global_position = origin_pos + Vector3(spread_x, spread_y, -0.2 * (i + 1))

func _play_bounce_tween() -> void:
	if not visuals:
		return
	var tween = create_tween()
	tween.tween_property(visuals, "scale", Vector3(1.25, 1.25, 1.25), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(visuals, "scale", Vector3(1.0, 1.0, 1.0), 0.12).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
