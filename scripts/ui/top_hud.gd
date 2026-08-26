extends CanvasLayer

@onready var gold_container: Control = $MarginContainer/HBoxContainer/GoldPanel
@onready var gold_label: Label = $MarginContainer/HBoxContainer/GoldPanel/MarginContainer/HBoxContainer/GoldLabel
@onready var level_title: Label = $MarginContainer/HBoxContainer/ProgressContainer/LevelTitle
@onready var level_progress_bar: ProgressBar = $MarginContainer/HBoxContainer/ProgressContainer/HBoxContainer/LevelProgressBar
@onready var multiplier_panel: Control = $MarginContainer/HBoxContainer/MultiplierPanel
@onready var multiplier_label: Label = $MarginContainer/HBoxContainer/MultiplierPanel/MarginContainer/MultiplierLabel

var _gold_tween: Tween
var _multiplier_tween: Tween
var _progress_tween: Tween
var _displayed_gold: int = 0

func _ready() -> void:
	# Ensure pivot centers for punch scale animations
	_update_pivots()
	get_viewport().size_changed.connect(_update_pivots)
	
	# Connect to GameState Autoload signals
	if Engine.has_singleton("GameState") or get_node_or_null("/root/GameState"):
		GameState.doubloons_changed.connect(_on_doubloons_changed)
		GameState.multiplier_changed.connect(_on_multiplier_changed)
		GameState.progress_changed.connect(_on_progress_changed)
		
		# Set initial state
		_displayed_gold = GameState.doubloons
		gold_label.text = str(GameState.doubloons)
		_update_multiplier_text(GameState.active_multiplier, GameState.multiplier_mode)
		level_progress_bar.max_value = GameState.level_distance_target
		level_progress_bar.value = GameState.distance_traveled
		if "current_level" in GameState:
			level_title.text = "WORLD %d - COVE RUN" % GameState.current_level

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
		var scale_tween = create_tween().set_parallel(false)
		scale_tween.tween_property(gold_container, "scale", Vector2(1.2, 1.2), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		scale_tween.tween_property(gold_container, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		
	# Smooth count-up / count-down tween
	var start_gold = _displayed_gold
	_gold_tween.tween_method(func(val: int):
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
	var prefix = "+" if mode == "+" else "x"
	var val_str = str(int(val)) if val == int(val) else "%.1f" % val
	multiplier_label.text = prefix + val_str

func _on_progress_changed(current: float, total: float) -> void:
	if not level_progress_bar:
		return
	level_progress_bar.max_value = max(1.0, total)
	
	if _progress_tween and _progress_tween.is_valid():
		_progress_tween.kill()
		
	_progress_tween = create_tween()
	_progress_tween.tween_property(level_progress_bar, "value", clamp(current, 0.0, total), 0.1).set_trans(Tween.TRANS_LINEAR)
