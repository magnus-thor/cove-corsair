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

var last_spawned_row_z: float = -70.0
var spawn_interval: float = 12.0
var procedural_pattern_index: int = 0
var bank_strips: Array[Node3D] = []

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

		# Spawn Surrounding Biome & Riverbank system (pre-warmed)
		var strip_scene = preload("res://src/gameplay/levels/biome_bank_strip.tscn")
		if strip_scene:
			for side in ["left", "right"]:
				for i in range(4): # 4 tiles per side
					var strip = strip_scene.instantiate()
					add_child(strip)
					# Pre-warm tiling from Z = 20.0 to Z = -100.0 (covering Z = 40.0 to Z = -140.0)
					strip.global_position = Vector3(0.0, 0.0, 20.0 - i * 40.0)
					if strip.has_method("setup"):
						strip.setup(side, 40.0)
					bank_strips.append(strip)
					
		# Configure Environment Fog
		var env = get_node_or_null("../WorldEnvironment") as WorldEnvironment
		if env and env.environment:
			env.environment.fog_enabled = true
			env.environment.fog_light_color = Color(0.12, 0.22, 0.28) # Moody blue smuggler fog
			env.environment.fog_density = 0.018 # Soft thick fog
			env.environment.fog_sky_affect = 0.4

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
		
	# Scroll tracked spawner Z position
	last_spawned_row_z += speed * delta
	
	# Continuous density spawner check
	if last_spawned_row_z > spawn_z_ahead + spawn_interval:
		if GameState.boss_spawned:
			last_spawned_row_z = spawn_z_ahead
			_spawn_boss_arena_streams()
		else:
			var ok_to_spawn = true
			if GameState.current_level == 1:
				ok_to_spawn = false # Disable procedural rows in Level 1 to enforce strict timeline
			elif not active_queue.is_empty():
				var dist_to_next = active_queue[0].distance - current_distance
				if dist_to_next <= spawn_interval:
					ok_to_spawn = false
			
			if ok_to_spawn:
				last_spawned_row_z = spawn_z_ahead
				_spawn_procedural_row()
		
	# Scroll direct children that are obstacles/enemies
	var scroll_movement = speed * delta
	for child in get_children():
		if child is Node3D and not child.is_in_group("boss") and not child.is_in_group("collectibles") and not child.is_in_group("doubloons"):
			child.global_position.z += scroll_movement

	# Wrap bank strips
	var cleanup_z = 40.0
	for strip in bank_strips:
		if is_instance_valid(strip) and strip.global_position.z > cleanup_z:
			strip.global_position.z -= 160.0 # 4 tiles * 40m = 160m

func normalized_to_world_x(norm_x: float) -> float:
	return norm_x * (river_width_world / 2.0)

