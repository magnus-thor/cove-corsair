class_name CoveMainHub
extends Node3D

## Cove Main Hub 2.5D Orchestrator.
## Combines a painted 2D cove backdrop locked to the Camera3D with interactive
## 3D modular building plots, lighting matching the backdrop sun/torches,
## and a dedicated vessel dock anchor.

const BuildingPlot = preload("res://scenes/cove_hub/building_plot.gd")
const RIVER_MAP_SCENE: PackedScene = preload("res://src/ui/river_map.tscn")
const SHIPYARD_SCENE: PackedScene = preload("res://src/ui/shipyard/shipyard_ui.tscn")
const MAIN_GAME_PATH: String = "res://src/core/main_game.tscn"

signal plot_selected(plot_id: String, plot_name: String)
signal dock_selected()

@onready var hub_camera: Camera3D = %HubCamera as Camera3D
@onready var background_quad: MeshInstance3D = %BackgroundQuad as MeshInstance3D
@onready var moonlight: DirectionalLight3D = %Moonlight as DirectionalLight3D
@onready var dock_anchor: Marker3D = %DockAnchor as Marker3D
@onready var dock_area: Area3D = %DockArea as Area3D

@onready var plot_forge: BuildingPlot = %Plot_Forge as BuildingPlot
@onready var plot_tavern: BuildingPlot = %Plot_Tavern as BuildingPlot
@onready var plot_chart_house: BuildingPlot = %Plot_ChartHouse as BuildingPlot
@onready var plot_expansion: BuildingPlot = %Plot_Expansion as BuildingPlot

var all_plots: Array[BuildingPlot] = []
var _flagship_mesh: Node3D = null
var _dock_bob_tween: Tween = null
var _maiden_voyage_prompt: CanvasLayer = null

const DINGHY_FALLBACK_MESH: PackedScene = preload("res://assets/models/user/vessels/dinghy.glb")

func _ready() -> void:
	_collect_plots()
	_connect_plot_signals()
	_setup_dock_interaction()
	_setup_docked_flagship()
	refresh_feature_unlocks()
	_listen_to_game_state()
	_check_maiden_voyage_prompt()

func _collect_plots() -> void:
	all_plots.clear()
	if plot_forge:
		all_plots.append(plot_forge)
	if plot_tavern:
		all_plots.append(plot_tavern)
	if plot_chart_house:
		all_plots.append(plot_chart_house)
	if plot_expansion:
		all_plots.append(plot_expansion)

func _connect_plot_signals() -> void:
	for plot: BuildingPlot in all_plots:
		if not plot:
			continue
		if not plot.plot_clicked.is_connected(_on_plot_clicked):
			plot.plot_clicked.connect(_on_plot_clicked)
		if not plot.plot_hover_changed.is_connected(_on_plot_hover_changed):
			plot.plot_hover_changed.connect(_on_plot_hover_changed)

func _get_game_state() -> Node:
	if has_node("/root/GameState"):
		return get_node("/root/GameState")
	return null

func _listen_to_game_state() -> void:
	var gs: Node = _get_game_state()
	if gs:
		if gs.has_signal("tutorial_step_changed") and not gs.is_connected("tutorial_step_changed", Callable(self, "_on_progression_changed")):
			gs.connect("tutorial_step_changed", Callable(self, "_on_progression_changed"))
		if gs.has_signal("level_completed") and not gs.is_connected("level_completed", Callable(self, "_on_level_completed")):
			gs.connect("level_completed", Callable(self, "_on_level_completed"))
		if gs.has_signal("active_vessel_changed") and not gs.is_connected("active_vessel_changed", Callable(self, "_on_active_vessel_changed")):
			gs.connect("active_vessel_changed", Callable(self, "_on_active_vessel_changed"))

func _on_progression_changed(_step: int) -> void:
	refresh_feature_unlocks()
	_check_maiden_voyage_prompt()

func _on_level_completed(_doubloons: int, _targets: int) -> void:
	refresh_feature_unlocks()

func _on_active_vessel_changed(_ship_id: String) -> void:
	_setup_docked_flagship()

## Evaluates GameState progression to determine which buildings are built & unlocked.
func refresh_feature_unlocks() -> void:
	var forge_unlocked: bool = is_feature_unlocked("forge")
	var tavern_unlocked: bool = is_feature_unlocked("tavern")
	var chart_house_unlocked: bool = is_feature_unlocked("chart_house")
	var expansion_unlocked: bool = is_feature_unlocked("expansion")

	set_plot_unlocked("forge", forge_unlocked)
	set_plot_unlocked("tavern", tavern_unlocked)
	set_plot_unlocked("chart_house", chart_house_unlocked)
	set_plot_unlocked("expansion", expansion_unlocked)

