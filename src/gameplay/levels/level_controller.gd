class_name LevelController
extends Node3D

# ──────────────────────────────────────────────────────────────────────────────
# STRICTLY DETERMINISTIC LEVEL CONTROLLER
# Reads wave_events from LevelData, executes them in order, then triggers boss.
# Zero procedural generation. Zero random timers. No fallback loops.
# ──────────────────────────────────────────────────────────────────────────────

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
var bank_strips: Array[Node3D] = []
var is_boss_spawned: bool = false

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
		
		# Copy and sort wave events by distance – deterministic order
		active_queue = level_data.wave_events.duplicate()
		active_queue.sort_custom(func(a, b): return a.distance < b.distance)
		
		# Configure TrackManager
		var track_mgr = get_tree().get_first_node_in_group("track_manager")
		if track_mgr:
			track_mgr.scroll_speed = base_scroll_speed
			if "current_level_data" in track_mgr:
				track_mgr.current_level_data["is_scripted"] = true
				
		# Update level title on HUD
		var hud = get_tree().get_first_node_in_group("top_hud")
		if hud and "level_title" in hud:
			hud.level_title.text = level_data.level_name

		# Spawn Surrounding Biome & Riverbank (pre-warmed)
		var strip_scene = preload("res://src/gameplay/levels/biome_bank_strip.tscn")
		if strip_scene:
			for side in ["left", "right"]:
				for i in range(4):
					var strip = strip_scene.instantiate()
					add_child(strip)
					strip.global_position = Vector3(0.0, 0.0, 20.0 - i * 40.0)
					if strip.has_method("setup"):
						strip.setup(side, 40.0)
					bank_strips.append(strip)
					
		# Configure Environment Fog
		var env = get_node_or_null("../WorldEnvironment") as WorldEnvironment
		if env and env.environment:
			env.environment.fog_enabled = true
			env.environment.fog_light_color = Color(0.12, 0.22, 0.28)
			env.environment.fog_density = 0.018
			env.environment.fog_sky_affect = 0.4

func _physics_process(delta: float) -> void:
	if not GameState.is_game_active:
		return
		
	var track_mgr = get_tree().get_first_node_in_group("track_manager")
	var speed = base_scroll_speed
	if track_mgr and "scroll_speed" in track_mgr:
		speed = track_mgr.scroll_speed

	# ── Hard 250m Boss-Arena Trigger ───────────────────────────────────────────
	# When distance reaches the cap AND all wave events are exhausted, spawn boss.
	if not is_boss_spawned and current_distance >= 250.0:
		current_distance = 250.0       # Lock – no drift past cap
		base_scroll_speed = 0.0
		if track_mgr:
			track_mgr.scroll_speed = 0.0
		active_queue.clear()           # Ensure nothing fires after boss spawn
		_spawn_boss()
		return
	# ──────────────────────────────────────────────────────────────────────────

	# Accumulate distance only while pre-boss and not yet halted
	if not GameState.boss_spawned:
		var new_dist = current_distance + speed * delta
		current_distance = minf(new_dist, 250.0)
		GameState.update_distance(speed * delta)

	# ── Deterministic wave event dispatch ─────────────────────────────────────
	# Pop and execute every event whose trigger distance has been reached.
	while not active_queue.is_empty() and current_distance >= active_queue[0].distance:
		var event = active_queue.pop_front()
		_spawn_wave_event(event)
	# ──────────────────────────────────────────────────────────────────────────

	# Scroll LevelController-owned obstacles/enemies forward
	var scroll_movement = speed * delta
	for child in get_children():
		if child is Node3D \
				and not child.is_in_group("boss") \
				and not child.is_in_group("collectibles") \
				and not child.is_in_group("doubloons"):
			child.global_position.z += scroll_movement

	# Wrap bank strips (infinite tiling river banks)
	for strip in bank_strips:
		if is_instance_valid(strip) and strip.global_position.z > 40.0:
			strip.global_position.z -= 160.0  # 4 tiles × 40m

func normalized_to_world_x(norm_x: float) -> float:
	return norm_x * (river_width_world / 2.0)

