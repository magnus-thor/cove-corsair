class_name LevelData
extends Resource

## Modular Level Data schema for dynamic recipe-based runner level generation.

@export_group("Level Identity")
@export var level_id: int = 1
@export var level_title: String = ""
@export var biome_name: String = "tropical" # tropical, bayou, brimstone
@export var base_scroll_speed: float = 7.0
@export var chunk_scenes: Array[PackedScene] = []
@export var completion_doubloon_reward: int = 150

@export_group("Environment & Visuals")
@export var scenery_theme: ThemeSceneryData
@export var horizon_texture: Texture2D
@export var water_albedo: Color = Color(0.08, 0.58, 0.82, 0.88)
@export var fog_color: Color = Color(0.48, 0.76, 0.94, 1.0)
@export var fog_density: float = 0.0
@export var river_width_world: float = 12.0

## Resolves the active ThemeSceneryData resource, falling back to biome_name lookup if scenery_theme is unset.
func get_effective_theme() -> ThemeSceneryData:
	if scenery_theme != null and is_instance_valid(scenery_theme):
		scenery_theme.ensure_populated()
		if not scenery_theme.near_lane_props.is_empty():
			return scenery_theme
	var resolved: ThemeSceneryData = ThemeSceneryData.get_theme_for_biome(biome_name)
	if resolved != null:
		resolved.ensure_populated()
	return resolved
