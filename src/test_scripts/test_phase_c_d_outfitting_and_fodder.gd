@tool
# Turn off untyped warnings specifically for test harnesses:
@warning_ignore("untyped_declaration")
@warning_ignore("unsafe_property_access")
@warning_ignore("unsafe_method_access")
@warning_ignore("unsafe_cast")
extends Node

const CannonballScript = preload("res://src/gameplay/projectiles/cannonball.gd")
const EnemyFodderSkiffScript = preload("res://src/gameplay/enemies/enemy_fodder_skiff.gd")
const OutfittingCardScript = preload("res://src/ui/shipyard/outfitting_card.gd")
const ShipyardUIScript = preload("res://src/ui/shipyard/shipyard_ui.gd")
const BossPhantomDredgeScript = preload("res://src/gameplay/enemies/boss_phantom_dredge.gd")
const HazardSeaMineScript = preload("res://src/gameplay/obstacles/hazard_sea_mine.gd")
const PlayerSwerveScript = preload("res://src/gameplay/player/player.gd")

func _ready() -> void:
	print("==================================================")
	print("  TESTING PHASE C & PHASE D: OUTFITTING & FODDER  ")
	print("==================================================")

	await _test_phase_c_gamestate_outfitting()
	await _test_phase_c_tactical_ammo_mechanics()
	await _test_phase_c_hull_platings_and_prow_mine_absorb()
	await _test_phase_c_shipyard_outfitting_ui()
	await _test_phase_d_action_mobs_and_economy()
	await _test_phase_d_fire_frenzy_streak_and_timer_refresh()
	await _test_phase_d_levels_and_chunk_integration()

	print("==================================================")
	print("  ALL PHASE C & PHASE D TESTS PASSED WITH SUCCESS!")
	print("==================================================")
	get_tree().quit(0)

func _test_phase_c_gamestate_outfitting() -> void:
	print("\n--- 1. Testing Phase C: GameState Outfitting Data & Persistence ---")
	
	# Initialize fresh outfitting state
	GameState.active_vessel = "dinghy"
	GameState.unlocked_outfitting = {"standard_iron": true, "none": true}
	GameState.equipped_ammo = {"dinghy": "standard_iron", "sloop": "standard_iron", "ironclad": "standard_iron", "bombard_skiff": "standard_iron"}
	GameState.equipped_plating = {"dinghy": "none", "sloop": "none", "ironclad": "none", "bombard_skiff": "none"}

	# Verify catalog completeness
	assert(GameState.OUTFITTING_CATALOG.has("standard_iron"), "Catalog must have standard_iron")
	assert(GameState.OUTFITTING_CATALOG.has("battering_shot"), "Catalog must have battering_shot")
	assert(GameState.OUTFITTING_CATALOG.has("chain_shot"), "Catalog must have chain_shot")
	assert(GameState.OUTFITTING_CATALOG.has("spectral_salt"), "Catalog must have spectral_salt")
	assert(GameState.OUTFITTING_CATALOG.has("none"), "Catalog must have none plating")
	assert(GameState.OUTFITTING_CATALOG.has("spectral_ward"), "Catalog must have spectral_ward")
	assert(GameState.OUTFITTING_CATALOG.has("brimstone_fireproof"), "Catalog must have brimstone_fireproof")
	assert(GameState.OUTFITTING_CATALOG.has("spiked_iron_prow"), "Catalog must have spiked_iron_prow")
	print("  [PASS] Catalog contains all 4 tactical ammo types and 4 hull platings")

	# Verify defaults
	assert(GameState.is_outfitting_unlocked("standard_iron") == true, "standard_iron must be unlocked by default")
	assert(GameState.is_outfitting_unlocked("none") == true, "none plating must be unlocked by default")
	assert(GameState.get_active_ammo() == "standard_iron", "Active ammo must default to standard_iron")
	assert(GameState.get_active_plating() == "none", "Active plating must default to none")
	print("  [PASS] Default unlocked state and active loadout verified")

	# Purchasing outfitting
	GameState.doubloons = 0
	assert(GameState.buy_outfitting("battering_shot") == false, "Cannot buy outfitting without coins")
	
	GameState.doubloons = 2000
	assert(GameState.buy_outfitting("battering_shot") == true, "Must buy battering_shot with sufficient coins")
	assert(GameState.doubloons == 1600, "Purse must deduct 400 coins for battering_shot")
	assert(GameState.is_outfitting_unlocked("battering_shot") == true, "battering_shot is now unlocked")

	# Equipping and toggling
	assert(GameState.equip_ammo("dinghy", "battering_shot") == true, "Must equip battering_shot to dinghy")
	assert(GameState.get_equipped_ammo("dinghy") == "battering_shot", "Equipped ammo for dinghy must be battering_shot")

	# Toggle off reverts to standard_iron
	GameState.active_vessel = "dinghy"
	GameState.toggle_equip_outfitting_active_ship("battering_shot")
	assert(GameState.get_active_ammo() == "standard_iron", "Toggling equipped ammo off reverts to standard_iron")

	# Buy plating and equip
	assert(GameState.buy_outfitting("spiked_iron_prow") == true, "Must buy spiked_iron_prow")
	assert(GameState.equip_plating("dinghy", "spiked_iron_prow") == true, "Must equip spiked_iron_prow")
	assert(GameState.get_active_plating() == "spiked_iron_prow", "Active plating must be spiked_iron_prow")

	# Persistence check
	GameState.save_game()
	GameState.load_game()
	assert(GameState.is_outfitting_unlocked("battering_shot") == true, "Save/Load must persist unlocked outfitting")
	assert(GameState.get_equipped_plating("dinghy") == "spiked_iron_prow", "Save/Load must persist equipped plating")
	print("  [PASS] GameState outfitting purchasing, equipping, toggling, and persistence verified")

