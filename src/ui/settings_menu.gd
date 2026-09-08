class_name SettingsMenu
extends CanvasLayer

signal settings_closed

@onready var master_slider: HSlider = %MasterSlider
@onready var master_val_label: Label = %MasterValLabel
@onready var master_mute_btn: Button = %MasterMuteBtn

@onready var music_slider: HSlider = %MusicSlider
@onready var music_val_label: Label = %MusicValLabel
@onready var music_mute_btn: Button = %MusicMuteBtn

@onready var sfx_slider: HSlider = %SFXSlider
@onready var sfx_val_label: Label = %SFXValLabel
@onready var sfx_mute_btn: Button = %SFXMuteBtn

@onready var reset_button: Button = %ResetButton
@onready var close_button: Button = %CloseButton
@onready var panel_container: PanelContainer = %PanelContainer
@onready var backdrop: ColorRect = %Backdrop

var is_confirming_reset: bool = false
var reset_confirm_timer: SceneTreeTimer

# Toggle button styles
var style_mute_on: StyleBoxFlat
var style_mute_off: StyleBoxFlat
var style_reset_normal: StyleBoxFlat
var style_reset_confirm: StyleBoxFlat

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 25
	
	_init_styles()
	_load_current_values()
	_connect_signals()
	_animate_open()

func _init_styles() -> void:
	# Mute ON (Vibrant Emerald Green)
	style_mute_on = StyleBoxFlat.new()
	style_mute_on.bg_color = Color(0.22, 0.72, 0.15, 1.0)
	style_mute_on.border_width_left = 2
	style_mute_on.border_width_top = 2
	style_mute_on.border_width_right = 2
	style_mute_on.border_width_bottom = 2
	style_mute_on.border_color = Color(0.12, 0.44, 0.08, 1.0)
	style_mute_on.corner_radius_top_left = 10
	style_mute_on.corner_radius_top_right = 10
	style_mute_on.corner_radius_bottom_right = 10
	style_mute_on.corner_radius_bottom_left = 10

	# Mute OFF / MUTED (Crimson Red)
	style_mute_off = StyleBoxFlat.new()
	style_mute_off.bg_color = Color(0.72, 0.14, 0.18, 1.0)
	style_mute_off.border_width_left = 2
	style_mute_off.border_width_top = 2
	style_mute_off.border_width_right = 2
	style_mute_off.border_width_bottom = 2
	style_mute_off.border_color = Color(0.42, 0.08, 0.10, 1.0)
	style_mute_off.corner_radius_top_left = 10
	style_mute_off.corner_radius_top_right = 10
	style_mute_off.corner_radius_bottom_right = 10
	style_mute_off.corner_radius_bottom_left = 10

	# Reset Button Normal (Crimson Red with Gold Trim)
	style_reset_normal = StyleBoxFlat.new()
	style_reset_normal.bg_color = Color(0.72, 0.13, 0.18, 1.0)
	style_reset_normal.border_width_left = 3
	style_reset_normal.border_width_top = 3
	style_reset_normal.border_width_right = 3
	style_reset_normal.border_width_bottom = 3
	style_reset_normal.border_color = Color(0.95, 0.78, 0.28, 1.0)
	style_reset_normal.corner_radius_top_left = 14
	style_reset_normal.corner_radius_top_right = 14
	style_reset_normal.corner_radius_bottom_right = 14
	style_reset_normal.corner_radius_bottom_left = 14
	style_reset_normal.shadow_color = Color(0, 0, 0, 0.4)
	style_reset_normal.shadow_size = 6
	style_reset_normal.shadow_offset = Vector2(0, 3)

	# Reset Button Confirming (Amber Flashing)
	style_reset_confirm = StyleBoxFlat.new()
	style_reset_confirm.bg_color = Color(0.88, 0.45, 0.10, 1.0)
	style_reset_confirm.border_width_left = 4
	style_reset_confirm.border_width_top = 4
	style_reset_confirm.border_width_right = 4
	style_reset_confirm.border_width_bottom = 4
	style_reset_confirm.border_color = Color(1.0, 0.95, 0.45, 1.0)
	style_reset_confirm.corner_radius_top_left = 14
	style_reset_confirm.corner_radius_top_right = 14
	style_reset_confirm.corner_radius_bottom_right = 14
	style_reset_confirm.corner_radius_bottom_left = 14
	style_reset_confirm.shadow_color = Color(1.0, 0.8, 0.2, 0.5)
	style_reset_confirm.shadow_size = 10
	style_reset_confirm.shadow_offset = Vector2(0, 3)

	_setup_slider_styles()