func _spawn_wave_event(event: Dictionary, z_pos_override: float = 0.0) -> void:
	if event.has("distance") and z_pos_override == 0.0:
		last_spawned_row_z = spawn_z_ahead
		
	var z_spawn = spawn_z_ahead if z_pos_override == 0.0 else z_pos_override
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
				var z_pos = z_spawn + z_offset - (i * 1.2)
				
				if coin_scene:
					var coin = coin_scene.instantiate() as Area3D
					add_child(coin)
					coin.global_position = Vector3(x_world, 0.13, z_pos)
					
		"obstacles":
			var x_positions = event.get("x_positions", [])
			var hp = int(event.get("hp", 1))
			var obs_type_str = event.get("obstacle_type", "wooden")
			for x_norm in x_positions:
				var x_world = normalized_to_world_x(x_norm)
				if barrel_scene:
					var barrel = barrel_scene.instantiate() as Area3D
					add_child(barrel)
					barrel.global_position = Vector3(x_world, 0.05, z_spawn)
					barrel.hp = hp
					if "obstacle_type" in barrel:
						if obs_type_str == "fuse" or obs_type_str == "explosive":
							barrel.obstacle_type = DestructibleObstacle.ObstacleType.FUSE_BARREL
						else:
							barrel.obstacle_type = DestructibleObstacle.ObstacleType.WOODEN_BARREL
						
		"obstacle":
			var x_norm = float(event.get("x", 0.0))
			var hp = int(event.get("hp", 1))
			var x_world = normalized_to_world_x(x_norm)
			if barrel_scene:
				var barrel = barrel_scene.instantiate() as Area3D
				add_child(barrel)
				barrel.global_position = Vector3(x_world, 0.05, z_spawn)
				barrel.hp = hp
				
				if event.get("sub_type", "") == "armored_barrel_chest":
					barrel.set_meta("spawns_chest", true)
					if "obstacle_type" in barrel:
						barrel.obstacle_type = DestructibleObstacle.ObstacleType.RUNE_BARREL
						
		"barricade":
			var x_points = event.get("x_points", [-0.8, -0.4, 0.0, 0.4, 0.8])
			var hp = int(event.get("hp", 2))
			var hp_values = event.get("hp_values", [])
			if barricade_scene:
				var wall = barricade_scene.instantiate() as Node3D
				add_child(wall)
				wall.global_position = Vector3(0.0, 0.0, z_spawn)
				if "x_points" in wall:
					wall.x_points = x_points
				if "hp" in wall:
					wall.hp = hp
				if "hp_values" in wall:
					wall.hp_values = hp_values
					
		"fleet_gate":
			var gate_prefab = preload("res://src/gameplay/obstacles/multiplier_gate.tscn")
			if gate_prefab:
				var gate = gate_prefab.instantiate() as Area3D
				add_child(gate)
				var x_norm = float(event.get("x", 0.0))
				var x_world = normalized_to_world_x(x_norm)
				gate.global_position = Vector3(x_world, 0.0, z_spawn)
				
				var gate_val = int(event.get("value", 1))
				var gate_text = str(event.get("text", "+%d" % gate_val if not event.has("text") else event.get("text")))
				var gate_action = str(event.get("action", "add_fleet_1" if gate_val == 1 else "add_fleet_2"))
				
				if "custom_text" in gate:
					gate.custom_text = gate_text
				if "gate_action" in gate:
					gate.gate_action = gate_action
				if "value" in gate:
					gate.value = gate_val
				if "operation" in gate:
					gate.operation = 0 # ADD
				
				print("[GATE SPAWNED] At distance: ", current_distance, " | Value: +", gate_val)

		"choice_gates":
			var gates_data = event.get("gates", [])
			var choice_id = "choice_" + str(event.get("distance", current_distance))
			var gate_prefab = preload("res://src/gameplay/obstacles/multiplier_gate.tscn")
			for g_info in gates_data:
				var x_norm = float(g_info.get("x", 0.0))
				var x_world = normalized_to_world_x(x_norm)
				if gate_prefab:
					var gate = gate_prefab.instantiate() as Area3D
					add_child(gate)
					gate.global_position = Vector3(x_world, 0.0, z_spawn)
					var gate_val = int(g_info.get("value", 1))
					if "custom_text" in gate:
						gate.custom_text = g_info.get("text", "")
					if "gate_action" in gate:
						gate.gate_action = g_info.get("action", "")
					if "choice_group" in gate:
						gate.choice_group = choice_id
					if "value" in gate and g_info.has("value"):
						gate.value = gate_val
					if "operation" in gate and g_info.has("operation"):
						gate.operation = int(g_info.get("operation"))
					
					print("[GATE SPAWNED] At distance: ", current_distance, " | Value: +", gate_val)
					
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
					rock.global_position = Vector3(side_world, 0.0, z_spawn)
					rock.hp = 15
					if "obstacle_type" in rock:
						rock.obstacle_type = DestructibleObstacle.ObstacleType.CORAL_REEF
						
		"raider_skiffs":
			var x_positions = event.get("x_positions", [])
			var hp = int(event.get("hp", 3))
			var skiff_speed = float(event.get("speed", 2.0))
			for x_norm in x_positions:
				var x_world = normalized_to_world_x(x_norm)
				if enemy_mob_scene:
					var enemy = enemy_mob_scene.instantiate() as Area3D
					add_child(enemy)
					enemy.global_position = Vector3(x_world, 0.1, z_spawn)
					var skiff_data = preload("res://src/data/resources/raider_skiff.tres")
					if enemy.has_method("apply_enemy_data"):
						enemy.apply_enemy_data(skiff_data)
					enemy.max_hp = hp
					enemy.current_hp = hp
					enemy.forward_speed = skiff_speed
					
		"sea_mine":
			var x_norm = float(event.get("x", 0.0))
			var x_world = normalized_to_world_x(x_norm)
			if sea_mine_scene:
				var mine = sea_mine_scene.instantiate() as Node3D
				add_child(mine)
				mine.global_position = Vector3(x_world, 0.0, z_spawn)
				
		"patrol_boat":
			var x_norm = float(event.get("x", 0.0))
			var x_world = normalized_to_world_x(x_norm)
			
			if enemy_mob_scene:
				var patrol = enemy_mob_scene.instantiate() as Area3D
				add_child(patrol)
				patrol.global_position = Vector3(x_world, 0.1, z_spawn)
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
					barrel.global_position = Vector3(side_world, 0.05, z_spawn - 1.2)
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
					raft.global_position = Vector3(x_world, 0.1, z_spawn)
					var rower_data = preload("res://src/data/resources/skeleton_rower.tres")
					if raft.has_method("apply_enemy_data"):
						raft.apply_enemy_data(rower_data)
					raft.forward_speed = 5.5
					raft.max_hp = 1
					raft.current_hp = 1
					raft.set_meta("is_kamikaze", true)
					
		"reinforced_gate":
			if reinforced_gate_scene:
				var gate = reinforced_gate_scene.instantiate() as Node3D
				var gate_hp = int(event.get("hp", 25))
				if "lock_hp" in gate:
					gate.lock_hp = gate_hp
				add_child(gate)
				gate.global_position = Vector3(0.0, 0.0, z_spawn)
				
		"elite_ironclad":
			var x_norm = float(event.get("x", 0.0))
			var x_world = normalized_to_world_x(x_norm)
			var elite_scene = preload("res://src/gameplay/enemies/enemy_elite_ironclad.tscn")
			if elite_scene:
				var elite = elite_scene.instantiate() as Area3D
				add_child(elite)
				elite.global_position = Vector3(x_world, 0.1, z_spawn)
			if barrel_scene:
				for x_off in [-0.3, 0.3]:
					var barrel = barrel_scene.instantiate() as Area3D
					add_child(barrel)
					barrel.global_position = Vector3(x_world + normalized_to_world_x(x_off), 0.05, z_spawn - 1.5)
					barrel.hp = 1
					if "obstacle_type" in barrel:
						barrel.obstacle_type = DestructibleObstacle.ObstacleType.FUSE_BARREL
				
		"reef_hazard":
			var x_norm = float(event.get("x", 0.0))
			var x_world = normalized_to_world_x(x_norm)
			var scale_x = float(event.get("scale_x", 3.0))
			var scale_z = float(event.get("scale_z", 8.0))
			var reef_prefab = preload("res://src/gameplay/obstacles/hazard_reef.tscn")
			if reef_prefab:
				var reef = reef_prefab.instantiate() as Area3D
				add_child(reef)
				reef.global_position = Vector3(x_world, -0.05, z_spawn)
				reef.scale = Vector3(scale_x, 1.0, scale_z)
				
		"boss":
			_spawn_boss()

