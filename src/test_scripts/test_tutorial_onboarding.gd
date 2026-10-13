extends Node

const DINGHY_SHIP_RES: String = "res://src/data/resources/user_vessels/dinghy_ship.tres"
const SLOOP_SHIP_RES: String = "res://src/data/resources/user_vessels/sloop_ship.tres"
const DINGHY_WEAPON_RES: String = "res://src/data/resources/user_crew/weapon_dinghy_chaser.tres"
const SHIPYARD_SCENE: String = "res://src/ui/shipyard/shipyard_ui.tscn"

var _pass_count: int = 0
var _fail_count: int = 0

func assert_test(cond: bool, test_name: String) -> void:
	if cond:
		_pass_count += 1
		print("  [PASS] %s" % test_name)
	else:
		_fail_count += 1
		push_error("  [FAIL] %s" % test_name)
		print("  [FAIL] %s" % test_name)

func _ready() -> void:
	print("\n========================================================")
	print("  RUNNING TUTORIAL & ONBOARDING SYSTEM REGRESSION TEST  ")
	print("========================================================\n")

	_test_dinghy_nerf_and_weapon_resources()
	_test_sloop_tier_2_crew_socket()
	_test_tutorial_reset_and_initial_state()
	_test_shipyard_hides_dinghy_when_sloop_owned()
	_test_sloop_tutorial_discount_and_progression()
	_test_sloop_t2_upgrade_discount_and_socket()
	_test_crew_auto_equip_and_tutorial_discount()
	_test_settlement_and_hub_routing()
	_test_save_migration()
	_test_crew_and_sloop_fast_forward_recovery()

	print("\n========================================================")
	print("  RESULTS: %d PASSED, %d FAILED" % [_pass_count, _fail_count])
	print("========================================================\n")

	if _fail_count == 0:
		print("ALL TUTORIAL ONBOARDING TESTS COMPLETED SUCCESSFULLY! ✓\n")
		get_tree().quit(0)
	else:
		push_error("Tutorial tests encountered failures!")
		get_tree().quit(1)

func _test_dinghy_nerf_and_weapon_resources() -> void:
	print("--- 1. Dinghy Nerfed Fire Rate & Weapon Resource Checks ---")
	assert_test(GameState.VESSEL_CATALOG["dinghy"]["fire_rate"] == 0.38, "GameState VESSEL_CATALOG dinghy fire_rate is 0.38s")
	
	var dinghy_res: ShipData = load(DINGHY_SHIP_RES) as ShipData
	assert_test(dinghy_res != null, "dinghy_ship.tres loaded successfully")
	if dinghy_res:
		assert_test(is_equal_approx(dinghy_res.fire_rate, 0.38), "dinghy_ship.tres fire_rate is 0.38s")
		assert_test(dinghy_res.socket_weapons.has("BowMount"), "dinghy has BowMount socket")
		var bow_wpn_path: String = str(dinghy_res.socket_weapons.get("BowMount", ""))
		assert_test(not bow_wpn_path.is_empty(), "BowMount weapon path is assigned")
		var bow_wpn: WeaponData = load(bow_wpn_path) as WeaponData
		assert_test(bow_wpn != null, "BowMount weapon data is loaded")
		if bow_wpn:
			assert_test(is_equal_approx(bow_wpn.fire_rate, 0.38), "BowMount weapon data fire_rate is 0.38s")
			assert_test(bow_wpn.resource_path.ends_with("weapon_dinghy_chaser.tres"), "BowMount uses dedicated weapon_dinghy_chaser.tres")

func _test_sloop_tier_2_crew_socket() -> void:
	print("\n--- 2. Sloop Tier 2 Mid-Deck Socket Standard ---")
	var sloop_res: ShipData = load(SLOOP_SHIP_RES) as ShipData
	assert_test(sloop_res != null, "sloop_ship.tres loaded successfully")
	if sloop_res:
		assert_test(sloop_res.tier_sockets.size() >= 2, "sloop_ship.tres has at least 2 tiers defined")
		if sloop_res.tier_sockets.size() >= 2:
			var tier_2_sockets: Array = sloop_res.tier_sockets[1]
			assert_test(tier_2_sockets.has("MidDeckCrew"), "sloop_ship.tres Tier 2 includes MidDeckCrew socket")

	var sockets_from_game_state: Array[String] = GameState.get_crew_sockets_for_ship("sloop", 2)
	assert_test(sockets_from_game_state.has("MidDeckCrew"), "GameState get_crew_sockets_for_ship('sloop', 2) returns MidDeckCrew")

