class_name BoardingHUD
extends CanvasLayer

## Tactical HUD for 3-Zone Deck Defense.
## Shows wave progress, zone infestation meters, and control cues.

@onready var label_wave: Label = %LabelWave
@onready var bar_bow: ProgressBar = %BarBow
@onready var bar_mid: ProgressBar = %BarMid
@onready var bar_stern: ProgressBar = %BarStern
@onready var label_bow: Label = %LabelBow
@onready var label_mid: Label = %LabelMid
@onready var label_stern: Label = %LabelStern
@onready var banner: PanelContainer = %Banner
@onready var label_banner: Label = %LabelBanner

func _ready() -> void:
	if is_instance_valid(banner):
		banner.visible = false
	update_wave(1, 3)
	update_zone("bow", 0.0, false)
	update_zone("midship", 0.0, false)
	update_zone("stern", 0.0, false)

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

func show_defeat() -> void:
	if is_instance_valid(banner) and is_instance_valid(label_banner):
		label_banner.text = "FLAGSHIP OVERRUN!"
		label_banner.modulate = Color(1.0, 0.2, 0.2)
		banner.visible = true
