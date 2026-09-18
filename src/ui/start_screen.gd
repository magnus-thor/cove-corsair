class_name StartScreen
extends CanvasLayer

## Main Start & Progression Screen for Cove Corsair
## Integrates the scrollable RiverMap, top economy/settings bar, and shipyard dock.

signal game_started
signal endless_started

@onready var main_control: Control = $Control
@onready var doubloons_label: Label = %DoubloonsLabel
@onready var settings_button: Button = %SettingsButton
@onready var shipyard_button: Button = %ShipyardButton
@onready var endless_button: Button = %EndlessButton
@onready var river_map: RiverMap = %RiverMap

const LEVEL_NAMES: Dictionary = {
	1: "SMUGGLER'S RUN",
	2: "BLACK TIDE BAYOU",
	3: "BRIMSTONE BASTION",
	4: "SMUGGLER'S NIGHTMARE",
	5: "BLACK TIDE ABYSS",
	6: "BRIMSTONE INFERNO"
}

const LEVEL_BIOMES: Dictionary = {
	1: "Tropical Reef",
	2: "Murky Bayou",
	3: "Volcanic Bastion",
	4: "Stormy Coast",
	5: "Abyssal Mire",
	6: "Lava Caldera"
}

const LEVEL_DISTANCES: Dictionary = {
	1: 250,
	2: 300,
	3: 350,
	4: 300,
	5: 350,
	6: 400
}

func _ready() -> void:
	GameState.set_performance_mode(false)
	
	if river_map:
		river_map.sail_requested.connect(_on_river_map_sail_requested)
		river_map.level_selected.connect(_on_river_map_level_selected)
		
	if shipyard_button:
		shipyard_button.pressed.connect(_on_shipyard_button_pressed)

	if settings_button:
		settings_button.pressed.connect(_on_settings_button_pressed)
		
	if endless_button:
		endless_button.pressed.connect(_on_endless_button_pressed)
		
	GameState.active_vessel_changed.connect(_on_active_vessel_changed)
	GameState.doubloons_changed.connect(_on_doubloons_changed)
	
	_update_doubloons_display()
	_refresh_player_ship()
	_select_level(GameState.current_selected_level, true)

func _update_doubloons_display() -> void:
	if doubloons_label:
		doubloons_label.text = "%d DOUBLOONS" % GameState.doubloons

func _on_doubloons_changed(_amt: int) -> void:
	_update_doubloons_display()

func _on_active_vessel_changed(_v_id: String) -> void:
	_refresh_player_ship()

func _refresh_player_ship() -> void:
	var player: Node = get_tree().get_first_node_in_group("player")
	if player and player.has_method("apply_ship_data"):
		var ship: ShipData = GameState.get_active_ship_resource()
		if ship:
			player.call("apply_ship_data", ship)
			
	if river_map and river_map.has_method("_setup_mini_vessel"):
		river_map.call("_setup_mini_vessel")

func _on_river_map_level_selected(lvl: int) -> void:
	_select_level(lvl, false)

func _on_river_map_sail_requested(lvl: int) -> void:
	_select_level(lvl, true)
	
	visible = false
	game_started.emit()
	
	var fade_tween: Tween = create_tween().set_parallel(true)
	if main_control:
		fade_tween.tween_property(main_control, "modulate:a", 0.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		fade_tween.tween_property(main_control, "position:y", main_control.position.y - 60.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	fade_tween.chain().tween_callback(func() -> void:
		queue_free()
	)

func _on_endless_button_pressed() -> void:
	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("gate_passes")
		
	var hud: Node = get_tree().get_first_node_in_group("top_hud")
	if hud and "level_title" in hud and hud.get("level_title"):
		var title_label: Label = hud.get("level_title") as Label
		if title_label:
			title_label.text = "CORSAIR GAUNTLET"
			
	visible = false
	endless_started.emit()
	
	var fade_tween: Tween = create_tween().set_parallel(true)
	if main_control:
		fade_tween.tween_property(main_control, "modulate:a", 0.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		fade_tween.tween_property(main_control, "position:y", main_control.position.y - 60.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	fade_tween.chain().tween_callback(func() -> void:
		queue_free()
	)

func _on_shipyard_button_pressed() -> void:
	AudioManager.play_sfx("gate_passes")
	var shipyard_scene = preload("res://src/ui/shipyard/shipyard_ui.tscn")
	if shipyard_scene:
		var shipyard = shipyard_scene.instantiate()
		get_parent().add_child(shipyard)
		if shipyard.has_signal("shipyard_closed"):
			shipyard.shipyard_closed.connect(func():
				_update_doubloons_display()
				_refresh_player_ship()
			)

func _on_settings_button_pressed() -> void:
	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("gate_passes")
	var settings_scene = preload("res://src/ui/settings_menu.tscn")
	if settings_scene:
		var settings = settings_scene.instantiate()
		get_parent().add_child(settings)
		if settings.has_signal("settings_closed"):
			settings.settings_closed.connect(func():
				_update_doubloons_display()
				_select_level(GameState.current_selected_level, true)
				_refresh_player_ship()
			)

func _select_level(lvl: int, force: bool = false) -> void:
	if not force and GameState.current_level == lvl:
		return
		
	GameState.select_level(lvl)
	_refresh_player_ship()
	
	var harbor = get_tree().get_first_node_in_group("harbor_bay")
	if harbor and harbor.has_method("on_expedition_changed"):
		harbor.on_expedition_changed(lvl)
			
	var level_ctrl = get_tree().get_first_node_in_group("level_controller")
	if level_ctrl and is_instance_valid(level_ctrl):
		var res = GameState.get_current_level_resource()
		if res:
			if level_ctrl.has_method("load_level_resource"):
				level_ctrl.load_level_resource(res)
			else:
				level_ctrl.level_data = res
				level_ctrl.current_distance = 0.0
				if level_ctrl.has_method("setup_active_queue"):
					level_ctrl.setup_active_queue()
				level_ctrl._apply_biome_visuals()
			
	var hud = get_tree().get_first_node_in_group("top_hud")
	if hud and "level_title" in hud and hud.level_title:
		hud.level_title.text = LEVEL_NAMES.get(lvl, "Level %d" % lvl)
