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
@export var camera_activation_distance: float = 75.0

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
	var existing = get_tree().get_first_node_in_group("persistent_water")
	if existing and existing is MeshInstance3D:
		_persistent_water = existing
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
		
		var shader := preload("res://src/shaders/water_stylized.gdshader")
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
	# Solid untextured sand/earth material at Y = 0.02m starting at |X| = 6.0m
	_bank_mat = StandardMaterial3D.new()
	_bank_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	_bank_mat.roughness = 0.95
	_bank_mat.albedo_color = Color(0.85, 0.72, 0.48) # Warm sand/shoreline tone
	_bank_mat.cull_mode = BaseMaterial3D.CULL_BACK
	
	for b_side in [-1.0, 1.0]:
		var bank_name := "PersistentBank_%s" % ("Left" if b_side < 0 else "Right")
		var existing_bank = get_tree().get_first_node_in_group("persistent_bank_%s" % ("left" if b_side < 0 else "right"))
		var bank_mesh: MeshInstance3D = null
		if existing_bank and existing_bank is MeshInstance3D:
			bank_mesh = existing_bank
		else:
			bank_mesh = MeshInstance3D.new()
			bank_mesh.name = bank_name
			bank_mesh.add_to_group("persistent_bank")
			bank_mesh.add_to_group("persistent_bank_%s" % ("left" if b_side < 0 else "right"))
			add_child(bank_mesh)
			
		var bank_plane := PlaneMesh.new()
		# 94m wide plane spanning from |X| = 6.0m to 100.0m
		bank_plane.size = Vector2(94.0, 320.0)
		bank_mesh.mesh = bank_plane
		# Elevated to Y = 0.02m (above water Y = 0.0m) to seal shorelines and hide any water under mountains
		bank_mesh.position = Vector3(b_side * 53.0, 0.02, -100.0)
		bank_mesh.material_override = _bank_mat
		if b_side < 0:
			_persistent_bank_left = bank_mesh
		else:
			_persistent_bank_right = bank_mesh

func update_water_color(color: Color) -> void:
	if _persistent_water and _persistent_water.material_override:
		var mat = _persistent_water.material_override as ShaderMaterial
		if mat:
			mat.set_shader_parameter("albedo", color)

	if _bank_mat:
		var b_name := "tropical"
		if active_level_data:
			if "biome_name" in active_level_data and active_level_data.biome_name != "":
				b_name = active_level_data.biome_name
			elif "biome" in active_level_data and active_level_data.biome != "":
				b_name = active_level_data.biome
				
		match b_name.to_lower():
			"bayou", "black_tide_bayou":
				_bank_mat.albedo_color = Color(0.28, 0.35, 0.25) # Mossy swamp bank
			"brimstone", "brimstone_bastion":
				_bank_mat.albedo_color = Color(0.22, 0.20, 0.22) # Volcanic basalt bank
			_:
				_bank_mat.albedo_color = Color(0.85, 0.72, 0.48) # Tropical sand bank

