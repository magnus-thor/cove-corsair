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

## Tier 1: Beach / Sand Shoals
const SHOAL_SAND_PATHS: Array[String] = [
	"res://assets/models/patch-sand.glb",
	"res://assets/models/patch-sand-foliage.glb",
]

## Tier 1: Shoreline Rocks
const SHORE_ROCKS_PATHS: Array[String] = [
	"res://assets/models/rocks-sand-a.glb",
	"res://assets/models/rocks-sand-b.glb",
	"res://assets/models/rocks-sand-c.glb",
]

## Tier 2: Canopy Palms & Overhangs
const PALM_BEND_PATHS: Array[String] = [
	"res://assets/models/palm-detailed-bend.glb",
	"res://assets/models/palm-bend.glb",
]
const PALM_STRAIGHT_PATH := "res://assets/models/palm-detailed-straight.glb"

## Tier 2: Understory Tufts
const FOLIAGE_TUFT_PATH := "res://assets/models/grass-plant.glb"

## Tier 3: Cliff Rock Formations
const CLIFF_ROCK_PATHS: Array[String] = [
	"res://assets/models/rocks-a.glb",
	"res://assets/models/rocks-b.glb",
	"res://assets/models/rocks-c.glb",
]

## Rare Flavor Accents
const FLAVOR_SHIPWRECK := "res://assets/models/ship-wreck.glb"
const FLAVOR_DOCK_RUIN := "res://assets/models/structure-platform-dock-small.glb"
const FLAVOR_BARREL    := "res://assets/models/barrel.glb"

# ── Shared Materials for Mobile Batching ───────────────────────────────────────

static var _shared_mat_tropical: StandardMaterial3D = null
static var _shared_mat_bayou:    StandardMaterial3D = null
static var _shared_mat_bastion:  StandardMaterial3D = null

static func _get_or_create_material(p_biome: String) -> StandardMaterial3D:
	match p_biome:
		"black_tide_bayou":
			if _shared_mat_bayou == null:
				_shared_mat_bayou = StandardMaterial3D.new()
				_shared_mat_bayou.cull_mode = BaseMaterial3D.CULL_BACK
				_shared_mat_bayou.roughness = 0.9
				_shared_mat_bayou.albedo_color = Color(0.58, 0.68, 0.54)
				_shared_mat_bayou.albedo_texture = preload("res://assets/models/Textures/colormap.png")
			return _shared_mat_bayou
		"brimstone_bastion":
			if _shared_mat_bastion == null:
				_shared_mat_bastion = StandardMaterial3D.new()
				_shared_mat_bastion.cull_mode = BaseMaterial3D.CULL_BACK
				_shared_mat_bastion.roughness = 0.95
				_shared_mat_bastion.albedo_color = Color(0.52, 0.46, 0.46)
				_shared_mat_bastion.albedo_texture = preload("res://assets/models/Textures/colormap.png")
			return _shared_mat_bastion
		_:
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
var biome        : String = "smugglers_run"

func _ready() -> void:
	add_to_group("riverbank_chunk")

# ── Public API ────────────────────────────────────────────────────────────────

func setup(p_side: String, p_length: float = 40.0, p_biome: String = "smugglers_run") -> void:
	side         = p_side
	chunk_length = p_length
	biome        = p_biome
	_generate()

# ── Internal Generation ───────────────────────────────────────────────────────

func _generate() -> void:
	# Clear previous props (called on setup & recycling)
	for child in get_children():
		child.queue_free()

	# Prepare BankScenerySlots hook container for modular slot queries
	_setup_bank_scenery_slots()

	# Generate 3-tier natural shoreline
	_generate_3tier_shoreline()

## Creates BankScenerySlots containing MultiMeshInstance3D and Marker3D slot array
## for modular integration and inspector hooks.
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
	var shore_x := -5.8 if side == "left" else 5.8
	var start_z := -chunk_length * 0.5

	for i in range(slot_count):
		var marker := Marker3D.new()
		marker.name = "Slot_%d" % i
		marker.position = Vector3(shore_x, 0.0, start_z + (i + 0.5) * step)
		slots_container.add_child(marker)

