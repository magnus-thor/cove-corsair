class_name LevelController
extends Node3D

# ──────────────────────────────────────────────────────────────────────────────
# STRICTLY DETERMINISTIC LEVEL CONTROLLER
# Reads wave_events from LevelData, executes them in order, then triggers boss.
# Zero procedural generation. Zero random timers. No fallback loops.
# ──────────────────────────────────────────────────────────────────────────────

signal run_failed(coins_collected: int, distance_reached: float)

@export var debug_level_override: int = 0
@export var level_data: LevelData = preload("res://src/data/resources/levels/level_01.tres")
@export var spawn_z_ahead: float = -70.0
@export var settlement_screen_scene: PackedScene = preload("res://src/ui/settlement_screen.tscn")

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
@export var whirlpool_scene: PackedScene = preload("res://src/gameplay/obstacles/hazard_whirlpool.tscn")
@export var iron_gunner_scene: PackedScene = preload("res://src/gameplay/enemies/enemy_iron_gunner.tscn")
@export var brimstone_raft_scene: PackedScene = preload("res://src/gameplay/enemies/enemy_brimstone_raft.tscn")
@export var bombard_scene: PackedScene = preload("res://src/gameplay/enemies/enemy_mini_boss_bombard.tscn")

var current_distance: float = 0.0
var active_queue: Array = []
var river_width_world: float = 12.0
var base_scroll_speed: float = 6.5
var bank_strips: Array[Node3D] = []          # legacy – kept for potential future use
var riverbank_chunks: Array[Node3D] = []     # Layer 2 framing strips (new system)
var _horizon_backdrop: Node3D = null         # Layer 1 horizon quad
var is_boss_spawned: bool = false
var chunk_assembler: ChunkAssembler = null

func _ready() -> void:
	add_to_group("level_controller")
	_setup_boundary_walls()
	_ensure_chunk_assembler()
	
	if debug_level_override > 0:
		GameState.current_level = debug_level_override
	
	# Load level according to GameState
	var active_res = GameState.get_current_level_resource()
	if active_res:
		load_level_resource(active_res)

func _ensure_chunk_assembler() -> void:
	if not chunk_assembler:
		chunk_assembler = get_node_or_null("ChunkAssembler") as ChunkAssembler
		if not chunk_assembler:
			chunk_assembler = ChunkAssembler.new()
			chunk_assembler.name = "ChunkAssembler"
			add_child(chunk_assembler)
		if not chunk_assembler.boss_arena_reached.is_connected(_on_chunk_boss_arena_reached):
			chunk_assembler.boss_arena_reached.connect(_on_chunk_boss_arena_reached)

func _on_chunk_boss_arena_reached(boss_chunk: BaseTrackChunk) -> void:
	is_boss_spawned = true
	var boss = boss_chunk.find_child("*Boss*", true, false)
	if not boss:
		boss = get_tree().get_first_node_in_group("boss")
	var camera = get_tree().get_first_node_in_group("game_camera")
	if camera and camera.has_method("start_boss_focus") and boss:
		camera.start_boss_focus(boss)
	print("[LEVEL CONTROLLER] Locked camera to boss arena")

func handle_player_defeat(coins_collected: int, distance_reached: float) -> void:
	# 1. Freeze forward track scrolling smoothly
	var freeze_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	freeze_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	
	if chunk_assembler and is_instance_valid(chunk_assembler):
		freeze_tween.tween_property(chunk_assembler, "scroll_speed", 0.0, 0.5)
		
	var track_mgr = get_tree().get_first_node_in_group("track_manager")
	if track_mgr and is_instance_valid(track_mgr) and "scroll_speed" in track_mgr:
		freeze_tween.tween_property(track_mgr, "scroll_speed", 0.0, 0.5)
		
	base_scroll_speed = 0.0
	run_failed.emit(coins_collected, distance_reached)
	
	# 2. Wait for deceleration, then display Defeat Settlement Screen
	await get_tree().create_timer(0.45, true, false, true).timeout
	
	var settlement = get_tree().get_first_node_in_group("settlement_screen")
	if not settlement:
		var root = get_tree().current_scene
		if root and settlement_screen_scene:
			settlement = settlement_screen_scene.instantiate()
			settlement.add_to_group("settlement_screen")
			root.add_child(settlement)
			
	if settlement and settlement.has_method("show_defeat"):
		settlement.show_defeat(coins_collected, distance_reached, GameState.doubloons)

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
	elif not level_data.wave_events.is_empty():
		for we in level_data.wave_events:
			if we != null:
				active_queue.append(we)
		active_queue.sort_custom(func(a, b): return a.distance < b.distance)

