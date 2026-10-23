class_name LevelTestHarness
extends Node3D

## In-Engine Level Tester & Developer Inspection Harness
## Allows immediate F6 execution of any level from 1 to 45.
## Supports instant level swapping, isolated boss testing, vessel/crew selection, and real-time inspector tuning.

const AVAILABLE_VESSELS: Array[String] = [
	"sloop",
	"dinghy",
	"ironclad",
	"bombard_skiff"
]

const VESSEL_NAMES: Dictionary = {
	"sloop": "The Sloop",
	"dinghy": "The Dinghy",
	"ironclad": "The Ironclad",
	"bombard_skiff": "The Bombard Skiff"
}

const AVAILABLE_CREW: Array[String] = [
	"none",
	"monkey_bomber",
	"skeleton_tosser",
	"grease_monkey"
]

const CREW_NAMES: Dictionary = {
	"none": "None (No Crew)",
	"monkey_bomber": "Monkey Bomber",
	"skeleton_tosser": "Skeleton Tosser",
	"grease_monkey": "Grease Monkey"
}

@export_range(1, 45) var target_level: int = 3
@export var jump_straight_to_boss: bool = false
@export_enum("sloop", "dinghy", "ironclad", "bombard_skiff") var target_vessel: String = "sloop"
@export_range(1, 10) var vessel_level: int = 7
@export_enum("none", "monkey_bomber", "skeleton_tosser", "grease_monkey") var target_crew: String = "monkey_bomber"
@export_range(1, 5) var crew_level: int = 3
@export var main_game_scene: PackedScene = preload("res://src/core/main_game.tscn")

var _current_game_instance: Node3D = null
var _hud_layer: CanvasLayer = null
var _level_label: Label = null
var _vessel_status_label: Label = null
var _boss_label: Label = null
var _shortcuts_label: Label = null
var _vessel_option_btn: OptionButton = null
var _crew_option_btn: OptionButton = null

func _ready() -> void:
	print("==================================================")
	print("   COVE CORSAIR - IN-ENGINE LEVEL TEST HARNESS    ")
	print("   Active Target Level: %d / 45                  " % target_level)
	print("   Vessel: %s (Tier %d) | Crew: %s (Lvl %d)       " % [target_vessel, vessel_level, target_crew, crew_level])
	print("   Shortcuts: [ / ] = Step Level | V = Vessel | C = Crew | B = Boss | R = Reload")
	print("==================================================")
	
	_setup_debug_ui()
	_load_target_level(target_level, jump_straight_to_boss)

func _setup_debug_ui() -> void:
	_hud_layer = CanvasLayer.new()
	_hud_layer.name = "HarnessDebugUI"
	_hud_layer.layer = 120 # Above standard HUD
	add_child(_hud_layer)
	
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "HarnessPanel"
	_hud_layer.add_child(panel)
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.offset_left = 16.0
	panel.offset_top = 16.0
	panel.offset_right = 440.0
	
	# Semi-transparent dark background
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.08, 0.12, 0.88)
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
	
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)
	
	var title: Label = Label.new()
	title.text = "⚓ LEVEL TEST HARNESS (DEBUG)"
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)
	
	_level_label = Label.new()
	_level_label.text = "Level: %d / 45" % target_level
	_level_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	_level_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(_level_label)
	
	_vessel_status_label = Label.new()
	_vessel_status_label.text = "Vessel: %s (Tier %d) | Crew: %s" % [target_vessel, vessel_level, target_crew]
	_vessel_status_label.add_theme_color_override("font_color", Color(0.3, 0.85, 0.95))
	_vessel_status_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(_vessel_status_label)
	
	# Vessel Selector Row
	var vessel_row: HBoxContainer = HBoxContainer.new()
	vessel_row.add_theme_constant_override("separation", 8)
	vbox.add_child(vessel_row)
	
	var vessel_lbl: Label = Label.new()
	vessel_lbl.text = "Choose Vessel:"
	vessel_lbl.custom_minimum_size = Vector2(100, 0)
	vessel_lbl.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	vessel_lbl.add_theme_font_size_override("font_size", 12)
	vessel_row.add_child(vessel_lbl)
	
	_vessel_option_btn = OptionButton.new()
	_vessel_option_btn.focus_mode = Control.FOCUS_NONE
	_vessel_option_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i: int in range(AVAILABLE_VESSELS.size()):
		var v_id: String = AVAILABLE_VESSELS[i]
		var v_title: String = String(VESSEL_NAMES.get(v_id, v_id))
		_vessel_option_btn.add_item("%s (Tier %d)" % [v_title, vessel_level], i)
		if v_id == target_vessel:
			_vessel_option_btn.selected = i
	_vessel_option_btn.item_selected.connect(_on_vessel_item_selected)
	vessel_row.add_child(_vessel_option_btn)
	
	# Crew Selector Row
	var crew_row: HBoxContainer = HBoxContainer.new()
	crew_row.add_theme_constant_override("separation", 8)
	vbox.add_child(crew_row)
	
	var crew_lbl: Label = Label.new()
	crew_lbl.text = "Choose Crew:"
	crew_lbl.custom_minimum_size = Vector2(100, 0)
	crew_lbl.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	crew_lbl.add_theme_font_size_override("font_size", 12)
	crew_row.add_child(crew_lbl)
	
	_crew_option_btn = OptionButton.new()
	_crew_option_btn.focus_mode = Control.FOCUS_NONE
	_crew_option_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i: int in range(AVAILABLE_CREW.size()):
		var c_id: String = AVAILABLE_CREW[i]
		var c_title: String = String(CREW_NAMES.get(c_id, c_id))
		_crew_option_btn.add_item(c_title, i)
		if c_id == target_crew:
			_crew_option_btn.selected = i
	_crew_option_btn.item_selected.connect(_on_crew_item_selected)
	crew_row.add_child(_crew_option_btn)
	
	_boss_label = Label.new()
	_boss_label.text = "Boss: Initializing..."
	_boss_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.6))
	_boss_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(_boss_label)
	
	_shortcuts_label = Label.new()
	_shortcuts_label.text = "[ [ / ] ]: Level  |  [ V ]: Vessel  |  [ C ]: Crew  |  [ B ]: Boss  |  [ R ]: Reload"
	_shortcuts_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
	_shortcuts_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(_shortcuts_label)

