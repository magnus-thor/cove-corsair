extends Node3D

# ──────────────────────────────────────────────────────────────────────────────
# RIVERBANK PROPS – Layer 2 Organic 3-Tier Natural Shoreline System
#
# Generates an organic, tiered natural shoreline using verified Kenney pirate
# assets. Fully replaces continuous wooden dock piers and primitive shapes
# (CylinderMesh, SphereMesh) with:
#   - Tier 1: Jagged Shoreline (X ≈ ±4.0m to ±4.5m)
#       Low-poly sand patches & overlapping shoreline boulders.
#   - Tier 2: Canopy & Overhangs (X ≈ ±5.0m)
#       Bent palms leaning toward river center with generous vertical
#       clearance (>4.5m) above water plane to prevent clipping with tall
#       vessels like the Ironclad; understory grass tufts.
#   - Tier 3: Natural Cliff Ridge (X ≈ ±6.5m to ±8.5m)
#       Stacked towering rock formations replacing primitive boxes/cylinders.
#   - Rare Flavor:
#       Stranded shipwrecks, isolated ruined dock sections, and weathered barrels.
#
# Performance & Mobile Batching:
#   - Shared material with res://assets/models/Textures/colormap.png
#   - cull_mode = BaseMaterial3D.CULL_BACK (no redundant backfaces)
#   - Shadows disabled on scenery geometry (SHADOW_CASTING_SETTING_OFF)
#   - Zero realtime point lights
# ──────────────────────────────────────────────────────────────────────────────

# ── Verified Asset Manifest Constants ──────────────────────────────────────────

## Tropical Biome Assets
const TROPICAL_SAND_PATHS: Array[String] = [
	"res://assets/models/patch-sand.glb",
	"res://assets/models/patch-sand-foliage.glb",
]
const TROPICAL_ROCKS_PATHS: Array[String] = [
	"res://assets/models/rocks-sand-a.glb",
	"res://assets/models/rocks-sand-b.glb",
	"res://assets/models/rocks-sand-c.glb",
]
const PALM_BEND_PATHS: Array[String] = [
	"res://assets/models/palm-detailed-bend.glb",
	"res://assets/models/palm-bend.glb",
]
const PALM_STRAIGHT_PATH := "res://assets/models/palm-detailed-straight.glb"
const FOLIAGE_TUFT_PATH := "res://assets/models/grass-plant.glb"
const TROPICAL_CLIFF_PATHS: Array[String] = [
	"res://assets/models/rocks-sand-a.glb",
	"res://assets/models/rocks-sand-b.glb",
	"res://assets/models/rocks-sand-c.glb",
	"res://assets/models/rocks-a.glb",
	"res://assets/models/rocks-b.glb",
]

## Bayou Biome Assets (Mangrove Marsh & Stilt Docks)
const BAYOU_PATCH_PATHS: Array[String] = [
	"res://assets/models/patch-grass.glb",
	"res://assets/models/patch-grass-foliage.glb",
	"res://assets/models/grass-patch.glb",
]
const BAYOU_ROCK_PATHS: Array[String] = [
	"res://assets/models/rocks-c.glb",
	"res://assets/models/rocks-b.glb",
	"res://assets/models/rocks-sand-c.glb",
]
const BAYOU_STRUCTURE_PATHS: Array[String] = [
	"res://assets/models/structure-platform-dock-small.glb",
	"res://assets/models/structure-platform-small.glb",
	"res://assets/models/platform-planks.glb",
]

## Pirate Citadel & Fortified Reach Assets (Stone Bastions & Palisades)
const CITADEL_WALL_PATHS: Array[String] = [
	"res://assets/models/castle-wall.glb",
	"res://assets/models/structure-fence.glb",
	"res://assets/models/structure-fence-sides.glb",
]
const CITADEL_TOWER_PATHS: Array[String] = [
	"res://assets/models/tower-complete-small.glb",
	"res://assets/models/tower-watch.glb",
	"res://assets/models/tower-base.glb",
]
const CITADEL_ROCK_PATHS: Array[String] = [
	"res://assets/models/rocks-a.glb",
	"res://assets/models/rocks-b.glb",
	"res://assets/models/rocks-c.glb",
]

## Volcanic Brimstone Assets (Basalt Crags & Charred Remains)
const BRIMSTONE_ROCK_PATHS: Array[String] = [
	"res://assets/models/rocks-a.glb",
	"res://assets/models/rocks-b.glb",
	"res://assets/models/rocks-c.glb",
]

## Shared Flavor Accents
const FLAVOR_SHIPWRECK := "res://assets/models/ship-wreck.glb"
const FLAVOR_DOCK_RUIN := "res://assets/models/structure-platform-dock-small.glb"
const FLAVOR_BARREL    := "res://assets/models/barrel.glb"
const FLAVOR_CANNON    := "res://assets/models/cannon.glb"
const FLAVOR_CRATE     := "res://assets/models/crate.glb"

