class_name ChunkAssembler
extends Node3D

## Modular Chunk Assembler Manager for Cove Corsair.
## Constructs runner levels dynamically from recipe sequences of 50m track chunks.
## Replaces monolithic level tracks with dynamic end-to-end chunk layout,
## camera frustum spawner activation, persistent water management,
## and memory cleanup (+30m behind camera) for mobile performance.

signal level_assembled(total_distance: float)
signal boss_arena_reached(boss_chunk: BaseTrackChunk)

@export var active_level_data: LevelData
@export var scroll_speed: float = 7.0
@export var cleanup_distance_behind_camera: float = 30.0
@export var camera_activation_distance: float = 55.0

const BOSS_BUFFER_CHUNK_SCENE: PackedScene = preload("res://src/gameplay/chunks/chunk_boss_intro_buffer.tscn")
const TROPICAL_SAND_BANK_MAT: StandardMaterial3D = preload("res://assets/materials/mat_sand_stylized.tres")
const BAYOU_MUD_BANK_MAT: StandardMaterial3D = preload("res://assets/materials/mat_bayou_mud_stylized.tres")
const BRIMSTONE_ASH_BANK_MAT: StandardMaterial3D = preload("res://assets/materials/mat_brimstone_ash_stylized.tres")

var active_chunks: Array[BaseTrackChunk] = []
var total_track_distance: float = 0.0
var distance_traveled: float = 0.0
var is_boss_active: bool = false
var is_assembled: bool = false
var _persistent_water: MeshInstance3D = null
var _persistent_bank_left: MeshInstance3D = null
var _persistent_bank_right: MeshInstance3D = null
var _bank_mat: StandardMaterial3D = null

func _get_game_state() -> Node:
	return get_node_or_null("/root/GameState")

func _ready() -> void:
	add_to_group("chunk_assembler")
	_setup_persistent_water()
	
	if active_level_data:
		assemble_level(active_level_data)

## Sets up a persistent river water surface plane beneath the camera constrained strictly
## to the river corridor (width 12.0m: X in [-6.0m, +6.0m]), along with solid bank
## ground planes extending outward to eliminate water outside the lane.
func _setup_persistent_water() -> void:
	var existing: Node = get_tree().get_first_node_in_group("persistent_water")
	if existing and existing is MeshInstance3D:
		_persistent_water = existing as MeshInstance3D
		if _persistent_water.mesh is PlaneMesh:
			(_persistent_water.mesh as PlaneMesh).size = Vector2(13.2, 320.0)
	else:
		var water_mesh := MeshInstance3D.new()
		water_mesh.name = "PersistentWaterPlane"
		water_mesh.add_to_group("persistent_water")
		
		# River lane water: 13.2m width covers wide channel from -6.6m to +6.6m
		var plane := PlaneMesh.new()
		plane.size = Vector2(13.2, 320.0)
		water_mesh.mesh = plane
		water_mesh.position = Vector3(0.0, 0.0, -100.0)
		
		var shader: Shader = preload("res://src/shaders/water_stylized.gdshader")
		if shader:
			var mat := ShaderMaterial.new()
			mat.shader = shader
			mat.set_shader_parameter("albedo", Color(0.08, 0.58, 0.82, 0.88))
			mat.set_shader_parameter("roughness", 0.05)
			mat.set_shader_parameter("refraction_strength", 0.04)
			mat.set_shader_parameter("flow_speed", Vector2(0.0, -0.6))
			
			var noise := FastNoiseLite.new()
			noise.noise_type = FastNoiseLite.TYPE_CELLULAR
			noise.frequency = 0.04
			var noise_tex := NoiseTexture2D.new()
			noise_tex.seamless = true
			noise_tex.as_normal_map = true
			noise_tex.noise = noise
			
			mat.set_shader_parameter("texture_normal", noise_tex)
			mat.set_shader_parameter("texture_refraction", noise_tex)
			water_mesh.material_override = mat
			
		add_child(water_mesh)
		_persistent_water = water_mesh

	# Setup persistent bank ground underlays outside the wide river corridor
	# Stylized textured sand/earth material at Y = 0.02m starting at |X| = 6.0m
	if TROPICAL_SAND_BANK_MAT != null:
		_bank_mat = TROPICAL_SAND_BANK_MAT.duplicate() as StandardMaterial3D
	else:
		_bank_mat = StandardMaterial3D.new()
		_bank_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		_bank_mat.roughness = 0.85
		_bank_mat.albedo_color = Color(0.85, 0.72, 0.48) # Warm sand/shoreline tone
	_bank_mat.cull_mode = BaseMaterial3D.CULL_BACK
	
	for b_side: float in [-1.0, 1.0]:
		var bank_name: String = "PersistentBank_%s" % ("Left" if b_side < 0.0 else "Right")
		var existing_bank: Node = get_tree().get_first_node_in_group("persistent_bank_%s" % ("left" if b_side < 0.0 else "right"))
		var bank_mesh: MeshInstance3D = null
		if existing_bank and existing_bank is MeshInstance3D:
			bank_mesh = existing_bank as MeshInstance3D
		else:
			bank_mesh = MeshInstance3D.new()
			bank_mesh.name = bank_name
			bank_mesh.add_to_group("persistent_bank")
			bank_mesh.add_to_group("persistent_bank_%s" % ("left" if b_side < 0.0 else "right"))
			add_child(bank_mesh)
			
		var bank_plane := PlaneMesh.new()
		# 94m wide plane spanning from |X| = 6.0m to 100.0m
		bank_plane.size = Vector2(94.0, 320.0)
		bank_mesh.mesh = bank_plane
		# Elevated to Y = 0.02m (above water Y = 0.0m) to seal shorelines and hide any water under mountains
		bank_mesh.position = Vector3(b_side * 53.0, 0.02, -100.0)
		bank_mesh.material_override = _bank_mat
		if b_side < 0.0:
			_persistent_bank_left = bank_mesh
		else:
			_persistent_bank_right = bank_mesh