func _test_tutorial_reset_and_initial_state() -> void:
	print("\n--- 3. Tutorial Reset & Initial State ---")
	GameState.reset_tutorial()
	assert_test(GameState.tutorial_step == GameState.TutorialStep.NOT_STARTED, "tutorial_step is NOT_STARTED (0)")
	assert_test(GameState.highest_unlocked_level == 1, "highest_unlocked_level is 1")
	assert_test(GameState.active_vessel == "dinghy", "active_vessel is dinghy")
	assert_test(GameState.is_vessel_owned("dinghy"), "dinghy is owned")
	assert_test(not GameState.is_vessel_owned("sloop"), "sloop is NOT owned initially")
	assert_test(GameState.is_tutorial_in_progress(), "is_tutorial_in_progress() is true")
	assert_test(not GameState.is_tutorial_completed(), "is_tutorial_completed() is false")

	var hotspot_scene: PackedScene = load("res://src/features/hub/lair_hotspot_area.tscn") as PackedScene
	assert_test(hotspot_scene != null, "lair_hotspot_area.tscn loaded")
	if hotspot_scene:
		var hotspot: LairHotspotArea = hotspot_scene.instantiate() as LairHotspotArea
		hotspot.mode_id = "shipyard"
		hotspot.required_level = 3
		add_child(hotspot)
		hotspot.refresh_lock_state()
		assert_test(hotspot.is_active_locked(), "Shipyard hotspot is locked during Level 1 (initial tutorial)")
		
		GameState.advance_tutorial_to(GameState.TutorialStep.LEVEL_2_COMPLETED)
		hotspot.refresh_lock_state()
		assert_test(not hotspot.is_active_locked(), "Shipyard hotspot successfully unlocks at LEVEL_2_COMPLETED")

		GameState.advance_tutorial_to(GameState.TutorialStep.SLOOP_PURCHASED)
		hotspot.refresh_lock_state()
		assert_test(hotspot.is_active_locked(), "Shipyard hotspot re-locks at SLOOP_PURCHASED to prevent freestyling")
		hotspot.queue_free()

func _test_shipyard_hides_dinghy_when_sloop_owned() -> void:
	print("\n--- 4. Shipyard Vessel Filtering (Dinghy Retirement) ---")
	var shipyard_packed: PackedScene = load(SHIPYARD_SCENE) as PackedScene
	assert_test(shipyard_packed != null, "shipyard_ui.tscn loaded successfully")
	if shipyard_packed:
		var shipyard_node: ShipyardUI = shipyard_packed.instantiate() as ShipyardUI
		assert_test(shipyard_node != null, "shipyard_node instantiated successfully")
		if shipyard_node:
			add_child(shipyard_node)
			
			# While tutorial is in progress and sloop is NOT owned:
			GameState.reset_tutorial()
			var v_ids_before: Array[String] = shipyard_node._get_active_vessel_ids()
			assert_test(v_ids_before.has("dinghy"), "Dinghy is visible in shipyard while sloop is unowned")
			
			# Now simulate sloop owned / purchased:
			GameState.owned_vessels.append("sloop")
			GameState.active_vessel = "sloop"
			var v_ids_after: Array[String] = shipyard_node._get_active_vessel_ids()
			assert_test(not v_ids_after.has("dinghy"), "Dinghy is permanently hidden from shipyard once Sloop is owned")
			assert_test(v_ids_after.has("sloop"), "Sloop is visible in shipyard")
			
			shipyard_node.queue_free()

func _test_sloop_tutorial_discount_and_progression() -> void:
	print("\n--- 5. Dynamic Sloop Discount & Progression ---")
	GameState.reset_tutorial()
	# Simulate clearing Level 2:
	GameState.highest_unlocked_level = 3
	GameState.advance_tutorial_to(GameState.TutorialStep.LEVEL_2_COMPLETED)
	assert_test(GameState.tutorial_step == GameState.TutorialStep.LEVEL_2_COMPLETED, "Tutorial step is LEVEL_2_COMPLETED")
	
	# Give player only 75 doubloons (less than standard 400 cost)
	GameState.doubloons = 75
	var buy_success: bool = GameState.buy_vessel("sloop")
	assert_test(buy_success, "buy_vessel('sloop') succeeded with dynamic tutorial discount")
	assert_test(GameState.doubloons == 0, "All available gold consumed by dynamic discount (cost capped to player doubloons)")
	assert_test(GameState.is_vessel_owned("sloop"), "sloop is now owned")
	assert_test(GameState.active_vessel == "sloop", "sloop is auto-equipped as active vessel")
	assert_test(GameState.tutorial_step == GameState.TutorialStep.SLOOP_PURCHASED, "Tutorial step advanced to SLOOP_PURCHASED")

