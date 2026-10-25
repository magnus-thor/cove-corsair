class_name SettlementScreen
extends CanvasLayer

## Responsive Settlement Screen Overlay Modal for Cove Corsair
## Handles both Victory and Defeat ("SHIP SUNK!") with gold retention roll-up count,
## completion bonus breakdown, shipyard upgrade badge/glow alert, and seamless navigation.

signal retry_requested
signal next_level_requested
signal map_requested

@onready var backdrop: ColorRect = %Backdrop
@onready var modal_panel: PanelContainer = %ModalPanel
@onready var header_label: Label = %HeaderLabel
@onready var subtitle_label: Label = %SubtitleLabel

@onready var stars_container: HBoxContainer = %StarsContainer
@onready var star_1: Label = %Star1
@onready var star_2: Label = %Star2
@onready var star_3: Label = %Star3

@onready var run_doubloons_label: Label = %RunDoubloonsLabel
@onready var bonus_row: HBoxContainer = %BonusRow
@onready var bonus_label: Label = %BonusLabel
@onready var total_banked_label: Label = %TotalBankedLabel
@onready var run_spoils_label: Label = %TotalBankedLabel
@onready var vault_balance_label: Label = get_node_or_null("%VaultBalanceLabel")

@onready var primary_button: Button = %PrimaryButton
@onready var endless_button: Button = get_node_or_null("%EndlessButton") as Button
@onready var bonus_claim_button: Button = %BonusClaimButton
@onready var shipyard_button: Button = %ShipyardButton
@onready var shipyard_badge: PanelContainer = %ShipyardBadge
@onready var shipyard_badge_label: Label = %ShipyardBadgeLabel
@onready var map_button: Button = %MapButton
@onready var copy_telemetry_button: Button = get_node_or_null("%CopyTelemetryButton")

var _is_victory: bool = false
var _is_extraction: bool = false
var _extracted_distance: int = 0
var _extracted_multiplier: float = 1.0
var _bonus_claimed: bool = false
var _run_doubloons: int = 0
var _completion_bonus: int = 0
var _banked_this_run: int = 0
var _total_banked: int = 0
var _stars_earned: int = 1

var _tally_tween: Tween = null
var _glow_tween: Tween = null
var _badge_tween: Tween = null
var _modal_tween: Tween = null

const COLOR_VICTORY_HEADER := Color(1.0, 0.84, 0.22, 1.0) # Radiant Gold
const COLOR_DEFEAT_HEADER := Color(0.92, 0.22, 0.24, 1.0) # Crimson Red
const COLOR_STAR_ACTIVE := Color(1.0, 0.85, 0.15, 1.0)
const COLOR_STAR_INACTIVE := Color(0.40, 0.35, 0.30, 1.0)
const GUIDANCE_SCENE: PackedScene = preload("res://src/ui/tutorial/tutorial_guidance_overlay.tscn")

var _tutorial_overlay: TutorialGuidanceOverlay = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 25
	visible = false

	if primary_button:
		primary_button.pressed.connect(_on_primary_pressed)
	if endless_button:
		endless_button.pressed.connect(_on_endless_pressed)
	if bonus_claim_button:
		bonus_claim_button.pressed.connect(_on_bonus_claim_pressed)
	if shipyard_button:
		shipyard_button.pressed.connect(_on_shipyard_pressed)
	if map_button:
		map_button.pressed.connect(_on_map_pressed)
	if copy_telemetry_button:
		copy_telemetry_button.pressed.connect(_on_copy_telemetry_pressed)

	if GameState and GameState.has_signal("doubloons_changed"):
		if not GameState.doubloons_changed.is_connected(_on_doubloons_changed):
			GameState.doubloons_changed.connect(_on_doubloons_changed)

func show_defeat(coins_collected: int, _distance_reached: float, banked_total: int) -> void:
	_is_victory = false
	_is_extraction = false
	_run_doubloons = coins_collected
	_completion_bonus = 0
	_banked_this_run = coins_collected
	_total_banked = banked_total
	_stars_earned = 0
	if GameState:
		GameState.first_loss_occurred = true
		GameState.save_game()
	print("[LEVEL END] River Level %d DEFEAT | In-Run Coins Saved: %d 🪙 | Vault Total: %d 🪙" % [
		GameState.current_level,
		coins_collected,
		banked_total
	])
	_present_modal()

