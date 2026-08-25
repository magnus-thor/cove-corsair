class_name TrackSegment
extends Node3D

## The length of this segment along the Z-axis.
@export var segment_length: float = 40.0

## The barrel prefab to instantiate dynamically
@export var barrel_prefab: PackedScene = preload("res://prefabs/destructible_barrel.tscn")

## The multiplier gate prefab to instantiate dynamically
@export var multiplier_gate_prefab: PackedScene = preload("res://prefabs/multiplier_gate.tscn")

@onready var obstacles_container: Node3D = $Obstacles

## Signal emitted when this segment moves off-screen and needs recycling.
signal off_screen(segment: TrackSegment)

var level_config_data: Dictionary = {}

func _ready() -> void:
	var notifier = get_node_or_null("VisibleOnScreenNotifier3D") as VisibleOnScreenNotifier3D
	if notifier:
		notifier.screen_exited.connect(_on_screen_exited)
	
	spawn_obstacles()
	spawn_gates()
	spawn_scenery()

func _on_screen_exited() -> void:
	# Signal to the TrackManager that this segment is ready to be recycled
	off_screen.emit(self)

## Allows TrackManager to pass down current level configuration dictionary
func apply_level_data(data: Dictionary) -> void:
	level_config_data = data
	spawn_obstacles()
	spawn_gates()
	spawn_scenery()

## Hook called by the TrackManager when this segment is recycled.
func recycle_segment_with_config(data: Dictionary) -> void:
	level_config_data = data
	recycle_segment()

## Reset and randomize segment contents
func recycle_segment() -> void:
	spawn_obstacles()
	spawn_gates()
	spawn_scenery()

## Helper to clean up existing obstacles and spawn new barrels dynamically using level config
func spawn_obstacles() -> void:
	if not obstacles_container or not barrel_prefab:
		return
		
	# Clean up any existing obstacles from previous cycles
	for child in obstacles_container.get_children():
		obstacles_container.remove_child(child)
		child.queue_free()
		
	var level_idx = int(level_config_data.get("level_index", 1))
	var rarities: Array = level_config_data.get("obstacle_rarities_allowed", ["common"])
	var is_boss: bool = bool(level_config_data.get("is_boss_level", false))
	
	# Determine barrel count based on level index and boss status
	var count = randi_range(2, 2 + int(level_idx / 3))
	if is_boss:
		count += 1
		
	var base_min_hp = 2 + int(level_idx * 0.5)
	var base_max_hp = 3 + level_idx
	
	for i in range(count):
		var barrel = barrel_prefab.instantiate() as Area3D
		if not barrel:
			continue
			
		obstacles_container.add_child(barrel)
		
		# Boss Level Special Handling for first obstacle
		if is_boss and i == 0:
			barrel.hp = 12 + level_idx * 2
			barrel.scale = Vector3(1.75, 1.75, 1.75)
			barrel.position = Vector3(0.0, 0.0, -30.0)
			continue
			
		# Regular / Rare barrel generation
		var hp_mult = 1.0
		if "rare" in rarities and randf() < 0.25:
			hp_mult = 2.0
			barrel.scale = Vector3(1.3, 1.3, 1.3)
		elif "normal" in rarities and randf() < 0.40:
			hp_mult = 1.4
			barrel.scale = Vector3(1.15, 1.15, 1.15)
			
		barrel.hp = int(randi_range(base_min_hp, base_max_hp) * hp_mult)
		
		var rand_x = randf_range(-4.0, 4.0)
		var rand_z = randf_range(-45.0, -20.0)
		barrel.position = Vector3(rand_x, 0.0, rand_z)

## Intermittently spawns Multiplier Gates based on level config gate frequency
func spawn_gates() -> void:
	var gates_container = get_node_or_null("Gates") as Node3D
	if not gates_container:
		gates_container = Node3D.new()
		gates_container.name = "Gates"
		add_child(gates_container)
		
	# Clean up any existing gates
	for child in gates_container.get_children():
		gates_container.remove_child(child)
		child.queue_free()
		
	if not multiplier_gate_prefab:
		return
		
	var gate_freq: float = float(level_config_data.get("gate_frequency", 0.4))
	if randf() <= gate_freq:
		var gate = multiplier_gate_prefab.instantiate() as Node3D
		if gate:
			gates_container.add_child(gate)
			var rand_x = randf_range(-3.2, 3.2)
			var rand_z = randf_range(-35.0, -15.0)
			gate.position = Vector3(rand_x, 0.0, rand_z)
			
			var level_idx = int(level_config_data.get("level_index", 1))
			if "operation" in gate and "value" in gate:
				if randf() < 0.65:
					gate.operation = 0 # ADD
					gate.value = randi_range(2, min(8, 2 + int(level_idx * 0.5)))
				else:
					gate.operation = 1 # MULTIPLY
					gate.value = randi_range(2, 3)

## Spawns landscape scenery pieces along the segment shores
func spawn_scenery() -> void:
	var scenery_container = get_node_or_null("Scenery")
	if not scenery_container:
		return
		
	for child in scenery_container.get_children():
		scenery_container.remove_child(child)
		child.queue_free()
		
	var sand_island_path = "res://assets/models/patch-sand.glb"
	var rock_island_path = "res://assets/models/rocks-sand-a.glb"
	var palm_straight_path = "res://assets/models/palm-detailed-straight.glb"
	var palm_bend_path = "res://assets/models/palm-detailed-bend.glb"
	
	var zones = [
		Vector2(-40.0, -32.5),
		Vector2(-32.5, -25.0),
		Vector2(-25.0, -17.5),
		Vector2(-17.5, -10.0)
	]
	
	for zone in zones:
		var shore = randi() % 3
		if shore == 0:
			continue
			
		var rand_x = 0.0
		if shore == 1:
			rand_x = randf_range(-18.0, -9.0)
		else:
			rand_x = randf_range(9.0, 18.0)
			
		var rand_z = randf_range(zone.x, zone.y)
		
		var base_path = sand_island_path if randf() < 0.5 else rock_island_path
		var base_scene = load(base_path)
		if base_scene:
			var base_inst = base_scene.instantiate() as Node3D
			scenery_container.add_child(base_inst)
			base_inst.position = Vector3(rand_x, 0.0, rand_z)
			
			if randf() < 0.6:
				var palm_path = palm_straight_path if randf() < 0.5 else palm_bend_path
				var palm_scene = load(palm_path)
				if palm_scene:
					var palm_inst = palm_scene.instantiate() as Node3D
					base_inst.add_child(palm_inst)
					palm_inst.rotation.y = randf_range(0.0, TAU)