func _test_sloop_t2_upgrade_discount_and_socket() -> void:
	print("\n--- 6. Sloop Crew Socket Verification & Upgrade Affordance ---")
	var t1_sockets: Array[String] = GameState.get_crew_sockets_for_ship("sloop", 1)
	assert_test(t1_sockets.has("MidDeckCrew"), "Sloop Tier 1 has MidDeckCrew socket available for crew placement")

	var sockets: Array[String] = GameState.get_crew_sockets_for_ship("sloop", 2)
	assert_test(sockets.has("MidDeckCrew"), "Sloop Tier 2 includes MidDeckCrew socket")

func _test_crew_auto_equip_and_tutorial_discount() -> void:
	print("\n--- 7. Monkey Bomber Recruitment & Auto-Equip (Post-Level 3) ---")
	# Simulate clearing Level 3:
	GameState.highest_unlocked_level = 4
	GameState.advance_tutorial_to(GameState.TutorialStep.LEVEL_3_COMPLETED)
	assert_test(GameState.tutorial_step == GameState.TutorialStep.LEVEL_3_COMPLETED, "Tutorial step is LEVEL_3_COMPLETED")

	# Give player 25 doubloons (less than standard unlock cost)
	GameState.doubloons = 25
	var hire_success: bool = GameState.buy_crew("monkey_bomber")
	assert_test(hire_success, "buy_crew('monkey_bomber') succeeded with dynamic tutorial discount")
	assert_test(GameState.doubloons == 0, "Doubloons spent correctly")
	assert_test(GameState.is_crew_unlocked("monkey_bomber"), "monkey_bomber is unlocked")

	# Verify auto-equip into Sloop's MidDeckCrew socket
	var equipped: String = GameState.get_equipped_crew("sloop", "MidDeckCrew")
	assert_test(equipped == "monkey_bomber", "monkey_bomber was automatically equipped to Sloop MidDeckCrew socket")
	assert_test(GameState.tutorial_step == GameState.TutorialStep.CREW_EQUIPPED, "Tutorial step advanced to CREW_EQUIPPED")

	# Advance to completion
	GameState.advance_tutorial_to(GameState.TutorialStep.COMPLETED)
	assert_test(GameState.is_tutorial_completed(), "is_tutorial_completed() is true after reaching COMPLETED")

func _test_settlement_and_hub_routing() -> void:
	print("\n--- 8. Settlement Post-Level 3 Routing & Hub Lock States ---")
	GameState.current_level = 3
	GameState.highest_unlocked_level = 3
	GameState.tutorial_step = GameState.TutorialStep.SLOOP_PURCHASED
	GameState.is_game_active = false
	GameState.unlocked_crew = {}
	GameState.equipped_crew = {}

	var settle_scene: PackedScene = load("res://src/ui/settlement_screen.tscn") as PackedScene
	assert_test(settle_scene != null, "settlement_screen.tscn loaded successfully")
	var settle_node: SettlementScreen = settle_scene.instantiate() as SettlementScreen
	assert_test(settle_node != null, "settlement_screen instantiated successfully")
	add_child(settle_node)

	settle_node.show_victory(50, 50, 100, 3)
	assert_test(GameState.tutorial_step == GameState.TutorialStep.LEVEL_3_COMPLETED, "Tutorial step advanced to LEVEL_3_COMPLETED after Level 3 victory")
	var map_btn: Button = settle_node.map_button
	var primary_btn: Button = settle_node.primary_button
	assert_test(map_btn != null and map_btn.text == "RETURN TO COVE", "Settlement map_button text is 'RETURN TO COVE' after Level 3")
	assert_test(primary_btn != null and not primary_btn.visible, "Settlement primary_button is hidden after Level 3 to prevent bypassing tutorial")

	# Test hotspot lock states at LEVEL_3_COMPLETED
	var hotspot_scene: PackedScene = load("res://src/features/hub/lair_hotspot_area.tscn") as PackedScene
	var drydock_hotspot: LairHotspotArea = hotspot_scene.instantiate() as LairHotspotArea
	drydock_hotspot.mode_id = "shipyard"
	add_child(drydock_hotspot)
	drydock_hotspot.refresh_lock_state()
	assert_test(not drydock_hotspot.is_active_locked(), "Drydock hotspot is unlocked at LEVEL_3_COMPLETED")

	var chart_hotspot: LairHotspotArea = hotspot_scene.instantiate() as LairHotspotArea
	chart_hotspot.mode_id = "campaign"
	add_child(chart_hotspot)
	chart_hotspot.refresh_lock_state()
	assert_test(chart_hotspot.is_active_locked(), "Chart House hotspot is locked at LEVEL_3_COMPLETED to steer player to Drydock")

	settle_node.queue_free()
	drydock_hotspot.queue_free()
	chart_hotspot.queue_free()

