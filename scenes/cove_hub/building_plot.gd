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

@export var show_foundation_when_locked: bool = false:
	set(value):
		show_foundation_when_locked = value
		if is_node_ready():
			refresh_visuals()

@export var collision_box_size: Vector3 = Vector3(2.5, 2.5, 2.5):
	set(value):
		collision_box_size = value
		if is_node_ready():
			_update_collision_shape()

@export var auto_fit_collision_to_mesh: bool = true

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
	var box := BoxShape3D.new()
	box.size = collision_box_size
	collision_shape.shape = box
	# Center box so bottom is at ground level
	collision_shape.position = Vector3(0.0, collision_box_size.y * 0.5, 0.0)

func _update_collision_shape_with_center(size: Vector3, center_pos: Vector3) -> void:
	if not collision_shape:
		return
	var box := BoxShape3D.new()
	box.size = size
	collision_shape.shape = box
	collision_shape.position = center_pos

func _calculate_node_aabb(root_node: Node3D) -> AABB:
	var total_aabb := AABB()
	var has_mesh: bool = false
	var stack: Array[Node] = [root_node]
	while not stack.is_empty():
		var curr: Node = stack.pop_back() as Node
		if curr is MeshInstance3D:
			var mi: MeshInstance3D = curr as MeshInstance3D
			if mi.mesh:
				var mesh_aabb: AABB = mi.get_aabb()
				var xform: Transform3D = root_node.global_transform.affine_inverse() * mi.global_transform
				var transformed_aabb: AABB = xform * mesh_aabb
				if not has_mesh:
					total_aabb = transformed_aabb
					has_mesh = true
				else:
					total_aabb = total_aabb.merge(transformed_aabb)
		for child: Node in curr.get_children():
			stack.append(child)
	return total_aabb

func _fit_collision_to_active_model(model_node: Node3D) -> void:
	if not model_node or not auto_fit_collision_to_mesh:
		return
	var computed_aabb: AABB = _calculate_node_aabb(model_node)
	if computed_aabb.size.length_squared() > 0.01:
		collision_box_size = computed_aabb.size
		_update_collision_shape_with_center(computed_aabb.size, computed_aabb.get_center())

func refresh_visuals() -> void:
	if not mesh_root:
		return

	# Immediately detach and free prior instantiated child
	if _current_instantiated_model and is_instance_valid(_current_instantiated_model):
		_clear_harmonized_materials(_current_instantiated_model)
		if _current_instantiated_model.get_parent() == mesh_root:
			mesh_root.remove_child(_current_instantiated_model)
		_current_instantiated_model.queue_free()
		_current_instantiated_model = null

	for child: Node in mesh_root.get_children():
		if child is Node3D:
			_clear_harmonized_materials(child as Node3D)
		mesh_root.remove_child(child)
		child.queue_free()

	if is_unlocked and building_scene:
		var model: Node3D = building_scene.instantiate() as Node3D
		if model:
			model.name = "BuildingMesh"
			_harmonize_materials(model)
			mesh_root.add_child(model)
			_current_instantiated_model = model
			_fit_collision_to_active_model(model)
	elif show_foundation_when_locked and foundation_scene:
		var foundation: Node3D = foundation_scene.instantiate() as Node3D
		if foundation:
			foundation.name = "FoundationMesh"
			_harmonize_materials(foundation)
			mesh_root.add_child(foundation)
			_current_instantiated_model = foundation
			_fit_collision_to_active_model(foundation)
	else:
		_update_collision_shape()

