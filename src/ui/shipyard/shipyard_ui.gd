class_name ShipyardUI
extends CanvasLayer

## Accessible Visual Comparison Dashboard — Shipyard UI
## Features 2-column vessel cards, dark comparison inspector with 4 UIStatBar slots,
## tactical perk chips, and a VS comparison column.
## Signal hookups for Buy, Equip, and Tab switching are preserved unchanged.

signal shipyard_closed

@onready var root_margin: MarginContainer = $RootMargin
@onready var back_button: Button = %BackButton
@onready var shipyard_title: Label = %ShipyardTitle
@onready var purse_label: Label = %PurseLabel
@onready var grid_container: GridContainer = %GridContainer

# Comparison Inspector Nodes
@onready var drawer_panel: PanelContainer = %DrawerPanel
@onready var inspector_title_label: Label = %InspectorTitleLabel
@onready var stat_bar_hull_armor: UIStatBar = %StatBarHullArmor
@onready var stat_bar_top_speed: UIStatBar = %StatBarTopSpeed
@onready var stat_bar_firepower: UIStatBar = %StatBarFirepower
@onready var stat_bar_steering: UIStatBar = %StatBarSteering
@onready var perk_flow_container: FlowContainer = %PerkFlowContainer
@onready var compare_vessel_label: Label = %CompareVesselLabel
@onready var compare_tier_label: Label = %CompareTierLabel
@onready var compare_desc_label: Label = %CompareDescLabel

@onready var action_button: Button = %ActionButton
@onready var equip_button: Button = %EquipButton

# Category Tabs
@onready var tab_vessels: Button = %TabVessels
@onready var tab_crew: Button = %TabCrew
@onready var tab_outfitting: Button = %TabOutfitting

const CARD_SCENE: PackedScene = preload("res://src/ui/shipyard/vessel_card.tscn")
const VesselCardScript = preload("res://src/ui/shipyard/vessel_card.gd")
const CREW_CARD_SCENE: PackedScene = preload("res://src/ui/shipyard/crew_card.tscn")
const CrewCardScript = preload("res://src/ui/shipyard/crew_card.gd")
const OUTFITTING_CARD_SCENE: PackedScene = preload("res://src/ui/shipyard/outfitting_card.tscn")
const OutfittingCardScript = preload("res://src/ui/shipyard/outfitting_card.gd")

# Perk chip style reused for all dynamically created chips
var _style_perk_chip: StyleBoxFlat

enum TabType { VESSELS, CREW, OUTFITTING }
var current_tab: TabType = TabType.VESSELS

var vessel_ids: Array[String] = ["dinghy", "sloop", "bombard_skiff", "ironclad"]
var card_instances: Dictionary = {} # vessel_id -> VesselCard
var selected_vessel_id: String = "dinghy"

var crew_ids: Array[String] = ["monkey_bomber", "skeleton_tosser"]
var crew_card_instances: Dictionary = {} # crew_id -> CrewCard
var outfitting_card_instances: Dictionary = {} # item_id -> OutfittingCard

# Action button state enum
enum ActionState { BUY, UPGRADE, EQUIP, EQUIPPED, DISABLED }
var current_action_state: ActionState = ActionState.EQUIPPED

# Action button styleboxes
var style_btn_buy: StyleBoxFlat
var style_btn_upgrade: StyleBoxFlat
var style_btn_equip: StyleBoxFlat
var style_btn_disabled: StyleBoxFlat
var style_btn_upgrade_disabled: StyleBoxFlat
var style_tab_active: StyleBoxFlat
var style_tab_inactive: StyleBoxFlat

