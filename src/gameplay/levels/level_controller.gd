class_name LevelController
extends Node3D

# ──────────────────────────────────────────────────────────────────────────────
# STRICTLY DETERMINISTIC LEVEL CONTROLLER
# Reads wave_events from LevelData, executes them in order, then triggers boss.
# Zero procedural generation. Zero random timers. No fallback loops.
# ──────────────────────────────────────────────────────────────────────────────

@export var debug_level_override: int = 0
@export var level_data: LevelData = preload("res://src/data/resources/levels/level_01_smugglers_run.tres")
@export var spawn_z_ahead: float = -70.0

const SpawnEvent = preload("res://src/data/spawn_event.gd")

# Prefabs
@export var coin_scene: PackedScene = preload("res://src/gameplay/collectibles/collectible_doubloon.tscn")
@export var barrel_scene: PackedScene = preload("res://src/gameplay/obstacles/destructible_barrel.tscn")
@export var barricade_scene: PackedScene = preload("res://src/gameplay/obstacles/barricade_wall.tscn")
@export var sea_mine_scene: PackedScene = preload("res://src/gameplay/obstacles/hazard_sea_mine.tscn")
@export var reinforced_gate_scene: PackedScene = preload("res://src/gameplay/obstacles/reinforced_gate.tscn")
@export var multiplier_gate_scene: PackedScene = preload("res://src/gameplay/obstacles/multiplier_gate.tscn")
@export var boss_scene: PackedScene = preload("res://src/gameplay/enemies/boss_war_barge.tscn")
@export var enemy_mob_scene: PackedScene = preload("res://src/gameplay/enemies/enemy_mob.tscn")

# Level 2 & 3 Prefabs
@export var biogas_pod_scene: PackedScene = preload("res://src/gameplay/obstacles/hazard_biogas_pod.tscn")
@export var grave_skiff_scene: PackedScene = preload("res://src/gameplay/enemies/enemy_grave_skiff.tscn")
@export var tide_cutter_scene: PackedScene = preload("res://src/gameplay/enemies/enemy_tide_cutter.tscn")
@export var harvester_scene: PackedScene = preload("res://src/gameplay/enemies/enemy_mini_boss_harvester.tscn")

@export var thermal_geyser_scene: PackedScene = preload("res://src/gameplay/obstacles/hazard_thermal_geyser.tscn")
@export var iron_gunner_scene: PackedScene = preload("res://src/gameplay/enemies/enemy_iron_gunner.tscn")
@export var brimstone_raft_scene: PackedScene = preload("res://src/gameplay/enemies/enemy_brimstone_raft.tscn")
@export var bombard_scene: PackedScene = preload("res://src/gameplay/enemies/enemy_mini_boss_bombard.tscn")

var current_distance: float = 0.0
var active_queue: Array = []
var river_width_world: float = 12.0
var base_scroll_speed: float = 10.0
var bank_strips: Array[Node3D] = []          # legacy – kept for potential future use
var riverbank_chunks: Array[Node3D] = []     # Layer 2 framing strips (new system)
var _horizon_backdrop: Node3D = null         # Layer 1 horizon quad
var is_boss_spawned: bool = false

func _ready() -> void:
	add_to_group("level_controller")
	
	if debug_level_override > 0:
		GameState.current_level = debug_level_override
	
	# Load level according to GameState
	var active_res = GameState.get_current_level_resource()
	if active_res:
		load_level_resource(active_res)

func setup_active_queue() -> void:
	active_queue = [] # Guarantee fresh untyped Array
	if not level_data:
		return
	if not level_data.timeline_events.is_empty():
		for te in level_data.timeline_events:
			if te != null:
				active_queue.append(te)
		active_queue.sort_custom(func(a, b):
			var da = a.trigger_distance if "trigger_distance" in a else a.get("distance", 0.0)
			var db = b.trigger_distance if "trigger_distance" in b else b.get("distance", 0.0)
			return da < db
		)
		print("[LEVEL QUEUE] Loaded %d timeline events for %s" % [active_queue.size(), level_data.level_name])
	elif not level_data.wave_events.is_empty():
		for we in level_data.wave_events:
			if we != null:
				active_queue.append(we)
		active_queue.sort_custom(func(a, b): return a.distance < b.distance)
		print("[LEVEL QUEUE] Loaded %d wave events for %s" % [active_queue.size(), level_data.level_name])
	else:
		print("[LEVEL QUEUE WARNING] No events found in %s!" % level_data.level_name)

