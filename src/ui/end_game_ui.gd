extends CanvasLayer

var _victory: bool = false
var _score: int = 0
var _initialized: bool = false

@onready var title_label: Label = $Control/Panel/VBoxContainer/TitleLabel
@onready var score_label: Label = $Control/Panel/VBoxContainer/ScoreLabel
@onready var restart_button: Button = %RestartButton
@onready var start_screen_button: Button = %StartScreenButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	if restart_button:
		restart_button.pressed.connect(_on_restart_button_pressed)
	if start_screen_button:
		start_screen_button.pressed.connect(_on_start_screen_button_pressed)
	
	_initialized = true
	_update_ui()
	
	var background = $Control/Background
	var panel = $Control/Panel
	
	background.color.a = 0.0
	panel.scale = Vector2(0.8, 0.8)
	panel.modulate.a = 0.0
	
	call_deferred("_setup_animation")

func _setup_animation() -> void:
	var background = $Control/Background
	var panel = $Control/Panel
	panel.pivot_offset = panel.size / 2.0
	
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(background, "color:a", 0.7, 0.4)
	tween.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.5)
	tween.tween_property(panel, "modulate:a", 1.0, 0.3)

func set_result(victory: bool, score: int) -> void:
	_victory = victory
	_score = score
	if _initialized:
		_update_ui()

func _update_ui() -> void:
	if not title_label or not score_label:
		return
	if _victory:
		title_label.text = "VICTORY!"
		title_label.add_theme_color_override("font_color", Color(0.24, 0.81, 0.45))
	else:
		title_label.text = "DEFEAT!"
		title_label.add_theme_color_override("font_color", Color(0.95, 0.26, 0.26))
	
	score_label.text = "Barrels Sunk: %d" % _score

func _on_restart_button_pressed() -> void:
	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("gate_passes")
	get_tree().paused = false
	GameState.should_auto_start = true
	GameState.reset_level()
	get_tree().reload_current_scene()

func _on_start_screen_button_pressed() -> void:
	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("gate_passes")
	get_tree().paused = false
	GameState.should_auto_start = false
	GameState.reset_level()
	get_tree().reload_current_scene()
