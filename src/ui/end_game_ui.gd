extends CanvasLayer

var _victory: bool = false
var _score: int = 0
var _initialized: bool = false

@onready var title_label: Label = $Control/Panel/VBoxContainer/TitleLabel
@onready var score_label: Label = $Control/Panel/VBoxContainer/ScoreLabel
@onready var play_again_button: Button = $Control/Panel/VBoxContainer/PlayAgainButton

func _ready() -> void:
	# Ensure the UI responds even when the game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Wire up the play again button click signal
	play_again_button.pressed.connect(_on_play_again_button_pressed)
	
	_initialized = true
	_update_ui()
	
	# Initial transparent state for animations
	var background = $Control/Background
	var panel = $Control/Panel
	
	background.color.a = 0.0
	panel.scale = Vector2(0.8, 0.8)
	panel.modulate.a = 0.0
	
	# Defer the animation setup to ensure layout size is calculated for center pivot offset
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
	if _victory:
		title_label.text = "VICTORY!"
		title_label.add_theme_color_override("font_color", Color(0.24, 0.81, 0.45)) # Emerald Green
	else:
		title_label.text = "DEFEAT!"
		title_label.add_theme_color_override("font_color", Color(0.95, 0.26, 0.26)) # Premium Coral/Red
	
	score_label.text = "Barrels Sunk: %d" % _score

func _on_play_again_button_pressed() -> void:
	get_tree().paused = false
	GameState.reset_level()
	get_tree().reload_current_scene()