func load_level_resource(res: LevelData) -> void:
	if not res:
		return
	level_data = res
	current_distance = 0.0
	is_boss_spawned = false
	river_width_world = level_data.river_width_world
	base_scroll_speed = level_data.base_scroll_speed
	GameState.level_distance_target = level_data.target_distance if level_data.target_distance > 0.0 else level_data.total_distance
	GameState.distance_traveled = 0.0
	
	# Clear only dynamically spawned obstacles/mobs/hazards from previous level previews
	for child in get_children():
		if child is Node3D and (child.is_in_group("destructible") or child.is_in_group("hazards") or child.is_in_group("enemies") or child.is_in_group("collectibles") or child.is_in_group("multiplier_gate")):
			child.queue_free()
			
	setup_active_queue()
	
	var track_mgr = get_tree().get_first_node_in_group("track_manager")
	if track_mgr:
		track_mgr.scroll_speed = base_scroll_speed
		if "current_level_data" in track_mgr:
			track_mgr.current_level_data["is_scripted"] = true
			
	var hud = get_tree().get_first_node_in_group("top_hud")
	if hud and "level_title" in hud:
		hud.level_title.text = level_data.level_name
		
	if level_data:
		var biome_name: String = level_data.biome_type if "biome_type" in level_data else "smugglers_run"

		# ── Layer 1: Horizon Backdrop ────────────────────────────────────────
		if not _horizon_backdrop:
			var backdrop_scene := preload("res://src/gameplay/levels/horizon_backdrop.tscn")
			if backdrop_scene:
				_horizon_backdrop = backdrop_scene.instantiate()
				add_child(_horizon_backdrop)
				_horizon_backdrop.add_to_group("horizon_backdrop")  # exempt from child-scroll loop
		
		if _horizon_backdrop and _horizon_backdrop.has_method("bind_texture"):
			var htex: Texture2D = level_data.horizon_texture if ("horizon_texture" in level_data and level_data.horizon_texture) else null
			if not htex:
				var tex_path := "res://assets/textures/horizon_smugglers_run.png"
				if FileAccess.file_exists(tex_path):
					var img := Image.load_from_file(ProjectSettings.globalize_path(tex_path))
					if img and not img.is_empty():
						htex = ImageTexture.create_from_image(img)
			if htex:
				_horizon_backdrop.bind_texture(htex)

		# ── Layer 2: Riverbank Framing Strips ────────────────────────────────
		var valid_chunks = riverbank_chunks.filter(func(c): return is_instance_valid(c))
		if valid_chunks.is_empty():
			riverbank_chunks.clear()
			var props_scene := preload("res://src/gameplay/levels/riverbank_props.tscn")
			if props_scene:
				for prop_side in ["left", "right"]:
					for i in range(4):
						var chunk := props_scene.instantiate()
						add_child(chunk)
						chunk.global_position = Vector3(0.0, 0.0, 20.0 - i * 40.0)
						if chunk.has_method("setup"):
							chunk.setup(prop_side, 40.0, biome_name)
						riverbank_chunks.append(chunk)
		else:
			for chunk in valid_chunks:
				if chunk.has_method("setup"):
					chunk.setup(chunk.side, chunk.chunk_length, biome_name)

		# Configure Environment Visuals
		_apply_biome_visuals()