func _ready() -> void:
	GameState.set_performance_mode(false)
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 35

	_init_button_styles()
	_init_perk_chip_style()
	_apply_safe_area()
	get_tree().root.size_changed.connect(_apply_safe_area)

	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	if action_button:
		action_button.pressed.connect(_on_action_pressed)
	if equip_button:
		equip_button.pressed.connect(_on_equip_pressed)

	if tab_vessels:
		tab_vessels.pressed.connect(_on_tab_vessels_pressed)
	if tab_crew:
		tab_crew.pressed.connect(_on_tab_crew_pressed)
	if tab_outfitting:
		tab_outfitting.pressed.connect(_on_tab_outfitting_pressed)

	GameState.doubloons_changed.connect(_on_doubloons_changed)
	GameState.active_vessel_changed.connect(_on_active_vessel_changed)
	GameState.crew_unlocked.connect(func(_id: String, _lvl: int): _refresh_crew_cards())
	GameState.crew_equipped.connect(func(_ship: String, _sock: String, _id: String): _refresh_crew_cards())
	GameState.outfitting_unlocked.connect(func(_id: String): _refresh_outfitting_cards())
	GameState.outfitting_equipped.connect(func(_ship: String, _cat: String, _id: String): _refresh_outfitting_cards())

	# Default selected vessel to active vessel
	if GameState.active_vessel in vessel_ids:
		selected_vessel_id = GameState.active_vessel
	else:
		selected_vessel_id = "dinghy"

	_update_tab_headers()
	_build_grid_cards()
	_update_purse_display()
	_update_inspection_drawer()

func _init_perk_chip_style() -> void:
	_style_perk_chip = StyleBoxFlat.new()
	_style_perk_chip.bg_color = Color(0.11, 0.22, 0.35, 1.0)
	_style_perk_chip.border_width_left = 1
	_style_perk_chip.border_width_top = 1
	_style_perk_chip.border_width_right = 1
	_style_perk_chip.border_width_bottom = 1
	_style_perk_chip.border_color = Color(0.22, 0.74, 0.97, 0.55)
	_style_perk_chip.corner_radius_top_left = 8
	_style_perk_chip.corner_radius_top_right = 8
	_style_perk_chip.corner_radius_bottom_right = 8
	_style_perk_chip.corner_radius_bottom_left = 8

func _init_button_styles() -> void:
	# Buy button style (#FBBF24 gold with dark text for maximum legibility)
	style_btn_buy = StyleBoxFlat.new()
	style_btn_buy.bg_color = Color(0.984, 0.750, 0.141, 1.0)
	style_btn_buy.border_width_left = 3
	style_btn_buy.border_width_top = 3
	style_btn_buy.border_width_right = 3
	style_btn_buy.border_width_bottom = 3
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
	style_btn_disabled.bg_color = Color(0.14, 0.22, 0.34, 0.9)
	style_btn_disabled.border_width_left = 2
	style_btn_disabled.border_width_top = 2
	style_btn_disabled.border_width_right = 2
	style_btn_disabled.border_width_bottom = 2
	style_btn_disabled.border_color = Color(0.22, 0.35, 0.50, 1.0)
	style_btn_disabled.corner_radius_top_left = 16
	style_btn_disabled.corner_radius_top_right = 16
	style_btn_disabled.corner_radius_bottom_right = 16
	style_btn_disabled.corner_radius_bottom_left = 16

	# Disabled Upgrade style
	style_btn_upgrade_disabled = StyleBoxFlat.new()
	style_btn_upgrade_disabled.bg_color = Color(0.42, 0.18, 0.20, 0.85)
	style_btn_upgrade_disabled.border_width_left = 3
	style_btn_upgrade_disabled.border_width_top = 3
	style_btn_upgrade_disabled.border_width_right = 3
	style_btn_upgrade_disabled.border_width_bottom = 3
	style_btn_upgrade_disabled.border_color = Color(0.55, 0.40, 0.25, 0.9)
	style_btn_upgrade_disabled.corner_radius_top_left = 16
	style_btn_upgrade_disabled.corner_radius_top_right = 16
	style_btn_upgrade_disabled.corner_radius_bottom_right = 16
	style_btn_upgrade_disabled.corner_radius_bottom_left = 16

	# Tab styles
	style_tab_active = StyleBoxFlat.new()
	style_tab_active.bg_color = Color(0.85, 0.45, 0.12, 1.0)
	style_tab_active.border_width_left = 3
	style_tab_active.border_width_top = 3
	style_tab_active.border_width_right = 3
	style_tab_active.border_width_bottom = 3
	style_tab_active.border_color = Color(1.0, 0.82, 0.45, 1.0)
	style_tab_active.corner_radius_top_left = 12
	style_tab_active.corner_radius_top_right = 12
	style_tab_active.corner_radius_bottom_right = 12
	style_tab_active.corner_radius_bottom_left = 12

	style_tab_inactive = StyleBoxFlat.new()
	style_tab_inactive.bg_color = Color(0.082, 0.149, 0.22, 0.9)
	style_tab_inactive.border_width_left = 2
	style_tab_inactive.border_width_top = 2
	style_tab_inactive.border_width_right = 2
	style_tab_inactive.border_width_bottom = 2
	style_tab_inactive.border_color = Color(0.18, 0.31, 0.47, 1.0)
	style_tab_inactive.corner_radius_top_left = 12
	style_tab_inactive.corner_radius_top_right = 12
	style_tab_inactive.corner_radius_bottom_right = 12
	style_tab_inactive.corner_radius_bottom_left = 12

