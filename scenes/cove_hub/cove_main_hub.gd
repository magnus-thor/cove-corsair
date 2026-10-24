class_name CoveMainHub
extends Node3D

## Cove Main Hub 2.5D Orchestrator.
## A painted 2D cove backdrop locked to a Camera3D with three interactive 3D house lots
## and a pier where the player's vessel is moored:
##   * Pier / vessel  -> starts River Levels (opens the river map).
##   * Shipyard house -> Drydock & Shipyard (vessels, crew, upgrades).
##   * Skull Outpost  -> Endless mode.
##   * Future lot     -> reserved for a future feature (stays an empty lot).
## Lots start empty. A house is "built" (animated) the first time the tutorial/progression
## directs the player to it, and the Quartermaster guides the player to enter it.

const BuildingPlot = preload("res://scenes/cove_hub/building_plot.gd")
const RIVER_MAP_SCENE: PackedScene = preload("res://src/ui/river_map.tscn")
const SHIPYARD_SCENE: PackedScene = preload("res://src/ui/shipyard/shipyard_ui.tscn")
const SETTINGS_SCENE: PackedScene = preload("res://src/ui/settings_menu.tscn")
const GUIDANCE_SCENE: PackedScene = preload("res://src/ui/tutorial/tutorial_guidance_overlay.tscn")
const DINGHY_FALLBACK_MESH: PackedScene = preload("res://assets/models/user/vessels/dinghy.glb")
const FONT_CARTER: FontFile = preload("res://assets/fonts/CarterOne.ttf")
const MAIN_GAME_PATH: String = "res://src/core/main_game.tscn"

## Delay before houses are raised so the player first sees the empty lots.
const BUILD_START_DELAY: float = 0.6
const BUILD_SETTLE_DELAY: float = 1.2

signal plot_selected(plot_id: String, plot_name: String)
signal dock_selected()

@onready var hub_camera: Camera3D = %HubCamera as Camera3D
@onready var background_quad: MeshInstance3D = %BackgroundQuad as MeshInstance3D
@onready var moonlight: DirectionalLight3D = %Moonlight as DirectionalLight3D
@onready var dock_anchor: Marker3D = %DockAnchor as Marker3D
@onready var dock_area: Area3D = %DockArea as Area3D

@onready var plot_shipyard: BuildingPlot = %Plot_Shipyard as BuildingPlot
@onready var plot_skull_outpost: BuildingPlot = %Plot_SkullOutpost as BuildingPlot
@onready var plot_future: BuildingPlot = %Plot_Future as BuildingPlot

var all_plots: Array[BuildingPlot] = []
var hud: CoveHubHUD = null

var _flagship_mesh: Node3D = null
var _dock_bob_tween: Tween = null
var _tutorial_overlay: TutorialGuidanceOverlay = null
var _pin_layer: CanvasLayer = null
var _pins: Dictionary[String, Control] = {}
var _sequence_running: bool = false
var _active_guidance_key: String = ""
## Id of a house that was raised during this visit and the player has not entered yet.
var _fresh_house_id: String = ""
var _river_map_layer: CanvasLayer = null
var _river_map: RiverMap = null

func _ready() -> void:
	# Required so the Area3D lots / pier receive mouse + touch (emulated mouse) clicks.
	get_viewport().physics_object_picking = true

	GameState.check_and_fast_forward_tutorial()
	_collect_plots()
	_connect_plot_signals()
	_setup_dock_interaction()
	_setup_docked_flagship()
	_setup_hud()
	_setup_guide_pins()
	_restore_built_houses()
	_listen_to_game_state()

	if GameState.should_open_map:
		GameState.should_open_map = false
		_open_river_map()

	_run_hub_sequence()

func _process(_delta: float) -> void:
	_update_guide_pins()

# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

func _collect_plots() -> void:
	all_plots.clear()
	for plot: BuildingPlot in [plot_shipyard, plot_skull_outpost, plot_future]:
		if plot:
			all_plots.append(plot)

func _connect_plot_signals() -> void:
	for plot: BuildingPlot in all_plots:
		if not plot.plot_clicked.is_connected(_on_plot_clicked):
			plot.plot_clicked.connect(_on_plot_clicked)
		if not plot.plot_hover_changed.is_connected(_on_plot_hover_changed):
			plot.plot_hover_changed.connect(_on_plot_hover_changed)

