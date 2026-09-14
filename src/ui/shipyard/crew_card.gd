class_name CrewCard
extends PanelContainer

signal buy_requested(crew_id: String)
signal upgrade_requested(crew_id: String)
signal equip_requested(crew_id: String)

@onready var crew_name_label: Label = %CrewNameLabel
@onready var role_badge_label: Label = %RoleBadgeLabel
@onready var level_badge_label: Label = %LevelBadgeLabel
@onready var crew_icon: TextureRect = %CrewIcon
@onready var stats_desc_label: Label = %StatsDescLabel
@onready var next_upgrade_label: Label = %NextUpgradeLabel
@onready var buy_button: Button = %BuyButton
@onready var upgrade_button: Button = %UpgradeButton
@onready var equip_button: Button = %EquipButton

var crew_id: String = ""

# Styleboxes for buttons
var style_buy: StyleBoxFlat
var style_upgrade: StyleBoxFlat
var style_equip: StyleBoxFlat
var style_equipped: StyleBoxFlat
var style_disabled: StyleBoxFlat

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_init_styles()
	if buy_button:
		buy_button.pressed.connect(func(): buy_requested.emit(crew_id))
	if upgrade_button:
		upgrade_button.pressed.connect(func(): upgrade_requested.emit(crew_id))
	if equip_button:
		equip_button.pressed.connect(func(): equip_requested.emit(crew_id))

func _init_styles() -> void:
	style_buy = StyleBoxFlat.new()
	style_buy.bg_color = Color(0.82, 0.58, 0.18, 1.0)
	style_buy.border_width_left = 3
	style_buy.border_width_top = 3
	style_buy.border_width_right = 3
	style_buy.border_width_bottom = 3
	style_buy.border_color = Color(1.0, 0.88, 0.45, 1.0)
	style_buy.corner_radius_top_left = 12
	style_buy.corner_radius_top_right = 12
	style_buy.corner_radius_bottom_right = 12
	style_buy.corner_radius_bottom_left = 12

	style_upgrade = StyleBoxFlat.new()
	style_upgrade.bg_color = Color(0.72, 0.13, 0.18, 1.0)
	style_upgrade.border_width_left = 3
	style_upgrade.border_width_top = 3
	style_upgrade.border_width_right = 3
	style_upgrade.border_width_bottom = 3
	style_upgrade.border_color = Color(0.95, 0.78, 0.28, 1.0)
	style_upgrade.corner_radius_top_left = 12
	style_upgrade.corner_radius_top_right = 12
	style_upgrade.corner_radius_bottom_right = 12
	style_upgrade.corner_radius_bottom_left = 12

	style_equip = StyleBoxFlat.new()
	style_equip.bg_color = Color(0.20, 0.68, 0.16, 1.0)
	style_equip.border_width_left = 3
	style_equip.border_width_top = 3
	style_equip.border_width_right = 3
	style_equip.border_width_bottom = 3
	style_equip.border_color = Color(0.12, 0.44, 0.08, 1.0)
	style_equip.corner_radius_top_left = 12
	style_equip.corner_radius_top_right = 12
	style_equip.corner_radius_bottom_right = 12
	style_equip.corner_radius_bottom_left = 12

	style_equipped = StyleBoxFlat.new()
	style_equipped.bg_color = Color(0.25, 0.45, 0.22, 1.0)
	style_equipped.border_width_left = 3
	style_equipped.border_width_top = 3
	style_equipped.border_width_right = 3
	style_equipped.border_width_bottom = 3
	style_equipped.border_color = Color(0.4, 0.8, 0.35, 1.0)
	style_equipped.corner_radius_top_left = 12
	style_equipped.corner_radius_top_right = 12
	style_equipped.corner_radius_bottom_right = 12
	style_equipped.corner_radius_bottom_left = 12

	style_disabled = StyleBoxFlat.new()
	style_disabled.bg_color = Color(0.3, 0.25, 0.22, 0.8)
	style_disabled.border_width_left = 2
	style_disabled.border_width_top = 2
	style_disabled.border_width_right = 2
	style_disabled.border_width_bottom = 2
	style_disabled.border_color = Color(0.4, 0.35, 0.3, 0.8)
	style_disabled.corner_radius_top_left = 12
	style_disabled.corner_radius_top_right = 12
	style_disabled.corner_radius_bottom_right = 12
	style_disabled.corner_radius_bottom_left = 12