func _apply_safe_area() -> void:
	if not is_instance_valid(root_margin):
		return

	var margin_left: int = 16
	var margin_right: int = 16
	var margin_top: int = 16
	var margin_bottom: int = 14

	if OS.has_feature("mobile"):
		var safe_area: Rect2i = DisplayServer.get_display_safe_area()
		var window_size: Vector2i = DisplayServer.window_get_size()
		if window_size.x > 0 and window_size.y > 0 and safe_area.size.x > 0:
			var vp_rect: Rect2 = get_viewport().get_visible_rect()
			var scale_x: float = vp_rect.size.x / float(window_size.x)
			var scale_y: float = vp_rect.size.y / float(window_size.y)
			var in_l: int = int(safe_area.position.x * scale_x)
			var in_r: int = int((window_size.x - safe_area.end.x) * scale_x)
			var in_t: int = int(safe_area.position.y * scale_y)
			var in_b: int = int((window_size.y - safe_area.end.y) * scale_y)
			margin_left = maxi(margin_left, in_l + 8)
			margin_right = maxi(margin_right, in_r + 8)
			margin_top = maxi(margin_top, in_t + 8)
			margin_bottom = maxi(margin_bottom, in_b + 6)

	root_margin.add_theme_constant_override("margin_left", margin_left)
	root_margin.add_theme_constant_override("margin_right", margin_right)
	root_margin.add_theme_constant_override("margin_top", margin_top)
	root_margin.add_theme_constant_override("margin_bottom", margin_bottom)

func _build_grid_cards() -> void:
	if not grid_container:
		return

	# Clear existing children
	for child: Node in grid_container.get_children():
		child.queue_free()
	card_instances.clear()

	var index_counter: int = 1
	for v_id: String in vessel_ids:
		var card: VesselCard = CARD_SCENE.instantiate() as VesselCard
		grid_container.add_child(card)
		card.setup_vessel(v_id, index_counter)
		card.card_clicked.connect(_on_card_clicked)
		card_instances[v_id] = card
		index_counter += 1

	_refresh_card_selections()

func _refresh_card_selections() -> void:
	for v_id: String in card_instances:
		var card: VesselCard = card_instances[v_id] as VesselCard
		if is_instance_valid(card):
			card.set_selected(v_id == selected_vessel_id)
			card.update_status()

func _on_card_clicked(v_id: String) -> void:
	if selected_vessel_id != v_id:
		selected_vessel_id = v_id
		AudioManager.play_sfx("gate_passes", 1.0, 1.1)
		_refresh_card_selections()
		_update_inspection_drawer()

func _update_purse_display() -> void:
	if purse_label:
		purse_label.text = "🪙 %s COINS" % _format_number(GameState.doubloons)

## ─── Comparison Inspector ────────────────────────────────────────────────────

