class_name ShipyardUI
extends CanvasLayer

## Modern 2-Column Grid Shipyard Interface for Cove Corsair
## Features 2-column vessel cards, bottom inspection drawer, extensible tabs,
## and complete persistence/economy hookups.

signal shipyard_closed

@onready var back_button: Button = %BackButton
@onready var shipyard_title: Label = %ShipyardTitle
@onready var purse_label: Label = %PurseLabel
@onready var grid_container: GridContainer = %GridContainer

# Inspection Drawer Nodes
@onready var drawer_panel: PanelContainer = %DrawerPanel
@onready var drawer_title_label: Label = %DrawerTitleLabel
@onready var stat_hp_label: Label = %StatHpLabel
@onready var stat_hp_bar: ProgressBar = %StatHpBar
@onready var stat_speed_label: Label = %StatSpeedLabel
@onready var stat_speed_bar: ProgressBar = %StatSpeedBar
@onready var stat_cannons_label: Label = %StatCannonsLabel
@onready var stat_cannons_bar: ProgressBar = %StatCannonsBar
@onready var next_upgrade_label: Label = %NextUpgradeLabel
@onready var action_button: Button = %ActionButton
@onready var equip_button: Button = %EquipButton

# Category Tabs
@onready var tab_vessels: Button = %TabVessels
@onready var tab_crew: PanelContainer = %TabCrew
@onready var tab_ammo: PanelContainer = %TabAmmo

const CARD_SCENE: PackedScene = preload("res://src/ui/vessel_card.tscn")
const VesselCardScript = preload("res://src/ui/vessel_card.gd")

var vessel_ids: Array[String] = ["dinghy", "sloop", "ironclad"]
var card_instances: Dictionary = {} # vessel_id -> Node
var selected_vessel_id: String = "dinghy"

# Action button state enum
enum ActionState { BUY, UPGRADE, EQUIP, EQUIPPED, DISABLED }
var current_action_state: ActionState = ActionState.EQUIPPED

# Action button styleboxes
var style_btn_buy: StyleBoxFlat
var style_btn_upgrade: StyleBoxFlat
var style_btn_equip: StyleBoxFlat
var style_btn_disabled: StyleBoxFlat

func _ready() -> void:
	GameState.set_performance_mode(false)
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20

	_init_button_styles()

	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	if action_button:
		action_button.pressed.connect(_on_action_pressed)
	if equip_button:
		equip_button.pressed.connect(_on_equip_pressed)

	if tab_crew:
		tab_crew.gui_input.connect(_on_locked_tab_clicked)
	if tab_ammo:
		tab_ammo.gui_input.connect(_on_locked_tab_clicked)

	GameState.doubloons_changed.connect(_on_doubloons_changed)
	GameState.active_vessel_changed.connect(_on_active_vessel_changed)

	# Default selected vessel to active vessel
	if GameState.active_vessel in vessel_ids:
		selected_vessel_id = GameState.active_vessel
	else:
		selected_vessel_id = "dinghy"

	_build_grid_cards()
	_update_purse_display()
	_update_inspection_drawer()

