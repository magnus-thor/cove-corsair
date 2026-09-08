class_name BarricadeWall
extends Node3D

@export var segment_prefab: PackedScene = preload("res://src/gameplay/obstacles/barricade_segment.tscn")
@export var x_points: Array = [-0.8, -0.4, 0.0, 0.4, 0.8]
@export var hp: int = 20
@export var hp_values: Array = []
var level_override: int = -1

static func get_tier_hp(level: int) -> int:
	if level <= 3:
		return 2
	elif level <= 10:
		return 6
	elif level <= 25:
		return 12
	else:
		return 20

func _get_effective_level() -> int:
	if level_override > 0:
		return level_override
	if has_node("/root/GameState"):
		var gs = get_node("/root/GameState")
		if "current_level" in gs:
			return int(gs.current_level)
	return 1

func _ready() -> void:
	# Clear placeholders
	for child in get_children():
		child.queue_free()
		
	var river_width = 12.0
	var player = get_tree().get_first_node_in_group("player")
	if player and "river_width" in player:
		river_width = player.river_width
		
	var cur_level = _get_effective_level()
	var tier_hp = get_tier_hp(cur_level)
	
	# Scale barricade slat HP dynamically based on Campaign Tier:
	# Levels 1 to 3: Slat HP = 2 (starter Dinghy destroys a slat in 2 direct cannon shots).
	# Levels 4 to 10: Slat HP = 6 (requires 5-6 shots or upgraded vessel fire).
	# Levels 11 to 25: Slat HP = 12.
	# Levels 26+: Slat HP = 20 (late-game fortified siege walls).
	var default_slat_hp = tier_hp
	if cur_level > 10 and hp > 0 and hp != 20:
		default_slat_hp = hp
	elif cur_level >= 26:
		default_slat_hp = 20
		
	for i in range(x_points.size()):
		var x_norm = x_points[i]
		if segment_prefab:
			var segment = segment_prefab.instantiate() as BarricadeSegment
			var seg_hp = default_slat_hp
			if cur_level > 10 and i < hp_values.size() and int(hp_values[i]) > 0:
				seg_hp = int(hp_values[i])
			segment.hp = seg_hp
			add_child(segment)
			var x_world = x_norm * (river_width / 2.0)
			segment.position = Vector3(x_world, 0.0, 0.0)

