extends CanvasLayer

@onready var gold_container: Control = $MarginContainer/HBoxContainer/GoldPanel
@onready var gold_label: Label = $MarginContainer/HBoxContainer/GoldPanel/MarginContainer/HBoxContainer/GoldLabel
@onready var level_title: Label = $MarginContainer/HBoxContainer/ProgressContainer/LevelTitle
@onready var level_progress_bar: ProgressBar = $MarginContainer/HBoxContainer/ProgressContainer/HBoxContainer/LevelProgressBar
@onready var multiplier_panel: Control = $MarginContainer/HBoxContainer/MultiplierPanel
@onready var multiplier_label: Label = $MarginContainer/HBoxContainer/MultiplierPanel/MarginContainer/MultiplierLabel

# Boss HUD components
@onready var boss_health_panel: PanelContainer = $MarginContainer/HBoxContainer/ProgressContainer/BossHealthPanel
@onready var boss_name_label: Label = $MarginContainer/HBoxContainer/ProgressContainer/BossHealthPanel/MarginContainer/VBoxContainer/BossNameLabel
@onready var segments_container: HBoxContainer = $MarginContainer/HBoxContainer/ProgressContainer/BossHealthPanel/MarginContainer/VBoxContainer/SegmentsContainer

var _gold_tween: Tween
var _multiplier_tween: Tween
var _progress_tween: Tween
var _displayed_gold: int = 0
var _boss_segments: Array[ProgressBar] = []

func _ready() -> void:
	add_to_group("top_hud")
	_update_pivots()
	get_viewport().size_changed.connect(_update_pivots)
	
	# Cache boss progress bars
	if segments_container:
		for child in segments_container.get_children():
			if child is ProgressBar:
				_boss_segments.append(child)
				
	# Hide boss HUD by default
	if boss_health_panel:
		boss_health_panel.visible = false
		boss_health_panel.modulate.a = 0.0
		
	# Connect to GameState Autoload signals
	if Engine.has_singleton("GameState") or get_node_or_null("/root/GameState"):
		GameState.doubloons_changed.connect(_on_doubloons_changed)
		GameState.multiplier_changed.connect(_on_multiplier_changed)
		GameState.progress_changed.connect(_on_progress_changed)
		GameState.boss_spawned_event.connect(_on_boss_spawned)
		GameState.boss_health_changed.connect(_on_boss_health_changed)
		
		# Set initial state
		_displayed_gold = GameState.doubloons
		gold_label.text = str(GameState.doubloons)
		_update_multiplier_text(GameState.active_multiplier, GameState.multiplier_mode)
		level_progress_bar.max_value = GameState.level_distance_target
		level_progress_bar.value = GameState.distance_traveled
		if "current_level" in GameState:
			if GameState.current_level == 1:
				level_title.text = "Level 1: Smuggler's Run"
			else:
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

# Boss logic
func _on_boss_spawned(boss_name: String, max_hp: int) -> void:
	if boss_name_label:
		boss_name_label.text = boss_name
		
	if boss_health_panel:
		boss_health_panel.visible = true
		var tween = create_tween()
		tween.tween_property(boss_health_panel, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _on_boss_health_changed(current: int, max_hp: int) -> void:
	if _boss_segments.is_empty():
		return
	var seg_count = _boss_segments.size()
	var segment_max = float(max_hp) / float(seg_count) if max_hp > 0 else 10.0
	
	for i in range(seg_count):
		var segment = _boss_segments[i]
		if not is_instance_valid(segment):
			continue
		var min_hp = float(i) * segment_max
		var segment_val = clamp(float(current) - min_hp, 0.0, segment_max) / segment_max * 10.0
		
		# Tween individual segment value smoothly
		var tween = create_tween()
		tween.tween_property(segment, "value", float(segment_val), 0.15).set_trans(Tween.TRANS_SINE)

func show_warning_alert(text: String) -> void:
	var label = get_node_or_null("MarginContainer/HBoxContainer/ProgressContainer/WarningLabel") as Label
	if label and is_instance_valid(label):
		label.text = text
		label.visible = true
		label.modulate = Color.WHITE
		label.modulate.a = 1.0
		
		var tween = create_tween()
		tween.tween_property(label, "modulate", Color(1.5, 1.5, 1.5, 1.0), 0.1)
		tween.tween_property(label, "modulate", Color.WHITE, 0.1)
		tween.tween_property(label, "modulate", Color(1.5, 1.5, 1.5, 1.0), 0.1)
		tween.tween_property(label, "modulate", Color.WHITE, 0.1)
		tween.tween_interval(2.5)
		tween.tween_property(label, "modulate:a", 0.0, 0.5)
		tween.tween_callback(func():
			if is_instance_valid(label):
				label.visible = false
		)


func trigger_red_flash() -> void:
	var flash = get_node_or_null("VignetteAlert")
	if flash:
		flash.queue_free()
		
	var panel = Panel.new()
	panel.name = "VignetteAlert"
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0) # Transparent center
	style.border_color = Color(0.8, 0.1, 0.1, 0.45) # Red border
	style.border_width_left = 60
	style.border_width_top = 60
	style.border_width_right = 60
	style.border_width_bottom = 60
	style.shadow_color = Color(0.8, 0.1, 0.1, 0.5)
	style.shadow_size = 40
	
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	
	var tween = create_tween()
	tween.tween_property(panel, "modulate:a", 0.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(panel.queue_free)