func load_level_resource(res: LevelData) -> void:
	if not res:
		return
	level_data = res
	current_distance = 0.0
	is_boss_spawned = false
	river_width_world = level_data.river_width_world
	base_scroll_speed = level_data.base_scroll_speed
	GameState.distance_traveled = 0.0
	
	var hud = get_tree().get_first_node_in_group("top_hud")
	if hud and "level_title" in hud and hud.level_title:
		hud.level_title.text = level_data.level_title
		
	# If this level contains chunk_scenes, hand off to ChunkAssembler
	if not level_data.chunk_scenes.is_empty():
		var track_mgr = get_tree().get_first_node_in_group("track_manager")
		if track_mgr:
			track_mgr.visible = false
			track_mgr.set_physics_process(false)
			
		_ensure_chunk_assembler()
		chunk_assembler.assemble_level(level_data)
	else:
		GameState.level_distance_target = 250.0
		# Clear only dynamically spawned obstacles/mobs/hazards from previous level previews
		for child in get_children():
			if child is Node3D and (child.is_in_group("destructible") or child.is_in_group("hazards") or child.is_in_group("enemies") or child.is_in_group("collectibles") or child.is_in_group("multiplier_gate")):
				child.queue_free()
		setup_active_queue()
		
		var track_mgr = get_tree().get_first_node_in_group("track_manager")
		if track_mgr:
			track_mgr.visible = true
			track_mgr.set_physics_process(true)
			track_mgr.scroll_speed = base_scroll_speed
			if "current_level_data" in track_mgr:
				track_mgr.current_level_data["is_scripted"] = true
			if track_mgr.has_method("clear_all_segment_obstacles"):
				track_mgr.clear_all_segment_obstacles()
			
	if level_data:
		var biome_name: String = level_data.biome_name if "biome_name" in level_data else "tropical"
		_update_biome_music(biome_name)

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
				if ResourceLoader.exists(tex_path):
					htex = load(tex_path) as Texture2D
			if htex:
				_horizon_backdrop.bind_texture(htex)

		# ── Layer 2: Riverbank Framing Strips ────────────────────────────────
		_setup_riverbank_chunks(biome_name)

		# Configure Environment Visuals
		_apply_biome_visuals()

func _apply_biome_visuals() -> void:
	if not level_data:
		return
		
	var env = get_node_or_null("../WorldEnvironment") as WorldEnvironment
	if env and env.environment:
		env.environment.fog_enabled = level_data.fog_density > 0.0
		env.environment.fog_light_color = level_data.fog_color
		env.environment.fog_density = level_data.fog_density
		env.environment.fog_sky_affect = 0.45 if level_data.fog_density > 0.0 else 0.0
		
	if chunk_assembler:
		chunk_assembler.update_water_color(level_data.water_albedo)
		
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
		
	if chunk_assembler and chunk_assembler.is_assembled:
		# Modular chunk system handles track scrolling, entities, and progress.
		# Advance and wrap Layer-2 riverbank framing chunks
		var scroll_step = chunk_assembler.scroll_speed * delta if not chunk_assembler.is_boss_active else 0.0
		_scroll_riverbank_chunks(scroll_step)
		return
	# ──────────────────────────────────────────────────────────────────────────

	var track_mgr = get_tree().get_first_node_in_group("track_manager")
	var speed = base_scroll_speed
	if track_mgr and "scroll_speed" in track_mgr:
		speed = track_mgr.scroll_speed

	var max_dist = 250.0

	# ── Boss-Arena Trigger ───────────────────────────────────────────
	if not is_boss_spawned and current_distance >= max_dist:
		current_distance = max_dist       # Lock – no drift past cap
		base_scroll_speed = 0.0
		if track_mgr:
			track_mgr.scroll_speed = 0.0
		active_queue.clear()           # Ensure nothing fires after boss spawn
		_spawn_boss()
		return

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
				and not child.is_in_group("horizon_backdrop") \
				and not child.is_in_group("riverbank_chunk") \
				and not child.is_in_group("boundary_wall"):
			child.global_position.z += scroll_movement

	# Wrap bank strips (legacy – array is empty; kept as no-op for safety)
	for strip in bank_strips:
		if is_instance_valid(strip) and strip.global_position.z > 40.0:
			strip.global_position.z -= 160.0  # 4 tiles × 40m

	# Advance and wrap Layer-2 riverbank framing chunks with overlap guard
	_scroll_riverbank_chunks(scroll_movement)