## Custom Stylized Scenery Models (assets/models/scenery/)
const SCENERY_MANGROVE_GROVE    := "res://assets/models/scenery/Emerald_Mangrove_Grov.glb"
const SCENERY_PALM_ISLAND       := "res://assets/models/scenery/Low_Poly_Palm_Island.glb"
const SCENERY_MOLTEN_CROWN      := "res://assets/models/scenery/Molten_Crown.glb"
const SCENERY_MOLTEN_TREE       := "res://assets/models/scenery/Molten_Thorn_Tree.glb"
const SCENERY_MOSSWOOD_DRIFT    := "res://assets/models/scenery/Mosswood_Drift.glb"
const SCENERY_OBSIDIAN_CRYSTAL  := "res://assets/models/scenery/Obsidian_Crystal_Clus.glb"
const SCENERY_PAINTED_TOTEM     := "res://assets/models/scenery/Totem_of_the_Painted.glb"
const SCENERY_LAVA_GEYSER_VFX   := "res://src/vfx/vfx_lava_geyser.tscn"
const SCENERY_VOLCANIC_SPIRE    := "res://assets/models/scenery/Volcanic_Spire.glb"
const SCENERY_MOURNWOOD_TREE    := "res://assets/models/scenery/Mournwood_Tree.glb"
const SCENERY_WITHERED_WILLOW   := "res://assets/models/scenery/The_Withered_Willow.glb"
const SCENERY_CATTAILS          := "res://assets/models/scenery/Cattails.glb"
const SCENERY_CATTAILS_WATER    := "res://assets/models/scenery/Cattails_in_Water.glb"
const SCENERY_TROPICAL_BUSH     := "res://assets/models/scenery/Tropical_Hibiscus_Blo.glb"
const SCENERY_COCONUT_PALM      := "res://assets/models/scenery/Coconut_Palm_Tree.glb"
const SCENERY_RUSTBOUND_ANCHOR  := "res://assets/models/scenery/Rustbound_Anchor.glb"

# ── Shared Materials for Mobile Batching ───────────────────────────────────────

static var _shared_mat_tropical: StandardMaterial3D = null
static var _shared_mat_bayou:    StandardMaterial3D = null
static var _shared_mat_citadel:  StandardMaterial3D = null
static var _shared_mat_bastion:  StandardMaterial3D = null

static var _scenery_cache: Dictionary[String, PackedScene] = {}

static func _get_or_create_material(p_biome: String) -> StandardMaterial3D:
	var b := p_biome.to_lower()
	if "bayou" in b:
		if _shared_mat_bayou == null:
			_shared_mat_bayou = StandardMaterial3D.new()
			_shared_mat_bayou.cull_mode = BaseMaterial3D.CULL_BACK
			_shared_mat_bayou.roughness = 0.9
			_shared_mat_bayou.albedo_color = Color(0.58, 0.68, 0.54)
			_shared_mat_bayou.albedo_texture = preload("res://assets/models/Textures/colormap.png")
		return _shared_mat_bayou
	elif "citadel" in b or "fort" in b or "corsair" in b:
		if _shared_mat_citadel == null:
			_shared_mat_citadel = StandardMaterial3D.new()
			_shared_mat_citadel.cull_mode = BaseMaterial3D.CULL_BACK
			_shared_mat_citadel.roughness = 0.88
			_shared_mat_citadel.albedo_color = Color(0.68, 0.64, 0.62)
			_shared_mat_citadel.albedo_texture = preload("res://assets/models/Textures/colormap.png")
		return _shared_mat_citadel
	elif "brimstone" in b or "inferno" in b or "volcanic" in b:
		if _shared_mat_bastion == null:
			_shared_mat_bastion = StandardMaterial3D.new()
			_shared_mat_bastion.cull_mode = BaseMaterial3D.CULL_BACK
			_shared_mat_bastion.roughness = 0.95
			_shared_mat_bastion.albedo_color = Color(0.48, 0.42, 0.42)
			_shared_mat_bastion.albedo_texture = preload("res://assets/models/Textures/colormap.png")
		return _shared_mat_bastion
	else:
		if _shared_mat_tropical == null:
			_shared_mat_tropical = StandardMaterial3D.new()
			_shared_mat_tropical.cull_mode = BaseMaterial3D.CULL_BACK
			_shared_mat_tropical.roughness = 0.85
			_shared_mat_tropical.albedo_color = Color.WHITE
			_shared_mat_tropical.albedo_texture = preload("res://assets/models/Textures/colormap.png")
		return _shared_mat_tropical

# ──────────────────────────────────────────────────────────────────────────────

var side         : String = "left"
var chunk_length : float  = 40.0
var biome        : String = "tropical"

func _ready() -> void:
	add_to_group("riverbank_chunk")

# ── Public API ────────────────────────────────────────────────────────────────

func setup(p_side: String, p_length: float = 40.0, p_biome: String = "tropical", p_seed: int = 0) -> void:
	side         = p_side
	chunk_length = p_length
	biome        = p_biome
	if p_seed != 0:
		seed(p_seed)
	_generate()

# ── Internal Generation ───────────────────────────────────────────────────────

func _generate() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()

	_setup_bank_scenery_slots()

	var b := biome.to_lower()
	if "bayou" in b:
		_generate_bayou_shoreline()
	elif "citadel" in b or "fort" in b or "corsair" in b:
		_generate_citadel_shoreline()
	elif "brimstone" in b or "inferno" in b or "volcanic" in b:
		_generate_brimstone_shoreline()
	else:
		_generate_tropical_shoreline()

func _setup_bank_scenery_slots() -> void:
	var slots_container := Node3D.new()
	slots_container.name = "BankScenerySlots"
	add_child(slots_container)

	var multimesh_inst := MultiMeshInstance3D.new()
	multimesh_inst.name = "BankSceneryMultiMesh"
	multimesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	multimesh_inst.extra_cull_margin = 100.0
	slots_container.add_child(multimesh_inst)

	var step := 10.0
	var slot_count := ceili(chunk_length / step)
	var shore_x := -6.8 if side == "left" else 6.8
	var start_z := -chunk_length * 0.5

	for i in range(slot_count):
		var marker := Marker3D.new()
		marker.name = "Slot_%d" % i
		marker.position = Vector3(shore_x, 0.0, start_z + (i + 0.5) * step)
		slots_container.add_child(marker)

