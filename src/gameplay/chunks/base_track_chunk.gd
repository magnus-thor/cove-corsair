class_name BaseTrackChunk
extends Node3D

## Base contract for all modular runner track chunks in Cove Corsair.
## Chunks represent 50m length slices of banks, obstacles, spawners, gates, and markers.
## Chunks intentionally do NOT contain water geometry (water is rendered as a persistent plane under the camera).

const CHUNK_LENGTH: float = 50.0
const MIN_NAVIGABLE_CLEARANCE: float = 6.8
const DEFAULT_COLORMAP_PATH: String = "res://assets/models/Textures/colormap.png"

const BOMBARD_OR_OBSTACLE_LEVELS: Array[int] = [
	4, 6, 8, 12, 14, 16, 18, 20, 24, 26, 28, 32, 34, 36, 37, 38, 40, 42, 43, 44
]

signal chunk_activated(chunk: BaseTrackChunk)
@warning_ignore("unused_signal")
signal chunk_completed(chunk: BaseTrackChunk)

@export var chunk_id: String = ""
@export var biome_id: String = ""
@export var is_boss_chunk: bool = false
@export var is_active: bool = false
@export var boss_scene: PackedScene

var chunk_start: Marker3D = null
var chunk_end: Marker3D = null
var scenery_anchors: Node3D = null
var scenery_container: Node3D = null

## Resolves the active biome ("tropical", "bayou", or "brimstone") for this chunk from biome_id, GameState LevelData, or level number.
func resolve_chunk_biome(cur_lvl: int = -1) -> String:
	var b_override: String = biome_id.strip_edges().to_lower()
	if b_override == "tropical" or b_override == "bayou" or b_override == "brimstone":
		return b_override
	var gs: Node = get_node_or_null("/root/GameState")
	if cur_lvl <= 0:
		if gs and "current_level" in gs:
			cur_lvl = int(gs.get("current_level"))
		else:
			cur_lvl = 1
	if gs and gs.has_method("get_current_level_resource"):
		var res: LevelData = gs.call("get_current_level_resource") as LevelData
		if res and res.level_id == cur_lvl and not res.biome_name.is_empty():
			var b_res: String = res.biome_name.strip_edges().to_lower()
			if "brimstone" in b_res:
				return "brimstone"
			if "bayou" in b_res:
				return "bayou"
			return "tropical"
	if cur_lvl >= 31:
		return "brimstone"
	if cur_lvl >= 16:
		return "bayou"
	return "tropical"

## Returns true if the level favors the Bombard Skiff or is a Hazard Navigation / Obstacle Gauntlet level.
func is_bombard_or_obstacle_level(cur_lvl: int = -1) -> bool:
	var gs: Node = get_node_or_null("/root/GameState")
	if cur_lvl <= 0:
		if gs and "current_level" in gs:
			cur_lvl = int(gs.get("current_level"))
		else:
			cur_lvl = 1
	if cur_lvl in BOMBARD_OR_OBSTACLE_LEVELS:
		return true
	if gs and "LEVEL_SHIPS" in gs:
		var ships_dict: Dictionary = gs.get("LEVEL_SHIPS") as Dictionary
		if ships_dict.has(cur_lvl) and "bombard_skiff" in str(ships_dict[cur_lvl]):
			return true
	if gs and gs.has_method("get_current_level_resource"):
		var res: LevelData = gs.call("get_current_level_resource") as LevelData
		if res and res.level_id == cur_lvl and "hazard" in res.level_title.to_lower():
			return true
	return false

## Static material cache keyed by "<biome>|<tex_key>|<col_key>|<wind>" to share ShaderMaterial instances
## across all Kenney meshes (sharing colormap.png) and Meshy models (each sharing its baked diffuse map).
static var _material_cache: Dictionary[String, ShaderMaterial] = {}
static var _default_colormap: Texture2D = null

func _ready() -> void:
	add_to_group("track_chunks")
	_ensure_markers()
	_ensure_scenery_anchors()
	_apply_base_chunk_pacing()
	
	# Keep entities dormant until entering camera frustum
	if not is_active:
		_set_entities_dormant(true)

var _base_pacing_applied: bool = false