func normalized_to_world_x(norm_x: float) -> float:
	return norm_x * (river_width_world / 2.0)

func _spawn_timeline_event(event: SpawnEvent, z_pos_override: float = 0.0) -> void:
	var target_z = spawn_z_ahead if z_pos_override == 0.0 else z_pos_override
	var z_spawn = minf(target_z, -45.0) # Ensure at least 45m distance from player vessel
	var is_brimstone: bool = level_data != null and (level_data.biome_name == "brimstone" or level_data.level_id == 3)
	
	match event.entity_type:
		SpawnEvent.EntityType.BARREL:
			var x_pos = clampf(event.lane_x, -5.2, 5.2)
			if barrel_scene:
				var barrel = barrel_scene.instantiate() as Area3D
				barrel.name = "Barrel_%.1fm_x%.1f" % [current_distance, x_pos]
				add_child(barrel)
				barrel.global_position = Vector3(x_pos, 0.05, z_spawn)
				var hp = event.base_hp_override if event.base_hp_override > 0 else (2 if event.rarity_tier == SpawnEvent.RarityTier.COMMON else (4 if event.rarity_tier == SpawnEvent.RarityTier.NORMAL else 6))
				barrel.hp = hp
				if "obstacle_type" in barrel:
					if event.rarity_tier == SpawnEvent.RarityTier.RARE:
						barrel.obstacle_type = DestructibleObstacle.ObstacleType.RUNE_BARREL
					elif event.rarity_tier == SpawnEvent.RarityTier.NORMAL:
						barrel.obstacle_type = DestructibleObstacle.ObstacleType.FUSE_BARREL
					else:
						barrel.obstacle_type = DestructibleObstacle.ObstacleType.WOODEN_BARREL

		SpawnEvent.EntityType.MOB:
			if is_brimstone:
				if event.rarity_tier == SpawnEvent.RarityTier.ELITE or event.base_hp_override >= 40:
					var x_pos = clampf(event.lane_x, -4.1, 4.1)
					if bombard_scene:
						var bombard = bombard_scene.instantiate() as Area3D
						bombard.name = "MiniBossBombard_%.1fm" % current_distance
						add_child(bombard)
						bombard.global_position = Vector3(x_pos, 0.1, z_spawn)
						bombard.max_hp = event.base_hp_override if event.base_hp_override > 0 else 120
						bombard.current_hp = bombard.max_hp
						bombard.forward_speed = 1.3
				elif event.rarity_tier == SpawnEvent.RarityTier.RARE or event.base_hp_override == 18:
					var x_pos = clampf(event.lane_x, -4.5, 4.5)
					if brimstone_raft_scene:
						var raft = brimstone_raft_scene.instantiate() as Area3D
						raft.name = "BrimstoneRaft_%.1fm_x%.1f" % [current_distance, x_pos]
						add_child(raft)
						raft.global_position = Vector3(x_pos, 0.1, z_spawn)
						raft.max_hp = event.base_hp_override if event.base_hp_override > 0 else 18
						raft.current_hp = raft.max_hp
						raft.forward_speed = 7.8
				else:
					var x_pos = clampf(event.lane_x, -4.5, 4.5)
					if iron_gunner_scene:
						var gunner = iron_gunner_scene.instantiate() as Area3D
						var label = "IronGunnerScout" if (event.base_hp_override > 0 and event.base_hp_override < 20) else "IronGunner"
						gunner.name = "%s_%.1fm_x%.1f" % [label, current_distance, x_pos]
						add_child(gunner)
						gunner.global_position = Vector3(x_pos, 0.1, z_spawn)
						gunner.max_hp = event.base_hp_override if event.base_hp_override > 0 else 22
						gunner.current_hp = gunner.max_hp
						gunner.forward_speed = 2.6
			else:
				if event.rarity_tier == SpawnEvent.RarityTier.ELITE or event.base_hp_override >= 40:
					var x_pos = clampf(event.lane_x, -4.1, 4.1)
					if harvester_scene:
						var harv = harvester_scene.instantiate() as Area3D
						harv.name = "MiniBossHarvester_%.1fm" % current_distance
						add_child(harv)
						harv.global_position = Vector3(x_pos, 0.1, z_spawn)
						harv.max_hp = event.base_hp_override if event.base_hp_override > 0 else 45
						harv.current_hp = harv.max_hp
				elif (event.rarity_tier == SpawnEvent.RarityTier.RARE and event.base_hp_override >= 8) or event.base_hp_override == 8:
					var x_pos = clampf(event.lane_x, -4.5, 4.5)
					if tide_cutter_scene:
						var cutter = tide_cutter_scene.instantiate() as Area3D
						cutter.name = "TideCutter_%.1fm_x%.1f" % [current_distance, x_pos]
						add_child(cutter)
						cutter.global_position = Vector3(x_pos, 0.1, z_spawn)
						cutter.max_hp = event.base_hp_override if event.base_hp_override > 0 else 8
						cutter.current_hp = cutter.max_hp
						cutter.forward_speed = 4.5
				else:
					var x_pos = clampf(event.lane_x, -4.2, 4.2)
					if grave_skiff_scene:
						var skiff = grave_skiff_scene.instantiate() as Area3D
						skiff.name = "GraveSkiff_%.1fm_x%.1f" % [current_distance, x_pos]
						add_child(skiff)
						skiff.global_position = Vector3(x_pos, 0.1, z_spawn)
						skiff.max_hp = event.base_hp_override if event.base_hp_override > 0 else (6 if event.rarity_tier == SpawnEvent.RarityTier.RARE else 4)
						skiff.current_hp = skiff.max_hp
						skiff.forward_speed = 2.4

		SpawnEvent.EntityType.MULTIPLIER_GATE:
			var x_pos = clampf(event.lane_x, -3.9, 3.9)
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

		SpawnEvent.EntityType.HAZARD:
			if is_brimstone:
				var x_pos = clampf(event.lane_x, -4.2, 4.2)
				if thermal_geyser_scene:
					var geyser = thermal_geyser_scene.instantiate() as Node3D
					geyser.name = "ThermalGeyser_%.1fm_x%.1f" % [current_distance, x_pos]
					add_child(geyser)
					geyser.global_position = Vector3(x_pos, 0.0, z_spawn)
			else:
				if event.rarity_tier == SpawnEvent.RarityTier.RARE or event.base_hp_override >= 5:
					var x_pos = clampf(event.lane_x, -4.5, 4.5)
					var reef_prefab = preload("res://src/gameplay/obstacles/hazard_reef.tscn")
					if reef_prefab:
						var reef = reef_prefab.instantiate() as Area3D
						reef.name = "CoralReef_%.1fm_x%.1f" % [current_distance, x_pos]
						add_child(reef)
						reef.global_position = Vector3(x_pos, 0.0, z_spawn)
				elif biogas_pod_scene:
					var x_pos = clampf(event.lane_x, -5.2, 5.2)
					var pod = biogas_pod_scene.instantiate() as Area3D
					pod.name = "BiogasPod_%.1fm_x%.1f" % [current_distance, x_pos]
					add_child(pod)
					pod.global_position = Vector3(x_pos, 0.05, z_spawn)
					pod.hp = event.base_hp_override if event.base_hp_override > 0 else 1

		SpawnEvent.EntityType.BOSS:
			print("[SPAWN BOSS TRIGGER] Triggering Boss at dist=%.1fm" % current_distance)
			_spawn_boss()