func _init_button_styles() -> void:
	# Buy button style (Warm Bronze / Gold)
	style_btn_buy = StyleBoxFlat.new()
	style_btn_buy.bg_color = Color(0.82, 0.58, 0.18, 1.0)
	style_btn_buy.border_width_left = 4
	style_btn_buy.border_width_top = 4
	style_btn_buy.border_width_right = 4
	style_btn_buy.border_width_bottom = 4
	style_btn_buy.border_color = Color(1.0, 0.88, 0.45, 1.0)
	style_btn_buy.corner_radius_top_left = 16
	style_btn_buy.corner_radius_top_right = 16
	style_btn_buy.corner_radius_bottom_right = 16
	style_btn_buy.corner_radius_bottom_left = 16
	style_btn_buy.shadow_color = Color(0, 0, 0, 0.45)
	style_btn_buy.shadow_size = 6
	style_btn_buy.shadow_offset = Vector2(0, 4)

	# Upgrade button style (Crimson Red with Gold Trim, matching mock)
	style_btn_upgrade = StyleBoxFlat.new()
	style_btn_upgrade.bg_color = Color(0.72, 0.13, 0.18, 1.0) # #B8212E
	style_btn_upgrade.border_width_left = 4
	style_btn_upgrade.border_width_top = 4
	style_btn_upgrade.border_width_right = 4
	style_btn_upgrade.border_width_bottom = 4
	style_btn_upgrade.border_color = Color(0.95, 0.78, 0.28, 1.0) # #F2C747
	style_btn_upgrade.corner_radius_top_left = 16
	style_btn_upgrade.corner_radius_top_right = 16
	style_btn_upgrade.corner_radius_bottom_right = 16
	style_btn_upgrade.corner_radius_bottom_left = 16
	style_btn_upgrade.shadow_color = Color(0, 0, 0, 0.45)
	style_btn_upgrade.shadow_size = 6
	style_btn_upgrade.shadow_offset = Vector2(0, 4)

	# Equip button style (Vibrant Green)
	style_btn_equip = StyleBoxFlat.new()
	style_btn_equip.bg_color = Color(0.22, 0.72, 0.15, 1.0) # #38B826
	style_btn_equip.border_width_left = 4
	style_btn_equip.border_width_top = 4
	style_btn_equip.border_width_right = 4
	style_btn_equip.border_width_bottom = 4
	style_btn_equip.border_color = Color(0.12, 0.44, 0.08, 1.0)
	style_btn_equip.corner_radius_top_left = 16
	style_btn_equip.corner_radius_top_right = 16
	style_btn_equip.corner_radius_bottom_right = 16
	style_btn_equip.corner_radius_bottom_left = 16
	style_btn_equip.shadow_color = Color(0, 0, 0, 0.45)
	style_btn_equip.shadow_size = 6
	style_btn_equip.shadow_offset = Vector2(0, 4)

	# Disabled / Equipped button style
	style_btn_disabled = StyleBoxFlat.new()
	style_btn_disabled.bg_color = Color(0.35, 0.35, 0.35, 0.9)
	style_btn_disabled.border_width_left = 3
	style_btn_disabled.border_width_top = 3
	style_btn_disabled.border_width_right = 3
	style_btn_disabled.border_width_bottom = 3
	style_btn_disabled.border_color = Color(0.24, 0.24, 0.24, 1.0)
	style_btn_disabled.corner_radius_top_left = 16
	style_btn_disabled.corner_radius_top_right = 16
	style_btn_disabled.corner_radius_bottom_right = 16
	style_btn_disabled.corner_radius_bottom_left = 16

func _build_grid_cards() -> void:
	if not grid_container:
		return

	# Clear existing children
	for child in grid_container.get_children():
		child.queue_free()
	card_instances.clear()

	# 1. Configured vessels: dinghy, sloop, ironclad
	var index_counter = 1
	for v_id in vessel_ids:
		var card = CARD_SCENE.instantiate() as VesselCardScript
		grid_container.add_child(card)
		card.setup_vessel(v_id, index_counter)
		card.card_clicked.connect(_on_card_clicked)
		card_instances[v_id] = card
		index_counter += 1

	# 2. Locked Mystery 4th Card to match mock
	var mystery_card = CARD_SCENE.instantiate() as VesselCardScript
	grid_container.add_child(mystery_card)
	mystery_card.setup_mystery(index_counter)
	mystery_card.card_clicked.connect(_on_card_clicked)
	card_instances["mystery"] = mystery_card

	_refresh_card_selections()

func _refresh_card_selections() -> void:
	for v_id in card_instances:
		var card = card_instances[v_id] as VesselCardScript
		if is_instance_valid(card):
			card.set_selected(v_id == selected_vessel_id)
			card.update_status()

func _on_card_clicked(v_id: String) -> void:
	if v_id == "mystery":
		AudioManager.play_sfx("gate_passes", 0.8, 0.9)
		return

	if selected_vessel_id != v_id:
		selected_vessel_id = v_id
		AudioManager.play_sfx("gate_passes", 1.0, 1.1)
		_refresh_card_selections()
		_update_inspection_drawer()
	elif GameState.is_vessel_owned(v_id) and GameState.active_vessel != v_id:
		# Clicking an already selected owned vessel immediately equips it!
		if GameState.equip_vessel(v_id):
			AudioManager.play_sfx("coin_pickups", 1.0, 1.2)
			AudioManager.play_sfx("gate_passes")
			_refresh_card_selections()
			_update_inspection_drawer()

