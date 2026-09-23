class_name TelegraphIronjawMortar
extends Node3D

signal countdown_finished(detonation_pos: Vector3)

@export var duration: float = 1.8
@export var radius: float = 1.8

@onready var outer_ring: MeshInstance3D = $OuterRing
@onready var contracting_ring: MeshInstance3D = $ContractingRing
@onready var center_skull: Sprite3D = get_node_or_null("CenterSkull") as Sprite3D
@onready var water_churn: MeshInstance3D = $WaterChurn
@onready var crosshair_h: MeshInstance3D = $CrosshairH
@onready var crosshair_v: MeshInstance3D = $CrosshairV

var _elapsed: float = 0.0
var _is_active: bool = true
var _outer_mat: StandardMaterial3D = null
var _contract_mat: StandardMaterial3D = null
var _churn_mat: StandardMaterial3D = null
var _crosshair_mat: StandardMaterial3D = null

func _ready() -> void:
	add_to_group("ironjaw_telegraphs")
	duration = maxf(1.6, duration)
	_setup_materials_and_meshes()

func setup(p_duration: float, p_radius: float = 1.8) -> void:
	duration = maxf(1.6, p_duration)
	radius = p_radius
	if is_node_ready():
		_setup_materials_and_meshes()

func _setup_materials_and_meshes() -> void:
	# 1. Outer Heavy Iron Ring
	if outer_ring:
		var torus: TorusMesh = TorusMesh.new()
		torus.inner_radius = radius - 0.08
		torus.outer_radius = radius
		torus.rings = 36
		torus.ring_segments = 16
		outer_ring.mesh = torus
		
		_outer_mat = StandardMaterial3D.new()
		_outer_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_outer_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_outer_mat.albedo_color = Color(0.95, 0.25, 0.1, 0.95)
		outer_ring.material_override = _outer_mat
		outer_ring.position.y = 0.03

	# 2. Contracting Warning Ring (Shrinks from outer boundary to center)
	if contracting_ring:
		var c_torus: TorusMesh = TorusMesh.new()
		c_torus.inner_radius = radius - 0.12
		c_torus.outer_radius = radius - 0.02
		c_torus.rings = 36
		c_torus.ring_segments = 16
		contracting_ring.mesh = c_torus
		
		_contract_mat = StandardMaterial3D.new()
		_contract_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_contract_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_contract_mat.albedo_color = Color(1.0, 0.85, 0.15, 0.95) # Radiant amber/yellow ring
		contracting_ring.material_override = _contract_mat
		contracting_ring.position.y = 0.035

	# 3. Water Churn / Foam Area under the targeting circle
	if water_churn:
		var disc: CylinderMesh = CylinderMesh.new()
		disc.top_radius = radius - 0.05
		disc.bottom_radius = radius - 0.05
		disc.height = 0.01
		disc.radial_segments = 32
		water_churn.mesh = disc
		
		_churn_mat = StandardMaterial3D.new()
		_churn_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_churn_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_churn_mat.albedo_color = Color(0.85, 0.15, 0.1, 0.25)
		water_churn.material_override = _churn_mat
		water_churn.position.y = 0.015

	# 4. Crosshairs (Naval Target Reticle)
	_crosshair_mat = StandardMaterial3D.new()
	_crosshair_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_crosshair_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_crosshair_mat.albedo_color = Color(1.0, 0.3, 0.1, 0.8)

	if crosshair_h:
		var box_h: BoxMesh = BoxMesh.new()
		box_h.size = Vector3(radius * 2.2, 0.01, 0.06)
		crosshair_h.mesh = box_h
		crosshair_h.material_override = _crosshair_mat
		crosshair_h.position.y = 0.025

	if crosshair_v:
		var box_v: BoxMesh = BoxMesh.new()
		box_v.size = Vector3(0.06, 0.01, radius * 2.2)
		crosshair_v.mesh = box_v
		crosshair_v.material_override = _crosshair_mat
		crosshair_v.position.y = 0.025

	# 5. Center Skull / Warning icon if available
	if center_skull:
		center_skull.modulate = Color(1.0, 0.9, 0.2, 0.9)
		center_skull.position.y = 0.04

func _physics_process(delta: float) -> void:
	if not _is_active:
		return
		
	_elapsed += delta
	var progress: float = clampf(_elapsed / duration, 0.0, 1.0)
	
	# Rotate outer reticle slowly for dynamic naval tracking feel
	rotation.y += delta * 1.5
	
	# Shrink contracting warning ring from 1.0 down to 0.05
	if contracting_ring:
		var shrink_scale: float = lerpf(1.0, 0.05, progress)
		contracting_ring.scale = Vector3(shrink_scale, 1.0, shrink_scale)
		if _contract_mat:
			# Shift color from warning amber to blistering red as impact approaches
			_contract_mat.albedo_color = Color(1.0, lerpf(0.85, 0.1, progress), 0.1, 0.95)

	# Water churn agitation
	if water_churn and _churn_mat:
		var pulse: float = 0.22 + sin(_elapsed * 12.0) * 0.08
		_churn_mat.albedo_color.a = pulse

	# High-urgency warning strobing in final 0.4s
	var remaining: float = duration - _elapsed
	if remaining <= 0.4:
		var flash: float = 0.5 + sin(_elapsed * 35.0) * 0.5
		if _outer_mat:
			_outer_mat.albedo_color = Color(1.0, 0.1 + flash * 0.8, 0.1, 0.95)
		if center_skull:
			center_skull.modulate = Color(1.0, flash, flash, 1.0)

	if _elapsed >= duration:
		_is_active = false
		countdown_finished.emit(global_position)
		queue_free()

func cancel_and_cleanup() -> void:
	_is_active = false
	queue_free()