func show_victory(coins_collected: int, completion_bonus: int, banked_total: int, stars: int = 3) -> void:
	_is_victory = true
	_is_extraction = false
	_run_doubloons = coins_collected
	_completion_bonus = completion_bonus
	_banked_this_run = coins_collected + completion_bonus
	_total_banked = banked_total
	_stars_earned = clamp(stars, 1, 3)
	
	print("[LEVEL COMPLETE] River Level %d VICTORY! | In-Run Coins: %d | Clear Bonus: %d | Total Earned: %d 🪙 | Vault Total: %d 🪙" % [
		GameState.current_level,
		coins_collected,
		completion_bonus,
		coins_collected + completion_bonus,
		banked_total
	])
	
	var cleared_lvl: int = GameState.current_level
	
	# Record high score, star mastery, and unlock next level
	GameState.record_level_score(cleared_lvl, coins_collected + completion_bonus)
	GameState.record_level_stars(cleared_lvl, _stars_earned)
	GameState.unlock_next_level()

	# Tutorial Progression Advancements
	if GameState.is_tutorial_in_progress():
		match cleared_lvl:
			1:
				GameState.advance_tutorial_to(GameState.TutorialStep.LEVEL_1_COMPLETED)
			2:
				GameState.advance_tutorial_to(GameState.TutorialStep.LEVEL_2_COMPLETED)
			3:
				GameState.advance_tutorial_to(GameState.TutorialStep.LEVEL_3_COMPLETED)
			4:
				GameState.advance_tutorial_to(GameState.TutorialStep.LEVEL_4_COMPLETED)
			5:
				GameState.advance_tutorial_to(GameState.TutorialStep.COMPLETED)
	
	_present_modal()

func show_extraction(distance_reached: int, doubloons_banked: int, total_banked: int, multiplier_reached: float) -> void:
	_is_victory = true
	_is_extraction = true
	_extracted_distance = distance_reached
	_extracted_multiplier = multiplier_reached
	_run_doubloons = doubloons_banked
	_completion_bonus = 0
	_banked_this_run = doubloons_banked
	_total_banked = total_banked
	_stars_earned = 0
	print("[GAUNTLET EXTRACTED] River Level %d | Distance: %dm (%.1fx) | Coins Banked: %d 🪙 | Vault Total: %d 🪙" % [
		GameState.current_level,
		distance_reached,
		multiplier_reached,
		doubloons_banked,
		total_banked
	])
	_present_modal()

