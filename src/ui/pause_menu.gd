class_name PauseMenu
extends CanvasLayer

signal pause_closed

@onready var continue_button: Button = %ContinueButton
@onready var exit_button: Button = %ExitButton

@onready var master_slider: HSlider = %MasterSlider
@onready var master_val_label: Label = %MasterValLabel
@onready var master_mute_btn: Button = %MasterMuteBtn

@onready var music_slider: HSlider = %MusicSlider
@onready var music_val_label: Label = %MusicValLabel
@onready var music_mute_btn: Button = %MusicMuteBtn

@onready var sfx_slider: HSlider = %SFXSlider
@onready var sfx_val_label: Label = %SFXValLabel
@onready var sfx_mute_btn: Button = %SFXMuteBtn

@onready var panel_container: PanelContainer = %PanelContainer
@onready var backdrop: ColorRect = %Backdrop

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	
	_load_current_values()
	_connect_signals()
	_animate_open()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_P):
		get_viewport().set_input_as_handled()
		_on_continue_pressed()

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

func _connect_signals() -> void:
	if continue_button:
		continue_button.pressed.connect(_on_continue_pressed)
	if exit_button:
		exit_button.pressed.connect(_on_exit_pressed)
		
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

func _animate_open() -> void:
	if backdrop:
		backdrop.color.a = 0.0
		var t1 = create_tween()
		t1.tween_property(backdrop, "color:a", 0.7, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		
	if panel_container:
		panel_container.pivot_offset = panel_container.size * 0.5
		panel_container.scale = Vector2(0.85, 0.85)
		panel_container.modulate.a = 0.0
		var t2 = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t2.tween_property(panel_container, "scale", Vector2.ONE, 0.28)
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
	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("coin_pickups", 1.0, 1.0)

func _on_music_mute_pressed() -> void:
	GameState.music_muted = not GameState.music_muted
	if AudioManager and AudioManager.has_method("set_bus_muted"):
		AudioManager.set_bus_muted("BGM", GameState.music_muted)
	_update_mute_buttons()
	GameState.save_game()
	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("coin_pickups", 1.0, 1.0)

func _on_sfx_mute_pressed() -> void:
	GameState.sfx_muted = not GameState.sfx_muted
	if AudioManager and AudioManager.has_method("set_bus_muted"):
		AudioManager.set_bus_muted("SFX", GameState.sfx_muted)
	_update_mute_buttons()
	GameState.save_game()
	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("coin_pickups", 1.0, 1.0)

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
		master_mute_btn.text = "🔇 MUTED" if GameState.master_muted else "🔊 ON"
		master_mute_btn.modulate = Color(0.9, 0.4, 0.4) if GameState.master_muted else Color(0.4, 0.9, 0.5)
	if music_mute_btn:
		music_mute_btn.text = "🔇 MUTED" if GameState.music_muted else "🎵 ON"
		music_mute_btn.modulate = Color(0.9, 0.4, 0.4) if GameState.music_muted else Color(0.4, 0.8, 1.0)
	if sfx_mute_btn:
		sfx_mute_btn.text = "🔇 MUTED" if GameState.sfx_muted else "💥 ON"
		sfx_mute_btn.modulate = Color(0.9, 0.4, 0.4) if GameState.sfx_muted else Color(1.0, 0.85, 0.3)

func _on_continue_pressed() -> void:
	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("gate_passes", 1.0, 1.0)
		
	if panel_container:
		panel_container.pivot_offset = panel_container.size * 0.5
		var t = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_property(panel_container, "scale", Vector2(0.85, 0.85), 0.15)
		t.tween_property(panel_container, "modulate:a", 0.0, 0.15)
		if backdrop:
			t.tween_property(backdrop, "color:a", 0.0, 0.15)
		await t.finished
		
	get_tree().paused = false
	pause_closed.emit()
	queue_free()

func _on_exit_pressed() -> void:
	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("gate_passes", 0.8, 0.9)
	get_tree().paused = false
	GameState.should_auto_start = false
	GameState.reset_level()
	get_tree().change_scene_to_file("res://src/features/hub/pirate_lair_hub.tscn")