func _test_phase_c_tactical_ammo_mechanics() -> void:
	print("\n--- 2. Testing Phase C: Tactical Ammo In-Flight & On-Hit Mechanics ---")

	var cannonball_scene = load("res://src/gameplay/projectiles/cannonball.tscn") as PackedScene
	assert(cannonball_scene != null, "cannonball.tscn must exist")

	# A. Battering Shot deals 2x damage against barricades
	var ball_battering = cannonball_scene.instantiate()
	add_child(ball_battering)
	ball_battering.set_meta("ammo_id", "battering_shot")
	ball_battering.setup(Vector3(0, 0, -1), null)
	assert(ball_battering.ammo_id == "battering_shot", "Ammo id must be battering_shot")

	# Mock Barricade
	var dummy_barricade = Area3D.new()
	dummy_barricade.name = "BarricadeSegment_Test"
	dummy_barricade.add_to_group("barricade")
	dummy_barricade.add_to_group("destructible")
	dummy_barricade.set_script(load("res://src/gameplay/obstacles/barricade_segment.gd"))
	add_child(dummy_barricade)
	dummy_barricade.hp = 10
	dummy_barricade.global_position = Vector3(0, 0, -5)
	ball_battering.global_position = Vector3(0, 0, -5)

	ball_battering._on_hit(dummy_barricade)
	# Battering shot base damage is 2, 2x against barricade = 4 damage
	assert(dummy_barricade.hp == 6, "Barricade should take 4 damage (2x from Battering Shot). Remaining: %d" % dummy_barricade.hp)
	print("  [PASS] Battering Shot successfully deals 2x damage against barricade segment")
	dummy_barricade.queue_free()

	# B. Chain Shot sweeps and detonates sea mines in a radius
	var ball_chain = cannonball_scene.instantiate()
	add_child(ball_chain)
	ball_chain.set_meta("ammo_id", "chain_shot")
	ball_chain.setup(Vector3(0, 0, -1), null)
	assert(ball_chain.ammo_id == "chain_shot", "Ammo id must be chain_shot")

	var mine_scene = load("res://src/gameplay/obstacles/hazard_sea_mine.tscn") as PackedScene
	var mine = mine_scene.instantiate()
	add_child(mine)
	mine.global_position = Vector3(2.0, 0, -5.0) # Within 3.5m radius
	ball_chain.global_position = Vector3(0, 0, -5.0)

	ball_chain._sweep_chain_shot_mines()
	await get_tree().process_frame
	assert(not is_instance_valid(mine) or mine.is_queued_for_deletion(), "Chain shot sweep must trigger sea mine detonation")
	print("  [PASS] Chain Shot sweep safely detonates sea mines in radius")

	# C. Spectral Salt deals +50% damage and interrupts boss geyser barrage
	var boss_scene = load("res://src/gameplay/enemies/boss_phantom_dredge.tscn") as PackedScene
	var boss = boss_scene.instantiate()
	add_child(boss)
	boss.is_arena_active = true
	boss.is_barrage_active = true
	boss.current_hp = 500

	var ball_salt = cannonball_scene.instantiate()
	add_child(ball_salt)
	ball_salt.set_meta("ammo_id", "spectral_salt")
	ball_salt.setup(Vector3(0, 0, -1), null)
	assert(ball_salt.ammo_id == "spectral_salt", "Ammo id must be spectral_salt")

	ball_salt._on_hit(boss)
	# Spectral salt base damage 2 * 1.5 = 3 damage
	assert(boss.current_hp == 497, "Boss should take 3 damage (+50%% bonus). HP: %d" % boss.current_hp)
	assert(boss.is_barrage_active == false, "Spectral salt must interrupt boss geyser barrage")
	print("  [PASS] Spectral Salt deals +50% bonus damage and interrupts boss barrage channel")
	boss.queue_free()
	await get_tree().process_frame

