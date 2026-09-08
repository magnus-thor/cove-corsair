class_name VFXMineExplosion
extends Node3D

@onready var core_flash: CPUParticles3D = get_node_or_null("CoreFlash")
@onready var smoke_cloud: CPUParticles3D = get_node_or_null("SmokeCloud")

signal finished

func _ready() -> void:
	if core_flash:
		core_flash.restart()
		core_flash.emitting = true
	if smoke_cloud:
		smoke_cloud.restart()
		smoke_cloud.emitting = true
		smoke_cloud.finished.connect(_on_smoke_finished)
	else:
		get_tree().create_timer(0.5).timeout.connect(_on_smoke_finished)

func _on_smoke_finished() -> void:
	emit_signal("finished")
