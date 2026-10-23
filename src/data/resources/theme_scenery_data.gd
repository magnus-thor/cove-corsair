class_name ThemeSceneryData
extends Resource

## Modular Biome Theme Scenery Data schema for Cove Corsair.
## Drives procedural depth-sorted riverbank and horizon prop assembly,
## material harmonization, and atmospheric colors per biome ("tropical", "bayou", "brimstone").

@export_group("Biome Identity")
@export var theme_name: String = "tropical"
@export var scenery_shader: Shader = preload("res://src/shaders/harmonized_scenery.gdshader")

@export_group("Depth-Sorted Prop Pools")
## Shoreline clutter: docks, rowboats, anchor ruins, cattails, rocks, crates. Boundary: |X| in [6.8m, 11.0m]
@export var near_lane_props: Array[PackedScene] = []
## Vegetation & structures: palms, mangroves, withered willows, watchtowers, rock formations. Boundary: |X| in [11.0m, 26.0m]
@export var midground_props: Array[PackedScene] = []
## Massive silhouette vistas: volcanic spires, palm islands, obsidian crystal clusters, shipwrecks, cliffs. Boundary: |X| in [26.0m, 60.0m]
@export var far_backdrop_props: Array[PackedScene] = []

@export_group("Atmospheric & Biome Aesthetics")
@export var water_albedo: Color = Color(0.08, 0.58, 0.82, 0.88)
@export var bank_color: Color = Color(0.85, 0.72, 0.48, 1.0)
@export var fog_color: Color = Color(0.48, 0.76, 0.94, 1.0)
@export var fog_density: float = 0.002

# ── Static Biome Theme Cache & Factory ────────────────────────────────────────

static var _theme_cache: Dictionary[String, ThemeSceneryData] = {}
static var _scene_cache: Dictionary[String, PackedScene] = {}

static func _load_prop_pool(paths: Array[String]) -> Array[PackedScene]:
	var pool: Array[PackedScene] = []
	for path: String in paths:
		if _scene_cache.has(path):
			var cached: PackedScene = _scene_cache[path]
			if cached != null:
				pool.append(cached)
		elif ResourceLoader.exists(path):
			var loaded: PackedScene = load(path) as PackedScene
			if loaded != null:
				_scene_cache[path] = loaded
				pool.append(loaded)
	return pool

static func _sanitize_pool(pool: Array[PackedScene]) -> Array[PackedScene]:
	var clean: Array[PackedScene] = []
	for scene: PackedScene in pool:
		if scene != null:
			clean.append(scene)
	return clean

## Guarantees that all three depth-sorted prop pools and the shader are non-empty and valid,
## even if a .tres resource was loaded before editor array re-indexing.
func ensure_populated() -> void:
	if scenery_shader == null:
		scenery_shader = preload("res://src/shaders/harmonized_scenery.gdshader")

	near_lane_props = ThemeSceneryData._sanitize_pool(near_lane_props)
	midground_props = ThemeSceneryData._sanitize_pool(midground_props)
	far_backdrop_props = ThemeSceneryData._sanitize_pool(far_backdrop_props)

	if not near_lane_props.is_empty() and not midground_props.is_empty() and not far_backdrop_props.is_empty():
		return

	var key: String = theme_name.to_lower().strip_edges()
	var fallback: ThemeSceneryData = null
	if "bayou" in key:
		fallback = ThemeSceneryData.create_black_tide_bayou_theme()
	elif "brimstone" in key or "inferno" in key or "volcanic" in key:
		fallback = ThemeSceneryData.create_brimstone_bastion_theme()
	else:
		fallback = ThemeSceneryData.create_tropical_bay_theme()

	if near_lane_props.is_empty():
		near_lane_props = fallback.near_lane_props
	if midground_props.is_empty():
		midground_props = fallback.midground_props
	if far_backdrop_props.is_empty():
		far_backdrop_props = fallback.far_backdrop_props

static func get_theme_for_biome(biome: String) -> ThemeSceneryData:
	var key: String = biome.to_lower().strip_edges()
	if "bayou" in key:
		key = "bayou"
	elif "brimstone" in key or "inferno" in key or "volcanic" in key:
		key = "brimstone"
	else:
		key = "tropical"

	if _theme_cache.has(key) and is_instance_valid(_theme_cache[key]):
		var cached_theme: ThemeSceneryData = _theme_cache[key]
		cached_theme.ensure_populated()
		return cached_theme

	var tres_path: String = "res://src/data/resources/themes/theme_tropical_bay.tres"
	if key == "bayou":
		tres_path = "res://src/data/resources/themes/theme_black_tide_bayou.tres"
	elif key == "brimstone":
		tres_path = "res://src/data/resources/themes/theme_brimstone_bastion.tres"

	if ResourceLoader.exists(tres_path):
		var loaded_res: Resource = load(tres_path)
		if loaded_res is ThemeSceneryData:
			var loaded_theme: ThemeSceneryData = loaded_res as ThemeSceneryData
			loaded_theme.ensure_populated()
			if not loaded_theme.near_lane_props.is_empty():
				_theme_cache[key] = loaded_theme
				return loaded_theme

	var generated: ThemeSceneryData = null
	if key == "bayou":
		generated = create_black_tide_bayou_theme()
	elif key == "brimstone":
		generated = create_brimstone_bastion_theme()
	else:
		generated = create_tropical_bay_theme()

	_theme_cache[key] = generated
	return generated

