class_name VictoryScreen
extends CanvasLayer

@export var star_inactive_color: Color = Color(0.35, 0.38, 0.45, 1.0)
@export var star_active_color: Color = Color(1.0, 0.84, 0.0, 1.0)

@onready var panel_container: PanelContainer = $CenterContainer/PanelContainer
@onready var title_label: Label = %TitleLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var star_1: Label = %Star1
@onready var star_2: Label = %Star2
@onready var star_3: Label = %Star3
@onready var star_summary_label: Label = %StarSummaryLabel
@onready var doubloons_label: Label = %DoubloonsLabel
@onready var targets_label: Label = %TargetsLabel
@onready var mobs_label: Label = %MobsLabel
@onready var hits_label: Label = %HitsLabel
@onready var boss_label: Label = %BossLabel
@onready var retry_button: Button = %RetryButton
@onready var next_level_button: Button = %NextLevelButton
@onready var start_screen_button: Button = %StartScreenButton

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	
	if retry_button:
		retry_button.pressed.connect(_on_retry_pressed)
	if next_level_button:
		next_level_button.pressed.connect(_on_next_level_pressed)
	if start_screen_button:
		start_screen_button.pressed.connect(_on_start_screen_pressed)

func show_victory(doubloons_earned: int, targets_hit: int, stars_earned: int = 3) -> void:
	visible = true
	get_tree().paused = true
	GameState.set_performance_mode(false)
	
	# Record high score, star mastery, and advance progression
	GameState.record_level_score(GameState.current_level, doubloons_earned)
	GameState.record_level_stars(GameState.current_level, stars_earned)
	GameState.unlock_next_level()
	
	match GameState.last_cleared_level:
		1:
			if title_label: title_label.text = "LEVEL 1 VICTORY"
			if subtitle_label: subtitle_label.text = "COVE 1 CLEARED: SMUGGLER'S RUN"
			if boss_label: boss_label.text = "Captain Ironjaw"
			if next_level_button: next_level_button.text = "CONTINUE TO RIVER MAP"
		2:
			if title_label: title_label.text = "LEVEL 2 VICTORY"
			if subtitle_label: subtitle_label.text = "COVE 2 CLEARED: BLACK TIDE BAYOU"
			if boss_label: boss_label.text = "The Phantom Dredge"
			if next_level_button: next_level_button.text = "CONTINUE TO RIVER MAP"
		3:
			if title_label: title_label.text = "LEVEL 3 VICTORY"
			if subtitle_label: subtitle_label.text = "COVE 3 CLEARED: BRIMSTONE BASTION"
			if boss_label: boss_label.text = "The Siege Fortress"
			if next_level_button: next_level_button.text = "CONTINUE TO RIVER MAP"
		4:
			if title_label: title_label.text = "LEVEL 4 VICTORY"
			if subtitle_label: subtitle_label.text = "COVE 4 CLEARED: SMUGGLER'S NIGHTMARE"
			if boss_label: boss_label.text = "Captain Ironjaw (Nightmare)"
			if next_level_button: next_level_button.text = "CONTINUE TO RIVER MAP"
		5:
			if title_label: title_label.text = "LEVEL 5 VICTORY"
			if subtitle_label: subtitle_label.text = "COVE 5 CLEARED: BLACK TIDE ABYSS"
			if boss_label: boss_label.text = "The Phantom Dredge (Abyss)"
			if next_level_button: next_level_button.text = "CONTINUE TO RIVER MAP"
		_:
			if title_label: title_label.text = "CAMPAIGN VICTORY!"
			if subtitle_label: subtitle_label.text = "ALL 6 COVES CONQUERED - ULTIMATE PIRATE KING!"
			if boss_label: boss_label.text = "The Infernal Siege Fortress"
			if next_level_button: next_level_button.text = "CONTINUE TO RIVER MAP"
			
	if doubloons_label:
		doubloons_label.text = "0"
	if targets_label:
		targets_label.text = "0"

	if star_summary_label:
		match stars_earned:
			3:
				star_summary_label.text = "★★★ 3 STARS - PERFECT FLAWLESS RUN!"
				star_summary_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0, 1.0))
			2:
				star_summary_label.text = "★★☆ 2 STARS - EXCELLENT VOYAGE!"
				star_summary_label.add_theme_color_override("font_color", Color(0.9, 0.72, 0.25, 1.0))
			_:
				star_summary_label.text = "★☆☆ 1 STAR - EXPEDITION CLEARED"
				star_summary_label.add_theme_color_override("font_color", Color(0.75, 0.65, 0.5, 1.0))

	if mobs_label:
		if GameState.mobs_leaked == 0:
			mobs_label.text = "0 ★ (FLAWLESS)"
			mobs_label.add_theme_color_override("font_color", Color(0.2, 0.65, 0.3, 1.0))
		else:
			mobs_label.text = "%d ESCAPED" % GameState.mobs_leaked
			mobs_label.add_theme_color_override("font_color", Color(0.85, 0.25, 0.15, 1.0))

	if hits_label:
		if GameState.hits_taken == 0:
			hits_label.text = "0 ★ (UNTOUCHED)"
			hits_label.add_theme_color_override("font_color", Color(0.2, 0.65, 0.3, 1.0))
		else:
			hits_label.text = "%d HITS TAKEN" % GameState.hits_taken
			hits_label.add_theme_color_override("font_color", Color(0.85, 0.25, 0.15, 1.0))
	
	# Reset stars to inactive state
	var stars: Array[Label] = [star_1, star_2, star_3]
	for s in stars:
		if s:
			s.add_theme_color_override("font_color", star_inactive_color)
			s.scale = Vector2.ONE
			s.pivot_offset = s.size / 2.0
	
	# Animate panel pop-in (Scale 0.7 -> 1.0 with Ease Out Back)
	if panel_container:
		panel_container.pivot_offset = panel_container.size / 2.0
		panel_container.scale = Vector2(0.7, 0.7)
		panel_container.modulate.a = 0.0
		
		var entrance_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		entrance_tween.tween_property(panel_container, "scale", Vector2(1.0, 1.0), 0.45)
		entrance_tween.tween_property(panel_container, "modulate:a", 1.0, 0.3)
		
		await entrance_tween.finished
	
	# Number tally animation (Doubloons & Targets)
	_animate_tally(doubloons_earned, targets_hit)
	
	# Sequential Star Reveal
	await get_tree().create_timer(0.2, true, false, true).timeout
	_animate_stars(stars_earned)

