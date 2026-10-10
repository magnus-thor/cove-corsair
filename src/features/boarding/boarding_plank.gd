@tool
class_name BoardingPlank
extends Node3D

## Physical and visual wooden boarding plank connecting the enemy vessel to a ship zone.
## Can be targeted and severed/broken by the player or crew to dump charging enemies into the sea.

signal plank_severed(plank: BoardingPlank)
signal plank_hit(plank: BoardingPlank, current_hp: float, max_hp: float)

@export var max_health: float = 30.0
@export var cross_duration_sec: float = 4.2
@export var plank_width: float = 0.41:
	set(value):
		plank_width = value
		if is_inside_tree():
			_update_visual_and_collision()

@export var plank_thickness: float = 0.12:
	set(value):
		plank_thickness = value
		if is_inside_tree():
			_update_visual_and_collision()

var current_health: float = 30.0
var origin_pos: Vector3 = Vector3.ZERO
var target_pos: Vector3 = Vector3.ZERO
var is_latched: bool = false
var target_zone: BoardingZone = null

@onready var hit_area: Area3D = $HitArea
@onready var hit_collision: CollisionShape3D = $HitArea/CollisionShape3D
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

func _ready() -> void:
	current_health = max_health
	if not Engine.is_editor_hint():
		add_to_group("boarding_plank")
		add_to_group("grapple_rope") # Compatibility group

func setup_plank(start_point: Vector3, end_point: Vector3, zone: BoardingZone) -> void:
	origin_pos = start_point
	target_pos = end_point
	target_zone = zone
	current_health = max_health
	is_latched = true
	
	if target_zone:
		if target_zone.has_method("register_plank"):
			target_zone.call("register_plank", self)
		elif target_zone.has_method("register_grapple"):
			target_zone.call("register_grapple", self)
	
	_update_visual_and_collision()

# Backward-compatibility alias
func setup_grapple(start_point: Vector3, end_point: Vector3, zone: BoardingZone) -> void:
	setup_plank(start_point, end_point, zone)

func _get_audio_manager() -> Node:
	if Engine.is_editor_hint():
		return null
	if is_inside_tree() and get_tree() and get_tree().root:
		return get_tree().root.get_node_or_null("AudioManager")
	return null

func take_damage(amount: float) -> void:
	if not is_latched:
		return
		
	current_health = maxf(current_health - amount, 0.0)
	plank_hit.emit(self, current_health, max_health)
	
	var audio: Node = _get_audio_manager()
	if audio and audio.has_method("play_sfx"):
		audio.call("play_sfx", "sfx_wood_smash", 1.1, 1.3)
	_spawn_damage_text(int(round(amount)))
	
	if current_health <= 0.0:
		sever()

func sever() -> void:
	if not is_latched:
		return
	is_latched = false
	var audio: Node = _get_audio_manager()
	if audio and audio.has_method("play_sfx"):
		audio.call("play_sfx", "sfx_wood_smash", 0.8, 1.0)
	if is_instance_valid(target_zone):
		if target_zone.has_method("unregister_plank"):
			target_zone.call("unregister_plank", self)
		elif target_zone.has_method("unregister_grapple"):
			target_zone.call("unregister_grapple", self)
	plank_severed.emit(self)
	queue_free()

func _spawn_damage_text(dmg: int) -> void:
	var ft_script: GDScript = load("res://src/vfx/floating_text.gd") as GDScript
	if ft_script:
		var fct: Node3D = ft_script.new() as Node3D
		var root: Node = get_tree().current_scene
		if root and fct:
			root.add_child(fct)
			fct.global_position = global_position + Vector3(randf_range(-0.2, 0.2), 0.8, randf_range(-0.2, 0.2))
			if fct.has_method("setup"):
				fct.call("setup", "-%d" % dmg, Color(1.0, 0.8, 0.2))

func get_point_along_plank(progress_t: float) -> Vector3:
	var t: float = clampf(progress_t, 0.0, 1.0)
	var linear_p: Vector3 = origin_pos.lerp(target_pos, t)
	if is_inside_tree() and global_transform.basis.y.length_squared() > 0.01:
		linear_p += global_transform.basis.y * (plank_thickness * 0.5)
	else:
		linear_p.y += plank_thickness * 0.5
	return linear_p

# Backward-compatibility alias
func get_point_along_rope(progress_t: float) -> Vector3:
	return get_point_along_plank(progress_t)

var is_selected: bool = false
var border_container: Node3D = null

func set_selected(selected: bool) -> void:
	is_selected = selected
	if is_instance_valid(border_container):
		border_container.visible = is_selected

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if is_selected and is_instance_valid(border_container):
		var pulse: float = 1.0 + sin(float(Time.get_ticks_msec()) * 0.008) * 0.12
		border_container.scale = Vector3(1.0 + pulse * 0.05, 1.0, 1.0 + pulse * 0.02)

