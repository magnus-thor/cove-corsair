class_name DeckReticle3D
extends Node3D

## Visual targeting reticle projected on the deck or locked onto enemies/ropes.

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

func _process(delta: float) -> void:
	rotate_y(2.2 * delta)
	var pulse: float = 1.0 + sin(float(Time.get_ticks_msec()) * 0.008) * 0.12
	scale = Vector3(pulse, 1.0, pulse)
