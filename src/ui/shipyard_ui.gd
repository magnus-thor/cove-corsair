class_name ShipyardUI
extends CanvasLayer

## Shipyard Interface for Cove Corsair
## Handles vessel inspection carousel, purchases, tier upgrades, and equipping active flagship.
## Authentically themed with Dark Oak, Burnished Gold, Ivory text, and Crimson/Green actions.

signal shipyard_closed

@onready var purse_label: Label = %PurseLabel
@onready var btn_prev: Button = %BtnPrev
@onready var btn_next: Button = %BtnNext
@onready var vessel_name_label: Label = %VesselNameLabel
@onready var vessel_archetype_label: Label = %VesselArchetypeLabel
@onready var tier_badge_label: Label = %TierBadgeLabel
@onready var vessel_preview_rect: TextureRect = %VesselPreviewRect
@onready var stat_hp_label: Label = %StatHpLabel
@onready var stat_speed_label: Label = %StatSpeedLabel
@onready var stat_firerate_label: Label = %StatFirerateLabel
@onready var hardpoints_desc_label: Label = %HardpointsDescLabel
@onready var upgrade_preview_box: PanelContainer = %UpgradePreviewBox
@onready var upgrade_preview_label: Label = %UpgradePreviewLabel

@onready var buy_button: Button = %BuyButton
@onready var upgrade_button: Button = %UpgradeButton
@onready var equip_button: Button = %EquipButton
@onready var close_button: Button = %CloseButton

var vessel_ids: Array[String] = ["dinghy", "sloop", "ironclad"]
var current_idx: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	
	# Default carousel index to active vessel
	var active_idx = vessel_ids.find(GameState.active_vessel)
	if active_idx != -1:
		current_idx = active_idx
		
	if btn_prev:
		btn_prev.pressed.connect(_on_prev_pressed)
	if btn_next:
		btn_next.pressed.connect(_on_next_pressed)
	if buy_button:
		buy_button.pressed.connect(_on_buy_pressed)
	if upgrade_button:
		upgrade_button.pressed.connect(_on_upgrade_pressed)
	if equip_button:
		equip_button.pressed.connect(_on_equip_pressed)
	if close_button:
		close_button.pressed.connect(_on_close_pressed)
		
	GameState.doubloons_changed.connect(_on_doubloons_changed)
	_update_display()

func _on_doubloons_changed(_amount: int) -> void:
	_update_display()

func _on_prev_pressed() -> void:
	current_idx = (current_idx - 1 + vessel_ids.size()) % vessel_ids.size()
	AudioManager.play_sfx("gate_passes")
	_update_display()

func _on_next_pressed() -> void:
	current_idx = (current_idx + 1) % vessel_ids.size()
	AudioManager.play_sfx("gate_passes")
	_update_display()