func _present_modal() -> void:
	visible = true
	get_tree().paused = true
	if GameState:
		GameState.is_game_active = false
		GameState.set_performance_mode(false)

	# 1. Setup Header & Subtitle
	if _is_extraction:
		if header_label:
			header_label.text = "⚓ SAFE HARBOR REACHED!"
			header_label.add_theme_color_override("font_color", Color(0.20, 0.96, 0.65, 1.0))
		if subtitle_label:
			subtitle_label.text = "CORSAIR GAUNTLET EXTRACTED • %dm VOYAGE • %.1fx MULTIPLIER" % [_extracted_distance, _extracted_multiplier]
			subtitle_label.add_theme_color_override("font_color", Color(0.80, 0.98, 0.90, 1.0))
		if modal_panel:
			var panel_style: StyleBox = modal_panel.get_theme_stylebox("panel")
			if panel_style is StyleBoxFlat:
				var flat: StyleBoxFlat = (panel_style as StyleBoxFlat).duplicate() as StyleBoxFlat
				flat.border_color = Color(0.18, 0.92, 0.65, 1.0)
				modal_panel.add_theme_stylebox_override("panel", flat)
		if stars_container:
			stars_container.visible = false
		if bonus_row:
			bonus_row.visible = false
		if bonus_claim_button:
			bonus_claim_button.visible = false
		if primary_button:
			primary_button.text = "SAIL AGAIN (GAUNTLET)"
		if map_button:
			map_button.text = "RETURN TO HARBOR"
	elif _is_victory:
		if modal_panel:
			var panel_style: StyleBox = modal_panel.get_theme_stylebox("panel")
			if panel_style is StyleBoxFlat:
				var flat: StyleBoxFlat = (panel_style as StyleBoxFlat).duplicate() as StyleBoxFlat
				flat.border_color = Color(0.82, 0.65, 0.32, 1.0)
				modal_panel.add_theme_stylebox_override("panel", flat)
		if header_label:
			header_label.text = "VICTORY!"
			header_label.add_theme_color_override("font_color", COLOR_VICTORY_HEADER)
		if subtitle_label:
			subtitle_label.text = "COVE CONQUERED - CARGO SECURED!"
			subtitle_label.add_theme_color_override("font_color", Color(0.85, 0.95, 0.85, 1.0))
		if stars_container:
			stars_container.visible = true
			_update_stars(_stars_earned)
		if bonus_row:
			bonus_row.visible = true
			if bonus_label:
				bonus_label.text = "+0"
		if primary_button:
			if GameState.is_campaign_complete():
				primary_button.text = "MAP COMPLETE"
				primary_button.visible = true
			elif GameState.is_tutorial_in_progress() and GameState.last_cleared_level in [2, 3]:
				primary_button.visible = false
			else:
				primary_button.text = "NEXT LEVEL"
				primary_button.visible = true
		_bonus_claimed = false
		if endless_button:
			endless_button.visible = false
		if bonus_claim_button:
			bonus_claim_button.visible = true
			bonus_claim_button.disabled = false
			if GameState and not GameState.has_used_free_double:
				bonus_claim_button.text = "✦ CLAIM FREE 2X BONUS DOUBLOONS"
			else:
				bonus_claim_button.text = "🎬 WATCH AD FOR 2X DOUBLOONS"
		if map_button:
			if GameState.is_tutorial_in_progress() and GameState.last_cleared_level in [2, 3, 4]:
				map_button.text = "RETURN TO COVE"
			else:
				map_button.text = "LEVEL MAP"
	else:
		if header_label:
			header_label.text = "SHIP SUNK!"
			header_label.add_theme_color_override("font_color", COLOR_DEFEAT_HEADER)
		if subtitle_label:
			var cur_lvl: int = GameState.current_level if GameState else 1
			if cur_lvl in [8, 15, 22, 30, 37, 44]:
				subtitle_label.text = "GATEKEEPER CHALLENGE • UPGRADE VESSEL AT SHIPYARD"
			else:
				subtitle_label.text = "HULL BREACHED - TREASURE RETAINED"
			subtitle_label.add_theme_color_override("font_color", Color(0.95, 0.8, 0.8, 1.0))
		if stars_container:
			stars_container.visible = false
		if bonus_row:
			bonus_row.visible = false
		if bonus_claim_button:
			bonus_claim_button.visible = false
		if endless_button:
			var show_endless: bool = GameState.current_level >= 3 if GameState else true
			endless_button.visible = show_endless
		if primary_button:
			primary_button.text = "RETRY"
		if map_button:
			map_button.text = "LEVEL MAP"

	# 2. Setup initial counters
	if run_doubloons_label:
		run_doubloons_label.text = "0"
	if total_banked_label:
		total_banked_label.text = "0"
	_update_vault_balance_display()

	# 3. Check shipyard upgrade affordance
	_update_shipyard_button()

	# 4. Animate Pop-in
	_animate_open()

	# 5. Roll-up count animation
	_animate_breakdown(_run_doubloons, _completion_bonus, _banked_this_run)
	_check_tutorial_guidance()

func _animate_open() -> void:
	if _modal_tween and _modal_tween.is_valid():
		_modal_tween.kill()

	_modal_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_modal_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	if backdrop:
		backdrop.color.a = 0.0
		_modal_tween.tween_property(backdrop, "color:a", 0.85, 0.3)

	if modal_panel:
		modal_panel.pivot_offset = modal_panel.size * 0.5
		modal_panel.scale = Vector2(0.7, 0.7)
		modal_panel.modulate.a = 0.0
		_modal_tween.tween_property(modal_panel, "scale", Vector2.ONE, 0.4)
		_modal_tween.tween_property(modal_panel, "modulate:a", 1.0, 0.3)

