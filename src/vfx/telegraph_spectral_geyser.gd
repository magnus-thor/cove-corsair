class_name TelegraphSpectralGeyser
extends Node3D

signal countdown_finished(detonation_pos: Vector3)

@export var duration: float = 1.6
@export var radius: float = 1.6

@onready var outer_ring: MeshInstance3D = $OuterRing
@onready var fill_disc: MeshInstance3D = $FillDisc
@onready var pulse_ring: MeshInstance3D = $PulseRing

var _elapsed: float = 0.0
var _is_active: bool = true
var _fill_mat: StandardMaterial3D
var _ring_mat: StandardMaterial3D
var _pulse_mat: StandardMaterial3D

func _ready() -> void:
	add_to_group("spectral_geyser_telegraphs")
	duration = maxf(1.6, duration)
	_setup_visuals()

func setup(p_duration: float, p_radius: float = 1.6) -> void:
	duration = maxf(1.6, p_duration)
	radius = p_radius
	if is_node_ready():
		_setup_visuals()

func _setup_visuals() -> void:
	# 1. Outer Ring: Crisp neon spectral border
	if outer_ring:
		var torus := TorusMesh.new()
		torus.inner_radius = radius - 0.08
		torus.outer_radius = radius
		torus.rings = 32
		torus.ring_segments = 16
		outer_ring.mesh = torus
		
		_ring_mat = StandardMaterial3D.new()
		_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_ring_mat.albedo_color = Color(0.15, 1.0, 0.45, 0.95) # High-contrast spectral green
		outer_ring.material_override = _ring_mat
		outer_ring.position.y = 0.03

	# 2. Fill Disc: Interior fill indicator expanding from center outward
	if fill_disc:
		var disc := CylinderMesh.new()
		disc.top_radius = radius - 0.08
		disc.bottom_radius = radius - 0.08
		disc.height = 0.01
		disc.radial_segments = 32
		fill_disc.mesh = disc
		
		_fill_mat = StandardMaterial3D.new()
		_fill_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_fill_mat.albedo_color = Color(0.1, 0.95, 0.35, 0.30)
		fill_disc.material_override = _fill_mat
		fill_disc.position.y = 0.02
		fill_disc.scale = Vector3(0.01, 1.0, 0.01)

	# 3. Pulse Ring: Fast warning strobe near end of countdown
	if pulse_ring:
		var p_torus := TorusMesh.new()
		p_torus.inner_radius = radius * 0.4
		p_torus.outer_radius = radius * 0.46
		p_torus.rings = 24
		p_torus.ring_segments = 12
		pulse_ring.mesh = p_torus
		
		_pulse_mat = StandardMaterial3D.new()
		_pulse_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_pulse_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_pulse_mat.albedo_color = Color(0.4, 1.0, 0.7, 0.8)
		pulse_ring.material_override = _pulse_mat
		pulse_ring.position.y = 0.025

func _physics_process(delta: float) -> void:
	if not _is_active:
		return
		
	_elapsed += delta
	var progress := clampf(_elapsed / duration, 0.0, 1.0)
	
	# Expanding interior fill
	if fill_disc:
		var current_fill_scale := lerpf(0.02, 1.0, progress)
		fill_disc.scale = Vector3(current_fill_scale, 1.0, current_fill_scale)
		if _fill_mat:
			_fill_mat.albedo_color.a = lerpf(0.25, 0.70, progress)

	# Pulse ring expands and loops
	if pulse_ring and _pulse_mat:
		var cycle := fmod(_elapsed * 2.5, 1.0)
		var p_scale := lerpf(0.3, 1.0, cycle)
		pulse_ring.scale = Vector3(p_scale, 1.0, p_scale)
		_pulse_mat.albedo_color.a = (1.0 - cycle) * 0.75

	# Outer ring subtle urgency flicker as detonation nears
	if outer_ring and _ring_mat and progress > 0.7:
		var flash := 0.85 + sin(_elapsed * 25.0) * 0.15
		_ring_mat.albedo_color = Color(0.15 * flash, 1.0, 0.45 * flash, 0.95)

	if _elapsed >= duration:
		_is_active = false
		countdown_finished.emit(global_position)
		queue_free()

func _exit_tree() -> void:
	if outer_ring:
		outer_ring.material_override = null
	if fill_disc:
		fill_disc.material_override = null
	if pulse_ring:
		pulse_ring.material_override = null
	_fill_mat = null
	_ring_mat = null
	_pulse_mat = null

func cancel_and_cleanup() -> void:
	_is_active = false
	queue_free()