## Assembles the level dynamically from chunk_scenes in LevelData.
func assemble_level(data: LevelData = null) -> void:
	if data == null:
		var initial_gs = _get_game_state()
		if initial_gs and initial_gs.has_method("get_current_level_resource"):
			data = initial_gs.get_current_level_resource()
		
	if not data:
		push_warning("ChunkAssembler: No LevelData provided to assemble.")
		return
		
	active_level_data = data
	scroll_speed = active_level_data.base_scroll_speed
	distance_traveled = 0.0
	is_boss_active = false
	
	update_water_color(active_level_data.water_albedo)
	
	# Clear any previous chunks
	for chunk in active_chunks:
		if is_instance_valid(chunk):
			chunk.queue_free()
	active_chunks.clear()
	
	# Instantiation Loop:
	# Iterate through chunk_scenes, placing each at current_z_offset
	var current_z_offset: float = 0.0
	for scene in active_level_data.chunk_scenes:
		if scene == null:
			continue
			
		var chunk_instance = scene.instantiate() as BaseTrackChunk
		if not chunk_instance:
			continue
			
		add_child(chunk_instance)
		chunk_instance.position = Vector3(0.0, 0.0, current_z_offset)
		var c_len = chunk_instance.CHUNK_LENGTH
		current_z_offset -= c_len
		active_chunks.append(chunk_instance)
		
	# Calculate total track distance (distance until boss arena is reached)
	total_track_distance = 0.0
	for chunk in active_chunks:
		if not chunk.is_boss_chunk:
			total_track_distance += chunk.CHUNK_LENGTH
			
	if total_track_distance <= 0.0:
		total_track_distance = maxf(50.0, active_chunks.size() * 50.0)
		
	var gs = _get_game_state()
	if gs:
		gs.level_distance_target = total_track_distance
		gs.distance_traveled = 0.0
		if gs.has_signal("progress_changed"):
			gs.progress_changed.emit(0.0, total_track_distance)
	
	# Activate the first chunk immediately if it is at Z = 0
	if not active_chunks.is_empty():
		active_chunks[0].activate_spawners()
		
	is_assembled = true
	level_assembled.emit(total_track_distance)
	print("[CHUNK ASSEMBLER] Level %d (%s) assembled: %d chunks, total distance %.1fm" % [
		active_level_data.level_id,
		active_level_data.level_title,
		active_chunks.size(),
		total_track_distance
	])

func _physics_process(delta: float) -> void:
	var gs = _get_game_state()
	if not gs or not gs.is_game_active or not is_assembled or is_boss_active:
		return
		
	var movement = scroll_speed * delta
	
	# 1. Scroll all active chunks forward along +Z
	for chunk in active_chunks:
		if is_instance_valid(chunk):
			chunk.global_position.z += movement
			
	# 2. Accumulate player forward distance
	distance_traveled += movement
	if gs.has_method("update_distance"):
		gs.update_distance(movement)
	
	# 3. Spawner Activation: trigger chunks entering camera range
	for chunk in active_chunks:
		if is_instance_valid(chunk) and not chunk.is_active:
			if chunk.get_start_z() >= -camera_activation_distance:
				chunk.activate_spawners()
				
	# 4. Boss Arena Transition Check:
	# Check if the boss chunk has reached the arena engagement point
	for chunk in active_chunks:
		if is_instance_valid(chunk) and chunk.is_boss_chunk:
			if chunk.get_start_z() >= 0.0 or distance_traveled >= total_track_distance:
				_on_boss_arena_reached(chunk)
				break
				
	# 5. Memory / Pool Cleanup:
	# Chunks past the camera frustum (+30m behind) call queue_free()
	var to_remove: Array[BaseTrackChunk] = []
	for chunk in active_chunks:
		if is_instance_valid(chunk) and not chunk.is_boss_chunk:
			if chunk.is_past_camera(cleanup_distance_behind_camera):
				to_remove.append(chunk)
				
	for chunk in to_remove:
		active_chunks.erase(chunk)
		chunk.queue_free()
		print("[CHUNK CLEANUP] Chunk %s freed (+30m behind camera)" % chunk.name)

func _on_boss_arena_reached(boss_chunk: BaseTrackChunk) -> void:
	if is_boss_active:
		return
	is_boss_active = true
	scroll_speed = 0.0
	
	var gs = _get_game_state()
	if gs:
		gs.boss_spawned = true
		if gs.has_signal("distance_target_reached"):
			gs.distance_target_reached.emit()
		
		# Lock player progress to completion distance
		distance_traveled = total_track_distance
		gs.distance_traveled = total_track_distance
		if gs.has_signal("progress_changed"):
			gs.progress_changed.emit(total_track_distance, total_track_distance)
	
	# Trigger boss engagement hook inside boss chunk
	if not boss_chunk.is_active:
		boss_chunk.activate_spawners()
		
	boss_arena_reached.emit(boss_chunk)
	print("[CHUNK ASSEMBLER] Clean transition into Boss Arena: %s" % boss_chunk.name)