# ──────────────────────────────────────────────────────────────────────────────
# TROPICAL ARCHIPELAGO SHORELINE GENERATION
# ──────────────────────────────────────────────────────────────────────────────

func _generate_tropical_shoreline() -> void:
	var is_left: bool = (side == "left")
	var sign_x: float = -1.0 if is_left else 1.0
	var half_len: float = chunk_length * 0.5
	var active_mat: StandardMaterial3D = _get_or_create_material("tropical")

	# Tier 1: Sandy Beach & Overlapping Water Rocks (|X| >= 6.8m)
	var sand_count := randi_range(5, 7)
	var sand_step := chunk_length / float(sand_count)
	for i in range(sand_count):
		var z_pos := -half_len + (i + 0.5) * sand_step + randf_range(-0.5, 0.5)
		var sand_path := TROPICAL_SAND_PATHS[randi() % TROPICAL_SAND_PATHS.size()]
		var sand_node := _instantiate_prop(sand_path, active_mat)
		if sand_node:
			sand_node.position = Vector3(sign_x * randf_range(7.2, 8.0), 0.08, z_pos)
			var s_xz := randf_range(0.26, 0.35)
			sand_node.scale = Vector3(s_xz, randf_range(0.6, 0.8), s_xz)
			sand_node.rotation.y = randf_range(0.0, TAU)
			_enforce_navigable_clearance(sand_node, is_left, 6.6)

	var rock_count := randi_range(5, 7)
	var rock_step := chunk_length / float(rock_count)
	for i in range(rock_count):
		var z_pos := -half_len + (i + 0.75) * rock_step + randf_range(-0.6, 0.6)
		var rock_path := TROPICAL_ROCKS_PATHS[randi() % TROPICAL_ROCKS_PATHS.size()]
		var rock_node := _instantiate_prop(rock_path, active_mat)
		if rock_node:
			rock_node.position = Vector3(sign_x * randf_range(7.0, 7.8), randf_range(0.08, 0.14), z_pos)
			var s_val := randf_range(0.24, 0.32)
			rock_node.scale = Vector3(s_val, s_val * randf_range(0.9, 1.2), s_val)
			rock_node.rotation.y = randf_range(0.0, TAU)
			_enforce_navigable_clearance(rock_node, is_left, 6.6)

	# Custom Scenery: Low-Poly Palm Shoal Island
	if randf() < 0.45:
		var island_node := _instantiate_custom_scenery(SCENERY_PALM_ISLAND)
		if island_node:
			var s_val := randf_range(1.1, 1.4)
			island_node.scale = Vector3.ONE * s_val
			island_node.position = Vector3(sign_x * randf_range(7.8, 8.8), 0.65 * s_val, randf_range(-half_len * 0.7, half_len * 0.7))
			island_node.rotation.y = randf_range(0.0, TAU)
			_enforce_navigable_clearance(island_node, is_left, 6.6)

	# Tier 2: Leaning Palms & Grass Tufts (|X| >= 8.2m)
	var palm_count := randi_range(3, 4)
	var palm_step := chunk_length / float(palm_count)
	for i in range(palm_count):
		var z_pos := -half_len + (i + 0.5) * palm_step + randf_range(-1.2, 1.2)
		var is_bent := randf() < 0.8
		var palm_path := PALM_BEND_PATHS[randi() % PALM_BEND_PATHS.size()] if is_bent else PALM_STRAIGHT_PATH
		var palm_node := _instantiate_prop(palm_path, active_mat)
		if palm_node:
			palm_node.position = Vector3(sign_x * randf_range(8.2, 9.2), randf_range(0.10, 0.15), z_pos)
			palm_node.scale = Vector3.ONE * randf_range(1.0, 1.15)
			var lean_base_angle: float = PI if is_left else 0.0
			palm_node.rotation.y = lean_base_angle + randf_range(-0.08, 0.08) if is_bent else randf_range(0.0, TAU)
			_enforce_navigable_clearance(palm_node, is_left, 6.6)

			var tuft_count := randi_range(1, 2)
			for t in range(tuft_count):
				var tuft_node := _instantiate_prop(FOLIAGE_TUFT_PATH, active_mat)
				if tuft_node:
					var angle := (float(t) / float(tuft_count)) * TAU
					var offset := Vector3(cos(angle) * 0.5, -0.03, sin(angle) * 0.5)
					tuft_node.position = palm_node.position + offset
					tuft_node.scale = Vector3.ONE * randf_range(0.5, 0.75)
					tuft_node.rotation.y = randf_range(0.0, TAU)
					_enforce_navigable_clearance(tuft_node, is_left, 6.6)

	# Custom Scenery: Tropical Flowering Bush (understory landmark)
	var bush_count: int = 1 if randf() < 0.60 else 0
	var bush_step := chunk_length / maxf(float(bush_count), 1.0)
	for i in range(bush_count):
		var z_pos := -half_len + (i + 0.5) * bush_step + randf_range(-1.0, 1.0)
		var bush_node := _instantiate_custom_scenery(SCENERY_TROPICAL_BUSH)
		if bush_node:
			var s_val := randf_range(0.9, 1.3)
			bush_node.scale = Vector3.ONE * s_val
			bush_node.position = Vector3(sign_x * randf_range(7.4, 8.4), 0.52 * s_val, z_pos)
			bush_node.rotation.y = randf_range(0.0, TAU)
			_enforce_navigable_clearance(bush_node, is_left, 6.6)

	# Custom Scenery: Coconut Palm Sapling/Tree (landmark)
	var coco_count: int = 1 if randf() < 0.65 else 0
	var coco_step := chunk_length / maxf(float(coco_count), 1.0)
	for i in range(coco_count):
		var z_pos := -half_len + (i + 0.6) * coco_step + randf_range(-1.0, 1.0)
		var coco_node := _instantiate_custom_scenery(SCENERY_COCONUT_PALM)
		if coco_node:
			var s_val := randf_range(1.1, 1.4)
			coco_node.scale = Vector3.ONE * s_val
			coco_node.position = Vector3(sign_x * randf_range(8.4, 9.4), 0.95 * s_val, z_pos)
			coco_node.rotation.y = randf_range(0.0, TAU)
			_enforce_navigable_clearance(coco_node, is_left, 6.6)

	# Custom Scenery: Rustbound Anchor (flavor prop half-buried in sand)
	if randf() < 0.35:
		var anchor_node := _instantiate_custom_scenery(SCENERY_RUSTBOUND_ANCHOR)
		if anchor_node:
			var s_val := randf_range(0.9, 1.2)
			anchor_node.scale = Vector3.ONE * s_val
			anchor_node.position = Vector3(sign_x * randf_range(7.2, 8.0), 0.45 * s_val, randf_range(-half_len * 0.7, half_len * 0.7))
			anchor_node.rotation.y = randf_range(0.0, TAU)
			anchor_node.rotation.z = sign_x * randf_range(0.10, 0.25)
			_enforce_navigable_clearance(anchor_node, is_left, 6.6)

	# Custom Scenery: Lush Mangrove Cluster with arching waterline roots
	if randf() < 0.50:
		var mangrove_node := _instantiate_custom_scenery(SCENERY_MANGROVE_GROVE)
		if mangrove_node:
			var s_val := randf_range(1.2, 1.5)
			mangrove_node.scale = Vector3.ONE * s_val
			mangrove_node.position = Vector3(sign_x * randf_range(8.2, 9.2), 0.50 * s_val, randf_range(-half_len * 0.6, half_len * 0.6))
			mangrove_node.rotation.y = randf_range(0.0, TAU)
			_enforce_navigable_clearance(mangrove_node, is_left, 6.6)

	# Tier 3: Natural Cliff Ridge (|X| >= 10.5m)
	var cliff_count := randi_range(4, 6)
	var cliff_step := chunk_length / float(cliff_count)
	for i in range(cliff_count):
		var z_pos := -half_len + (i + 0.5) * cliff_step + randf_range(-1.5, 1.5)
		var cliff_path := TROPICAL_CLIFF_PATHS[randi() % TROPICAL_CLIFF_PATHS.size()]
		var cliff_node := _instantiate_prop(cliff_path, active_mat)
		if cliff_node:
			cliff_node.position = Vector3(sign_x * randf_range(10.5, 12.5), randf_range(0.06, 0.15), z_pos)
			var base_scale := randf_range(1.0, 1.3)
			cliff_node.scale = Vector3(base_scale, base_scale * randf_range(1.4, 1.8), base_scale)
			cliff_node.rotation.y = randf_range(0.0, TAU)
			_enforce_navigable_clearance(cliff_node, is_left, 6.6)

	if randf() < 0.2:
		var wreck := _instantiate_prop(FLAVOR_SHIPWRECK, active_mat)
		if wreck:
			wreck.position = Vector3(sign_x * randf_range(9.5, 11.0), 0.06, randf_range(-half_len * 0.6, half_len * 0.6))
			wreck.scale = Vector3.ONE * 0.55
			wreck.rotation.y = (0.0 if randf() < 0.5 else PI) + randf_range(-0.25, 0.25)
			wreck.rotation.z = sign_x * randf_range(0.10, 0.20)
			_enforce_navigable_clearance(wreck, is_left, 6.6)