func _update_inspection_drawer() -> void:
	if not GameState.VESSEL_CATALOG.has(selected_vessel_id):
		return

	var v_info: Dictionary = GameState.VESSEL_CATALOG[selected_vessel_id]
	var ship_data: ShipData = GameState.get_vessel_resource(selected_vessel_id)
	var is_owned: bool = GameState.is_vessel_owned(selected_vessel_id)
	var cur_tier: int = GameState.get_vessel_tier(selected_vessel_id) if is_owned else 1
	var is_active: bool = (GameState.active_vessel == selected_vessel_id)

	# 1. Inspector title
	if inspector_title_label:
		var name_str: String = v_info.get("name", "Vessel").to_upper()
		var arch_str: String = v_info.get("archetype", "Standard").to_upper()
		var tier_str: String = "TIER %d" % cur_tier if is_owned else "LOCKED"
		inspector_title_label.text = "%s — %s (%s)" % [name_str, arch_str, tier_str]

	# 2. Collect selected-vessel raw stats
	var hp_val: float = float(ship_data.max_health) if ship_data else float(v_info.get("base_hp", 2))
	var speed_val: float = ship_data.move_speed if ship_data else float(v_info.get("base_speed", 8.0))
	var cannons_val: float = float(ship_data.base_cannons) if ship_data else 1.0
	# Steering: light fast ships score higher; max_speed vessel = lowest agility
	var agility_val: float = clampf((14.0 - speed_val) / 14.0 * 70.0 + 30.0, 20.0, 100.0)

	# 3. Collect baseline (active/equipped) vessel stats for delta display
	var baseline_hp: float = -1.0
	var baseline_speed: float = -1.0
	var baseline_cannons: float = -1.0
	var baseline_agility: float = -1.0

	if not is_active and GameState.VESSEL_CATALOG.has(GameState.active_vessel):
		var base_data: ShipData = GameState.get_vessel_resource(GameState.active_vessel)
		if base_data:
			baseline_hp = float(base_data.max_health)
			baseline_speed = base_data.move_speed
			baseline_cannons = float(base_data.base_cannons)
			baseline_agility = clampf((14.0 - baseline_speed) / 14.0 * 70.0 + 30.0, 20.0, 100.0)

	# 4. Set stat bars
	if stat_bar_hull_armor:
		stat_bar_hull_armor.set_bar_color(Color("#EF4444"))
		stat_bar_hull_armor.set_stat("Hull Armor", hp_val, 8.0, baseline_hp, " HP")
	if stat_bar_top_speed:
		stat_bar_top_speed.set_bar_color(Color("#38BDF8"))
		stat_bar_top_speed.set_stat("Top Speed", speed_val, 14.0, baseline_speed, " m/s")
	if stat_bar_firepower:
		stat_bar_firepower.set_bar_color(Color("#F97316"))
		stat_bar_firepower.set_stat("Firepower", cannons_val, 4.0, baseline_cannons, "x")
	if stat_bar_steering:
		stat_bar_steering.set_bar_color(Color("#A78BFA"))
		# Agility is on a 0-100 scale already, so max_val = 100
		stat_bar_steering.set_stat("Agility", agility_val, 100.0, baseline_agility, "")

	# 5. Perk chips from tier_descriptions
	_rebuild_perk_chips(ship_data, cur_tier)

	# 6. VS comparison column
	_update_compare_column()

	# 7. Action buttons (unchanged logic, preserved signal hookups)
	_update_action_buttons(v_info, is_owned, cur_tier, is_active)

func _rebuild_perk_chips(ship_data: ShipData, cur_tier: int) -> void:
	if not perk_flow_container:
		return
	for child: Node in perk_flow_container.get_children():
		child.queue_free()

	if not ship_data or ship_data.tier_descriptions.is_empty():
		return

	var desc_idx: int = clampi(cur_tier - 1, 0, ship_data.tier_descriptions.size() - 1)
	var full_desc: String = ship_data.tier_descriptions[desc_idx]

	# Split on comma or semicolon, take up to 3 clauses
	var clauses: Array = full_desc.split(",", false)
	if clauses.size() <= 1:
		clauses = full_desc.split(";", false)
	var max_chips: int = mini(clauses.size(), 3)
	for i: int in range(max_chips):
		var clause: String = (clauses[i] as String).strip_edges()
		if clause.is_empty():
			continue
		_add_perk_chip(clause)

func _add_perk_chip(text: String) -> void:
	var chip_panel: PanelContainer = PanelContainer.new()
	chip_panel.add_theme_stylebox_override("panel", _style_perk_chip)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)

	var lbl: Label = Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", Color("#E2E8F0"))
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	margin.add_child(lbl)
	chip_panel.add_child(margin)
	perk_flow_container.add_child(chip_panel)