func _setup_hud() -> void:
	hud = CoveHubHUD.new()
	hud.name = "CoveHubHUD"
	add_child(hud)
	hud.settings_pressed.connect(_on_settings_pressed)

func _setup_guide_pins() -> void:
	_pin_layer = CanvasLayer.new()
	_pin_layer.name = "GuidePins"
	_pin_layer.layer = 5
	add_child(_pin_layer)
	_pins["dock"] = _create_pin("PinDock", Vector2(220.0, 130.0))
	_pins["shipyard"] = _create_pin("PinShipyard", Vector2(170.0, 170.0))
	_pins["skull_outpost"] = _create_pin("PinSkullOutpost", Vector2(170.0, 170.0))

## Screen-space Controls that mirror 3D objects (pier, houses). They serve two purposes:
## the 2D tutorial overlay spotlights them, and they are the primary tap targets for the
## pier and the houses (so taps work identically for mouse, touch and tests).
func _create_pin(pin_name: String, pin_size: Vector2) -> Control:
	var pin: Control = Control.new()
	pin.name = pin_name
	pin.size = pin_size
	pin.mouse_filter = Control.MOUSE_FILTER_STOP
	pin.gui_input.connect(_on_pin_gui_input.bind(pin_name))
	_pin_layer.add_child(pin)
	return pin

func _on_pin_gui_input(event: InputEvent, pin_name: String) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_ev: InputEventMouseButton = event as InputEventMouseButton
	if mouse_ev.button_index != MOUSE_BUTTON_LEFT or not mouse_ev.pressed:
		return
	match pin_name:
		"PinDock":
			_on_dock_activated()
		"PinShipyard":
			plot_shipyard.press()
		"PinSkullOutpost":
			plot_skull_outpost.press()

func _update_guide_pins() -> void:
	if not hub_camera or not _pin_layer:
		return
	_place_pin("dock", dock_anchor.global_position)
	_place_pin("shipyard", plot_shipyard.global_position + Vector3(0.0, 0.5, 0.0))
	_place_pin("skull_outpost", plot_skull_outpost.global_position + Vector3(0.0, 0.5, 0.0))

func _place_pin(pin_id: String, world_pos: Vector3) -> void:
	var pin: Control = _pins.get(pin_id) as Control
	if not pin:
		return
	var screen_pos: Vector2 = hub_camera.unproject_position(world_pos)
	pin.position = screen_pos - pin.size * 0.5

# ---------------------------------------------------------------------------
# Progression -> which houses exist
# ---------------------------------------------------------------------------

func _listen_to_game_state() -> void:
	if not GameState.tutorial_step_changed.is_connected(_on_progression_changed):
		GameState.tutorial_step_changed.connect(_on_progression_changed)
	if not GameState.level_completed.is_connected(_on_level_completed):
		GameState.level_completed.connect(_on_level_completed)
	if not GameState.active_vessel_changed.is_connected(_on_active_vessel_changed):
		GameState.active_vessel_changed.connect(_on_active_vessel_changed)

func _on_progression_changed(_step: int) -> void:
	_run_hub_sequence()

func _on_level_completed(_doubloons: int, _targets: int) -> void:
	_run_hub_sequence()

func _on_active_vessel_changed(_ship_id: String) -> void:
	_setup_docked_flagship()

## Returns true once progression has reached the point where the given house should exist.
func is_feature_unlocked(feature_id: String) -> bool:
	var highest_lvl: int = GameState.highest_unlocked_level
	var step: int = GameState.tutorial_step
	match feature_id:
		"shipyard", "forge", "drydock":
			# Raised right after River Level 2, when the tutorial sends the player to buy the Sloop.
			return step >= GameState.TutorialStep.LEVEL_2_COMPLETED or highest_lvl >= 3
		"skull_outpost", "endless":
			# Raised when the player suffers their first sinking/loss (guaranteed on Level 6/7).
			return GameState.first_loss_occurred and GameState.highest_unlocked_level >= 5
		_:
			# "future" and anything unknown stays an empty lot.
			return false

