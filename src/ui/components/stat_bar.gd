class_name UIStatBar
extends HBoxContainer

## Reusable stat bar component for the Shipyard comparison inspector.
## Displays: Stat Icon | Stat Name | ProgressBar (with % value) | Delta Badge
## Fully statically typed.

@onready var stat_icon: TextureRect = %StatIcon
@onready var stat_name_label: Label = %StatNameLabel
@onready var progress_bar: ProgressBar = %StatProgressBar
@onready var value_label: Label = %StatValueLabel
@onready var delta_panel: PanelContainer = %DeltaPanel
@onready var delta_arrow_label: Label = %DeltaArrowLabel
@onready var delta_number_label: Label = %DeltaNumberLabel

# Bar fill colour — set before adding to scene or call set_bar_color() afterwards
var bar_color: Color = Color("#38BDF8")

# StyleBoxes for Delta Badge
var _style_delta_pos: StyleBoxFlat
var _style_delta_neg: StyleBoxFlat

func _ready() -> void:
	_init_delta_styles()
	_apply_bar_color()

func _init_delta_styles() -> void:
	_style_delta_pos = StyleBoxFlat.new()
	_style_delta_pos.bg_color = Color(0.08, 0.22, 0.12, 0.85)
	_style_delta_pos.border_width_left = 1
	_style_delta_pos.border_width_top = 1
	_style_delta_pos.border_width_right = 1
	_style_delta_pos.border_width_bottom = 1
	_style_delta_pos.border_color = Color(0.29, 0.87, 0.50, 0.8)
	_style_delta_pos.corner_radius_top_left = 6
	_style_delta_pos.corner_radius_top_right = 6
	_style_delta_pos.corner_radius_bottom_right = 6
	_style_delta_pos.corner_radius_bottom_left = 6

	_style_delta_neg = StyleBoxFlat.new()
	_style_delta_neg.bg_color = Color(0.28, 0.10, 0.10, 0.85)
	_style_delta_neg.border_width_left = 1
	_style_delta_neg.border_width_top = 1
	_style_delta_neg.border_width_right = 1
	_style_delta_neg.border_width_bottom = 1
	_style_delta_neg.border_color = Color(0.97, 0.44, 0.44, 0.8)
	_style_delta_neg.corner_radius_top_left = 6
	_style_delta_neg.corner_radius_top_right = 6
	_style_delta_neg.corner_radius_bottom_right = 6
	_style_delta_neg.corner_radius_bottom_left = 6

func set_icon(texture: Texture2D) -> void:
	if stat_icon:
		stat_icon.texture = texture
		stat_icon.visible = (texture != null)

## Configure the stat bar.
##   stat_name    — displayed on the left label (e.g. "ARMOR")
##   current_val  — raw stat value for the inspected vessel
##   max_val      — normalisation ceiling (e.g. 100.0)
##   baseline_val — raw stat value for the currently-equipped vessel; pass -1.0 to hide delta
##   suffix       — appended to the value label (e.g. "%", " HP", " m/s")
func set_stat(stat_name: String, current_val: float, max_val: float,
		baseline_val: float = -1.0, suffix: String = "") -> void:
	if stat_name_label:
		stat_name_label.text = stat_name

	var pct: float = clampf(current_val / maxf(max_val, 1.0) * 100.0, 0.0, 100.0)
	if progress_bar:
		progress_bar.value = pct
		_apply_bar_color()

	if value_label:
		# If suffix is "%" or not provided, show integer percentage matching mockup
		if suffix == "%" or suffix.is_empty():
			value_label.text = "%.0f%%" % pct
		elif suffix == " m/s" or not is_equal_approx(current_val, roundf(current_val)):
			value_label.text = "%.1f%s" % [current_val, suffix]
		else:
			value_label.text = "%.0f%s" % [current_val, suffix]

	if delta_panel and delta_arrow_label and delta_number_label:
		if _style_delta_pos == null:
			_init_delta_styles()
			
		if baseline_val >= 0.0 and not is_equal_approx(current_val, baseline_val):
			var delta: float = current_val - baseline_val
			var sign_str: String = "+" if delta > 0.0 else ""
			var num_str: String = ""
			if suffix == " m/s" or not is_equal_approx(delta, roundf(delta)):
				num_str = "%s%.1f" % [sign_str, delta]
			else:
				num_str = "%s%.0f" % [sign_str, delta]
				
			delta_number_label.text = num_str
			delta_panel.visible = true

			if delta > 0.0:
				delta_arrow_label.text = "▲"
				delta_arrow_label.add_theme_color_override("font_color", Color("#4ADE80"))
				delta_number_label.add_theme_color_override("font_color", Color("#4ADE80"))
				delta_panel.add_theme_stylebox_override("panel", _style_delta_pos)
			else:
				delta_arrow_label.text = "▼"
				delta_arrow_label.add_theme_color_override("font_color", Color("#F87171"))
				delta_number_label.add_theme_color_override("font_color", Color("#F87171"))
				delta_panel.add_theme_stylebox_override("panel", _style_delta_neg)
		else:
			delta_panel.visible = false

## Override the progress bar fill colour at runtime.
func set_bar_color(color: Color) -> void:
	bar_color = color
	_apply_bar_color()

func _apply_bar_color() -> void:
	if not progress_bar:
		return
	var fill_style: StyleBoxFlat = StyleBoxFlat.new()
	fill_style.bg_color = bar_color
	fill_style.corner_radius_top_left = 6
	fill_style.corner_radius_top_right = 6
	fill_style.corner_radius_bottom_right = 6
	fill_style.corner_radius_bottom_left = 6
	progress_bar.add_theme_stylebox_override("fill", fill_style)
