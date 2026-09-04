class_name StartScreen
extends CanvasLayer

## Signal emitted when player presses SET SAIL button and fade animation completes
signal game_started

@onready var start_button: Button = %StartButton
@onready var shipyard_button: Button = %ShipyardButton
@onready var settings_button: Button = %SettingsButton
@onready var reset_button: Button = %ResetButton
@onready var btn_lvl_1: Button = %BtnLvl1
@onready var btn_lvl_2: Button = %BtnLvl2
@onready var btn_lvl_3: Button = %BtnLvl3
@onready var btn_lvl_4: Button = %BtnLvl4
@onready var btn_lvl_5: Button = %BtnLvl5
@onready var btn_lvl_6: Button = %BtnLvl6
@onready var subtitle_label: Label = %GameSubtitle
@onready var main_control: Control = $Control

var pulse_tween: Tween

const LEVEL_NAMES: Dictionary = {
	1: "Level 1: Smuggler's Run",
	2: "Level 2: Black Tide Bayou",
	3: "Level 3: Brimstone Bastion",
	4: "Level 4: Smuggler's Nightmare",
	5: "Level 5: Black Tide Abyss",
	6: "Level 6: Brimstone Inferno"
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
		
	if btn_lvl_1: btn_lvl_1.pressed.connect(func(): _select_level(1))
	if btn_lvl_2: btn_lvl_2.pressed.connect(func(): _select_level(2))
	if btn_lvl_3: btn_lvl_3.pressed.connect(func(): _select_level(3))
	if btn_lvl_4: btn_lvl_4.pressed.connect(func(): _select_level(4))
	if btn_lvl_5: btn_lvl_5.pressed.connect(func(): _select_level(5))
	if btn_lvl_6: btn_lvl_6.pressed.connect(func(): _select_level(6))
	
	GameState.active_vessel_changed.connect(_on_active_vessel_changed)
	_update_level_buttons()
	_refresh_player_ship()

func _setup_button_pulse() -> void:
	if not start_button:
		return
	
	start_button.pivot_offset = start_button.custom_minimum_size / 2.0
	pulse_tween = create_tween().set_loops()
	pulse_tween.tween_property(start_button, "scale", Vector2(1.04, 1.04), 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse_tween.tween_property(start_button, "scale", Vector2(1.0, 1.0), 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _on_active_vessel_changed(_v_id: String) -> void:
	_refresh_player_ship()

func _refresh_player_ship() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("apply_ship_data"):
		var ship = GameState.get_active_ship_resource()
		if ship:
			player.apply_ship_data(ship)

func _on_shipyard_button_pressed() -> void:
	AudioManager.play_sfx("gate_passes")
	var shipyard_scene = preload("res://src/ui/shipyard_ui.tscn")
	if shipyard_scene:
		var shipyard = shipyard_scene.instantiate()
		get_parent().add_child(shipyard)
		if shipyard.has_signal("shipyard_closed"):
			shipyard.shipyard_closed.connect(func():
				_refresh_player_ship()
			)

func _on_settings_button_pressed() -> void:
	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("gate_passes")
	var settings_scene = preload("res://src/ui/settings_menu.tscn")
	if settings_scene:
		var settings = settings_scene.instantiate()
		get_parent().add_child(settings)

func _on_reset_button_pressed() -> void:
	GameState.reset_save_data()
	_select_level(1, true)
	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("coin_pickups", 0.8, 0.8)

func _select_level(lvl: int, force: bool = false) -> void:
	if not force and GameState.current_level == lvl:
		return
		
	GameState.current_level = lvl
	AudioManager.play_sfx("coin_pickups", 1.0, 1.2)
	_update_level_buttons()
	
	# Keep player flagship as user equipped active vessel
	_refresh_player_ship()
			
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


func _update_level_buttons() -> void:
	var cur = GameState.current_level
	if subtitle_label:
		subtitle_label.text = LEVEL_NAMES.get(cur, "COVE OF PLUNDER").to_upper()
		
	var sel_style = StyleBoxFlat.new()
	sel_style.bg_color = Color(0.18, 0.55, 0.85, 0.95)
	sel_style.border_color = Color(1.0, 0.85, 0.2, 1.0)
	sel_style.border_width_left = 2
	sel_style.border_width_top = 2
	sel_style.border_width_right = 2
	sel_style.border_width_bottom = 2
	sel_style.corner_radius_top_left = 8
	sel_style.corner_radius_top_right = 8
	sel_style.corner_radius_bottom_right = 8
	sel_style.corner_radius_bottom_left = 8
	
	var unsel_style = StyleBoxFlat.new()
	unsel_style.bg_color = Color(0.12, 0.18, 0.25, 0.8)
	unsel_style.border_color = Color(0.4, 0.5, 0.6, 0.5)
	unsel_style.border_width_left = 1
	unsel_style.border_width_top = 1
	unsel_style.border_width_right = 1
	unsel_style.border_width_bottom = 1
	unsel_style.corner_radius_top_left = 8
	unsel_style.corner_radius_top_right = 8
	unsel_style.corner_radius_bottom_right = 8
	unsel_style.corner_radius_bottom_left = 8
	
	var buttons = [btn_lvl_1, btn_lvl_2, btn_lvl_3, btn_lvl_4, btn_lvl_5, btn_lvl_6]
	for i in range(buttons.size()):
		var btn = buttons[i]
		if btn:
			var lvl_idx = i + 1
			btn.add_theme_stylebox_override("normal", sel_style if cur == lvl_idx else unsel_style)
			btn.modulate = Color.WHITE if cur == lvl_idx else Color(0.75, 0.75, 0.75, 0.9)

func _on_start_button_pressed() -> void:
	if not start_button or start_button.disabled:
		return
		
	start_button.disabled = true
	
	if pulse_tween and pulse_tween.is_valid():
		pulse_tween.kill()
		
	start_button.scale = Vector2.ONE
	
	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("gate_passes")
	
	var fade_tween = create_tween().set_parallel(true)
	if main_control:
		fade_tween.tween_property(main_control, "modulate:a", 0.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		fade_tween.tween_property(main_control, "position:y", main_control.position.y - 60.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	fade_tween.chain().tween_callback(func():
		game_started.emit()
		queue_free()
	)
