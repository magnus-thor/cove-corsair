class_name PirateLairHub
extends Control

## Pirate Lair Hub (Smuggler's Cove) Orchestrator.
## Full-screen 2D nocturnal pirate cove with interactive building hotspot pins
## and an overlaid 3D docked flagship bobbing in the foreground water pocket.

# 2D Interactive Building Hotspot Pins
@onready var hotspot_chart_house: LairHotspotArea = %HotspotChartHouse as LairHotspotArea
@onready var hotspot_skull_outpost: LairHotspotArea = %HotspotSkullOutpost as LairHotspotArea
@onready var hotspot_drydock: LairHotspotArea = %HotspotDrydock as LairHotspotArea

# Quick-HUD header nodes
@onready var doubloons_label: Label = %DoubloonsLabel as Label
@onready var vessel_badge_label: Label = %VesselBadgeLabel as Label
@onready var btn_settings: BaseButton = %BtnSettings as BaseButton
@onready var btn_calibrate: BaseButton = %BtnCalibrate as BaseButton

# 3D Showcase Nodes in the Water Pocket
@onready var basin_flagship_anchor: Node3D = %BasinFlagshipAnchor as Node3D
@onready var flagship_click_area: Control = %FlagshipClickArea as Control
@onready var flagship_tag_label: Label = %FlagshipTagLabel as Label

# River Map Overlay & Back Button
@onready var river_map_layer: CanvasLayer = %RiverMapLayer as CanvasLayer
@onready var river_map_instance: Control = %RiverMapInstance as Control
@onready var btn_close_river_map: Button = %BtnCloseRiverMap as Button

const WAKE_SCENE: PackedScene = preload("res://src/vfx/boat_wake.tscn")
const SHIPYARD_SCENE: PackedScene = preload("res://src/ui/shipyard/shipyard_ui.tscn")
const SETTINGS_SCENE: PackedScene = preload("res://src/ui/settings_menu.tscn")
const CALIBRATION_PANEL_SCENE: PackedScene = preload("res://src/features/hub/harbor_calibration_panel.tscn")
const GUIDANCE_SCENE: PackedScene = preload("res://src/ui/tutorial/tutorial_guidance_overlay.tscn")
const MAIN_GAME_PATH: String = "res://src/core/main_game.tscn"

const WATERLINE_ELEVATION_OFFSET: float = 0.35

## Default calibrated harbor dock configuration per vessel.
## Angles (pitch, yaw, roll) are applied to the harbor pivot node while the child
## ship model preserves its canonical game baseline orientation and y_offset.
var harbor_dock_configs: Dictionary = {
	"dinghy": {
		"pitch": 14.00,
		"yaw": 11.00,
		"roll": 0.00,
		"waterline_y": 0.420,
		"scale_mult": 0.430,
		"offset_x": 0.000,
		"offset_z": 0.000,
	},
	"sloop": {
		"pitch": 13.00,
		"yaw": 12.00,
		"roll": 7.00,
		"waterline_y": 0.450,
		"scale_mult": 0.640,
		"offset_x": 0.140,
		"offset_z": 0.000,
	},
	"ironclad": {
		"pitch": 23.00,
		"yaw": 12.00,
		"roll": 0.00,
		"waterline_y": 0.460,
		"scale_mult": 0.570,
		"offset_x": 0.320,
		"offset_z": -0.220,
	},
	"bombard_skiff": {
		"pitch": 22.50,
		"yaw": 11.00,
		"roll": 0.00,
		"waterline_y": 0.260,
		"scale_mult": 0.450,
		"offset_x": 0.240,
		"offset_z": -1.480,
	},

}

var _current_flagship_mesh: Node3D = null
var _flagship_wake: Node3D = null
var _bob_tween: Tween = null
var _calibration_panel: HarborCalibrationPanel = null
var _tutorial_overlay: TutorialGuidanceOverlay = null

