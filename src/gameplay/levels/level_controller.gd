class_name LevelController
extends Node3D

@export var level_data: LevelData = preload("res://src/data/resources/level_01_smugglers_run.tres")
@export var spawn_z_ahead: float = -70.0

# Prefabs
@export var coin_scene: PackedScene = preload("res://src/gameplay/collectibles/collectible_doubloon.tscn")
@export var barrel_scene: PackedScene = preload("res://src/gameplay/obstacles/destructible_barrel.tscn")
@export var barricade_scene: PackedScene = preload("res://src/gameplay/obstacles/barricade_wall.tscn")
@export var sea_mine_scene: PackedScene = preload("res://src/gameplay/obstacles/hazard_sea_mine.tscn")
@export var reinforced_gate_scene: PackedScene = preload("res://src/gameplay/obstacles/reinforced_gate.tscn")
@export var boss_scene: PackedScene = preload("res://src/gameplay/enemies/boss_war_barge.tscn")
@export var enemy_mob_scene: PackedScene = preload("res://src/gameplay/enemies/enemy_mob.tscn")

var current_distance: float = 0.0
var active_queue: Array[Dictionary] = []
var river_width_world: float = 12.0
var base_scroll_speed: float = 12.0

func _ready() -> void:
	add_to_group("level_controller")
	
	if level_data:
		river_width_world = level_data.river_width_world
		base_scroll_speed = level_data.base_scroll_speed
		
		# Set up GameState
		GameState.level_distance_target = level_data.total_distance
		GameState.distance_traveled = 0.0
		GameState.is_game_active = true
		GameState.current_level = 1
		
		# Copy and sort wave events by distance
		active_queue = level_data.wave_events.duplicate()
		active_queue.sort_custom(func(a, b): return a.distance < b.distance)
		
		# Configure TrackManager speed and flag
		var track_mgr = get_tree().get_first_node_in_group("track_manager")
		if track_mgr:
			track_mgr.scroll_speed = base_scroll_speed
			if "current_level_data" in track_mgr:
				track_mgr.current_level_data["is_scripted"] = true
				
		# Update level title on HUD
		var hud = get_tree().get_first_node_in_group("top_hud")
		if hud and "level_title" in hud:
			hud.level_title.text = level_data.level_name

func _physics_process(delta: float) -> void:
	if not GameState.is_game_active:
		return
		
	var speed = base_scroll_speed
	var track_mgr = get_tree().get_first_node_in_group("track_manager")
	if track_mgr and "scroll_speed" in track_mgr:
		speed = track_mgr.scroll_speed
		
	# Don't increment distance if boss has spawned
	if not GameState.boss_spawned:
		current_distance += speed * delta
		GameState.update_distance(speed * delta)
		
	# Check wave events queue
	while not active_queue.is_empty() and current_distance >= active_queue[0].distance:
		var event = active_queue.pop_front()
		_spawn_wave_event(event)
		
	# Scroll direct children that are obstacles/enemies
	var scroll_movement = speed * delta
	for child in get_children():
		if child is Node3D and not child.is_in_group("boss") and not child.is_in_group("collectibles") and not child.is_in_group("doubloons"):
			child.global_position.z += scroll_movement

func normalized_to_world_x(norm_x: float) -> float:
	return norm_x * (river_width_world / 2.0)