func _update_compare_column() -> void:
	var active_id: String = GameState.active_vessel
	if not GameState.VESSEL_CATALOG.has(active_id):
		return

	var active_info: Dictionary = GameState.VESSEL_CATALOG[active_id]
	var active_tier: int = GameState.get_vessel_tier(active_id)

	if compare_vessel_label:
		compare_vessel_label.text = active_info.get("name", "Vessel").to_upper()
	if compare_tier_label:
		compare_tier_label.text = "TIER %d / 3" % active_tier

	# Show active tier description as compare context
	if compare_desc_label:
		var active_data: ShipData = GameState.get_vessel_resource(active_id)
		if active_data and not active_data.tier_descriptions.is_empty():
			var idx: int = clampi(active_tier - 1, 0, active_data.tier_descriptions.size() - 1)
			var desc: String = active_data.tier_descriptions[idx]
			# Truncate to first clause for the compact column
			var comma_pos: int = desc.find(",")
			compare_desc_label.text = desc.substr(0, comma_pos if comma_pos > 0 else desc.length())
		else:
			compare_desc_label.text = ""

func _update_action_buttons(v_info: Dictionary, is_owned: bool, cur_tier: int, is_active: bool) -> void:
	if not action_button:
		return

	if not is_owned:
		if equip_button:
			equip_button.visible = false
		action_button.visible = true
		current_action_state = ActionState.BUY
		var price: int = v_info.get("purchase_price", 0)
		var can_buy: bool = GameState.can_afford(price)
		action_button.text = "BUY VESSEL: %s 🪙" % _format_number(price)
		action_button.add_theme_stylebox_override("normal", style_btn_buy)
		action_button.add_theme_stylebox_override("hover", style_btn_buy)
		action_button.add_theme_stylebox_override("pressed", style_btn_buy)
		action_button.add_theme_color_override("font_color", Color("#0B131F"))
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
			var next_tier: int = cur_tier + 1
			var cost: int = GameState.get_upgrade_cost(selected_vessel_id, next_tier)
			var can_upgrade: bool = GameState.can_afford(cost)
			action_button.text = "UPGRADE TO TIER %d: %s 🪙" % [next_tier, _format_number(cost)]
			action_button.add_theme_stylebox_override("normal", style_btn_upgrade)
			action_button.add_theme_stylebox_override("hover", style_btn_upgrade)
			action_button.add_theme_stylebox_override("pressed", style_btn_upgrade)
			action_button.add_theme_stylebox_override("disabled", style_btn_upgrade_disabled)
			action_button.add_theme_color_override("font_color", Color(1, 1, 1, 1))
			action_button.add_theme_color_override("font_disabled_color", Color(0.95, 0.85, 0.70, 0.9))
			action_button.disabled = not can_upgrade
			action_button.modulate = Color(1, 1, 1, 1) if can_upgrade else Color(0.85, 0.85, 0.85, 0.9)
		else:
			# Max tier reached
			action_button.visible = true
			current_action_state = ActionState.EQUIPPED
			action_button.disabled = true
			action_button.text = "⚓ MAX TIER"
			action_button.add_theme_stylebox_override("normal", style_btn_disabled)
			action_button.add_theme_stylebox_override("disabled", style_btn_disabled)
			action_button.add_theme_color_override("font_disabled_color", Color(0.96, 0.82, 0.38, 1.0))
			action_button.modulate = Color(1.0, 1.0, 1.0, 0.95)

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
	if current_tab == TabType.VESSELS:
		_refresh_card_selections()
		_update_inspection_drawer()
	elif current_tab == TabType.CREW:
		_refresh_crew_cards()
	elif current_tab == TabType.OUTFITTING:
		_refresh_outfitting_cards()

func _on_active_vessel_changed(_v_id: String) -> void:
	if current_tab == TabType.VESSELS:
		_refresh_card_selections()
		_update_inspection_drawer()
	elif current_tab == TabType.CREW:
		_refresh_crew_cards()
	elif current_tab == TabType.OUTFITTING:
		_refresh_outfitting_cards()