# ──────────────────────────────────────────────────────────────────────────────
# BLACK TIDE BAYOU SHORELINE GENERATION (MANGROVES, DEADWOOD & STILTS)
# ──────────────────────────────────────────────────────────────────────────────

func _generate_bayou_shoreline() -> void:
	var is_left: bool = (side == "left")
	var sign_x: float = -1.0 if is_left else 1.0
	var half_len: float = chunk_length * 0.5
	var active_mat: StandardMaterial3D = _get_or_create_material("black_tide_bayou")

	# Tier 1: Overgrown Swamp Grass & Mossy Shoreline Rocks
	var patch_count := randi_range(6, 8)
	var patch_step := chunk_length / float(patch_count)
	for i in range(patch_count):
		var z_pos := -half_len + (i + 0.5) * patch_step + randf_range(-0.6, 0.6)
		var patch_path := BAYOU_PATCH_PATHS[randi() % BAYOU_PATCH_PATHS.size()]
		var patch_node := _instantiate_prop(patch_path, active_mat)
		if patch_node:
			patch_node.position = Vector3(sign_x * randf_range(7.2, 8.2), 0.06, z_pos)
			var s_xz := randf_range(0.35, 0.5)
			patch_node.scale = Vector3(s_xz, randf_range(0.4, 0.7), s_xz)
			patch_node.rotation.y = randf_range(0.0, TAU)
			_enforce_navigable_clearance(patch_node, is_left, 6.6)

	var rock_count := randi_range(5, 7)
	var rock_step := chunk_length / float(rock_count)
	for i in range(rock_count):
		var z_pos := -half_len + (i + 0.5) * rock_step + randf_range(-0.5, 0.5)
		var rock_path := BAYOU_ROCK_PATHS[randi() % BAYOU_ROCK_PATHS.size()]
		var rock_node := _instantiate_prop(rock_path, active_mat)
		if rock_node:
			rock_node.position = Vector3(sign_x * randf_range(7.0, 8.0), 0.08, z_pos)
			var s_val := randf_range(0.25, 0.35)
			rock_node.scale = Vector3(s_val, s_val * randf_range(0.8, 1.3), s_val)
			rock_node.rotation.y = randf_range(0.0, TAU)
			_enforce_navigable_clearance(rock_node, is_left, 6.6)

	# Custom Scenery: Mossy Driftwood Log along the waterline
	var drift_count: int = 1 if randf() < 0.60 else 0
	var drift_step := chunk_length / maxf(float(drift_count), 1.0)
	for i in range(drift_count):
		var z_pos := -half_len + (i + 0.5) * drift_step + randf_range(-1.0, 1.0)
		var drift_node := _instantiate_custom_scenery(SCENERY_MOSSWOOD_DRIFT)
		if drift_node:
			var s_val := randf_range(1.1, 1.4)
			drift_node.scale = Vector3.ONE * s_val
			drift_node.position = Vector3(sign_x * randf_range(7.2, 8.0), 0.18 * s_val, z_pos)
			drift_node.rotation.y = randf_range(0.0, TAU)
			drift_node.rotation.z = sign_x * randf_range(-0.06, 0.06)
			_enforce_navigable_clearance(drift_node, is_left, 6.6)

	# Custom Scenery: Swamp Cattail Reeds along waterline (landmark)
	var cattail_count: int = 1 if randf() < 0.85 else 0
	var cattail_step := chunk_length / maxf(float(cattail_count), 1.0)
	for i in range(cattail_count):
		var z_pos := -half_len + (i + 0.5) * cattail_step + randf_range(-0.8, 0.8)
		var reed_path := SCENERY_CATTAILS_WATER if randf() < 0.5 else SCENERY_CATTAILS
		var reed_node := _instantiate_custom_scenery(reed_path)
		if reed_node:
			var s_val := randf_range(1.0, 1.4)
			reed_node.scale = Vector3.ONE * s_val
			reed_node.position = Vector3(sign_x * randf_range(7.0, 7.8), 0.72 * s_val, z_pos)
			reed_node.rotation.y = randf_range(0.0, TAU)
			_enforce_navigable_clearance(reed_node, is_left, 6.6)

	# Tier 2: Ruined Stilt Dock Platforms & Dense Reeds
	var dock_count := randi_range(1, 2)
	var dock_step := chunk_length / float(dock_count)
	for i in range(dock_count):
		var z_pos := -half_len + (i + 0.5) * dock_step + randf_range(-1.0, 1.0)
		var dock_path := BAYOU_STRUCTURE_PATHS[randi() % BAYOU_STRUCTURE_PATHS.size()]
		var dock_node := _instantiate_prop(dock_path, active_mat)
		if dock_node:
			dock_node.position = Vector3(sign_x * randf_range(7.5, 8.5), 0.05, z_pos)
			dock_node.scale = Vector3(randf_range(0.8, 1.1), 0.9, randf_range(0.8, 1.1))
			dock_node.rotation.y = randf_range(0.0, TAU)
			dock_node.rotation.z = sign_x * randf_range(0.04, 0.08) # slightly dilapidated tilt
			_enforce_navigable_clearance(dock_node, is_left, 6.6)

	# Custom Scenery: Dead Swamp Trees (Mournwood / Withered Willow, landmark)
	var swamp_tree_count: int = 1 if randf() < 0.85 else 0
	var swamp_tree_step := chunk_length / maxf(float(swamp_tree_count), 1.0)
	for i in range(swamp_tree_count):
		var z_pos := -half_len + (i + 0.5) * swamp_tree_step + randf_range(-1.2, 1.2)
		var tree_path := SCENERY_WITHERED_WILLOW if randf() < 0.5 else SCENERY_MOURNWOOD_TREE
		var tree_node := _instantiate_custom_scenery(tree_path)
		if tree_node:
			var s_val := randf_range(1.2, 1.6)
			tree_node.scale = Vector3.ONE * s_val
			tree_node.position = Vector3(sign_x * randf_range(8.2, 9.5), 0.76 * s_val, z_pos)
			tree_node.rotation.y = randf_range(0.0, TAU)
			_enforce_navigable_clearance(tree_node, is_left, 6.6)

	# Custom Scenery: Swamp Mangrove Trees with twisted aerial roots
	var mangrove_count: int = 1 if randf() < 0.60 else 0
	var mangrove_step := chunk_length / maxf(float(mangrove_count), 1.0)
	for i in range(mangrove_count):
		var z_pos := -half_len + (i + 0.5) * mangrove_step + randf_range(-1.2, 1.2)
		var mangrove_node := _instantiate_custom_scenery(SCENERY_MANGROVE_GROVE)
		if mangrove_node:
			var s_val := randf_range(1.3, 1.7)
			mangrove_node.scale = Vector3.ONE * s_val
			mangrove_node.position = Vector3(sign_x * randf_range(8.0, 9.2), 0.50 * s_val, z_pos)
			mangrove_node.rotation.y = randf_range(0.0, TAU)
			_enforce_navigable_clearance(mangrove_node, is_left, 6.6)

	# Custom Scenery: Voodoo Painted Totem Pole
	var totem_count: int = 1 if randf() < 0.50 else 0
	var totem_step := chunk_length / maxf(float(totem_count), 1.0)
	for i in range(totem_count):
		var z_pos := -half_len + (i + 0.5) * totem_step + randf_range(-1.0, 1.0)
		var totem_node := _instantiate_custom_scenery(SCENERY_PAINTED_TOTEM)
		if totem_node:
			var s_val := randf_range(1.0, 1.3)
			totem_node.scale = Vector3.ONE * s_val
			totem_node.position = Vector3(sign_x * randf_range(7.6, 8.6), 0.88 * s_val, z_pos)
			var base_facing: float = PI * 0.5 if is_left else -PI * 0.5
			totem_node.rotation.y = base_facing + randf_range(-0.35, 0.35)
			totem_node.rotation.z = sign_x * randf_range(0.02, 0.08)
			_enforce_navigable_clearance(totem_node, is_left, 6.6)

	# Tier 3: Swamp Cliffs & Sunken Hulks
	var cliff_count := randi_range(4, 5)
	var cliff_step := chunk_length / float(cliff_count)
	for i in range(cliff_count):
		var z_pos := -half_len + (i + 0.5) * cliff_step + randf_range(-1.5, 1.5)
		var cliff_node := _instantiate_prop(BAYOU_ROCK_PATHS[randi() % BAYOU_ROCK_PATHS.size()], active_mat)
		if cliff_node:
			cliff_node.position = Vector3(sign_x * randf_range(10.5, 12.0), 0.1, z_pos)
			var base_scale := randf_range(1.1, 1.4)
			cliff_node.scale = Vector3(base_scale, base_scale * randf_range(1.5, 2.0), base_scale)
			cliff_node.rotation.y = randf_range(0.0, TAU)
			_enforce_navigable_clearance(cliff_node, is_left, 6.6)

	if randf() < 0.35:
		var wreck := _instantiate_prop(FLAVOR_SHIPWRECK, active_mat)
		if wreck:
			wreck.position = Vector3(sign_x * randf_range(9.0, 10.5), 0.04, randf_range(-half_len * 0.5, half_len * 0.5))
			wreck.scale = Vector3.ONE * 0.5
			wreck.rotation.y = randf_range(0.0, TAU)
			wreck.rotation.x = randf_range(-0.1, 0.1)
			_enforce_navigable_clearance(wreck, is_left, 6.6)

