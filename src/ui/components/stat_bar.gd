class_name UIStatBar
extends HBoxContainer

## Reusable stat bar component for the Shipyard comparison inspector.
## Displays: Stat Name | ProgressBar | Value | Comparative Delta (optional)
## Call set_stat() after adding to the scene tree.

@onready var stat_name_label: Label = %StatNameLabel
@onready var progress_bar: ProgressBar = %StatProgressBar
@onready var value_label: Label = %StatValueLabel
@onready var delta_label: Label = %StatDeltaLabel

# Bar fill colour — set before adding to scene or call set_bar_color() afterwards
var bar_color: Color = Color("#38BDF8")

## Configure the stat bar.
##   stat_name    — displayed on the left label (e.g. "Hull Armor")
##   current_val  — raw stat value for the inspected vessel
##   max_val      — normalisation ceiling (e.g. 100.0)
##   baseline_val — raw stat value for the currently-equipped vessel; pass -1.0 to hide delta
##   suffix       — appended to the value label (e.g. " HP", " m/s")
func set_stat(stat_name: String, current_val: float, max_val: float,
		baseline_val: float = -1.0, suffix: String = "") -> void:
	if stat_name_label:
		stat_name_label.text = stat_name

	var pct: float = clampf(current_val / maxf(max_val, 1.0) * 100.0, 0.0, 100.0)
	if progress_bar:
		progress_bar.value = pct
		_apply_bar_color()

	if value_label:
		value_label.text = "%.0f%s" % [current_val, suffix]

	if delta_label:
		if baseline_val >= 0.0 and not is_equal_approx(current_val, baseline_val):
			var delta: float = current_val - baseline_val
			var sign_str: String = "+" if delta > 0.0 else ""
			delta_label.text = "%s%.0f" % [sign_str, delta]
			if delta > 0.0:
				delta_label.add_theme_color_override("font_color", Color("#4ADE80"))
			else:
				delta_label.add_theme_color_override("font_color", Color("#F87171"))
			delta_label.visible = true
		else:
			delta_label.visible = false

## Override the progress bar fill colour at runtime.
func set_bar_color(color: Color) -> void:
	bar_color = color
	_apply_bar_color()

func _apply_bar_color() -> void:
	if not progress_bar:
		return
	var fill_style: StyleBoxFlat = StyleBoxFlat.new()
	fill_style.bg_color = bar_color
	fill_style.corner_radius_top_left = 4
	fill_style.corner_radius_top_right = 4
	fill_style.corner_radius_bottom_right = 4
	fill_style.corner_radius_bottom_left = 4
	progress_bar.add_theme_stylebox_override("fill", fill_style)
