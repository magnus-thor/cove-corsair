@tool
class_name EnemyBoardingRig
extends Node3D

## Per-vessel layout for enemy boss ships in the boarding arena.
## Stores plank origin launch points, wake particle emitter, and calibrated dock position.

@export var plank_origin_bow: Marker3D = null
@export var plank_origin_mid: Marker3D = null
@export var plank_origin_stern: Marker3D = null
@export var wake: GPUParticles3D = null
@export var dock_position: Vector3 = Vector3(13.323, 0.287, 0.386)

func _ready() -> void:
	_ensure_rig_visibility(self)

func _ensure_rig_visibility(target_node: Node) -> void:
	if target_node is GeometryInstance3D:
		var geom: GeometryInstance3D = target_node as GeometryInstance3D
		geom.extra_cull_margin = 8.0
		geom.lod_bias = 0.001
	for child: Node in target_node.get_children():
		_ensure_rig_visibility(child)

func get_plank_origin(zone_index: int) -> Marker3D:
	match zone_index:
		0:
			return plank_origin_bow
		2:
			return plank_origin_stern
		_:
			return plank_origin_mid