func _apply_base_chunk_pacing() -> void:
	if _base_pacing_applied:
		return
	_base_pacing_applied = true
	var entities: Node = get_node_or_null("Entities")
	if not entities:
		return
	var cur_lvl: int = 1
	var gs: Node = get_node_or_null("/root/GameState")
	if gs and "current_level" in gs:
		cur_lvl = int(gs.get("current_level"))
	var active_biome: String = resolve_chunk_biome(cur_lvl)

	# 1. Opener chunks: keep first 42m gentle (barrels + first gate), then spawn first light enemy wave at Z = -43.5 to -48.0
	if chunk_id in ["warmup", "opener_slalom", "opener_ambush", "opener_gauntlet"]:
		var tail_spawns: Array[Vector3] = [
			Vector3(-2.2, 0.1, -43.5),
			Vector3(2.2, 0.1, -44.5),
			Vector3(0.0, 0.1, -47.5),
		]
		var intro_hp: int = 1 if cur_lvl <= 1 else (2 if cur_lvl <= 4 else 3)
		var intro_spd: float = 1.6 if cur_lvl <= 2 else 2.2
		var intro_data_path: String = "res://src/data/resources/enemy_vessels/skeleton_rower.tres"
		if active_biome == "bayou" or active_biome == "brimstone":
			intro_data_path = "res://src/data/resources/enemy_vessels/ghost_sloop.tres"
		var intro_data: Resource = load(intro_data_path)
		var mob_scene: PackedScene = load("res://src/gameplay/enemies/enemy_mob.tscn") as PackedScene
		for i: int in range(tail_spawns.size()):
			if mob_scene:
				var mob: Area3D = mob_scene.instantiate() as Area3D
				if mob:
					mob.name = "OpenerTailWave_%d" % (i + 1)
					entities.add_child(mob)
					mob.position = tail_spawns[i]
					if mob.has_method("apply_enemy_data") and intro_data:
						mob.call("apply_enemy_data", intro_data)
					mob.set("max_hp", intro_hp)
					mob.set("current_hp", intro_hp)
					mob.set("forward_speed", intro_spd)
					mob.set("doubloons_drop", 0)
		return

	# 2. Mine Gauntlet chunk: either dense obstacles (for Bombard Skiff / Hazard Nav levels) or continuous enemy waves (standard levels)
	if chunk_id == "mine_gauntlet":
		if is_bombard_or_obstacle_level(cur_lvl):
			# Bombard Skiff / Obstacle-Heavy level: pack extra obstacles between mine gates (Z = -6, -18, -30, -41)
			var obs_positions: Array[Vector3] = [
				Vector3(1.8, 0.05, -6.5),
				Vector3(-2.2, 0.05, -18.0),
				Vector3(2.2, 0.05, -18.0),
				Vector3(-1.8, 0.05, -30.0),
				Vector3(1.8, 0.05, -30.0),
				Vector3(-2.6, 0.05, -41.5),
				Vector3(2.6, 0.05, -41.5),
			]
			var biogas_scene: PackedScene = load("res://src/gameplay/obstacles/hazard_biogas_pod.tscn") as PackedScene
			var geyser_scene: PackedScene = load("res://src/gameplay/obstacles/hazard_thermal_geyser.tscn") as PackedScene
			var mine_scene: PackedScene = load("res://src/gameplay/obstacles/hazard_sea_mine.tscn") as PackedScene
			var barrel_scene: PackedScene = load("res://src/gameplay/obstacles/destructible_barrel.tscn") as PackedScene
			for idx: int in range(obs_positions.size()):
				var opos: Vector3 = obs_positions[idx]
				if active_biome == "bayou" and idx % 2 == 1 and biogas_scene:
					var pod: Node3D = biogas_scene.instantiate() as Node3D
					if pod:
						pod.name = "BombardHazardPod_%d" % (idx + 1)
						entities.add_child(pod)
						pod.position = opos
				elif active_biome == "brimstone" and idx % 2 == 1 and geyser_scene:
					var geyser: Node3D = geyser_scene.instantiate() as Node3D
					if geyser:
						geyser.name = "BombardHazardGeyser_%d" % (idx + 1)
						entities.add_child(geyser)
						geyser.position = Vector3(opos.x, 0.0, opos.z)
				elif idx % 3 == 0 and mine_scene:
					var mine: Node3D = mine_scene.instantiate() as Node3D
					if mine:
						mine.name = "BombardExtraMine_%d" % (idx + 1)
						entities.add_child(mine)
						mine.position = Vector3(opos.x, 0.0, opos.z)
				elif barrel_scene:
					var keg: Area3D = barrel_scene.instantiate() as Area3D
					if keg:
						keg.name = "BombardFuseKeg_%d" % (idx + 1)
						entities.add_child(keg)
						keg.position = opos
						keg.set("obstacle_type", 1)
						keg.set("hp", 2)
						keg.set("doubloons_drop", 0)
		else:
			# Standard level: continuous enemy waves through the mine gauntlet from Z = -4.5 to -44.0 (zero downtime!)
			var wave_coords: Array[Vector3] = [
				Vector3(1.6, 0.1, -4.5),
				Vector3(3.0, 0.1, -6.5),
				Vector3(-2.4, 0.1, -9.0),
				Vector3(1.8, 0.1, -16.5),
				Vector3(-1.8, 0.1, -18.5),
				Vector3(0.0, 0.1, -21.0),
				Vector3(-2.8, 0.1, -29.0),
				Vector3(2.8, 0.1, -31.0),
				Vector3(-1.6, 0.1, -33.5),
				Vector3(1.8, 0.1, -40.5),
				Vector3(-2.2, 0.1, -43.0),
				Vector3(2.2, 0.1, -44.5),
			]
			var mob_hp: int = 2 if cur_lvl <= 3 else (3 if cur_lvl <= 5 else (5 if cur_lvl <= 10 else 7))
			var mob_spd: float = 2.0 if cur_lvl <= 3 else 2.8
			var g_skiff_scene: PackedScene = load("res://src/gameplay/enemies/enemy_grave_skiff.tscn") as PackedScene
			var b_raft_scene: PackedScene = load("res://src/gameplay/enemies/enemy_brimstone_raft.tscn") as PackedScene
			var mob_scene: PackedScene = load("res://src/gameplay/enemies/enemy_mob.tscn") as PackedScene
			var rower_res: Resource = load("res://src/data/resources/enemy_vessels/skeleton_rower.tres")
			var raider_res: Resource = load("res://src/data/resources/enemy_vessels/raider_skiff.tres")
			var ghost_res: Resource = load("res://src/data/resources/enemy_vessels/ghost_sloop.tres")
			var ironclad_res: Resource = load("res://src/data/resources/enemy_vessels/enemy_elite_ironclad.tres")
			for w_idx: int in range(wave_coords.size()):
				var w_pos: Vector3 = wave_coords[w_idx]
				if active_biome == "bayou" and w_idx % 3 == 1 and g_skiff_scene:
					var g_skiff: Area3D = g_skiff_scene.instantiate() as Area3D
					if g_skiff:
						g_skiff.name = "GauntletWaveSkiff_%d" % (w_idx + 1)
						entities.add_child(g_skiff)
						g_skiff.position = w_pos
						g_skiff.set("max_hp", mob_hp + 2)
						g_skiff.set("current_hp", mob_hp + 2)
						g_skiff.set("forward_speed", mob_spd)
						g_skiff.set("doubloons_drop", 0)
					continue
				elif active_biome == "brimstone" and w_idx % 3 == 1 and b_raft_scene:
					var b_raft: Area3D = b_raft_scene.instantiate() as Area3D
					if b_raft:
						b_raft.name = "GauntletWaveRaft_%d" % (w_idx + 1)
						entities.add_child(b_raft)
						b_raft.position = w_pos
						b_raft.set("max_hp", mob_hp + 2)
						b_raft.set("current_hp", mob_hp + 2)
						b_raft.set("forward_speed", mob_spd + 1.0)
						b_raft.set("doubloons_drop", 0)
					continue
				if mob_scene:
					var mob: Area3D = mob_scene.instantiate() as Area3D
					if mob:
						mob.name = "GauntletWaveMob_%d" % (w_idx + 1)
						entities.add_child(mob)
						mob.position = w_pos
						var v_res: Resource = rower_res if (w_idx % 2 == 0 or cur_lvl <= 3) else raider_res
						if active_biome == "bayou":
							v_res = ghost_res
						elif active_biome == "brimstone":
							v_res = ironclad_res if w_idx % 4 == 0 else ghost_res
						if mob.has_method("apply_enemy_data") and v_res:
							mob.call("apply_enemy_data", v_res)
						mob.set("max_hp", mob_hp)
						mob.set("current_hp", mob_hp)
						mob.set("forward_speed", mob_spd)
						mob.set("doubloons_drop", 0)