func update_water_color(color: Color) -> void:
	if _persistent_water and _persistent_water.material_override:
		var mat := _persistent_water.material_override as ShaderMaterial
		if mat:
			mat.set_shader_parameter("albedo", color)

	if _bank_mat:
		if active_level_data:
			var effective_theme: ThemeSceneryData = active_level_data.get_effective_theme()
			if effective_theme:
				if effective_theme.bank_material is StandardMaterial3D:
					_apply_bank_material_from_source(effective_theme.bank_material as StandardMaterial3D)
				else:
					_apply_flat_bank_color(effective_theme.bank_color)
				return

		var b_name: String = "tropical"
		if active_level_data:
			if "biome_name" in active_level_data and str(active_level_data.get("biome_name")) != "":
				b_name = str(active_level_data.get("biome_name"))
			elif "biome" in active_level_data and str(active_level_data.get("biome")) != "":
				b_name = str(active_level_data.get("biome"))
				
		match b_name.to_lower():
			"bayou", "black_tide_bayou":
				if BAYOU_MUD_BANK_MAT != null:
					_apply_bank_material_from_source(BAYOU_MUD_BANK_MAT)
				else:
					_apply_flat_bank_color(Color(0.28, 0.35, 0.25)) # Mossy swamp bank
			"brimstone", "brimstone_bastion":
				if BRIMSTONE_ASH_BANK_MAT != null:
					_apply_bank_material_from_source(BRIMSTONE_ASH_BANK_MAT)
				else:
					_apply_flat_bank_color(Color(0.22, 0.20, 0.22)) # Volcanic basalt bank
			_:
				if TROPICAL_SAND_BANK_MAT != null:
					_apply_bank_material_from_source(TROPICAL_SAND_BANK_MAT)
				else:
					_apply_flat_bank_color(Color(0.85, 0.72, 0.48)) # Tropical sand bank

func _apply_bank_material_from_source(src_mat: StandardMaterial3D) -> void:
	if not _bank_mat or not src_mat:
		return
	_bank_mat.albedo_color = src_mat.albedo_color
	_bank_mat.albedo_texture = src_mat.albedo_texture
	_bank_mat.roughness = src_mat.roughness
	_bank_mat.roughness_texture = src_mat.roughness_texture
	_bank_mat.normal_enabled = src_mat.normal_enabled
	_bank_mat.normal_scale = src_mat.normal_scale
	_bank_mat.normal_texture = src_mat.normal_texture
	_bank_mat.uv1_scale = src_mat.uv1_scale