# ──────────────────────────────────────────────────────────────────────────────
# PIRATE CITADEL & FORTIFIED STRAITS SHORELINE (TOWERS, WALLS & BARRICADES)
# ──────────────────────────────────────────────────────────────────────────────

func _generate_citadel_shoreline() -> void:
	var is_left: bool = (side == "left")
	var sign_x: float = -1.0 if is_left else 1.0
	var half_len: float = chunk_length * 0.5
	var active_mat: StandardMaterial3D = _get_or_create_material("pirate_citadel")

	# Tier 1: Timber Palisade & Stone Waterfront
	var wall_count := randi_range(3, 4)
	var wall_step := chunk_length / float(wall_count)
	for i in range(wall_count):
		var z_pos := -half_len + (i + 0.5) * wall_step + randf_range(-0.5, 0.5)
		var wall_path := CITADEL_WALL_PATHS[randi() % CITADEL_WALL_PATHS.size()]
		var wall_node := _instantiate_prop(wall_path, active_mat)
		if wall_node:
			wall_node.position = Vector3(sign_x * randf_range(7.5, 8.5), 0.05, z_pos)
			wall_node.scale = Vector3(1.2, 1.2, 1.4)
			wall_node.rotation.y = (0.0 if randf() < 0.5 else PI) + randf_range(-0.1, 0.1)
			_enforce_navigable_clearance(wall_node, is_left, 6.6)

	# Tier 2: Fortified Watchtowers & Emplaced Cannons
	var tower_count := randi_range(2, 3)
	var tower_step := chunk_length / float(tower_count)
	for i in range(tower_count):
		var z_pos := -half_len + (i + 0.5) * tower_step + randf_range(-1.0, 1.0)
		var tower_path := CITADEL_TOWER_PATHS[randi() % CITADEL_TOWER_PATHS.size()]
		var tower_node := _instantiate_prop(tower_path, active_mat)
		if tower_node:
			tower_node.position = Vector3(sign_x * randf_range(8.5, 9.8), 0.1, z_pos)
			tower_node.scale = Vector3.ONE * randf_range(0.8, 1.0)
			tower_node.rotation.y = randf_range(0.0, TAU)
			_enforce_navigable_clearance(tower_node, is_left, 6.6)

			# Emplaced Cannon next to watchtower
			var cannon := _instantiate_prop(FLAVOR_CANNON, active_mat)
			if cannon:
				cannon.position = tower_node.position + Vector3(sign_x * -1.2, 0.0, randf_range(-1.0, 1.0))
				cannon.scale = Vector3.ONE * 0.9
				cannon.rotation.y = (PI * 0.5 if is_left else -PI * 0.5) + randf_range(-0.1, 0.1)
				_enforce_navigable_clearance(cannon, is_left, 6.6)

	# Tier 3: Fortress Sea Cliffs
	var cliff_count := randi_range(4, 6)
	var cliff_step := chunk_length / float(cliff_count)
	for i in range(cliff_count):
		var z_pos := -half_len + (i + 0.5) * cliff_step + randf_range(-1.5, 1.5)
		var cliff_path := CITADEL_ROCK_PATHS[randi() % CITADEL_ROCK_PATHS.size()]
		var cliff_node := _instantiate_prop(cliff_path, active_mat)
		if cliff_node:
			cliff_node.position = Vector3(sign_x * randf_range(11.0, 12.5), 0.1, z_pos)
			var base_scale := randf_range(1.2, 1.5)
			cliff_node.scale = Vector3(base_scale, base_scale * randf_range(1.5, 2.2), base_scale)
			cliff_node.rotation.y = randf_range(0.0, TAU)
			_enforce_navigable_clearance(cliff_node, is_left, 6.6)

