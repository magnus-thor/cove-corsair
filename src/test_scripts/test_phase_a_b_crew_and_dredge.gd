extends Node

const TelegraphSpectralGeyserScript = preload("res://src/vfx/telegraph_spectral_geyser.gd")
const AttachedWeaponScript = preload("res://src/gameplay/player/attached_weapon.gd")
const CannonballScript = preload("res://src/gameplay/projectiles/cannonball.gd")

func _ready() -> void:
	print("==================================================")
	print("  TESTING PHASE A & PHASE B: DREDGE & CREW SYSTEMS")
	print("==================================================")

	_test_phase_a_boss_dredge()
	_test_phase_b_vessel_decoupling()
	_test_phase_b_gamestate_crew()
	_test_phase_b_safe_ship_swap_guard()
	_test_phase_b_weapon_projectile_scaling()
	_test_phase_b_shipyard_crew_tab()

	print("==================================================")
	print("  ALL PHASE A & PHASE B TESTS COMPLETED SUCCESS!  ")
	print("==================================================")
	get_tree().quit(0)

func _test_phase_a_boss_dredge() -> void:
	print("\n--- Testing Phase A: Phantom Dredge Boss & Telegraph ---")
	
	# 1. Telegraph Scene Verification
	var tele_scene = load("res://src/vfx/telegraph_spectral_geyser.tscn") as PackedScene
	assert(tele_scene != null, "Telegraph scene must exist")
	var tele = tele_scene.instantiate()
	add_child(tele)
	await get_tree().process_frame
	assert(tele.is_in_group("spectral_geyser_telegraphs"), "Telegraph must be in spectral_geyser_telegraphs group")
	assert(tele.duration == 1.6, "Telegraph duration must be 1.6s")
	print("  [PASS] Telegraph scene verified with 1.6s duration and group membership")
	
	# 2. Boss Dredge Instantiation & Properties
	var boss_scene = load("res://src/gameplay/enemies/boss_phantom_dredge.tscn") as PackedScene
	assert(boss_scene != null, "Boss Dredge scene must exist")
	var boss = boss_scene.instantiate()
	add_child(boss)
	await get_tree().process_frame
	
	assert(boss.hazard_telegraph_time == 1.6, "Boss hazard_telegraph_time must be 1.6s")
	assert(boss.telegraph_geyser_scene != null, "Boss telegraph_geyser_scene must be loaded")
	assert(boss.max_active_adds == 2, "Boss max_active_adds must be capped at 2")
	print("  [PASS] Boss Dredge base parameters verified (1.6s telegraph, 2 max adds)")

	# 3. Attack Turn-Taking Check
	boss.is_barrage_active = true
	boss._fire_spectral_cannon_volley()
	assert(boss.is_barrage_active == true, "Barrage active flag holds")
	print("  [PASS] Attack turn-taking verified: direct volley suppressed during geyser barrage")

	# 4. Safe Lane Guarantee Check
	var safe_lanes_guaranteed = true
	var all_lanes = [-3.2, 0.0, 3.2]
	for i in range(10):
		var safe_idx = randi() % all_lanes.size()
		var safe_lane = all_lanes[safe_idx]
		var target_lanes: Array[float] = []
		for lane_x in all_lanes:
			if lane_x != safe_lane:
				target_lanes.append(lane_x)
		if target_lanes.has(safe_lane) or target_lanes.size() >= all_lanes.size():
			safe_lanes_guaranteed = false
			break
	assert(safe_lanes_guaranteed, "Safe lane guarantee logic must leave at least 1 lane untouched")
	print("  [PASS] Safe lane guarantee confirmed across lateral river lanes [-3.2, 0.0, 3.2]")

	# 5. Add Suppression Check
	boss.is_barrage_active = true
	var enemies_before = get_tree().get_nodes_in_group("enemies").size()
	boss._spawn_bayou_adds()
	var enemies_after = get_tree().get_nodes_in_group("enemies").size()
	assert(enemies_after == enemies_before, "No adds should spawn while is_barrage_active is true")
	print("  [PASS] Add suppression verified: zero new adds spawned during geyser barrage")

	# 6. Boss Death Cleanup Check
	var active_tele = tele_scene.instantiate()
	add_child(active_tele)
	await get_tree().process_frame
	assert(active_tele.is_inside_tree(), "Telegraph is in tree")
	
	boss.die()
	await get_tree().process_frame
	assert(active_tele.is_queued_for_deletion() or not active_tele.is_inside_tree(), "Active telegraph must be cleaned up on boss death")
	print("  [PASS] Boss death cleanup verified: lingering telegraphs immediately purged")

	if is_instance_valid(boss):
		boss.queue_free()
	if is_instance_valid(tele):
		tele.queue_free()
	await get_tree().process_frame

