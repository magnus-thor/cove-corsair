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

func get_plank_origin(zone_index: int) -> Marker3D:
	match zone_index:
		0:
			return plank_origin_bow
		2:
			return plank_origin_stern
		_:
			return plank_origin_mid
