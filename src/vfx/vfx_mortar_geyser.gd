class_name VFXMortarGeyser
extends Node3D

@onready var water_column: CPUParticles3D = get_node_or_null("WaterColumn")
@onready var shockwave_ring: MeshInstance3D = get_node_or_null("ShockwaveRing")

signal finished

var _mat: StandardMaterial3D = null

func _exit_tree() -> void:
	if shockwave_ring:
		shockwave_ring.material_override = null
	_mat = null

func _ready() -> void:
	top_level = true
	if water_column:
		water_column.local_coords = true
		water_column.restart()
		water_column.emitting = true
		water_column.finished.connect(_on_particles_finished)
	
	if shockwave_ring:
		shockwave_ring.position = Vector3(0.0, 0.05, 0.0)
		shockwave_ring.scale = Vector3(0.2, 1.0, 0.2)
		var base_mat: Material = shockwave_ring.get_active_material(0)
		if base_mat is StandardMaterial3D:
			_mat = (base_mat as StandardMaterial3D).duplicate() as StandardMaterial3D
			shockwave_ring.material_override = _mat
			var tween: Tween = create_tween().set_parallel(true)
			tween.tween_property(shockwave_ring, "scale", Vector3(3.5, 1.0, 3.5), 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(_mat, "albedo_color:a", 0.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _on_particles_finished() -> void:
	emit_signal("finished")