func _ready() -> void:
	GameState.set_performance_mode(false)
	GameState.is_game_active = false

	_setup_building_pins()
	_setup_hud_buttons()
	_setup_flagship_interaction()
	_setup_river_map()
	_refresh_docked_flagship()
	_update_hud_display()

	# Auto-open the river map if requested (e.g. from settlement screen "Level Map" button).
	if GameState.should_open_map:
		GameState.should_open_map = false
		_open_campaign_map()

	GameState.active_vessel_changed.connect(_on_active_vessel_changed)
	GameState.doubloons_changed.connect(_on_doubloons_changed)
	GameState.tutorial_step_changed.connect(func(_s: int) -> void: _check_tutorial_guidance())

	if AudioManager and AudioManager.has_method("play_music"):
		AudioManager.play_music()

	_check_tutorial_guidance()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_ev := event as InputEventKey
		if key_ev.pressed and not key_ev.echo and key_ev.keycode == KEY_C:
			_toggle_calibration_panel()

func _setup_building_pins() -> void:
	if hotspot_chart_house:
		hotspot_chart_house.hotspot_activated.connect(_on_building_activated)
		hotspot_chart_house.refresh_lock_state()

	if hotspot_skull_outpost:
		hotspot_skull_outpost.hotspot_activated.connect(_on_building_activated)
		hotspot_skull_outpost.refresh_lock_state()

	if hotspot_drydock:
		hotspot_drydock.hotspot_activated.connect(_on_building_activated)
		hotspot_drydock.refresh_lock_state()

func _setup_hud_buttons() -> void:
	if btn_settings:
		btn_settings.pressed.connect(_on_settings_pressed)

	if btn_calibrate:
		btn_calibrate.pressed.connect(_toggle_calibration_panel)

	if btn_close_river_map:
		btn_close_river_map.pressed.connect(_close_river_map)

func _setup_flagship_interaction() -> void:
	if flagship_click_area:
		flagship_click_area.gui_input.connect(_on_flagship_gui_input)

func _setup_river_map() -> void:
	if river_map_layer:
		river_map_layer.visible = false
	if river_map_instance:
		if river_map_instance.has_signal("sail_requested"):
			river_map_instance.connect("sail_requested", Callable(self, "_on_sail_requested"))
		if river_map_instance.has_signal("level_selected"):
			river_map_instance.connect("level_selected", Callable(self, "_on_level_selected"))

func _update_hud_display() -> void:
	if doubloons_label:
		doubloons_label.text = "%s DOUBLOONS" % _format_number(GameState.doubloons)

	var ship := GameState.get_active_ship_resource()
	var ship_title: String = ship.ship_name.to_upper() if ship else "THE DINGHY"
	var tier: int = GameState.get_active_ship_tier()

	if vessel_badge_label:
		vessel_badge_label.text = "%s (TIER %d)" % [ship_title, tier]

	if flagship_tag_label:
		flagship_tag_label.text = "⚓ %s" % ship_title

	if hotspot_skull_outpost:
		hotspot_skull_outpost.refresh_lock_state()

func _refresh_docked_flagship() -> void:
	if not basin_flagship_anchor:
		return

	if _bob_tween and _bob_tween.is_valid():
		_bob_tween.kill()

	if _current_flagship_mesh and is_instance_valid(_current_flagship_mesh):
		var mesh_parent: Node = _current_flagship_mesh.get_parent()
		if mesh_parent:
			mesh_parent.remove_child(_current_flagship_mesh)
		_current_flagship_mesh.queue_free()
		_current_flagship_mesh = null

	if _flagship_wake and is_instance_valid(_flagship_wake):
		var wake_parent: Node = _flagship_wake.get_parent()
		if wake_parent:
			wake_parent.remove_child(_flagship_wake)
		_flagship_wake.queue_free()
		_flagship_wake = null

	var ship := GameState.get_active_ship_resource()
	if not ship or not ship.model_scene:
		return

	# Pivot node to apply harbor docking angles cleanly in vessel-relative space
	var pivot := Node3D.new()
	pivot.name = "DockedFlagshipMesh"
	basin_flagship_anchor.add_child(pivot)
	_current_flagship_mesh = pivot

	# Inside pivot, instantiate ship model with its canonical game orientation and y_offset
	var boat_model := ship.model_scene.instantiate() as Node3D
	if not boat_model:
		return
	boat_model.name = "ShipModel"
	boat_model.position = Vector3(0.0, ship.y_offset, 0.0)
	boat_model.rotation_degrees = ship.rotation_degrees
	boat_model.scale = ship.scale
	pivot.add_child(boat_model)

	_apply_harbor_transform_to_pivot(pivot, ship.ship_id)

	if WAKE_SCENE:
		var wake_instance := WAKE_SCENE.instantiate() as Node3D
		if wake_instance:
			wake_instance.name = "CalmWaterRipples"
			wake_instance.position = Vector3(0.0, 0.02, 0.0)
			wake_instance.scale = Vector3(0.9, 0.9, 0.9)
			basin_flagship_anchor.add_child(wake_instance)
			_flagship_wake = wake_instance

	var cfg: Dictionary = harbor_dock_configs.get(ship.ship_id, {}) as Dictionary
	var base_y: float = float(cfg.get("waterline_y", 0.40))
	_start_flagship_bobbing(pivot, base_y)

