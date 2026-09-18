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

## Virtual method for custom chunk behaviors upon activation
func _on_spawners_activated() -> void:
	if is_boss_chunk and boss_scene:
		var existing = get_tree().get_first_node_in_group("boss")
		if not existing or existing.is_queued_for_deletion():
			var boss = boss_scene.instantiate() as Node3D
			add_child(boss)
			boss.position = Vector3(0.0, 0.0, -35.0)
			var camera = get_tree().get_first_node_in_group("game_camera")
			if camera and camera.has_method("start_boss_focus"):
				camera.start_boss_focus(boss)
			print("[BOSS CHUNK] Spawned boss: %s at Z = -35.0 (35m buffer zone)" % boss.name)

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