func _apply_biome_visuals() -> void:
	if not level_data:
		return
		
	var env = get_node_or_null("../WorldEnvironment") as WorldEnvironment
	if env and env.environment:
		env.environment.fog_enabled = false
		env.environment.fog_light_color = level_data.fog_color
		env.environment.fog_density = 0.0
		env.environment.fog_sky_affect = 0.0
		
	# Apply water shader color across track segments
	var track_mgr = get_tree().get_first_node_in_group("track_manager")
	if track_mgr and "active_segments" in track_mgr:
		for seg in track_mgr.active_segments:
			_tint_segment_water(seg, level_data.water_albedo)

func _tint_segment_water(segment: Node, water_color: Color) -> void:
	if not segment:
		return
	var water_plane = segment.get_node_or_null("WaterPlane") as MeshInstance3D
	if water_plane and water_plane.material_override:
		var mat = water_plane.material_override as ShaderMaterial
		if mat:
			mat.set_shader_parameter("albedo", water_color)

func _physics_process(delta: float) -> void:
	if not GameState.is_game_active:
		return
		
	var track_mgr = get_tree().get_first_node_in_group("track_manager")
	var speed = base_scroll_speed
	if track_mgr and "scroll_speed" in track_mgr:
		speed = track_mgr.scroll_speed

	var max_dist = level_data.total_distance if level_data else 250.0

	# ── Boss-Arena Trigger ───────────────────────────────────────────
	if not is_boss_spawned and current_distance >= max_dist:
		current_distance = max_dist       # Lock – no drift past cap
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
		current_distance = minf(new_dist, max_dist)
		GameState.update_distance(speed * delta)

	# ── Deterministic wave event dispatch ─────────────────────────────────────
	while not active_queue.is_empty():
		var first = active_queue[0]
		var dist = first.trigger_distance if "trigger_distance" in first else first.get("distance", 0.0)
		if current_distance >= dist:
			var event = active_queue.pop_front()
			if event is SpawnEvent or "entity_type" in event:
				_spawn_timeline_event(event)
			else:
				_spawn_wave_event(event)
		else:
			break
	# ──────────────────────────────────────────────────────────────────────────

	# Scroll LevelController-owned obstacles/enemies forward
	var scroll_movement = speed * delta
	for child in get_children():
		if child is Node3D \
				and not child.is_in_group("boss") \
				and not child.is_in_group("collectibles") \
				and not child.is_in_group("doubloons") \
				and not child.is_in_group("horizon_backdrop"):
			child.global_position.z += scroll_movement

	# Wrap bank strips (legacy – array is empty; kept as no-op for safety)
	for strip in bank_strips:
		if is_instance_valid(strip) and strip.global_position.z > 40.0:
			strip.global_position.z -= 160.0  # 4 tiles × 40m

	# Recycle Layer-2 riverbank framing chunks (4 tiles × 40m = 160m pool)
	for chunk in riverbank_chunks:
		if is_instance_valid(chunk) and chunk.global_position.z > 40.0:
			chunk.global_position.z -= 160.0

func normalized_to_world_x(norm_x: float) -> float:
	return norm_x * (river_width_world / 2.0)

