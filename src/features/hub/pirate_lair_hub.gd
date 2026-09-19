class_name PirateLairHub
extends Control

## Pirate Lair Hub (Smuggler's Hideout) Orchestrator.
## 2D Town Canvas (top 60%) + 3D Side-Dock Vessel Showcase (bottom 40%).

# 2D Interactive Building Hotspots
@onready var hotspot_chart_house: LairHotspotArea = %HotspotChartHouse
@onready var hotspot_skull_outpost: LairHotspotArea = %HotspotSkullOutpost
@onready var hotspot_drydock: LairHotspotArea = %HotspotDrydock

# Backwards compatibility aliases
@onready var building_chart_house: LairHotspotArea = %HotspotChartHouse
@onready var building_skull_outpost: LairHotspotArea = %HotspotSkullOutpost
@onready var building_drydock: LairHotspotArea = %HotspotDrydock

# Quick-HUD header nodes
@onready var doubloons_label: Label = %DoubloonsLabel
@onready var vessel_badge_label: Label = %VesselBadgeLabel
@onready var btn_settings: BaseButton = %BtnSettings

# 3D Showcase Anchor
@onready var basin_flagship_anchor: Node3D = %BasinFlagshipAnchor

# River Map Overlay & Back Button
@onready var river_map_layer: CanvasLayer = %RiverMapLayer
@onready var river_map_instance: Control = %RiverMapInstance
@onready var btn_close_river_map: Button = %BtnCloseRiverMap

const WAKE_SCENE: PackedScene = preload("res://src/vfx/boat_wake.tscn")
const SHIPYARD_SCENE: PackedScene = preload("res://src/ui/shipyard/shipyard_ui.tscn")
const SETTINGS_SCENE: PackedScene = preload("res://src/ui/settings_menu.tscn")
const MAIN_GAME_PATH: String = "res://src/core/main_game.tscn"

# Baseline elevation offset added to ship.y_offset to prevent dinghy / hulls sinking into water
const WATERLINE_ELEVATION_OFFSET: float = 0.35

var _current_flagship_mesh: Node3D = null
var _flagship_wake: Node3D = null
var _bob_tween: Tween = null

func _ready() -> void:
	GameState.set_performance_mode(false)
	GameState.is_game_active = false

	_setup_building_cards()
	_setup_hud_buttons()
	_setup_river_map()
	_refresh_docked_flagship()
	_update_hud_display()

	GameState.active_vessel_changed.connect(_on_active_vessel_changed)
	GameState.doubloons_changed.connect(_on_doubloons_changed)

	if AudioManager and AudioManager.has_method("play_music"):
		AudioManager.play_music()

func _setup_building_cards() -> void:
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

	if btn_close_river_map:
		btn_close_river_map.pressed.connect(_close_river_map)

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

	if vessel_badge_label:
		var ship := GameState.get_active_ship_resource()
		var ship_title: String = ship.ship_name.to_upper() if ship else "THE DINGHY"
		var tier: int = GameState.get_active_ship_tier()
		vessel_badge_label.text = "%s (TIER %d)" % [ship_title, tier]

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

	var boat_node := ship.model_scene.instantiate() as Node3D
	if not boat_node:
		return

	boat_node.name = "DockedFlagshipMesh"
	boat_node.scale = ship.scale * 0.95
	# Side-angle profile: vessel docked parallel to pier along X-axis
	boat_node.rotation_degrees = Vector3(0.0, -90.0, 0.0)

	# Corrected baseline Y so small hulls and dinghy do NOT sink into water
	var baseline_y: float = ship.y_offset + WATERLINE_ELEVATION_OFFSET
	boat_node.position = Vector3(0.0, baseline_y, 0.0)

	basin_flagship_anchor.add_child(boat_node)
	_current_flagship_mesh = boat_node

	# Gentle water wake underneath
	if WAKE_SCENE:
		var wake_instance := WAKE_SCENE.instantiate() as Node3D
		if wake_instance:
			wake_instance.name = "CalmDockWake"
			wake_instance.position = Vector3(0.0, 0.04, 0.0)
			wake_instance.scale = Vector3(0.85, 0.85, 0.85)
			basin_flagship_anchor.add_child(wake_instance)
			_flagship_wake = wake_instance

	_start_flagship_bobbing(boat_node, baseline_y)

func _start_flagship_bobbing(target_node: Node3D, base_y: float) -> void:
	var base_rot_z: float = target_node.rotation_degrees.z
	var base_rot_x: float = target_node.rotation_degrees.x

	# Subtle, gentle idle water bobbing (Y offset +/- 0.03m, Z tilt +/- 1.0 deg)
	_bob_tween = create_tween().set_loops()
	_bob_tween.set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_bob_tween.tween_property(target_node, "position:y", base_y + 0.03, 2.0)
	_bob_tween.tween_property(target_node, "rotation_degrees:z", base_rot_z + 1.0, 2.0)
	_bob_tween.tween_property(target_node, "rotation_degrees:x", base_rot_x - 0.5, 2.0)

	_bob_tween.chain().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_bob_tween.tween_property(target_node, "position:y", base_y - 0.03, 2.0)
	_bob_tween.tween_property(target_node, "rotation_degrees:z", base_rot_z - 1.0, 2.0)
	_bob_tween.tween_property(target_node, "rotation_degrees:x", base_rot_x + 0.5, 2.0)

func _on_building_activated(mode_id: String) -> void:
	match mode_id:
		"campaign":
			_open_campaign_map()
		"endless":
			_launch_endless_mode()
		"shipyard":
			_open_shipyard_ui()

func _open_campaign_map() -> void:
	if river_map_layer:
		river_map_layer.visible = true
		river_map_layer.process_mode = Node.PROCESS_MODE_INHERIT
		if river_map_instance and river_map_instance.has_method("_setup_mini_vessel"):
			river_map_instance.call("_setup_mini_vessel")

func _close_river_map() -> void:
	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("gate_passes", 0.9, 1.0)

	if river_map_layer:
		river_map_layer.visible = false

func _on_level_selected(level_num: int) -> void:
	GameState.select_level(level_num)

func _on_sail_requested(level_num: int) -> void:
	GameState.select_level(level_num)
	GameState.should_auto_start = true
	GameState.should_auto_start_endless = false
	GameState.reset_level()
	get_tree().change_scene_to_file(MAIN_GAME_PATH)

func _launch_endless_mode() -> void:
	GameState.should_auto_start = false
	GameState.should_auto_start_endless = true
	GameState.reset_level()
	get_tree().change_scene_to_file(MAIN_GAME_PATH)

func _open_shipyard_ui() -> void:
	if not SHIPYARD_SCENE:
		return

	var shipyard_node := SHIPYARD_SCENE.instantiate() as CanvasLayer
	if not shipyard_node:
		return

	add_child(shipyard_node)
	if shipyard_node.has_signal("shipyard_closed"):
		shipyard_node.connect("shipyard_closed", func() -> void:
			_refresh_docked_flagship()
			_update_hud_display()
		)

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
