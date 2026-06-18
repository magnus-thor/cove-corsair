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

var active_segments: Array[TrackSegment] = []

func _ready() -> void:
	# 1. Adopt any pre-placed track segments under this node in the editor
	for child in get_children():
		if child is TrackSegment:
			active_segments.append(child)
			child.off_screen.connect(_on_segment_off_screen)
	
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
		else:
			push_warning("TrackManager: No pre-placed TrackSegment children found and 'segment_scene' is not assigned!")

func _physics_process(delta: float) -> void:
	# Move each segment backward along positive Z
	for segment in active_segments:
		segment.global_position.z += scroll_speed * delta
		
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
	
	# Reset/randomize dynamic contents on this segment
	segment.recycle_segment()