func _animate_tally(doubloons_earned: int, targets_hit: int) -> void:
	var tally_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	tally_tween.tween_method(func(val: float):
		if doubloons_label:
			doubloons_label.text = str(int(val))
	, 0.0, float(doubloons_earned), 0.9)
	
	tally_tween.tween_method(func(val: float):
		if targets_label:
			targets_label.text = str(int(val))
	, 0.0, float(targets_hit), 0.9)

func _animate_stars(stars_earned: int) -> void:
	var stars: Array[Label] = [star_1, star_2, star_3]
	var count = clamp(stars_earned, 0, 3)
	
	for i in range(count):
		var star = stars[i]
		if not star:
			continue
			
		star.pivot_offset = star.size / 2.0
		star.add_theme_color_override("font_color", star_active_color)
		star.scale = Vector2(1.4, 1.4)
		
		# Play audio chime
		AudioManager.play_sfx("coin_pickups", 0.95 + i * 0.1, 1.05 + i * 0.1, 2.0)
		
		var star_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		star_tween.tween_property(star, "scale", Vector2(1.0, 1.0), 0.3)
		
		await get_tree().create_timer(0.25, true, false, true).timeout

func _on_retry_pressed() -> void:
	get_tree().paused = false
	GameState.should_auto_start = true
	GameState.just_cleared_level = false
	GameState.reset_level()
	get_tree().reload_current_scene()

func _on_next_level_pressed() -> void:
	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("gate_passes")
	get_tree().paused = false
	GameState.should_auto_start = false
	GameState.reset_level()
	get_tree().reload_current_scene()

func _on_start_screen_pressed() -> void:
	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("gate_passes")
	get_tree().paused = false
	GameState.should_auto_start = false
	GameState.reset_level()
	get_tree().change_scene_to_file("res://src/features/hub/pirate_lair_hub.tscn")