func _ensure_markers() -> void:
	chunk_start = get_node_or_null("ChunkStart") as Marker3D
	if not chunk_start:
		chunk_start = Marker3D.new()
		chunk_start.name = "ChunkStart"
		add_child(chunk_start)
		chunk_start.position = Vector3(0.0, 0.0, 0.0)
		
	chunk_end = get_node_or_null("ChunkEnd") as Marker3D
	if not chunk_end:
		chunk_end = Marker3D.new()
		chunk_end.name = "ChunkEnd"
		add_child(chunk_end)
		chunk_end.position = Vector3(0.0, 0.0, -CHUNK_LENGTH)

## Ensures standardized depth-sorted SceneryAnchors and a dedicated Scenery container node exist.
func _ensure_scenery_anchors() -> void:
	scenery_container = get_node_or_null("Scenery") as Node3D
	if not scenery_container:
		scenery_container = Node3D.new()
		scenery_container.name = "Scenery"
		scenery_container.add_to_group("scenery")
		add_child(scenery_container)

	scenery_anchors = get_node_or_null("SceneryAnchors") as Node3D
	if scenery_anchors:
		return

	scenery_anchors = Node3D.new()
	scenery_anchors.name = "SceneryAnchors"
	add_child(scenery_anchors)

	# 1. Left & Right Shoreline Near Slots (|X| in [6.8m, 11.0m], 10 slots per side spanning 50m)
	var near_z_slots: Array[float] = [-2.5, -7.5, -12.5, -17.5, -22.5, -27.5, -32.5, -37.5, -42.5, -47.5]
	for idx: int in range(near_z_slots.size()):
		var z_val: float = near_z_slots[idx]
		var left_near := Marker3D.new()
		left_near.name = "Near_Left_%d" % idx
		left_near.position = Vector3(-8.0, 0.0, z_val)
		left_near.set_meta("depth_tier", "near")
		left_near.set_meta("side", -1.0)
		scenery_anchors.add_child(left_near)

		var right_near := Marker3D.new()
		right_near.name = "Near_Right_%d" % idx
		right_near.position = Vector3(8.0, 0.0, z_val)
		right_near.set_meta("depth_tier", "near")
		right_near.set_meta("side", 1.0)
		scenery_anchors.add_child(right_near)

	# 2. Left & Right Midground Slots (|X| in [11.0m, 26.0m], 7 slots per side spanning 50m)
	var mid_z_slots: Array[float] = [-4.0, -11.0, -18.0, -25.0, -32.0, -39.0, -46.0]
	for idx: int in range(mid_z_slots.size()):
		var z_val: float = mid_z_slots[idx]
		var left_mid := Marker3D.new()
		left_mid.name = "Mid_Left_%d" % idx
		left_mid.position = Vector3(-15.5, 0.0, z_val)
		left_mid.set_meta("depth_tier", "mid")
		left_mid.set_meta("side", -1.0)
		scenery_anchors.add_child(left_mid)

		var right_mid := Marker3D.new()
		right_mid.name = "Mid_Right_%d" % idx
		right_mid.position = Vector3(15.5, 0.0, z_val)
		right_mid.set_meta("depth_tier", "mid")
		right_mid.set_meta("side", 1.0)
		scenery_anchors.add_child(right_mid)

	# 3. Distant Backdrop Slots (|X| in [26.0m, 60.0m], 4 slots per side spanning 50m)
	var far_z_slots: Array[float] = [-6.0, -18.5, -31.5, -44.0]
	for idx: int in range(far_z_slots.size()):
		var z_val: float = far_z_slots[idx]
		var left_far := Marker3D.new()
		left_far.name = "Far_Left_%d" % idx
		left_far.position = Vector3(-34.0, 0.0, z_val)
		left_far.set_meta("depth_tier", "far")
		left_far.set_meta("side", -1.0)
		scenery_anchors.add_child(left_far)

		var right_far := Marker3D.new()
		right_far.name = "Far_Right_%d" % idx
		right_far.position = Vector3(34.0, 0.0, z_val)
		right_far.set_meta("depth_tier", "far")
		right_far.set_meta("side", 1.0)
		scenery_anchors.add_child(right_far)

