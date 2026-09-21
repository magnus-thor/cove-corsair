class_name VesselCard
extends PanelContainer

## Reusable 2-column vessel card component for the Shipyard
## Displays vessel illustration, high-contrast tier ribbon, and state tag:
## "EQUIPPED" (green), "OWNED" (neutral wood), or "LOCKED - [Cost] 🪙"
## Clicking the card emits card_clicked for inspection drawer selection without auto-equipping.
## Fully statically typed.

signal card_clicked(vessel_id: String)

@onready var click_button: Button = %ClickButton
@onready var title_label: Label = %TitleLabel
@onready var tier_badge: PanelContainer = %TierBadge
@onready var tier_badge_label: Label = %TierBadgeLabel
@onready var preview_texture: TextureRect = %PreviewTexture
@onready var lock_icon: TextureRect = %LockIcon
@onready var status_panel: PanelContainer = %StatusPanel
@onready var status_label: Label = %StatusLabel
@onready var status_icon: TextureRect = %StatusIcon

var vessel_id: String = ""
var is_selected: bool = false
var is_mystery: bool = false

# Custom StyleBoxes for states
var style_normal: StyleBoxFlat
var style_selected: StyleBoxFlat
var style_mystery: StyleBoxFlat

# Status pill styles
var style_status_equipped: StyleBoxFlat
var style_status_owned: StyleBoxFlat
var style_status_locked: StyleBoxFlat

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_init_styles()
	_apply_card_border()
	if click_button:
		click_button.pressed.connect(_on_clicked)
		click_button.mouse_entered.connect(_on_mouse_entered)
		click_button.mouse_exited.connect(_on_mouse_exited)

func _init_styles() -> void:
	# Normal Card Style (Dark rich slate interior with warm bronze border matching reference mockup)
	style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.06, 0.09, 0.14, 0.92)
	style_normal.border_width_left = 2
	style_normal.border_width_top = 2
	style_normal.border_width_right = 2
	style_normal.border_width_bottom = 2
	style_normal.border_color = Color(0.48, 0.38, 0.25, 0.9)
	style_normal.corner_radius_top_left = 14
	style_normal.corner_radius_top_right = 14
	style_normal.corner_radius_bottom_right = 14
	style_normal.corner_radius_bottom_left = 14
	style_normal.shadow_color = Color(0, 0, 0, 0.45)
	style_normal.shadow_size = 6
	style_normal.shadow_offset = Vector2(0, 3)

	# Selected Card Style (Electric cyan focus glow from reference image)
	style_selected = StyleBoxFlat.new()
	style_selected.bg_color = Color(0.07, 0.11, 0.17, 0.95)
	style_selected.border_width_left = 3
	style_selected.border_width_top = 3
	style_selected.border_width_right = 3
	style_selected.border_width_bottom = 3
	style_selected.border_color = Color(0.0, 0.94, 1.0, 1.0)
	style_selected.corner_radius_top_left = 14
	style_selected.corner_radius_top_right = 14
	style_selected.corner_radius_bottom_right = 14
	style_selected.corner_radius_bottom_left = 14
	style_selected.shadow_color = Color(0.0, 0.94, 1.0, 0.55)
	style_selected.shadow_size = 14
	style_selected.shadow_offset = Vector2(0, 0)

	# Mystery / Locked Card Style
	style_mystery = StyleBoxFlat.new()
	style_mystery.bg_color = Color(0.05, 0.07, 0.10, 0.85)
	style_mystery.border_width_left = 2
	style_mystery.border_width_top = 2
	style_mystery.border_width_right = 2
	style_mystery.border_width_bottom = 2
	style_mystery.border_color = Color(0.24, 0.28, 0.34, 0.8)
	style_mystery.corner_radius_top_left = 14
	style_mystery.corner_radius_top_right = 14
	style_mystery.corner_radius_bottom_right = 14
	style_mystery.corner_radius_bottom_left = 14
	style_mystery.shadow_color = Color(0, 0, 0, 0.3)
	style_mystery.shadow_size = 4
	style_mystery.shadow_offset = Vector2(0, 2)

	# Status Equipped (Vibrant Green)
	style_status_equipped = StyleBoxFlat.new()
	style_status_equipped.bg_color = Color(0.12, 0.52, 0.18, 0.95)
	style_status_equipped.border_width_left = 2
	style_status_equipped.border_width_top = 2
	style_status_equipped.border_width_right = 2
	style_status_equipped.border_width_bottom = 2
	style_status_equipped.border_color = Color(0.29, 0.87, 0.5, 0.8)
	style_status_equipped.corner_radius_top_left = 8
	style_status_equipped.corner_radius_top_right = 8
	style_status_equipped.corner_radius_bottom_right = 8
	style_status_equipped.corner_radius_bottom_left = 8

	# Status Owned (Neutral Wood tone)
	style_status_owned = StyleBoxFlat.new()
	style_status_owned.bg_color = Color(0.28, 0.18, 0.12, 0.95)
	style_status_owned.border_width_left = 2
	style_status_owned.border_width_top = 2
	style_status_owned.border_width_right = 2
	style_status_owned.border_width_bottom = 2
	style_status_owned.border_color = Color(0.55, 0.42, 0.26, 0.8)
	style_status_owned.corner_radius_top_left = 8
	style_status_owned.corner_radius_top_right = 8
	style_status_owned.corner_radius_bottom_right = 8
	style_status_owned.corner_radius_bottom_left = 8

	# Status Locked (Dark Bronze / Charcoal Wood)
	style_status_locked = StyleBoxFlat.new()
	style_status_locked.bg_color = Color(0.14, 0.12, 0.12, 0.95)
	style_status_locked.border_width_left = 2
	style_status_locked.border_width_top = 2
	style_status_locked.border_width_right = 2
	style_status_locked.border_width_bottom = 2
	style_status_locked.border_color = Color(0.35, 0.28, 0.22, 0.8)
	style_status_locked.corner_radius_top_left = 8
	style_status_locked.corner_radius_top_right = 8
	style_status_locked.corner_radius_bottom_right = 8
	style_status_locked.corner_radius_bottom_left = 8

