extends Node3D

# ──────────────────────────────────────────────────────────────────────────────
# HORIZON BACKDROP  –  Layer 1 of the 3-Layer Parallax Environment System
#
# A 120 × 60 unshaded quad pinned at Z = -65, Y = 15.
# Scrolls its UV Y-offset at 10 % of the track scroll speed (0.1× parallax).
# texture_repeat is enabled; fmod() keeps the offset in [0, 1) to prevent
# clamping / edge-bleeding artifacts on any texture that is assigned later.
# ──────────────────────────────────────────────────────────────────────────────

const QUAD_WIDTH    : float = 120.0
const QUAD_HEIGHT   : float = 60.0
const ANCHOR_Y      : float = 15.0
const ANCHOR_Z      : float = -65.0
const PARALLAX_RATE : float = 0.1   # fraction of scroll speed applied to UV

var _mesh_instance : MeshInstance3D
var _material      : StandardMaterial3D
var _uv_y_offset   : float = 0.0

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_build_quad()

func _process(delta: float) -> void:
	if not is_instance_valid(_material):
		return
	# Horizon remains stable in vertical perspective, with soft horizontal parallax if desired

func bind_texture(tex: Texture2D) -> void:
	if not is_instance_valid(_material):
		return
	if tex:
		_material.albedo_texture = tex
		_material.albedo_color = Color.WHITE

# ── Internal ──────────────────────────────────────────────────────────────────

func _build_quad() -> void:
	_mesh_instance = MeshInstance3D.new()
	add_child(_mesh_instance)

	# Position the backdrop – stays fixed in world space relative to its parent.
	# LevelController (or the scene root) should NOT scroll this node.
	_mesh_instance.position = Vector3(0.0, ANCHOR_Y, ANCHOR_Z)

	# Mesh ─────────────────────────────────────────────────────────────────────
	var quad := QuadMesh.new()
	quad.size = Vector2(QUAD_WIDTH, QUAD_HEIGHT)
	# QuadMesh faces -Z by default; rotate so it faces the camera (+Z direction)
	_mesh_instance.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	_mesh_instance.mesh = quad

	# Material ─────────────────────────────────────────────────────────────────
	_material = StandardMaterial3D.new()
	_material.shading_mode      = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.cull_mode         = BaseMaterial3D.CULL_DISABLED
	_material.albedo_color      = Color(0.05, 0.08, 0.12)  # dark ocean fallback
	_material.texture_repeat    = true

	# No shadows – pure backdrop
	_mesh_instance.cast_shadow  = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh_instance.material_override = _material

func _get_scroll_speed() -> float:
	var mgr := get_tree().get_first_node_in_group("track_manager") if get_tree() else null
	if mgr and "scroll_speed" in mgr:
		return float(mgr.scroll_speed)
	return 0.0
