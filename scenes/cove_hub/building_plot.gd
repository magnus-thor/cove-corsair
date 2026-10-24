class_name BuildingPlot
extends Node3D

## Interactive 2.5D Building Plot Anchor for Cove Main Hub.
## Handles mouse interaction (hover/click), state gating (locked vs unlocked),
## and instantiates modular 3D building / foundation assets.

signal plot_clicked(plot: BuildingPlot)
signal plot_hover_changed(plot: BuildingPlot, is_hovered: bool)

@export var plot_id: String = ""
@export var display_name: String = "Building Plot"
@export var is_unlocked: bool = false:
	set(value):
		is_unlocked = value
		if is_node_ready():
			refresh_visuals()

@export var building_scene: PackedScene = null:
	set(value):
		building_scene = value
		if is_node_ready():
			refresh_visuals()

@export var foundation_scene: PackedScene = null:
	set(value):
		foundation_scene = value
		if is_node_ready():
			refresh_visuals()

@export var collision_box_size: Vector3 = Vector3(2.5, 2.5, 2.5):
	set(value):
		collision_box_size = value
		if is_node_ready():
			_update_collision_shape()

@onready var interaction_area: Area3D = $InteractionArea as Area3D
@onready var collision_shape: CollisionShape3D = $InteractionArea/CollisionShape3D as CollisionShape3D
@onready var mesh_root: Node3D = $MeshRoot as Node3D

var is_hovered: bool = false
var _current_instantiated_model: Node3D = null
var _hover_tween: Tween = null
var _original_scale: Vector3 = Vector3.ONE

func _ready() -> void:
	_original_scale = scale
	_setup_interaction()
	_update_collision_shape()
	refresh_visuals()

func _setup_interaction() -> void:
	if not interaction_area:
		return
	if not interaction_area.mouse_entered.is_connected(_on_mouse_entered):
		interaction_area.mouse_entered.connect(_on_mouse_entered)
	if not interaction_area.mouse_exited.is_connected(_on_mouse_exited):
		interaction_area.mouse_exited.connect(_on_mouse_exited)
	if not interaction_area.input_event.is_connected(_on_input_event):
		interaction_area.input_event.connect(_on_input_event)

func _update_collision_shape() -> void:
	if not collision_shape:
		return
	var box: BoxShape3D = collision_shape.shape as BoxShape3D
	if not box:
		box = BoxShape3D.new()
		collision_shape.shape = box
	box.size = collision_box_size
	# Center box so bottom is at ground level
	collision_shape.position = Vector3(0.0, collision_box_size.y * 0.5, 0.0)

func refresh_visuals() -> void:
	if not mesh_root:
		return

	# Remove prior instantiated child
	if _current_instantiated_model and is_instance_valid(_current_instantiated_model):
		_current_instantiated_model.queue_free()
		_current_instantiated_model = null

	for child: Node in mesh_root.get_children():
		child.queue_free()

	if is_unlocked and building_scene:
		var model: Node3D = building_scene.instantiate() as Node3D
		if model:
			model.name = "BuildingMesh"
			mesh_root.add_child(model)
			_current_instantiated_model = model
	elif foundation_scene:
		var foundation: Node3D = foundation_scene.instantiate() as Node3D
		if foundation:
			foundation.name = "FoundationMesh"
			mesh_root.add_child(foundation)
			_current_instantiated_model = foundation
	else:
		_create_placeholder_fallback_mesh()

func _create_placeholder_fallback_mesh() -> void:
	# Fallback visual: small rustic wooden/stone marker base if no scene is assigned yet
	var marker_mesh_instance: MeshInstance3D = MeshInstance3D.new()
	marker_mesh_instance.name = "FallbackMarker"
	var box_mesh: BoxMesh = BoxMesh.new()
	box_mesh.size = Vector3(1.4, 0.2, 1.4)
	marker_mesh_instance.mesh = box_mesh
	marker_mesh_instance.position = Vector3(0.0, 0.1, 0.0)

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.35, 0.25, 0.85) if not is_unlocked else Color(0.2, 0.6, 0.4, 0.9)
	marker_mesh_instance.material_override = mat
	mesh_root.add_child(marker_mesh_instance)
	_current_instantiated_model = marker_mesh_instance

func _on_mouse_entered() -> void:
	is_hovered = true
	_animate_hover(true)
	plot_hover_changed.emit(self, true)

func _on_mouse_exited() -> void:
	is_hovered = false
	_animate_hover(false)
	plot_hover_changed.emit(self, false)

func _on_input_event(_camera: Camera3D, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			plot_clicked.emit(self)

func _animate_hover(hovered: bool) -> void:
	if _hover_tween and _hover_tween.is_valid():
		_hover_tween.kill()

	_hover_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var target_scale: Vector3 = _original_scale * (1.06 if hovered else 1.0)
	_hover_tween.tween_property(self, "scale", target_scale, 0.15)

func set_unlocked_state(unlocked: bool) -> void:
	is_unlocked = unlocked
	refresh_visuals()
