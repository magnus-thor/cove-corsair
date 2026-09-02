class_name LevelData
extends Resource

## Strongly typed Level Data schema for Cove Corsair deterministic level generation

const SpawnEvent = preload("res://src/data/spawn_event.gd")

enum StartingHull {
	DINGHY,
	SLOOP,
	IRONCLAD
}

@export_group("Level Identity")
@export var level_id: int = 1
@export var level_name: String = "Level 1: Smuggler's Run"
@export var target_distance: float = 250.0
@export var starting_hull: StartingHull = StartingHull.DINGHY

@export_group("Boss Encounter")
@export var boss_scene: PackedScene
@export var boss_hp: int = 220

@export_group("Environment & Visuals")
@export var backdrop_texture: Texture2D
@export var horizon_texture: Texture2D
@export var biome_type: String = "coastal"
@export var water_albedo: Color = Color(0.1, 0.3, 0.5, 1.0)
@export var fog_color: Color = Color(0.6, 0.7, 0.8, 1.0)
@export var fog_density: float = 0.0
@export var river_width_world: float = 12.0
@export var base_scroll_speed: float = 10.0

@export_group("Timeline Generation")
@export var timeline_events: Array[SpawnEvent] = []

# ── Backward Compatibility Aliases & Legacy Containers ───────────────────────
@export var total_distance: float:
	get:
		return target_distance
	set(val):
		target_distance = val

@export var wave_events: Array[Dictionary] = []
