class_name ShipyardUI
extends CanvasLayer

## Visual Dashboard — Shipyard UI
## Features 2x2 vessel cards layout, authentic shipyard dock background,
## icon navigation tabs, wooden plank inspector with 4 UIStatBar slots,
## stat icons, and a full-width golden action button.
## Fully statically typed.

signal shipyard_closed

const ICON_STAT_ARMOR: Texture2D = preload("res://assets/sprites/ui/shipyard/icon_stat_armor.svg")
const ICON_STAT_SPEED: Texture2D = preload("res://assets/sprites/ui/shipyard/icon_stat_speed.svg")
const ICON_STAT_FIREPOWER: Texture2D = preload("res://assets/sprites/ui/shipyard/icon_stat_firepower.svg")
const ICON_STAT_AGILITY: Texture2D = preload("res://assets/sprites/ui/shipyard/icon_stat_agility.svg")

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

@onready var action_button: Button = %ActionButton
@onready var equip_button: Button = %EquipButton

# Category Tabs
@onready var tab_vessels: Button = %TabVessels
@onready var tab_crew: Button = %TabCrew
@onready var tab_outfitting: Button = %TabOutfitting

@onready var label_vessels: Label = %LabelVessels
@onready var icon_vessels: TextureRect = %IconVessels
@onready var indicator_vessels: ColorRect = %IndicatorVessels

@onready var label_crew: Label = %LabelCrew
@onready var icon_crew: TextureRect = %IconCrew
@onready var indicator_crew: ColorRect = %IndicatorCrew

@onready var label_outfitting: Label = %LabelOutfitting
@onready var icon_outfitting: TextureRect = %IconOutfitting
@onready var indicator_outfitting: ColorRect = %IndicatorOutfitting

const CARD_SCENE: PackedScene = preload("res://src/ui/shipyard/vessel_card.tscn")
const CREW_CARD_SCENE: PackedScene = preload("res://src/ui/shipyard/crew_card.tscn")
const OUTFITTING_CARD_SCENE: PackedScene = preload("res://src/ui/shipyard/outfitting_card.tscn")

# Perk chip style reused for all dynamically created chips
var _style_perk_chip: StyleBoxFlat

enum TabType { VESSELS, CREW, OUTFITTING }
var current_tab: TabType = TabType.VESSELS

var vessel_ids: Array[String] = ["dinghy", "sloop", "bombard_skiff", "ironclad"]
var card_instances: Dictionary = {} # vessel_id -> VesselCard
var selected_vessel_id: String = "dinghy"

var crew_ids: Array[String] = ["monkey_bomber", "skeleton_tosser", "grease_monkey"]
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
	GameState.crew_unlocked.connect(func(_id: String, _lvl: int) -> void: _refresh_crew_cards())
	GameState.crew_equipped.connect(func(_ship: String, _sock: String, _id: String) -> void: _refresh_crew_cards())
	GameState.outfitting_unlocked.connect(func(_id: String) -> void: _refresh_outfitting_cards())
	GameState.outfitting_equipped.connect(func(_ship: String, _cat: String, _id: String) -> void: _refresh_outfitting_cards())

	# Default selected vessel to active vessel
	if GameState.active_vessel in vessel_ids:
		selected_vessel_id = GameState.active_vessel
	else:
		selected_vessel_id = "dinghy"

	_update_tab_headers()
	_build_grid_cards()
	_update_purse_display()
	_update_inspection_drawer()
	print("[TELEMETRY:SHIPYARD] ⚓ Shipyard Opened | Vault Balance: %d 🪙" % (GameState.doubloons if GameState else 0))


func _init_perk_chip_style() -> void:
	_style_perk_chip = StyleBoxFlat.new()
	_style_perk_chip.bg_color = Color(0.12, 0.08, 0.05, 0.9)
	_style_perk_chip.border_width_left = 1
	_style_perk_chip.border_width_top = 1
	_style_perk_chip.border_width_right = 1
	_style_perk_chip.border_width_bottom = 1
	_style_perk_chip.border_color = Color(0.85, 0.68, 0.28, 0.7)
	_style_perk_chip.corner_radius_top_left = 6
	_style_perk_chip.corner_radius_top_right = 6
	_style_perk_chip.corner_radius_bottom_right = 6
	_style_perk_chip.corner_radius_bottom_left = 6
	_style_perk_chip.content_margin_left = 8
	_style_perk_chip.content_margin_top = 3
	_style_perk_chip.content_margin_right = 8
	_style_perk_chip.content_margin_bottom = 3