func _apply_vessel_and_crew_configuration() -> void:
	if not Engine.has_singleton("GameState") and not get_node_or_null("/root/GameState"):
		return
		
	# 1. Ensure target vessel is recognized and owned
	if not GameState.owned_vessels.has(target_vessel):
		GameState.owned_vessels.append(target_vessel)
		
	# 2. Configure Vessel Tier (Level 7 by default, capped by vessel capabilities)
	var max_tier: int = GameState.get_max_vessel_tier(target_vessel) if GameState.has_method("get_max_vessel_tier") else 10
	var effective_tier: int = clampi(vessel_level, 1, max_tier)
	GameState.vessel_tiers[target_vessel] = effective_tier
	GameState.active_vessel = target_vessel
	
	# 3. Configure Crew Member
	if not GameState.equipped_crew.has(target_vessel) or not (GameState.equipped_crew[target_vessel] is Dictionary):
		GameState.equipped_crew[target_vessel] = {}
	else:
		(GameState.equipped_crew[target_vessel] as Dictionary).clear()
		
	if target_crew != "" and target_crew != "none":
		GameState.unlocked_crew[target_crew] = crew_level
		GameState.auto_equip_crew_to_vessel(target_vessel, target_crew)
		
	GameState.active_vessel_changed.emit(target_vessel)

func _sync_ui_selectors() -> void:
	if _vessel_option_btn:
		var v_idx: int = AVAILABLE_VESSELS.find(target_vessel)
		if v_idx != -1 and _vessel_option_btn.selected != v_idx:
			_vessel_option_btn.selected = v_idx
	if _crew_option_btn:
		var c_idx: int = AVAILABLE_CREW.find(target_crew)
		if c_idx != -1 and _crew_option_btn.selected != c_idx:
			_crew_option_btn.selected = c_idx

func _update_hud_labels() -> void:
	var level_res: LevelData = GameState.get_current_level_resource() if GameState.has_method("get_current_level_resource") else null
	var level_title: String = level_res.level_title if level_res else "Level %d" % target_level
	var biome: String = level_res.biome_name if level_res and "biome_name" in level_res else "tropical"
	if _level_label:
		_level_label.text = "Level %d / 45: %s (%s)" % [target_level, level_title, biome.capitalize()]
	
	if _vessel_status_label:
		var v_name: String = String(VESSEL_NAMES.get(target_vessel, target_vessel))
		var eff_tier: int = GameState.get_vessel_tier(target_vessel) if GameState.has_method("get_vessel_tier") else vessel_level
		var c_name: String = String(CREW_NAMES.get(target_crew, target_crew))
		_vessel_status_label.text = "Ship: %s (Tier %d) | Crew: %s" % [v_name, eff_tier, c_name]

