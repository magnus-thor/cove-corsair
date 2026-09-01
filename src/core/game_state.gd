extends Node

## Global GameState / ScoreManager Autoload for Cove Corsair

signal doubloons_changed(new_amount: int)
signal multiplier_changed(new_multiplier: float, mode: String)
signal progress_changed(current_distance: float, total_distance: float)
signal distance_target_reached
signal level_completed(doubloons: int, targets: int)
signal campaign_completed(total_doubloons: int, total_targets: int)
signal boss_spawned_event(boss_name: String, max_val: int)
signal boss_health_changed(current: int, max_val: int)

var doubloons: int = 0
var targets_destroyed: int = 0
var active_multiplier: float = 1.0
var multiplier_mode: String = "x" # "x" for multiply, "+" for add
var current_level: int = 1
var unlocked_levels: int = 1
var level_distance_target: float = 250.0 # meters / units to reach boss or finish
var distance_traveled: float = 0.0
var is_game_active: bool = false
var boss_spawned: bool = false

const LEVEL_RESOURCES: Dictionary = {
	1: "res://src/data/resources/levels/level_01_smugglers_run.tres",
	2: "res://src/data/resources/levels/level_02_black_tide_bayou.tres",
	3: "res://src/data/resources/levels/level_03_brimstone_bastion.tres"
}

const LEVEL_SHIPS: Dictionary = {
	1: "res://src/data/resources/user_vessels/dinghy_ship.tres",
	2: "res://src/data/resources/user_vessels/sloop_ship.tres",
	3: "res://src/data/resources/user_vessels/ironclad_ship.tres"
}

func get_current_level_resource() -> LevelData:
	var path = LEVEL_RESOURCES.get(current_level, LEVEL_RESOURCES[1])
	if ResourceLoader.exists(path):
		return load(path) as LevelData
	return null

func get_current_ship_resource() -> ShipData:
	var path = LEVEL_SHIPS.get(current_level, LEVEL_SHIPS[1])
	if ResourceLoader.exists(path):
		return load(path) as ShipData
	return null

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
	if not is_game_active or boss_spawned:
		return
	distance_traveled = min(level_distance_target, distance_traveled + delta_distance)
	progress_changed.emit(distance_traveled, level_distance_target)

func unlock_next_level() -> void:
	unlocked_levels = max(unlocked_levels, current_level + 1)

func is_campaign_complete() -> bool:
	return current_level >= 3

func reset_level() -> void:
	doubloons = 0
	targets_destroyed = 0
	distance_traveled = 0.0
	is_game_active = false
	boss_spawned = false
	active_multiplier = 1.0
	multiplier_mode = "x"
	doubloons_changed.emit(doubloons)
	progress_changed.emit(distance_traveled, level_distance_target)
	multiplier_changed.emit(active_multiplier, multiplier_mode)