func _set_entities_dormant(dormant: bool) -> void:
	for container_name: String in ["Spawners", "Entities", "Obstacles", "Enemies", "Coins", "Gates"]:
		var node: Node = get_node_or_null(container_name)
		if node:
			node.process_mode = Node.PROCESS_MODE_DISABLED if dormant else Node.PROCESS_MODE_INHERIT

## Spawner hook: activates all coins, obstacles, gates, and enemy formations when entering camera range
func activate_spawners() -> void:
	if is_active:
		return
	is_active = true
	_set_entities_dormant(false)
	
	# Execute spawner callbacks on any spawner nodes
	for child: Node in find_children("*", "", true, false):
		if child != self:
			if child.has_method("spawn"):
				child.call("spawn")
			elif child.has_method("activate"):
				child.call("activate")
				
	_on_spawners_activated()
	chunk_activated.emit(self)

	# ── Engagement telemetry ─────────────────────────────────────────────────
	if EventBus and EventBus.has_signal("chunk_activated"):
		var c_id: String = chunk_id if not chunk_id.is_empty() else scene_file_path.get_file().get_basename()
		var river_dist: float = GameState.distance_traveled if GameState else 0.0
		EventBus.chunk_activated.emit(c_id, river_dist)

## Virtual method for custom chunk behaviors upon activation
func _on_spawners_activated() -> void:
	if is_boss_chunk and boss_scene:
		var existing: Node = get_tree().get_first_node_in_group("boss")
		if not existing or existing.is_queued_for_deletion():
			var boss := boss_scene.instantiate() as Node3D
			if boss:
				add_child(boss)
				boss.position = Vector3(0.0, 0.0, -60.0)
				var camera: Node = get_tree().get_first_node_in_group("game_camera")
				if camera and camera.has_method("start_boss_focus"):
					camera.call("start_boss_focus", boss)

func get_start_z() -> float:
	if chunk_start:
		return chunk_start.global_position.z
	return global_position.z