func _apply_flat_bank_color(flat_color: Color) -> void:
	if not _bank_mat:
		return
	_bank_mat.albedo_color = flat_color
	_bank_mat.albedo_texture = null
	_bank_mat.roughness = 0.95
	_bank_mat.roughness_texture = null
	_bank_mat.normal_enabled = false
	_bank_mat.normal_texture = null

## Assembles the level dynamically from chunk_scenes in LevelData.
func assemble_level(data: LevelData = null) -> void:
	if data == null:
		var initial_gs: Node = _get_game_state()
		if initial_gs and initial_gs.has_method("get_current_level_resource"):
			data = initial_gs.call("get_current_level_resource") as LevelData
		
	if not data:
		push_warning("ChunkAssembler: No LevelData provided to assemble.")
		return
		
	active_level_data = data
	scroll_speed = active_level_data.base_scroll_speed
	distance_traveled = 0.0
	is_boss_active = false

	var active_theme: ThemeSceneryData = active_level_data.get_effective_theme()
	update_water_color(active_level_data.water_albedo)
	print("[ChunkAssembler] Assembling Level %d ('%s') | Biome='%s' | Resolved Theme='%s' (near=%d, mid=%d, far=%d)" % [
		active_level_data.level_id,
		active_level_data.level_title,
		active_level_data.biome_name,
		active_theme.theme_name if active_theme else "null",
		active_theme.near_lane_props.size() if active_theme else 0,
		active_theme.midground_props.size() if active_theme else 0,
		active_theme.far_backdrop_props.size() if active_theme else 0
	])
	
	# Clear any previous chunks cleanly
	for chunk: BaseTrackChunk in active_chunks:
		if is_instance_valid(chunk):
			if chunk.get_parent() == self:
				remove_child(chunk)
			chunk.queue_free()
	active_chunks.clear()
	
	# Instantiation Loop:
	# Iterate through chunk_scenes, placing each at current_z_offset
	var current_z_offset: float = 0.0
	for scene: PackedScene in active_level_data.chunk_scenes:
		if scene == null:
			continue
			
		var chunk_instance := scene.instantiate() as BaseTrackChunk
		if not chunk_instance:
			continue
			
		# If transitioning into a boss chunk, ensure buffer chunk and gate suppression
		if chunk_instance.is_boss_chunk:
			if not active_chunks.is_empty():
				var prev_chunk: BaseTrackChunk = active_chunks.back() as BaseTrackChunk
				_suppress_gates_in_chunk_final_portion(prev_chunk, 0.30)
				
				# Insert empty transition/buffer chunk if preceding chunk is not already a buffer
				if prev_chunk.chunk_id != "boss_intro_buffer" and BOSS_BUFFER_CHUNK_SCENE:
					var buffer_instance := BOSS_BUFFER_CHUNK_SCENE.instantiate() as BaseTrackChunk
					if buffer_instance:
						var buf_seed: int = (active_level_data.level_id * 7919) + (active_chunks.size() * 313) + 42
						add_child(buffer_instance)
						buffer_instance.position = Vector3(0.0, 0.0, current_z_offset)
						buffer_instance.populate_scenery(active_theme, buf_seed, false)
						current_z_offset -= buffer_instance.CHUNK_LENGTH
						active_chunks.append(buffer_instance)
			
		# Set position before add_child so _ready() sees the chunk's true world Z offset
		var chunk_idx: int = active_chunks.size()
		var level_seed: int = (active_level_data.level_id * 7919) + (chunk_idx * 313) + 42
		var is_narrow: bool = ((active_level_data.level_id + chunk_idx) % 3 == 0)
		chunk_instance.biome_id = active_level_data.biome_name
		chunk_instance.position = Vector3(0.0, 0.0, current_z_offset)
		add_child(chunk_instance)
		chunk_instance.populate_scenery(active_theme, level_seed, is_narrow)
		var c_len: float = chunk_instance.CHUNK_LENGTH
		current_z_offset -= c_len
		active_chunks.append(chunk_instance)

		# Enforce safe settle-in clearance runway (>= 50.0m in Chunk 0, plus >= 12.0m into Chunk 1 = 62m total, well beyond 38m bullet range)
		if active_chunks.size() == 1:
			_enforce_start_clearance_in_chunk(chunk_instance, 50.0)
		elif active_chunks.size() == 2 and not chunk_instance.is_boss_chunk:
			_enforce_start_clearance_in_chunk(chunk_instance, 12.0)
		
	# Calculate total track distance (distance until boss arena is reached)
	total_track_distance = 0.0
	for chunk: BaseTrackChunk in active_chunks:
		if not chunk.is_boss_chunk:
			total_track_distance += chunk.CHUNK_LENGTH
			
	if total_track_distance <= 0.0:
		total_track_distance = maxf(50.0, float(active_chunks.size()) * 50.0)
		
	var gs: Node = _get_game_state()
	if gs:
		gs.set("level_distance_target", total_track_distance)
		gs.set("distance_traveled", 0.0)
		if gs.has_signal("progress_changed"):
			gs.emit_signal("progress_changed", 0.0, total_track_distance)
	
	# Activate the first chunk immediately if it is at Z = 0
	if not active_chunks.is_empty():
		active_chunks[0].activate_spawners()
		
	is_assembled = true
	level_assembled.emit(total_track_distance)

