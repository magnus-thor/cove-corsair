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

func _get_game_state() -> Node:
	return get_node_or_null("/root/GameState")

func _ready() -> void:
	add_to_group("chunk_assembler")
	_setup_persistent_water()
	
	if active_level_data:
		assemble_level(active_level_data)

## Sets up a single persistent water surface plane beneath the camera to prevent
## seam tearing and redundant GPU overdraw across individual chunks.
func _setup_persistent_water() -> void:
	var existing = get_tree().get_first_node_in_group("persistent_water")
	if existing and existing is MeshInstance3D:
		_persistent_water = existing
		return
		
	var water_mesh := MeshInstance3D.new()
	water_mesh.name = "PersistentWaterPlane"
	water_mesh.add_to_group("persistent_water")
	
	var plane := PlaneMesh.new()
	plane.size = Vector2(200.0, 320.0)
	water_mesh.mesh = plane
	water_mesh.position = Vector3(0.0, -0.01, -100.0)
	
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

func update_water_color(color: Color) -> void:
	if _persistent_water and _persistent_water.material_override:
		var mat = _persistent_water.material_override as ShaderMaterial
		if mat:
			mat.set_shader_parameter("albedo", color)

## Assembles the level dynamically from chunk_scenes in LevelData.
func assemble_level(data: LevelData = null) -> void:
	if data == null:
		var gs = _get_game_state()
		if gs and gs.has_method("get_current_level_resource"):
			data = gs.get_current_level_resource()
		
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