func get_end_z() -> float:
	if chunk_end:
		return chunk_end.global_position.z
	return global_position.z - CHUNK_LENGTH

func get_chunk_length() -> float:
	if chunk_end:
		return absf(chunk_end.position.z)
	return CHUNK_LENGTH

## Checks whether the entire chunk (including its end at Z = -50 relative to origin)
## has moved past the cleanup threshold behind the camera.
func is_past_camera(cleanup_z: float = 30.0) -> bool:
	return get_end_z() > cleanup_z

## Deterministic dynamic population of biome-themed scenery across Near, Midground, and Far Backdrop pools.
func populate_scenery(theme: ThemeSceneryData, chunk_seed: int, is_narrow_section: bool = false) -> void:
	if theme == null:
		theme = ThemeSceneryData.get_theme_for_biome("tropical")
	theme.ensure_populated()

	_ensure_scenery_anchors()

	# Clear any previously spawned dynamic scenery in this chunk to prevent leaks or duplicates
	if scenery_container:
		for child: Node in scenery_container.get_children():
			scenery_container.remove_child(child)
			child.queue_free()

	# Clear legacy hardcoded static Banks props so side-lane scenery is driven cleanly by the biome theme
	var cleared_banks_count: int = 0
	var static_banks: Node3D = get_node_or_null("Banks") as Node3D
	if static_banks:
		for child: Node in static_banks.get_children():
			cleared_banks_count += 1
			static_banks.remove_child(child)
			child.queue_free()
		static_banks.visible = false

	# Retrofit any static FinishArch, FinishGate, or landmark structures inside Entities with the harmonized shader
	var harmonized_mesh_count: int = 0
	var entities_node: Node3D = get_node_or_null("Entities") as Node3D
	if entities_node:
		for ent_child: Node in entities_node.get_children():
			var ent_name: String = ent_child.name.to_lower()
			if ent_child.is_in_group("finish_landmark") or "finish" in ent_name or "gatecenter" in ent_name or "tower" in ent_name or "arch" in ent_name or "spire" in ent_name or "willow" in ent_name or "mournwood" in ent_name or "totem" in ent_name or "crown" in ent_name or "obsidian" in ent_name or "dock" in ent_name or "wall" in ent_name:
				var use_wind: bool = "willow" in ent_name or "mournwood" in ent_name or "tree" in ent_name or "palm" in ent_name
				harmonized_mesh_count += _apply_harmonized_materials_and_optimizations(ent_child, theme, use_wind, 140.0)

	var rng := RandomNumberGenerator.new()
	rng.seed = chunk_seed

	var narrow_offset: float = rng.randf_range(0.0, 0.5) if is_narrow_section else rng.randf_range(0.6, 1.8)
	var spawned_near: int = 0
	var spawned_mid: int = 0
	var spawned_far: int = 0

	for anchor_node: Node in scenery_anchors.get_children():
		if not (anchor_node is Marker3D):
			continue
		var marker: Marker3D = anchor_node as Marker3D
		var tier: String = str(marker.get_meta("depth_tier", "near"))
		var side_sign: float = float(marker.get_meta("side", -1.0 if marker.position.x < 0.0 else 1.0))

		var pool: Array[PackedScene] = theme.near_lane_props
		var min_x: float = 6.9
		var max_x: float = 10.6
		var vis_end: float = 90.0
		var spawn_chance: float = 0.92

		if tier == "mid":
			pool = theme.midground_props
			min_x = 11.5
			max_x = 24.0
			vis_end = 90.0
			spawn_chance = 0.90
		elif tier == "far":
			pool = theme.far_backdrop_props
			min_x = 27.0
			max_x = 52.0
			vis_end = 180.0
			spawn_chance = 0.88

		if pool.is_empty() or rng.randf() > spawn_chance:
			continue

		var prop_scene: PackedScene = pool[rng.randi() % pool.size()]
		if prop_scene == null:
			continue

		var prop_inst: Node3D = prop_scene.instantiate() as Node3D
		if not prop_inst:
			continue

		var prop_path: String = prop_scene.resource_path.get_file().get_basename().to_lower()
		prop_inst.name = "%s_%s" % [tier.capitalize(), prop_path]
		scenery_container.add_child(prop_inst)

		# Calculate randomized X & Z coordinates within tier boundaries
		var rand_x: float = rng.randf_range(min_x, max_x)
		if tier == "near":
			rand_x = clampf(rand_x + narrow_offset * 0.4, 6.8, 11.0)
			spawned_near += 1
		elif tier == "mid":
			rand_x = clampf(rand_x + narrow_offset, 11.0, 26.0)
			spawned_mid += 1
		else:
			rand_x = clampf(rand_x, 26.0, 60.0)
			spawned_far += 1

		var rand_z: float = clampf(marker.position.z + rng.randf_range(-1.8, 1.8), -CHUNK_LENGTH + 1.2, -1.2)
		var base_scale: float = _compute_tier_scale(prop_path, tier, rng)
		prop_inst.scale = Vector3.ONE * base_scale

		var is_architectural: bool = _is_architectural_prop(prop_path)
		var is_foliage: bool = _is_foliage_prop(prop_path)
		var is_custom_meshy: bool = "scenery/" in prop_scene.resource_path.to_lower()

		# Y-offset grounding adjustment for custom Meshy origin centers vs Kenney bottom-pivot models
		var y_pos: float = 0.04
		if is_custom_meshy:
			y_pos = _get_meshy_ground_offset(prop_path, base_scale)
		prop_inst.position = Vector3(side_sign * rand_x, y_pos, rand_z)

		# Rotation randomization:
		# Architectural pieces get subtle yaw jitter; natural assets get full 360° yaw and slight pitch/roll
		if is_architectural:
			var arch_base_yaw: float = (PI * 0.5 if side_sign < 0.0 else -PI * 0.5)
			prop_inst.rotation.y = wrapf(arch_base_yaw + rng.randf_range(-0.2, 0.2), 0.0, TAU)
			prop_inst.rotation.x = 0.0
			prop_inst.rotation.z = 0.0
		else:
			prop_inst.rotation.y = rng.randf_range(0.0, TAU)
			prop_inst.rotation.x = rng.randf_range(-0.05, 0.05)
			prop_inst.rotation.z = rng.randf_range(-0.05, 0.05)

		# Apply Harmonized Scenery Shader & mobile draw-call optimizations
		harmonized_mesh_count += _apply_harmonized_materials_and_optimizations(prop_inst, theme, is_foliage, vis_end)

		# Strictly enforce navigable corridor clearance (|X| >= 6.8m)
		_enforce_prop_clearance(prop_inst, side_sign < 0.0, MIN_NAVIGABLE_CLEARANCE)

	var total_spawned: int = spawned_near + spawned_mid + spawned_far
	var c_label: String = chunk_id if not chunk_id.is_empty() else name
	print("[ScenerySpawner] Chunk='%s' (seed=%d) | Theme='%s' (pools: near=%d, mid=%d, far=%d) | Cleared %d static Banks props | Spawned %d props (near=%d, mid=%d, far=%d) | Harmonized %d meshes" % [
		c_label,
		chunk_seed,
		theme.theme_name,
		theme.near_lane_props.size(),
		theme.midground_props.size(),
		theme.far_backdrop_props.size(),
		cleared_banks_count,
		total_spawned,
		spawned_near,
		spawned_mid,
		spawned_far,
		harmonized_mesh_count
	])

