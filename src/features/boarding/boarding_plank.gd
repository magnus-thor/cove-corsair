class_name BoardingPlank
extends Node3D

## Physical and visual wooden boarding plank connecting the enemy vessel to a ship zone.
## Can be targeted and severed/broken by the player or crew to dump charging enemies into the sea.

signal plank_severed(plank: BoardingPlank)
signal plank_hit(plank: BoardingPlank, current_hp: float, max_hp: float)

@export var max_health: float = 30.0
@export var cross_duration_sec: float = 3.5
@export var plank_width: float = 0.41
@export var plank_thickness: float = 0.12

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

func take_damage(amount: float) -> void:
	if not is_latched:
		return
		
	current_health = maxf(current_health - amount, 0.0)
	plank_hit.emit(self, current_health, max_health)
	
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
	linear_p.y += plank_thickness * 0.5
	return linear_p

# Backward-compatibility alias
func get_point_along_rope(progress_t: float) -> Vector3:
	return get_point_along_plank(progress_t)

func _update_visual_and_collision() -> void:
	var mid_p: Vector3 = (origin_pos + target_pos) * 0.5
	global_position = mid_p
	
	var length: float = origin_pos.distance_to(target_pos)
	if not origin_pos.is_equal_approx(target_pos):
		look_at(target_pos, Vector3.UP)
	
	# Position HitArea collision at mid-point spanning distance
	if is_instance_valid(hit_area) and is_instance_valid(hit_collision):
		var box: BoxShape3D = BoxShape3D.new()
		box.size = Vector3(maxf(plank_width, 1.2), 1.8, length)
		hit_collision.shape = box
		hit_area.position = Vector3.ZERO
		hit_area.rotation = Vector3.ZERO
	
	_draw_plank_mesh()

func _draw_plank_mesh() -> void:
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