func _test_phase_c_hull_platings_and_prow_mine_absorb() -> void:
	print("\n--- 3. Testing Phase C: Hull Platings & Prow Mine Absorption ---")

	var player_scene = load("res://src/gameplay/player/player_boat.tscn") as PackedScene
	var player = player_scene.instantiate()
	add_child(player)
	GameState.is_game_active = true
	GameState.active_vessel = "dinghy"

	# A. Spectral Ward: -60% damage from geysers/spectral
	GameState.unlocked_outfitting["spectral_ward"] = true
	GameState.unlocked_outfitting["brimstone_fireproof"] = true
	GameState.unlocked_outfitting["spiked_iron_prow"] = true
	GameState.equip_plating("dinghy", "spectral_ward")
	player.hit_invulnerability_timer = 0.0
	player.current_health = 10
	player.max_health = 10
	player.take_hit(5, "poison_mortar_geyser")
	# 5 * 0.4 = 2 damage taken (60% mitigated)
	assert(player.current_health == 8, "Spectral Ward should mitigate 60%% damage (took 2 from 5). HP: %d" % player.current_health)
	print("  [PASS] Spectral Ward reduces geyser/spectral damage by 60%")

	# B. Brimstone Fireproof: -50% damage from fire/magma
	GameState.equip_plating("dinghy", "brimstone_fireproof")
	player.hit_invulnerability_timer = 0.0
	player.current_health = 10
	player.take_hit(4, "brimstone_magma_vent")
	# 4 * 0.5 = 2 damage taken (50% mitigated)
	assert(player.current_health == 8, "Brimstone Fireproof should mitigate 50%% damage (took 2 from 4). HP: %d" % player.current_health)
	print("  [PASS] Brimstone Fireproof reduces fire hazard damage by 50%")

	# C. Spiked Iron Prow: Sea mine ram absorption
	# "When Spiked Iron Prow absorbs a sea mine ram collision, ensure both the direct contact hit and the resulting explosion splash are nullified for that single impact."
	GameState.equip_plating("dinghy", "spiked_iron_prow")
	player.hit_invulnerability_timer = 0.0
	player.ram_absorb_charges_remaining = 1
	player.current_health = 10
	var initial_hp = player.current_health

	var mine_scene = load("res://src/gameplay/obstacles/hazard_sea_mine.tscn") as PackedScene
	var mine = mine_scene.instantiate()
	add_child(mine)
	mine.global_position = player.global_position

	# Simulate player colliding with sea mine
	player._on_area_entered(mine)
	await get_tree().process_frame

	assert(player.ram_absorb_charges_remaining == 0, "Spiked Iron Prow charge must be consumed (0 remaining)")
	assert(player.current_health == initial_hp, "Player must take 0 damage from mine ram. HP: %d" % player.current_health)
	assert(player.hit_invulnerability_timer > 0.0, "Hit invulnerability timer must be active (>=0.6s) to nullify splash")

	# Simulate subsequent splash / leak threat triggering during that frame/window
	player.leak_threat(null)
	assert(player.current_health == initial_hp, "Explosion splash / leak threat must be completely nullified. HP: %d" % player.current_health)
	print("  [PASS] Spiked Iron Prow cleanly absorbs sea mine ram (both contact and explosion splash nullified with 0 damage)")
	player.queue_free()
	await get_tree().process_frame

