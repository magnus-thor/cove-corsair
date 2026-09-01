class_name LevelData
extends Resource

@export var level_name: String = "Level 1: Smuggler's Run"
@export var total_distance: float = 600.0
@export var base_scroll_speed: float = 12.0
@export var river_width_world: float = 12.0 # Converts normalized -1.0..1.0 to world X coordinates (-6.0 to +6.0)
@export var biome_type: String = "smugglers_run" # "smugglers_run", "black_tide_bayou", "brimstone_bastion"
@export var water_albedo: Color = Color(0.08, 0.58, 0.82, 0.88)
@export var fog_color: Color = Color(0.12, 0.22, 0.28)
@export var fog_density: float = 0.018
@export var boss_scene: PackedScene
@export var horizon_texture: Texture2D           # Panoramic backdrop for the horizon quad (null = dark fallback)
@export var wave_events: Array[Dictionary] = [] # Distance-triggered spawns