# ──────────────────────────────────────────────────────────────────────────────
# EVENT SPAWNER – purely data-driven, no randomness
# ──────────────────────────────────────────────────────────────────────────────
func _spawn_wave_event(event: Dictionary, z_pos_override: float = 0.0) -> void:
	var target_z = spawn_z_ahead if z_pos_override == 0.0 else z_pos_override
	var z_spawn = minf(target_z, -45.0) # Ensure at least 45m distance from player vessel
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
				var x_world = clampf(normalized_to_world_x(x_norm), -5.2, 5.2)
				var z_offset = -abs(sin(t * PI)) * 2.0
				var z_pos    = z_spawn + z_offset - (i * 1.2)
				if coin_scene:
					var coin = coin_scene.instantiate() as Area3D
					add_child(coin)
					coin.global_position = Vector3(x_world, 0.13, z_pos)

		# ── Barrel row ────────────────────────────────────────────────────────
		"obstacles":
			var x_positions: Array = event.get("x_positions", [])
			var hp           = int(event.get("hp", 1))
			var obs_type_str: String = event.get("obstacle_type", "wooden")
			for x_norm in x_positions:
				var x_world = clampf(normalized_to_world_x(float(x_norm)), -5.2, 5.2)
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
			var hp      = int(event.get("hp", 1))
			var x_world = clampf(normalized_to_world_x(x_norm), -5.2, 5.2)
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
				var x_world = clampf(normalized_to_world_x(x_norm), -3.9, 3.9)
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
			var x_world = clampf(normalized_to_world_x(x_norm), -5.2, 5.2)
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
				var x_world = clampf(normalized_to_world_x(float(x_norm)), -4.6, 4.6)
				if grave_skiff_scene:
					var skiff = grave_skiff_scene.instantiate() as Area3D
					add_child(skiff)
					skiff.global_position = Vector3(x_world, 0.1, z_spawn)
					skiff.max_hp = hp
					skiff.current_hp = hp
					skiff.forward_speed = speed_val

		# ── Ghost Sloops (Level 2) ────────────────────────────────────────────
		"ghost_sloops":
			var x_positions: Array = event.get("x_positions", [0.0])
			var hp = int(event.get("hp", 8))
			var speed_val = float(event.get("speed", 2.4))
			for x_norm in x_positions:
				var x_world = clampf(normalized_to_world_x(float(x_norm)), -4.6, 4.6)
				if enemy_mob_scene:
					var mob = enemy_mob_scene.instantiate() as Area3D
					add_child(mob)
					mob.global_position = Vector3(x_world, 0.1, z_spawn)
					var sloop_data = preload("res://src/data/resources/enemy_vessels/ghost_sloop.tres")
					if mob.has_method("apply_enemy_data") and sloop_data:
						mob.apply_enemy_data(sloop_data)
					mob.max_hp = hp
					mob.current_hp = hp
					mob.forward_speed = speed_val

		# ── Tide Cutters (Level 2) ────────────────────────────────────────────
		"tide_cutters":
			var x_positions: Array = event.get("x_positions", [0.0])
			var hp = int(event.get("hp", 20))
			var speed_val = float(event.get("speed", 6.8))
			for x_norm in x_positions:
				var x_world = clampf(normalized_to_world_x(float(x_norm)), -4.6, 4.6)
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
			var x_world = clampf(normalized_to_world_x(x_norm), -4.1, 4.1)
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
			var x_world = clampf(normalized_to_world_x(x_norm), -4.2, 4.2)
			if thermal_geyser_scene:
				var geyser = thermal_geyser_scene.instantiate() as Node3D
				add_child(geyser)
				geyser.global_position = Vector3(x_world, 0.0, z_spawn)

		# ── Whirlpool Hazard ──────────────────────────────────────────────────
		"whirlpool":
			var x_norm = float(event.get("x", 0.0))
			var x_world = clampf(normalized_to_world_x(x_norm), -4.2, 4.2)
			if whirlpool_scene:
				var pool = whirlpool_scene.instantiate() as Area3D
				add_child(pool)
				pool.global_position = Vector3(x_world, 0.0, z_spawn)


		# ── Iron Gunners (Level 3) ────────────────────────────────────────────
		"iron_gunners":
			var x_positions: Array = event.get("x_positions", [0.0])
			var hp = int(event.get("hp", 22))
			var speed_val = float(event.get("speed", 2.6))
			for x_norm in x_positions:
				var x_world = clampf(normalized_to_world_x(float(x_norm)), -4.6, 4.6)
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
				var x_world = clampf(normalized_to_world_x(float(x_norm)), -4.6, 4.6)
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
			var x_world = clampf(normalized_to_world_x(x_norm), -4.1, 4.1)
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
			var hp = int(event.get("hp", 2))
			var mob_speed = float(event.get("speed", 2.0))
			for x_norm in x_positions:
				var x_world = clampf(normalized_to_world_x(float(x_norm)), -4.6, 4.6)
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
			var hp = int(event.get("hp", 4))
			var skiff_speed = float(event.get("speed", 3.0))
			for x_norm in x_positions:
				var x_world = clampf(normalized_to_world_x(float(x_norm)), -4.2, 4.2)
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
			var hp = int(event.get("hp", 5))
			var raft_speed = float(event.get("speed", 7.0))
			for x_norm in x_positions:
				var x_world = clampf(normalized_to_world_x(float(x_norm)), -4.2, 4.2)
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
			var x_world = clampf(normalized_to_world_x(x_norm), -5.2, 5.2)
			if sea_mine_scene:
				var mine = sea_mine_scene.instantiate() as Node3D
				add_child(mine)
				mine.global_position = Vector3(x_world, 0.0, z_spawn)

		# ── Reef hazard ───────────────────────────────────────────────────────
		"reef_hazard":
			var x_norm   = float(event.get("x", 0.0))
			var scale_x  = clampf(float(event.get("scale_x", 1.2)), 0.6, 2.5)
			var scale_z  = clampf(float(event.get("scale_z", 1.0)), 0.8, 1.5)
			var half_w   = 1.2 * scale_x
			var x_world  = clampf(normalized_to_world_x(x_norm), -5.8 + half_w, 5.8 - half_w)
			var reef_prefab = preload("res://src/gameplay/obstacles/hazard_reef.tscn")
			if reef_prefab:
				var reef = reef_prefab.instantiate() as Area3D
				add_child(reef)
				reef.global_position = Vector3(x_world, 0.0, z_spawn)
				reef.scale = Vector3(scale_x, 1.0, scale_z)


		# ── Armored Turtle Rafts ───────────────────────────────────────────────
		"turtle_rafts":
			var x_positions: Array = event.get("x_positions", [0.0])
			var hp         = int(event.get("hp", 6))
			var cur_lvl = GameState.current_level if has_node("/root/GameState") else 1
			if cur_lvl <= 1 and hp > 6:
				hp = 6
			var raft_speed = float(event.get("speed", 1.8))
			for x_norm in x_positions:
				var x_world = clampf(normalized_to_world_x(float(x_norm)), -4.4, 4.4)
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
				var x_world = clampf(normalized_to_world_x(float(x_norm)), -5.2, 5.2)
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
				var x_world = clampf(normalized_to_world_x(float(x_norm)), -4.2, 4.2)
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
		if level_data and "boss_hp" in level_data and level_data.boss_hp > 0:
			if "max_hp" in boss:
				boss.max_hp = level_data.boss_hp
				boss.current_hp = level_data.boss_hp
			if boss is BossSiegeFortress:
				var scale_factor: float = float(level_data.boss_hp) / 800.0
				boss.hp_port_turret = int(round(150.0 * scale_factor))
				boss.hp_starboard_turret = int(round(150.0 * scale_factor))
				boss.hp_prow_ram = int(round(150.0 * scale_factor))
				boss.hp_furnace_core = level_data.boss_hp - (boss.hp_port_turret + boss.hp_starboard_turret + boss.hp_prow_ram)
		var main_root = get_tree().current_scene
		if main_root:
			main_root.add_child(boss)
		else:
			add_child(boss)
		boss.global_position = Vector3(0.0, 0.0, player_z - 18.0)
		print("[BOSS] Spawned boss for ", level_data.level_title if level_data else "Level", " with HP: ", str(level_data.boss_hp) if (level_data and "boss_hp" in level_data) else "default")

		# Lock camera to boss arena
		var camera = get_tree().get_first_node_in_group("game_camera")
		if camera and camera.has_method("start_boss_focus"):
			camera.start_boss_focus(boss)

