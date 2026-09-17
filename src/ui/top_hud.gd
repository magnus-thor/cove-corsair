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