## Computes distance-appropriate scale with uniform jitter (0.85 - 1.25x baseline)
## while scaling down oversized Kenney boulders in the near lane and scaling up far horizon vistas.
func _compute_tier_scale(prop_name: String, tier: String, rng: RandomNumberGenerator) -> float:
	var jitter: float = rng.randf_range(0.85, 1.25)
	if tier == "near":
		if "rocks-sand" in prop_name or "patch-" in prop_name:
			return jitter * 0.42
		elif "rocks-" in prop_name:
			return jitter * 0.48
		return jitter * 1.05
	elif tier == "mid":
		if "willow" in prop_name or "mournwood" in prop_name or "mangrove" in prop_name or "coconut" in prop_name or "spire" in prop_name or "thorn" in prop_name:
			return jitter * 1.45
		elif "rocks-" in prop_name:
			return jitter * 1.15
		return jitter * 1.20
	else:
		# Far backdrop silhouettes (|X| in 26m..60m) need grand silhouette scale
		if "island" in prop_name or "spire" in prop_name or "willow" in prop_name or "mournwood" in prop_name:
			return jitter * 2.65
		elif "tower" in prop_name or "crystal" in prop_name:
			return jitter * 2.10
		return jitter * 1.75

## Legacy compatibility wrapper: delegates to populate_scenery with resolved biome ThemeSceneryData.
func apply_scenery_variation(level_seed: int, is_narrow_section: bool = false) -> void:
	var resolved_theme: ThemeSceneryData = null
	var assembler: ChunkAssembler = get_parent() as ChunkAssembler
	if assembler and assembler.active_level_data:
		resolved_theme = assembler.active_level_data.get_effective_theme()
	if resolved_theme == null:
		resolved_theme = ThemeSceneryData.get_theme_for_biome("tropical")
	populate_scenery(resolved_theme, level_seed, is_narrow_section)

func _is_architectural_prop(prop_name: String) -> bool:
	for keyword: String in ["dock", "wall", "fence", "platform", "tower", "castle", "cannon", "totem"]:
		if keyword in prop_name:
			return true
	return false