func _physics_process(delta: float) -> void:
	var gs: Node = _get_game_state()
	var is_active: bool = (gs.get("is_game_active") == true) if (gs and "is_game_active" in gs) else false
	if not gs or not is_active or not is_assembled or is_boss_active:
		return
		
	var movement: float = scroll_speed * delta
	
	# 1. Scroll all active chunks forward along +Z
	for chunk: BaseTrackChunk in active_chunks:
		if is_instance_valid(chunk):
			chunk.global_position.z += movement
			
	# 2. Accumulate player forward distance
	distance_traveled += movement
	if gs.has_method("update_distance"):
		gs.call("update_distance", movement)
	
	# 3. Spawner Activation: trigger chunks entering camera range
	for chunk: BaseTrackChunk in active_chunks:
		if is_instance_valid(chunk) and not chunk.is_active:
			if chunk.get_start_z() >= -camera_activation_distance:
				chunk.activate_spawners()
				
	# 4. Boss Arena Transition Check:
	# Check if the boss chunk has reached the arena engagement point
	for chunk: BaseTrackChunk in active_chunks:
		if is_instance_valid(chunk) and chunk.is_boss_chunk:
			if chunk.get_start_z() >= -60.0 or distance_traveled >= total_track_distance:
				_on_boss_arena_reached(chunk)
				break
				
	# 5. Memory / Pool Cleanup:
	# Chunks past the camera frustum (+30m behind) call queue_free()
	var to_remove: Array[BaseTrackChunk] = []
	for chunk: BaseTrackChunk in active_chunks:
		if is_instance_valid(chunk) and not chunk.is_boss_chunk:
			if chunk.is_past_camera(cleanup_distance_behind_camera):
				to_remove.append(chunk)
				
	for chunk: BaseTrackChunk in to_remove:
		active_chunks.erase(chunk)
		if is_instance_valid(chunk):
			if chunk.get_parent() == self:
				remove_child(chunk)
			chunk.queue_free()

func _on_boss_arena_reached(boss_chunk: BaseTrackChunk) -> void:
	if is_boss_active:
		return
	is_boss_active = true
	scroll_speed = 0.0
	
	var gs: Node = _get_game_state()
	if gs:
		gs.set("boss_spawned", true)
		EventBus.distance_target_reached.emit()
		
		# Lock player progress to completion distance
		distance_traveled = total_track_distance
		gs.set("distance_traveled", total_track_distance)
		if gs.has_signal("progress_changed"):
			gs.emit_signal("progress_changed", total_track_distance, total_track_distance)
	
	# Trigger boss engagement hook inside boss chunk
	if not boss_chunk.is_active:
		boss_chunk.activate_spawners()

	var boss: Node = boss_chunk.find_child("*Boss*", true, false)
	if not boss:
		boss = get_tree().get_first_node_in_group("boss")
	if boss and is_instance_valid(boss):
		if boss.has_method("activate_arena"):
			boss.call("activate_arena")
		
	boss_arena_reached.emit(boss_chunk)

