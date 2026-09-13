class_name FireTrail3D
extends MeshInstance3D

## 3D Ribbon Trail for incendiary/fire projectiles using ImmediateMesh.
## Renders a glowing ribbon tapering from core bright yellow-orange to smoky ember red.

const COLOR_HEAD: Color = Color(1.0, 0.7, 0.2, 0.9)
const COLOR_TAIL: Color = Color(0.8, 0.2, 0.05, 0.0)

@export var max_points: int = 14
@export var trail_lifetime: float = 0.20
@export var width_head: float = 0.22
@export var width_tail: float = 0.04
@export var min_point_distance: float = 0.04

var _points: Array[Dictionary] = [] # Array of {"pos": Vector3, "age": float}
var _is_emitting: bool = true
var _is_fading: bool = false
var _fade_timer: float = 0.0
var _immediate_mesh: ImmediateMesh
var _trail_material: StandardMaterial3D
var _target_parent: Node3D = null

func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	_target_parent = get_parent() as Node3D
	
	_immediate_mesh = ImmediateMesh.new()
	mesh = _immediate_mesh
	
	_trail_material = StandardMaterial3D.new()
	_trail_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_trail_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_trail_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_trail_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_trail_material.vertex_color_use_as_albedo = true
	material_override = _trail_material

func _process(delta: float) -> void:
	if _is_emitting and is_instance_valid(_target_parent):
		var cur_pos = _target_parent.global_position
		if _points.is_empty():
			_points.push_front({"pos": cur_pos, "age": 0.0})
		elif _points[0]["pos"].distance_to(cur_pos) >= min_point_distance:
			_points.push_front({"pos": cur_pos, "age": 0.0})
		else:
			_points[0]["pos"] = cur_pos

	# Age all points
	for pt in _points:
		pt["age"] += delta

	# Cull points that exceed lifetime or max_points
	while _points.size() > max_points:
		_points.pop_back()
	while not _points.is_empty() and _points.back()["age"] > trail_lifetime:
		_points.pop_back()

	if _is_fading:
		_fade_timer += delta
		if _points.is_empty() or _fade_timer >= trail_lifetime:
			queue_free()
			return

	_render_ribbon()

func _render_ribbon() -> void:
	_immediate_mesh.clear_surfaces()
	if _points.size() < 2:
		return

	_immediate_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, _trail_material)

	var cam = get_viewport().get_camera_3d() if get_viewport() else null
	var num_pts = _points.size()

	for i in range(num_pts):
		var pt: Vector3 = _points[i]["pos"]
		var t: float = float(i) / float(max(1, num_pts - 1))

		# Direction / tangent along ribbon
		var tangent: Vector3
		if i == 0:
			tangent = (_points[0]["pos"] - _points[1]["pos"]).normalized()
		elif i == num_pts - 1:
			tangent = (_points[i - 1]["pos"] - _points[i]["pos"]).normalized()
		else:
			tangent = (_points[i - 1]["pos"] - _points[i + 1]["pos"]).normalized()

		if tangent.length_squared() < 0.0001:
			tangent = Vector3(0, 0, 1)

		# Normal perpendicular to motion and view direction
		var normal: Vector3
		if cam and is_instance_valid(cam):
			var to_cam = (cam.global_position - pt).normalized()
			normal = tangent.cross(to_cam).normalized()
		else:
			normal = tangent.cross(Vector3.UP).normalized()

		if normal.length_squared() < 0.0001:
			normal = Vector3.RIGHT

		var width: float = lerp(width_head, width_tail, t)
		var half_w: float = width * 0.5

		# Color profile: fiery gradient
		var col: Color = COLOR_HEAD.lerp(COLOR_TAIL, t)
		
		# Individual point age dissipation
		var age_fade: float = clampf(1.0 - (_points[i]["age"] / trail_lifetime), 0.0, 1.0)
		col.a *= age_fade

		# Global fade timer dissipation if detached
		if _is_fading:
			var global_fade: float = clampf(1.0 - (_fade_timer / trail_lifetime), 0.0, 1.0)
			col.a *= global_fade

		var v1 = pt + normal * half_w
		var v2 = pt - normal * half_w

		_immediate_mesh.surface_set_color(col)
		_immediate_mesh.surface_set_uv(Vector2(t, 0.0))
		_immediate_mesh.surface_add_vertex(v1)

		_immediate_mesh.surface_set_color(col)
		_immediate_mesh.surface_set_uv(Vector2(t, 1.0))
		_immediate_mesh.surface_add_vertex(v2)

	_immediate_mesh.surface_end()

## Detaches trail from dying projectile and reparents to current_scene so trail points fade smoothly
func detach_and_fade() -> void:
	if _is_fading:
		return
	_is_emitting = false
	_is_fading = true
	_fade_timer = 0.0
	_target_parent = null

	var tree = get_tree()
	if tree and is_inside_tree():
		var target_scene = tree.current_scene
		if not target_scene:
			target_scene = tree.root
		if target_scene and get_parent() != target_scene:
			reparent(target_scene)
			global_transform = Transform3D.IDENTITY