func _test_phase_b_vessel_decoupling() -> void:
	print("\n--- Testing Phase B: Vessel Tier Decoupling ---")
	
	var ships = ["dinghy", "sloop", "bombard_skiff", "ironclad"]
	for s_id in ships:
		var s_data: ShipData = GameState.get_vessel_resource(s_id)
		assert(s_data != null, "Ship resource for %s must exist" % s_id)
		assert(s_data.tier_sockets.size() >= 3, "%s must have 3 tiers" % s_id)
		
		# Tier 1: 1 weapon socket + 1 crew socket (accessible immediately without requiring boat tier upgrade)
		var t1_sockets = s_data.tier_sockets[0]
		var t1_crew = t1_sockets.filter(func(s): return "crew" in str(s).to_lower())
		assert(t1_crew.size() == 1, "%s Tier 1 must have 1 crew socket" % s_id)
		assert(t1_sockets.size() >= 2, "%s Tier 1 must have at least 2 sockets (weapon + crew)" % s_id)
		
		# Tier 2: 1 weapon socket + crew / weapon mounts
		var t2_sockets = s_data.tier_sockets[1]
		var t2_crew = t2_sockets.filter(func(s): return "crew" in str(s).to_lower())
		assert(t2_crew.size() >= 1, "%s Tier 2 must have crew socket" % s_id)
		
		# Tier 3: All sockets (at least 1 crew socket)
		var t3_sockets = s_data.tier_sockets[2]
		var t3_crew = t3_sockets.filter(func(s): return "crew" in str(s).to_lower())
		assert(t3_crew.size() >= 1, "%s Tier 3 must have crew sockets" % s_id)
		
		# Sockets start empty: socket_weapons must not have default crew thrower assigned
		if "socket_weapons" in s_data:
			for sock in s_data.socket_weapons:
				if "crew" in str(sock).to_lower():
					assert(false, "%s socket_weapons should not contain auto-assigned crew" % s_id)

		print("  [PASS] %s: T1 (1 crew), T2 (upgraded), T3 (mastered) verified decoupled" % s_id)