## Constructs invisible StaticBody3D physical collision walls bounding the navigable corridor at X = +/- 6.0
func _setup_boundary_walls() -> void:
	if get_node_or_null("BoundaryWall_Left") and get_node_or_null("BoundaryWall_Right"):
		return
		
	# Left invisible collision wall: center at X = -6.5, width 1.0 -> inner face at X = -6.0
	var left_wall := StaticBody3D.new()
	left_wall.name = "BoundaryWall_Left"
	left_wall.add_to_group("boundary_wall")
	left_wall.add_to_group("scenery_barrier")
	left_wall.position = Vector3(-6.5, 0.5, 0.0)
	var left_col := CollisionShape3D.new()
	var box_shape_l := BoxShape3D.new()
	box_shape_l.size = Vector3(1.0, 10.0, 500.0)
	left_col.shape = box_shape_l
	left_wall.add_child(left_col)
	add_child(left_wall)
	
	# Right invisible collision wall: center at X = +6.5, width 1.0 -> inner face at X = +6.0
	var right_wall := StaticBody3D.new()
	right_wall.name = "BoundaryWall_Right"
	right_wall.add_to_group("boundary_wall")
	right_wall.add_to_group("scenery_barrier")
	right_wall.position = Vector3(6.5, 0.5, 0.0)
	var right_col := CollisionShape3D.new()
	var box_shape_r := BoxShape3D.new()
	box_shape_r.size = Vector3(1.0, 10.0, 500.0)
	right_col.shape = box_shape_r
	right_wall.add_child(right_col)
	add_child(right_wall)

