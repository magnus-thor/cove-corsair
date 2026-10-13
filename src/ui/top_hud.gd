extends CanvasLayer

@onready var gold_container: Control = $MarginContainer/HBoxContainer/GoldPanel
@onready var gold_label: Label = $MarginContainer/HBoxContainer/GoldPanel/MarginContainer/HBoxContainer/GoldLabel
@onready var level_title: Label = $MarginContainer/HBoxContainer/ProgressContainer/LevelTitle
@onready var level_progress_bar: ProgressBar = $MarginContainer/HBoxContainer/ProgressContainer/HBoxContainer/LevelProgressBar
@onready var multiplier_panel: Control = $MarginContainer/HBoxContainer/MultiplierPanel
@onready var multiplier_label: Label = $MarginContainer/HBoxContainer/MultiplierPanel/MarginContainer/MultiplierLabel
@onready var pause_button: Button = %PauseButton

var _gold_tween: Tween
var _multiplier_tween: Tween
var _progress_tween: Tween
var _displayed_gold: int = 0
var is_boss_mode: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Ensure pivot centers for punch scale animations
	_update_pivots()
	get_viewport().size_changed.connect(_update_pivots)
	
	if pause_button:
		pause_button.pressed.connect(_on_pause_button_pressed)
	
	GameState.doubloons_changed.connect(_on_doubloons_changed)
	GameState.multiplier_changed.connect(_on_multiplier_changed)
	GameState.progress_changed.connect(_on_progress_changed)
	
	# Boss lifecycle events now come from EventBus (cross-boundary, Rule B)
	if get_node_or_null("/root/EventBus"):
		EventBus.boss_spawned_event.connect(_on_boss_spawned)
		EventBus.boss_health_changed.connect(_on_boss_health_changed)
	
	# Set initial state
	_displayed_gold = GameState.doubloons
	gold_label.text = str(GameState.doubloons)
	_update_multiplier_text(GameState.active_multiplier, GameState.multiplier_mode)
	level_progress_bar.max_value = GameState.level_distance_target
	level_progress_bar.value = GameState.distance_traveled
	if "current_level" in GameState:
		level_title.text = "WORLD %d - COVE RUN" % GameState.current_level
	if GameState.is_game_active:
		_setup_level_1_tutorial_prompt()

func _unhandled_input(event: InputEvent) -> void:
	if not GameState.is_game_active or get_tree().paused:
		return
	var is_p_pressed: bool = false
	if event is InputEventKey:
		var key_ev := event as InputEventKey
		is_p_pressed = key_ev.pressed and not key_ev.echo and key_ev.keycode == KEY_P
	if event.is_action_pressed("ui_cancel") or is_p_pressed:
		get_viewport().set_input_as_handled()
		_on_pause_button_pressed()

func _on_pause_button_pressed() -> void:
	if not GameState.is_game_active or get_tree().paused:
		return
	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("gate_passes")
	var pause_scene: PackedScene = preload("res://src/ui/pause_menu.tscn")
	if pause_scene:
		var pause_menu: Node = pause_scene.instantiate()
		get_parent().add_child(pause_menu)

func _on_boss_spawned(boss_name: String, max_hp: int) -> void:
	is_boss_mode = true
	if level_title:
		level_title.text = "⚔ " + boss_name.to_upper() + " ⚔"
		level_title.modulate = Color(1.0, 0.3, 0.3)
	if level_progress_bar:
		level_progress_bar.max_value = max_hp
		level_progress_bar.value = max_hp
		var red_fill: StyleBoxFlat = StyleBoxFlat.new()
		red_fill.bg_color = Color(0.95, 0.15, 0.15)
		red_fill.corner_radius_top_left = 7
		red_fill.corner_radius_top_right = 7
		red_fill.corner_radius_bottom_left = 7
		red_fill.corner_radius_bottom_right = 7
		level_progress_bar.add_theme_stylebox_override("fill", red_fill)

