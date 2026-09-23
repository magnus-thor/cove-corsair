class_name BoardingGrappleRope
extends Node3D

## Physical and visual grappling rope connecting the enemy vessel to a ship zone.
## Can be targeted and severed by the player or crew to dump climbers overboard.

signal rope_severed(rope: BoardingGrappleRope)
signal rope_hit(rope: BoardingGrappleRope, current_hp: float, max_hp: float)

@export var max_health: float = 30.0
@export var climb_duration_sec: float = 3.5
@export var sag_depth: float = 0.45

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
	add_to_group("grapple_rope")

func setup_grapple(start_point: Vector3, end_point: Vector3, zone: BoardingZone) -> void:
	origin_pos = start_point
	target_pos = end_point
	target_zone = zone
	current_health = max_health
	is_latched = true
	
	if target_zone:
		target_zone.register_grapple(self)
	
	_update_visual_and_collision()

func take_damage(amount: float) -> void:
	if not is_latched:
		return
		
	current_health = maxf(current_health - amount, 0.0)
	rope_hit.emit(self, current_health, max_health)
	
	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("sfx_wood_smash", 1.1, 1.3)
	_spawn_damage_text(int(round(amount)))
	
	if current_health <= 0.0:
		sever()

func sever() -> void:
	if not is_latched:
		return
	is_latched = false
	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("sfx_wood_smash", 0.8, 1.0)
	if is_instance_valid(target_zone):
		target_zone.unregister_grapple(self)
	rope_severed.emit(self)
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
				fct.call("setup", "-%d ROPE" % dmg, Color(1.0, 0.8, 0.2))

func get_point_along_rope(progress_t: float) -> Vector3:
	var t: float = clampf(progress_t, 0.0, 1.0)
	var linear_p: Vector3 = origin_pos.lerp(target_pos, t)
	var sag: float = sin(t * PI) * sag_depth
	linear_p.y -= sag
	return linear_p

func _update_visual_and_collision() -> void:
	var mid_p: Vector3 = get_point_along_rope(0.5)
	global_position = mid_p
	
	# Position HitArea collision at mid-point spanning distance
	if is_instance_valid(hit_area) and is_instance_valid(hit_collision):
		var length: float = origin_pos.distance_to(target_pos)
		var box: BoxShape3D = BoxShape3D.new()
		box.size = Vector3(1.2, 1.8, length)
		hit_collision.shape = box
		hit_area.global_position = mid_p
		if not origin_pos.is_equal_approx(target_pos):
			hit_area.look_at(target_pos, Vector3.UP)
	
	_draw_rope_mesh()

func _draw_rope_mesh() -> void:
	if not is_instance_valid(mesh_instance):
		return
	
	var im: ImmediateMesh = ImmediateMesh.new()
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.48, 0.34, 0.22) # Hemp rope color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	
	im.surface_begin(Mesh.PRIMITIVE_LINES, mat)
	var segments: int = 14
	var prev_pt: Vector3 = to_local(get_point_along_rope(0.0))
	for i: int in range(1, segments + 1):
		var t: float = float(i) / float(segments)
		var next_pt: Vector3 = to_local(get_point_along_rope(t))
		im.surface_add_vertex(prev_pt)
		im.surface_add_vertex(next_pt)
		prev_pt = next_pt
	im.surface_end()
	mesh_instance.mesh = im