static func create_tropical_bay_theme() -> ThemeSceneryData:
	var theme := ThemeSceneryData.new()
	theme.theme_name = "tropical"
	theme.water_albedo = Color(0.08, 0.58, 0.82, 0.88)
	theme.bank_color = Color(0.85, 0.72, 0.48, 1.0)
	theme.fog_color = Color(0.48, 0.76, 0.94, 1.0)
	theme.fog_density = 0.002
	theme.scenery_shader = preload("res://src/shaders/harmonized_scenery.gdshader")
	theme.near_lane_props = _load_prop_pool([
		"res://assets/models/structure-platform-dock-small.glb",
		"res://assets/models/structure-platform-dock.glb",
		"res://assets/models/boat-row-small.glb",
		"res://assets/models/scenery/Rustbound_Anchor.glb",
		"res://assets/models/scenery/Tropical_Hibiscus_Blo.glb",
		"res://assets/models/rocks-sand-a.glb",
		"res://assets/models/rocks-sand-b.glb",
		"res://assets/models/patch-sand-foliage.glb",
		"res://assets/models/crate.glb",
	])
	theme.midground_props = _load_prop_pool([
		"res://assets/models/palm-detailed-bend.glb",
		"res://assets/models/palm-detailed-straight.glb",
		"res://assets/models/scenery/Coconut_Palm_Tree.glb",
		"res://assets/models/scenery/Emerald_Mangrove_Grov.glb",
		"res://assets/models/tower-complete-small.glb",
		"res://assets/models/tower-watch.glb",
		"res://assets/models/rocks-a.glb",
		"res://assets/models/rocks-b.glb",
	])
	theme.far_backdrop_props = _load_prop_pool([
		"res://assets/models/scenery/Low_Poly_Palm_Island.glb",
		"res://assets/models/ship-wreck.glb",
		"res://assets/models/tower-complete-large.glb",
		"res://assets/models/rocks-sand-c.glb",
		"res://assets/models/rocks-c.glb",
	])
	return theme

static func create_black_tide_bayou_theme() -> ThemeSceneryData:
	var theme := ThemeSceneryData.new()
	theme.theme_name = "bayou"
	theme.water_albedo = Color(0.07, 0.18, 0.14, 0.95)
	theme.bank_color = Color(0.28, 0.35, 0.25, 1.0)
	theme.fog_color = Color(0.15, 0.28, 0.22, 1.0)
	theme.fog_density = 0.024
	theme.scenery_shader = preload("res://src/shaders/harmonized_scenery.gdshader")
	theme.near_lane_props = _load_prop_pool([
		"res://assets/models/scenery/Cattails.glb",
		"res://assets/models/scenery/Cattails_in_Water.glb",
		"res://assets/models/scenery/Mosswood_Drift.glb",
		"res://assets/models/scenery/Totem_of_the_Painted.glb",
		"res://assets/models/structure-platform-small.glb",
		"res://assets/models/platform-planks.glb",
		"res://assets/models/patch-grass-foliage.glb",
		"res://assets/models/rocks-c.glb",
	])
	theme.midground_props = _load_prop_pool([
		"res://assets/models/scenery/The_Withered_Willow.glb",
		"res://assets/models/scenery/Mournwood_Tree.glb",
		"res://assets/models/scenery/Emerald_Mangrove_Grov.glb",
		"res://assets/models/tower-watch.glb",
		"res://assets/models/structure-fence.glb",
		"res://assets/models/rocks-b.glb",
	])
	theme.far_backdrop_props = _load_prop_pool([
		"res://assets/models/ship-wreck.glb",
		"res://assets/models/scenery/The_Withered_Willow.glb",
		"res://assets/models/scenery/Mournwood_Tree.glb",
		"res://assets/models/rocks-a.glb",
		"res://assets/models/rocks-c.glb",
	])
	return theme

static func create_brimstone_bastion_theme() -> ThemeSceneryData:
	var theme := ThemeSceneryData.new()
	theme.theme_name = "brimstone"
	theme.water_albedo = Color(0.24, 0.06, 0.06, 0.96)
	theme.bank_color = Color(0.22, 0.20, 0.22, 1.0)
	theme.fog_color = Color(0.40, 0.16, 0.14, 1.0)
	theme.fog_density = 0.026
	theme.scenery_shader = preload("res://src/shaders/harmonized_scenery.gdshader")
	theme.near_lane_props = _load_prop_pool([
		"res://assets/models/scenery/Molten_Crown.glb",
		"res://assets/models/scenery/Obsidian_Crystal_Clus.glb",
		"res://assets/models/scenery/Rustbound_Anchor.glb",
		"res://assets/models/castle-wall.glb",
		"res://assets/models/cannon.glb",
		"res://assets/models/rocks-a.glb",
		"res://assets/models/rocks-b.glb",
	])
	theme.midground_props = _load_prop_pool([
		"res://assets/models/scenery/Molten_Thorn_Tree.glb",
		"res://assets/models/scenery/Volcanic_Spire.glb",
		"res://assets/models/scenery/Obsidian_Crystal_Clus.glb",
		"res://assets/models/tower-complete-small.glb",
		"res://assets/models/tower-watch.glb",
		"res://assets/models/rocks-c.glb",
	])
	theme.far_backdrop_props = _load_prop_pool([
		"res://assets/models/scenery/Volcanic_Spire.glb",
		"res://assets/models/scenery/Obsidian_Crystal_Clus.glb",
		"res://assets/models/tower-complete-large.glb",
		"res://assets/models/ship-wreck.glb",
		"res://assets/models/rocks-a.glb",
	])
	return theme
