class_name StartScreen
extends CanvasLayer

## Signal emitted when player presses SET SAIL button and fade animation completes
signal game_started

@onready var doubloons_label: Label = %DoubloonsLabel
@onready var settings_button: Button = %SettingsButton
@onready var game_title: Control = get_node_or_null("%GameTitle")

@onready var btn_prev_expedition: BaseButton = %BtnPrevExpedition
@onready var btn_next_expedition: BaseButton = %BtnNextExpedition
@onready var expedition_num_label: Label = %ExpeditionNumLabel
@onready var expedition_name_label: Label = %ExpeditionNameLabel
@onready var expedition_meta_label: Label = get_node_or_null("%ExpeditionMetaLabel")

@onready var start_button: Button = %StartButton
@onready var shipyard_button: Button = %ShipyardButton
@onready var reset_button: Button = get_node_or_null("%ResetButton")
@onready var main_control: Control = $Control

var pulse_tween: Tween

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
	if start_button:
		start_button.pressed.connect(_on_start_button_pressed)
		_setup_button_pulse()
		
	if shipyard_button:
		shipyard_button.pressed.connect(_on_shipyard_button_pressed)

	if settings_button:
		settings_button.pressed.connect(_on_settings_button_pressed)

	if reset_button:
		reset_button.pressed.connect(_on_reset_button_pressed)
		
	if btn_prev_expedition:
		btn_prev_expedition.pressed.connect(_on_prev_expedition_pressed)
		
	if btn_next_expedition:
		btn_next_expedition.pressed.connect(_on_next_expedition_pressed)
		
	GameState.active_vessel_changed.connect(_on_active_vessel_changed)
	GameState.doubloons_changed.connect(_on_doubloons_changed)
	
	_update_doubloons_display()
	_update_expedition_display()
	_refresh_player_ship()

func _update_doubloons_display() -> void:
	if doubloons_label:
		doubloons_label.text = "%d DOUBLOONS" % GameState.doubloons

func _on_doubloons_changed(_amt: int) -> void:
	_update_doubloons_display()

func _setup_button_pulse() -> void:
	if not start_button:
		return
	
	start_button.resized.connect(_update_start_button_pivot)
	_update_start_button_pivot()
	pulse_tween = create_tween().set_loops()
	pulse_tween.tween_property(start_button, "scale", Vector2(1.035, 1.035), 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse_tween.tween_property(start_button, "scale", Vector2(1.0, 1.0), 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _update_start_button_pivot() -> void:
	if start_button:
		start_button.pivot_offset = start_button.size * 0.5

func _on_active_vessel_changed(_v_id: String) -> void:
	_refresh_player_ship()

func _refresh_player_ship() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("apply_ship_data"):
		var ship = GameState.get_active_ship_resource()
		if ship:
			player.apply_ship_data(ship)

func _on_prev_expedition_pressed() -> void:
	if GameState.current_level > 1:
		_select_level(GameState.current_level - 1)
	else:
		_select_level(6)

func _on_next_expedition_pressed() -> void:
	if GameState.current_level < 6:
		_select_level(GameState.current_level + 1)
	else:
		_select_level(1)

func _on_shipyard_button_pressed() -> void:
	AudioManager.play_sfx("gate_passes")
	var shipyard_scene = preload("res://src/ui/shipyard_ui.tscn")
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
				_select_level(GameState.current_level, true)
				_refresh_player_ship()
			)

func _on_reset_button_pressed() -> void:
	GameState.reset_save_data()
	_update_doubloons_display()
	_select_level(1, true)
	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("coin_pickups", 0.8, 0.8)

func _select_level(lvl: int, force: bool = false) -> void:
	if not force and GameState.current_level == lvl:
		return
		
	GameState.current_level = lvl
	AudioManager.play_sfx("gate_passes", 1.0, 1.1)
	_update_expedition_display()
	
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

func _update_expedition_display() -> void:
	var cur = GameState.current_level
	var max_unlocked = clamp(GameState.unlocked_levels, 1, 6)
	
	if expedition_num_label:
		expedition_num_label.text = "EXPEDITION %02d:" % cur
	if expedition_name_label:
		var exp_name = LEVEL_NAMES.get(cur, "COVE RUN")
		expedition_name_label.text = exp_name
		if exp_name.length() > 16:
			expedition_name_label.add_theme_font_size_override("font_size", 28)
		else:
			expedition_name_label.add_theme_font_size_override("font_size", 32)
	if expedition_meta_label:
		var biome = LEVEL_BIOMES.get(cur, "Open Waters")
		var dist = LEVEL_DISTANCES.get(cur, 250)
		expedition_meta_label.text = "%s  •  Target: %dm" % [biome, dist]
		
	if btn_prev_expedition:
		btn_prev_expedition.disabled = false
		btn_prev_expedition.modulate = Color.WHITE
		
	if btn_next_expedition:
		btn_next_expedition.disabled = false
		btn_next_expedition.modulate = Color.WHITE

func _on_start_button_pressed() -> void:
	if not start_button or start_button.disabled:
		return
		
	start_button.disabled = true
	
	if pulse_tween and pulse_tween.is_valid():
		pulse_tween.kill()
		
	start_button.scale = Vector2.ONE
	
	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("gate_passes")
	
	game_started.emit()
	
	var fade_tween = create_tween().set_parallel(true)
	if main_control:
		fade_tween.tween_property(main_control, "modulate:a", 0.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		fade_tween.tween_property(main_control, "position:y", main_control.position.y - 60.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	fade_tween.chain().tween_callback(func():
		queue_free()
	)
