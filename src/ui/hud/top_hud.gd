class_name TopHUD
extends CanvasLayer

@onready var gold_container: Control = $MarginContainer/HBoxContainer/GoldPanel
@onready var gold_label: Label = $MarginContainer/HBoxContainer/GoldPanel/MarginContainer/HBoxContainer/GoldLabel
@onready var progress_container: Control = $MarginContainer/HBoxContainer/ProgressContainer
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
		
	# Instantiate celebratory Fire Frenzy / Overdrive vignette
	var vignette_scene := preload("res://src/ui/hud/frenzy_vignette.tscn")
	if vignette_scene:
		var vig := vignette_scene.instantiate()
		add_child(vig)

	# Connect to GameState for economy signals (stay in GameState)
	if Engine.has_singleton("GameState") or get_node_or_null("/root/GameState"):
		GameState.doubloons_changed.connect(_on_doubloons_changed)
		GameState.multiplier_changed.connect(_on_multiplier_changed)
		GameState.progress_changed.connect(_on_progress_changed)
		
	# Connect to EventBus for cross-boundary boss lifecycle events
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
			if GameState.current_level == 1:
				level_title.text = "Level 1: Smuggler's Run"
			else:
				level_title.text = "WORLD %d - COVE RUN" % GameState.current_level

		# If game hasn't started yet, hide distance progress and multiplier
		if "is_game_active" in GameState and not GameState.is_game_active:
			_set_run_hud_visible(false)

var _tutorial_swipe_prompt: Control = null

func on_game_started() -> void:
	_set_run_hud_visible(true, true)
	_setup_level_1_tutorial_prompt()

## Teaches steering during the very first run (River Level 1 while the tutorial is at its first steps).
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
	style.set_border_width_all(2)
	style.border_color = Color(0.96, 0.72, 0.22, 0.95)
	style.set_corner_radius_all(14)
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

	var pulse: Tween = prompt_container.create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(prompt_container, "scale", Vector2(1.05, 1.05), 0.55)
	pulse.tween_property(prompt_container, "scale", Vector2.ONE, 0.55)

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

func _set_run_hud_visible(vis: bool, animate: bool = false) -> void:
	if not progress_container or not multiplier_panel:
		return
	if gold_container:
		gold_container.visible = vis
	if vis:
		progress_container.visible = true
		multiplier_panel.visible = true
		if animate:
			progress_container.modulate.a = 0.0
			multiplier_panel.modulate.a = 0.0
			if gold_container:
				gold_container.modulate.a = 0.0
			var t := create_tween().set_parallel(true)
			t.tween_property(progress_container, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			t.tween_property(multiplier_panel, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			if gold_container:
				t.tween_property(gold_container, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		else:
			progress_container.modulate.a = 1.0
			multiplier_panel.modulate.a = 1.0
			if gold_container:
				gold_container.modulate.a = 1.0
	else:
		progress_container.visible = false
		multiplier_panel.visible = false

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
		var scale_tween := create_tween().set_parallel(false)
		scale_tween.tween_property(gold_container, "scale", Vector2(1.2, 1.2), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		scale_tween.tween_property(gold_container, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		
	# Smooth count-up / count-down tween
	var start_gold := _displayed_gold
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
	var prefix := "+" if mode == "+" else "x"
	var val_str := str(int(val)) if val == int(val) else "%.1f" % val
	multiplier_label.text = prefix + val_str

func _on_progress_changed(current: float, total: float) -> void:
	if progress_container and not progress_container.visible and GameState.is_game_active:
		_set_run_hud_visible(true, true)
	if not level_progress_bar:
		return
	level_progress_bar.max_value = max(1.0, total)
	
	if _progress_tween and _progress_tween.is_valid():
		_progress_tween.kill()
		
	_progress_tween = create_tween()
	_progress_tween.tween_property(level_progress_bar, "value", clamp(current, 0.0, total), 0.1).set_trans(Tween.TRANS_LINEAR)

# Boss logic
func _on_boss_spawned(boss_name: String, _max_hp: int) -> void:
	if boss_name_label:
		boss_name_label.text = boss_name
		
	if boss_health_panel:
		boss_health_panel.visible = true
		var tween := create_tween()
		tween.tween_property(boss_health_panel, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _on_boss_health_changed(current: int, max_hp: int) -> void:
	if _boss_segments.is_empty():
		return
	var seg_count := _boss_segments.size()
	var segment_max := float(max_hp) / float(seg_count) if max_hp > 0 else 10.0
	
	for i in range(seg_count):
		var segment := _boss_segments[i]
		if not is_instance_valid(segment):
			continue
		var min_hp := float(i) * segment_max
		var segment_val: float = clampf(float(current) - min_hp, 0.0, segment_max) / segment_max * 10.0
		
		# Tween individual segment value smoothly
		var tween := create_tween()
		tween.tween_property(segment, "value", float(segment_val), 0.15).set_trans(Tween.TRANS_SINE)

func show_warning_alert(text: String) -> void:
	var label := get_node_or_null("MarginContainer/HBoxContainer/ProgressContainer/WarningLabel") as Label
	if label and is_instance_valid(label):
		label.text = text
		label.visible = true
		label.modulate = Color.WHITE
		label.modulate.a = 1.0
		
		var tween := create_tween()
		tween.tween_property(label, "modulate", Color(1.5, 1.5, 1.5, 1.0), 0.1)
		tween.tween_property(label, "modulate", Color.WHITE, 0.1)
		tween.tween_property(label, "modulate", Color(1.5, 1.5, 1.5, 1.0), 0.1)
		tween.tween_property(label, "modulate", Color.WHITE, 0.1)
		tween.tween_interval(2.5)
		tween.tween_property(label, "modulate:a", 0.0, 0.5)
		tween.tween_callback(func() -> void:
			if is_instance_valid(label):
				label.visible = false
		)


func trigger_red_flash() -> void:
	var flash := get_node_or_null("VignetteAlert")
	if flash:
		flash.queue_free()
		
	var panel := Panel.new()
	panel.name = "VignetteAlert"
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var style := StyleBoxFlat.new()
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
	
	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 0.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(panel.queue_free)