func _update_purse_display() -> void:
	if purse_label:
		purse_label.text = _format_number(GameState.doubloons)

func _update_inspection_drawer() -> void:
	if not GameState.VESSEL_CATALOG.has(selected_vessel_id):
		return

	var v_info = GameState.VESSEL_CATALOG[selected_vessel_id]
	var is_owned = GameState.is_vessel_owned(selected_vessel_id)
	var cur_tier = GameState.get_vessel_tier(selected_vessel_id)
	var is_active = (GameState.active_vessel == selected_vessel_id)

	# 1. Title with tier
	if drawer_title_label:
		if is_owned:
			drawer_title_label.text = "%s (TIER %d)" % [v_info["name"].to_upper(), cur_tier]
		else:
			drawer_title_label.text = "%s (UNOWNED)" % v_info["name"].to_upper()

	# 2. Stats & Gauges
	var base_hp = v_info["base_hp"]
	var base_speed = v_info["base_speed"]
	
	# Cannons description based on vessel & tier
	var cannon_desc = "1 Bow"
	var cannon_val = 1.0
	if selected_vessel_id == "dinghy":
		cannon_desc = "1 Bow"
		cannon_val = 1.0
	elif selected_vessel_id == "sloop":
		cannon_desc = "2 Bow"
		cannon_val = 2.0 if cur_tier == 1 else (3.0 if cur_tier == 2 else 4.0)
	elif selected_vessel_id == "ironclad":
		cannon_desc = "3 Heavy"
		cannon_val = 3.0 if cur_tier == 1 else (4.0 if cur_tier == 2 else 5.0)

	if stat_hp_label:
		stat_hp_label.text = "Hull: %d HP" % base_hp
	if stat_hp_bar:
		stat_hp_bar.value = clamp(float(base_hp) / 8.0 * 100.0, 12.0, 100.0)

	if stat_speed_label:
		stat_speed_label.text = "Speed: %.0f m/s" % base_speed
	if stat_speed_bar:
		stat_speed_bar.value = clamp(base_speed / 14.0 * 100.0, 15.0, 100.0)

	if stat_cannons_label:
		stat_cannons_label.text = "Cannons: %s" % cannon_desc
	if stat_cannons_bar:
		stat_cannons_bar.value = clamp(cannon_val / 5.0 * 100.0, 20.0, 100.0)

	# 3. Next Upgrade Preview Line
	if next_upgrade_label:
		if not is_owned:
			next_upgrade_label.text = "Acquire vessel to commission for open sea expeditions."
		elif cur_tier < 3:
			var next_tier = cur_tier + 1
			var next_text = ""
			if selected_vessel_id == "dinghy":
				if next_tier == 2:
					next_text = "Unlocks Mid-Deck Monkey Bomber Crew"
				else:
					next_text = "Unlocks Aft Skeleton Tosser Crew"
			elif selected_vessel_id == "sloop":
				if next_tier == 2:
					next_text = "Unlocks Monkey Bomber & Skeleton Crew"
				else:
					next_text = "Unlocks Port & Starboard Swivel Guns"
			elif selected_vessel_id == "ironclad":
				if next_tier == 2:
					next_text = "Unlocks Mid-Deck Deck Crew Gunners"
				else:
					next_text = "Unlocks Quad Swivel Gun Broadside Battery"
			next_upgrade_label.text = "Next: " + next_text
		else:
			next_upgrade_label.text = "Flagship Fully Mastered (Tier 3 Maximum)"

	# 4. Action & Equip Button Configuration
	if not action_button:
		return

	if not is_owned:
		if equip_button:
			equip_button.visible = false
		action_button.visible = true
		current_action_state = ActionState.BUY
		var price = v_info["purchase_price"]
		var can_buy = GameState.can_afford(price)
		action_button.text = "BUY VESSEL (%s)" % _format_number(price)
		action_button.add_theme_stylebox_override("normal", style_btn_buy)
		action_button.add_theme_stylebox_override("hover", style_btn_buy)
		action_button.add_theme_stylebox_override("pressed", style_btn_buy)
		action_button.disabled = not can_buy
		action_button.modulate = Color(1, 1, 1, 1) if can_buy else Color(0.7, 0.7, 0.7, 0.8)
	else:
		if equip_button:
			equip_button.visible = true
			if is_active:
				equip_button.text = "EQUIPPED ✓"
				equip_button.disabled = true
				equip_button.add_theme_stylebox_override("normal", style_btn_disabled)
				equip_button.add_theme_stylebox_override("disabled", style_btn_disabled)
				equip_button.modulate = Color(0.85, 1.0, 0.85, 0.95)
			else:
				equip_button.text = "EQUIP VESSEL"
				equip_button.disabled = false
				equip_button.add_theme_stylebox_override("normal", style_btn_equip)
				equip_button.add_theme_stylebox_override("hover", style_btn_equip)
				equip_button.add_theme_stylebox_override("pressed", style_btn_equip)
				equip_button.modulate = Color.WHITE

		if cur_tier < 3:
			# Owned and upgrade available
			action_button.visible = true
			current_action_state = ActionState.UPGRADE
			var next_tier = cur_tier + 1
			var cost = GameState.get_upgrade_cost(selected_vessel_id, next_tier)
			var can_upgrade = GameState.can_afford(cost)
			action_button.text = "UPGRADE T%d (%s)" % [next_tier, _format_number(cost)]
			action_button.add_theme_stylebox_override("normal", style_btn_upgrade)
			action_button.add_theme_stylebox_override("hover", style_btn_upgrade)
			action_button.add_theme_stylebox_override("pressed", style_btn_upgrade)
			action_button.disabled = not can_upgrade
			action_button.modulate = Color(1, 1, 1, 1) if can_upgrade else Color(0.7, 0.7, 0.7, 0.8)
		else:
			# Max tier reached
			action_button.visible = false
			current_action_state = ActionState.EQUIPPED