func _spawn_wave_event(event: Dictionary) -> void:
	var event_type = event.type
	
	match event_type:
		"coin_arc":
			var x_start = float(event.get("x_start", -0.3))
			var x_end = float(event.get("x_end", 0.3))
			var count = int(event.get("count", 5))
			
			for i in range(count):
				var t = float(i) / float(count - 1) if count > 1 else 0.5
				var x_norm = lerp(x_start, x_end, t)
				var x_world = normalized_to_world_x(x_norm)
				var z_offset = -abs(sin(t * PI)) * 2.0
				var z_pos = spawn_z_ahead + z_offset - (i * 1.2)
				
				if coin_scene:
					var coin = coin_scene.instantiate() as Area3D
					add_child(coin)
					coin.global_position = Vector3(x_world, 0.13, z_pos)
					
		"obstacles":
			var x_positions = event.get("x_positions", [])
			var hp = int(event.get("hp", 1))
			for x_norm in x_positions:
				var x_world = normalized_to_world_x(x_norm)
				if barrel_scene:
					var barrel = barrel_scene.instantiate() as Area3D
					add_child(barrel)
					barrel.global_position = Vector3(x_world, 0.05, spawn_z_ahead)
					barrel.hp = hp
					if "obstacle_type" in barrel:
						barrel.obstacle_type = DestructibleObstacle.ObstacleType.WOODEN_BARREL
						
		"obstacle":
			var x_norm = float(event.get("x", 0.0))
			var hp = int(event.get("hp", 1))
			var x_world = normalized_to_world_x(x_norm)
			if barrel_scene:
				var barrel = barrel_scene.instantiate() as Area3D
				add_child(barrel)
				barrel.global_position = Vector3(x_world, 0.05, spawn_z_ahead)
				barrel.hp = hp
				
				if event.get("sub_type", "") == "armored_barrel_chest":
					barrel.set_meta("spawns_chest", true)
					if "obstacle_type" in barrel:
						barrel.obstacle_type = DestructibleObstacle.ObstacleType.RUNE_BARREL
						
		"barricade":
			var x_points = event.get("x_points", [-0.8, -0.4, 0.0, 0.4, 0.8])
			var hp = int(event.get("hp", 2))
			if barricade_scene:
				var wall = barricade_scene.instantiate() as Node3D
				add_child(wall)
				wall.global_position = Vector3(0.0, 0.0, spawn_z_ahead)
				if "x_points" in wall:
					wall.x_points = x_points
				if "hp" in wall:
					wall.hp = hp
					
		"warning":
			var top_hud = get_tree().get_first_node_in_group("top_hud")
			if top_hud and top_hud.has_method("show_warning_alert"):
				top_hud.show_warning_alert("CAUTION: RIVER NARROWING AHEAD!")
				
			# Spawn rocky shores narrowing the river corridor
			for side_x in [-0.85, 0.85]:
				var side_world = normalized_to_world_x(side_x)
				if barrel_scene:
					var rock = barrel_scene.instantiate() as Area3D
					add_child(rock)
					rock.global_position = Vector3(side_world, 0.0, spawn_z_ahead)
					rock.hp = 15
					if "obstacle_type" in rock:
						rock.obstacle_type = DestructibleObstacle.ObstacleType.CORAL_REEF
						
		"raider_skiffs":
			var x_positions = event.get("x_positions", [])
			var hp = int(event.get("hp", 3))
			for x_norm in x_positions:
				var x_world = normalized_to_world_x(x_norm)
				if enemy_mob_scene:
					var enemy = enemy_mob_scene.instantiate() as Area3D
					add_child(enemy)
					enemy.global_position = Vector3(x_world, 0.1, spawn_z_ahead)
					var skiff_data = preload("res://src/data/resources/raider_skiff.tres")
					if enemy.has_method("apply_enemy_data"):
						enemy.apply_enemy_data(skiff_data)
					enemy.max_hp = hp
					enemy.current_hp = hp
					
		"sea_mine":
			var x_norm = float(event.get("x", 0.0))
			var x_world = normalized_to_world_x(x_norm)
			if sea_mine_scene:
				var mine = sea_mine_scene.instantiate() as Node3D
				add_child(mine)
				mine.global_position = Vector3(x_world, 0.0, spawn_z_ahead)
				
		"patrol_boat":
			var x_norm = float(event.get("x", 0.0))
			var x_world = normalized_to_world_x(x_norm)
			
			if enemy_mob_scene:
				var patrol = enemy_mob_scene.instantiate() as Area3D
				add_child(patrol)
				patrol.global_position = Vector3(x_world, 0.1, spawn_z_ahead)
				var patrol_data = preload("res://src/data/resources/turtle_raft.tres")
				if patrol.has_method("apply_enemy_data"):
					patrol.apply_enemy_data(patrol_data)
				patrol.max_hp = 8
				patrol.current_hp = 8
				if "doubloons_drop" in patrol:
					patrol.doubloons_drop = 6
					
			var explosive_barrels = event.get("explosive_barrels", [-0.6, 0.6])
			for side_x in explosive_barrels:
				var side_world = normalized_to_world_x(side_x)
				if barrel_scene:
					var barrel = barrel_scene.instantiate() as Area3D
					add_child(barrel)
					barrel.global_position = Vector3(side_world, 0.05, spawn_z_ahead - 1.2)
					barrel.hp = 1
					if "obstacle_type" in barrel:
						barrel.obstacle_type = DestructibleObstacle.ObstacleType.FUSE_BARREL
						
		"kamikaze_rafts":
			var x_positions = event.get("x_positions", [-0.7, 0.0, 0.7])
			for x_norm in x_positions:
				var x_world = normalized_to_world_x(x_norm)
				if enemy_mob_scene:
					var raft = enemy_mob_scene.instantiate() as Area3D
					add_child(raft)
					raft.global_position = Vector3(x_world, 0.1, spawn_z_ahead)
					var rower_data = preload("res://src/data/resources/skeleton_rower.tres")
					if raft.has_method("apply_enemy_data"):
						raft.apply_enemy_data(rower_data)
					raft.forward_speed = 5.5
					raft.max_hp = 1
					raft.current_hp = 1
					
		"reinforced_gate":
			if reinforced_gate_scene:
				var gate = reinforced_gate_scene.instantiate() as Node3D
				add_child(gate)
				gate.global_position = Vector3(0.0, 0.0, spawn_z_ahead)
				
		"boss":
			_spawn_boss()

func _spawn_boss() -> void:
	if GameState.boss_spawned:
		return
	GameState.boss_spawned = true
	GameState.distance_target_reached.emit()
	
	var player = get_tree().get_first_node_in_group("player")
	var player_z = player.global_position.z if player else 0.0
	
	if boss_scene:
		var boss = boss_scene.instantiate() as Node3D
		var main_root = get_tree().current_scene
		if main_root:
			main_root.add_child(boss)
		else:
			add_child(boss)
		boss.global_position = Vector3(0.0, 0.0, player_z - 60.0)