func _update_biome_music(biome_name: String) -> void:
	if not AudioManager:
		return
	var music_track = "music_tropical"
	match biome_name.to_lower():
		"bayou":
			music_track = "music_bayou"
		"brimstone":
			music_track = "music_brimstone"
		_:
			music_track = "music_tropical"
			
	if AudioManager.has_method("crossfade_music"):
		AudioManager.crossfade_music(music_track, 1.0)
	elif AudioManager.has_method("play_music"):
		AudioManager.play_music(music_track)

# ── Riverbank Chunk Overlap Guard & Recycling System ─────────────────────────

func _setup_riverbank_chunks(biome_name: String) -> void:
	var valid_chunks = riverbank_chunks.filter(func(c): return is_instance_valid(c))
	var left_chunks: Array[Node3D] = []
	var right_chunks: Array[Node3D] = []
	for chunk in valid_chunks:
		if "side" in chunk and chunk.side == "right":
			right_chunks.append(chunk)
		else:
			left_chunks.append(chunk)

	# If 8 valid chunks already exist (4 left, 4 right), cleanly reset positions and re-seed biome
	if left_chunks.size() == 4 and right_chunks.size() == 4:
		print("[RIVERBANK CHUNKS] Reusing pool of 8 chunks (4 left, 4 right). Offsets reset to [20, -20, -60, -100]m for biome %s" % biome_name)
		for i in range(4):
			left_chunks[i].global_position = Vector3(0.0, 0.0, 20.0 - i * 40.0)
			left_chunks[i].setup("left", 40.0, biome_name)
			right_chunks[i].global_position = Vector3(0.0, 0.0, 20.0 - i * 40.0)
			right_chunks[i].setup("right", 40.0, biome_name)
		return

	# Otherwise, clear and eliminate any duplicate or orphaned chunks in tree
	var purged = 0
	for child in get_children():
		if child.is_in_group("riverbank_chunk"):
			child.queue_free()
			purged += 1
	riverbank_chunks.clear()
	if purged > 0:
		print("[RIVERBANK CHUNKS] Purged %d duplicate/orphaned riverbank chunks from scene tree" % purged)

	var props_scene := preload("res://src/gameplay/levels/riverbank_props.tscn")
	if props_scene:
		for prop_side in ["left", "right"]:
			for i in range(4):
				var chunk := props_scene.instantiate()
				chunk.name = "RiverbankChunk_%s_%d" % [prop_side.capitalize(), i]
				add_child(chunk)
				chunk.global_position = Vector3(0.0, 0.0, 20.0 - i * 40.0)
				if chunk.has_method("setup"):
					chunk.setup(prop_side, 40.0, biome_name)
				riverbank_chunks.append(chunk)
		print("[RIVERBANK CHUNKS] Instantiated fresh pool of 8 chunks (4 left, 4 right) with 0 initial overlaps.")