func _spawn_timeline_event(event: SpawnEvent, z_pos_override: float = 0.0) -> void:
	var z_spawn = spawn_z_ahead if z_pos_override == 0.0 else z_pos_override
	var x_pos = clampf(event.lane_x, -7.5, 7.5)
	
	match event.entity_type:
		SpawnEvent.EntityType.BARREL:
			if barrel_scene:
				var barrel = barrel_scene.instantiate() as Area3D
				barrel.name = "Barrel_%.1fm_x%.1f" % [current_distance, x_pos]
				add_child(barrel)
				barrel.global_position = Vector3(x_pos, 0.05, z_spawn)
				var hp = event.base_hp_override if event.base_hp_override > 0 else (2 if event.rarity_tier == SpawnEvent.RarityTier.COMMON else (4 if event.rarity_tier == SpawnEvent.RarityTier.NORMAL else 6))
				barrel.hp = hp
				var type_name = "WOODEN"
				if "obstacle_type" in barrel:
					if event.rarity_tier == SpawnEvent.RarityTier.RARE:
						barrel.obstacle_type = DestructibleObstacle.ObstacleType.RUNE_BARREL
						type_name = "RUNE"
					elif event.rarity_tier == SpawnEvent.RarityTier.NORMAL:
						barrel.obstacle_type = DestructibleObstacle.ObstacleType.FUSE_BARREL
						type_name = "FUSE"
					else:
						barrel.obstacle_type = DestructibleObstacle.ObstacleType.WOODEN_BARREL
				print("[SPAWN] Barrel (%s) at dist=%.1fm | lane_x=%.2f | HP=%d" % [type_name, current_distance, x_pos, hp])

		SpawnEvent.EntityType.MOB:
			if event.rarity_tier == SpawnEvent.RarityTier.ELITE or event.base_hp_override >= 40:
				if harvester_scene:
					var harv = harvester_scene.instantiate() as Area3D
					harv.name = "MiniBossHarvester_%.1fm" % current_distance
					add_child(harv)
					harv.global_position = Vector3(x_pos, 0.1, z_spawn)
					harv.max_hp = event.base_hp_override if event.base_hp_override > 0 else 45
					harv.current_hp = harv.max_hp
					print("[SPAWN MOB] Mini-Boss Harvester at dist=%.1fm | lane_x=%.2f | HP=%d" % [current_distance, x_pos, harv.max_hp])
			elif (event.rarity_tier == SpawnEvent.RarityTier.RARE and event.base_hp_override >= 8) or event.base_hp_override == 8:
				if tide_cutter_scene:
					var cutter = tide_cutter_scene.instantiate() as Area3D
					cutter.name = "TideCutter_%.1fm_x%.1f" % [current_distance, x_pos]
					add_child(cutter)
					cutter.global_position = Vector3(x_pos, 0.1, z_spawn)
					cutter.max_hp = event.base_hp_override if event.base_hp_override > 0 else 8
					cutter.current_hp = cutter.max_hp
					cutter.forward_speed = 4.5
					print("[SPAWN MOB] Tide Cutter at dist=%.1fm | lane_x=%.2f | HP=%d | Speed=4.5" % [current_distance, x_pos, cutter.max_hp])
			else:
				if grave_skiff_scene:
					var skiff = grave_skiff_scene.instantiate() as Area3D
					skiff.name = "GraveSkiff_%.1fm_x%.1f" % [current_distance, x_pos]
					add_child(skiff)
					skiff.global_position = Vector3(x_pos, 0.1, z_spawn)
					skiff.max_hp = event.base_hp_override if event.base_hp_override > 0 else (6 if event.rarity_tier == SpawnEvent.RarityTier.RARE else 4)
					skiff.current_hp = skiff.max_hp
					skiff.forward_speed = 2.4
					print("[SPAWN MOB] Grave Skiff at dist=%.1fm | lane_x=%.2f | HP=%d | Speed=2.4" % [current_distance, x_pos, skiff.max_hp])

		SpawnEvent.EntityType.MULTIPLIER_GATE:
			if multiplier_gate_scene:
				var gate = multiplier_gate_scene.instantiate() as Area3D
				gate.name = "MultiplierGate_%.1fm" % current_distance
				add_child(gate)
				gate.global_position = Vector3(x_pos, 0.0, z_spawn)
				var text_val = "+%d" % event.gate_value if event.gate_type == SpawnEvent.GateType.FLEET_SUMMON else ("x%d" % event.gate_value)
				if "value" in gate:
					gate.value = event.gate_value
				if "custom_text" in gate:
					gate.custom_text = text_val
				if gate.has_method("update_visuals"):
					gate.update_visuals()
				print("[SPAWN GATE] Multiplier Gate (%s) at dist=%.1fm | lane_x=%.2f" % [text_val, current_distance, x_pos])

		SpawnEvent.EntityType.HAZARD:
			if event.rarity_tier == SpawnEvent.RarityTier.RARE or event.base_hp_override >= 5:
				var reef_prefab = preload("res://src/gameplay/obstacles/hazard_reef.tscn")
				if reef_prefab:
					var reef = reef_prefab.instantiate() as Area3D
					reef.name = "CoralReef_%.1fm_x%.1f" % [current_distance, x_pos]
					add_child(reef)
					reef.global_position = Vector3(x_pos, 0.0, z_spawn)
					print("[SPAWN HAZARD] Indestructible Coral Reef at dist=%.1fm | lane_x=%.2f" % [current_distance, x_pos])
			elif biogas_pod_scene:
				var pod = biogas_pod_scene.instantiate() as Area3D
				pod.name = "BiogasPod_%.1fm_x%.1f" % [current_distance, x_pos]
				add_child(pod)
				pod.global_position = Vector3(x_pos, 0.05, z_spawn)
				pod.hp = event.base_hp_override if event.base_hp_override > 0 else 1
				print("[SPAWN HAZARD] Biogas Pod at dist=%.1fm | lane_x=%.2f | HP=%d" % [current_distance, x_pos, pod.hp])

		SpawnEvent.EntityType.BOSS:
			print("[SPAWN BOSS TRIGGER] Triggering Boss at dist=%.1fm" % current_distance)
			_spawn_boss()

