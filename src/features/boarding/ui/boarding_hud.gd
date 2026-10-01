class_name BoardingHUD
extends CanvasLayer

## Tactical HUD for 3-Zone Deck Defense.
## Shows wave progress, zone infestation meters, and crew special attack button.

signal special_attack_requested()

@onready var label_wave: Label = %LabelWave
@onready var bar_bow: ProgressBar = %BarBow
@onready var bar_mid: ProgressBar = %BarMid
@onready var bar_stern: ProgressBar = %BarStern
@onready var label_bow: Label = %LabelBow
@onready var label_mid: Label = %LabelMid
@onready var label_stern: Label = %LabelStern
@onready var banner: PanelContainer = %Banner
@onready var label_banner: Label = %LabelBanner
@onready var button_special: Button = %ButtonSpecial

var _ability_name: String = ""

func _ready() -> void:
	if is_instance_valid(banner):
		banner.visible = false
	if is_instance_valid(button_special):
		button_special.visible = false
		button_special.pressed.connect(_on_special_button_pressed)
	update_wave(1, 3)
	update_zone("bow", 0.0, false)
	update_zone("midship", 0.0, false)
	update_zone("stern", 0.0, false)

func _on_special_button_pressed() -> void:
	special_attack_requested.emit()

func set_special_ability_name(_role_name: String, ability_name: String) -> void:
	_ability_name = ability_name
	if not is_instance_valid(button_special):
		return
	if ability_name.is_empty():
		button_special.visible = false
	else:
		button_special.visible = true
		button_special.text = "SPECIAL: %s" % ability_name.to_upper()

func update_special_cooldown(current_cd: float, _max_cd: float) -> void:
	if not is_instance_valid(button_special) or not button_special.visible:
		return
	if current_cd > 0.05:
		button_special.text = "%s (%.1fs)" % [_ability_name.to_upper(), current_cd]
		button_special.disabled = true
	else:
		button_special.text = "SPECIAL: %s" % _ability_name.to_upper()
		button_special.disabled = false

func update_wave(current: int, total: int) -> void:
	if is_instance_valid(label_wave):
		label_wave.text = "BOARDING DEFENSE — WAVE %d / %d" % [current, total]

func update_zone(zone_id: String, pct: float, is_overrun: bool) -> void:
	var val: float = clampf(pct * 100.0, 0.0, 100.0)
	match zone_id:
		"bow":
			if is_instance_valid(bar_bow):
				bar_bow.value = val
			if is_instance_valid(label_bow):
				label_bow.text = "BOW: %d%% %s" % [int(val), "(OVERRUN!)" if is_overrun else ""]
				label_bow.modulate = Color.RED if is_overrun else Color.WHITE
		"midship":
			if is_instance_valid(bar_mid):
				bar_mid.value = val
			if is_instance_valid(label_mid):
				label_mid.text = "MIDSHIP: %d%% %s" % [int(val), "(OVERRUN!)" if is_overrun else ""]
				label_mid.modulate = Color.RED if is_overrun else Color.WHITE
		"stern":
			if is_instance_valid(bar_stern):
				bar_stern.value = val
			if is_instance_valid(label_stern):
				label_stern.text = "STERN: %d%% %s" % [int(val), "(OVERRUN!)" if is_overrun else ""]
				label_stern.modulate = Color.RED if is_overrun else Color.WHITE

func show_victory() -> void:
	if is_instance_valid(banner) and is_instance_valid(label_banner):
		label_banner.text = "REPUDIATED! ENEMY RETREATED!"
		label_banner.modulate = Color(0.2, 1.0, 0.4)
		banner.visible = true

func show_defeat(reason: String = "FLAGSHIP OVERRUN!") -> void:
	if is_instance_valid(banner) and is_instance_valid(label_banner):
		label_banner.text = reason
		label_banner.modulate = Color(1.0, 0.2, 0.2)
		banner.visible = true