func _is_foliage_prop(prop_name: String) -> bool:
	for keyword: String in ["palm", "tree", "willow", "mournwood", "mangrove", "cattail", "hibiscus", "grass", "foliage", "bush"]:
		if keyword in prop_name:
			return true
	return false

func _get_meshy_ground_offset(prop_name: String, scale_val: float) -> float:
	if "drift" in prop_name:
		return 0.18 * scale_val
	elif "crown" in prop_name or "anchor" in prop_name:
		return 0.40 * scale_val
	elif "mangrove" in prop_name or "hibiscus" in prop_name:
		return 0.50 * scale_val
	elif "island" in prop_name or "cattail" in prop_name or "willow" in prop_name or "mournwood" in prop_name:
		return 0.68 * scale_val
	return 0.82 * scale_val

## Recursively traverses child MeshInstance3D nodes to assign cached ShaderMaterial instances
## while preserving per-surface textures and albedo colors, and configures shadow culling & visibility range.
func _apply_harmonized_materials_and_optimizations(root_node: Node, theme: ThemeSceneryData, enable_wind: bool, vis_range_end: float) -> int:
	var count: int = 0
	if root_node is MeshInstance3D:
		var mi: MeshInstance3D = root_node as MeshInstance3D
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.extra_cull_margin = 0.0
		mi.visibility_range_end = vis_range_end
		mi.visibility_range_end_margin = 10.0
		mi.lod_bias = 0.5

		if mi.mesh != null:
			var surf_count: int = mi.mesh.get_surface_count()
			if surf_count <= 1:
				var tex: Texture2D = _extract_surface_texture(mi, 0)
				var col: Color = _extract_surface_color(mi, 0)
				var harmonized_mat: ShaderMaterial = _get_or_create_harmonized_material(theme, tex, col, enable_wind)
				if harmonized_mat != null:
					mi.material_override = harmonized_mat
					count += 1
			else:
				mi.material_override = null
				for s_idx: int in range(surf_count):
					var s_tex: Texture2D = _extract_surface_texture(mi, s_idx)
					var s_col: Color = _extract_surface_color(mi, s_idx)
					var s_mat: ShaderMaterial = _get_or_create_harmonized_material(theme, s_tex, s_col, enable_wind)
					if s_mat != null:
						mi.set_surface_override_material(s_idx, s_mat)
				count += 1
	elif root_node is GeometryInstance3D:
		var gi: GeometryInstance3D = root_node as GeometryInstance3D
		gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		gi.visibility_range_end = vis_range_end
		gi.visibility_range_end_margin = 10.0

	for child: Node in root_node.get_children():
		count += _apply_harmonized_materials_and_optimizations(child, theme, enable_wind, vis_range_end)
	return count

func _get_original_surface_material(mi: MeshInstance3D, surf_idx: int) -> Material:
	if mi.material_override != null:
		return mi.material_override
	if surf_idx < mi.get_surface_override_material_count():
		var over_mat: Material = mi.get_surface_override_material(surf_idx)
		if over_mat != null:
			return over_mat
	if mi.mesh != null and surf_idx < mi.mesh.get_surface_count():
		var mesh_mat: Material = mi.mesh.surface_get_material(surf_idx)
		if mesh_mat != null:
			return mesh_mat
	return null

func _extract_surface_texture(mi: MeshInstance3D, surf_idx: int) -> Texture2D:
	var orig_mat: Material = _get_original_surface_material(mi, surf_idx)
	if orig_mat is BaseMaterial3D:
		var bm: BaseMaterial3D = orig_mat as BaseMaterial3D
		if bm.albedo_texture != null:
			return bm.albedo_texture
		# If BaseMaterial3D exists and has a non-white flat albedo_color without texture, do NOT overwrite with colormap.png
		if bm.albedo_color != Color.WHITE:
			return null
	elif orig_mat is ShaderMaterial:
		var sm: ShaderMaterial = orig_mat as ShaderMaterial
		var param_tex: Variant = sm.get_shader_parameter("albedo_texture")
		if param_tex is Texture2D:
			return param_tex as Texture2D

	# Fallback to Kenney pirate kit colormap.png for untextured Kenney meshes
	if _default_colormap == null and ResourceLoader.exists(DEFAULT_COLORMAP_PATH):
		_default_colormap = load(DEFAULT_COLORMAP_PATH) as Texture2D
	return _default_colormap

func _extract_surface_color(mi: MeshInstance3D, surf_idx: int) -> Color:
	var orig_mat: Material = _get_original_surface_material(mi, surf_idx)
	if orig_mat is BaseMaterial3D:
		return (orig_mat as BaseMaterial3D).albedo_color
	elif orig_mat is ShaderMaterial:
		var sm: ShaderMaterial = orig_mat as ShaderMaterial
		var param_col: Variant = sm.get_shader_parameter("albedo_tint")
		if param_col is Color:
			return param_col as Color
	return Color.WHITE

