class_name HarborCalibrationPanel
extends PanelContainer

## Real-time calibration overlay for tuning how vessels sit docked in Smuggler's Cove harbor.
## Adjusts pitch, yaw, roll, waterline elevation, scale multiplier, and horizontal offsets.

signal config_changed(ship_id: String, config: Dictionary)
signal vessel_switch_requested(ship_id: String)
signal panel_closed

@onready var btn_dinghy: Button = %BtnDinghy as Button
@onready var btn_sloop: Button = %BtnSloop as Button
@onready var btn_ironclad: Button = %BtnIronclad as Button
@onready var btn_bombard: Button = %BtnBombard as Button

@onready var slider_pitch: HSlider = %SliderPitch as HSlider
@onready var slider_yaw: HSlider = %SliderYaw as HSlider
@onready var slider_roll: HSlider = %SliderRoll as HSlider
@onready var slider_waterline: HSlider = %SliderWaterline as HSlider
@onready var slider_scale: HSlider = %SliderScale as HSlider
@onready var slider_offset_x: HSlider = %SliderOffsetX as HSlider
@onready var slider_offset_z: HSlider = %SliderOffsetZ as HSlider

@onready var label_pitch_val: Label = %LabelPitchVal as Label
@onready var label_yaw_val: Label = %LabelYawVal as Label
@onready var label_roll_val: Label = %LabelRollVal as Label
@onready var label_waterline_val: Label = %LabelWaterlineVal as Label
@onready var label_scale_val: Label = %LabelScaleVal as Label
@onready var label_offset_x_val: Label = %LabelOffsetXVal as Label
@onready var label_offset_z_val: Label = %LabelOffsetZVal as Label

@onready var btn_print: Button = %BtnPrint as Button
@onready var btn_close: Button = %BtnClose as Button
@onready var status_label: Label = %StatusLabel as Label

var current_ship_id: String = "sloop"
var configs: Dictionary = {}
var _is_updating_sliders: bool = false

func _ready() -> void:
	_connect_signals()

func setup_configs(p_configs: Dictionary, active_ship_id: String) -> void:
	configs = p_configs.duplicate(true)
	current_ship_id = active_ship_id
	_highlight_active_vessel_btn()
	_load_ship_config_to_sliders(current_ship_id)

func _connect_signals() -> void:
	if btn_dinghy:
		btn_dinghy.pressed.connect(func() -> void: _select_vessel("dinghy"))
	if btn_sloop:
		btn_sloop.pressed.connect(func() -> void: _select_vessel("sloop"))
	if btn_ironclad:
		btn_ironclad.pressed.connect(func() -> void: _select_vessel("ironclad"))
	if btn_bombard:
		btn_bombard.pressed.connect(func() -> void: _select_vessel("bombard_skiff"))

	if slider_pitch:
		slider_pitch.value_changed.connect(_on_slider_value_changed)
	if slider_yaw:
		slider_yaw.value_changed.connect(_on_slider_value_changed)
	if slider_roll:
		slider_roll.value_changed.connect(_on_slider_value_changed)
	if slider_waterline:
		slider_waterline.value_changed.connect(_on_slider_value_changed)
	if slider_scale:
		slider_scale.value_changed.connect(_on_slider_value_changed)
	if slider_offset_x:
		slider_offset_x.value_changed.connect(_on_slider_value_changed)
	if slider_offset_z:
		slider_offset_z.value_changed.connect(_on_slider_value_changed)

	if btn_print:
		btn_print.pressed.connect(_on_print_pressed)
	if btn_close:
		btn_close.pressed.connect(_on_close_pressed)

func _select_vessel(ship_id: String) -> void:
	current_ship_id = ship_id
	_highlight_active_vessel_btn()
	_load_ship_config_to_sliders(ship_id)
	vessel_switch_requested.emit(ship_id)

func _highlight_active_vessel_btn() -> void:
	var btn_map: Dictionary = {
		"dinghy": btn_dinghy,
		"sloop": btn_sloop,
		"ironclad": btn_ironclad,
		"bombard_skiff": btn_bombard
	}
	for s_id: String in btn_map:
		var b: Button = btn_map[s_id] as Button
		if is_instance_valid(b):
			b.modulate = Color(1.0, 0.85, 0.3, 1.0) if s_id == current_ship_id else Color(0.7, 0.7, 0.7, 0.8)