func _update_visual_and_collision() -> void:
	var mid_p: Vector3 = (origin_pos + target_pos) * 0.5
	global_position = mid_p
	
	var length: float = origin_pos.distance_to(target_pos)
	if not origin_pos.is_equal_approx(target_pos):
		look_at(target_pos, Vector3.UP)
	
	if not is_instance_valid(hit_area):
		hit_area = find_child("HitArea", true, false) as Area3D
	if not is_instance_valid(hit_collision) and is_instance_valid(hit_area):
		hit_collision = hit_area.find_child("CollisionShape3D", true, false) as CollisionShape3D

	# Position HitArea collision at mid-point spanning distance.
	# Keep width and height proportional to plank dimensions so adjacent planks
	# do not overlap and occlude each other's click volumes.
	if is_instance_valid(hit_area) and is_instance_valid(hit_collision):
		var box: BoxShape3D = BoxShape3D.new()
		var col_width: float = clampf(plank_width * 1.5, 0.32, 0.55)
		var col_height: float = clampf(plank_thickness * 3.5, 0.35, 0.65)
		box.size = Vector3(col_width, col_height, length)
		hit_collision.shape = box
		hit_area.position = Vector3.ZERO
		hit_area.rotation = Vector3.ZERO
	
	_draw_plank_mesh()
	_create_or_update_selection_border(length)

func _draw_plank_mesh() -> void:
	if not is_instance_valid(mesh_instance):
		mesh_instance = find_child("MeshInstance3D", true, false) as MeshInstance3D
		if not is_instance_valid(mesh_instance):
			return
	
	var length: float = origin_pos.distance_to(target_pos)
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(plank_width, plank_thickness, length)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.48, 0.32, 0.18, 1.0) # Weathered oak plank
	mat.roughness = 0.85
	box.material = mat
	mesh_instance.mesh = box
	mesh_instance.position = Vector3.ZERO
	mesh_instance.rotation = Vector3.ZERO

func _create_or_update_selection_border(length: float) -> void:
	if not is_instance_valid(border_container):
		border_container = Node3D.new()
		border_container.name = "SelectionBorder"
		add_child(border_container)
	
	for child: Node in border_container.get_children():
		child.queue_free()
		
	var border_mat: StandardMaterial3D = StandardMaterial3D.new()
	border_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	border_mat.albedo_color = Color(1.0, 0.15, 0.15, 1.0) # Vibrant red border
	
	var border_w: float = 0.05
	var border_h: float = 0.035
	var top_y: float = plank_thickness * 0.5 + (border_h * 0.5)
	var half_w: float = plank_width * 0.5
	var half_l: float = length * 0.5
	
	# Left strip (along length)
	var left_mesh: MeshInstance3D = MeshInstance3D.new()
	var left_box: BoxMesh = BoxMesh.new()
	left_box.size = Vector3(border_w, border_h, length + border_w * 2.0)
	left_box.material = border_mat
	left_mesh.mesh = left_box
	left_mesh.position = Vector3(-half_w - (border_w * 0.5), top_y, 0.0)
	border_container.add_child(left_mesh)
	
	# Right strip (along length)
	var right_mesh: MeshInstance3D = MeshInstance3D.new()
	var right_box: BoxMesh = BoxMesh.new()
	right_box.size = Vector3(border_w, border_h, length + border_w * 2.0)
	right_box.material = border_mat
	right_mesh.mesh = right_box
	right_mesh.position = Vector3(half_w + (border_w * 0.5), top_y, 0.0)
	border_container.add_child(right_mesh)
	
	# Start strip (crosswise at origin)
	var start_mesh: MeshInstance3D = MeshInstance3D.new()
	var start_box: BoxMesh = BoxMesh.new()
	start_box.size = Vector3(plank_width + border_w * 2.0, border_h, border_w)
	start_box.material = border_mat
	start_mesh.mesh = start_box
	start_mesh.position = Vector3(0.0, top_y, -half_l - (border_w * 0.5))
	border_container.add_child(start_mesh)
	
	# End strip (crosswise at ship railing)
	var end_mesh: MeshInstance3D = MeshInstance3D.new()
	var end_box: BoxMesh = BoxMesh.new()
	end_box.size = Vector3(plank_width + border_w * 2.0, border_h, border_w)
	end_box.material = border_mat
	end_mesh.mesh = end_box
	end_mesh.position = Vector3(0.0, top_y, half_l + (border_w * 0.5))
	border_container.add_child(end_mesh)
	
	border_container.visible = is_selected