func _animate_breakdown(run_coins: int, bonus: int, final_run_bank: int) -> void:
	if _tally_tween and _tally_tween.is_valid():
		_tally_tween.kill()

	_tally_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tally_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

	var tracker: Dictionary = {"last_tick": -1}
	var step_chunk: int = max(1, int(float(run_coins) / 12.0))
	
	_tally_tween.tween_method(func(val: float) -> void:
		var cur: int = int(val)
		if run_doubloons_label:
			run_doubloons_label.text = str(cur)
		if cur != int(tracker["last_tick"]) and (cur % step_chunk == 0 or cur == run_coins):
			tracker["last_tick"] = cur
			if AudioManager and AudioManager.has_method("play_sfx") and cur > 0:
				AudioManager.play_sfx("coin_pickups", 0.95 + float(cur) / max(1.0, float(run_coins)) * 0.35, 1.05 + float(cur) / max(1.0, float(run_coins)) * 0.35, 0.5)
	, 0.0, float(run_coins), 0.75)

	if _is_victory and bonus > 0:
		_tally_tween.tween_method(func(val: float) -> void:
			if bonus_label:
				bonus_label.text = "+%d" % int(val)
		, 0.0, float(bonus), 0.75)

	_tally_tween.tween_method(func(val: float) -> void:
		if total_banked_label:
			total_banked_label.text = str(int(val))
	, 0.0, float(final_run_bank), 0.85)

func _update_stars(count: int) -> void:
	var stars: Array[Label] = [star_1, star_2, star_3]
	for i: int in range(stars.size()):
		var s: Label = stars[i]
		if not s:
			continue
		if i < count:
			s.add_theme_color_override("font_color", COLOR_STAR_ACTIVE)
		else:
			s.add_theme_color_override("font_color", COLOR_STAR_INACTIVE)

func _update_shipyard_button() -> void:
	if not shipyard_button:
		return

	# During tutorial levels 1 & 2, shipyard is completely locked & hidden
	if GameState and GameState.is_tutorial_in_progress() and GameState.highest_unlocked_level <= 2:
		shipyard_button.visible = false
		if shipyard_badge:
			shipyard_badge.visible = false
		return
	shipyard_button.visible = true

	var can_afford: bool = GameState.can_afford_active_vessel_upgrade()

	if _glow_tween and _glow_tween.is_valid():
		_glow_tween.kill()
	if _badge_tween and _badge_tween.is_valid():
		_badge_tween.kill()

	if can_afford:
		if shipyard_badge:
			shipyard_badge.visible = true
			shipyard_badge.pivot_offset = shipyard_badge.size * 0.5
			_badge_tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			_badge_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			_badge_tween.tween_property(shipyard_badge, "scale", Vector2(1.15, 1.15), 0.45)
			_badge_tween.tween_property(shipyard_badge, "scale", Vector2.ONE, 0.45)

		_glow_tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_glow_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_glow_tween.tween_property(shipyard_button, "modulate", Color(1.35, 1.25, 0.70, 1.0), 0.5)
		_glow_tween.tween_property(shipyard_button, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.5)
	else:
		if shipyard_badge:
			shipyard_badge.visible = false
		shipyard_button.modulate = Color.WHITE

func _update_vault_balance_display() -> void:
	if vault_balance_label and GameState:
		vault_balance_label.text = str(GameState.doubloons)

func _on_doubloons_changed(_new_amt: int) -> void:
	_update_vault_balance_display()
	_update_shipyard_button()

func _refresh_banked_display() -> void:
	_total_banked = GameState.doubloons
	_update_vault_balance_display()
	# Banked This Run label remains strictly cached and never mutates when spending in shipyard!

func _on_bonus_claim_pressed() -> void:
	if _bonus_claimed or not _is_victory:
		return
	_bonus_claimed = true
	
	if bonus_claim_button:
		bonus_claim_button.disabled = true
		bonus_claim_button.text = "BONUS CLAIMED! ✦"
		
	var bonus_amount: int = _run_doubloons + _completion_bonus
	if GameState:
		GameState.has_used_free_double = true
		GameState.is_game_active = false
		GameState.doubloons += bonus_amount
		GameState.save_game()
		print("[2X SETTLEMENT CLAIMED] River Level %d | Claimed 2X Bonus: +%d 🪙 | New Vault Total: %d 🪙" % [
			GameState.current_level,
			bonus_amount,
			GameState.doubloons
		])
		GameState.doubloons_changed.emit(GameState.doubloons)
		
	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("coin_pickups", 1.2, 1.2, 4.0)
		AudioManager.play_sfx("gate_passes", 0.9, 1.1)
		
	var old_run_spoils: int = _banked_this_run
	_banked_this_run += bonus_amount
	_total_banked = GameState.doubloons
	
	if total_banked_label:
		total_banked_label.text = str(_banked_this_run)
		var tween: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_method(func(val: float) -> void:
			if total_banked_label:
				total_banked_label.text = str(int(val))
		, float(old_run_spoils), float(_banked_this_run), 0.5)
		
	_update_vault_balance_display()
	_update_shipyard_button()
	_check_tutorial_guidance()