## Houses that were already built on an earlier visit simply appear (no animation).
func _restore_built_houses() -> void:
	for plot: BuildingPlot in all_plots:
		if GameState.is_hub_building_built(plot.plot_id) and is_feature_unlocked(plot.plot_id):
			plot.set_unlocked_state(true)

## Raises every house that is now eligible but has never been built, with the build animation.
## Returns the plots that were built.
func _build_pending_houses() -> Array[BuildingPlot]:
	var built: Array[BuildingPlot] = []
	for plot: BuildingPlot in all_plots:
		if plot.is_unlocked:
			continue
		if not is_feature_unlocked(plot.plot_id):
			continue
		if GameState.is_hub_building_built(plot.plot_id):
			plot.set_unlocked_state(true)
			continue
		plot.play_build_animation()
		GameState.mark_hub_building_built(plot.plot_id)
		_fresh_house_id = plot.plot_id
		built.append(plot)
	return built

func _run_hub_sequence() -> void:
	if _sequence_running:
		return
	_sequence_running = true
	if not _has_pending_houses():
		_sequence_running = false
		_check_tutorial_guidance()
		return

	await get_tree().create_timer(BUILD_START_DELAY).timeout
	var built: Array[BuildingPlot] = _build_pending_houses()
	if not built.is_empty():
		await get_tree().create_timer(BUILD_SETTLE_DELAY).timeout
	_sequence_running = false
	_check_tutorial_guidance()

func _has_pending_houses() -> bool:
	for plot: BuildingPlot in all_plots:
		if not plot.is_unlocked and is_feature_unlocked(plot.plot_id):
			return true
	return false

# ---------------------------------------------------------------------------
# Quartermaster tutorial guidance
# ---------------------------------------------------------------------------

## Returns {"target": pin id, "text": String, "voice": String} for the current tutorial step,
## or an empty Dictionary when nothing should be shown.
func get_guidance_config() -> Dictionary:
	match GameState.tutorial_step:
		GameState.TutorialStep.NOT_STARTED, GameState.TutorialStep.LEVEL_1_IN_PROGRESS:
			return {
				"target": "dock",
				"text": "Ahoy, Captain! Tap yer vessel at the pier to set sail on yer first voyage!",
				"voice": "",
			}
		GameState.TutorialStep.LEVEL_1_COMPLETED:
			return {
				"target": "dock",
				"text": "First voyage survived! Chart your course for River Level 2!",
				"voice": "tut_hub_open_charthouse_lvl2",
			}
		GameState.TutorialStep.LEVEL_2_COMPLETED:
			return {
				"target": "shipyard",
				"text": "Well rowed, Captain! But that rowboat won't survive the open waters ahead. To the Drydock! Commission THE SLOOP!",
				"voice": "tut_hub_open_drydock",
			}
		GameState.TutorialStep.SLOOP_PURCHASED:
			return {
				"target": "dock",
				"text": "The Sloop is rigged and ready! Chart a course for River Level 3!",
				"voice": "tut_hub_open_map_lvl3",
			}
		GameState.TutorialStep.LEVEL_3_COMPLETED:
			return {
				"target": "shipyard",
				"text": "Every flagship needs a salty crew! To the Drydock to recruit a Monkey Bomber!",
				"voice": "tut_hub_drydock_for_crew",
			}
		GameState.TutorialStep.CREW_EQUIPPED:
			return {
				"target": "dock",
				"text": "Crew battle stations manned! Set sail on River Level 4!",
				"voice": "tut_hub_open_map_lvl4",
			}
		GameState.TutorialStep.LEVEL_4_COMPLETED:
			return {
				"target": "shipyard",
				"text": "The waters ahead are treacherous! Visit the Drydock to upgrade your Sloop to Tier 2!",
				"voice": "tut_hub_drydock_for_upgrade",
			}
		GameState.TutorialStep.SLOOP_T2_UPGRADED:
			return {
				"target": "dock",
				"text": "Your flagship is reinforced and ready! Chart a course for River Level 5 to challenge the Dreadnought!",
				"voice": "tut_hub_open_map_lvl5",
			}
		_:
			if _fresh_house_id == "skull_outpost":
				return {
					"target": "skull_outpost",
					"text": "Yer vessel was sunk by cutthroat corsairs! We need more coin and hull upgrades to survive ahead. We raised the Skull Outpost on the cliffs—venture into endless waters to plunder the gold we need!",
					"voice": "",
				}
	return {}

