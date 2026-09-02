class_name StartScreen
extends CanvasLayer

## Signal emitted when player presses SET SAIL button and fade animation completes
signal game_started

@onready var start_button: Button = %StartButton
@onready var btn_lvl_1: Button = %BtnLvl1
@onready var btn_lvl_2: Button = %BtnLvl2
@onready var btn_lvl_3: Button = %BtnLvl3
@onready var subtitle_label: Label = %GameSubtitle
@onready var main_control: Control = $Control

var pulse_tween: Tween

const LEVEL_NAMES: Dictionary = {
	1: "Level 1: Smuggler's Run",
	2: "Level 2: Black Tide Bayou",
	3: "Level 3: Brimstone Bastion"
}

func _ready() -> void:
	if start_button:
		start_button.pressed.connect(_on_start_button_pressed)
		_setup_button_pulse()
		
	if btn_lvl_1: btn_lvl_1.pressed.connect(func(): _select_level(1))
	if btn_lvl_2: btn_lvl_2.pressed.connect(func(): _select_level(2))
	if btn_lvl_3: btn_lvl_3.pressed.connect(func(): _select_level(3))
	
	_update_level_buttons()

func _setup_button_pulse() -> void:
	if not start_button:
		return
	
	start_button.pivot_offset = start_button.custom_minimum_size / 2.0
	pulse_tween = create_tween().set_loops()
	pulse_tween.tween_property(start_button, "scale", Vector2(1.05, 1.05), 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse_tween.tween_property(start_button, "scale", Vector2(1.0, 1.0), 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _select_level(lvl: int) -> void:
	if GameState.current_level == lvl:
		return
		
	GameState.current_level = lvl
	AudioManager.play_sfx("coin_pickups", 1.0, 1.2)
	_update_level_buttons()
	
	# Update active ship and level controller live
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("apply_ship_data"):
		var ship = GameState.get_current_ship_resource()
		if ship:
			player.apply_ship_data(ship)
			
	var level_ctrl = get_tree().get_first_node_in_group("level_controller")
	if level_ctrl and is_instance_valid(level_ctrl):
		var res = GameState.get_current_level_resource()
		if res:
			level_ctrl.level_data = res
			level_ctrl.current_distance = 0.0
			level_ctrl.active_queue = res.wave_events.duplicate()
			level_ctrl.active_queue.sort_custom(func(a, b): return a.distance < b.distance)
			level_ctrl._apply_biome_visuals()
			
	var hud = get_tree().get_first_node_in_group("top_hud")
	if hud and "level_title" in hud and hud.level_title:
		hud.level_title.text = LEVEL_NAMES.get(lvl, "Level %d" % lvl)

func _update_level_buttons() -> void:
	var cur = GameState.current_level
	if subtitle_label:
		subtitle_label.text = LEVEL_NAMES.get(cur, "COVE OF PLUNDER").to_upper()
		
	var normal_style = preload("res://src/ui/start_screen.tscn").instantiate().get_node("Control/BottomContainer/LevelSelectContainer/BtnLvl1").get_theme_stylebox("normal")
	
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
	
	if btn_lvl_1:
		btn_lvl_1.add_theme_stylebox_override("normal", sel_style if cur == 1 else unsel_style)
		btn_lvl_1.modulate = Color.WHITE if cur == 1 else Color(0.7, 0.7, 0.7, 0.9)
	if btn_lvl_2:
		btn_lvl_2.add_theme_stylebox_override("normal", sel_style if cur == 2 else unsel_style)
		btn_lvl_2.modulate = Color.WHITE if cur == 2 else Color(0.7, 0.7, 0.7, 0.9)
	if btn_lvl_3:
		btn_lvl_3.add_theme_stylebox_override("normal", sel_style if cur == 3 else unsel_style)
		btn_lvl_3.modulate = Color.WHITE if cur == 3 else Color(0.7, 0.7, 0.7, 0.9)

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
