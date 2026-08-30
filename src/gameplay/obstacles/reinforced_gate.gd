class_name ReinforcedGate
extends Node3D

@export var segment_prefab: PackedScene = preload("res://src/gameplay/obstacles/barricade_segment.tscn")
@export var lock_hp: int = 5
@export var wall_hp: int = 99

var lock_segment: BarricadeSegment = null
var _collapsed: bool = false

func _ready() -> void:
	for child in get_children():
		child.queue_free()
		
	var river_width = 12.0
	var player = get_tree().get_first_node_in_group("player")
	if player and "river_width" in player:
		river_width = player.river_width
		
	var x_points = [-0.8, -0.4, 0.0, 0.4, 0.8]
	for x_norm in x_points:
		if segment_prefab:
			var segment = segment_prefab.instantiate() as BarricadeSegment
			add_child(segment)
			var x_world = x_norm * (river_width / 2.0)
			segment.position = Vector3(x_world, 0.0, 0.0)
			
			if abs(x_norm) < 0.05:
				segment.hp = lock_hp
				lock_segment = segment
				
				# Golden highlight material for weak-point lock
				var mesh = segment.get_node_or_null("LogMesh") as MeshInstance3D
				if mesh:
					var mat = StandardMaterial3D.new()
					mat.albedo_color = Color(1.0, 0.8, 0.0)
					mat.roughness = 0.2
					mesh.material_override = mat
			else:
				segment.hp = wall_hp
				
				# Dark ironwood material for reinforced logs
				var mesh = segment.get_node_or_null("LogMesh") as MeshInstance3D
				if mesh:
					var mat = StandardMaterial3D.new()
					mat.albedo_color = Color(0.18, 0.12, 0.08)
					mat.roughness = 0.9
					mesh.material_override = mat

func _physics_process(_delta: float) -> void:
	if _collapsed:
		return
	if lock_segment == null or not is_instance_valid(lock_segment):
		collapse_gate()

func collapse_gate() -> void:
	_collapsed = true
	var explosion_scene = preload("res://src/gameplay/vfx/barrel_explosion.tscn")
	for child in get_children():
		if is_instance_valid(child) and child != lock_segment:
			if explosion_scene:
				var vfx = explosion_scene.instantiate() as Node3D
				var parent = get_parent() if get_parent() else get_tree().current_scene
				if parent:
					parent.add_child(vfx)
					vfx.global_position = child.global_position
			child.queue_free()
	queue_free()