func setup_crew(p_crew_id: String) -> void:
	crew_id = p_crew_id
	update_card()

func update_card() -> void:
	if not GameState or not GameState.CREW_CATALOG.has(crew_id):
		return
		
	var c_info = GameState.CREW_CATALOG[crew_id]
	var is_unlocked = GameState.is_crew_unlocked(crew_id)
	var cur_lvl = GameState.get_crew_level(crew_id)
	var is_equipped = GameState.is_crew_equipped_on_active_ship(crew_id)
	
	if crew_name_label:
		crew_name_label.text = c_info.get("name", "Crew").to_upper()
	if role_badge_label:
		role_badge_label.text = c_info.get("role", "CREW").to_upper()
	if crew_icon and c_info.has("preview_texture"):
		var p_tex = c_info["preview_texture"]
		if ResourceLoader.exists(p_tex):
			crew_icon.texture = load(p_tex)

	if level_badge_label:
		if not is_unlocked:
			level_badge_label.text = "LOCKED"
			level_badge_label.modulate = Color(0.8, 0.4, 0.4)
		else:
			level_badge_label.text = "LEVEL %d" % cur_lvl
			level_badge_label.modulate = Color(1.0, 0.85, 0.3)

	# Stats description
	if stats_desc_label:
		if is_unlocked and cur_lvl >= 1:
			var lvl_info = c_info["levels"].get(cur_lvl, {})
			stats_desc_label.text = lvl_info.get("description", "")
		else:
			var lvl1_info = c_info["levels"].get(1, {})
			stats_desc_label.text = "L1: " + lvl1_info.get("description", "")

	# Next upgrade preview
	if next_upgrade_label:
		if not is_unlocked:
			next_upgrade_label.text = "Unlock to deploy on vessel deck crew sockets."
		elif cur_lvl < 3:
			var next_lvl = cur_lvl + 1
			var up_cost = GameState.get_crew_upgrade_cost(crew_id, next_lvl)
			var n_info = c_info["levels"].get(next_lvl, {})
			next_upgrade_label.text = "Next (L%d - %d 🪙): %s" % [next_lvl, up_cost, n_info.get("description", "")]
		else:
			next_upgrade_label.text = "Mastered (Max Level 3)"

	# Button visibility and setup
	if not is_unlocked:
		if buy_button:
			buy_button.visible = true
			var cost = GameState.get_crew_unlock_cost(crew_id)
			buy_button.text = "BUY: %d 🪙" % cost
			var can_afford = GameState.can_afford(cost)
			buy_button.disabled = not can_afford
			buy_button.add_theme_stylebox_override("normal", style_buy if can_afford else style_disabled)
		if upgrade_button:
			upgrade_button.visible = false
		if equip_button:
			equip_button.visible = false
	else:
		if buy_button:
			buy_button.visible = false
			
		if upgrade_button:
			if cur_lvl < 3:
				upgrade_button.visible = true
				var cost = GameState.get_crew_upgrade_cost(crew_id, cur_lvl + 1)
				upgrade_button.text = "UPGRADE L%d: %d 🪙" % [cur_lvl + 1, cost]
				var can_up = GameState.can_afford(cost)
				upgrade_button.disabled = not can_up
				upgrade_button.add_theme_stylebox_override("normal", style_upgrade if can_up else style_disabled)
			else:
				upgrade_button.visible = true
				upgrade_button.disabled = true
				upgrade_button.text = "MAX LEVEL"
				upgrade_button.add_theme_stylebox_override("normal", style_disabled)
				upgrade_button.add_theme_stylebox_override("disabled", style_disabled)

		if equip_button:
			equip_button.visible = true
			var available_crew_sockets = GameState.get_crew_sockets_for_ship(GameState.active_vessel)
			
			if is_equipped:
				equip_button.text = "EQUIPPED ✓"
				equip_button.disabled = false
				equip_button.add_theme_stylebox_override("normal", style_equipped)
			elif available_crew_sockets.is_empty():
				equip_button.text = "NO SOCKETS"
				equip_button.disabled = true
				equip_button.add_theme_stylebox_override("normal", style_disabled)
				equip_button.add_theme_stylebox_override("disabled", style_disabled)
			else:
				equip_button.text = "EQUIP"
				equip_button.disabled = false
				equip_button.add_theme_stylebox_override("normal", style_equip)