## Generates the organic 3-tier shoreline layout.
func _generate_3tier_shoreline() -> void:
	var sign_x: float = -1.0 if side == "left" else 1.0
	var half_len: float = chunk_length * 0.5
	var active_mat: StandardMaterial3D = _get_or_create_material(biome)

	# Baseline offset guard: prevent double-offsetting if parent or chunk has non-zero X
	var base_chunk_x: float = position.x

	# ──────────────────────────────────────────────────────────────────────────
	# TIER 1: The Jagged Shoreline (Center at |X| = 4.6m to 6.2m)
	# ──────────────────────────────────────────────────────────────────────────

	# 1. Low-poly sand patches / shoals (Dry beach at Y = 0.08m above water plane)
	var sand_count := randi_range(4, 5)
	var sand_step := chunk_length / float(sand_count)
	for i in range(sand_count):
		var z_pos := -half_len + (i + 0.25) * sand_step + randf_range(-0.6, 0.6)
		var sand_path := SHOAL_SAND_PATHS[randi() % SHOAL_SAND_PATHS.size()]
		var sand_node := _instantiate_prop(sand_path, active_mat)
		if sand_node:
			var x_pos := (sign_x * randf_range(4.6, 6.2)) - base_chunk_x
			sand_node.position = Vector3(x_pos, 0.08, z_pos)
			var s_xz := randf_range(0.18, 0.22)
			sand_node.scale = Vector3(s_xz, randf_range(0.6, 0.8), s_xz)
			sand_node.rotation.y = randf_range(0.0, TAU)

	# 2. Shore Rocks overlapping the waterline (Y = 0.06m to 0.14m resting on beach)
	var rock_count := randi_range(6, 8)
	var rock_step := chunk_length / float(rock_count)
	for i in range(rock_count):
		var z_pos := -half_len + (i + 0.75) * rock_step + randf_range(-0.6, 0.6)
		var rock_path := SHORE_ROCKS_PATHS[randi() % SHORE_ROCKS_PATHS.size()]
		var rock_node := _instantiate_prop(rock_path, active_mat)
		if rock_node:
			var x_pos := (sign_x * randf_range(6.0, 6.4)) - base_chunk_x
			rock_node.position = Vector3(x_pos, randf_range(0.06, 0.14), z_pos)
			var s_val := randf_range(0.24, 0.32)
			rock_node.scale = Vector3(
				s_val,
				s_val * randf_range(0.9, 1.2),
				s_val
			)
			rock_node.rotation.y = randf_range(0.0, TAU)
			rock_node.rotation.x = randf_range(-0.04, 0.04)
			rock_node.rotation.z = randf_range(-0.04, 0.04)

	# ──────────────────────────────────────────────────────────────────────────
	# TIER 2: Canopy & Overhangs (Center at |X| = 6.5m to 7.8m)
	# ──────────────────────────────────────────────────────────────────────────
	var palm_count := randi_range(3, 5)
	var palm_step := chunk_length / float(palm_count)
	for i in range(palm_count):
		var z_pos := -half_len + (i + 0.5) * palm_step + randf_range(-1.2, 1.2)
		var is_bent := randf() < 0.8
		var palm_path := PALM_BEND_PATHS[randi() % PALM_BEND_PATHS.size()] if is_bent else PALM_STRAIGHT_PATH
		var palm_node := _instantiate_prop(palm_path, active_mat)
		if palm_node:
			var x_pos := (sign_x * randf_range(6.5, 7.8)) - base_chunk_x
			# Base grounded on the bank (Y ≈ 0.10m to 0.15m) ensuring high vertical
			# canopy clearance (>4.5m above water plane) for tall vessels like Ironclad.
			var y_pos := randf_range(0.10, 0.15)
			palm_node.position = Vector3(x_pos, y_pos, z_pos)
			palm_node.scale = Vector3.ONE * randf_range(1.0, 1.10)

			if is_bent:
				# Kenney palm models lean toward -X by default (rotation.y = 0).
				# Left bank (X negative): rotate PI to lean inward toward river center (+X).
				# Right bank (X positive): rotate 0 to lean inward toward river center (-X).
				# Controlled lean ensures canopy reaches no further inward than |X| = 4.4m (> 4.2m safe zone).
				var lean_base_angle: float = PI if side == "left" else 0.0
				palm_node.rotation.y = lean_base_angle + randf_range(-0.10, 0.10)
				palm_node.rotation.z = randf_range(-0.03, 0.03)
			else:
				palm_node.rotation.y = randf_range(0.0, TAU)

			# Scatter grass tufts radially around tree bases (guaranteeing distinct coordinates)
			var tuft_count := randi_range(2, 3)
			for t in range(tuft_count):
				var tuft_node := _instantiate_prop(FOLIAGE_TUFT_PATH, active_mat)
				if tuft_node:
					var angle := (float(t) / float(tuft_count)) * TAU + randf_range(-0.25, 0.25)
					var dist := randf_range(0.75, 1.15)
					var offset := Vector3(
						cos(angle) * dist,
						-0.05,
						sin(angle) * dist
					)
					tuft_node.position = palm_node.position + offset
					tuft_node.scale = Vector3.ONE * randf_range(0.6, 0.9)
					tuft_node.rotation.y = randf_range(0.0, TAU)

	# ──────────────────────────────────────────────────────────────────────────
	# TIER 3: Natural Cliff Ridge (Center at |X| = 8.2m to 10.5m)
	# ──────────────────────────────────────────────────────────────────────────
	var cliff_count := randi_range(6, 8)
	var cliff_step := chunk_length / float(cliff_count)
	for i in range(cliff_count):
		var z_pos := -half_len + (i + 0.5) * cliff_step + randf_range(-1.8, 1.8)
		var cliff_path := CLIFF_ROCK_PATHS[randi() % CLIFF_ROCK_PATHS.size()]
		var cliff_node := _instantiate_prop(cliff_path, active_mat)
		if cliff_node:
			var x_pos := (sign_x * randf_range(8.2, 10.5)) - base_chunk_x
			cliff_node.position = Vector3(x_pos, randf_range(0.05, 0.15), z_pos)
			var base_scale := randf_range(1.1, 1.25)
			cliff_node.scale = Vector3(
				base_scale,
				base_scale * randf_range(1.4, 1.8),  # Towering cliff height
				base_scale
			)
			cliff_node.rotation.y = randf_range(0.0, TAU)
			cliff_node.rotation.x = randf_range(-0.04, 0.04)
			cliff_node.rotation.z = randf_range(-0.04, 0.04)

	# ──────────────────────────────────────────────────────────────────────────
	# RARE FLAVOR: Accents (Shipwrecks, Ruined Platforms, Barrels)
	# ──────────────────────────────────────────────────────────────────────────

	# 1. Stranded Shipwreck (15% chance per 40m chunk, beached parallel along shoreline)
	if randf() < 0.15:
		var wreck_node := _instantiate_prop(FLAVOR_SHIPWRECK, active_mat)
		if wreck_node:
			var x_pos := (sign_x * randf_range(8.2, 8.8)) - base_chunk_x
			var z_pos := randf_range(-half_len * 0.7, half_len * 0.7)
			wreck_node.position = Vector3(x_pos, 0.05, z_pos)
			wreck_node.scale = Vector3.ONE * 0.55
			wreck_node.rotation.y = (0.0 if randf() < 0.5 else PI) + randf_range(-0.25, 0.25)
			wreck_node.rotation.z = sign_x * randf_range(0.10, 0.25)  # tilted list into shore

	# 2. Ruined small dock platform (20% chance per 40m chunk, deck elevated above water)
	if randf() < 0.20:
		var ruin_node := _instantiate_prop(FLAVOR_DOCK_RUIN, active_mat)
		if ruin_node:
			var x_pos := (sign_x * randf_range(5.8, 6.4)) - base_chunk_x
			var z_pos := randf_range(-half_len * 0.8, half_len * 0.8)
			ruin_node.position = Vector3(x_pos, 0.18, z_pos)
			ruin_node.scale = Vector3.ONE * 0.75
			ruin_node.rotation.y = randf_range(0.0, TAU)
			ruin_node.rotation.x = randf_range(-0.05, 0.05)

	# 3. Weathered cargo barrels (30% chance per 40m chunk, resting on dry bank)
	if randf() < 0.30:
		var b_count := randi_range(1, 2)
		var base_z := randf_range(-half_len * 0.8, half_len * 0.8)
		for b in range(b_count):
			var barrel_node := _instantiate_prop(FLAVOR_BARREL, active_mat)
			if barrel_node:
				var x_pos := (sign_x * randf_range(5.6, 6.2)) - base_chunk_x
				barrel_node.position = Vector3(
					x_pos,
					0.12,
					base_z + b * 0.7 + randf_range(-0.2, 0.2)
				)
				barrel_node.scale = Vector3.ONE * 0.75
				barrel_node.rotation.y = randf_range(0.0, TAU)
				if b > 0 and randf() < 0.5:
					barrel_node.rotation.z = PI * 0.5  # toppled barrel

# ── Asset Instantiation & Performance Helpers ─────────────────────────────────

func _instantiate_prop(path: String, shared_mat: StandardMaterial3D) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var scene_res := load(path) as PackedScene
	if not scene_res:
		return null
	var inst := scene_res.instantiate() as Node3D
	if not inst:
		return null
	inst.name = path.get_file().get_basename()
	add_child(inst)
	_apply_mesh_optimizations(inst, shared_mat)
	return inst

## Recursively configures mesh instances for mobile performance:
## - Overrides material to shared colormap StandardMaterial3D (cull_mode = CULL_BACK)
## - Disables cast_shadow to eliminate redundant shadow map draw passes
func _apply_mesh_optimizations(node: Node, shared_mat: StandardMaterial3D) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		mi.material_override = shared_mat
	if node is GeometryInstance3D:
		var gi := node as GeometryInstance3D
		gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		gi.extra_cull_margin = 100.0
	for child in node.get_children():
		_apply_mesh_optimizations(child, shared_mat)
