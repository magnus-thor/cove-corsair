class_name VFXMineExplosion
extends Node3D

@onready var core_flash: CPUParticles3D = get_node_or_null("CoreFlash")

signal finished

func _ready() -> void:
	if core_flash:
		core_flash.restart()
		core_flash.emitting = true
		core_flash.finished.connect(_on_finished)
	else:
		get_tree().create_timer(0.35).timeout.connect(_on_finished)

func _on_finished() -> void:
	emit_signal("finished")