func _on_tab_vessels_pressed() -> void:
	if current_tab == TabType.VESSELS:
		return
	current_tab = TabType.VESSELS
	AudioManager.play_sfx("gate_passes", 1.0, 1.2)
	_update_tab_headers()
	_build_grid_cards()
	if drawer_panel:
		drawer_panel.visible = true
	_update_inspection_drawer()

func _on_tab_crew_pressed() -> void:
	if current_tab == TabType.CREW:
		return
	current_tab = TabType.CREW
	AudioManager.play_sfx("gate_passes", 1.0, 1.2)
	_update_tab_headers()
	if drawer_panel:
		drawer_panel.visible = false
	_build_crew_cards()

func _on_tab_outfitting_pressed() -> void:
	if current_tab == TabType.OUTFITTING:
		return
	current_tab = TabType.OUTFITTING
	AudioManager.play_sfx("gate_passes", 1.0, 1.2)
	_update_tab_headers()
	if drawer_panel:
		drawer_panel.visible = false
	_build_outfitting_cards()

func _update_tab_headers() -> void:
	if tab_vessels:
		if current_tab == TabType.VESSELS:
			tab_vessels.add_theme_stylebox_override("normal", style_tab_active)
			tab_vessels.modulate = Color.WHITE
		else:
			tab_vessels.add_theme_stylebox_override("normal", style_tab_inactive)
			tab_vessels.modulate = Color(0.7, 0.7, 0.7, 0.8)

	if tab_crew:
		if current_tab == TabType.CREW:
			tab_crew.add_theme_stylebox_override("normal", style_tab_active)
			tab_crew.modulate = Color.WHITE
		else:
			tab_crew.add_theme_stylebox_override("normal", style_tab_inactive)
			tab_crew.modulate = Color(0.7, 0.7, 0.7, 0.8)

	if tab_outfitting:
		if current_tab == TabType.OUTFITTING:
			tab_outfitting.add_theme_stylebox_override("normal", style_tab_active)
			tab_outfitting.modulate = Color.WHITE
		else:
			tab_outfitting.add_theme_stylebox_override("normal", style_tab_inactive)
			tab_outfitting.modulate = Color(0.7, 0.7, 0.7, 0.8)

func _build_crew_cards() -> void:
	if not grid_container:
		return
	for child: Node in grid_container.get_children():
		child.queue_free()
	card_instances.clear()
	crew_card_instances.clear()
	outfitting_card_instances.clear()

	for c_id: String in crew_ids:
		var card: CrewCard = CREW_CARD_SCENE.instantiate() as CrewCard
		grid_container.add_child(card)
		card.setup_crew(c_id)
		card.buy_requested.connect(_on_crew_buy_requested)
		card.upgrade_requested.connect(_on_crew_upgrade_requested)
		card.equip_requested.connect(_on_crew_equip_requested)
		crew_card_instances[c_id] = card

func _refresh_crew_cards() -> void:
	for c_id: String in crew_card_instances:
		var card: Node = crew_card_instances[c_id]
		if is_instance_valid(card) and card.has_method("update_card"):
			card.update_card()

func _on_crew_buy_requested(c_id: String) -> void:
	if GameState.buy_crew(c_id):
		AudioManager.play_sfx("coin_pickups", 1.0, 1.2)
		AudioManager.play_sfx("barrel_hits")
		_update_purse_display()
		_refresh_crew_cards()

func _on_crew_upgrade_requested(c_id: String) -> void:
	if GameState.upgrade_crew_level(c_id):
		AudioManager.play_sfx("coin_pickups", 1.1, 1.3)
		AudioManager.play_sfx("gate_passes")
		_update_purse_display()
		_refresh_crew_cards()

func _on_crew_equip_requested(c_id: String) -> void:
	if GameState.toggle_equip_crew_active_ship(c_id):
		AudioManager.play_sfx("coin_pickups", 1.0, 1.2)
		AudioManager.play_sfx("gate_passes")
		_refresh_crew_cards()