func _init_button_styles() -> void:
	# Gold Buy Button (Metallic gold from mockup)
	style_btn_buy = StyleBoxFlat.new()
	style_btn_buy.bg_color = Color(0.92, 0.72, 0.24, 1.0)
	style_btn_buy.border_width_left = 3
	style_btn_buy.border_width_top = 3
	style_btn_buy.border_width_right = 3
	style_btn_buy.border_width_bottom = 3
	style_btn_buy.border_color = Color(1.0, 0.90, 0.62, 1.0)
	style_btn_buy.corner_radius_top_left = 14
	style_btn_buy.corner_radius_top_right = 14
	style_btn_buy.corner_radius_bottom_right = 14
	style_btn_buy.corner_radius_bottom_left = 14
	style_btn_buy.shadow_color = Color(0, 0, 0, 0.45)
	style_btn_buy.shadow_size = 6
	style_btn_buy.shadow_offset = Vector2(0, 3)

	# Warm Amber Upgrade Button
	style_btn_upgrade = StyleBoxFlat.new()
	style_btn_upgrade.bg_color = Color(0.88, 0.62, 0.18, 1.0)
	style_btn_upgrade.border_width_left = 3
	style_btn_upgrade.border_width_top = 3
	style_btn_upgrade.border_width_right = 3
	style_btn_upgrade.border_width_bottom = 3
	style_btn_upgrade.border_color = Color(1.0, 0.85, 0.50, 1.0)
	style_btn_upgrade.corner_radius_top_left = 14
	style_btn_upgrade.corner_radius_top_right = 14
	style_btn_upgrade.corner_radius_bottom_right = 14
	style_btn_upgrade.corner_radius_bottom_left = 14
	style_btn_upgrade.shadow_color = Color(0, 0, 0, 0.45)
	style_btn_upgrade.shadow_size = 6
	style_btn_upgrade.shadow_offset = Vector2(0, 3)

	# Rich Green/Gold Equip Button
	style_btn_equip = StyleBoxFlat.new()
	style_btn_equip.bg_color = Color(0.18, 0.62, 0.28, 1.0)
	style_btn_equip.border_width_left = 3
	style_btn_equip.border_width_top = 3
	style_btn_equip.border_width_right = 3
	style_btn_equip.border_width_bottom = 3
	style_btn_equip.border_color = Color(0.40, 0.92, 0.55, 1.0)
	style_btn_equip.corner_radius_top_left = 14
	style_btn_equip.corner_radius_top_right = 14
	style_btn_equip.corner_radius_bottom_right = 14
	style_btn_equip.corner_radius_bottom_left = 14
	style_btn_equip.shadow_color = Color(0, 0, 0, 0.45)
	style_btn_equip.shadow_size = 6
	style_btn_equip.shadow_offset = Vector2(0, 3)

	# Disabled Action Button
	style_btn_disabled = StyleBoxFlat.new()
	style_btn_disabled.bg_color = Color(0.18, 0.14, 0.12, 0.95)
	style_btn_disabled.border_width_left = 2
	style_btn_disabled.border_width_top = 2
	style_btn_disabled.border_width_right = 2
	style_btn_disabled.border_width_bottom = 2
	style_btn_disabled.border_color = Color(0.42, 0.32, 0.22, 0.8)
	style_btn_disabled.corner_radius_top_left = 14
	style_btn_disabled.corner_radius_top_right = 14
	style_btn_disabled.corner_radius_bottom_right = 14
	style_btn_disabled.corner_radius_bottom_left = 14

	style_btn_upgrade_disabled = style_btn_disabled

