class_name LevelData
extends Resource

@export var level_name: String = "Level 1: Smuggler's Run"
@export var total_distance: float = 600.0
@export var base_scroll_speed: float = 12.0
@export var river_width_world: float = 12.0 # Converts normalized -1.0..1.0 to world X coordinates (-6.0 to +6.0)
@export var wave_events: Array[Dictionary] = [] # Distance-triggered spawns