func setup_vessel(v_id: String, _index_num: int = 0) -> void:
	vessel_id = v_id
	is_mystery = false

	if not GameState.VESSEL_CATALOG.has(v_id):
		setup_mystery(_index_num)
		return

	var v_data: Dictionary = GameState.VESSEL_CATALOG[v_id]
	if title_label:
		title_label.text = str(v_data["name"]).to_upper()

	if preview_texture:
		var tex_path: String = str(v_data["preview_texture"])
		if ResourceLoader.exists(tex_path):
			preview_texture.texture = load(tex_path) as Texture2D
			preview_texture.modulate = Color.WHITE

	if lock_icon:
		lock_icon.visible = false

	update_status()

func setup_mystery(_index_num: int = 0) -> void:
	vessel_id = "mystery"
	is_mystery = true

	if title_label:
		title_label.text = "LOCKED"

	if tier_badge:
		tier_badge.visible = false

	if preview_texture:
		var sil_path: String = "res://assets/sprites/user_vessels/mystery_ship_silhouette.svg"
		if ResourceLoader.exists(sil_path):
			preview_texture.texture = load(sil_path) as Texture2D
			preview_texture.modulate = Color(1, 1, 1, 0.85)

	if lock_icon:
		lock_icon.visible = true

	if status_panel:
		status_panel.add_theme_stylebox_override("panel", style_status_locked)
	if status_label:
		status_label.text = "COMING SOON"
		status_label.add_theme_color_override("font_color", Color(0.7, 0.65, 0.6, 1))
	if status_icon:
		status_icon.visible = false

	_apply_card_border()

func update_status() -> void:
	if is_mystery:
		return

	var is_owned: bool = GameState.is_vessel_owned(vessel_id)
	var cur_tier: int = GameState.get_vessel_tier(vessel_id)
	var is_active: bool = (GameState.active_vessel == vessel_id)
	var v_data: Dictionary = GameState.VESSEL_CATALOG[vessel_id]

	# High contrast Tier badge
	if tier_badge:
		if is_owned:
			tier_badge.visible = true
			if tier_badge_label:
				var max_lvl: int = GameState.get_max_vessel_tier(vessel_id)
				tier_badge_label.text = "LVL %d / %d" % [cur_tier, max_lvl]
		else:
			tier_badge.visible = false

	# State Tag: "EQUIPPED" (green), "OWNED" (neutral wood), or "LOCKED - [Cost] 🪙"
	if is_active:
		if status_panel:
			status_panel.add_theme_stylebox_override("panel", style_status_equipped)
		if status_label:
			status_label.text = "EQUIPPED"
			status_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		if status_icon:
			status_icon.visible = false
	elif is_owned:
		if status_panel:
			status_panel.add_theme_stylebox_override("panel", style_status_owned)
		if status_label:
			status_label.text = "OWNED"
			status_label.add_theme_color_override("font_color", Color(1, 0.98, 0.92, 1))
		if status_icon:
			status_icon.visible = false
	else:
		var price: int = int(v_data["purchase_price"])
		if status_panel:
			status_panel.add_theme_stylebox_override("panel", style_status_locked)
		if status_label:
			status_label.text = "%s 🪙" % _format_number(price)
			status_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.75, 1))
		if status_icon:
			status_icon.visible = false

	_apply_card_border()

func set_selected(selected: bool) -> void:
	is_selected = selected
	_apply_card_border()

func _apply_card_border() -> void:
	if not style_normal:
		_init_styles()

	if is_mystery:
		add_theme_stylebox_override("panel", style_mystery)
		if title_label:
			title_label.add_theme_color_override("font_color", Color(0.48, 0.52, 0.58, 1.0))
			title_label.add_theme_constant_override("outline_size", 0)
	elif is_selected:
		add_theme_stylebox_override("panel", style_selected)
		if title_label:
			title_label.add_theme_color_override("font_color", Color(0.99, 0.98, 0.92, 1.0))
			title_label.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.08, 1.0))
			title_label.add_theme_constant_override("outline_size", 3)
	else:
		add_theme_stylebox_override("panel", style_normal)
		if title_label:
			title_label.add_theme_color_override("font_color", Color(0.92, 0.88, 0.82, 1.0))
			title_label.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.02, 1.0))
			title_label.add_theme_constant_override("outline_size", 2)

func _on_clicked() -> void:
	if is_mystery:
		AudioManager.play_sfx("gate_passes", 0.7, 0.8)
		return
	card_clicked.emit(vessel_id)

func _on_mouse_entered() -> void:
	if not is_selected and not is_mystery:
		var hover_style: StyleBoxFlat = style_normal.duplicate() as StyleBoxFlat
		hover_style.border_color = Color(0.95, 0.78, 0.28, 1.0)
		hover_style.shadow_size = 10
		add_theme_stylebox_override("panel", hover_style)

func _on_mouse_exited() -> void:
	_apply_card_border()

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