# ──────────────────────────────────────────────────────────────────────────────
# EVENT SPAWNER – purely data-driven, no randomness
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

		# ── Barrel row ────────────────────────────────────────────────────────
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

		# ── Biogas Pod (Level 2) ──────────────────────────────────────────────
		"biogas_pod":
			var x_norm = float(event.get("x", 0.0))
			var x_world = normalized_to_world_x(x_norm)
			if biogas_pod_scene:
				var pod = biogas_pod_scene.instantiate() as Area3D
				add_child(pod)
				pod.global_position = Vector3(x_world, 0.0, z_spawn)

		# ── Grave Skiffs (Level 2) ────────────────────────────────────────────
		"grave_skiffs":
			var x_positions: Array = event.get("x_positions", [0.0])
			var hp = int(event.get("hp", 14))
			var speed_val = float(event.get("speed", 3.2))
			for x_norm in x_positions:
				var x_world = normalized_to_world_x(float(x_norm))
				if grave_skiff_scene:
					var skiff = grave_skiff_scene.instantiate() as Area3D
					add_child(skiff)
					skiff.global_position = Vector3(x_world, 0.1, z_spawn)
					skiff.max_hp = hp
					skiff.current_hp = hp
					skiff.forward_speed = speed_val

		# ── Tide Cutters (Level 2) ────────────────────────────────────────────
		"tide_cutters":
			var x_positions: Array = event.get("x_positions", [0.0])
			var hp = int(event.get("hp", 20))
			var speed_val = float(event.get("speed", 6.8))
			for x_norm in x_positions:
				var x_world = normalized_to_world_x(float(x_norm))
				if tide_cutter_scene:
					var cutter = tide_cutter_scene.instantiate() as Area3D
					add_child(cutter)
					cutter.global_position = Vector3(x_world, 0.1, z_spawn)
					cutter.max_hp = hp
					cutter.current_hp = hp
					cutter.forward_speed = speed_val

		# ── Mini Boss Harvester (Level 2) ─────────────────────────────────────
		"mini_boss_harvester":
			var x_norm = float(event.get("x", 0.0))
			var x_world = normalized_to_world_x(x_norm)
			if harvester_scene:
				var harvester = harvester_scene.instantiate() as Area3D
				add_child(harvester)
				harvester.global_position = Vector3(x_world, 0.1, z_spawn)
				harvester.max_hp = int(event.get("hp", 110))
				harvester.current_hp = harvester.max_hp
				harvester.forward_speed = float(event.get("speed", 1.4))

		# ── Thermal Geyser (Level 3) ──────────────────────────────────────────
		"thermal_geyser":
			var x_norm = float(event.get("x", 0.0))
			var x_world = normalized_to_world_x(x_norm)
			if thermal_geyser_scene:
				var geyser = thermal_geyser_scene.instantiate() as Node3D
				add_child(geyser)
				geyser.global_position = Vector3(x_world, 0.0, z_spawn)

		# ── Iron Gunners (Level 3) ────────────────────────────────────────────
		"iron_gunners":
			var x_positions: Array = event.get("x_positions", [0.0])
			var hp = int(event.get("hp", 22))
			var speed_val = float(event.get("speed", 2.6))
			for x_norm in x_positions:
				var x_world = normalized_to_world_x(float(x_norm))
				if iron_gunner_scene:
					var gunner = iron_gunner_scene.instantiate() as Area3D
					add_child(gunner)
					gunner.global_position = Vector3(x_world, 0.1, z_spawn)
					gunner.max_hp = hp
					gunner.current_hp = hp
					gunner.forward_speed = speed_val

		# ── Brimstone Rafts (Level 3) ─────────────────────────────────────────
		"brimstone_rafts":
			var x_positions: Array = event.get("x_positions", [0.0])
			var hp = int(event.get("hp", 18))
			var speed_val = float(event.get("speed", 7.8))
			for x_norm in x_positions:
				var x_world = normalized_to_world_x(float(x_norm))
				if brimstone_raft_scene:
					var raft = brimstone_raft_scene.instantiate() as Area3D
					add_child(raft)
					raft.global_position = Vector3(x_world, 0.1, z_spawn)
					raft.max_hp = hp
					raft.current_hp = hp
					raft.forward_speed = speed_val

		# ── Mini Boss Bombard (Level 3) ───────────────────────────────────────
		"mini_boss_bombard":
			var x_norm = float(event.get("x", 0.0))
			var x_world = normalized_to_world_x(x_norm)
			if bombard_scene:
				var bombard = bombard_scene.instantiate() as Area3D
				add_child(bombard)
				bombard.global_position = Vector3(x_world, 0.1, z_spawn)
				bombard.max_hp = int(event.get("hp", 120))
				bombard.current_hp = bombard.max_hp
				bombard.forward_speed = float(event.get("speed", 1.3))

		# ── Skeleton Rowers (Level 1) ─────────────────────────────────────────
		"skeleton_rowers":
			var x_positions: Array = event.get("x_positions", [])
			var hp = int(event.get("hp", 6))
			var mob_speed = float(event.get("speed", 2.0))
			for x_norm in x_positions:
				var x_world = normalized_to_world_x(float(x_norm))
				if enemy_mob_scene:
					var mob = enemy_mob_scene.instantiate() as Area3D
					add_child(mob)
					mob.global_position = Vector3(x_world, 0.1, z_spawn)
					var rower_data = preload("res://src/data/resources/enemy_vessels/skeleton_rower.tres")
					if mob.has_method("apply_enemy_data"):
						mob.apply_enemy_data(rower_data)
					mob.max_hp = hp
					mob.current_hp = hp
					mob.forward_speed = mob_speed

		# ── Raider Skiffs (Level 1) ───────────────────────────────────────────
		"raider_skiffs":
			var x_positions: Array = event.get("x_positions", [])
			var hp = int(event.get("hp", 10))
			var skiff_speed = float(event.get("speed", 3.0))
			for x_norm in x_positions:
				var x_world = normalized_to_world_x(float(x_norm))
				if enemy_mob_scene:
					var enemy = enemy_mob_scene.instantiate() as Area3D
					add_child(enemy)
					enemy.global_position = Vector3(x_world, 0.1, z_spawn)
					var skiff_data = preload("res://src/data/resources/enemy_vessels/raider_skiff.tres")
					if enemy.has_method("apply_enemy_data"):
						enemy.apply_enemy_data(skiff_data)
					enemy.max_hp = hp
					enemy.current_hp = hp
					enemy.forward_speed = skiff_speed

		# ── Kamikaze Rafts (Level 1) ──────────────────────────────────────────
		"kamikaze_rafts":
			var x_positions: Array = event.get("x_positions", [-0.6, 0.6])
			var hp = int(event.get("hp", 14))
			var raft_speed = float(event.get("speed", 7.0))
			for x_norm in x_positions:
				var x_world = normalized_to_world_x(float(x_norm))
				if enemy_mob_scene:
					var raft = enemy_mob_scene.instantiate() as Area3D
					add_child(raft)
					raft.global_position = Vector3(x_world, 0.1, z_spawn)
					var rower_data = preload("res://src/data/resources/enemy_vessels/skeleton_rower.tres")
					if raft.has_method("apply_enemy_data"):
						raft.apply_enemy_data(rower_data)
					raft.forward_speed = raft_speed
					raft.max_hp = hp
					raft.current_hp = hp
					raft.set_meta("is_kamikaze", true)

		# ── Sea Mine ──────────────────────────────────────────────────────────
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

		# ── Armored Turtle Rafts ───────────────────────────────────────────────
		"turtle_rafts":
			var x_positions: Array = event.get("x_positions", [0.0])
			var hp         = int(event.get("hp", 8))
			var raft_speed = float(event.get("speed", 1.8))
			for x_norm in x_positions:
				var x_world = normalized_to_world_x(float(x_norm))
				if enemy_mob_scene:
					var enemy = enemy_mob_scene.instantiate() as Area3D
					add_child(enemy)
					enemy.global_position = Vector3(x_world, 0.1, z_spawn)
					var turtle_data = preload("res://src/data/resources/enemy_vessels/turtle_raft.tres")
					if enemy.has_method("apply_enemy_data"):
						enemy.apply_enemy_data(turtle_data)
					enemy.max_hp        = hp
					enemy.current_hp    = hp
					enemy.forward_speed = raft_speed

		# ── Barricade wall ────────────────────────────────────────────────────
		"barricade":
			var x_points = event.get("x_points", [-0.8, -0.4, 0.0, 0.4, 0.8])
			var hp       = int(event.get("hp", 2))
			var hp_values: Array = event.get("hp_values", [])
			if barricade_scene:
				var wall = barricade_scene.instantiate() as Node3D
				add_child(wall)
				wall.global_position = Vector3(0.0, 0.0, z_spawn)
				if "x_points" in wall: wall.x_points = x_points
				if "hp" in wall: wall.hp = hp
				if "hp_values" in wall: wall.hp_values = hp_values

		# ── Reinforced gate (Ironwood) ─────────────────────────────────────────
		"reinforced_gate":
			if reinforced_gate_scene:
				var gate    = reinforced_gate_scene.instantiate() as Node3D
				var gate_hp = int(event.get("hp", 50))
				if "lock_hp" in gate: gate.lock_hp = gate_hp
				add_child(gate)
				gate.global_position = Vector3(0.0, 0.0, z_spawn)

		# ── Mixed wave ────────────────────────────────────────────────────────
		"mixed_wave":
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
						mob_data = preload("res://src/data/resources/enemy_vessels/raider_skiff.tres")
					else:
						mob_data = preload("res://src/data/resources/enemy_vessels/skeleton_rower.tres")
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

	# Clean up track obstacles in the arena so the boss channel is completely clear
	for grp in ["obstacles", "destructible_obstacles", "multiplier_gate"]:
		for obs in get_tree().get_nodes_in_group(grp):
			if is_instance_valid(obs) and not obs.is_in_group("boss") and not (obs is BossWarBarge) and not (obs is BossComponentDelegate):
				obs.queue_free()

	var spawn_prefab = boss_scene
	if level_data and "boss_scene" in level_data and level_data.boss_scene:
		spawn_prefab = level_data.boss_scene

	if spawn_prefab:
		var boss      = spawn_prefab.instantiate() as Node3D
		var main_root = get_tree().current_scene
		if main_root:
			main_root.add_child(boss)
		else:
			add_child(boss)
		boss.global_position = Vector3(0.0, 0.0, player_z - 18.0)
		print("[BOSS] Spawned boss for ", level_data.level_name if level_data else "Level")

		# Lock camera to boss arena
		var camera = get_tree().get_first_node_in_group("game_camera")
		if camera and camera.has_method("start_boss_focus"):
			camera.start_boss_focus(boss)