func _apply_harbor_transform_to_pivot(pivot: Node3D, ship_id: String) -> void:
	if not pivot or not is_instance_valid(pivot):
		return

	var cfg: Dictionary = harbor_dock_configs.get(ship_id, {}) as Dictionary
	var p: float = float(cfg.get("pitch", 0.0))
	var y: float = float(cfg.get("yaw", -115.0))
	var r: float = float(cfg.get("roll", 0.0))
	var by: float = float(cfg.get("waterline_y", 0.40))
	var sc: float = float(cfg.get("scale_mult", 0.65))
	var ox: float = float(cfg.get("offset_x", 0.0))
	var oz: float = float(cfg.get("offset_z", 0.0))

	pivot.scale = Vector3(sc, sc, sc)
	pivot.position = Vector3(ox, by, oz)
	pivot.rotation_degrees = Vector3(p, y, r)

func _start_flagship_bobbing(target_node: Node3D, base_y: float) -> void:
	var base_rot_z: float = target_node.rotation_degrees.z
	var base_rot_x: float = target_node.rotation_degrees.x

	_bob_tween = create_tween().set_loops()
	_bob_tween.set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_bob_tween.tween_property(target_node, "position:y", base_y + 0.03, 2.2)
	_bob_tween.tween_property(target_node, "rotation_degrees:z", base_rot_z + 0.8, 2.2)
	_bob_tween.tween_property(target_node, "rotation_degrees:x", base_rot_x - 0.4, 2.2)

	_bob_tween.chain().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_bob_tween.tween_property(target_node, "position:y", base_y - 0.03, 2.2)
	_bob_tween.tween_property(target_node, "rotation_degrees:z", base_rot_z - 0.8, 2.2)
	_bob_tween.tween_property(target_node, "rotation_degrees:x", base_rot_x + 0.4, 2.2)

func _toggle_calibration_panel() -> void:
	if _calibration_panel and is_instance_valid(_calibration_panel):
		_calibration_panel.visible = not _calibration_panel.visible
		if _calibration_panel.visible:
			_calibration_panel.setup_configs(harbor_dock_configs, GameState.active_vessel)
		return

	if not CALIBRATION_PANEL_SCENE:
		return

	_calibration_panel = CALIBRATION_PANEL_SCENE.instantiate() as HarborCalibrationPanel
	if not _calibration_panel:
		return

	add_child(_calibration_panel)
	_calibration_panel.setup_configs(harbor_dock_configs, GameState.active_vessel)
	_calibration_panel.config_changed.connect(_on_calibration_config_changed)
	_calibration_panel.vessel_switch_requested.connect(_on_calibration_vessel_switch)

func _on_calibration_config_changed(ship_id: String, cfg: Dictionary) -> void:
	harbor_dock_configs[ship_id] = cfg
	if GameState.active_vessel == ship_id and _current_flagship_mesh:
		_apply_harbor_transform_to_pivot(_current_flagship_mesh, ship_id)
		if _bob_tween and _bob_tween.is_valid():
			_bob_tween.kill()
		_start_flagship_bobbing(_current_flagship_mesh, float(cfg.get("waterline_y", 0.40)))

func _on_calibration_vessel_switch(ship_id: String) -> void:
	GameState.set_active_vessel(ship_id)

func _on_building_activated(mode_id: String) -> void:
	match mode_id:
		"campaign":
			_open_campaign_map()
		"endless":
			_launch_endless_mode()
		"shipyard":
			_open_shipyard_ui()