func _on_primary_pressed() -> void:
	if _tutorial_overlay and is_instance_valid(_tutorial_overlay):
		_tutorial_overlay.dismiss()
	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("gate_passes")
	get_tree().paused = false
	if _is_extraction:
		retry_requested.emit()
		GameState.should_auto_start = false
		GameState.should_auto_start_endless = true
		GameState.reset_level()
		get_tree().reload_current_scene()
	elif _is_victory:
		if GameState.is_campaign_complete():
			# Campaign finished — go to hub and open the river map so the
			# player can see their full completed map rather than restarting.
			map_requested.emit()
			GameState.should_auto_start = false
			GameState.should_open_map = true
			GameState.change_scene_with_loading("res://scenes/cove_hub/cove_main_hub.tscn", "Pirate Lair")
		else:
			next_level_requested.emit()
			GameState.should_auto_start = true
			GameState.reset_level()
			get_tree().reload_current_scene()
	else:
		retry_requested.emit()
		GameState.should_auto_start = true
		GameState.reset_level()
		get_tree().reload_current_scene()

func _on_endless_pressed() -> void:
	if _tutorial_overlay and is_instance_valid(_tutorial_overlay):
		_tutorial_overlay.dismiss()
	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("gate_passes")
	get_tree().paused = false
	retry_requested.emit()
	GameState.should_auto_start = false
	GameState.should_auto_start_endless = true
	GameState.reset_level()
	get_tree().reload_current_scene()

func _on_shipyard_pressed() -> void:
	if _tutorial_overlay and is_instance_valid(_tutorial_overlay):
		_tutorial_overlay.dismiss()
	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("gate_passes")
	if shipyard_button:
		shipyard_button.disabled = true
	var shipyard_scene: PackedScene = preload("res://src/ui/shipyard/shipyard_ui.tscn")
	if shipyard_scene:
		var shipyard: ShipyardUI = shipyard_scene.instantiate() as ShipyardUI
		visible = false
		get_parent().add_child(shipyard)
		if shipyard:
			shipyard.shipyard_closed.connect(func() -> void:
				visible = true
				if shipyard_button:
					shipyard_button.disabled = false
				_refresh_banked_display()
				_update_shipyard_button()
				_check_tutorial_guidance()
			)

func _on_map_pressed() -> void:
	if _tutorial_overlay and is_instance_valid(_tutorial_overlay):
		_tutorial_overlay.dismiss()
	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("gate_passes")
	map_requested.emit()
	get_tree().paused = false
	GameState.should_auto_start = false
	if GameState.is_tutorial_in_progress():
		GameState.should_open_map = false
	else:
		GameState.should_open_map = true
	GameState.reset_level()
	GameState.change_scene_with_loading("res://scenes/cove_hub/cove_main_hub.tscn", "Smuggler's Cove")

