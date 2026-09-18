class_name OutfittingCard
extends PanelContainer

signal buy_requested(item_id: String)
signal equip_requested(item_id: String)

@onready var item_name_label: Label = %ItemNameLabel
@onready var item_icon: TextureRect = %ItemIcon
@onready var desc_label: Label = %DescLabel
@onready var buy_button: Button = %BuyButton
@onready var equip_button: Button = %EquipButton

var item_id: String = ""

# Styleboxes for buttons
var style_buy: StyleBoxFlat
var style_equip: StyleBoxFlat
var style_equipped: StyleBoxFlat
var style_disabled: StyleBoxFlat

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_init_styles()
	if buy_button:
		buy_button.pressed.connect(func(): buy_requested.emit(item_id))
	if equip_button:
		equip_button.pressed.connect(func(): equip_requested.emit(item_id))

func _init_styles() -> void:
	# Buy: gold (#FBBF24) for maximum legibility with dark label text
	style_buy = StyleBoxFlat.new()
	style_buy.bg_color = Color(0.984, 0.750, 0.141, 1.0)
	style_buy.border_width_left = 2
	style_buy.border_width_top = 2
	style_buy.border_width_right = 2
	style_buy.border_width_bottom = 2
	style_buy.border_color = Color(1.0, 0.88, 0.45, 1.0)
	style_buy.corner_radius_top_left = 12
	style_buy.corner_radius_top_right = 12
	style_buy.corner_radius_bottom_right = 12
	style_buy.corner_radius_bottom_left = 12

	style_equip = StyleBoxFlat.new()
	style_equip.bg_color = Color(0.20, 0.68, 0.16, 1.0)
	style_equip.border_width_left = 2
	style_equip.border_width_top = 2
	style_equip.border_width_right = 2
	style_equip.border_width_bottom = 2
	style_equip.border_color = Color(0.12, 0.44, 0.08, 1.0)
	style_equip.corner_radius_top_left = 12
	style_equip.corner_radius_top_right = 12
	style_equip.corner_radius_bottom_right = 12
	style_equip.corner_radius_bottom_left = 12

	style_equipped = StyleBoxFlat.new()
	style_equipped.bg_color = Color(0.082, 0.31, 0.082, 1.0)
	style_equipped.border_width_left = 2
	style_equipped.border_width_top = 2
	style_equipped.border_width_right = 2
	style_equipped.border_width_bottom = 2
	style_equipped.border_color = Color(0.29, 0.867, 0.502, 0.8)
	style_equipped.corner_radius_top_left = 12
	style_equipped.corner_radius_top_right = 12
	style_equipped.corner_radius_bottom_right = 12
	style_equipped.corner_radius_bottom_left = 12

	style_disabled = StyleBoxFlat.new()
	style_disabled.bg_color = Color(0.082, 0.149, 0.22, 0.85)
	style_disabled.border_width_left = 1
	style_disabled.border_width_top = 1
	style_disabled.border_width_right = 1
	style_disabled.border_width_bottom = 1
	style_disabled.border_color = Color(0.18, 0.31, 0.47, 0.8)
	style_disabled.corner_radius_top_left = 12
	style_disabled.corner_radius_top_right = 12
	style_disabled.corner_radius_bottom_right = 12
	style_disabled.corner_radius_bottom_left = 12

func setup_item(p_item_id: String) -> void:
	item_id = p_item_id
	update_card()

func update_card() -> void:
	if not GameState or not GameState.OUTFITTING_CATALOG.has(item_id):
		return

	var info: Dictionary = GameState.OUTFITTING_CATALOG[item_id]
	var is_unlocked: bool = GameState.is_outfitting_unlocked(item_id)
	var category: String = info.get("category", "ammo")

	var is_equipped: bool = false
	if category == "ammo":
		is_equipped = (GameState.get_active_ammo() == item_id)
	elif category == "plating":
		is_equipped = (GameState.get_active_plating() == item_id)

	if item_name_label:
		item_name_label.text = info.get("name", "Outfitting").to_upper()

	if item_icon and info.has("preview_texture"):
		var p_tex: String = info["preview_texture"]
		if ResourceLoader.exists(p_tex):
			item_icon.texture = load(p_tex)

	if desc_label:
		desc_label.text = info.get("description", "")

	# Button state
	if not is_unlocked:
		if buy_button:
			buy_button.visible = true
			var cost: int = info.get("price", 0)
			buy_button.text = "BUY: %d 🪙" % cost
			var can_afford: bool = GameState.can_afford(cost)
			buy_button.disabled = not can_afford
			buy_button.add_theme_stylebox_override("normal", style_buy if can_afford else style_disabled)
			if can_afford:
				buy_button.add_theme_color_override("font_color", Color("#0B131F"))
		if equip_button:
			equip_button.visible = false
	else:
		if buy_button:
			buy_button.visible = false
		if equip_button:
			equip_button.visible = true
			if is_equipped:
				equip_button.text = "EQUIPPED ✓"
				equip_button.disabled = false
				equip_button.add_theme_stylebox_override("normal", style_equipped)
			else:
				equip_button.text = "EQUIP"
				equip_button.disabled = false
				equip_button.add_theme_stylebox_override("normal", style_equip)
