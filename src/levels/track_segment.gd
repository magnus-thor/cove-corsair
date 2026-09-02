class_name TrackSegment
extends Node3D

## The length of this segment along the Z-axis.
@export var segment_length: float = 40.0

## The barrel prefab to instantiate dynamically
@export var barrel_prefab: PackedScene = preload("res://src/gameplay/obstacles/destructible_barrel.tscn")

## The multiplier gate prefab to instantiate dynamically
@export var multiplier_gate_prefab: PackedScene = preload("res://src/gameplay/obstacles/multiplier_gate.tscn")

## The enemy mob scenes / prefabs to instantiate dynamically
@export var enemy_mob_scenes: Array[PackedScene] = [preload("res://src/gameplay/enemies/enemy_mob.tscn")]
@export var enemy_mob_prefab: PackedScene = preload("res://src/gameplay/enemies/enemy_mob.tscn")

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
		
	# Clean up any existing obstacles and enemies from previous cycles
	for child in obstacles_container.get_children():
		obstacles_container.remove_child(child)
		child.queue_free()
		
	if GameState.current_level == 1 or level_config_data.get("is_scripted", false):
		return
		
	var player = get_tree().get_first_node_in_group("player")
	if player and "is_calibration_mode" in player and player.is_calibration_mode:
		return
		
	var level_idx = int(level_config_data.get("level_index", 1))
	var rarities: Array = level_config_data.get("obstacle_rarities_allowed", ["common"])
	var is_boss: bool = bool(level_config_data.get("is_boss_level", false))
	
	# Determine barrel count based on level index and boss status
	var count = randi_range(2, 2 + int(level_idx / 3.0))
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
			if "obstacle_type" in barrel:
				barrel.obstacle_type = DestructibleObstacle.ObstacleType.CORAL_REEF
			continue
			
		# Regular / Rare barrel generation
		var hp_mult = 1.0
		if "rare" in rarities and randf() < 0.25:
			hp_mult = 2.0
		elif "normal" in rarities and randf() < 0.40:
			hp_mult = 1.5
			
		barrel.hp = int(randi_range(base_min_hp, base_max_hp) * hp_mult)
		
		# Pick obstacle visual variant based on HP and rarity
		if "obstacle_type" in barrel:
			if barrel.hp >= 8:
				barrel.obstacle_type = DestructibleObstacle.ObstacleType.CORAL_REEF
			elif barrel.hp >= 6:
				barrel.obstacle_type = DestructibleObstacle.ObstacleType.RUNE_BARREL
			elif barrel.hp >= 4:
				barrel.obstacle_type = DestructibleObstacle.ObstacleType.FUSE_BARREL
			elif randf() < 0.2:
				barrel.obstacle_type = DestructibleObstacle.ObstacleType.SEA_MINE
			else:
				barrel.obstacle_type = DestructibleObstacle.ObstacleType.WOODEN_BARREL
				
		var lane_x = randf_range(-4.5, 4.5)
		var rand_z = -randf_range(5.0, segment_length - 5.0)
		barrel.position = Vector3(lane_x, 0.0, rand_z)

	# Dynamic enemy mob spawning based on level difficulty
	var enemy_mob_count = 0
	if level_idx >= 2:
		enemy_mob_count = randi_range(1, 2)
	if level_idx >= 5:
		enemy_mob_count = randi_range(2, 3)
		
	var enemy_types = ["skeleton_rower"]
	if level_idx >= 3:
		enemy_types.append("goblin_skiff")
	if level_idx >= 5:
		enemy_types.append("turtle_raft")

	var enemy_res_map = {
		"skeleton_rower": "res://src/data/resources/enemy_vessels/skeleton_rower.tres",
		"raider_skiff": "res://src/data/resources/enemy_vessels/raider_skiff.tres",
		"goblin_skiff": "res://src/data/resources/enemy_vessels/raider_skiff.tres",
		"turtle_raft": "res://src/data/resources/enemy_vessels/turtle_raft.tres"
	}
		
	for e in range(enemy_mob_count):
		if enemy_mob_prefab:
			var enemy = enemy_mob_prefab.instantiate() as Area3D
			if enemy:
				obstacles_container.add_child(enemy)
				var chosen_type = enemy_types.pick_random()
				if enemy_res_map.has(chosen_type):
					var res = load(enemy_res_map[chosen_type]) as EnemyData
					if res and enemy.has_method("apply_enemy_data"):
						enemy.apply_enemy_data(res)
				elif "mob_type" in enemy:
					enemy.mob_type = chosen_type
				
				var lane_x = randf_range(-4.0, 4.0)
				var rand_z = -randf_range(8.0, segment_length - 8.0)
				enemy.position = Vector3(lane_x, 0.0, rand_z)

## Spawns Multiplier Gates on this segment according to level config frequency
func spawn_gates() -> void:
	var gates_container = get_node_or_null("Gates")
	if not gates_container:
		gates_container = Node3D.new()
		gates_container.name = "Gates"
		add_child(gates_container)
		
	for child in gates_container.get_children():
		gates_container.remove_child(child)
		child.queue_free()

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
			rand_x = randf_range(-18.0, -9.5)
		else:
			rand_x = randf_range(9.5, 18.0)
			
		var rand_z = randf_range(zone.x, zone.y)
		
		var base_path = sand_island_path if randf() < 0.5 else rock_island_path
		var base_scene = load(base_path)
		if base_scene:
			var base_inst = base_scene.instantiate() as Node3D
			scenery_container.add_child(base_inst)
			base_inst.position = Vector3(rand_x, 0.0, rand_z)
			_clean_shadow_nodes(base_inst)
			
			if randf() < 0.6:
				var palm_path = palm_straight_path if randf() < 0.5 else palm_bend_path
				var palm_scene = load(palm_path)
				if palm_scene:
					var palm_inst = palm_scene.instantiate() as Node3D
					base_inst.add_child(palm_inst)
					palm_inst.rotation.y = randf_range(0.0, TAU)
					_clean_shadow_nodes(palm_inst)

func _clean_shadow_nodes(node: Node) -> void:
	if not node:
		return
		
	if node is MeshInstance3D or node is Sprite3D or node is GeometryInstance3D:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		
	var lower_name = node.name.to_lower()
	var is_shadow_node = false
	if "shadow" in lower_name or "decal" in lower_name or "projector" in lower_name or "card" in lower_name or "oblate" in lower_name or "shadow_sphere" in lower_name or "sphere_shadow" in lower_name or "quad" in lower_name or "dark" in lower_name:
		is_shadow_node = true
		
	if is_shadow_node:
		node.queue_free()
		return
			
	for child in node.get_children():
		_clean_shadow_nodes(child)