func _setup_slider_styles() -> void:
	var grabber_normal = _create_grabber_texture(false)
	var grabber_highlight = _create_grabber_texture(true)
	
	for s in [master_slider, music_slider, sfx_slider]:
		if s:
			s.add_theme_icon_override("grabber", grabber_normal)
			s.add_theme_icon_override("grabber_highlight", grabber_highlight)

func _create_grabber_texture(highlighted: bool) -> ImageTexture:
	var img_size = 24
	var img = Image.create(img_size, img_size, false, Image.FORMAT_RGBA8)
	var center = Vector2(img_size * 0.5, img_size * 0.5)
	var r_outer = 10.5
	var r_border = 9.0
	var r_rim = 7.5
	var r_core = 5.5

	var border_color = Color(0.12, 0.07, 0.03, 1.0) # Dark engraved outline (#1A1108)
	var highlight_rim = Color(1.0, 1.0, 0.92, 1.0) if highlighted else Color(1.0, 0.95, 0.72, 1.0) # Bright glowing rim
	var gold_high = Color(1.0, 0.92, 0.45, 1.0) if highlighted else Color(0.96, 0.82, 0.38, 1.0) # #F5D061
	var gold_dark = Color(0.83, 0.64, 0.22, 1.0) # #D4A338

	for y in range(img_size):
		for x in range(img_size):
			var d = (Vector2(x + 0.5, y + 0.5) - center).length()
			if d <= r_outer:
				if d > r_border:
					img.set_pixel(x, y, border_color)
				elif d > r_rim:
					# High-contrast highlight rim
					img.set_pixel(x, y, highlight_rim)
				elif d > r_core:
					# Secondary brass ring
					img.set_pixel(x, y, gold_high)
				else:
					# Inner embossed brass core
					var t = float(y) / float(img_size)
					img.set_pixel(x, y, gold_high.lerp(gold_dark, t))
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				
	return ImageTexture.create_from_image(img)

func _load_current_values() -> void:
	if master_slider:
		master_slider.value = GameState.master_volume * 100.0
		_update_master_label(master_slider.value)
	if music_slider:
		music_slider.value = GameState.music_volume * 100.0
		_update_music_label(music_slider.value)
	if sfx_slider:
		sfx_slider.value = GameState.sfx_volume * 100.0
		_update_sfx_label(sfx_slider.value)
		
	_update_mute_buttons()
	_update_reset_button_ui()

func _connect_signals() -> void:
	if master_slider:
		master_slider.value_changed.connect(_on_master_slider_changed)
	if master_mute_btn:
		master_mute_btn.pressed.connect(_on_master_mute_pressed)
		
	if music_slider:
		music_slider.value_changed.connect(_on_music_slider_changed)
	if music_mute_btn:
		music_mute_btn.pressed.connect(_on_music_mute_pressed)
		
	if sfx_slider:
		sfx_slider.value_changed.connect(_on_sfx_slider_changed)
	if sfx_mute_btn:
		sfx_mute_btn.pressed.connect(_on_sfx_mute_pressed)
		
	if reset_button:
		reset_button.pressed.connect(_on_reset_pressed)
	if close_button:
		close_button.pressed.connect(_on_close_pressed)