func _apply_safe_area() -> void:
	if not is_instance_valid(root_margin):
		return

	var margin_left: int = 14
	var margin_right: int = 14
	var margin_top: int = 14
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
			margin_left = maxi(margin_left, in_l + 6)
			margin_right = maxi(margin_right, in_r + 6)
			margin_top = maxi(margin_top, in_t + 6)
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
		purse_label.text = "🪙 %s" % _format_number(GameState.doubloons)

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
		var name_str: String = str(v_info.get("name", "Vessel")).to_upper()
		var arch_str: String = str(v_info.get("archetype", "Standard")).to_upper()
		var max_lvl: int = GameState.get_max_vessel_tier(selected_vessel_id)
		var tier_str: String = "LVL %d / %d" % [cur_tier, max_lvl] if is_owned else "LOCKED"
		inspector_title_label.text = "%s — %s (%s)" % [name_str, arch_str, tier_str]

	# 2. Collect max ceilings across all vessels when fully upgraded
	var max_stats: Dictionary = _get_max_fully_upgraded_stats()
	var max_hp_ceiling: float = float(max_stats["hp"])
	var max_speed_ceiling: float = float(max_stats["speed"])
	var max_firepower_ceiling: float = float(max_stats["firepower"])
	var max_agility_ceiling: float = float(max_stats["agility"])

	# 3. Collect selected-vessel stats scaled to current level
	var max_vessel_lvl: int = GameState.get_max_vessel_tier(selected_vessel_id)
	var progress_ratio: float = float(cur_tier - 1) / float(maxf(1.0, float(max_vessel_lvl - 1))) if is_owned else 0.0
	var max_hp_gain: float = 2.0 if selected_vessel_id == "dinghy" else (3.0 if selected_vessel_id == "sloop" else 2.0)
	var hp_val: float = (float(ship_data.max_health) + roundf(progress_ratio * max_hp_gain)) if ship_data else float(v_info.get("base_hp", 2))
	var speed_bonus_max: float = 1.0 if selected_vessel_id == "dinghy" else 3.0
	var speed_val: float = (ship_data.move_speed if ship_data else float(v_info.get("base_speed", 8.0))) + (progress_ratio * speed_bonus_max)
	var cannons_val: float = _get_vessel_firepower(ship_data, cur_tier if is_owned else 1)
	var agility_val: float = clampf((speed_val / max_speed_ceiling) * 85.0 + 15.0, 10.0, 100.0)

	# 4. Collect baseline (active/equipped) vessel stats for delta display
	var baseline_hp: float = -1.0
	var baseline_speed: float = -1.0
	var baseline_cannons: float = -1.0
	var baseline_agility: float = -1.0

	var active_id: String = GameState.active_vessel
	if active_id != selected_vessel_id and GameState.VESSEL_CATALOG.has(active_id):
		var base_data: ShipData = GameState.get_vessel_resource(active_id)
		var active_tier: int = GameState.get_vessel_tier(active_id)
		var active_max: int = GameState.get_max_vessel_tier(active_id)
		var active_ratio: float = float(active_tier - 1) / float(maxf(1.0, float(active_max - 1)))
		if base_data:
			var act_hp_gain: float = 2.0 if active_id == "dinghy" else (3.0 if active_id == "sloop" else 2.0)
			var act_spd_gain: float = 1.0 if active_id == "dinghy" else 3.0
			baseline_hp = float(base_data.max_health) + roundf(active_ratio * act_hp_gain)
			baseline_speed = base_data.move_speed + (active_ratio * act_spd_gain)
			baseline_cannons = _get_vessel_firepower(base_data, active_tier)
			baseline_agility = clampf((baseline_speed / max_speed_ceiling) * 85.0 + 15.0, 10.0, 100.0)

	# 5. Set stat bars matching reference mockup with icons & colors
	if stat_bar_hull_armor:
		stat_bar_hull_armor.set_icon(ICON_STAT_ARMOR)
		stat_bar_hull_armor.set_bar_color(Color("#22C55E"))
		stat_bar_hull_armor.set_stat("ARMOR", hp_val, max_hp_ceiling, baseline_hp, "%")
	if stat_bar_top_speed:
		stat_bar_top_speed.set_icon(ICON_STAT_SPEED)
		stat_bar_top_speed.set_bar_color(Color("#F59E0B"))
		stat_bar_top_speed.set_stat("SPEED", speed_val, max_speed_ceiling, baseline_speed, "%")
	if stat_bar_firepower:
		stat_bar_firepower.set_icon(ICON_STAT_FIREPOWER)
		stat_bar_firepower.set_bar_color(Color("#EF4444"))
		stat_bar_firepower.set_stat("FIREPOWER", cannons_val, max_firepower_ceiling, baseline_cannons, "%")
	if stat_bar_steering:
		stat_bar_steering.set_icon(ICON_STAT_AGILITY)
		stat_bar_steering.set_bar_color(Color("#38BDF8"))
		stat_bar_steering.set_stat("AGILITY", agility_val, max_agility_ceiling, baseline_agility, "%")

	# 6. Perk chips from tier_descriptions
	_rebuild_perk_chips(ship_data, cur_tier)

	# 7. Action buttons
	_update_action_buttons(v_info, is_owned, cur_tier, is_active)

