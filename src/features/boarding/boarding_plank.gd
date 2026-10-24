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

## Lowers and slams the boarding plank down from the enemy vessel onto the player ship deck
func drop_plank(start_point: Vector3, end_point: Vector3, zone: BoardingZone) -> void:
	origin_pos = start_point
	target_pos = end_point
	target_zone = zone
	current_health = max_health
	is_latched = false

	# Calculate upright initial position tilted against the enemy gunwale
	var length: float = start_point.distance_to(end_point)
	var flat_dir: Vector3 = (Vector3(end_point.x, start_point.y, end_point.z) - start_point).normalized()
	var raised_tip: Vector3 = start_point + (flat_dir * length * 0.28) + Vector3(0.0, length * 0.90, 0.0)

	_apply_endpoints(start_point, raised_tip)

	var drop_tween: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	drop_tween.tween_method(func(t: float) -> void:
		var cur_tip: Vector3 = raised_tip.lerp(end_point, t)
		_apply_endpoints(start_point, cur_tip)
	, 0.0, 1.0, 0.38)

	drop_tween.tween_callback(func() -> void:
		_apply_endpoints(start_point, end_point)
		is_latched = true
		if target_zone:
			if target_zone.has_method("register_plank"):
				target_zone.call("register_plank", self)
			elif target_zone.has_method("register_grapple"):
				target_zone.call("register_grapple", self)
		var audio: Node = _get_audio_manager()
		if audio and audio.has_method("play_sfx"):
			audio.call("play_sfx", "sfx_wood_smash", 0.9, 1.1)
	)

func _apply_endpoints(p_start: Vector3, p_end: Vector3) -> void:
	origin_pos = p_start
	target_pos = p_end
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
var _gold_trim_mat: StandardMaterial3D = null

func set_selected(selected: bool) -> void:
	is_selected = selected
	if is_instance_valid(border_container):
		border_container.visible = is_selected

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if is_selected and is_instance_valid(_gold_trim_mat):
		var time_sec: float = float(Time.get_ticks_msec()) * 0.001
		var pulse: float = sin(time_sec * 3.5)
		_gold_trim_mat.emission_energy_multiplier = 0.70 + pulse * 0.20
		_gold_trim_mat.albedo_color.a = 0.40 + pulse * 0.10

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
		
	_gold_trim_mat = StandardMaterial3D.new()
	_gold_trim_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_gold_trim_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Luminous transparent gold hue
	_gold_trim_mat.albedo_color = Color(1.0, 0.80, 0.15, 0.40)
	_gold_trim_mat.metallic = 0.55
	_gold_trim_mat.metallic_specular = 0.95
	_gold_trim_mat.roughness = 0.08
	_gold_trim_mat.clearcoat_enabled = true
	_gold_trim_mat.clearcoat = 1.0
	_gold_trim_mat.clearcoat_roughness = 0.08
	_gold_trim_mat.emission_enabled = true
	_gold_trim_mat.emission = Color(1.0, 0.75, 0.12, 1.0)
	_gold_trim_mat.emission_energy_multiplier = 0.70

	var half_w: float = plank_width * 0.5
	var half_l: float = length * 0.5
	var side_thickness: float = 0.016
	var top_y: float = (plank_thickness * 0.5) + 0.002

	# Left side flank: hugs the vertical outer left face of the plank
	var left_side_mesh: MeshInstance3D = MeshInstance3D.new()
	var left_side_box: BoxMesh = BoxMesh.new()
	left_side_box.size = Vector3(side_thickness, plank_thickness + 0.010, length)
	left_side_box.material = _gold_trim_mat
	left_side_mesh.mesh = left_side_box
	left_side_mesh.position = Vector3(-half_w, 0.003, 0.0)
	border_container.add_child(left_side_mesh)

	# Right side flank: hugs the vertical outer right face of the plank
	var right_side_mesh: MeshInstance3D = MeshInstance3D.new()
	var right_side_box: BoxMesh = BoxMesh.new()
	right_side_box.size = Vector3(side_thickness, plank_thickness + 0.010, length)
	right_side_box.material = _gold_trim_mat
	right_side_mesh.mesh = right_side_box
	right_side_mesh.position = Vector3(half_w, 0.003, 0.0)
	border_container.add_child(right_side_mesh)

	# Left top deck rim ribbon: a sleek, transparent gold rim hugging the top-left edge
	var left_top_mesh: MeshInstance3D = MeshInstance3D.new()
	var left_top_box: BoxMesh = BoxMesh.new()
	left_top_box.size = Vector3(0.024, 0.003, length)
	left_top_box.material = _gold_trim_mat
	left_top_mesh.mesh = left_top_box
	left_top_mesh.position = Vector3(-half_w + 0.010, top_y, 0.0)
	border_container.add_child(left_top_mesh)

	# Right top deck rim ribbon: a sleek, transparent gold rim hugging the top-right edge
	var right_top_mesh: MeshInstance3D = MeshInstance3D.new()
	var right_top_box: BoxMesh = BoxMesh.new()
	right_top_box.size = Vector3(0.024, 0.003, length)
	right_top_box.material = _gold_trim_mat
	right_top_mesh.mesh = right_top_box
	right_top_mesh.position = Vector3(half_w - 0.010, top_y, 0.0)
	border_container.add_child(right_top_mesh)

	# Start threshold inlay (flush with wood, not a raised block)
	var start_mesh: MeshInstance3D = MeshInstance3D.new()
	var start_box: BoxMesh = BoxMesh.new()
	start_box.size = Vector3(plank_width, 0.003, 0.018)
	start_box.material = _gold_trim_mat
	start_mesh.mesh = start_box
	start_mesh.position = Vector3(0.0, top_y, -half_l + 0.009)
	border_container.add_child(start_mesh)

	# End threshold inlay (flush with wood, not a raised block)
	var end_mesh: MeshInstance3D = MeshInstance3D.new()
	var end_box: BoxMesh = BoxMesh.new()
	end_box.size = Vector3(plank_width, 0.003, 0.018)
	end_box.material = _gold_trim_mat
	end_mesh.mesh = end_box
	end_mesh.position = Vector3(0.0, top_y, half_l - 0.009)
	border_container.add_child(end_mesh)

	border_container.visible = is_selected
