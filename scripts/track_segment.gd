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
	spawn_scenery()

func _on_screen_exited() -> void:
	# Signal to the TrackManager that this segment is ready to be recycled
	off_screen.emit(self)

## Hook called by the TrackManager when this segment is recycled.
## Resets and randomizes obstacles for a fresh pass.
func recycle_segment() -> void:
	spawn_obstacles()
	spawn_scenery()

## Helper to clean up existing obstacles and spawn new barrels
func spawn_obstacles() -> void:
	if not obstacles_container or not barrel_prefab:
		return
		
	# Clean up any existing obstacles from previous cycles
	for child in obstacles_container.get_children():
		obstacles_container.remove_child(child)
		child.queue_free()
		
	# Find player score for dynamic difficulty scaling
	var player = get_tree().get_first_node_in_group("player")
	var score = 0
	if player:
		score = player.score
		
	var count = 1
	var min_hp = 2
	var max_hp = 3
	var min_z = -50.0
	var max_z = -20.0
	
	if score <= 15:
		# Early Game
		count = randi_range(1, 2)
		min_hp = 2
		max_hp = 3
		min_z = -50.0
		max_z = -20.0
	elif score <= 30:
		# Mid Game
		count = randi_range(2, 3)
		min_hp = 4
		max_hp = 5
		min_z = -45.0
		max_z = -25.0
	else:
		# Late Game
		count = randi_range(3, 4)
		min_hp = 5
		max_hp = 6
		min_z = -40.0
		max_z = -28.0
		
	for i in range(count):
		var barrel = barrel_prefab.instantiate()
		obstacles_container.add_child(barrel)
		
		# Set barrel HP
		barrel.hp = randi_range(min_hp, max_hp)
		
		# Randomize position
		var rand_x = randf_range(-4.0, 4.0)
		var rand_y = 0.0
		var rand_z = randf_range(min_z, max_z)
		
		barrel.position = Vector3(rand_x, rand_y, rand_z)

## Spawns landscape scenery pieces along the segment shores
func spawn_scenery() -> void:
	var scenery_container = get_node_or_null("Scenery")
	if not scenery_container:
		return
		
	# Clean up any existing scenery from previous cycles (Scenery Recycling Clean Up)
	for child in scenery_container.get_children():
		scenery_container.remove_child(child)
		child.queue_free()
		
	# Define paths to scenery models outside the river boundaries
	var sand_island_path = "res://assets/models/patch-sand.glb"
	var rock_island_path = "res://assets/models/rocks-sand-a.glb"
	var palm_straight_path = "res://assets/models/palm-detailed-straight.glb"
	var palm_bend_path = "res://assets/models/palm-detailed-bend.glb"
	
	# Z coordinates scatter evenly across the segment length (between -10.0 and -40.0)
	var zones = [
		Vector2(-40.0, -32.5),
		Vector2(-32.5, -25.0),
		Vector2(-25.0, -17.5),
		Vector2(-17.5, -10.0)
	]
	
	for zone in zones:
		# Decide randomly to place scenery on left shoreline (-18.0 to -9.0), right shoreline (9.0 to 18.0), or skip
		var shore = randi() % 3
		if shore == 0:
			continue
			
		var rand_x = 0.0
		if shore == 1:
			rand_x = randf_range(-18.0, -9.0)
		else:
			rand_x = randf_range(9.0, 18.0)
			
		var rand_z = randf_range(zone.x, zone.y)
		
		# Instantiate base island
		var base_path = sand_island_path if randf() < 0.5 else rock_island_path
		var base_scene = load(base_path)
		if base_scene:
			var base_inst = base_scene.instantiate() as Node3D
			scenery_container.add_child(base_inst)
			base_inst.position = Vector3(rand_x, 0.0, rand_z)
			
			# Optionally nest palm tree on top of the sand coordinates
			if randf() < 0.6:
				var palm_path = palm_straight_path if randf() < 0.5 else palm_bend_path
				var palm_scene = load(palm_path)
				if palm_scene:
					var palm_inst = palm_scene.instantiate() as Node3D
					base_inst.add_child(palm_inst)
					palm_inst.rotation.y = randf_range(0.0, TAU)