func _test_phase_c_shipyard_outfitting_ui() -> void:
	print("\n--- 4. Testing Phase C: Shipyard UI Outfitting Tab & Cards ---")

	var shipyard_scene = load("res://src/ui/shipyard/shipyard_ui.tscn") as PackedScene
	assert(shipyard_scene != null, "shipyard_ui.tscn must exist")
	var shipyard = shipyard_scene.instantiate()
	add_child(shipyard)
	await get_tree().process_frame

	assert(shipyard.tab_outfitting != null, "TabOutfitting button must be present in shipyard_ui")
	assert(shipyard.tab_outfitting.text == "OUTFITTING", "TabOutfitting text must be 'OUTFITTING'")

	# Switch to Outfitting Tab
	shipyard._on_tab_outfitting_pressed()
	await get_tree().process_frame
	assert(shipyard.current_tab == ShipyardUIScript.TabType.OUTFITTING, "Current tab must be TabType.OUTFITTING")
	assert(shipyard.drawer_panel.visible == false, "Drawer panel must be hidden on Outfitting tab")
	assert(shipyard.outfitting_card_instances.size() >= 8, "All catalog items must have generated cards in grid. Found: %d" % shipyard.outfitting_card_instances.size())

	var salt_card = shipyard.outfitting_card_instances.get("spectral_salt")
	assert(salt_card != null, "Spectral salt card must exist in grid")
	assert(salt_card.item_id == "spectral_salt", "Card item_id must match")
	print("  [PASS] Shipyard UI Outfitting tab and cards properly rendered and wired")
	shipyard.queue_free()

func _test_phase_d_action_mobs_and_economy() -> void:
	print("\n--- 5. Testing Phase D: Action Mobs & Economy Integrity ---")

	var fodder_scene = load("res://src/gameplay/enemies/enemy_fodder_skiff.tscn") as PackedScene
	assert(fodder_scene != null, "enemy_fodder_skiff.tscn must exist")

	var fodder = fodder_scene.instantiate()
	add_child(fodder)
	await get_tree().process_frame

	assert(fodder.max_hp == 1, "Fodder skiff must have 1 max_hp")
	assert(fodder.current_hp == 1, "Fodder skiff must have 1 current_hp")
	assert(fodder.doubloons_drop == 0, "Fodder skiff doubloons_drop must strictly be 0")
	assert(fodder.is_in_group("fodder"), "Fodder skiff must be in 'fodder' group")

	# Economy Integrity Check: Destroying fodder awards exactly 0 coins
	var initial_coins = GameState.doubloons
	var initial_run_coins = GameState.run_doubloons
	var collectible_count_before = get_tree().get_nodes_in_group("doubloons").size()

	fodder.take_damage(1)
	await get_tree().process_frame

	var collectible_count_after = get_tree().get_nodes_in_group("doubloons").size()
	assert(GameState.doubloons == initial_coins, "Doubloons purse must NOT increase upon fodder destruction")
	assert(GameState.run_doubloons == initial_run_coins, "Run doubloons must NOT increase upon fodder destruction")
	assert(collectible_count_after == collectible_count_before, "Zero doubloon collectibles should spawn from fodder destruction")
	print("  [PASS] Economy Integrity strictly verified: 1 HP fodder skiff awards 0 doubloons and spawns 0 coins")