func _load_target_level(lvl: int, auto_boss: bool = false) -> void:
	target_level = clampi(lvl, 1, 45)
	
	# 1. Cleanup existing game instance if present before updating configuration
	if _current_game_instance and is_instance_valid(_current_game_instance):
		remove_child(_current_game_instance)
		_current_game_instance.queue_free()
		_current_game_instance = null
		
	# 2. Apply vessel and crew setup
	_apply_vessel_and_crew_configuration()
	
	# 3. Update GameState
	GameState.current_level = target_level
	GameState.current_selected_level = target_level
	GameState.should_auto_start = true
	GameState.is_game_active = true
	GameState.distance_traveled = 0.0
	GameState.boss_spawned = false
		
	# 4. Instantiate fresh MainGame instance
	if main_game_scene:
		_current_game_instance = main_game_scene.instantiate() as Node3D
		add_child(_current_game_instance)
		
	# 5. Refresh debug HUD info & UI dropdowns
	_update_hud_labels()
	_sync_ui_selectors()
		
	if auto_boss:
		call_deferred("_deferred_jump_to_boss")
	else:
		_poll_boss_status()

func select_vessel(v_id: String) -> void:
	if not AVAILABLE_VESSELS.has(v_id):
		return
	target_vessel = v_id
	_sync_ui_selectors()
	print("[TEST HARNESS] Selected Vessel: %s (Level %d)" % [target_vessel, vessel_level])
	_load_target_level(target_level, false)

func select_crew(c_id: String) -> void:
	if not AVAILABLE_CREW.has(c_id):
		return
	target_crew = c_id
	_sync_ui_selectors()
	print("[TEST HARNESS] Selected Crew: %s" % target_crew)
	_load_target_level(target_level, false)

func _cycle_vessel() -> void:
	var cur_idx: int = AVAILABLE_VESSELS.find(target_vessel)
	var next_idx: int = (cur_idx + 1) % AVAILABLE_VESSELS.size()
	select_vessel(AVAILABLE_VESSELS[next_idx])

func _cycle_crew() -> void:
	var cur_idx: int = AVAILABLE_CREW.find(target_crew)
	var next_idx: int = (cur_idx + 1) % AVAILABLE_CREW.size()
	select_crew(AVAILABLE_CREW[next_idx])

func _on_vessel_item_selected(index: int) -> void:
	if index >= 0 and index < AVAILABLE_VESSELS.size():
		select_vessel(AVAILABLE_VESSELS[index])

func _on_crew_item_selected(index: int) -> void:
	if index >= 0 and index < AVAILABLE_CREW.size():
		select_crew(AVAILABLE_CREW[index])

func _deferred_jump_to_boss() -> void:
	# Give scene tree 1 frame to initialize chunks
	await get_tree().process_frame
	jump_to_boss()

func jump_to_boss() -> void:
	var ctrl: Node = get_tree().get_first_node_in_group("level_controller")
	if ctrl and ctrl.has_method("jump_to_boss"):
		ctrl.call("jump_to_boss")
		if _boss_label:
			_boss_label.text = "Boss: Jumped to Boss Arena"
		print("[TEST HARNESS] Jumped directly to boss arena for Level %d" % target_level)
	else:
		var assembler: Node = get_tree().get_first_node_in_group("chunk_assembler")
		if assembler and assembler.has_method("jump_to_boss"):
			assembler.call("jump_to_boss")
			if _boss_label:
				_boss_label.text = "Boss: Jumped to Boss Arena"

func _poll_boss_status() -> void:
	var boss: Node = get_tree().get_first_node_in_group("boss")
	if _boss_label:
		if boss and is_instance_valid(boss):
			var hp: int = int(boss.get("current_hp")) if ("current_hp" in boss) else 0
			var max_h: int = int(boss.get("max_hp")) if ("max_hp" in boss) else 0
			_boss_label.text = "Boss: %s (%d/%d HP)" % [boss.name, hp, max_h]
		else:
			_boss_label.text = "Boss: In Approach / Buffer Phase"

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.is_pressed() or event.is_echo():
		return
		
	var key: Key = (event as InputEventKey).keycode
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
		KEY_V:
			print("[TEST HARNESS] Key 'V': Cycling Vessel")
			_cycle_vessel()
		KEY_C:
			print("[TEST HARNESS] Key 'C': Cycling Crew")
			_cycle_crew()
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
