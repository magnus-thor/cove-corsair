class_name VesselCard
extends PanelContainer

## Reusable 2-column vessel card component for the Shipyard
## Displays vessel illustration, index badge, tier ribbon, and quick status pill.
## Clicking the card emits card_clicked for inspection drawer selection without auto-equipping.

signal card_clicked(vessel_id: String)

@onready var click_button: Button = %ClickButton
@onready var index_badge_label: Label = %IndexBadgeLabel
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
var style_status_buy: StyleBoxFlat
var style_status_locked: StyleBoxFlat

func _ready() -> void:
	_init_styles()
	if click_button:
		click_button.pressed.connect(_on_clicked)
		click_button.mouse_entered.connect(_on_mouse_entered)
		click_button.mouse_exited.connect(_on_mouse_exited)

func _init_styles() -> void:
	# Normal Card Style (Parchment with dark chocolate border)
	style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.93, 0.88, 0.79, 1.0) # #EDE0C9
	style_normal.border_width_left = 4
	style_normal.border_width_top = 4
	style_normal.border_width_right = 4
	style_normal.border_width_bottom = 4
	style_normal.border_color = Color(0.24, 0.17, 0.12, 1.0) # #3D2B1E
	style_normal.corner_radius_top_left = 16
	style_normal.corner_radius_top_right = 16
	style_normal.corner_radius_bottom_right = 16
	style_normal.corner_radius_bottom_left = 16
	style_normal.shadow_color = Color(0, 0, 0, 0.45)
	style_normal.shadow_size = 6
	style_normal.shadow_offset = Vector2(0, 4)

	# Selected Card Style (Glowing Gold Border)
	style_selected = StyleBoxFlat.new()
	style_selected.bg_color = Color(0.96, 0.92, 0.84, 1.0)
	style_selected.border_width_left = 5
	style_selected.border_width_top = 5
	style_selected.border_width_right = 5
	style_selected.border_width_bottom = 5
	style_selected.border_color = Color(0.98, 0.78, 0.22, 1.0) # #FBC738
	style_selected.corner_radius_top_left = 16
	style_selected.corner_radius_top_right = 16
	style_selected.corner_radius_bottom_right = 16
	style_selected.corner_radius_bottom_left = 16
	style_selected.shadow_color = Color(0.98, 0.78, 0.22, 0.4)
	style_selected.shadow_size = 12
	style_selected.shadow_offset = Vector2(0, 4)

	# Mystery / Locked Card Style (Darker tone)
	style_mystery = StyleBoxFlat.new()
	style_mystery.bg_color = Color(0.72, 0.67, 0.60, 1.0)
	style_mystery.border_width_left = 4
	style_mystery.border_width_top = 4
	style_mystery.border_width_right = 4
	style_mystery.border_width_bottom = 4
	style_mystery.border_color = Color(0.28, 0.32, 0.36, 1.0)
	style_mystery.corner_radius_top_left = 16
	style_mystery.corner_radius_top_right = 16
	style_mystery.corner_radius_bottom_right = 16
	style_mystery.corner_radius_bottom_left = 16
	style_mystery.shadow_color = Color(0, 0, 0, 0.35)
	style_mystery.shadow_size = 6
	style_mystery.shadow_offset = Vector2(0, 4)

	# Status Equipped (Vibrant Green)
	style_status_equipped = StyleBoxFlat.new()
	style_status_equipped.bg_color = Color(0.25, 0.76, 0.16, 1.0) # #40C229
	style_status_equipped.border_width_left = 3
	style_status_equipped.border_width_top = 3
	style_status_equipped.border_width_right = 3
	style_status_equipped.border_width_bottom = 3
	style_status_equipped.border_color = Color(0.14, 0.46, 0.08, 1.0)
	style_status_equipped.corner_radius_top_left = 12
	style_status_equipped.corner_radius_top_right = 12
	style_status_equipped.corner_radius_bottom_right = 12
	style_status_equipped.corner_radius_bottom_left = 12

	# Status Owned (Warm Slate / Amber)
	style_status_owned = StyleBoxFlat.new()
	style_status_owned.bg_color = Color(0.26, 0.34, 0.42, 1.0)
	style_status_owned.border_width_left = 3
	style_status_owned.border_width_top = 3
	style_status_owned.border_width_right = 3
	style_status_owned.border_width_bottom = 3
	style_status_owned.border_color = Color(0.16, 0.22, 0.28, 1.0)
	style_status_owned.corner_radius_top_left = 12
	style_status_owned.corner_radius_top_right = 12
	style_status_owned.corner_radius_bottom_right = 12
	style_status_owned.corner_radius_bottom_left = 12

	# Status Buy (Warm Bronze / Gold)
	style_status_buy = StyleBoxFlat.new()
	style_status_buy.bg_color = Color(0.76, 0.54, 0.22, 1.0)
	style_status_buy.border_width_left = 3
	style_status_buy.border_width_top = 3
	style_status_buy.border_width_right = 3
	style_status_buy.border_width_bottom = 3
	style_status_buy.border_color = Color(0.42, 0.28, 0.10, 1.0)
	style_status_buy.corner_radius_top_left = 12
	style_status_buy.corner_radius_top_right = 12
	style_status_buy.corner_radius_bottom_right = 12
	style_status_buy.corner_radius_bottom_left = 12

	# Status Locked (Dark Muted Slate)
	style_status_locked = StyleBoxFlat.new()
	style_status_locked.bg_color = Color(0.22, 0.20, 0.18, 1.0)
	style_status_locked.border_width_left = 3
	style_status_locked.border_width_top = 3
	style_status_locked.border_width_right = 3
	style_status_locked.border_width_bottom = 3
	style_status_locked.border_color = Color(0.12, 0.10, 0.08, 1.0)
	style_status_locked.corner_radius_top_left = 12
	style_status_locked.corner_radius_top_right = 12
	style_status_locked.corner_radius_bottom_right = 12
	style_status_locked.corner_radius_bottom_left = 12