func _load_ship_config_to_sliders(ship_id: String) -> void:
	_is_updating_sliders = true
	var cfg: Dictionary = configs.get(ship_id, {}) as Dictionary

	var pitch: float = float(cfg.get("pitch", 0.0))
	var yaw: float = float(cfg.get("yaw", -115.0))
	var roll: float = float(cfg.get("roll", 0.0))
	var waterline: float = float(cfg.get("waterline_y", 0.40))
	var sc: float = float(cfg.get("scale_mult", 0.65))
	var off_x: float = float(cfg.get("offset_x", 0.0))
	var off_z: float = float(cfg.get("offset_z", 0.0))

	if slider_pitch: slider_pitch.value = pitch
	if slider_yaw: slider_yaw.value = yaw
	if slider_roll: slider_roll.value = roll
	if slider_waterline: slider_waterline.value = waterline
	if slider_scale: slider_scale.value = sc
	if slider_offset_x: slider_offset_x.value = off_x
	if slider_offset_z: slider_offset_z.value = off_z

	_update_labels(pitch, yaw, roll, waterline, sc, off_x, off_z)
	_is_updating_sliders = false

func _update_labels(p: float, y: float, r: float, w: float, s: float, ox: float, oz: float) -> void:
	if label_pitch_val: label_pitch_val.text = "%.1f°" % p
	if label_yaw_val: label_yaw_val.text = "%.1f°" % y
	if label_roll_val: label_roll_val.text = "%.1f°" % r
	if label_waterline_val: label_waterline_val.text = "%.2fm" % w
	if label_scale_val: label_scale_val.text = "%.2fx" % s
	if label_offset_x_val: label_offset_x_val.text = "%.2fm" % ox
	if label_offset_z_val: label_offset_z_val.text = "%.2fm" % oz

func _on_slider_value_changed(_val: float) -> void:
	if _is_updating_sliders:
		return

	var p: float = slider_pitch.value if slider_pitch else 0.0
	var y: float = slider_yaw.value if slider_yaw else -115.0
	var r: float = slider_roll.value if slider_roll else 0.0
	var w: float = slider_waterline.value if slider_waterline else 0.40
	var s: float = slider_scale.value if slider_scale else 0.65
	var ox: float = slider_offset_x.value if slider_offset_x else 0.0
	var oz: float = slider_offset_z.value if slider_offset_z else 0.0

	_update_labels(p, y, r, w, s, ox, oz)

	var new_cfg: Dictionary = {
		"pitch": p,
		"yaw": y,
		"roll": r,
		"waterline_y": w,
		"scale_mult": s,
		"offset_x": ox,
		"offset_z": oz
	}
	configs[current_ship_id] = new_cfg
	config_changed.emit(current_ship_id, new_cfg)

func _on_print_pressed() -> void:
	print("==================================================")
	print("       HARBOR DOCK CONFIGS (COPY-PASTE READY)     ")
	print("==================================================")
	print("const HARBOR_DOCK_CONFIGS: Dictionary = {")
	for s_id: String in configs:
		var c: Dictionary = configs[s_id] as Dictionary
		print("\t\"%s\": {" % s_id)
		print("\t\t\"pitch\": %.2f," % float(c.get("pitch", 0.0)))
		print("\t\t\"yaw\": %.2f," % float(c.get("yaw", -115.0)))
		print("\t\t\"roll\": %.2f," % float(c.get("roll", 0.0)))
		print("\t\t\"waterline_y\": %.3f," % float(c.get("waterline_y", 0.40)))
		print("\t\t\"scale_mult\": %.3f," % float(c.get("scale_mult", 0.65)))
		print("\t\t\"offset_x\": %.3f," % float(c.get("offset_x", 0.0)))
		print("\t\t\"offset_z\": %.3f," % float(c.get("offset_z", 0.0)))
		print("\t},")
	print("}")
	print("==================================================")

	if status_label:
		status_label.text = "✓ Config printed to Output console!"
		var t := create_tween()
		t.tween_interval(2.5)
		t.tween_property(status_label, "text", "", 0.3)

func _on_close_pressed() -> void:
	panel_closed.emit()
	visible = false