func _check_tutorial_guidance() -> void:
	if not is_inside_tree():
		return
	if _is_subview_active():
		_dismiss_guidance()
		return

	var config: Dictionary = get_guidance_config()
	if config.is_empty():
		_dismiss_guidance()
		return

	# A target house must exist before the player is pointed at it.
	var target_id: String = str(config["target"])
	if target_id != "dock":
		var target_plot: BuildingPlot = get_plot_by_id(target_id)
		if not target_plot or not target_plot.is_unlocked:
			_dismiss_guidance()
			return

	var guidance_key: String = "%d:%s:%s" % [GameState.tutorial_step, target_id, _fresh_house_id]
	if guidance_key == _active_guidance_key and _tutorial_overlay and is_instance_valid(_tutorial_overlay) and _tutorial_overlay.visible:
		return

	if not _tutorial_overlay or not is_instance_valid(_tutorial_overlay):
		_tutorial_overlay = GUIDANCE_SCENE.instantiate() as TutorialGuidanceOverlay
		add_child(_tutorial_overlay)

	var pin: Control = _pins.get(target_id) as Control
	if not pin:
		return
	_update_guide_pins()
	_active_guidance_key = guidance_key
	_tutorial_overlay.guide_to(pin, str(config["text"]), Vector2.UP, "QUARTERMASTER", str(config["voice"]))

func _dismiss_guidance() -> void:
	_active_guidance_key = ""
	if _tutorial_overlay and is_instance_valid(_tutorial_overlay):
		_tutorial_overlay.dismiss()

func _is_subview_active() -> bool:
	if _river_map_layer and is_instance_valid(_river_map_layer):
		return true
	for child: Node in get_children():
		if child is ShipyardUI and not child.is_queued_for_deletion():
			return true
	return false

# ---------------------------------------------------------------------------
# Pier / vessel  (river levels)
# ---------------------------------------------------------------------------

func _setup_dock_interaction() -> void:
	if dock_area and not dock_area.input_event.is_connected(_on_dock_input_event):
		dock_area.input_event.connect(_on_dock_input_event)

