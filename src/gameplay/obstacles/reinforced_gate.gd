class_name ReinforcedGate
extends Node3D

@export var segment_prefab: PackedScene = preload("res://src/gameplay/obstacles/barricade_segment.tscn")
@export var lock_hp: int = 50
@export var wall_hp: int = 99

var lock_segment: BarricadeSegment = null
var _collapsed: bool = false

static var _lock_mat: StandardMaterial3D = null
static var _ironwood_mat: StandardMaterial3D = null

static func _get_lock_material() -> StandardMaterial3D:
	if not _lock_mat:
		_lock_mat = StandardMaterial3D.new()
		_lock_mat.albedo_color = Color(1.0, 0.8, 0.0)
		_lock_mat.roughness = 0.2
	return _lock_mat

static func _get_ironwood_material() -> StandardMaterial3D:
	if not _ironwood_mat:
		_ironwood_mat = StandardMaterial3D.new()
		_ironwood_mat.albedo_color = Color(0.18, 0.12, 0.08)
		_ironwood_mat.roughness = 0.9
	return _ironwood_mat

func _exit_tree() -> void:
	for child: Node in get_children():
		if is_instance_valid(child):
			var mesh: MeshInstance3D = child.get_node_or_null("LogMesh") as MeshInstance3D
			if mesh and is_instance_valid(mesh):
				mesh.material_override = null

func _ready() -> void:
	for child: Node in get_children():
		child.queue_free()
		
	var river_width: float = 12.0
	var player: Node = get_tree().get_first_node_in_group("player")
	if player and "river_width" in player:
		river_width = float(player.get("river_width"))
		
	var x_points: Array[float] = [-0.8, -0.4, 0.0, 0.4, 0.8]
	for x_norm: float in x_points:
		if segment_prefab:
			var segment: BarricadeSegment = segment_prefab.instantiate() as BarricadeSegment
			add_child(segment)
			var x_world: float = x_norm * (river_width / 2.0)
			segment.position = Vector3(x_world, 0.0, 0.0)
			
			if absf(x_norm) < 0.05:
				segment.hp = lock_hp
				lock_segment = segment
				
				# Golden highlight material for weak-point lock
				var mesh: MeshInstance3D = segment.get_node_or_null("LogMesh") as MeshInstance3D
				if mesh:
					mesh.material_override = _get_lock_material()
			else:
				segment.hp = wall_hp
				
				# Dark ironwood material for reinforced logs
				var mesh: MeshInstance3D = segment.get_node_or_null("LogMesh") as MeshInstance3D
				if mesh:
					mesh.material_override = _get_ironwood_material()

func _physics_process(_delta: float) -> void:
	if _collapsed:
		return
	if lock_segment == null or not is_instance_valid(lock_segment):
		collapse_gate()

func collapse_gate() -> void:
	_collapsed = true
	var explosion_scene: PackedScene = preload("res://src/vfx/barrel_explosion.tscn")
	for child: Node in get_children():
		if is_instance_valid(child) and child != lock_segment:
			if explosion_scene:
				var vfx: Node3D = explosion_scene.instantiate() as Node3D
				var parent: Node = get_parent() if get_parent() else get_tree().current_scene
				if parent:
					parent.add_child(vfx)
					vfx.global_position = (child as Node3D).global_position
			var mesh: MeshInstance3D = child.get_node_or_null("LogMesh") as MeshInstance3D
			if mesh and is_instance_valid(mesh):
				mesh.material_override = null
			child.queue_free()
	queue_free()