func _on_flagship_gui_input(event: InputEvent) -> void:
	var activated: bool = false
	if event is InputEventMouseButton:
		var mouse_ev := event as InputEventMouseButton
		if mouse_ev.button_index == MOUSE_BUTTON_LEFT and mouse_ev.pressed:
			activated = true
	elif event is InputEventScreenTouch:
		var touch_ev := event as InputEventScreenTouch
		if touch_ev.pressed:
			activated = true

	if activated:
		if hotspot_drydock and hotspot_drydock.is_active_locked():
			hotspot_drydock.trigger_activation()
			return
		if AudioManager and AudioManager.has_method("play_sfx"):
			AudioManager.play_sfx("gate_passes")
		_open_shipyard_ui()

func _open_campaign_map() -> void:
	if _tutorial_overlay and is_instance_valid(_tutorial_overlay):
		_tutorial_overlay.dismiss()
	if river_map_layer:
		river_map_layer.visible = true
		river_map_layer.process_mode = Node.PROCESS_MODE_INHERIT
		if river_map_instance:
			if river_map_instance.has_method("_setup_mini_vessel"):
				river_map_instance.call("_setup_mini_vessel")
			if river_map_instance.has_method("_check_tutorial_guidance"):
				river_map_instance.call("_check_tutorial_guidance")

func _close_river_map() -> void:
	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("gate_passes", 0.9, 1.0)

	if river_map_instance and river_map_instance.has_method("dismiss_tutorial_guidance"):
		river_map_instance.call("dismiss_tutorial_guidance")
	if river_map_layer:
		river_map_layer.visible = false
	_check_tutorial_guidance()

func _on_level_selected(level_num: int) -> void:
	GameState.select_level(level_num)

func _on_sail_requested(level_num: int) -> void:
	GameState.select_level(level_num)
	GameState.should_auto_start = true
	GameState.should_auto_start_endless = false
	GameState.reset_level()
	GameState.change_scene_with_loading(MAIN_GAME_PATH, GameState.get_level_display_name(level_num))

func _launch_endless_mode() -> void:
	GameState.should_auto_start = false
	GameState.should_auto_start_endless = true
	GameState.reset_level()
	GameState.change_scene_with_loading(MAIN_GAME_PATH, "Endless Skull Outpost")

func _open_shipyard_ui() -> void:
	if not SHIPYARD_SCENE:
		return

	for child: Node in get_children():
		if child is ShipyardUI and not child.is_queued_for_deletion():
			return

	if _tutorial_overlay and is_instance_valid(_tutorial_overlay):
		_tutorial_overlay.dismiss()
	if river_map_instance and river_map_instance.has_method("dismiss_tutorial_guidance"):
		river_map_instance.call("dismiss_tutorial_guidance")

	var shipyard_node := SHIPYARD_SCENE.instantiate() as CanvasLayer
	if not shipyard_node:
		return

	add_child(shipyard_node)
	if shipyard_node.has_signal("shipyard_closed"):
		shipyard_node.connect("shipyard_closed", func() -> void:
			_refresh_docked_flagship()
			_update_hud_display()
			call_deferred("_check_tutorial_guidance")
		)
	shipyard_node.tree_exited.connect(func() -> void:
		call_deferred("_check_tutorial_guidance")
	)


func _is_subview_active() -> bool:
	if river_map_layer and river_map_layer.visible:
		return true
	for child: Node in get_children():
		if child is ShipyardUI and not child.is_queued_for_deletion():
			return true
	return false