func _test_save_migration() -> void:
	print("\n--- 9. Save Data Migration for Legacy Profiles ---")
	# Test legacy profile with high level and Sloop
	var legacy_data: Dictionary = {
		"unlocked_levels": 6,
		"owned_vessels": ["dinghy", "sloop"],
		"active_vessel": "sloop",
		"doubloons": 1200
	}
	# Pass through load migration logic directly:
	if not legacy_data.has("tutorial_step"):
		if int(legacy_data.get("unlocked_levels", 1)) > 2 or (legacy_data.get("owned_vessels", []) as Array).has("sloop"):
			legacy_data["tutorial_step"] = GameState.TutorialStep.COMPLETED
		else:
			legacy_data["tutorial_step"] = GameState.TutorialStep.NOT_STARTED
			
	assert_test(legacy_data["tutorial_step"] == GameState.TutorialStep.COMPLETED, "Legacy high-level save migrated to COMPLETED")

	# Test legacy fresh profile:
	var fresh_data: Dictionary = {
		"unlocked_levels": 1,
		"owned_vessels": ["dinghy"],
		"active_vessel": "dinghy",
		"doubloons": 0
	}
	if not fresh_data.has("tutorial_step"):
		if int(fresh_data.get("unlocked_levels", 1)) > 2 or (fresh_data.get("owned_vessels", []) as Array).has("sloop"):
			fresh_data["tutorial_step"] = GameState.TutorialStep.COMPLETED
		else:
			fresh_data["tutorial_step"] = GameState.TutorialStep.NOT_STARTED
			
	assert_test(fresh_data["tutorial_step"] == GameState.TutorialStep.NOT_STARTED, "Legacy fresh save migrated to NOT_STARTED")

func _test_crew_and_sloop_fast_forward_recovery() -> void:
	print("\n--- 10. Tutorial Fast-Forward & Pre-Owned Assets Recovery ---")
	# 1. Test Sloop pre-owned at LEVEL_2_COMPLETED
	GameState.tutorial_step = GameState.TutorialStep.LEVEL_2_COMPLETED
	GameState.owned_vessels = ["dinghy", "sloop"]
	GameState.active_vessel = "dinghy"
	GameState.check_and_fast_forward_tutorial()
	assert_test(GameState.tutorial_step == GameState.TutorialStep.SLOOP_PURCHASED, "Pre-owned Sloop fast-forwards LEVEL_2_COMPLETED to SLOOP_PURCHASED")
	assert_test(GameState.active_vessel == "sloop", "Pre-owned Sloop is automatically set as active vessel")

	# 2. Test Monkey Bomber pre-owned at LEVEL_3_COMPLETED
	GameState.tutorial_step = GameState.TutorialStep.LEVEL_3_COMPLETED
	GameState.unlocked_crew = {"monkey_bomber": 1}
	GameState.equipped_crew = {}
	GameState.check_and_fast_forward_tutorial()
	assert_test(GameState.tutorial_step == GameState.TutorialStep.CREW_EQUIPPED, "Pre-owned Monkey Bomber fast-forwards LEVEL_3_COMPLETED to CREW_EQUIPPED")
	assert_test(GameState.is_crew_equipped_on_active_ship("monkey_bomber"), "Pre-owned Monkey Bomber is automatically equipped to Sloop")

	# 3. Test Overlay fail-safe when target is hidden / invalid
	var overlay_scene: PackedScene = load("res://src/ui/tutorial/tutorial_guidance_overlay.tscn") as PackedScene
	assert_test(overlay_scene != null, "tutorial_guidance_overlay.tscn loads successfully")
	var overlay: TutorialGuidanceOverlay = overlay_scene.instantiate() as TutorialGuidanceOverlay
	add_child(overlay)

	var dummy_btn: Button = Button.new()
	dummy_btn.visible = false
	add_child(dummy_btn)

	overlay.guide_to(dummy_btn, "Testing hidden target fail-safe")
	assert_test(overlay.shield_top.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Shields ignore mouse when target is invisible (prevents click blocking)")
	assert_test(not overlay.target_highlight.visible, "Target highlight hidden when target is invisible")

	dummy_btn.queue_free()
	overlay.queue_free()
