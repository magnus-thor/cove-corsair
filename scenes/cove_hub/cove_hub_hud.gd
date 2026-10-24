class_name CoveHubHUD
extends CanvasLayer

## Top overlay for the Cove Main Hub: doubloon balance, active vessel badge and settings gear.
## Built in code so the 2.5D hub scene stays purely 3D + a single HUD layer.

signal settings_pressed

const FONT_CARTER: FontFile = preload("res://assets/fonts/CarterOne.ttf")
const COIN_ICON: Texture2D = preload("res://assets/sprites/ui/coin_icon.svg")
const PILL_TEXTURE: Texture2D = preload("res://assets/sprites/ui/theme/doubloon_pill.svg")
const GEAR_TEXTURE: Texture2D = preload("res://assets/sprites/ui/theme/gear_button.svg")

var doubloons_label: Label = null
var vessel_label: Label = null
var settings_button: TextureButton = null
var _toast: PanelContainer = null

func _ready() -> void:
	layer = 10
	_build_ui()
	refresh()
	if GameState:
		if not GameState.doubloons_changed.is_connected(_on_doubloons_changed):
			GameState.doubloons_changed.connect(_on_doubloons_changed)
		if not GameState.active_vessel_changed.is_connected(_on_active_vessel_changed):
			GameState.active_vessel_changed.connect(_on_active_vessel_changed)

func _build_ui() -> void:
	var margin: MarginContainer = MarginContainer.new()
	margin.name = "HeaderMargin"
	margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 20)
	add_child(margin)

	var bar: HBoxContainer = HBoxContainer.new()
	bar.name = "TopBar"
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_constant_override("separation", 12)
	margin.add_child(bar)

	# Doubloon pill
	var pill: PanelContainer = PanelContainer.new()
	pill.name = "DoubloonPill"
	pill.custom_minimum_size = Vector2(0, 54)
	var pill_style: StyleBoxTexture = StyleBoxTexture.new()
	pill_style.texture = PILL_TEXTURE
	pill_style.texture_margin_left = 26.0
	pill_style.texture_margin_right = 26.0
	pill_style.texture_margin_top = 8.0
	pill_style.texture_margin_bottom = 8.0
	pill.add_theme_stylebox_override("panel", pill_style)
	bar.add_child(pill)

	var pill_row: HBoxContainer = HBoxContainer.new()
	pill_row.add_theme_constant_override("separation", 8)
	pill_row.alignment = BoxContainer.ALIGNMENT_CENTER
	pill.add_child(pill_row)

	var coin: TextureRect = TextureRect.new()
	coin.texture = COIN_ICON
	coin.custom_minimum_size = Vector2(30, 30)
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pill_row.add_child(coin)

	doubloons_label = Label.new()
	doubloons_label.name = "DoubloonsLabel"
	doubloons_label.add_theme_font_override("font", FONT_CARTER)
	doubloons_label.add_theme_font_size_override("font_size", 18)
	doubloons_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
	doubloons_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	doubloons_label.add_theme_constant_override("shadow_offset_y", 2)
	doubloons_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pill_row.add_child(doubloons_label)

	# Vessel badge
	var badge: PanelContainer = PanelContainer.new()
	badge.name = "VesselBadge"
	badge.custom_minimum_size = Vector2(0, 48)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var badge_style: StyleBoxFlat = StyleBoxFlat.new()
	badge_style.bg_color = Color(0.08, 0.14, 0.22, 0.92)
	badge_style.set_border_width_all(2)
	badge_style.border_color = Color(0.4, 0.75, 0.95, 0.9)
	badge_style.set_corner_radius_all(12)
	badge_style.content_margin_left = 14
	badge_style.content_margin_right = 14
	badge_style.content_margin_top = 4
	badge_style.content_margin_bottom = 4
	badge.add_theme_stylebox_override("panel", badge_style)
	bar.add_child(badge)

	vessel_label = Label.new()
	vessel_label.name = "VesselBadgeLabel"
	vessel_label.add_theme_font_override("font", FONT_CARTER)
	vessel_label.add_theme_font_size_override("font_size", 15)
	vessel_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	vessel_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(vessel_label)

	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(spacer)

	# Settings gear
	settings_button = TextureButton.new()
	settings_button.name = "BtnSettings"
	settings_button.custom_minimum_size = Vector2(46, 46)
	settings_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	settings_button.texture_normal = GEAR_TEXTURE
	settings_button.ignore_texture_size = true
	settings_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	settings_button.pressed.connect(func() -> void: settings_pressed.emit())
	bar.add_child(settings_button)

func refresh() -> void:
	if doubloons_label:
		doubloons_label.text = "%s DOUBLOONS" % _format_number(GameState.doubloons)
	if vessel_label:
		var ship: ShipData = GameState.get_active_ship_resource()
		var ship_title: String = ship.ship_name.to_upper() if ship else "THE DINGHY"
		vessel_label.text = "%s (TIER %d)" % [ship_title, GameState.get_active_ship_tier()]

## Shows a short message near the bottom of the screen that fades out on its own.
func show_toast(message: String) -> void:
	if _toast and is_instance_valid(_toast):
		_toast.queue_free()

	_toast = PanelContainer.new()
	_toast.name = "Toast"
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.07, 0.04, 0.92)
	style.set_border_width_all(2)
	style.border_color = Color(0.96, 0.72, 0.22, 0.95)
	style.set_corner_radius_all(14)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	_toast.add_theme_stylebox_override("panel", style)

	var label: Label = Label.new()
	label.text = message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(380, 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", FONT_CARTER)
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	_toast.add_child(label)
	add_child(_toast)

	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	_toast.position = Vector2((vp_size.x - 420.0) * 0.5, vp_size.y * 0.82)

	var fade: Tween = _toast.create_tween()
	fade.tween_interval(2.0)
	fade.tween_property(_toast, "modulate:a", 0.0, 0.5)
	fade.tween_callback(_toast.queue_free)

func _on_doubloons_changed(_amount: int) -> void:
	refresh()

func _on_active_vessel_changed(_vessel_id: String) -> void:
	refresh()

func _format_number(value: int) -> String:
	var digits: String = str(absi(value))
	var out: String = ""
	var count: int = 0
	for i: int in range(digits.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			out = "," + out
		out = digits[i] + out
		count += 1
	return ("-" if value < 0 else "") + out