func setup_vessel(v_id: String, index_num: int) -> void:
	vessel_id = v_id
	is_mystery = false
	
	if not GameState.VESSEL_CATALOG.has(v_id):
		setup_mystery(index_num)
		return
		
	var v_data = GameState.VESSEL_CATALOG[v_id]
	if index_badge_label:
		index_badge_label.text = str(index_num)
	if title_label:
		title_label.text = v_data["name"].to_upper()
		
	if preview_texture:
		var tex_path = v_data["preview_texture"]
		if ResourceLoader.exists(tex_path):
			preview_texture.texture = load(tex_path)
			preview_texture.modulate = Color.WHITE
			
	if lock_icon:
		lock_icon.visible = false
		
	update_status()

func setup_mystery(index_num: int) -> void:
	vessel_id = "mystery"
	is_mystery = true
	
	if index_badge_label:
		index_badge_label.text = str(index_num)
	if title_label:
		title_label.text = "LOCKED"
		
	if tier_badge:
		tier_badge.visible = false
		
	if preview_texture:
		var sil_path = "res://assets/sprites/user_vessels/mystery_ship_silhouette.svg"
		if ResourceLoader.exists(sil_path):
			preview_texture.texture = load(sil_path)
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
		
	var is_owned = GameState.is_vessel_owned(vessel_id)
	var cur_tier = GameState.get_vessel_tier(vessel_id)
	var is_active = (GameState.active_vessel == vessel_id)
	var v_data = GameState.VESSEL_CATALOG[vessel_id]
	
	# Tier badge
	if tier_badge:
		if is_owned:
			tier_badge.visible = true
			if tier_badge_label:
				tier_badge_label.text = "TIER %d/3" % cur_tier
		else:
			tier_badge.visible = false
			
	# Quick status pill
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
			status_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95, 1))
		if status_icon:
			status_icon.visible = false
	else:
		# Unowned - show price & BUY
		var price = v_data["purchase_price"]
		if status_panel:
			status_panel.add_theme_stylebox_override("panel", style_status_buy)
		if status_label:
			status_label.text = "%d BUY" % price
			status_label.add_theme_color_override("font_color", Color(1, 0.98, 0.9, 1))
		if status_icon:
			status_icon.visible = true
			
	_apply_card_border()

func set_selected(selected: bool) -> void:
	is_selected = selected
	_apply_card_border()

func _apply_card_border() -> void:
	if not style_normal:
		_init_styles()
		
	if is_mystery:
		add_theme_stylebox_override("panel", style_mystery)
	elif is_selected:
		add_theme_stylebox_override("panel", style_selected)
	else:
		add_theme_stylebox_override("panel", style_normal)

func _on_clicked() -> void:
	if is_mystery:
		AudioManager.play_sfx("gate_passes", 0.7, 0.8)
		return
	card_clicked.emit(vessel_id)

func _on_mouse_entered() -> void:
	if not is_selected and not is_mystery:
		var hover_style = style_normal.duplicate() as StyleBoxFlat
		hover_style.border_color = Color(0.85, 0.65, 0.25, 1.0)
		hover_style.shadow_size = 9
		add_theme_stylebox_override("panel", hover_style)

func _on_mouse_exited() -> void:
	_apply_card_border()