func _test_phase_d_fire_frenzy_streak_and_timer_refresh() -> void:
	print("\n--- 6. Testing Phase D: Fire Frenzy Streak & Timer Refresh ---")

	var player_scene = load("res://src/gameplay/player/player_boat.tscn") as PackedScene
	var player = player_scene.instantiate()
	add_child(player)
	GameState.is_game_active = true

	# Reset state
	GameState.fodder_kill_timestamps.clear()
	player.fire_frenzy_timer = 0.0
	player.fire_rate_multiplier = 1.0

	var frenzy_fired = [false]
	var frenzy_conn = func(dur): frenzy_fired[0] = true
	GameState.fire_frenzy_triggered.connect(frenzy_conn)

	# 3 rapid fodder kills within 2.0s triggers Fire Frenzy
	GameState.record_fodder_kill()
	GameState.record_fodder_kill()
	assert(frenzy_fired[0] == false, "Frenzy should not fire before 3 kills")

	GameState.record_fodder_kill()
	await get_tree().process_frame
	assert(frenzy_fired[0] == true, "3 rapid kills must trigger fire_frenzy_triggered")
	assert(player.fire_frenzy_timer > 2.0, "Player frenzy timer should be initialized to 2.5s. Value: %f" % player.fire_frenzy_timer)
	assert(player.fire_rate_multiplier == 1.25, "Fire rate multiplier must be 1.25 (+25%% fire rate)")
	print("  [PASS] 3-kill streak successfully triggered Fire Frenzy (1.25x fire rate, 2.5s duration)")

	# Frenzy Timer Refresh Test:
	# "If a new 3-kill streak occurs while Fire Frenzy is active, refresh the 2.5s timer rather than compounding the fire rate multiplier."
	player.fire_frenzy_timer = 0.8 # Simulate timer counting down to 0.8s
	assert(player.fire_rate_multiplier == 1.25, "Multiplier is 1.25")

	# Trigger another 3-kill streak
	GameState.record_fodder_kill()
	GameState.record_fodder_kill()
	GameState.record_fodder_kill()
	await get_tree().process_frame

	assert(player.fire_frenzy_timer > 2.4, "Frenzy timer must refresh to 2.5s (was 0.8s). Current: %f" % player.fire_frenzy_timer)
	assert(player.fire_rate_multiplier == 1.25, "Fire rate multiplier must remain 1.25 (strictly non-compounding)")
	print("  [PASS] Fire Frenzy timer refresh verified: refreshed to 2.5s without compounding fire rate multiplier")

	# Timer expiration returns multiplier to 1.0
	player._physics_process(2.6)
	assert(player.fire_frenzy_timer == 0.0, "Timer expires after duration")
	assert(player.fire_rate_multiplier == 1.0, "Fire rate multiplier resets to 1.0 on timer expiration")
	print("  [PASS] Fire Frenzy properly resets to baseline 1.0 upon timer expiration")

	GameState.fire_frenzy_triggered.disconnect(frenzy_conn)
	player.queue_free()

func _test_phase_d_levels_and_chunk_integration() -> void:
	print("\n--- 7. Testing Phase D: Levels & Chunk Swarm Integration ---")

	# A. Chunk Fodder Swarm instantiation
	var chunk_scene = load("res://src/gameplay/chunks/chunk_fodder_swarm.tscn") as PackedScene
	assert(chunk_scene != null, "chunk_fodder_swarm.tscn must exist")
	var chunk = chunk_scene.instantiate()
	add_child(chunk)
	await get_tree().process_frame

	var fodder_mobs = []
	for child in chunk.get_node("Entities").get_children():
		if child is EnemyFodderSkiffScript or child.is_in_group("fodder"):
			fodder_mobs.append(child)
	assert(fodder_mobs.size() >= 7, "chunk_fodder_swarm must contain dense swarm waves (>= 7). Found: %d" % fodder_mobs.size())
	print("  [PASS] chunk_fodder_swarm.tscn instantiated with %d dense fodder skiffs" % fodder_mobs.size())
	chunk.queue_free()

	# B. Verify Swarm Threat levels include chunk_fodder_swarm.tscn
	for lvl in [17, 19, 21, 23]:
		var path = "res://src/data/resources/levels/level_%02d.tres" % lvl
		var lvl_res = load(path) as LevelData
		assert(lvl_res != null, "Level resource %s must load" % path)
		
		var has_fodder_chunk = false
		for c_scene in lvl_res.chunk_scenes:
			if c_scene and "chunk_fodder_swarm" in c_scene.resource_path:
				has_fodder_chunk = true
				break
		assert(has_fodder_chunk == true, "Level %d must include chunk_fodder_swarm.tscn" % lvl)
	print("  [PASS] Swarm Threat levels verified to contain chunk_fodder_swarm.tscn")