func _animate_open() -> void:
	if backdrop:
		backdrop.color.a = 0.0
		var t1 = create_tween()
		t1.tween_property(backdrop, "color:a", 0.75, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		
	if panel_container:
		panel_container.pivot_offset = panel_container.size * 0.5
		panel_container.scale = Vector2(0.85, 0.85)
		panel_container.modulate.a = 0.0
		var t2 = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t2.tween_property(panel_container, "scale", Vector2.ONE, 0.3)
		t2.tween_property(panel_container, "modulate:a", 1.0, 0.2)

func _on_master_slider_changed(val: float) -> void:
	var linear_vol = val / 100.0
	GameState.master_volume = linear_vol
	if AudioManager and AudioManager.has_method("set_bus_volume"):
		AudioManager.set_bus_volume("Master", linear_vol)
	_update_master_label(val)
	GameState.save_game()

func _on_music_slider_changed(val: float) -> void:
	var linear_vol = val / 100.0
	GameState.music_volume = linear_vol
	if AudioManager and AudioManager.has_method("set_bus_volume"):
		AudioManager.set_bus_volume("BGM", linear_vol)
	_update_music_label(val)
	GameState.save_game()

func _on_sfx_slider_changed(val: float) -> void:
	var linear_vol = val / 100.0
	GameState.sfx_volume = linear_vol
	if AudioManager and AudioManager.has_method("set_bus_volume"):
		AudioManager.set_bus_volume("SFX", linear_vol)
	_update_sfx_label(val)
	GameState.save_game()

func _on_master_mute_pressed() -> void:
	GameState.master_muted = not GameState.master_muted
	if AudioManager and AudioManager.has_method("set_bus_muted"):
		AudioManager.set_bus_muted("Master", GameState.master_muted)
	_update_mute_buttons()
	GameState.save_game()
	AudioManager.play_sfx("gate_passes", 1.0, 1.0)

func _on_music_mute_pressed() -> void:
	GameState.music_muted = not GameState.music_muted
	if AudioManager and AudioManager.has_method("set_bus_muted"):
		AudioManager.set_bus_muted("BGM", GameState.music_muted)
	_update_mute_buttons()
	GameState.save_game()
	AudioManager.play_sfx("gate_passes", 1.0, 1.0)

func _on_sfx_mute_pressed() -> void:
	GameState.sfx_muted = not GameState.sfx_muted
	if AudioManager and AudioManager.has_method("set_bus_muted"):
		AudioManager.set_bus_muted("SFX", GameState.sfx_muted)
	_update_mute_buttons()
	GameState.save_game()
	AudioManager.play_sfx("gate_passes", 1.0, 1.0)

func _update_master_label(val: float) -> void:
	if master_val_label:
		master_val_label.text = "%d%%" % int(val)

func _update_music_label(val: float) -> void:
	if music_val_label:
		music_val_label.text = "%d%%" % int(val)

func _update_sfx_label(val: float) -> void:
	if sfx_val_label:
		sfx_val_label.text = "%d%%" % int(val)

func _update_mute_buttons() -> void:
	if master_mute_btn:
		master_mute_btn.text = "MUTED" if GameState.master_muted else "ON"
		master_mute_btn.add_theme_stylebox_override("normal", style_mute_off if GameState.master_muted else style_mute_on)
	if music_mute_btn:
		music_mute_btn.text = "MUTED" if GameState.music_muted else "ON"
		music_mute_btn.add_theme_stylebox_override("normal", style_mute_off if GameState.music_muted else style_mute_on)
	if sfx_mute_btn:
		sfx_mute_btn.text = "MUTED" if GameState.sfx_muted else "ON"
		sfx_mute_btn.add_theme_stylebox_override("normal", style_mute_off if GameState.sfx_muted else style_mute_on)

func _update_reset_button_ui() -> void:
	if not reset_button:
		return
	if is_confirming_reset:
		reset_button.text = "⚠️ CONFIRM RESET? (CLICK AGAIN)"
		reset_button.add_theme_stylebox_override("normal", style_reset_confirm)
	else:
		reset_button.text = "⚠️ RESET GAME PROGRESS"
		reset_button.add_theme_stylebox_override("normal", style_reset_normal)

func _on_reset_pressed() -> void:
	if not is_confirming_reset:
		is_confirming_reset = true
		_update_reset_button_ui()
		AudioManager.play_sfx("barrel_hits")
		
		# 4 second timeout to cancel confirmation
		reset_confirm_timer = get_tree().create_timer(4.0, true, false, true)
		reset_confirm_timer.timeout.connect(func():
			if is_confirming_reset:
				is_confirming_reset = false
				_update_reset_button_ui()
		)
	else:
		# Confirmed reset
		is_confirming_reset = false
		GameState.reset_save_data()
		_load_current_values()
		AudioManager.play_sfx("coin_pickups", 0.8, 0.8)
		if reset_button:
			reset_button.text = "PROGRESS RESET ✓"
			reset_button.add_theme_stylebox_override("normal", style_mute_on)
			await get_tree().create_timer(1.5, true, false, true).timeout
			_update_reset_button_ui()

func _on_close_pressed() -> void:
	AudioManager.play_sfx("gate_passes", 0.9, 1.0)
		
	if panel_container:
		panel_container.pivot_offset = panel_container.size * 0.5
		var t = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_property(panel_container, "scale", Vector2(0.85, 0.85), 0.18)
		t.tween_property(panel_container, "modulate:a", 0.0, 0.18)
		if backdrop:
			t.tween_property(backdrop, "color:a", 0.0, 0.18)
		await t.finished
		
	settings_closed.emit()
	queue_free()
