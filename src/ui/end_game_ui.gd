extends CanvasLayer

var _victory: bool = false
var _score: int = 0
var _initialized: bool = false

@onready var title_label: Label = %TitleLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var score_label: Label = %ScoreLabel
@onready var doubloons_label: Label = %DoubloonsLabel
@onready var restart_button: Button = %RestartButton
@onready var start_screen_button: Button = %StartScreenButton
@onready var panel_container: PanelContainer = %PanelContainer
@onready var backdrop: ColorRect = %Backdrop

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	
	if restart_button:
		restart_button.pressed.connect(_on_restart_button_pressed)
	if start_screen_button:
		start_screen_button.pressed.connect(_on_start_screen_button_pressed)
	
	_initialized = true
	_update_ui()
	_animate_open()

func _animate_open() -> void:
	if backdrop:
		backdrop.color.a = 0.0
		var t = create_tween()
		t.tween_property(backdrop, "color:a", 0.82, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		
	if panel_container:
		panel_container.pivot_offset = panel_container.size * 0.5
		panel_container.scale = Vector2(0.8, 0.8)
		panel_container.modulate.a = 0.0
		var t = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(panel_container, "scale", Vector2.ONE, 0.45)
		t.tween_property(panel_container, "modulate:a", 1.0, 0.3)

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
		title_label.add_theme_color_override("font_color", Color(0.96, 0.8, 0.35, 1.0))
		if subtitle_label:
			subtitle_label.text = "EXPEDITION TRIUMPHANT!"
	else:
		title_label.text = "DEFEAT!"
		title_label.add_theme_color_override("font_color", Color(0.85, 0.16, 0.18, 1.0))
		if subtitle_label:
			subtitle_label.text = "FLAGSHIP BROUGHT DOWN AT SEA"
	
	score_label.text = str(_score)
	if doubloons_label:
		doubloons_label.text = str(GameState.run_doubloons)

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
	GameState.change_scene_with_loading("res://scenes/cove_hub/cove_main_hub.tscn", "Pirate Lair")