func _scroll_riverbank_chunks(delta_z: float) -> void:
	if delta_z <= 0.0 or riverbank_chunks.is_empty():
		return

	var left_chunks: Array[Node3D] = []
	var right_chunks: Array[Node3D] = []
	for chunk in riverbank_chunks:
		if is_instance_valid(chunk):
			if "side" in chunk and chunk.side == "right":
				right_chunks.append(chunk)
			else:
				left_chunks.append(chunk)

	_advance_and_wrap_side(left_chunks, delta_z)
	_advance_and_wrap_side(right_chunks, delta_z)

## Advances chunks and executes a strict Overlap Guard upon wrapping:
## Wrapped chunks are guaranteed to reposition strictly behind the rearmost chunk,
## completely eliminating double instances and co-planar Z-offsets.
func _advance_and_wrap_side(chunks: Array[Node3D], delta_z: float) -> void:
	for chunk in chunks:
		chunk.global_position.z += delta_z

	var wrapping: Array[Node3D] = []
	for chunk in chunks:
		if chunk.global_position.z > 40.0:
			wrapping.append(chunk)

	if wrapping.is_empty():
		return

	# Sort furthest forward first
	wrapping.sort_custom(func(a, b): return a.global_position.z > b.global_position.z)

	for chunk in wrapping:
		var c_len: float = chunk.chunk_length if "chunk_length" in chunk else 40.0
		# Find the rearmost position among active chunks on this side
		var min_z := INF
		for other in chunks:
			if other != chunk and not wrapping.has(other):
				if other.global_position.z < min_z:
					min_z = other.global_position.z

		if is_finite(min_z):
			chunk.global_position.z = min_z - c_len
		else:
			chunk.global_position.z -= c_len * float(chunks.size())
		wrapping.erase(chunk)