func _check_tutorial_guidance() -> void:
	if hotspot_chart_house:
		hotspot_chart_house.refresh_lock_state()
	if hotspot_drydock:
		hotspot_drydock.refresh_lock_state()

	if not GameState.is_tutorial_in_progress() or _is_subview_active():
		if _tutorial_overlay and is_instance_valid(_tutorial_overlay):
			_tutorial_overlay.dismiss()
		return

	GameState.check_and_fast_forward_tutorial()

	if not _tutorial_overlay or not is_instance_valid(_tutorial_overlay):
		_tutorial_overlay = GUIDANCE_SCENE.instantiate() as TutorialGuidanceOverlay
		add_child(_tutorial_overlay)

	match GameState.tutorial_step:
		GameState.TutorialStep.NOT_STARTED:
			if hotspot_chart_house:
				_tutorial_overlay.guide_to(
					hotspot_chart_house,
					"Ahoy, Captain! Tap the Chart House to plot yer course and open the river roadmap!",
					Vector2.UP,
					"QUARTERMASTER",
					"tut_hub_open_charthouse"
				)
		GameState.TutorialStep.LEVEL_1_COMPLETED:
			if hotspot_chart_house:
				_tutorial_overlay.guide_to(
					hotspot_chart_house,
					"First voyage survived! Chart your course for River Level 2!",
					Vector2.UP,
					"QUARTERMASTER",
					"tut_hub_open_charthouse_lvl2"
				)
		GameState.TutorialStep.LEVEL_2_COMPLETED:
			if GameState.is_vessel_owned("sloop"):
				if GameState.active_vessel != "sloop":
					GameState.set_active_vessel("sloop")
				GameState.advance_tutorial_to(GameState.TutorialStep.SLOOP_PURCHASED)
				return
			if hotspot_drydock:
				hotspot_drydock.refresh_lock_state()
				_tutorial_overlay.guide_to(
					hotspot_drydock,
					"Well rowed, Captain! But that rowboat won't survive the open waters ahead. To the Drydock! Commission THE SLOOP!",
					Vector2.UP,
					"QUARTERMASTER",
					"tut_hub_open_drydock"
				)
		GameState.TutorialStep.SLOOP_PURCHASED:
			if hotspot_chart_house:
				_tutorial_overlay.guide_to(
					hotspot_chart_house,
					"The Sloop is rigged and ready! Chart a course for River Level 3!",
					Vector2.UP,
					"QUARTERMASTER",
					"tut_hub_open_map_lvl3"
				)
		GameState.TutorialStep.LEVEL_3_COMPLETED:
			if GameState.is_crew_unlocked("monkey_bomber"):
				if not GameState.is_crew_equipped_on_active_ship("monkey_bomber"):
					GameState.auto_equip_crew_to_vessel(GameState.active_vessel, "monkey_bomber")
				GameState.advance_tutorial_to(GameState.TutorialStep.CREW_EQUIPPED)
				return
			if hotspot_drydock:
				hotspot_drydock.refresh_lock_state()
				_tutorial_overlay.guide_to(
					hotspot_drydock,
					"Every flagship needs a salty crew! To the Drydock to recruit a Monkey Bomber!",
					Vector2.UP,
					"QUARTERMASTER",
					"tut_hub_drydock_for_crew"
				)
		GameState.TutorialStep.CREW_EQUIPPED:
			if hotspot_chart_house:
				_tutorial_overlay.guide_to(
					hotspot_chart_house,
					"Crew battle stations manned! Set sail on River Level 4!",
					Vector2.UP,
					"QUARTERMASTER",
					"tut_hub_open_map_lvl4"
				)
		GameState.TutorialStep.LEVEL_4_COMPLETED:
			if GameState.get_vessel_tier("sloop") >= 2:
				GameState.advance_tutorial_to(GameState.TutorialStep.SLOOP_T2_UPGRADED)
				return
			if hotspot_drydock:
				hotspot_drydock.refresh_lock_state()
				_tutorial_overlay.guide_to(
					hotspot_drydock,
					"The waters ahead are treacherous! Visit the Drydock to upgrade your Sloop to Tier 2!",
					Vector2.UP,
					"QUARTERMASTER",
					"tut_hub_drydock_for_upgrade"
				)
		GameState.TutorialStep.SLOOP_T2_UPGRADED:
			if hotspot_chart_house:
				_tutorial_overlay.guide_to(
					hotspot_chart_house,
					"Your flagship is reinforced and ready! Chart a course for River Level 5 to challenge the Dreadnought!",
					Vector2.UP,
					"QUARTERMASTER",
					"tut_hub_open_map_lvl5"
				)

		_:
			_tutorial_overlay.dismiss()

func _on_settings_pressed() -> void:
	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("gate_passes")
	if not SETTINGS_SCENE:
		return
	var settings_node := SETTINGS_SCENE.instantiate() as CanvasLayer
	if not settings_node:
		return
	add_child(settings_node)

func _on_active_vessel_changed(_vessel_id: String) -> void:
	_refresh_docked_flagship()
	_update_hud_display()
	if _calibration_panel and is_instance_valid(_calibration_panel) and _calibration_panel.visible:
		_calibration_panel.setup_configs(harbor_dock_configs, _vessel_id)

func _on_doubloons_changed(_amt: int) -> void:
	_update_hud_display()

func _format_number(val: int) -> String:
	var s := str(abs(val))
	var res := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		res = s[i] + res
		count += 1
		if count % 3 == 0 and i > 0:
			res = "," + res
	return res
