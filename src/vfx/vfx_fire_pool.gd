class_name VFXFirePool
extends Node3D

## Stylized lingering fire pool on water deployed by incendiary bombs and napalm.
## Replaces raw geometric cylinder discs with animated licking flames and smoky embers.

@onready var flames_particles: CPUParticles3D = get_node_or_null("FlamesParticles") as CPUParticles3D
@onready var embers_particles: CPUParticles3D = get_node_or_null("EmbersParticles") as CPUParticles3D
@onready var smoke_particles: CPUParticles3D = get_node_or_null("SmokeParticles") as CPUParticles3D

var _pool_lifetime: float = 2.0
var _is_fading: bool = false

func _ready() -> void:
	top_level = true
	if flames_particles:
		flames_particles.restart()
		flames_particles.emitting = true
	if embers_particles:
		embers_particles.restart()
		embers_particles.emitting = true
	if smoke_particles:
		smoke_particles.restart()
		smoke_particles.emitting = true

func start_fire_pool(duration: float = 2.0, radius: float = 2.4) -> void:
	_pool_lifetime = duration
	if flames_particles:
		flames_particles.emission_sphere_radius = radius * 0.7
	if embers_particles:
		embers_particles.emission_sphere_radius = radius * 0.8
	if smoke_particles:
		smoke_particles.emission_sphere_radius = radius * 0.6
		
	var tree: SceneTree = get_tree()
	if tree:
		var timer: SceneTreeTimer = tree.create_timer(maxf(0.1, duration - 0.5))
		timer.timeout.connect(stop_and_cleanup)

func stop_and_cleanup() -> void:
	if _is_fading:
		return
	_is_fading = true
	if flames_particles:
		flames_particles.emitting = false
	if embers_particles:
		embers_particles.emitting = false
	if smoke_particles:
		smoke_particles.emitting = false
		
	var tree: SceneTree = get_tree()
	if tree:
		var cleanup_timer: SceneTreeTimer = tree.create_timer(0.9)
		cleanup_timer.timeout.connect(queue_free)
	else:
		queue_free()