# ── Diagnostic In-Game Monitor ───────────────────────────────────────────────

func run_blinking_diagnostic() -> Dictionary:
	var node_count := get_tree().get_node_count()
	var positions: Dictionary = {}
	var dupes: int = 0
	var meshes: Array[MeshInstance3D] = []
	for group in ["scenery", "riverbank_chunk"]:
		for parent in get_tree().get_nodes_in_group(group):
			if parent is Node:
				_collect_diagnostic_meshes(parent, meshes)
				
	for mesh in meshes:
		if is_instance_valid(mesh) and mesh.is_inside_tree() and mesh.is_visible_in_tree():
			if "water" in mesh.name.to_lower() or "backdrop" in mesh.name.to_lower():
				continue
			var key = "%0.1f_%0.1f" % [mesh.global_position.x, mesh.global_position.z]
			if positions.has(key):
				print("[DUPLICATE DETECTED] Two meshes at same spot: %s - '%s' vs '%s'" % [key, mesh.name, positions[key]])
				dupes += 1
			positions[key] = mesh.name
			
	print("[DIAGNOSTIC MONITOR] Total Active Nodes: %d | Scenery Meshes: %d | Duplicates: %d" % [node_count, positions.size(), dupes])
	return {
		"node_count": node_count,
		"mesh_count": positions.size(),
		"duplicate_count": dupes
	}

func _collect_diagnostic_meshes(n: Node, out: Array[MeshInstance3D]) -> void:
	if n is MeshInstance3D:
		out.append(n)
	for child in n.get_children():
		_collect_diagnostic_meshes(child, out)