func _build_outfitting_cards() -> void:
	if not grid_container:
		return
	for child: Node in grid_container.get_children():
		child.queue_free()
	card_instances.clear()
	crew_card_instances.clear()
	outfitting_card_instances.clear()

	var categories: Array[String] = ["ammo", "plating"]
	var category_titles: Dictionary = {
		"ammo": "⚓ TACTICAL AMMUNITION",
		"plating": "🛡️ HULL PLATING",
	}
	var items_by_category: Dictionary = {}
	for cat: String in categories:
		items_by_category[cat] = []

	for item_id: String in GameState.OUTFITTING_CATALOG:
		var info: Dictionary = GameState.OUTFITTING_CATALOG[item_id] as Dictionary
		var cat: String = info.get("category", "ammo")
		if not items_by_category.has(cat):
			items_by_category[cat] = []
			categories.append(cat)
			category_titles[cat] = cat.to_upper()
		(items_by_category[cat] as Array).append(item_id)

	for cat: String in categories:
		var cat_items: Array = items_by_category[cat] as Array
		if not cat_items.is_empty():
			var title: String = category_titles.get(cat, cat.to_upper()) as String
			_add_outfitting_section_header(title)
			for item_id: String in cat_items:
				_create_outfitting_card(item_id)

func _add_outfitting_section_header(title: String) -> void:
	var left_panel: PanelContainer = PanelContainer.new()
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var left_style: StyleBoxFlat = StyleBoxFlat.new()
	left_style.bg_color = Color(0.06, 0.11, 0.18, 0.9)
	left_style.border_width_bottom = 2
	left_style.border_color = Color(0.984, 0.750, 0.141, 0.8)
	left_style.content_margin_left = 12
	left_style.content_margin_top = 8
	left_style.content_margin_bottom = 8
	left_style.content_margin_right = 8
	left_panel.add_theme_stylebox_override("panel", left_style)

	var label: Label = Label.new()
	label.text = title
	label.add_theme_font_override("font", preload("res://assets/fonts/CinzelDecorative-Bold.ttf"))
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.984, 0.816, 0.141, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.043, 0.075, 0.122, 1.0))
	label.add_theme_constant_override("outline_size", 4)
	left_panel.add_child(label)
	grid_container.add_child(left_panel)

	var right_panel: PanelContainer = PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var right_style: StyleBoxFlat = StyleBoxFlat.new()
	right_style.bg_color = Color(0.06, 0.11, 0.18, 0.9)
	right_style.border_width_bottom = 2
	right_style.border_color = Color(0.984, 0.750, 0.141, 0.8)
	right_style.content_margin_top = 8
	right_style.content_margin_bottom = 8
	right_panel.add_theme_stylebox_override("panel", right_style)
	grid_container.add_child(right_panel)

func _create_outfitting_card(item_id: String) -> void:
	var card: OutfittingCard = OUTFITTING_CARD_SCENE.instantiate() as OutfittingCard
	grid_container.add_child(card)
	card.setup_item(item_id)
	card.buy_requested.connect(_on_outfitting_buy_requested)
	card.equip_requested.connect(_on_outfitting_equip_requested)
	outfitting_card_instances[item_id] = card

func _refresh_outfitting_cards() -> void:
	for item_id: String in outfitting_card_instances:
		var card: Node = outfitting_card_instances[item_id]
		if is_instance_valid(card) and card.has_method("update_card"):
			card.update_card()

func _on_outfitting_buy_requested(item_id: String) -> void:
	if GameState.buy_outfitting(item_id):
		AudioManager.play_sfx("coin_pickups", 1.0, 1.2)
		AudioManager.play_sfx("barrel_hits")
		_update_purse_display()
		_refresh_outfitting_cards()

func _on_outfitting_equip_requested(item_id: String) -> void:
	if GameState.toggle_equip_outfitting_active_ship(item_id):
		AudioManager.play_sfx("coin_pickups", 1.0, 1.2)
		AudioManager.play_sfx("gate_passes")
		_refresh_outfitting_cards()

func _on_back_pressed() -> void:
	AudioManager.play_sfx("gate_passes")
	shipyard_closed.emit()
	queue_free()

func _format_number(val: int) -> String:
	var s: String = str(abs(val))
	var res: String = ""
	var count: int = 0
	for i: int in range(s.length() - 1, -1, -1):
		res = s[i] + res
		count += 1
		if count % 3 == 0 and i > 0:
			res = "," + res
	if val < 0:
		res = "-" + res
	return res