## Returns true only if the user has progressed far enough to open the given feature.
func is_feature_unlocked(feature_id: String) -> bool:
	var gs: Node = _get_game_state()
	if not gs:
		return false

	var highest_lvl: int = 1
	if "highest_unlocked_level" in gs:
		highest_lvl = int(gs.get("highest_unlocked_level"))
	elif gs.has_method("get_highest_level_unlocked"):
		highest_lvl = int(gs.call("get_highest_level_unlocked"))

	var is_tut: bool = false
	var tut_step: int = 0
	if gs.has_method("is_tutorial_in_progress"):
		is_tut = bool(gs.call("is_tutorial_in_progress"))
	if "tutorial_step" in gs:
		tut_step = int(gs.get("tutorial_step"))
	elif "current_tutorial_step" in gs:
		tut_step = int(gs.get("current_tutorial_step"))

	match feature_id:
		"chart_house", "campaign":
			# Chart House / Campaign River unlocks after Level 1 is beaten
			if is_tut:
				return tut_step >= 2 or highest_lvl >= 2
			return highest_lvl >= 2
		"forge", "drydock", "shipyard":
			# Drydock & Forge unlocks after Level 2 is completed
			if is_tut:
				return tut_step >= 4 or highest_lvl >= 3
			return highest_lvl >= 3
		"tavern", "endless", "skull_outpost":
			# Tavern / Endless mode unlocks after Level 4 / Tier 2 upgrade or Level 5
			if is_tut:
				return tut_step >= 11 or highest_lvl >= 5
			return highest_lvl >= 5
		"expansion":
			# Future expansion lot remains a clear lot until future feature release
			return false
		_:
			return false

func _setup_docked_flagship() -> void:
	if not dock_anchor:
		return

	if _dock_bob_tween and _dock_bob_tween.is_valid():
		_dock_bob_tween.kill()

	if _flagship_mesh and is_instance_valid(_flagship_mesh):
		_flagship_mesh.queue_free()
		_flagship_mesh = null

	var pivot := Node3D.new()
	pivot.name = "DockedFlagship"
	dock_anchor.add_child(pivot)
	_flagship_mesh = pivot

	var mesh_scene: PackedScene = DINGHY_FALLBACK_MESH
	var scale_mult: float = 0.55

	var gs: Node = _get_game_state()
	if gs and gs.has_method("get_active_ship_resource"):
		var ship: Resource = gs.call("get_active_ship_resource") as Resource
		if ship and "model_scene" in ship and ship.get("model_scene"):
			mesh_scene = ship.get("model_scene") as PackedScene

	if mesh_scene:
		var ship_inst: Node3D = mesh_scene.instantiate() as Node3D
		if ship_inst:
			ship_inst.name = "ShipInstance"
			ship_inst.scale = Vector3(scale_mult, scale_mult, scale_mult)
			pivot.add_child(ship_inst)

	_start_dock_bobbing(pivot)

func _start_dock_bobbing(pivot_node: Node3D) -> void:
	var base_y: float = pivot_node.position.y
	_dock_bob_tween = create_tween().set_loops()
	_dock_bob_tween.tween_property(pivot_node, "position:y", base_y + 0.04, 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_dock_bob_tween.tween_property(pivot_node, "position:y", base_y - 0.04, 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _setup_dock_interaction() -> void:
	if not dock_area:
		return
	if not dock_area.input_event.is_connected(_on_dock_input_event):
		dock_area.input_event.connect(_on_dock_input_event)

func _on_dock_input_event(_camera: Camera3D, event: InputEvent, _pos: Vector3, _norm: Vector3, _shape_idx: int) -> void:
	var activated: bool = false
	if event is InputEventMouseButton:
		var mouse_ev: InputEventMouseButton = event as InputEventMouseButton
		if mouse_ev.button_index == MOUSE_BUTTON_LEFT and mouse_ev.pressed:
			activated = true
	elif event is InputEventScreenTouch:
		var touch_ev: InputEventScreenTouch = event as InputEventScreenTouch
		if touch_ev.pressed:
			activated = true

	if activated:
		_on_dock_activated()

func _on_dock_activated() -> void:
	dock_selected.emit()
	var gs: Node = _get_game_state()
	var tut_step: int = 0
	if gs and "tutorial_step" in gs:
		tut_step = int(gs.get("tutorial_step"))

	if tut_step <= 1:
		# Start maiden voyage / tutorial
		if gs:
			gs.call("select_level", 1)
			gs.set("should_auto_start", true)
			gs.set("should_auto_start_endless", false)
			gs.call("reset_level")
			gs.call("advance_tutorial_to", 1)
			gs.call("change_scene_with_loading", MAIN_GAME_PATH, "Smuggler's Run (Tutorial)")
	else:
		_open_river_map()

func _check_maiden_voyage_prompt() -> void:
	var gs: Node = _get_game_state()
	var tut_step: int = int(gs.get("tutorial_step")) if gs and "tutorial_step" in gs else 0
	if tut_step > 0:
		if _maiden_voyage_prompt and is_instance_valid(_maiden_voyage_prompt):
			_maiden_voyage_prompt.queue_free()
			_maiden_voyage_prompt = null
		return

	if _maiden_voyage_prompt and is_instance_valid(_maiden_voyage_prompt):
		return

	var canvas := CanvasLayer.new()
	canvas.name = "MaidenVoyagePromptLayer"
	canvas.layer = 20
	add_child(canvas)

	var prompt_container := PanelContainer.new()
	prompt_container.name = "MaidenVoyagePrompt"
	prompt_container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.07, 0.04, 0.90)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.96, 0.72, 0.22, 0.95)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_right = 14
	style.corner_radius_bottom_left = 14
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	style.shadow_color = Color(0, 0, 0, 0.6)
	style.shadow_size = 6
	prompt_container.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = "⚓ TAP DINGHY TO EMBARK ON YER MAIDEN VOYAGE! ⚓"
	label.add_theme_font_override("font", preload("res://assets/fonts/CarterOne.ttf"))
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35, 1.0))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_container.add_child(label)

	canvas.add_child(prompt_container)
	_maiden_voyage_prompt = canvas

	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	prompt_container.custom_minimum_size = Vector2(360, 46)
	prompt_container.position = Vector2((vp_size.x - 360.0) * 0.5, vp_size.y * 0.76)
	prompt_container.pivot_offset = Vector2(180, 23)

	var t: Tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(prompt_container, "scale", Vector2(1.04, 1.04), 0.6)
	t.tween_property(prompt_container, "scale", Vector2.ONE, 0.6)

