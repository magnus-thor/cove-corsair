class_name VFXAutoDestroy
extends Node3D

## Maximum lifetime in seconds before auto-destroying this VFX instance
@export var max_lifetime: float = 1.0
@export var auto_destroy: bool = true
@export var modulate: Color = Color.WHITE:
	set(val):
		modulate = val

func _ready() -> void:
	top_level = true
	var particle_nodes: Array[Node] = []
	particle_nodes.append_array(find_children("*", "GPUParticles3D", true, false))
	particle_nodes.append_array(find_children("*", "CPUParticles3D", true, false))
	
	for p in particle_nodes:
		if "local_coords" in p:
			p.local_coords = true
		if p is GPUParticles3D:
			p.restart()
			p.emitting = true
		elif p is CPUParticles3D:
			p.restart()
			p.emitting = true
			
	if not auto_destroy:
		return
		
	var timer = get_tree().create_timer(max_lifetime)
	timer.timeout.connect(queue_free)