func _on_equip_pressed() -> void:
	if not GameState.VESSEL_CATALOG.has(selected_vessel_id):
		return
	if not GameState.is_vessel_owned(selected_vessel_id):
		return
	if GameState.active_vessel == selected_vessel_id:
		return
	if GameState.equip_vessel(selected_vessel_id):
		AudioManager.play_sfx("coin_pickups", 1.0, 1.2)
		AudioManager.play_sfx("gate_passes")
		_refresh_card_selections()
		_update_inspection_drawer()

func _on_action_pressed() -> void:
	if not GameState.VESSEL_CATALOG.has(selected_vessel_id):
		return

	match current_action_state:
		ActionState.BUY:
			if GameState.buy_vessel(selected_vessel_id):
				AudioManager.play_sfx("coin_pickups", 1.0, 1.2)
				AudioManager.play_sfx("barrel_hits")
				_refresh_card_selections()
				_update_inspection_drawer()
		ActionState.UPGRADE:
			if GameState.upgrade_vessel_tier(selected_vessel_id):
				AudioManager.play_sfx("coin_pickups", 1.1, 1.3)
				AudioManager.play_sfx("gate_passes")
				_refresh_card_selections()
				_update_inspection_drawer()
		ActionState.EQUIP:
			if GameState.equip_vessel(selected_vessel_id):
				AudioManager.play_sfx("coin_pickups", 1.0, 1.2)
				AudioManager.play_sfx("gate_passes")
				_refresh_card_selections()
				_update_inspection_drawer()
		_:
			pass

func _on_doubloons_changed(_amount: int) -> void:
	_update_purse_display()
	_refresh_card_selections()
	_update_inspection_drawer()

func _on_active_vessel_changed(_v_id: String) -> void:
	_refresh_card_selections()
	_update_inspection_drawer()

func _on_locked_tab_clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		AudioManager.play_sfx("gate_passes", 0.7, 0.8)

func _on_back_pressed() -> void:
	AudioManager.play_sfx("gate_passes")
	shipyard_closed.emit()
	queue_free()

func _format_number(val: int) -> String:
	var s = str(abs(val))
	var res = ""
	var count = 0
	for i in range(s.length() - 1, -1, -1):
		res = s[i] + res
		count += 1
		if count % 3 == 0 and i > 0:
			res = "," + res
	if val < 0:
		res = "-" + res
	return res