# ──────────────────────────────────────────────────────────────────────────────
# EVENT SPAWNER  –  purely data-driven, no randomness
# ──────────────────────────────────────────────────────────────────────────────
func _spawn_wave_event(event: Dictionary, z_pos_override: float = 0.0) -> void:
	var z_spawn = spawn_z_ahead if z_pos_override == 0.0 else z_pos_override
	var event_type: String = event.get("type", "")

	match event_type:

		# ── Coin arc ──────────────────────────────────────────────────────────
		"coin_arc":
			var x_start = float(event.get("x_start", -0.3))
			var x_end   = float(event.get("x_end",   0.3))
			var count   = int(event.get("count", 5))
			for i in range(count):
				var t      = float(i) / float(count - 1) if count > 1 else 0.5
				var x_norm = lerp(x_start, x_end, t)
				var x_world = normalized_to_world_x(x_norm)
				var z_offset = -abs(sin(t * PI)) * 2.0
				var z_pos    = z_spawn + z_offset - (i * 1.2)
				if coin_scene:
					var coin = coin_scene.instantiate() as Area3D
					add_child(coin)
					coin.global_position = Vector3(x_world, 0.13, z_pos)

		# ── Barrel row (multiple X positions) ────────────────────────────────
		"obstacles":
			var x_positions: Array = event.get("x_positions", [])
			var hp           = int(event.get("hp", 4))
			var obs_type_str: String = event.get("obstacle_type", "wooden")
			for x_norm in x_positions:
				var x_world = normalized_to_world_x(float(x_norm))
				if barrel_scene:
					var barrel = barrel_scene.instantiate() as Area3D
					add_child(barrel)
					barrel.global_position = Vector3(x_world, 0.05, z_spawn)
					barrel.hp = hp
					if "obstacle_type" in barrel:
						if obs_type_str == "fuse" or obs_type_str == "explosive":
							barrel.obstacle_type = DestructibleObstacle.ObstacleType.FUSE_BARREL
						elif obs_type_str == "rune":
							barrel.obstacle_type = DestructibleObstacle.ObstacleType.RUNE_BARREL
						else:
							barrel.obstacle_type = DestructibleObstacle.ObstacleType.WOODEN_BARREL

		# ── Single barrel / obstacle ──────────────────────────────────────────
		"obstacle":
			var x_norm  = float(event.get("x", 0.0))
			var hp      = int(event.get("hp", 4))
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

		# ── Barricade wall ────────────────────────────────────────────────────
		"barricade":
			var x_points = event.get("x_points", [-0.8, -0.4, 0.0, 0.4, 0.8])
			var hp       = int(event.get("hp", 2))
			var hp_values: Array = event.get("hp_values", [])
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

		# ── Fleet gate (adds ships) ────────────────────────────────────────────
		"fleet_gate":
			var gate_prefab = preload("res://src/gameplay/obstacles/multiplier_gate.tscn")
			if gate_prefab:
				var gate    = gate_prefab.instantiate() as Area3D
				add_child(gate)
				var x_norm  = float(event.get("x", 0.0))
				var x_world = normalized_to_world_x(x_norm)
				gate.global_position = Vector3(x_world, 0.0, z_spawn)
				var gate_val    = int(event.get("value", 1))
				var gate_text   = str(event.get("text", "+%d" % gate_val))
				var gate_action = str(event.get("action", "add_fleet_1" if gate_val == 1 else "add_fleet_2"))
				if "custom_text" in gate: gate.custom_text = gate_text
				if "gate_action"  in gate: gate.gate_action  = gate_action
				if "value"        in gate: gate.value         = gate_val
				if "operation"    in gate: gate.operation     = 0  # ADD
				print("[GATE] Spawned +", gate_val, " gate at ", current_distance, "m")

		# ── Skeleton Rower mobs ───────────────────────────────────────────────
		"skeleton_rowers":
			var x_positions: Array = event.get("x_positions", [])
			var hp            = int(event.get("hp", 6))
			var mob_speed     = float(event.get("speed", 2.0))
			for x_norm in x_positions:
				var x_world = normalized_to_world_x(float(x_norm))
				if enemy_mob_scene:
					var mob = enemy_mob_scene.instantiate() as Area3D
					add_child(mob)
					mob.global_position = Vector3(x_world, 0.1, z_spawn)
					var rower_data = preload("res://src/data/resources/skeleton_rower.tres")
					if mob.has_method("apply_enemy_data"):
						mob.apply_enemy_data(rower_data)
					mob.max_hp        = hp
					mob.current_hp    = hp
					mob.forward_speed = mob_speed

		# ── Raider Skiffs ─────────────────────────────────────────────────────
		"raider_skiffs":
			var x_positions: Array = event.get("x_positions", [])
			var hp         = int(event.get("hp", 10))
			var skiff_speed = float(event.get("speed", 3.0))
			for x_norm in x_positions:
				var x_world = normalized_to_world_x(float(x_norm))
				if enemy_mob_scene:
					var enemy = enemy_mob_scene.instantiate() as Area3D
					add_child(enemy)
					enemy.global_position = Vector3(x_world, 0.1, z_spawn)
					var skiff_data = preload("res://src/data/resources/raider_skiff.tres")
					if enemy.has_method("apply_enemy_data"):
						enemy.apply_enemy_data(skiff_data)
					enemy.max_hp        = hp
					enemy.current_hp    = hp
					enemy.forward_speed = skiff_speed

		# ── Kamikaze fire-rafts ───────────────────────────────────────────────
		"kamikaze_rafts":
			var x_positions: Array = event.get("x_positions", [-0.6, 0.6])
			var hp          = int(event.get("hp", 14))
			var raft_speed  = float(event.get("speed", 7.0))
			for x_norm in x_positions:
				var x_world = normalized_to_world_x(float(x_norm))
				if enemy_mob_scene:
					var raft = enemy_mob_scene.instantiate() as Area3D
					add_child(raft)
					raft.global_position = Vector3(x_world, 0.1, z_spawn)
					var rower_data = preload("res://src/data/resources/skeleton_rower.tres")
					if raft.has_method("apply_enemy_data"):
						raft.apply_enemy_data(rower_data)
					raft.forward_speed = raft_speed
					raft.max_hp        = hp
					raft.current_hp    = hp
					raft.set_meta("is_kamikaze", true)

		# ── Sea mine ─────────────────────────────────────────────────────────
		"sea_mine":
			var x_norm  = float(event.get("x", 0.0))
			var x_world = normalized_to_world_x(x_norm)
			if sea_mine_scene:
				var mine = sea_mine_scene.instantiate() as Node3D
				add_child(mine)
				mine.global_position = Vector3(x_world, 0.0, z_spawn)

		# ── Reef hazard ───────────────────────────────────────────────────────
		"reef_hazard":
			var x_norm   = float(event.get("x", 0.0))
			var x_world  = normalized_to_world_x(x_norm)
			var scale_x  = float(event.get("scale_x", 3.0))
			var scale_z  = float(event.get("scale_z", 8.0))
			var reef_prefab = preload("res://src/gameplay/obstacles/hazard_reef.tscn")
			if reef_prefab:
				var reef = reef_prefab.instantiate() as Area3D
				add_child(reef)
				reef.global_position = Vector3(x_world, -0.05, z_spawn)
				reef.scale = Vector3(scale_x, 1.0, scale_z)

		# ── Elite Ironclad mini-boss ───────────────────────────────────────────
		"elite_ironclad":
			var x_norm  = float(event.get("x", 0.0))
			var x_world = normalized_to_world_x(x_norm)
			var hp      = int(event.get("hp", 65))
			var elite_scene = preload("res://src/gameplay/enemies/enemy_elite_ironclad.tscn")
			if elite_scene:
				var elite = elite_scene.instantiate() as Area3D
				add_child(elite)
				elite.global_position = Vector3(x_world, 0.1, z_spawn)
				# Override HP from event data
				if "max_hp" in elite:     elite.max_hp     = hp
				if "current_hp" in elite: elite.current_hp = hp
			# Flanking fuse barrels
			var fuse_offsets: Array = event.get("fuse_offsets", [-0.35, 0.35])
			for x_off in fuse_offsets:
				if barrel_scene:
					var barrel = barrel_scene.instantiate() as Area3D
					add_child(barrel)
					barrel.global_position = Vector3(x_world + normalized_to_world_x(float(x_off)), 0.05, z_spawn - 1.5)
					barrel.hp = 1
					if "obstacle_type" in barrel:
						barrel.obstacle_type = DestructibleObstacle.ObstacleType.FUSE_BARREL

		# ── Reinforced gate (Ironwood) ─────────────────────────────────────────
		"reinforced_gate":
			if reinforced_gate_scene:
				var gate    = reinforced_gate_scene.instantiate() as Node3D
				var gate_hp = int(event.get("hp", 50))
				if "lock_hp" in gate:
					gate.lock_hp = gate_hp
				add_child(gate)
				gate.global_position = Vector3(0.0, 0.0, z_spawn)

		# ── Mixed wave: barrels + mobs together ────────────────────────────────
		"mixed_wave":
			# Barrels first
			var barrel_positions: Array = event.get("barrel_positions", [])
			var barrel_hp   = int(event.get("barrel_hp", 4))
			var barrel_type: String = event.get("barrel_type", "wooden")
			for x_norm in barrel_positions:
				var x_world = normalized_to_world_x(float(x_norm))
				if barrel_scene:
					var barrel = barrel_scene.instantiate() as Area3D
					add_child(barrel)
					barrel.global_position = Vector3(x_world, 0.05, z_spawn)
					barrel.hp = barrel_hp
					if "obstacle_type" in barrel:
						if barrel_type == "fuse":
							barrel.obstacle_type = DestructibleObstacle.ObstacleType.FUSE_BARREL
						else:
							barrel.obstacle_type = DestructibleObstacle.ObstacleType.WOODEN_BARREL
			# Mobs second (slightly behind barrels)
			var mob_positions: Array = event.get("mob_positions", [])
			var mob_hp        = int(event.get("mob_hp", 6))
			var mob_type: String = event.get("mob_type", "skeleton_rower")
			var mob_speed     = float(event.get("mob_speed", 2.0))
			for x_norm in mob_positions:
				var x_world = normalized_to_world_x(float(x_norm))
				if enemy_mob_scene:
					var mob = enemy_mob_scene.instantiate() as Area3D
					add_child(mob)
					mob.global_position = Vector3(x_world, 0.1, z_spawn + 2.0)
					var mob_data: EnemyData = null
					if mob_type == "raider_skiff":
						mob_data = preload("res://src/data/resources/raider_skiff.tres")
					else:
						mob_data = preload("res://src/data/resources/skeleton_rower.tres")
					if mob.has_method("apply_enemy_data") and mob_data:
						mob.apply_enemy_data(mob_data)
					mob.max_hp        = mob_hp
					mob.current_hp    = mob_hp
					mob.forward_speed = mob_speed

		# ── HUD alert/warning ────────────────────────────────────────────────
		"warning":
			var top_hud = get_tree().get_first_node_in_group("top_hud")
			if top_hud and top_hud.has_method("show_warning_alert"):
				top_hud.show_warning_alert(event.get("message", "DANGER AHEAD!"))

		# ── Boss trigger ─────────────────────────────────────────────────────
		"boss":
			_spawn_boss()

