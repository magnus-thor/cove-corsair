class_name TrackSegment
extends Node3D

## The length of this segment along the Z-axis.
@export var segment_length: float = 40.0

## The barrel prefab to instantiate dynamically
@export var barrel_prefab: PackedScene = preload("res://prefabs/destructible_barrel.tscn")

@onready var obstacles_container: Node3D = $Obstacles

## Signal emitted when this segment moves off-screen and needs recycling.
signal off_screen(segment: TrackSegment)

func _ready() -> void:
	var notifier = get_node_or_null("VisibleOnScreenNotifier3D") as VisibleOnScreenNotifier3D
	if notifier:
		notifier.screen_exited.connect(_on_screen_exited)
	
	spawn_obstacles()

func _on_screen_exited() -> void:
	# Signal to the TrackManager that this segment is ready to be recycled
	off_screen.emit(self)

## Hook called by the TrackManager when this segment is recycled.
## Resets and randomizes obstacles for a fresh pass.
func recycle_segment() -> void:
	spawn_obstacles()

## Helper to clean up existing obstacles and spawn new barrels
func spawn_obstacles() -> void:
	if not obstacles_container or not barrel_prefab:
		return
		
	# Clean up any existing obstacles from previous cycles
	for child in obstacles_container.get_children():
		obstacles_container.remove_child(child)
		child.queue_free()
		
	# Spawn between 1 and 3 barrels
	var count = randi_range(1, 3)
	for i in range(count):
		var barrel = barrel_prefab.instantiate() as Node3D
		obstacles_container.add_child(barrel)
		
		# Randomize position
		var rand_x = randf_range(-4.0, 4.0)
		var rand_y = 0.0
		# Z position along the segment (further back to give the player more runway to react)
		var rand_z = randf_range(-50.0, -20.0)
		
		barrel.position = Vector3(rand_x, rand_y, rand_z)