func _on_boss_health_changed(current: int, max_hp: int) -> void:
	if not level_progress_bar:
		return
	level_progress_bar.max_value = max_hp
	if _progress_tween and _progress_tween.is_valid():
		_progress_tween.kill()
	_progress_tween = create_tween()
	_progress_tween.tween_property(level_progress_bar, "value", clamp(current, 0, max_hp), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _update_pivots() -> void:
	if gold_container:
		gold_container.pivot_offset = gold_container.size * 0.5
	if multiplier_panel:
		multiplier_panel.pivot_offset = multiplier_panel.size * 0.5

func _on_doubloons_changed(new_amount: int) -> void:
	if not gold_label:
		return
		
	if _gold_tween and _gold_tween.is_valid():
		_gold_tween.kill()
		
	_gold_tween = create_tween().set_parallel(true)
	
	# Punch scale on gold panel
	if gold_container:
		gold_container.pivot_offset = gold_container.size * 0.5
		var scale_tween: Tween = create_tween().set_parallel(false)
		scale_tween.tween_property(gold_container, "scale", Vector2(1.2, 1.2), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		scale_tween.tween_property(gold_container, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		
	# Smooth count-up / count-down tween
	var start_gold: int = _displayed_gold
	_gold_tween.tween_method(func(val: int) -> void:
		_displayed_gold = val
		gold_label.text = str(val)
	, start_gold, new_amount, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _on_multiplier_changed(val: float, mode: String) -> void:
	_update_multiplier_text(val, mode)
	
	if multiplier_panel:
		if _multiplier_tween and _multiplier_tween.is_valid():
			_multiplier_tween.kill()
			
		multiplier_panel.pivot_offset = multiplier_panel.size * 0.5
		_multiplier_tween = create_tween().set_parallel(false)
		_multiplier_tween.tween_property(multiplier_panel, "scale", Vector2(1.3, 1.3), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_multiplier_tween.tween_property(multiplier_panel, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

func _update_multiplier_text(val: float, mode: String) -> void:
	if not multiplier_label:
		return
	var prefix: String = "+" if mode == "+" else "x"
	var val_str: String = str(int(val)) if val == int(val) else "%.1f" % val
	multiplier_label.text = prefix + val_str

func _on_progress_changed(current: float, total: float) -> void:
	if not level_progress_bar or is_boss_mode:
		return
	level_progress_bar.max_value = max(1.0, total)
	
	if _progress_tween and _progress_tween.is_valid():
		_progress_tween.kill()
		
	_progress_tween = create_tween()
	_progress_tween.tween_property(level_progress_bar, "value", clamp(current, 0.0, total), 0.1).set_trans(Tween.TRANS_LINEAR)

var _tutorial_swipe_prompt: Control = null

func on_game_started() -> void:
	_setup_level_1_tutorial_prompt()

func _setup_level_1_tutorial_prompt() -> void:
	if GameState.current_level != 1 or GameState.tutorial_step > GameState.TutorialStep.LEVEL_1_IN_PROGRESS:
		return

	if _tutorial_swipe_prompt and is_instance_valid(_tutorial_swipe_prompt):
		return

	var prompt_container: PanelContainer = PanelContainer.new()
	prompt_container.name = "TutorialSwipePrompt"
	prompt_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.07, 0.04, 0.90)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.96, 0.72, 0.22, 0.95)
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_right = 14
	style.corner_radius_bottom_left = 14
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	style.shadow_color = Color(0, 0, 0, 0.6)
	style.shadow_size = 6
	prompt_container.add_theme_stylebox_override("panel", style)

	var label: Label = Label.new()
	label.text = "◀  DRAG / SWERVE TO STEER  ▶"
	label.add_theme_font_override("font", preload("res://assets/fonts/CarterOne.ttf"))
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35, 1.0))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_container.add_child(label)

	add_child(prompt_container)
	_tutorial_swipe_prompt = prompt_container

	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	prompt_container.custom_minimum_size = Vector2(340, 46)
	prompt_container.position = Vector2((vp_size.x - 340.0) * 0.5, vp_size.y * 0.68)
	prompt_container.pivot_offset = Vector2(170, 23)

	var t: Tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(prompt_container, "scale", Vector2(1.05, 1.05), 0.55)
	t.tween_property(prompt_container, "scale", Vector2.ONE, 0.55)

	if EventBus and EventBus.has_signal("player_swerved"):
		EventBus.player_swerved.connect(_dismiss_swipe_prompt, CONNECT_ONE_SHOT)

func _dismiss_swipe_prompt() -> void:
	if not _tutorial_swipe_prompt or not is_instance_valid(_tutorial_swipe_prompt):
		return
	var target: Control = _tutorial_swipe_prompt
	_tutorial_swipe_prompt = null
	var fade: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	fade.tween_property(target, "modulate:a", 0.0, 0.3)
	fade.tween_callback(target.queue_free)
