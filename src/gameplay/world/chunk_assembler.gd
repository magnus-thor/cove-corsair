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

const BOSS_BUFFER_CHUNK_SCENE: PackedScene = preload("res://src/gameplay/chunks/chunk_boss_intro_buffer.tscn")

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
	var existing := get_tree().get_first_node_in_group("persistent_water")
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
	
	for b_side: float in [-1.0, 1.0]:
		var bank_name := "PersistentBank_%s" % ("Left" if b_side < 0 else "Right")
		var existing_bank := get_tree().get_first_node_in_group("persistent_bank_%s" % ("left" if b_side < 0 else "right"))
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
		var mat := _persistent_water.material_override as ShaderMaterial
		if mat:
			mat.set_shader_parameter("albedo", color)

	if _bank_mat:
		var b_name := "tropical"
		if active_level_data:
			if "biome_name" in active_level_data and str(active_level_data.get("biome_name")) != "":
				b_name = str(active_level_data.get("biome_name"))
			elif "biome" in active_level_data and str(active_level_data.get("biome")) != "":
				b_name = str(active_level_data.get("biome"))
				
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
		var initial_gs := _get_game_state()
		if initial_gs and initial_gs.has_method("get_current_level_resource"):
			data = initial_gs.call("get_current_level_resource") as LevelData
		
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
						add_child(buffer_instance)
						buffer_instance.position = Vector3(0.0, 0.0, current_z_offset)
						current_z_offset -= buffer_instance.CHUNK_LENGTH
						active_chunks.append(buffer_instance)
						print("[CHUNK ASSEMBLER] Inserted 50m buffer chunk before boss: %s" % buffer_instance.name)
			
		# If this is the starting chunk (index 0), enforce safe clearance runway (>= 35.0m) from player start
		if active_chunks.is_empty():
			_enforce_start_clearance_in_chunk(chunk_instance, 35.0)

		add_child(chunk_instance)
		chunk_instance.position = Vector3(0.0, 0.0, current_z_offset)
		var c_len := chunk_instance.CHUNK_LENGTH
		current_z_offset -= c_len
		active_chunks.append(chunk_instance)
		
	# Calculate total track distance (distance until boss arena is reached)
	total_track_distance = 0.0
	for chunk in active_chunks:
		if not chunk.is_boss_chunk:
			total_track_distance += chunk.CHUNK_LENGTH
			
	if total_track_distance <= 0.0:
		total_track_distance = maxf(50.0, active_chunks.size() * 50.0)
		
	var gs := _get_game_state()
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
	print("[CHUNK ASSEMBLER] Level %d (%s) assembled: %d chunks, total distance %.1fm" % [
		active_level_data.level_id,
		active_level_data.level_title,
		active_chunks.size(),
		total_track_distance
	])

func _physics_process(delta: float) -> void:
	var gs := _get_game_state()
	var is_active: bool = (gs.get("is_game_active") == true) if (gs and "is_game_active" in gs) else false
	if not gs or not is_active or not is_assembled or is_boss_active:
		return
		
	var movement := scroll_speed * delta
	
	# 1. Scroll all active chunks forward along +Z
	for chunk in active_chunks:
		if is_instance_valid(chunk):
			chunk.global_position.z += movement
			
	# 2. Accumulate player forward distance
	distance_traveled += movement
	if gs.has_method("update_distance"):
		gs.call("update_distance", movement)
	
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
	
	var gs := _get_game_state()
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
		
	boss_arena_reached.emit(boss_chunk)
	print("[CHUNK ASSEMBLER] Clean transition into Boss Arena: %s" % boss_chunk.name)

## Suppresses multiplier gates occurring in the final portion (e.g. 30%) of a chunk.
func _suppress_gates_in_chunk_final_portion(chunk: BaseTrackChunk, portion: float = 0.30) -> void:
	if not chunk or not is_instance_valid(chunk):
		return
	var threshold_z := -chunk.CHUNK_LENGTH * (1.0 - portion) # e.g. -35.0m for 50m chunk
	for child: Node in chunk.find_children("*", "", true, false):
		if not is_instance_valid(child):
			continue
		if (child.is_in_group("multiplier_gate") or (child is Area3D and child.has_method("apply_multiplier"))) and child is Node3D:
			# Check Z relative to chunk origin
			var rel_z: float = (child as Node3D).position.z
			if rel_z <= threshold_z:
				print("[CHUNK ASSEMBLER] Suppressing multiplier gate '%s' in final %.0f%% (Z=%.1fm <= %.1fm) of chunk %s" % [
					child.name, portion * 100.0, rel_z, threshold_z, chunk.name
				])
				if child.get_parent():
					child.get_parent().remove_child(child)
				child.queue_free()

## Enforces a safe clearance runway at the start of a level so no hazards, mines, or hostile vessels appear dangerously close to the player.
func _enforce_start_clearance_in_chunk(chunk: BaseTrackChunk, min_clearance: float = 35.0) -> void:
	if not chunk or not is_instance_valid(chunk):
		return
	var entities := chunk.find_child("Entities", true, false)
	if not entities:
		return
	for child: Node in entities.get_children():
		if not is_instance_valid(child):
			continue
		var is_hazard := child is HazardSeaMine or child is HazardThermalGeyser or child.is_in_group("hazards") or child.name.to_lower().contains("mine")
		var is_enemy := child.is_in_group("enemies") or child is EnemyMob or child.name.to_lower().contains("enemy") or child.name.to_lower().contains("fodder") or child.name.to_lower().contains("skiff") or child.name.to_lower().contains("rower")
		if (is_hazard or is_enemy) and child is Node3D and (child as Node3D).position.z > -min_clearance:
			print("[CHUNK ASSEMBLER] Suppressed early hostile/hazard '%s' at Z=%.1fm in starting chunk (< %.1fm clearance)" % [child.name, (child as Node3D).position.z, min_clearance])
			if child.get_parent():
				child.get_parent().remove_child(child)
			child.queue_free()

## Fast-forwards the runner track directly to the boss chunk entrance for isolated testing.
func jump_to_boss() -> void:
	if not is_assembled:
		return
	for chunk in active_chunks:
		if is_instance_valid(chunk) and chunk.is_boss_chunk:
			# Shift all chunks forward so the boss chunk starts at Z = 0
			var current_chunk_z := chunk.global_position.z
			var delta_z := 0.0 - current_chunk_z
			for c in active_chunks:
				if is_instance_valid(c):
					c.global_position.z += delta_z
			distance_traveled = total_track_distance
			var gs := _get_game_state()
			if gs:
				gs.set("distance_traveled", total_track_distance)
				if gs.has_signal("progress_changed"):
					gs.emit_signal("progress_changed", total_track_distance, total_track_distance)
			_on_boss_arena_reached(chunk)
			print("[CHUNK ASSEMBLER] Jumped directly to boss chunk: %s" % chunk.name)
			break
