class_name LevelTestHarness
extends Node3D

## In-Engine Level Tester & Developer Inspection Harness
## Allows immediate F6 execution of any level from 1 to 45.
## Supports instant level swapping, isolated boss testing, and real-time inspector tuning.

@export_range(1, 45) var target_level: int = 3
@export var jump_straight_to_boss: bool = false
@export var main_game_scene: PackedScene = preload("res://src/core/main_game.tscn")

var _current_game_instance: Node3D = null
var _hud_layer: CanvasLayer = null
var _level_label: Label = null
var _boss_label: Label = null
var _shortcuts_label: Label = null

func _ready() -> void:
	print("==================================================")
	print("   COVE CORSAIR - IN-ENGINE LEVEL TEST HARNESS    ")
	print("   Active Target Level: %d / 45                  " % target_level)
	print("   Shortcuts: [ / ] = Step Level | B = Boss Arena | R = Reload")
	print("==================================================")
	
	_setup_debug_ui()
	_load_target_level(target_level, jump_straight_to_boss)

func _setup_debug_ui() -> void:
	_hud_layer = CanvasLayer.new()
	_hud_layer.name = "HarnessDebugUI"
	_hud_layer.layer = 120 # Above standard HUD
	add_child(_hud_layer)
	
	var panel = PanelContainer.new()
	panel.name = "HarnessPanel"
	_hud_layer.add_child(panel)
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.offset_left = 16.0
	panel.offset_top = 16.0
	panel.offset_right = 360.0
	panel.offset_bottom = 120.0
	
	# Semi-transparent dark background
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.08, 0.12, 0.85)
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.border_width_bottom = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_color = Color(0.18, 0.65, 0.95, 0.9)
	style.content_margin_left = 12.0
	style.content_margin_top = 10.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 10.0
	panel.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)
	
	var title = Label.new()
	title.text = "⚓ LEVEL TEST HARNESS (DEBUG)"
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)
	
	_level_label = Label.new()
	_level_label.text = "Level: %d / 45" % target_level
	_level_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	_level_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(_level_label)
	
	_boss_label = Label.new()
	_boss_label.text = "Boss: Initializing..."
	_boss_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.6))
	_boss_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(_boss_label)
	
	_shortcuts_label = Label.new()
	_shortcuts_label.text = "[ [ / ] ]: Prev/Next Level  |  [ B ]: Jump to Boss  |  [ R ]: Reload"
	_shortcuts_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
	_shortcuts_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(_shortcuts_label)

func _load_target_level(lvl: int, auto_boss: bool = false) -> void:
	target_level = clampi(lvl, 1, 45)
	
	# 1. Update GameState
	GameState.current_level = target_level
	GameState.current_selected_level = target_level
	GameState.should_auto_start = true
	GameState.is_game_active = true
	GameState.distance_traveled = 0.0
	GameState.boss_spawned = false
	
	# 2. Cleanup existing game instance if present
	if _current_game_instance and is_instance_valid(_current_game_instance):
		_current_game_instance.queue_free()
		_current_game_instance = null
		
	# 3. Instantiate fresh MainGame instance
	if main_game_scene:
		_current_game_instance = main_game_scene.instantiate() as Node3D
		add_child(_current_game_instance)
		
	# 4. Refresh debug HUD info
	var level_res = GameState.get_current_level_resource()
	var level_title = level_res.level_title if level_res else "Level %d" % target_level
	var biome = level_res.biome_name if level_res and "biome_name" in level_res else "tropical"
	if _level_label:
		_level_label.text = "Level %d / 45: %s (%s)" % [target_level, level_title, biome.capitalize()]
		
	if auto_boss:
		call_deferred("_deferred_jump_to_boss")
	else:
		_poll_boss_status()

func _deferred_jump_to_boss() -> void:
	# Give scene tree 1 frame to initialize chunks
	await get_tree().process_frame
	jump_to_boss()

func jump_to_boss() -> void:
	var ctrl = get_tree().get_first_node_in_group("level_controller")
	if ctrl and ctrl.has_method("jump_to_boss"):
		ctrl.jump_to_boss()
		if _boss_label:
			_boss_label.text = "Boss: Jumped to Boss Arena"
		print("[TEST HARNESS] Jumped directly to boss arena for Level %d" % target_level)
	else:
		var assembler = get_tree().get_first_node_in_group("chunk_assembler")
		if assembler and assembler.has_method("jump_to_boss"):
			assembler.jump_to_boss()
			if _boss_label:
				_boss_label.text = "Boss: Jumped to Boss Arena"

func _poll_boss_status() -> void:
	var boss = get_tree().get_first_node_in_group("boss")
	if _boss_label:
		if boss and is_instance_valid(boss):
			var hp = boss.current_hp if "current_hp" in boss else 0
			var max_h = boss.max_hp if "max_hp" in boss else 0
			_boss_label.text = "Boss: %s (%d/%d HP)" % [boss.name, hp, max_h]
		else:
			_boss_label.text = "Boss: In Approach / Buffer Phase"

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.is_pressed() or event.is_echo():
		return
		
	var key = (event as InputEventKey).keycode
	match key:
		KEY_BRACKETLEFT:
			# Step backward
			if target_level > 1:
				print("[TEST HARNESS] Key '[': Loading Level %d" % (target_level - 1))
				_load_target_level(target_level - 1, false)
		KEY_BRACKETRIGHT:
			# Step forward
			if target_level < 45:
				print("[TEST HARNESS] Key ']': Loading Level %d" % (target_level + 1))
				_load_target_level(target_level + 1, false)
		KEY_B:
			# Jump directly to boss
			print("[TEST HARNESS] Key 'B': Jumping to boss chunk for Level %d" % target_level)
			jump_to_boss()
		KEY_R:
			# Quick reload
			print("[TEST HARNESS] Key 'R': Reloading Level %d" % target_level)
			_load_target_level(target_level, false)

func _process(_delta: float) -> void:
	_poll_boss_status()
