extends Node

## Global GameState / ScoreManager Autoload for Cove Corsair

signal doubloons_changed(new_amount: int)
signal multiplier_changed(new_multiplier: float, mode: String)
signal progress_changed(current_distance: float, total_distance: float)
signal distance_target_reached
signal level_completed

var doubloons: int = 0
var active_multiplier: float = 1.0
var multiplier_mode: String = "x" # "x" for multiply, "+" for add
var current_level: int = 1
var level_distance_target: float = 300.0 # meters / units to reach boss or finish
var distance_traveled: float = 0.0
var boss_spawned: bool = false

func add_doubloons(amount: int) -> void:
	doubloons += amount
	doubloons_changed.emit(doubloons)

func set_multiplier(value: float, mode: String = "x") -> void:
	multiplier_mode = mode
	if mode == "x":
		active_multiplier = clamp(value, 1.0, 8.0)
	else:
		active_multiplier = clamp(value, 0.0, 12.0)
	multiplier_changed.emit(active_multiplier, multiplier_mode)

func update_distance(delta_distance: float) -> void:
	if boss_spawned:
		return
	distance_traveled = min(level_distance_target, distance_traveled + delta_distance)
	progress_changed.emit(distance_traveled, level_distance_target)
	if distance_traveled >= level_distance_target and not boss_spawned:
		boss_spawned = true
		distance_target_reached.emit()

func reset_level() -> void:
	distance_traveled = 0.0
	boss_spawned = false
	active_multiplier = 1.0
	multiplier_mode = "x"
	progress_changed.emit(distance_traveled, level_distance_target)
	multiplier_changed.emit(active_multiplier, multiplier_mode)