# ──────────────────────────────────────────────────────────────────────────────
# BOSS SPAWN
# ──────────────────────────────────────────────────────────────────────────────
func _spawn_boss() -> void:
	if is_boss_spawned:
		return
	is_boss_spawned = true
	GameState.boss_spawned = true
	GameState.distance_target_reached.emit()

	var player   = get_tree().get_first_node_in_group("player")
	var player_z = player.global_position.z if player else 0.0

	# Fully halt all scrolling
	base_scroll_speed = 0.0
	var track_mgr = get_tree().get_first_node_in_group("track_manager")
	if track_mgr:
		track_mgr.scroll_speed = 0.0

	if boss_scene:
		var boss      = boss_scene.instantiate() as Node3D
		var main_root = get_tree().current_scene
		if main_root:
			main_root.add_child(boss)
		else:
			add_child(boss)
		# Spawn War-Barge 18 units ahead of the player (Z = -18)
		boss.global_position = Vector3(0.0, 0.0, player_z - 18.0)
		print("[BOSS] Captain Ironjaw's War-Barge spawned at distance 250m")

		# Lock camera to boss arena
		var camera = get_tree().get_first_node_in_group("game_camera")
		if camera and camera.has_method("start_boss_focus"):
			camera.start_boss_focus(boss)
