class_name VFXBiogasCloud
extends Node3D

## Stylized toxic biogas fume cloud deployed upon biogas pod detonation.
## Replaces raw geometric sphere with billowy marsh fumes and noxious surface bubbles.

@onready var fumes_particles: CPUParticles3D = get_node_or_null("FumesParticles") as CPUParticles3D
@onready var bubble_particles: CPUParticles3D = get_node_or_null("BubbleParticles") as CPUParticles3D

var _cloud_lifetime: float = 2.5
var _is_fading: bool = false

func _ready() -> void:
	top_level = true
	if fumes_particles:
		fumes_particles.restart()
		fumes_particles.emitting = true
	if bubble_particles:
		bubble_particles.restart()
		bubble_particles.emitting = true

func start_cloud(duration: float = 2.5, radius: float = 4.2) -> void:
	_cloud_lifetime = duration
	if fumes_particles:
		fumes_particles.emission_sphere_radius = radius * 0.5
	if bubble_particles:
		bubble_particles.emission_sphere_radius = radius * 0.65
		
	var tree: SceneTree = get_tree()
	if tree:
		var timer: SceneTreeTimer = tree.create_timer(maxf(0.1, duration - 0.8))
		timer.timeout.connect(stop_and_cleanup)

func stop_and_cleanup() -> void:
	if _is_fading:
		return
	_is_fading = true
	if fumes_particles:
		fumes_particles.emitting = false
	if bubble_particles:
		bubble_particles.emitting = false
		
	var tree: SceneTree = get_tree()
	if tree:
		var cleanup_timer: SceneTreeTimer = tree.create_timer(1.2)
		cleanup_timer.timeout.connect(queue_free)
	else:
		queue_free()