## Suppresses multiplier gates occurring in the final portion (e.g. 30%) of a chunk.
func _suppress_gates_in_chunk_final_portion(chunk: BaseTrackChunk, portion: float = 0.30) -> void:
	if not chunk or not is_instance_valid(chunk):
		return
	var threshold_z: float = -chunk.CHUNK_LENGTH * (1.0 - portion) # e.g. -35.0m for 50m chunk
	for child: Node in chunk.find_children("*", "", true, false):
		if not is_instance_valid(child):
			continue
		if (child.is_in_group("multiplier_gate") or (child is Area3D and child.has_method("apply_multiplier"))) and child is Node3D:
			# Check Z relative to chunk origin
			var rel_z: float = (child as Node3D).position.z
			if rel_z <= threshold_z:
				if child.get_parent():
					child.get_parent().remove_child(child)
				child.queue_free()

## Enforces a safe clearance runway at the start of a level so no hazards, mines, or hostile vessels appear closer than the bullet range (>= 42.0m).
func _enforce_start_clearance_in_chunk(chunk: BaseTrackChunk, min_clearance: float = 42.0) -> void:
	if not chunk or not is_instance_valid(chunk):
		return
	var entities: Node = chunk.find_child("Entities", true, false)
	if not entities:
		return
	var to_remove: Array[Node] = []
	for child: Node in entities.get_children():
		if not is_instance_valid(child) or not (child is Node3D):
			continue
		var n_lower: String = child.name.to_lower()
		# Exclude practice wooden barrels (non-explosive) and multiplier gates from removal so player can settle in, practice shooting, and recruit followers
		var is_explosive_keg: bool = n_lower.contains("keg") or n_lower.contains("explosive") or (child is DestructibleObstacle and (child as DestructibleObstacle).obstacle_type == DestructibleObstacle.ObstacleType.FUSE_BARREL)
		if not is_explosive_keg and (child is DestructibleBarrel or child.is_in_group("multiplier_gate") or n_lower.contains("barrel") or n_lower.contains("gate")):
			continue
		var is_hazard: bool = child.is_in_group("hazards") or child.is_in_group("sea_mine") or child.is_in_group("barricade") or child is HazardSeaMine or child is HazardThermalGeyser or child is HazardBiogasPod or child is HazardWhirlpool or child is BarricadeWall or n_lower.contains("mine") or n_lower.contains("reef") or n_lower.contains("barricade") or n_lower.contains("keg") or n_lower.contains("geyser") or n_lower.contains("biogas") or n_lower.contains("whirlpool")
		var is_enemy: bool = child.is_in_group("enemies") or child.is_in_group("fodder") or child is EnemyMob or child is EnemyBrimstoneRaft or child is EnemyIronGunner or child is EnemyTideCutter or child is EnemyGraveSkiff or child is EnemyMiniBossHarvester or child is EnemyMiniBossBombard or child is EnemyFodderSkiff or n_lower.contains("enemy") or n_lower.contains("fodder") or n_lower.contains("skiff") or n_lower.contains("rower") or n_lower.contains("gunner") or n_lower.contains("raft") or n_lower.contains("cutter") or n_lower.contains("harvester") or n_lower.contains("bombard") or n_lower.contains("sloop")
		var node_3d: Node3D = child as Node3D
		if (is_hazard or is_enemy) and node_3d.position.z > -min_clearance:
			to_remove.append(child)
	for rem: Node in to_remove:
		if is_instance_valid(rem):
			if rem.get_parent():
				rem.get_parent().remove_child(rem)
			rem.queue_free()

## Fast-forwards the runner track directly to the boss chunk entrance for isolated testing.
func jump_to_boss() -> void:
	if not is_assembled:
		return
	for chunk: BaseTrackChunk in active_chunks:
		if is_instance_valid(chunk) and chunk.is_boss_chunk:
			# Shift all chunks forward so the boss chunk starts at Z = 0
			var current_chunk_z: float = chunk.global_position.z
			var delta_z: float = 0.0 - current_chunk_z
			for c: BaseTrackChunk in active_chunks:
				if is_instance_valid(c):
					c.global_position.z += delta_z
			distance_traveled = total_track_distance
			var gs: Node = _get_game_state()
			if gs:
				gs.set("distance_traveled", total_track_distance)
				if gs.has_signal("progress_changed"):
					gs.emit_signal("progress_changed", total_track_distance, total_track_distance)
			_on_boss_arena_reached(chunk)
			break