func _spawn_boss() -> void:
	if GameState.boss_spawned:
		return
	GameState.boss_spawned = true
	GameState.distance_target_reached.emit()
	
	var player = get_tree().get_first_node_in_group("player")
	var player_z = player.global_position.z if player else 0.0
	
	# Halt scrolling and scroll speeds
	base_scroll_speed = 0.0
	var track_mgr = get_tree().get_first_node_in_group("track_manager")
	if track_mgr:
		track_mgr.scroll_speed = 0.0
	
	if boss_scene:
		var boss = boss_scene.instantiate() as Node3D
		var main_root = get_tree().current_scene
		if main_root:
			main_root.add_child(boss)
		else:
			add_child(boss)
		boss.global_position = Vector3(0.0, 0.0, player_z - 60.0)
		
		# Smoothly focus camera on the boss
		var camera = get_tree().get_first_node_in_group("game_camera")
		if camera and camera.has_method("start_boss_focus"):
			camera.start_boss_focus(boss)

func _spawn_procedural_row() -> void:
	match procedural_pattern_index:
		0:
			# Barrel Walls
			var event = {
				"type": "obstacles",
				"x_positions": [-0.8, -0.4, 0.0, 0.4, 0.8],
				"hp": 1
			}
			_spawn_wave_event(event)
		1:
			# Spawn standard obstacle barrels - NEVER gates
			var event = {
				"type": "barricade",
				"x_points": [-0.6, 0.0, 0.6],
				"hp_values": [randi_range(8, 12), randi_range(2, 4), randi_range(8, 12)]
			}
			_spawn_wave_event(event)
			
		2:
			# Skiff Swarms with Explosives
			var skiff_event = {
				"type": "raider_skiffs",
				"x_positions": [-0.8, -0.6, -0.4, 0.4, 0.6, 0.8],
				"hp": 2
			}
			var keg_event = {
				"type": "obstacles",
				"obstacle_type": "fuse",
				"x_positions": [-0.15, 0.0, 0.15],
				"hp": 1
			}
			_spawn_wave_event(skiff_event)
			_spawn_wave_event(keg_event)
		3:
			# Numbered Log Gates
			var event = {
				"type": "barricade",
				"x_points": [-0.5, 0.0, 0.5],
				"hp_values": [randi_range(15, 30), randi_range(2, 6), randi_range(20, 40)]
			}
			_spawn_wave_event(event)
			
	procedural_pattern_index = (procedural_pattern_index + 1) % 4

func _spawn_boss_arena_streams() -> void:
	var r = randf()
	if r < 0.40:
		var event = {
			"type": "obstacles",
			"obstacle_type": "fuse",
			"x_positions": [-0.6, 0.6],
			"hp": 1
		}
		_spawn_wave_event(event)
	elif r < 0.75:
		# Spawn standard obstacle barrels - NEVER gates
		var event = {
			"type": "obstacles",
			"x_positions": [-0.4, 0.4],
			"hp": 2
		}
		_spawn_wave_event(event)
	else:
		var x_pos = [-0.5 if randf() < 0.5 else 0.5]
		var event = {
			"type": "raider_skiffs",
			"x_positions": x_pos,
			"hp": 2
		}
		_spawn_wave_event(event)