func _on_dock_input_event(_camera: Camera3D, event: InputEvent, _pos: Vector3, _norm: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		var mouse_ev: InputEventMouseButton = event as InputEventMouseButton
		if mouse_ev.button_index == MOUSE_BUTTON_LEFT and mouse_ev.pressed:
			_on_dock_activated()

func _on_dock_activated() -> void:
	dock_selected.emit()
	_dismiss_guidance()
	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("gate_passes")

	if GameState.tutorial_step <= GameState.TutorialStep.LEVEL_1_IN_PROGRESS:
		# Maiden voyage: straight into River Level 1.
		_sail_to_level(1)
	else:
		_open_river_map()

func _open_river_map() -> void:
	if _river_map_layer and is_instance_valid(_river_map_layer):
		return

	_river_map_layer = CanvasLayer.new()
	_river_map_layer.name = "RiverMapLayer"
	_river_map_layer.layer = 20
	add_child(_river_map_layer)

	_river_map = RIVER_MAP_SCENE.instantiate() as RiverMap
	_river_map_layer.add_child(_river_map)
	_river_map.sail_requested.connect(_sail_to_level)
	_river_map.level_selected.connect(_on_level_selected)
	_river_map.cove_requested.connect(_close_river_map)

	var back_btn: Button = Button.new()
	back_btn.name = "BtnCloseRiverMap"
	back_btn.text = "⮌ BACK TO COVE"
	back_btn.position = Vector2(22.0, 22.0)
	back_btn.custom_minimum_size = Vector2(180, 52)
	back_btn.add_theme_font_override("font", FONT_CARTER)
	back_btn.add_theme_font_size_override("font_size", 17)
	back_btn.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	var back_style: StyleBoxFlat = StyleBoxFlat.new()
	back_style.bg_color = Color(0.08, 0.14, 0.22, 0.92)
	back_style.set_border_width_all(2)
	back_style.border_color = Color(0.4, 0.75, 0.95, 0.9)
	back_style.set_corner_radius_all(12)
	for state: String in ["normal", "pressed", "hover", "focus"]:
		back_btn.add_theme_stylebox_override(state, back_style)
	back_btn.pressed.connect(_close_river_map)
	_river_map_layer.add_child(back_btn)

	_river_map.call("_setup_mini_vessel")
	_river_map.call("_check_tutorial_guidance")

func _close_river_map() -> void:
	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("gate_passes", 0.9, 1.0)
	if _river_map and is_instance_valid(_river_map):
		_river_map.dismiss_tutorial_guidance()
	if _river_map_layer and is_instance_valid(_river_map_layer):
		_river_map_layer.queue_free()
	_river_map_layer = null
	_river_map = null
	call_deferred("_check_tutorial_guidance")

func _on_level_selected(level_num: int) -> void:
	GameState.select_level(level_num)

func _sail_to_level(level_num: int) -> void:
	GameState.select_level(level_num)
	GameState.should_auto_start = true
	GameState.should_auto_start_endless = false
	GameState.reset_level()
	if level_num <= 1 and GameState.tutorial_step < GameState.TutorialStep.LEVEL_1_IN_PROGRESS:
		GameState.advance_tutorial_to(GameState.TutorialStep.LEVEL_1_IN_PROGRESS)
	GameState.change_scene_with_loading(MAIN_GAME_PATH, GameState.get_level_display_name(level_num))

# ---------------------------------------------------------------------------
# Houses
# ---------------------------------------------------------------------------

func _on_plot_clicked(plot: BuildingPlot) -> void:
	plot_selected.emit(plot.plot_id, plot.display_name)
	if not plot.is_unlocked:
		_show_locked_hint(plot)
		return

	_dismiss_guidance()
	if _fresh_house_id == plot.plot_id:
		_fresh_house_id = ""
	match plot.plot_id:
		"shipyard":
			_open_shipyard()
		"skull_outpost":
			_launch_endless_mode()

func _show_locked_hint(plot: BuildingPlot) -> void:
	var hint: String = ""
	match plot.plot_id:
		"shipyard":
			hint = "The Drydock & Shipyard will be built after River Level 2!"
		"skull_outpost":
			hint = "The Skull Outpost will be built once you test your mettle against tougher waters!"
		"future":
			hint = "This lot is reserved for a future building."
	if hud and not hint.is_empty():
		hud.show_toast(hint)

func _open_shipyard() -> void:
	for child: Node in get_children():
		if child is ShipyardUI and not child.is_queued_for_deletion():
			return

	var shipyard_inst: ShipyardUI = SHIPYARD_SCENE.instantiate() as ShipyardUI
	add_child(shipyard_inst)
	shipyard_inst.shipyard_closed.connect(func() -> void:
		_setup_docked_flagship()
		if hud:
			hud.refresh()
		call_deferred("_check_tutorial_guidance")
	)

func _launch_endless_mode() -> void:
	GameState.should_auto_start = false
	GameState.should_auto_start_endless = true
	GameState.reset_level()
	GameState.change_scene_with_loading(MAIN_GAME_PATH, "Endless Skull Outpost")

func _on_plot_hover_changed(_plot: BuildingPlot, _is_hovered: bool) -> void:
	pass

func _on_settings_pressed() -> void:
	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("gate_passes")
	var settings_node: CanvasLayer = SETTINGS_SCENE.instantiate() as CanvasLayer
	if settings_node:
		add_child(settings_node)

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

# ---------------------------------------------------------------------------
# Docked vessel
# ---------------------------------------------------------------------------

func _setup_docked_flagship() -> void:
	if not dock_anchor:
		return

	if _dock_bob_tween and _dock_bob_tween.is_valid():
		_dock_bob_tween.kill()

	if _flagship_mesh and is_instance_valid(_flagship_mesh):
		dock_anchor.remove_child(_flagship_mesh)
		_flagship_mesh.queue_free()
		_flagship_mesh = null

	var pivot: Node3D = Node3D.new()
	pivot.name = "DockedFlagship"
	dock_anchor.add_child(pivot)
	_flagship_mesh = pivot

	var mesh_scene: PackedScene = DINGHY_FALLBACK_MESH
	var scale_mult: float = 0.55

	var ship: ShipData = GameState.get_active_ship_resource()
	if ship and ship.model_scene:
		mesh_scene = ship.model_scene

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