# ──────────────────────────────────────────────────────────────────────────────
# BRIMSTONE BASTION & VOLCANIC SHORELINE (BASALT CRAGS & CHARRED WOOD)
# ──────────────────────────────────────────────────────────────────────────────

func _generate_brimstone_shoreline() -> void:
	var is_left: bool = (side == "left")
	var sign_x: float = -1.0 if is_left else 1.0
	var half_len: float = chunk_length * 0.5
	var active_mat: StandardMaterial3D = _get_or_create_material("brimstone_bastion")

	# Tier 1: Jagged Basalt Rocks along waterline
	var rock_count := randi_range(6, 8)
	var rock_step := chunk_length / float(rock_count)
	for i in range(rock_count):
		var z_pos := -half_len + (i + 0.5) * rock_step + randf_range(-0.6, 0.6)
		var rock_path := BRIMSTONE_ROCK_PATHS[randi() % BRIMSTONE_ROCK_PATHS.size()]
		var rock_node := _instantiate_prop(rock_path, active_mat)
		if rock_node:
			rock_node.position = Vector3(sign_x * randf_range(7.2, 8.2), randf_range(0.08, 0.15), z_pos)
			var s_val := randf_range(0.28, 0.38)
			rock_node.scale = Vector3(s_val, s_val * randf_range(1.0, 1.5), s_val)
			rock_node.rotation.y = randf_range(0.0, TAU)
			_enforce_navigable_clearance(rock_node, is_left, 6.6)

	# Custom Scenery: Active Lava Geyser Vent with looping fire/smoke VFX
	var vent_count: int = 1 if randf() < 0.50 else 0
	var vent_step := chunk_length / maxf(float(vent_count), 1.0)
	for i in range(vent_count):
		var z_pos := -half_len + (i + 0.5) * vent_step + randf_range(-1.0, 1.0)
		var vent_node := _instantiate_custom_scenery(SCENERY_MOLTEN_CROWN)
		if vent_node:
			var s_val := randf_range(1.2, 1.5)
			vent_node.scale = Vector3.ONE * s_val
			vent_node.position = Vector3(sign_x * randf_range(7.4, 8.4), 0.38 * s_val, z_pos)
			vent_node.rotation.y = randf_range(0.0, TAU)
			if ResourceLoader.exists(SCENERY_LAVA_GEYSER_VFX):
				var vfx_scene := load(SCENERY_LAVA_GEYSER_VFX) as PackedScene
				if vfx_scene:
					var vfx_inst := vfx_scene.instantiate() as Node3D
					vent_node.add_child(vfx_inst)
					vfx_inst.position = Vector3(0.0, 0.38, 0.0)
			_enforce_navigable_clearance(vent_node, is_left, 6.6)

	# Custom Scenery: Obsidian Crystal Cluster
	var crystal_count: int = 1 if randf() < 0.60 else 0
	var crystal_step := chunk_length / maxf(float(crystal_count), 1.0)
	for i in range(crystal_count):
		var z_pos := -half_len + (i + 0.7) * crystal_step + randf_range(-0.8, 0.8)
		var crystal_node := _instantiate_custom_scenery(SCENERY_OBSIDIAN_CRYSTAL)
		if crystal_node:
			var s_val := randf_range(1.0, 1.4)
			crystal_node.scale = Vector3.ONE * s_val
			crystal_node.position = Vector3(sign_x * randf_range(7.6, 8.6), 0.85 * s_val, z_pos)
			crystal_node.rotation.y = randf_range(0.0, TAU)
			_enforce_navigable_clearance(crystal_node, is_left, 6.6)

	# Custom Scenery: Volcanic Rock Spire (landmark)
	var spire_count: int = 1 if randf() < 0.85 else 0
	var spire_step := chunk_length / maxf(float(spire_count), 1.0)
	for i in range(spire_count):
		var z_pos := -half_len + (i + 0.5) * spire_step + randf_range(-1.2, 1.2)
		var spire_node := _instantiate_custom_scenery(SCENERY_VOLCANIC_SPIRE)
		if spire_node:
			var s_val := randf_range(1.4, 2.0)
			spire_node.scale = Vector3.ONE * s_val
			spire_node.position = Vector3(sign_x * randf_range(8.0, 9.4), 0.92 * s_val, z_pos)
			spire_node.rotation.y = randf_range(0.0, TAU)
			_enforce_navigable_clearance(spire_node, is_left, 6.6)

	# Tier 2: Charred Watch Structures & Iron Fortifications
	var tower_count := randi_range(1, 2)
	var tower_step := chunk_length / float(tower_count)
	for i in range(tower_count):
		var z_pos := -half_len + (i + 0.5) * tower_step + randf_range(-1.0, 1.0)
		var tower_node := _instantiate_prop("res://assets/models/tower-watch.glb", active_mat)
		if tower_node:
			tower_node.position = Vector3(sign_x * randf_range(8.5, 9.8), 0.1, z_pos)
			tower_node.scale = Vector3.ONE * 0.85
			tower_node.rotation.y = randf_range(0.0, TAU)
			_enforce_navigable_clearance(tower_node, is_left, 6.6)

	# Custom Scenery: Charred Scorched Thorn Tree (landmark)
	var tree_count: int = 1 if randf() < 0.75 else 0
	var tree_step := chunk_length / maxf(float(tree_count), 1.0)
	for i in range(tree_count):
		var z_pos := -half_len + (i + 0.5) * tree_step + randf_range(-1.2, 1.2)
		var tree_node := _instantiate_custom_scenery(SCENERY_MOLTEN_TREE)
		if tree_node:
			var s_val := randf_range(1.2, 1.6)
			tree_node.scale = Vector3.ONE * s_val
			tree_node.position = Vector3(sign_x * randf_range(8.2, 9.4), 0.90 * s_val, z_pos)
			tree_node.rotation.y = randf_range(0.0, TAU)
			_enforce_navigable_clearance(tree_node, is_left, 6.6)

	# Tier 3: Towering Volcanic Basalt Cliffs
	var cliff_count := randi_range(5, 7)
	var cliff_step := chunk_length / float(cliff_count)
	for i in range(cliff_count):
		var z_pos := -half_len + (i + 0.5) * cliff_step + randf_range(-1.5, 1.5)
		var cliff_path := BRIMSTONE_ROCK_PATHS[randi() % BRIMSTONE_ROCK_PATHS.size()]
		var cliff_node := _instantiate_prop(cliff_path, active_mat)
		if cliff_node:
			cliff_node.position = Vector3(sign_x * randf_range(11.0, 13.0), 0.1, z_pos)
			var base_scale := randf_range(1.2, 1.6)
			cliff_node.scale = Vector3(base_scale, base_scale * randf_range(1.8, 2.5), base_scale)
			cliff_node.rotation.y = randf_range(0.0, TAU)
			_enforce_navigable_clearance(cliff_node, is_left, 6.6)

	if randf() < 0.25:
		var wreck := _instantiate_prop(FLAVOR_SHIPWRECK, active_mat)
		if wreck:
			wreck.position = Vector3(sign_x * randf_range(9.2, 10.8), 0.05, randf_range(-half_len * 0.5, half_len * 0.5))
			wreck.scale = Vector3.ONE * 0.5
			wreck.rotation.y = randf_range(0.0, TAU)
			_enforce_navigable_clearance(wreck, is_left, 6.6)

