class_name CoveMainHub
extends Node3D

## Cove Main Hub 2.5D Orchestrator.
## Combines a painted 2D cove backdrop locked to the Camera3D with interactive
## 3D modular building plots, lighting matching the backdrop sun/torches,
## and a dedicated vessel dock anchor.

const BuildingPlot = preload("res://scenes/cove_hub/building_plot.gd")

signal plot_selected(plot_id: String, plot_name: String)
signal dock_selected()

@onready var hub_camera: Camera3D = %HubCamera as Camera3D
@onready var background_quad: MeshInstance3D = %BackgroundQuad as MeshInstance3D
@onready var moonlight: DirectionalLight3D = %Moonlight as DirectionalLight3D
@onready var dock_anchor: Marker3D = %DockAnchor as Marker3D

@onready var plot_forge: BuildingPlot = %Plot_Forge as BuildingPlot
@onready var plot_tavern: BuildingPlot = %Plot_Tavern as BuildingPlot
@onready var plot_chart_house: BuildingPlot = %Plot_ChartHouse as BuildingPlot
@onready var plot_expansion: BuildingPlot = %Plot_Expansion as BuildingPlot

var all_plots: Array[BuildingPlot] = []
var _flagship_mesh: Node3D = null
var _dock_bob_tween: Tween = null

const DINGHY_FALLBACK_MESH: PackedScene = preload("res://assets/models/user/vessels/dinghy.glb")

func _ready() -> void:
	_collect_plots()
	_connect_plot_signals()
	_setup_docked_flagship()
	refresh_feature_unlocks()
	_listen_to_game_state()

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

func _listen_to_game_state() -> void:
	if Engine.has_singleton("GameState"):
		var gs: Node = Engine.get_singleton("GameState")
		if gs.has_signal("tutorial_step_changed"):
			gs.connect("tutorial_step_changed", Callable(self, "_on_progression_changed"))
		if gs.has_signal("level_completed"):
			gs.connect("level_completed", Callable(self, "_on_level_completed"))
		if gs.has_signal("active_vessel_changed"):
			gs.connect("active_vessel_changed", Callable(self, "_on_active_vessel_changed"))

func _on_progression_changed(_step: int) -> void:
	refresh_feature_unlocks()

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
	if not Engine.has_singleton("GameState"):
		return false

	var gs: Node = Engine.get_singleton("GameState")
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
	if "current_tutorial_step" in gs:
		tut_step = int(gs.get("current_tutorial_step"))

	match feature_id:
		"chart_house", "campaign":
			# Chart House / Campaign River is the initial embarkation point
			return true
		"forge", "drydock", "shipyard":
			# Drydock & Forge unlocks after Level 2 is completed!
			if is_tut:
				return tut_step >= 4
			return highest_lvl >= 3
		"tavern", "endless", "skull_outpost":
			# Tavern / Endless mode unlocks at Level 5!
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

	if Engine.has_singleton("GameState"):
		var gs: Node = Engine.get_singleton("GameState")
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

func _on_plot_clicked(plot: BuildingPlot) -> void:
	print("[CoveHub] Clicked plot: %s ('%s', unlocked=%s)" % [plot.plot_id, plot.display_name, plot.is_unlocked])
	plot_selected.emit(plot.plot_id, plot.display_name)
	if not plot.is_unlocked:
		_show_locked_hint(plot)

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