func _get_vessel_firepower(s_data: ShipData, tier: int) -> float:
	if not s_data:
		return 1.0
	var count: int = s_data.base_cannons
	if s_data.tier_sockets.size() > 0:
		var tier_idx: int = clampi(tier - 1, 0, s_data.tier_sockets.size() - 1)
		var sockets: Array = s_data.tier_sockets[tier_idx]
		for s: Variant in sockets:
			var s_str: String = str(s).to_lower()
			if "crew" not in s_str and "bow" not in s_str:
				count += 1
	return float(count)

func _get_max_fully_upgraded_stats() -> Dictionary:
	var max_hp: float = 1.0
	var max_speed: float = 1.0
	var max_firepower: float = 1.0

	for v_id: String in GameState.VESSEL_CATALOG.keys():
		var s_data: ShipData = GameState.get_vessel_resource(v_id)
		if not s_data:
			continue
		var max_tier: int = GameState.get_max_vessel_tier(v_id)
		var hp_gain: float = 2.0 if v_id == "dinghy" else (3.0 if v_id == "sloop" else 2.0)
		var spd_gain: float = 1.0 if v_id == "dinghy" else 3.0
		var upgraded_hp: float = float(s_data.max_health) + hp_gain
		var upgraded_speed: float = s_data.move_speed + spd_gain
		var upgraded_fp: float = _get_vessel_firepower(s_data, max_tier)

		max_hp = maxf(max_hp, upgraded_hp)
		max_speed = maxf(max_speed, upgraded_speed)
		max_firepower = maxf(max_firepower, upgraded_fp)

	return {
		"hp": max_hp,
		"speed": max_speed,
		"firepower": max_firepower,
		"agility": 100.0
	}

func _rebuild_perk_chips(ship_data: ShipData, cur_tier: int) -> void:
	if not perk_flow_container:
		return
	for child: Node in perk_flow_container.get_children():
		child.queue_free()

	if not ship_data or ship_data.tier_descriptions.is_empty():
		return

	var desc_idx: int = clampi(cur_tier - 1, 0, ship_data.tier_descriptions.size() - 1)
	var full_desc: String = ship_data.tier_descriptions[desc_idx]

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

	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_override("font", preload("res://assets/fonts/CarterOne.ttf"))
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.98, 0.92, 0.78, 1.0))

	chip_panel.add_child(label)
	perk_flow_container.add_child(chip_panel)

func _update_action_buttons(v_info: Dictionary, is_owned: bool, cur_tier: int, is_active: bool) -> void:
	if not action_button:
		return

	if not is_owned:
		if equip_button:
			equip_button.visible = false
		action_button.visible = true
		current_action_state = ActionState.BUY
		var price: int = int(v_info.get("purchase_price", 0))
		var can_buy: bool = GameState.can_afford(price)
		action_button.text = "🪙 %s   BUILD VESSEL" % _format_number(price)
		action_button.add_theme_stylebox_override("normal", style_btn_buy)
		action_button.add_theme_stylebox_override("hover", style_btn_buy)
		action_button.add_theme_stylebox_override("pressed", style_btn_buy)
		action_button.add_theme_color_override("font_color", Color(0.18, 0.10, 0.04, 1.0))
		action_button.disabled = not can_buy
		action_button.modulate = Color.WHITE if can_buy else Color(0.7, 0.7, 0.7, 0.75)
	else:
		# Vessel is owned
		var max_lvl: int = GameState.get_max_vessel_tier(selected_vessel_id)
		var next_tier: int = cur_tier + 1
		var can_upgrade_tier: bool = (cur_tier < max_lvl)

		if is_active:
			if can_upgrade_tier:
				if equip_button:
					equip_button.visible = false
				action_button.visible = true
				current_action_state = ActionState.UPGRADE
				var cost: int = GameState.get_upgrade_cost(selected_vessel_id, next_tier)
				var can_upgrade: bool = GameState.can_afford(cost)
				action_button.text = "UPGRADE TO LVL %d • %s 🪙" % [next_tier, _format_number(cost)]
				action_button.add_theme_stylebox_override("normal", style_btn_upgrade)
				action_button.add_theme_stylebox_override("hover", style_btn_upgrade)
				action_button.add_theme_stylebox_override("pressed", style_btn_upgrade)
				action_button.add_theme_stylebox_override("disabled", style_btn_upgrade_disabled)
				action_button.disabled = not can_upgrade
				action_button.modulate = Color.WHITE if can_upgrade else Color(0.7, 0.7, 0.7, 0.75)
			else:
				if equip_button:
					equip_button.visible = true
					equip_button.text = "ACTIVE VESSEL (MAX LEVEL) ✓"
					equip_button.disabled = true
					equip_button.add_theme_stylebox_override("normal", style_btn_disabled)
					equip_button.add_theme_stylebox_override("disabled", style_btn_disabled)
					equip_button.modulate = Color(0.85, 1.0, 0.85, 0.95)
				action_button.visible = false
		else:
			# Owned but not active
			if equip_button:
				equip_button.visible = true
				equip_button.text = "EQUIP VESSEL"
				equip_button.disabled = false
				equip_button.add_theme_stylebox_override("normal", style_btn_equip)
				equip_button.add_theme_stylebox_override("hover", style_btn_equip)
				equip_button.add_theme_stylebox_override("pressed", style_btn_equip)
				equip_button.modulate = Color.WHITE

			if can_upgrade_tier:
				action_button.visible = true
				current_action_state = ActionState.UPGRADE
				var cost: int = GameState.get_upgrade_cost(selected_vessel_id, next_tier)
				var can_upgrade: bool = GameState.can_afford(cost)
				action_button.text = "UPGRADE TO LVL %d • %s 🪙" % [next_tier, _format_number(cost)]
				action_button.add_theme_stylebox_override("normal", style_btn_upgrade)
				action_button.add_theme_stylebox_override("hover", style_btn_upgrade)
				action_button.add_theme_stylebox_override("pressed", style_btn_upgrade)
				action_button.add_theme_stylebox_override("disabled", style_btn_upgrade_disabled)
				action_button.add_theme_color_override("font_disabled_color", Color(0.85, 0.78, 0.68, 0.95))
				action_button.disabled = not can_upgrade
				action_button.modulate = Color.WHITE if can_upgrade else Color(0.7, 0.7, 0.7, 0.75)
			else:
				action_button.visible = false

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
	if action_button:
		action_button.visible = false
	if equip_button:
		equip_button.visible = false
	_build_crew_cards()