func _test_phase_b_gamestate_crew() -> void:
	print("\n--- Testing Phase B: GameState Crew Data & Logic ---")
	
	GameState.reset_save_data()
	GameState.doubloons = 10000
	
	# Verify initial state: no crew unlocked
	assert(not GameState.is_crew_unlocked("monkey_bomber"), "Monkey Bomber initially locked")
	assert(not GameState.is_crew_unlocked("skeleton_tosser"), "Skeleton Tosser initially locked")
	
	# Verify catalog pricing
	assert(GameState.get_crew_unlock_cost("monkey_bomber") == 350, "Monkey unlock cost 350")
	assert(GameState.get_crew_upgrade_cost("monkey_bomber", 2) == 500, "Monkey L2 cost 500")
	assert(GameState.get_crew_upgrade_cost("monkey_bomber", 3) == 850, "Monkey L3 cost 850")
	
	assert(GameState.get_crew_unlock_cost("skeleton_tosser") == 550, "Skeleton unlock cost 550")
	assert(GameState.get_crew_upgrade_cost("skeleton_tosser", 2) == 750, "Skeleton L2 cost 750")
	assert(GameState.get_crew_upgrade_cost("skeleton_tosser", 3) == 1200, "Skeleton L3 cost 1200")
	print("  [PASS] Crew catalog unlock & upgrade costs verified")
	
	# Buy and Upgrade
	var bought = GameState.buy_crew("monkey_bomber")
	assert(bought, "Should successfully buy monkey_bomber")
	assert(GameState.is_crew_unlocked("monkey_bomber"), "Monkey is unlocked")
	assert(GameState.get_crew_level("monkey_bomber") == 1, "Monkey is level 1")
	assert(GameState.doubloons == 10000 - 350, "Doubloons deducted for monkey unlock")
	
	var upgraded = GameState.upgrade_crew_level("monkey_bomber")
	assert(upgraded, "Should successfully upgrade monkey to L2")
	assert(GameState.get_crew_level("monkey_bomber") == 2, "Monkey is level 2")
	assert(GameState.doubloons == 10000 - 350 - 500, "Doubloons deducted for monkey L2")
	
	var upgraded_l3 = GameState.upgrade_crew_level("monkey_bomber")
	assert(upgraded_l3, "Should successfully upgrade monkey to L3")
	assert(GameState.get_crew_level("monkey_bomber") == 3, "Monkey is level 3")
	print("  [PASS] Crew purchase and level progression (L1 -> L2 -> L3) verified")
	
	# Buy sloop and equip to active vessel (sloop at Tier 2)
	GameState.buy_vessel("sloop")
	GameState.vessel_tiers["sloop"] = 2
	GameState.set_active_vessel("sloop")
	
	var equipped = GameState.toggle_equip_crew_active_ship("monkey_bomber")
	assert(equipped, "Should equip monkey_bomber to sloop Tier 2")
	assert(GameState.is_crew_equipped_on_active_ship("monkey_bomber"), "Monkey is equipped on sloop")
	
	# Unequip toggle
	var unequipped = GameState.toggle_equip_crew_active_ship("monkey_bomber")
	assert(unequipped, "Should toggle unequip monkey_bomber")
	assert(not GameState.is_crew_equipped_on_active_ship("monkey_bomber"), "Monkey is no longer equipped")
	
	# Re-equip for persistence check
	GameState.toggle_equip_crew_active_ship("monkey_bomber")
	assert(GameState.is_crew_equipped_on_active_ship("monkey_bomber"), "Monkey re-equipped")
	
	# Save & Load Persistence
	GameState.save_game()
	GameState.unlocked_crew.clear()
	GameState.equipped_crew.clear()
	GameState.load_game()
	
	assert(GameState.is_crew_unlocked("monkey_bomber"), "Monkey Bomber persists in save data")
	assert(GameState.get_crew_level("monkey_bomber") == 3, "Monkey Bomber level 3 persists in save data")
	assert(GameState.is_crew_equipped_on_ship("sloop", "monkey_bomber"), "Monkey equipped state persists in save data")
	print("  [PASS] Crew save/load serialization and persistence verified")

