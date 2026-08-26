class_name TrackManager
extends Node3D

## The segment scene to spawn if no segments are pre-placed in the scene tree.
@export var segment_scene: PackedScene

## Number of segments to maintain in the pool if dynamically generating.
@export var pool_size: int = 5

## Speed at which the track scrolls backward on the Z axis (units per second).
@export var scroll_speed: float = 16.0

## Length of a single track segment.
@export var segment_length: float = 40.0

## The Z coordinate behind the player/camera after which a segment is recycled.
@export var cleanup_z: float = 40.0

## Active level index to load from data/level_config.json
@export var current_level_index: int = 1

var active_segments: Array[TrackSegment] = []
var current_level_data: Dictionary = {}

func _ready() -> void:
	load_level_config(current_level_index)
	
	# 1. Adopt any pre-placed track segments under this node in the editor
	for child in get_children():
		if child is TrackSegment:
			active_segments.append(child)
			child.off_screen.connect(_on_segment_off_screen)
			child.apply_level_data(current_level_data)
	
	# 2. If none were pre-placed, instantiate the pool dynamically
	if active_segments.is_empty():
		if segment_scene:
			for i in range(pool_size):
				var segment = segment_scene.instantiate() as TrackSegment
				add_child(segment)
				# Place segments sequentially in front of the camera (negative Z)
				segment.global_position = Vector3(0, 0, -i * segment_length)
				active_segments.append(segment)
				segment.off_screen.connect(_on_segment_off_screen)
				segment.apply_level_data(current_level_data)
		else:
			push_warning("TrackManager: No pre-placed TrackSegment children found and 'segment_scene' is not assigned!")
			
	# Update player's win target score if available
	var player = get_tree().get_first_node_in_group("player")
	if player and "target_score" in player and current_level_data.has("target_score"):
		player.target_score = int(current_level_data["target_score"])

func load_level_config(level_num: int) -> void:
	var path = "res://data/level_config.json"
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		var json_text = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(json_text)
		if parse_result == OK:
			var data = json.get_data()
			if data is Array:
				for lvl in data:
					if int(lvl.get("level_index", 0)) == level_num:
						current_level_data = lvl
						break
				if current_level_data.is_empty() and data.size() > 0:
					current_level_data = data[0]
					
	if not current_level_data.is_empty():
		if current_level_data.has("track_speed"):
			scroll_speed = float(current_level_data["track_speed"])

func _physics_process(delta: float) -> void:
	# Read player score to dynamically increase track scroll speed slightly
	var player = get_tree().get_first_node_in_group("player")
	var speed = scroll_speed
	if player:
		# Add a speed bonus of 0.1 per barrel destroyed, up to +5.0 speed
		speed += min(player.score * 0.1, 5.0)

	GameState.update_distance(speed * delta)

	# Move each segment backward along positive Z
	for segment in active_segments:
		segment.global_position.z += speed * delta
		
		# Fallback: if a segment passes the cleanup threshold, recycle it
		if segment.global_position.z > cleanup_z:
			_recycle_segment(segment)

func _on_segment_off_screen(segment: TrackSegment) -> void:
	_recycle_segment(segment)

func _recycle_segment(segment: TrackSegment) -> void:
	# To avoid double recycling in the same frame
	if segment.global_position.z < 0:
		return
		
	# Find the furthest segment ahead (most negative Z)
	var furthest_z: float = 0.0
	for active in active_segments:
		if active.global_position.z < furthest_z:
			furthest_z = active.global_position.z
			
	# Reposition the recycled segment directly in front of the furthest one
	segment.global_position.z = furthest_z - segment_length
	
	# Reset/randomize dynamic contents on this segment using active level config
	segment.recycle_segment_with_config(current_level_data)
