class_name ShipyardUI
extends CanvasLayer

## Modern 2-Column Grid Shipyard Interface for Cove Corsair
## Features 2-column vessel cards, bottom inspection drawer, tabs bar,
## and complete tier progression (Mob Control style) bound to GameState and ship_data.gd.

signal shipyard_closed

@onready var back_button: Button = %BackButton
@onready var shipyard_title: Label = %ShipyardTitle
@onready var purse_label: Label = %PurseLabel
@onready var grid_container: GridContainer = %GridContainer

# Inspection Drawer Nodes
@onready var drawer_panel: PanelContainer = %DrawerPanel
@onready var drawer_title_label: Label = %DrawerTitleLabel
@onready var current_tier_desc_label: Label = %CurrentTierDescLabel
@onready var stat_hp_label: Label = %StatHpLabel
@onready var stat_hp_bar: ProgressBar = %StatHpBar
@onready var stat_speed_label: Label = %StatSpeedLabel
@onready var stat_speed_bar: ProgressBar = %StatSpeedBar
@onready var stat_sockets_label: Label = %StatSocketsLabel
@onready var stat_sockets_bar: ProgressBar = %StatSocketsBar
@onready var next_upgrade_label: Label = %NextUpgradeLabel
@onready var action_button: Button = %ActionButton
@onready var equip_button: Button = %EquipButton

# Category Tabs
@onready var tab_vessels: Button = %TabVessels
@onready var tab_crew: PanelContainer = %TabCrew
@onready var tab_weapons: PanelContainer = %TabWeapons

const CARD_SCENE: PackedScene = preload("res://src/ui/shipyard/vessel_card.tscn")
const VesselCardScript = preload("res://src/ui/shipyard/vessel_card.gd")

var vessel_ids: Array[String] = ["dinghy", "sloop", "ironclad", "bombard_skiff"]
var card_instances: Dictionary = {} # vessel_id -> VesselCard
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
	layer = 35

	_init_button_styles()

	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	if action_button:
		action_button.pressed.connect(_on_action_pressed)
	if equip_button:
		equip_button.pressed.connect(_on_equip_pressed)

	if tab_crew:
		tab_crew.gui_input.connect(_on_locked_tab_clicked)
	if tab_weapons:
		tab_weapons.gui_input.connect(_on_locked_tab_clicked)

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
	style_btn_buy.shadow_color = Color(0, 0, 0, 0.5)
	style_btn_buy.shadow_size = 6
	style_btn_buy.shadow_offset = Vector2(0, 4)

	# Upgrade button style (Crimson Red with Gold Trim)
	style_btn_upgrade = StyleBoxFlat.new()
	style_btn_upgrade.bg_color = Color(0.72, 0.13, 0.18, 1.0)
	style_btn_upgrade.border_width_left = 4
	style_btn_upgrade.border_width_top = 4
	style_btn_upgrade.border_width_right = 4
	style_btn_upgrade.border_width_bottom = 4
	style_btn_upgrade.border_color = Color(0.95, 0.78, 0.28, 1.0)
	style_btn_upgrade.corner_radius_top_left = 16
	style_btn_upgrade.corner_radius_top_right = 16
	style_btn_upgrade.corner_radius_bottom_right = 16
	style_btn_upgrade.corner_radius_bottom_left = 16
	style_btn_upgrade.shadow_color = Color(0, 0, 0, 0.5)
	style_btn_upgrade.shadow_size = 6
	style_btn_upgrade.shadow_offset = Vector2(0, 4)

	# Equip button style (Vibrant Emerald Green)
	style_btn_equip = StyleBoxFlat.new()
	style_btn_equip.bg_color = Color(0.20, 0.68, 0.16, 1.0)
	style_btn_equip.border_width_left = 4
	style_btn_equip.border_width_top = 4
	style_btn_equip.border_width_right = 4
	style_btn_equip.border_width_bottom = 4
	style_btn_equip.border_color = Color(0.12, 0.44, 0.08, 1.0)
	style_btn_equip.corner_radius_top_left = 16
	style_btn_equip.corner_radius_top_right = 16
	style_btn_equip.corner_radius_bottom_right = 16
	style_btn_equip.corner_radius_bottom_left = 16
	style_btn_equip.shadow_color = Color(0, 0, 0, 0.5)
	style_btn_equip.shadow_size = 6
	style_btn_equip.shadow_offset = Vector2(0, 4)

	# Disabled / Equipped button style
	style_btn_disabled = StyleBoxFlat.new()
	style_btn_disabled.bg_color = Color(0.32, 0.32, 0.32, 0.9)
	style_btn_disabled.border_width_left = 3
	style_btn_disabled.border_width_top = 3
	style_btn_disabled.border_width_right = 3
	style_btn_disabled.border_width_bottom = 3
	style_btn_disabled.border_color = Color(0.22, 0.22, 0.22, 1.0)
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

	# Configured vessels: dinghy, sloop, ironclad
	var index_counter = 1
	for v_id in vessel_ids:
		var card = CARD_SCENE.instantiate() as VesselCardScript
		grid_container.add_child(card)
		card.setup_vessel(v_id, index_counter)
		card.card_clicked.connect(_on_card_clicked)
		card_instances[v_id] = card
		index_counter += 1

	_refresh_card_selections()

func _refresh_card_selections() -> void:
	for v_id in card_instances:
		var card = card_instances[v_id] as VesselCardScript
		if is_instance_valid(card):
			card.set_selected(v_id == selected_vessel_id)
			card.update_status()

func _on_card_clicked(v_id: String) -> void:
	# Clicking a card selects it for the Inspection Drawer without automatically equipping it
	if selected_vessel_id != v_id:
		selected_vessel_id = v_id
		AudioManager.play_sfx("gate_passes", 1.0, 1.1)
		_refresh_card_selections()
		_update_inspection_drawer()

