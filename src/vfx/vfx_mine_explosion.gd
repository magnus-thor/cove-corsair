class_name VFXMineExplosion
extends Node3D

@onready var core_flash: CPUParticles3D = get_node_or_null("CoreFlash")
@onready var smoke_ring: MeshInstance3D = get_node_or_null("SmokeRing")

signal finished

func _ready() -> void:
	top_level = true
	if core_flash:
		core_flash.local_coords = true
		core_flash.restart()
		core_flash.emitting = true
		core_flash.finished.connect(_on_finished)
	else:
		get_tree().create_timer(0.45).timeout.connect(_on_finished)

	if smoke_ring:
		smoke_ring.position = Vector3(0.0, 0.05, 0.0)
		smoke_ring.scale = Vector3(0.2, 1.0, 0.2)
		var base_mat = smoke_ring.get_active_material(0)
		if base_mat is StandardMaterial3D:
			var mat: StandardMaterial3D = base_mat.duplicate()
			smoke_ring.material_override = mat
			var tween = create_tween().set_parallel(true)
			tween.tween_property(smoke_ring, "scale", Vector3(3.2, 1.0, 3.2), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(mat, "albedo_color:a", 0.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _on_finished() -> void:
	emit_signal("finished")
