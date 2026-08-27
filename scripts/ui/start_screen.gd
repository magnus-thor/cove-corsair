class_name StartScreen
extends CanvasLayer

## Signal emitted when player presses SET SAIL button and fade animation completes
signal game_started

@onready var start_button: Button = %StartButton
@onready var main_control: Control = $Control

var pulse_tween: Tween

func _ready() -> void:
	if start_button:
		start_button.pressed.connect(_on_start_button_pressed)
		_setup_button_pulse()

func _setup_button_pulse() -> void:
	if not start_button:
		return
	
	# Set pivot offset to center of button for symmetrical scaling pulse
	start_button.pivot_offset = start_button.custom_minimum_size / 2.0
	
	pulse_tween = create_tween().set_loops()
	pulse_tween.tween_property(start_button, "scale", Vector2(1.05, 1.05), 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse_tween.tween_property(start_button, "scale", Vector2(1.0, 1.0), 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _on_start_button_pressed() -> void:
	if not start_button or start_button.disabled:
		return
		
	# Disable button to prevent double-clicks
	start_button.disabled = true
	
	if pulse_tween and pulse_tween.is_valid():
		pulse_tween.kill()
		
	start_button.scale = Vector2.ONE
	
	# Play a gate or chime SFX
	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("gate_passes")
	
	# Animate the Start UI fading out and sliding upward
	var fade_tween = create_tween().set_parallel(true)
	if main_control:
		fade_tween.tween_property(main_control, "modulate:a", 0.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		fade_tween.tween_property(main_control, "position:y", main_control.position.y - 60.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	fade_tween.chain().tween_callback(func():
		game_started.emit()
		queue_free()
	)