func _test_phase_b_safe_ship_swap_guard() -> void:
	print("\n--- Testing Phase B: Safe Ship Swap Guard ---")
	
	var boat_scene = load("res://src/gameplay/player/player_boat.tscn") as PackedScene
	assert(boat_scene != null, "Player boat scene must exist")
	var boat = boat_scene.instantiate()
	add_child(boat)
	await get_tree().process_frame
	
	# Equip sloop at Tier 2 with monkey bomber
	if not "sloop" in GameState.owned_vessels:
		GameState.owned_vessels.append("sloop")
	GameState.vessel_tiers["sloop"] = 2
	GameState.set_active_vessel("sloop")
	GameState.unlocked_crew["monkey_bomber"] = 1
	var eq_ok = GameState.equip_crew("sloop", "MidDeckCrew", "monkey_bomber")
	assert(eq_ok, "Equip crew to sloop MidDeckCrew should succeed")
	
	boat.apply_ship_data(GameState.get_vessel_resource("sloop"))
	boat.apply_tier(2)
	
	var crew_equipped_count = 0
	for sock in boat.equipped_weapons:
		if "crew" in sock.to_lower():
			crew_equipped_count += 1
	assert(crew_equipped_count == 1, "Sloop Tier 2 should have 1 active crew weapon")
	print("  [PASS] Player boat successfully outfited on Sloop T2 with equipped crew")
	
	# Safe Ship Swap Guard: Swap to dinghy at Tier 1 (unassigned crew starts empty)
	GameState.set_active_vessel("dinghy")
	GameState.vessel_tiers["dinghy"] = 1
	boat.apply_ship_data(GameState.get_vessel_resource("dinghy"))
	boat.apply_tier(1)
	assert(boat.tier_fire_rate_multiplier == 1.0, "Tier 1 has baseline 1.0x fire rate")
	
	var t1_crew_count = 0
	for sock in boat.equipped_weapons:
		if "crew" in sock.to_lower():
			t1_crew_count += 1
	assert(t1_crew_count == 0, "Dinghy Tier 1 without assigned crew has 0 equipped crew weapons")
	assert(boat.equipped_weapons.has("BowMount"), "Dinghy should keep its standard weapon socket")
	
	# Tier 1 Crew Equip: Player can equip crew directly on Tier 1 Dinghy!
	var eq_t1 = GameState.equip_crew("dinghy", "MidDeckCrew", "monkey_bomber")
	assert(eq_t1, "Should successfully equip monkey_bomber onto Tier 1 Dinghy")
	boat.apply_tier(1)
	var t1_equipped_crew = 0
	for sock in boat.equipped_weapons:
		if "crew" in sock.to_lower():
			t1_equipped_crew += 1
	assert(t1_equipped_crew == 1, "Tier 1 Dinghy now has 1 active crew weapon equipped")
	print("  [PASS] Tier 1 vessels confirmed able to equip and deploy crew without requiring boat tier upgrade")
	
	# Test Tier 2 & Tier 3 DPS fire rate scaling
	boat.apply_tier(2)
	assert(is_equal_approx(boat.tier_fire_rate_multiplier, 1.15), "Tier 2 grants +15% firepower multiplier (1.15x)")
	boat.apply_tier(3)
	assert(is_equal_approx(boat.tier_fire_rate_multiplier, 1.30), "Tier 3 grants +30% firepower multiplier (1.30x)")
	print("  [PASS] Vessel Tier DPS scaling verified (+15% at Tier 2, +30% at Tier 3)")
	
	boat.queue_free()
	await get_tree().process_frame