func _on_tab_outfitting_pressed() -> void:
	if current_tab == TabType.OUTFITTING:
		return
	current_tab = TabType.OUTFITTING
	AudioManager.play_sfx("gate_passes", 1.0, 1.2)
	_update_tab_headers()
	if drawer_panel:
		drawer_panel.visible = false
	if action_button:
		action_button.visible = false
	if equip_button:
		equip_button.visible = false
	_build_outfitting_cards()

func _update_tab_headers() -> void:
	var color_active: Color = Color(0.99, 0.88, 0.32, 1.0)
	var color_inactive: Color = Color(0.85, 0.82, 0.75, 0.9)

	if label_vessels:
		label_vessels.add_theme_color_override("font_color", color_active if current_tab == TabType.VESSELS else color_inactive)
	if icon_vessels:
		icon_vessels.modulate = Color.WHITE if current_tab == TabType.VESSELS else Color(0.85, 0.82, 0.75, 0.85)
	if indicator_vessels:
		indicator_vessels.visible = (current_tab == TabType.VESSELS)

	if label_crew:
		label_crew.add_theme_color_override("font_color", color_active if current_tab == TabType.CREW else color_inactive)
	if icon_crew:
		icon_crew.modulate = Color.WHITE if current_tab == TabType.CREW else Color(0.85, 0.82, 0.75, 0.85)
	if indicator_crew:
		indicator_crew.visible = (current_tab == TabType.CREW)

	if label_outfitting:
		label_outfitting.add_theme_color_override("font_color", color_active if current_tab == TabType.OUTFITTING else color_inactive)
	if icon_outfitting:
		icon_outfitting.modulate = Color.WHITE if current_tab == TabType.OUTFITTING else Color(0.85, 0.82, 0.75, 0.85)
	if indicator_outfitting:
		indicator_outfitting.visible = (current_tab == TabType.OUTFITTING)

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
		var cat: String = str(info.get("category", "ammo"))
		if not items_by_category.has(cat):
			items_by_category[cat] = []
			categories.append(cat)
			category_titles[cat] = cat.to_upper()
		(items_by_category[cat] as Array).append(item_id)

	for cat: String in categories:
		var cat_items: Array = items_by_category[cat] as Array
		if not cat_items.is_empty():
			var title: String = str(category_titles.get(cat, cat.to_upper()))
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
	print("[TELEMETRY:SHIPYARD] ⚓ Shipyard Closed | Vault Balance: %d 🪙" % (GameState.doubloons if GameState else 0))
	shipyard_closed.emit()
	queue_free()


func _format_number(val: int) -> String:
	var s: String = str(absi(val))
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