func _open_river_map() -> void:
	if has_node("RiverMapLayer"):
		var existing: CanvasLayer = get_node("RiverMapLayer") as CanvasLayer
		if existing:
			existing.visible = true
			return

	var layer := CanvasLayer.new()
	layer.name = "RiverMapLayer"
	layer.layer = 50
	add_child(layer)

	var map_inst: RiverMap = RIVER_MAP_SCENE.instantiate() as RiverMap
	layer.add_child(map_inst)
	map_inst.sail_requested.connect(_on_sail_requested)
	map_inst.cove_requested.connect(func() -> void:
		layer.queue_free()
	)

func _open_shipyard() -> void:
	for child: Node in get_children():
		if child is ShipyardUI and not child.is_queued_for_deletion():
			return

	var shipyard_inst: ShipyardUI = SHIPYARD_SCENE.instantiate() as ShipyardUI
	add_child(shipyard_inst)
	shipyard_inst.shipyard_closed.connect(func() -> void:
		_setup_docked_flagship()
		refresh_feature_unlocks()
	)

func _launch_endless_mode() -> void:
	var gs: Node = _get_game_state()
	if gs:
		gs.set("should_auto_start", false)
		gs.set("should_auto_start_endless", true)
		gs.call("reset_level")
		gs.call("change_scene_with_loading", MAIN_GAME_PATH, "Endless Skull Outpost")

func _on_sail_requested(level_num: int) -> void:
	var gs: Node = _get_game_state()
	if gs:
		gs.call("select_level", level_num)
		gs.set("should_auto_start", true)
		gs.set("should_auto_start_endless", false)
		gs.call("reset_level")
		var lvl_name: String = str(gs.call("get_level_display_name", level_num))
		gs.call("change_scene_with_loading", MAIN_GAME_PATH, lvl_name)

func _on_plot_clicked(plot: BuildingPlot) -> void:
	print("[CoveHub] Clicked plot: %s ('%s', unlocked=%s)" % [plot.plot_id, plot.display_name, plot.is_unlocked])
	plot_selected.emit(plot.plot_id, plot.display_name)
	if not plot.is_unlocked:
		_show_locked_hint(plot)
		return

	match plot.plot_id:
		"chart_house":
			_open_river_map()
		"forge":
			_open_shipyard()
		"tavern":
			_launch_endless_mode()

func _show_locked_hint(plot: BuildingPlot) -> void:
	match plot.plot_id:
		"forge":
			print("[CoveHub] Drydock & Forge unlocks after completing River Level 2!")
		"tavern":
			print("[CoveHub] Tavern & Inn unlocks at River Level 5!")
		"expansion":
			print("[CoveHub] Construction Plot: Future cove expansion lot.")

func _on_plot_hover_changed(plot: BuildingPlot, is_hovered: bool) -> void:
	if is_hovered:
		print("[CoveHub] Hovering over: %s ('%s', unlocked=%s)" % [plot.plot_id, plot.display_name, plot.is_unlocked])

func get_plot_by_id(target_id: String) -> BuildingPlot:
	for plot: BuildingPlot in all_plots:
		if plot and plot.plot_id == target_id:
			return plot
	return null

func set_plot_unlocked(target_id: String, unlocked: bool) -> void:
	var plot: BuildingPlot = get_plot_by_id(target_id)
	if plot:
		plot.set_unlocked_state(unlocked)

func set_plot_building_scene(target_id: String, scene: PackedScene) -> void:
	var plot: BuildingPlot = get_plot_by_id(target_id)
	if plot:
		plot.building_scene = scene