func _update_purse_display() -> void:
	if purse_label:
		purse_label.text = "🪙 %s COINS" % _format_number(GameState.doubloons)

func _update_inspection_drawer() -> void:
	if not GameState.VESSEL_CATALOG.has(selected_vessel_id):
		return

	var v_info = GameState.VESSEL_CATALOG[selected_vessel_id]
	var ship_data: ShipData = GameState.get_vessel_resource(selected_vessel_id)
	var is_owned = GameState.is_vessel_owned(selected_vessel_id)
	var cur_tier = GameState.get_vessel_tier(selected_vessel_id) if is_owned else 1
	var is_active = (GameState.active_vessel == selected_vessel_id)

	# 1. Selected Vessel Name & Archetype string
	if drawer_title_label:
		var name_str = v_info.get("name", "Vessel").to_upper()
		var arch_str = v_info.get("archetype", "Standard").to_upper()
		if is_owned:
			drawer_title_label.text = "%s - %s (TIER %d)" % [name_str, arch_str, cur_tier]
		else:
			drawer_title_label.text = "%s - %s (LOCKED)" % [name_str, arch_str]

	# 2. Stat Line: Hull HP, Lateral Speed (m/s), and Active Sockets count
	var hp_val = ship_data.max_health if ship_data else v_info.get("base_hp", 1)
	var speed_val = ship_data.move_speed if ship_data else v_info.get("base_speed", 10.0)
	var socket_count = 1
	if ship_data and not ship_data.tier_sockets.is_empty():
		var s_idx = clampi(cur_tier - 1, 0, ship_data.tier_sockets.size() - 1)
		socket_count = ship_data.tier_sockets[s_idx].size()

	if stat_hp_label:
		stat_hp_label.text = "Hull: %d HP" % hp_val
	if stat_hp_bar:
		stat_hp_bar.value = clamp(float(hp_val) / 8.0 * 100.0, 15.0, 100.0)

	if stat_speed_label:
		stat_speed_label.text = "Speed: %.0f m/s" % speed_val
	if stat_speed_bar:
		stat_speed_bar.value = clamp(speed_val / 14.0 * 100.0, 20.0, 100.0)

	if stat_sockets_label:
		stat_sockets_label.text = "Sockets: %d" % socket_count
	if stat_sockets_bar:
		stat_sockets_bar.value = clamp(float(socket_count) / 5.0 * 100.0, 20.0, 100.0)

	# 3. Current Tier Description: ship_data.tier_descriptions[tier - 1]
	if current_tier_desc_label:
		if ship_data and not ship_data.tier_descriptions.is_empty():
			var desc_idx = clampi(cur_tier - 1, 0, ship_data.tier_descriptions.size() - 1)
			current_tier_desc_label.text = "Current: %s" % ship_data.tier_descriptions[desc_idx]
		else:
			current_tier_desc_label.text = "Standard Outfitting"

	# 4. Next Tier Preview: If below Tier 3, display Next: ship_data.tier_descriptions[tier]
	if next_upgrade_label:
		if not is_owned:
			next_upgrade_label.text = "Acquire vessel to commission for voyages and tier outfitting."
		elif cur_tier < 3:
			if ship_data and ship_data.tier_descriptions.size() > cur_tier:
				next_upgrade_label.text = "Next: %s" % ship_data.tier_descriptions[cur_tier]
			else:
				next_upgrade_label.text = "Next: Advanced Naval Sockets"
		else:
			next_upgrade_label.text = "Flagship Mastered (Tier 3 Maximum)"

	# 5. Main Action Button & Equip Button logic
	if not action_button:
		return

	if not is_owned:
		if equip_button:
			equip_button.visible = false
		action_button.visible = true
		current_action_state = ActionState.BUY
		var price = v_info.get("purchase_price", 0)
		var can_buy = GameState.can_afford(price)
		action_button.text = "BUY VESSEL: %s COINS" % _format_number(price)
		action_button.add_theme_stylebox_override("normal", style_btn_buy)
		action_button.add_theme_stylebox_override("hover", style_btn_buy)
		action_button.add_theme_stylebox_override("pressed", style_btn_buy)
		action_button.disabled = not can_buy
		action_button.modulate = Color(1, 1, 1, 1) if can_buy else Color(0.7, 0.7, 0.7, 0.75)
	else:
		# Vessel is owned
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
			action_button.visible = true
			current_action_state = ActionState.UPGRADE
			var next_tier = cur_tier + 1
			var cost = GameState.get_upgrade_cost(selected_vessel_id, next_tier)
			var can_upgrade = GameState.can_afford(cost)
			action_button.text = "UPGRADE TO TIER %d: %s COINS" % [next_tier, _format_number(cost)]
			action_button.add_theme_stylebox_override("normal", style_btn_upgrade)
			action_button.add_theme_stylebox_override("hover", style_btn_upgrade)
			action_button.add_theme_stylebox_override("pressed", style_btn_upgrade)
			action_button.disabled = not can_upgrade
			action_button.modulate = Color(1, 1, 1, 1) if can_upgrade else Color(0.7, 0.7, 0.7, 0.75)
		else:
			# Max tier reached: action button hidden or disabled
			action_button.visible = false
			current_action_state = ActionState.EQUIPPED

func _on_equip_pressed() -> void:
	if not GameState.VESSEL_CATALOG.has(selected_vessel_id):
		return
	if not GameState.is_vessel_owned(selected_vessel_id):
		return
	if GameState.active_vessel == selected_vessel_id:
		return
	if GameState.set_active_vessel(selected_vessel_id):
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
			if GameState.set_active_vessel(selected_vessel_id):
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
