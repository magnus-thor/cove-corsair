class_name TrackSegment
extends Node3D

## The length of this segment along the Z-axis.
@export var segment_length: float = 40.0

@onready var obstacles_container: Node3D = $Obstacles

## Signal emitted when this segment moves off-screen and needs recycling.
signal off_screen(segment: TrackSegment)

func _ready() -> void:
	var notifier = get_node_or_null("VisibleOnScreenNotifier3D") as VisibleOnScreenNotifier3D
	if notifier:
		notifier.screen_exited.connect(_on_screen_exited)

func _on_screen_exited() -> void:
	# Signal to the TrackManager that this segment is ready to be recycled
	off_screen.emit(self)

## Hook called by the TrackManager when this segment is recycled.
## Resets and randomizes obstacles for a fresh pass.
func recycle_segment() -> void:
	if not obstacles_container:
		return
		
	# Simple randomized obstacle placement logic for testing
	for obstacle in obstacles_container.get_children():
		if obstacle is Node3D:
			# Randomize horizontal position along the river channel width
			obstacle.position.x = randf_range(-3.5, 3.5)
			# Randomly enable or disable the obstacle
			obstacle.visible = randf() > 0.4
