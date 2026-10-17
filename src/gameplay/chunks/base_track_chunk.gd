class_name BaseTrackChunk
extends Node3D

## Base contract for all modular runner track chunks in Cove Corsair.
## Chunks represent 50m length slices of banks, obstacles, spawners, gates, and markers.
## Chunks intentionally do NOT contain water geometry (water is rendered as a persistent plane under the camera).

const CHUNK_LENGTH: float = 50.0

signal chunk_activated(chunk: BaseTrackChunk)
@warning_ignore("unused_signal")
signal chunk_completed(chunk: BaseTrackChunk)

@export var chunk_id: String = ""
@export var is_boss_chunk: bool = false
@export var is_active: bool = false
@export var boss_scene: PackedScene

var chunk_start: Marker3D
var chunk_end: Marker3D

func _ready() -> void:
	add_to_group("track_chunks")
	_ensure_markers()
	
	# Keep entities dormant until entering camera frustum
	if not is_active:
		_set_entities_dormant(true)

func _ensure_markers() -> void:
	chunk_start = get_node_or_null("ChunkStart") as Marker3D
	if not chunk_start:
		chunk_start = Marker3D.new()
		chunk_start.name = "ChunkStart"
		add_child(chunk_start)
		chunk_start.position = Vector3(0, 0, 0)
		
	chunk_end = get_node_or_null("ChunkEnd") as Marker3D
	if not chunk_end:
		chunk_end = Marker3D.new()
		chunk_end.name = "ChunkEnd"
		add_child(chunk_end)
		chunk_end.position = Vector3(0, 0, -CHUNK_LENGTH)

func _set_entities_dormant(dormant: bool) -> void:
	for container_name in ["Spawners", "Entities", "Obstacles", "Enemies", "Coins", "Gates"]:
		var node = get_node_or_null(container_name)
		if node:
			node.process_mode = Node.PROCESS_MODE_DISABLED if dormant else Node.PROCESS_MODE_INHERIT

## Spawner hook: activates all coins, obstacles, gates, and enemy formations when entering camera range
func activate_spawners() -> void:
	if is_active:
		return
	is_active = true
	_set_entities_dormant(false)
	
	# Execute spawner callbacks on any spawner nodes
	for child in find_children("*", "", true, false):
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
		var existing = get_tree().get_first_node_in_group("boss")
		if not existing or existing.is_queued_for_deletion():
			var boss = boss_scene.instantiate() as Node3D
			add_child(boss)
			boss.position = Vector3(0.0, 0.0, -60.0)
			var camera = get_tree().get_first_node_in_group("game_camera")
			if camera and camera.has_method("start_boss_focus"):
				camera.start_boss_focus(boss)

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

## Applies per-level procedural variation to chunk scenery (mirroring, scale, jitter, density, open vs narrow).
## Reuses existing Kenney and custom models with novel combinations, rotations, and distances from lane.
func apply_scenery_variation(level_seed: int, is_narrow_section: bool = false) -> void:
	var banks: Node3D = get_node_or_null("Banks") as Node3D
	if not banks:
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = level_seed

	# 1. Bank Mirroring: 50% chance to flip left and right banks across the river
	var mirror_banks: bool = (rng.randi() % 2 == 1)

	# 2. Section Spacing: Narrow gorge vs Open wide bay
	var spacing_bias: float = rng.randf_range(0.0, 0.7) if is_narrow_section else rng.randf_range(1.5, 3.2)

	for child: Node in banks.get_children():
		if not (child is Node3D):
			continue
		var prop: Node3D = child as Node3D

		# Mirror X-axis and mirror orientation
		if mirror_banks:
			prop.position.x = -prop.position.x
			prop.rotation.y = wrapf(prop.rotation.y + PI, 0.0, TAU)

		# Jitter lane distance while strictly respecting minimum navigable clearance (|X| >= 6.8m)
		var sign_x: float = -1.0 if prop.position.x < 0.0 else 1.0
		var current_dist: float = absf(prop.position.x)
		var target_dist: float = maxf(6.8, current_dist + spacing_bias + rng.randf_range(-0.4, 0.6))
		prop.position.x = sign_x * target_dist

		# Longitudinal Z-axis jitter (constrained within chunk length)
		var jitter_z: float = rng.randf_range(-2.0, 2.0)
		prop.position.z = clampf(prop.position.z + jitter_z, -CHUNK_LENGTH + 1.0, -1.0)

		# Scale randomization (0.85x to 1.30x)
		var scale_factor: float = rng.randf_range(0.85, 1.30)
		prop.scale *= scale_factor

		# Rotation randomization
		var prop_name: String = prop.name.to_lower()
		if "rock" in prop_name or "palm" in prop_name or "bush" in prop_name:
			prop.rotation.y = wrapf(prop.rotation.y + rng.randf_range(-PI, PI), 0.0, TAU)
			prop.rotation.x = rng.randf_range(-0.06, 0.06)
			prop.rotation.z = rng.randf_range(-0.06, 0.06)
		else:
			# Docks, towers, walls: subtle organic angle offset
			prop.rotation.y = wrapf(prop.rotation.y + rng.randf_range(-0.15, 0.15), 0.0, TAU)

		# Density & grouping: 30% chance to toggle non-essential secondary accents for organic pacing
		if "fence" in prop_name or "accent" in prop_name or "dock" in prop_name or "flavor" in prop_name:
			if rng.randf() < 0.30:
				prop.visible = false