func _get_or_create_harmonized_material(theme: ThemeSceneryData, source_tex: Texture2D, surface_color: Color, enable_wind: bool) -> ShaderMaterial:
	var shader: Shader = theme.scenery_shader
	if shader == null:
		shader = preload("res://src/shaders/harmonized_scenery.gdshader")
	if shader == null:
		return null

	var tex_key: String = "none"
	if source_tex != null:
		tex_key = source_tex.resource_path if not source_tex.resource_path.is_empty() else str(source_tex.get_rid().get_id())

	var col_key: String = surface_color.to_html(false)
	var cache_key: String = "%s|%s|%s|%s" % [theme.theme_name, tex_key, col_key, "wind" if enable_wind else "static"]
	if _material_cache.has(cache_key) and is_instance_valid(_material_cache[cache_key]):
		var cached_mat: ShaderMaterial = _material_cache[cache_key]
		cached_mat.set_shader_parameter("fog_color", theme.fog_color)
		return cached_mat

	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("use_albedo_texture", source_tex != null)
	if source_tex != null:
		mat.set_shader_parameter("albedo_texture", source_tex)

	# Biome tint & cel-shadow ambient fill harmonization
	var biome_tint := Color(1.0, 1.0, 1.0, 1.0)
	var shadow_col := Color(0.35, 0.42, 0.58, 1.0)
	var b_lower: String = theme.theme_name.to_lower()
	if "bayou" in b_lower:
		biome_tint = Color(0.84, 0.94, 0.82, 1.0)
		shadow_col = Color(0.20, 0.34, 0.28, 1.0)
	elif "brimstone" in b_lower:
		biome_tint = Color(0.94, 0.80, 0.78, 1.0)
		shadow_col = Color(0.36, 0.18, 0.22, 1.0)

	var combined_tint := Color(
		surface_color.r * biome_tint.r,
		surface_color.g * biome_tint.g,
		surface_color.b * biome_tint.b,
		1.0
	)

	mat.set_shader_parameter("albedo_tint", combined_tint)
	mat.set_shader_parameter("shadow_tint", Vector3(shadow_col.r, shadow_col.g, shadow_col.b))
	mat.set_shader_parameter("roughness_override", 0.85)
	mat.set_shader_parameter("enable_wind", enable_wind)
	mat.set_shader_parameter("wind_speed", 2.2)
	mat.set_shader_parameter("wind_strength", 0.18)
	mat.set_shader_parameter("fog_color", theme.fog_color)
	mat.set_shader_parameter("fog_start", 55.0)
	mat.set_shader_parameter("fog_end", 160.0)

	_material_cache[cache_key] = mat
	return mat

func _collect_prop_meshes(node: Node, out_meshes: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		out_meshes.append(node as MeshInstance3D)
	for child: Node in node.get_children():
		_collect_prop_meshes(child, out_meshes)

func _get_transform_relative_to_chunk(node: Node3D) -> Transform3D:
	var xform := Transform3D.IDENTITY
	var curr: Node = node
	while curr and curr != self and curr is Node3D:
		xform = (curr as Node3D).transform * xform
		curr = curr.get_parent()
	return xform

## Ensures spawned prop AABB vertices strictly respect minimum navigable clearance (|X| >= 6.8m).
func _enforce_prop_clearance(prop: Node3D, is_left_bank: bool, min_clearance: float = 6.8) -> void:
	if not prop:
		return
	var meshes: Array[MeshInstance3D] = []
	_collect_prop_meshes(prop, meshes)
	if meshes.is_empty():
		if absf(prop.position.x) < min_clearance:
			prop.position.x = (-min_clearance if is_left_bank else min_clearance)
		return

	var min_x: float = INF
	var max_x: float = -INF
	for mi: MeshInstance3D in meshes:
		if not mi.mesh:
			continue
		var aabb: AABB = mi.mesh.get_aabb()
		var rel_xform: Transform3D = _get_transform_relative_to_chunk(mi)
		for i: int in range(8):
			var corner := aabb.position + Vector3(
				aabb.size.x if (i & 1) != 0 else 0.0,
				aabb.size.y if (i & 2) != 0 else 0.0,
				aabb.size.z if (i & 4) != 0 else 0.0
			)
			var pt: Vector3 = rel_xform * corner
			min_x = minf(min_x, pt.x)
			max_x = maxf(max_x, pt.x)

	if min_x == INF or max_x == -INF:
		return

	if is_left_bank:
		if max_x > -min_clearance:
			var overshoot: float = max_x - (-min_clearance)
			prop.position.x -= (overshoot + 0.1)
	else:
		if min_x < min_clearance:
			var undershoot: float = min_clearance - min_x
			prop.position.x += (undershoot + 0.1)