func _update_display() -> void:
	var v_id = vessel_ids[current_idx]
	var v_info = GameState.VESSEL_CATALOG[v_id]
	var is_owned = GameState.is_vessel_owned(v_id)
	var cur_tier = GameState.get_vessel_tier(v_id)
	var is_active = (GameState.active_vessel == v_id)
	
	if purse_label:
		purse_label.text = "%d DOUBLOONS" % GameState.doubloons
		
	if vessel_name_label:
		vessel_name_label.text = v_info["name"].to_upper()
	if vessel_archetype_label:
		vessel_archetype_label.text = v_info["archetype"].to_upper()
		
	if tier_badge_label:
		if is_owned:
			if cur_tier >= 3:
				tier_badge_label.text = "TIER 3 / 3 (MAX MASTERED)"
				tier_badge_label.add_theme_color_override("font_color", Color(0.98, 0.82, 0.28, 1))
			else:
				tier_badge_label.text = "TIER %d / 3" % cur_tier
				tier_badge_label.add_theme_color_override("font_color", Color(0.96, 0.93, 0.86, 1))
		else:
			tier_badge_label.text = "UNACQUIRED"
			tier_badge_label.add_theme_color_override("font_color", Color(0.85, 0.45, 0.45, 1))
			
	if vessel_preview_rect:
		var tex_path = v_info["preview_texture"]
		if ResourceLoader.exists(tex_path):
			vessel_preview_rect.texture = load(tex_path)
			
	if stat_hp_label:
		stat_hp_label.text = "Hull: %d HP" % v_info["base_hp"]
	if stat_speed_label:
		stat_speed_label.text = "Speed: %.1f m/s" % v_info["base_speed"]
	if stat_firerate_label:
		stat_firerate_label.text = "Reload: %.2fs" % v_info["fire_rate"]
		
	if hardpoints_desc_label:
		var tier_desc = v_info["tier_descriptions"].get(cur_tier if is_owned else 1, "")
		hardpoints_desc_label.text = "Armed: " + tier_desc
		
	# Upgrade Preview
	if is_owned and cur_tier < 3:
		var next_tier = cur_tier + 1
		var next_desc = v_info["tier_descriptions"].get(next_tier, "")
		var upgrade_cost = GameState.get_upgrade_cost(v_id, next_tier)
		if upgrade_preview_box:
			upgrade_preview_box.visible = true
		if upgrade_preview_label:
			upgrade_preview_label.text = "Tier %d Blueprint: %s (%d Doubloons)" % [next_tier, next_desc, upgrade_cost]
	else:
		if upgrade_preview_box:
			upgrade_preview_box.visible = (is_owned and cur_tier >= 3)
		if upgrade_preview_label:
			upgrade_preview_label.text = "All Flagship Hardpoints Mastered (Tier 3 Max)"
			
	# Action Buttons Configuration
	if not is_owned:
		if buy_button:
			buy_button.visible = true
			var cost = v_info["purchase_price"]
			buy_button.text = "BUY VESSEL: %d DOUBLOONS" % cost
			buy_button.disabled = not GameState.can_afford(cost)
		if upgrade_button:
			upgrade_button.visible = false
		if equip_button:
			equip_button.visible = false
	else:
		if buy_button:
			buy_button.visible = false
			
		# Upgrade Button
		if upgrade_button:
			upgrade_button.visible = true
			if cur_tier < 3:
				var next_tier = cur_tier + 1
				var cost = GameState.get_upgrade_cost(v_id, next_tier)
				upgrade_button.text = "UPGRADE TIER %d: %d DOUBLOONS" % [next_tier, cost]
				upgrade_button.disabled = not GameState.can_afford(cost)
			else:
				upgrade_button.text = "MAX TIER MASTERED"
				upgrade_button.disabled = true
				
		# Equip Button
		if equip_button:
			equip_button.visible = true
			if is_active:
				equip_button.text = "EQUIPPED FLAGSHIP ✓"
				equip_button.disabled = true
			else:
				equip_button.text = "SELECT AS FLAGSHIP"
				equip_button.disabled = false

func _on_buy_pressed() -> void:
	var v_id = vessel_ids[current_idx]
	if GameState.buy_vessel(v_id):
		AudioManager.play_sfx("coin_pickups", 1.0, 1.2)
		AudioManager.play_sfx("barrel_hits")
		_update_display()

func _on_upgrade_pressed() -> void:
	var v_id = vessel_ids[current_idx]
	if GameState.upgrade_vessel_tier(v_id):
		AudioManager.play_sfx("coin_pickups", 1.1, 1.3)
		AudioManager.play_sfx("gate_passes")
		_update_display()

func _on_equip_pressed() -> void:
	var v_id = vessel_ids[current_idx]
	if GameState.equip_vessel(v_id):
		AudioManager.play_sfx("coin_pickups", 1.0, 1.2)
		_update_display()

func _on_close_pressed() -> void:
	AudioManager.play_sfx("gate_passes")
	shipyard_closed.emit()
	queue_free()
