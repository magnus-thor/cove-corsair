class_name VFXMineExplosion
extends Node3D

## Explosive fiery sea mine & bomb detonation VFX.
## Features fiery core burst, flying ember sparks, water splash, and billowing smoke plume.

@onready var core_flash: CPUParticles3D = get_node_or_null("CoreFlash") as CPUParticles3D
@onready var fire_burst: CPUParticles3D = get_node_or_null("FireBurst") as CPUParticles3D
@onready var ember_sparks: CPUParticles3D = get_node_or_null("EmberSparks") as CPUParticles3D
@onready var smoke_plume: CPUParticles3D = get_node_or_null("SmokePlume") as CPUParticles3D
@onready var water_splash: CPUParticles3D = get_node_or_null("WaterSplash") as CPUParticles3D

signal finished

func _ready() -> void:
	top_level = true
	var longest_lifetime: float = 0.75
	var particles: Array[Node] = find_children("*", "CPUParticles3D", true, false)
	for p: Node in particles:
		if p is CPUParticles3D:
			var cp: CPUParticles3D = p as CPUParticles3D
			cp.local_coords = true
			cp.restart()
			cp.emitting = true
			if cp.lifetime > longest_lifetime:
				longest_lifetime = cp.lifetime
				
	var tree: SceneTree = get_tree()
	if tree:
		var timer: SceneTreeTimer = tree.create_timer(longest_lifetime + 0.1)
		timer.timeout.connect(_on_finished)
	else:
		_on_finished()

func _on_finished() -> void:
	finished.emit()
	queue_free()