func _check_tutorial_guidance() -> void:
	if not GameState or not GameState.is_tutorial_in_progress() or not _is_victory:
		if _tutorial_overlay and is_instance_valid(_tutorial_overlay):
			_tutorial_overlay.dismiss()
		return

	if not _tutorial_overlay or not is_instance_valid(_tutorial_overlay):
		_tutorial_overlay = GUIDANCE_SCENE.instantiate() as TutorialGuidanceOverlay
		add_child(_tutorial_overlay)

	var cleared_lvl: int = GameState.last_cleared_level
	if cleared_lvl in [2, 3, 4]:
		if primary_button:
			primary_button.visible = false
		if map_button:
			map_button.text = "RETURN TO COVE"

	var can_claim_ad: bool = not _bonus_claimed and bonus_claim_button != null and bonus_claim_button.visible and not bonus_claim_button.disabled

	# 1. First action on victory: Free 2X tutorial double ONLY on Level 1 if not yet claimed!
	if can_claim_ad:
		if GameState and not GameState.has_used_free_double and cleared_lvl == 1:
			_tutorial_overlay.shields_block_input = true
			_tutorial_overlay.guide_to(
				bonus_claim_button,
				"A true corsair always doubles their haul! Claim yer free bonus gold!",
				Vector2.UP,
				"QUARTERMASTER",
				"tut_settle_claim_2x"
			)
			return

	# When guiding navigation buttons (Return to Cove, Next Level) while an ad bonus is available,
	# ensure the tutorial overlay shields do not block player input on the ad claim button!
	_tutorial_overlay.shields_block_input = not can_claim_ad

	# 2. After bonus is claimed, guide to the next navigation step:
	if cleared_lvl == 1:
		# Level 1 victory: proceed to next level
		if primary_button and primary_button.visible:
			_tutorial_overlay.guide_to(
				primary_button,
				"Doubloons banked in the vault! Onward to the next voyage!",
				Vector2.UP,
				"QUARTERMASTER",
				"tut_settle_continue_1"
			)
	elif cleared_lvl == 2:
		# Level 2 victory: return to cove / shipyard
		if primary_button:
			primary_button.visible = false
		if map_button and map_button.visible:
			map_button.text = "RETURN TO COVE"
			_tutorial_overlay.guide_to(
				map_button,
				"We've got the coin! Return to Smuggler's Cove to visit the Drydock!",
				Vector2.UP,
				"QUARTERMASTER",
				"tut_settle_return_to_hub"
			)
		elif shipyard_button and shipyard_button.visible:
			_tutorial_overlay.guide_to(
				shipyard_button,
				"To the Drydock! Commission THE SLOOP!",
				Vector2.UP,
				"QUARTERMASTER",
				"tut_settle_return_to_hub"
			)
	elif cleared_lvl == 3:
		# Level 3 victory: return to cove / recruit crew
		if primary_button:
			primary_button.visible = false
		if map_button and map_button.visible:
			map_button.text = "RETURN TO COVE"
			_tutorial_overlay.guide_to(
				map_button,
				"Plunder secured! Return to Smuggler's Cove to recruit your crew!",
				Vector2.UP,
				"QUARTERMASTER",
				"tut_settle_return_to_hub"
			)
	elif cleared_lvl == 4:
		# Level 4 victory: return to cove / upgrade vessel to Tier 2
		if primary_button:
			primary_button.visible = false
		if map_button and map_button.visible:
			map_button.text = "RETURN TO COVE"
			_tutorial_overlay.guide_to(
				map_button,
				"The Dreadnought awaits! Return to Smuggler's Cove to upgrade your flagship at the Drydock!",
				Vector2.UP,
				"QUARTERMASTER",
				"tut_settle_return_to_hub_upgrade"
			)
		elif shipyard_button and shipyard_button.visible:
			_tutorial_overlay.guide_to(
				shipyard_button,
				"To the Drydock! Upgrade your Sloop to Tier 2 before the boss!",
				Vector2.UP,
				"QUARTERMASTER",
				"tut_settle_return_to_hub_upgrade"
			)
	else:
		# Levels 5+: tutorial complete / proceed to next level
		if primary_button and primary_button.visible:
			_tutorial_overlay.guide_to(
				primary_button,
				"Victory achieved! Onward to the next voyage!",
				Vector2.UP,
				"QUARTERMASTER",
				"tut_settle_continue_5"
			)
		elif map_button and map_button.visible:
			_tutorial_overlay.guide_to(
				map_button,
				"Plunder secured! Return to Smuggler's Cove!",
				Vector2.UP,
				"QUARTERMASTER",
				"tut_settle_return_to_hub"
			)


func _on_copy_telemetry_pressed() -> void:
	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("gate_passes")
	var telemetry: Node = get_tree().root.get_node_or_null("PlaytestTelemetry")
	if telemetry and telemetry.has_method("copy_session_json_to_clipboard"):
		telemetry.call("copy_session_json_to_clipboard")
		if copy_telemetry_button:
			copy_telemetry_button.text = "COPIED TO CLIPBOARD! ✓"
			var t: Tween = create_tween()
			t.tween_interval(2.0)
			t.tween_callback(func() -> void:
				if is_instance_valid(copy_telemetry_button):
					copy_telemetry_button.text = "📋 COPY TELEMETRY"
			)