# ── Navigable Corridor Geometry Clearance Enforcement ─────────────────────────

func _collect_mesh_instances(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		result.append(node as MeshInstance3D)
	for child in node.get_children():
		_collect_mesh_instances(child, result)

func _get_relative_transform(node: Node3D, root: Node3D) -> Transform3D:
	var xform := Transform3D.IDENTITY
	var curr: Node = node
	while curr and curr != root and curr is Node3D:
		xform = (curr as Node3D).transform * xform
		curr = curr.get_parent()
	return xform

## Enforces that all visual mesh geometry is strictly beyond min_channel_margin (|X| >= 6.6m).
## Completely eliminates mountain/cliff geometry clipping into the playable river lane (|X| <= 6.0m).
func _enforce_navigable_clearance(prop: Node3D, p_is_left: bool, min_channel_margin: float = 6.6) -> void:
	if not prop:
		return
	var mesh_instances: Array[MeshInstance3D] = []
	_collect_mesh_instances(prop, mesh_instances)
	if mesh_instances.is_empty():
		return

	var min_x := INF
	var max_x := -INF

	for mi in mesh_instances:
		if not mi.mesh:
			continue
		var aabb: AABB = mi.mesh.get_aabb()
		var rel_xform: Transform3D = _get_relative_transform(mi, self)
		for i in range(8):
			var corner := aabb.position + Vector3(
				aabb.size.x if (i & 1) else 0.0,
				aabb.size.y if (i & 2) else 0.0,
				aabb.size.z if (i & 4) else 0.0
			)
			var pt := rel_xform * corner
			min_x = minf(min_x, pt.x)
			max_x = maxf(max_x, pt.x)

	if min_x == INF or max_x == -INF:
		return

	if p_is_left:
		# Left bank: all geometry must be strictly <= -min_channel_margin (-6.6m)
		if max_x > -min_channel_margin:
			var overshoot := max_x - (-min_channel_margin)
			prop.position.x -= (overshoot + 0.1)
	else:
		# Right bank: all geometry must be strictly >= +min_channel_margin (+6.6m)
		if min_x < min_channel_margin:
			var undershoot := min_channel_margin - min_x
			prop.position.x += (undershoot + 0.1)


# ── Asset Instantiation & Performance Helpers ─────────────────────────────────

func _instantiate_prop(path: String, shared_mat: StandardMaterial3D = null) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var scene_res: PackedScene = null
	if _scenery_cache.has(path):
		scene_res = _scenery_cache[path]
	else:
		scene_res = load(path) as PackedScene
		if scene_res:
			_scenery_cache[path] = scene_res
	if not scene_res:
		return null
	var inst: Node3D = scene_res.instantiate() as Node3D
	if not inst:
		return null
	inst.name = path.get_file().get_basename()
	add_child(inst)
	_apply_mesh_optimizations(inst, shared_mat)
	return inst

## Instantiates custom scenery models without overriding their dedicated PBR textures.
func _instantiate_custom_scenery(path: String) -> Node3D:
	return _instantiate_prop(path, null)

## Recursively configures mesh instances for mobile performance:
## - Overrides material to shared colormap StandardMaterial3D (cull_mode = CULL_BACK)
## - Disables cast_shadow to eliminate redundant shadow map draw passes
## - Enables standard frustum culling (extra_cull_margin = 0.0)
## - Limits visibility range to fog threshold (visibility_range_end = 75.0m)
## - Selects lighter mesh LOD levels for background geometry
func _apply_mesh_optimizations(node: Node, shared_mat: StandardMaterial3D = null) -> void:
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node as MeshInstance3D
		if shared_mat:
			mi.material_override = shared_mat
	if node is GeometryInstance3D:
		var gi: GeometryInstance3D = node as GeometryInstance3D
		gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		gi.extra_cull_margin = 0.0
		gi.visibility_range_end = 75.0
		gi.visibility_range_end_margin = 10.0
		gi.lod_bias = 0.5
	for child: Node in node.get_children():
		_apply_mesh_optimizations(child, shared_mat)
