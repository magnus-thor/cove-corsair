class_name BarricadeWall
extends Node3D

@export var segment_prefab: PackedScene = preload("res://src/gameplay/obstacles/barricade_segment.tscn")
@export var x_points: Array = [-0.8, -0.4, 0.0, 0.4, 0.8]
@export var hp: int = 20
@export var hp_values: Array = []

func _ready() -> void:
	# Clear placeholders
	for child in get_children():
		child.queue_free()
		
	var river_width = 12.0
	var player = get_tree().get_first_node_in_group("player")
	if player and "river_width" in player:
		river_width = player.river_width
		
	for i in range(x_points.size()):
		var x_norm = x_points[i]
		if segment_prefab:
			var segment = segment_prefab.instantiate() as BarricadeSegment
			add_child(segment)
			var x_world = x_norm * (river_width / 2.0)
			segment.position = Vector3(x_world, 0.0, 0.0)
			
			var seg_hp = hp
			if i < hp_values.size():
				seg_hp = int(hp_values[i])
			segment.hp = seg_hp