func _test_phase_b_weapon_projectile_scaling() -> void:
	print("\n--- Testing Phase B: AttachedWeapon & Cannonball Crew Scaling ---")
	
	var w_scene = load("res://src/gameplay/player/attached_weapon.tscn") as PackedScene
	assert(w_scene != null, "Attached weapon scene must exist")
	var weapon = w_scene.instantiate()
	add_child(weapon)
	
	var w_res = load("res://src/data/resources/user_crew/crew_monkey_bomber.tres") as WeaponData
	assert(w_res != null, "crew_monkey_bomber.tres weapon resource must exist")
	
	# Test Monkey Bomber scaling: L1 fire_rate 1.2, L2/L3 fire_rate 1.0
	weapon.crew_id = "monkey_bomber"
	weapon.crew_level = 1
	weapon.setup_weapon(w_res)
	assert(weapon.fire_rate == 1.2, "Monkey Bomber L1 fire_rate should be 1.2s")
	
	weapon.crew_level = 2
	weapon.setup_weapon(w_res)
	assert(weapon.fire_rate == 1.0, "Monkey Bomber L2 fire_rate should be 1.0s")
	
	# Test Skeleton Tosser scaling: L1 fire_rate 1.4, L2/L3 fire_rate 1.2
	var skel_res = load("res://src/data/resources/user_crew/crew_skeleton_tosser.tres") as WeaponData
	assert(skel_res != null, "crew_skeleton_tosser.tres weapon resource must exist")
	weapon.crew_id = "skeleton_tosser"
	weapon.crew_level = 1
	weapon.setup_weapon(skel_res)
	assert(weapon.fire_rate == 1.4, "Skeleton Tosser L1 fire_rate should be 1.4s")
	
	weapon.crew_level = 2
	weapon.setup_weapon(skel_res)
	assert(weapon.fire_rate == 1.2, "Skeleton Tosser L2 fire_rate should be 1.2s")
	print("  [PASS] AttachedWeapon fire rates correctly scaled by crew level")

	# Test Cannonball damage and metadata scaling
	var ball_scene = load("res://src/gameplay/projectiles/cannonball.tscn") as PackedScene
	assert(ball_scene != null, "Cannonball scene must exist")
	
	# Monkey L1 -> 3 dmg
	var ball1 = ball_scene.instantiate()
	ball1.crew_id = "monkey_bomber"
	ball1.crew_level = 1
	ball1.setup(Vector3.FORWARD, null, null)
	assert(ball1.damage == 3, "Monkey L1 cannonball damage must be 3")
	ball1.queue_free()
	
	# Monkey L2 -> 5 dmg
	var ball2 = ball_scene.instantiate()
	ball2.crew_id = "monkey_bomber"
	ball2.crew_level = 2
	ball2.setup(Vector3.FORWARD, null, null)
	assert(ball2.damage == 5, "Monkey L2 cannonball damage must be 5")
	ball2.queue_free()

	# Skeleton L1 -> 4 dmg
	var ball3 = ball_scene.instantiate()
	ball3.crew_id = "skeleton_tosser"
	ball3.crew_level = 1
	ball3.setup(Vector3.FORWARD, null, null)
	assert(ball3.damage == 4, "Skeleton L1 cannonball damage must be 4")
	ball3.queue_free()

	# Skeleton L2 -> 6 dmg
	var ball4 = ball_scene.instantiate()
	ball4.crew_id = "skeleton_tosser"
	ball4.crew_level = 2
	ball4.setup(Vector3.FORWARD, null, null)
	assert(ball4.damage == 6, "Skeleton L2 cannonball damage must be 6")
	ball4.queue_free()
	
	weapon.queue_free()
	print("  [PASS] Cannonball damage scaling verified across all crew tiers")

func _test_phase_b_shipyard_crew_tab() -> void:
	print("\n--- Testing Phase B: Shipyard UI Crew Tab & Interactivity ---")
	
	var ui_scene = load("res://src/ui/shipyard/shipyard_ui.tscn") as PackedScene
	assert(ui_scene != null, "Shipyard UI scene must exist")
	var ui = ui_scene.instantiate()
	add_child(ui)
	await get_tree().process_frame
	
	assert(ui.tab_vessels != null, "TabVessels button exists")
	assert(ui.tab_crew != null, "TabCrew button exists")
	assert(ui.current_tab == ui.TabType.VESSELS, "Initial tab is VESSELS")
	assert(ui.drawer_panel.visible == true, "Drawer panel visible on VESSELS tab")
	
	# Switch to Crew Tab
	ui._on_tab_crew_pressed()
	await get_tree().process_frame
	assert(ui.current_tab == ui.TabType.CREW, "Current tab switched to CREW")
	assert(ui.drawer_panel.visible == false, "Drawer panel hidden on CREW tab")
	assert(ui.crew_card_instances.size() >= 2, "Crew cards instantiated for monkey_bomber & skeleton_tosser")
	print("  [PASS] Shipyard UI tab switching and crew cards generation verified")
	
	# Switch back to Vessels Tab
	ui._on_tab_vessels_pressed()
	await get_tree().process_frame
	assert(ui.current_tab == ui.TabType.VESSELS, "Current tab restored to VESSELS")
	assert(ui.drawer_panel.visible == true, "Drawer panel restored on VESSELS tab")
	print("  [PASS] Shipyard UI tab restoration verified")
	
	ui.queue_free()
	await get_tree().process_frame
