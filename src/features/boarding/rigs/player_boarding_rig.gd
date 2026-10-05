@tool
class_name PlayerBoardingRig
extends Node3D

## Per-vessel deck layout for the boarding arena.
## All spatial transforms (deck floor, zones, crew stations, player spawn, anchors)
## are authored directly in each vessel's rig scene.

@export var zone_bow: BoardingZone = null
@export var zone_midship: BoardingZone = null
@export var zone_stern: BoardingZone = null
@export var crew_station_bow: BoardingCrewStation = null
@export var crew_station_stern: BoardingCrewStation = null
@export var player_spawn: Marker3D = null
@export var camera_mount: Marker3D = null
@export var breach_line: Marker3D = null

func _ready() -> void:
	_ensure_rig_visibility(self)

func _ensure_rig_visibility(target_node: Node) -> void:
	if target_node is GeometryInstance3D:
		var geom: GeometryInstance3D = target_node as GeometryInstance3D
		geom.extra_cull_margin = 8.0
		geom.lod_bias = 0.001
	for child: Node in target_node.get_children():
		_ensure_rig_visibility(child)

func get_zones() -> Array[BoardingZone]:
	var result: Array[BoardingZone] = []
	if is_instance_valid(zone_bow):
		result.append(zone_bow)
	if is_instance_valid(zone_midship):
		result.append(zone_midship)
	if is_instance_valid(zone_stern):
		result.append(zone_stern)
	return result

func get_breach_z(fallback: float = 6.2) -> float:
	if is_instance_valid(breach_line):
		return breach_line.global_position.z
	return fallback
