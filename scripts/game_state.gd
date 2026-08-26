extends Node

## Global GameState / ScoreManager Autoload for Cove Corsair

signal doubloons_changed(new_amount: int)
signal multiplier_changed(new_multiplier: float, mode: String)
signal progress_changed(current_distance: float, total_distance: float)
signal level_completed

var doubloons: int = 0
var active_multiplier: float = 1.0
var multiplier_mode: String = "x" # "x" for multiply, "+" for add
var current_level: int = 1
var level_distance_target: float = 300.0 # meters / units to reach boss or finish
var distance_traveled: float = 0.0

func add_doubloons(amount: int) -> void:
	doubloons += amount
	doubloons_changed.emit(doubloons)

func set_multiplier(value: float, mode: String = "x") -> void:
	active_multiplier = value
	multiplier_mode = mode
	multiplier_changed.emit(active_multiplier, multiplier_mode)

func update_distance(delta_distance: float) -> void:
	distance_traveled += delta_distance
	progress_changed.emit(distance_traveled, level_distance_target)
	if distance_traveled >= level_distance_target:
		level_completed.emit()

func reset_level() -> void:
	distance_traveled = 0.0
	active_multiplier = 1.0
	multiplier_mode = "x"
	progress_changed.emit(distance_traveled, level_distance_target)
	multiplier_changed.emit(active_multiplier, multiplier_mode)