func _harmonize_materials(model_node: Node3D) -> void:
	var stack: Array[Node] = [model_node]
	while not stack.is_empty():
		var curr: Node = stack.pop_back() as Node
		if curr is MeshInstance3D:
			var mi: MeshInstance3D = curr as MeshInstance3D
			if mi.mesh:
				for i: int in range(mi.mesh.get_surface_count()):
					var mat: Material = mi.get_surface_override_material(i)
					if not mat:
						mat = mi.mesh.surface_get_material(i)
					if not mat:
						continue
					if mat is StandardMaterial3D:
						var sm: StandardMaterial3D = mat.duplicate() as StandardMaterial3D
						var modified: bool = false
						match sm.resource_name:
							"MAT_Plaster_Wall":
								# Warm hand-painted Mediterranean cream plaster
								sm.albedo_color = Color(0.76, 0.71, 0.62)
								sm.roughness = 0.88
								modified = true
							"MAT_Stone_Base", "MAT_Stone_Dark":
								# Earthy coastal slate
								sm.albedo_color = Color(0.44, 0.42, 0.40)
								sm.roughness = 0.85
								modified = true
							"MAT_Stone_Light":
								# Soft sandstone
								sm.albedo_color = Color(0.55, 0.52, 0.48)
								sm.roughness = 0.80
								modified = true
							"MAT_Wood_Plank", "MAT_Wood_Light":
								# Warm oak timber
								sm.albedo_color = Color(0.50, 0.36, 0.22)
								sm.roughness = 0.78
								modified = true
							"MAT_Wood_Dark":
								# Dark aged support timber
								sm.albedo_color = Color(0.30, 0.20, 0.12)
								sm.roughness = 0.82
								modified = true
							"MAT_Roof_Terracotta":
								# Warm terracotta shingles
								sm.albedo_color = Color(0.68, 0.35, 0.24)
								sm.roughness = 0.72
								modified = true
							"MAT_Roof_Tile_Teal":
								# Weathered coastal teal slate
								sm.albedo_color = Color(0.26, 0.46, 0.52)
								sm.roughness = 0.68
								modified = true
						if modified:
							mi.set_surface_override_material(i, sm)
		for c: Node in curr.get_children():
			stack.append(c)

func _clear_harmonized_materials(model_node: Node3D) -> void:
	if not model_node or not is_instance_valid(model_node):
		return
	var stack: Array[Node] = [model_node]
	while not stack.is_empty():
		var curr: Node = stack.pop_back() as Node
		if curr is MeshInstance3D:
			var mi: MeshInstance3D = curr as MeshInstance3D
			mi.material_override = null
			for i: int in range(mi.get_surface_override_material_count()):
				mi.set_surface_override_material(i, null)
		for c: Node in curr.get_children():
			stack.append(c)

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
			press()

## Registers a tap on this lot (from 3D picking or the screen-space pin): click feedback + signal.
func press() -> void:
	_animate_click()
	plot_clicked.emit(self)

func _animate_hover(hovered: bool) -> void:
	if _hover_tween and _hover_tween.is_valid():
		_hover_tween.kill()

	_hover_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var target_scale: Vector3 = _original_scale * (1.06 if hovered else 1.0)
	_hover_tween.tween_property(self, "scale", target_scale, 0.18)

func _animate_click() -> void:
	var click_tween: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var squashed_scale: Vector3 = _original_scale * 0.94
	var restored_scale: Vector3 = _original_scale * (1.06 if is_hovered else 1.0)
	click_tween.tween_property(self, "scale", squashed_scale, 0.08)
	click_tween.tween_property(self, "scale", restored_scale, 0.14)

func set_unlocked_state(unlocked: bool) -> void:
	is_unlocked = unlocked
	refresh_visuals()

## Raises the building on its (empty) lot with a squash-and-stretch pop and a dust puff.
## Returns the duration of the animation in seconds so callers can wait for it.
func play_build_animation() -> float:
	const BUILD_DURATION: float = 1.0
	set_unlocked_state(true)
	if not mesh_root:
		return 0.0

	mesh_root.scale = Vector3(1.0, 0.02, 1.0)
	var build_tween: Tween = create_tween()
	build_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	build_tween.tween_property(mesh_root, "scale", Vector3.ONE, BUILD_DURATION)
	_spawn_dust_puff()
	return BUILD_DURATION

func _spawn_dust_puff() -> void:
	var dust: CPUParticles3D = CPUParticles3D.new()
	dust.name = "BuildDust"
	dust.one_shot = true
	dust.explosiveness = 0.9
	dust.amount = 36
	dust.lifetime = 1.1
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	dust.emission_sphere_radius = 0.9
	dust.direction = Vector3.UP
	dust.spread = 70.0
	dust.initial_velocity_min = 0.6
	dust.initial_velocity_max = 1.6
	dust.gravity = Vector3(0.0, -0.8, 0.0)
	dust.scale_amount_min = 0.6
	dust.scale_amount_max = 1.4

	var puff_mesh: SphereMesh = SphereMesh.new()
	puff_mesh.radius = 0.16
	puff_mesh.height = 0.32
	var puff_mat: StandardMaterial3D = StandardMaterial3D.new()
	puff_mat.albedo_color = Color(0.78, 0.68, 0.52, 0.8)
	puff_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	puff_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	puff_mesh.material = puff_mat
	dust.mesh = puff_mesh

	add_child(dust)
	dust.position = Vector3(0.0, 0.2, 0.0)
	dust.emitting = true
	get_tree().create_timer(1.6).timeout.connect(dust.queue_free)
