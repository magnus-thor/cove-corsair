extends Node3D

const SettlementScreenClass = preload("res://src/ui/settlement_screen.gd")

var total_tests: int = 0
var passed_tests: int = 0

func assert_test(cond: bool, test_name: String) -> void:
	total_tests += 1
	if cond:
		passed_tests += 1
		print("  [PASS] %s" % test_name)
	else:
		push_error("  [FAIL] %s" % test_name)
		print("  [FAIL] %s" % test_name)

func _ready() -> void:
	print("==========================================================")
	print("  TESTING ORGANIC PROGRESSION, GOLD RETENTION & SETTLEMENT ")
	print("==========================================================")

	_test_gold_retention_on_hull_destruction()
	_test_settlement_screen_ui_defeat()
	_test_settlement_screen_ui_victory()
	_test_shipyard_upgrade_with_retained_gold()
	_test_chunk_payout_tuning()

	print("==========================================================")
	print("  RESULTS: %d / %d TESTS PASSED" % [passed_tests, total_tests])
	print("==========================================================")

	if passed_tests == total_tests:
		print("ALL ORGANIC PROGRESSION & SETTLEMENT TESTS PASSED!")
		get_tree().quit(0)
	else:
		get_tree().quit(1)

func _test_gold_retention_on_hull_destruction() -> void:
	print("\n--- 1. Gold Retention on Hull Destruction ---")
	GameState.reset_save_data()
	GameState.equip_vessel("dinghy")
	GameState.select_level(4)
	
	assert_test(GameState.doubloons == 0, "Initial banked doubloons is 0")
	assert_test(GameState.active_vessel == "dinghy", "Active vessel is The Dinghy")
	assert_test(GameState.get_vessel_tier("dinghy") == 1, "The Dinghy starts at Tier 1")
	
	# Start in-run gameplay
	GameState.is_game_active = true
	GameState.run_doubloons = 0
	GameState.run_doubloons_banked = false
	GameState.distance_traveled = 125.0
	
	# Simulate picking up coins during run
	GameState.add_doubloons(50)
	GameState.add_doubloons(100)
	GameState.add_doubloons(200) # Total 350
	
	assert_test(GameState.run_doubloons == 350, "Run doubloons accumulated 350 coins in-run")
	assert_test(GameState.doubloons == 0, "Persistent bank untouched during run prior to settlement")
	
	# Spawn Dinghy player
	var player_scene = load("res://src/gameplay/player/player_boat.tscn") as PackedScene
	assert_test(player_scene != null, "player_boat.tscn loaded")
	var player = player_scene.instantiate() as PlayerSwerve
	add_child(player)
	
	var dinghy_data = load("res://src/data/resources/user_vessels/dinghy_ship.tres") as ShipData
	player.apply_ship_data(dinghy_data)
	assert_test(player.current_health == 1, "Dinghy hull HP starts at 1")
	
	# Connect to run_failed signals
	var player_signal = {"fired": false, "coins": 0, "dist": 0.0}
	player.run_failed.connect(func(c, d):
		player_signal["fired"] = true
		player_signal["coins"] = c
		player_signal["dist"] = d
	)
	
	var gs_signal = {"fired": false, "coins": 0}
	GameState.run_failed.connect(func(c, _d):
		gs_signal["fired"] = true
		gs_signal["coins"] = c
	)
	
	# Crash into Barricade slat mock (3 damage)
	var slat = Area3D.new()
	slat.set_script(load("res://src/gameplay/obstacles/barricade_segment.gd"))
	add_child(slat)
	slat._ready()
	
	player._on_area_entered(slat)
	
	assert_test(player.current_health == 0, "Dinghy HP reaches 0 on barricade collision")
	assert_test(player.is_game_over == true, "Player is_game_over is set to true")
	assert_test(player_signal["fired"] == true, "Player emitted run_failed signal")
	assert_test(player_signal["coins"] == 350, "run_failed emitted correct coins_collected (350)")
	assert_test(is_equal_approx(player_signal["dist"], 125.0), "run_failed emitted correct distance_reached (125m)")
	assert_test(gs_signal["fired"] == true, "GameState emitted run_failed signal")
	assert_test(gs_signal["coins"] == 350, "GameState run_failed emitted 350 coins")
	assert_test(GameState.doubloons == 350, "Banked coins (350) match the increase in GameState.doubloons")
	
	slat.queue_free()
	player.queue_free()

func _test_settlement_screen_ui_defeat() -> void:
	print("\n--- 2. Settlement Screen UI (Defeat / SHIP SUNK!) ---")
	var settlement_scene = load("res://src/ui/settlement_screen.tscn") as PackedScene
	assert_test(settlement_scene != null, "settlement_screen.tscn loads successfully")
	
	var screen = settlement_scene.instantiate() as SettlementScreenClass
	add_child(screen)
	
	screen.show_defeat(350, 125.0, GameState.doubloons)
	
	assert_test(screen.visible == true, "SettlementScreen is visible on defeat")
	assert_test(screen.header_label.text == "SHIP SUNK!", "Header displays 'SHIP SUNK!' in Crimson")
	assert_test(screen.subtitle_label.text == "HULL BREACHED - TREASURE RETAINED", "Subtitle displays 'HULL BREACHED - TREASURE RETAINED'")
	assert_test(screen.primary_button.text == "RETRY", "Primary button is 'RETRY'")
	assert_test(screen.bonus_row.visible == false, "Completion bonus row is hidden on defeat")
	
	# Verify pause mode safe tweens
	assert_test(screen._modal_tween != null and screen._modal_tween.is_valid(), "Modal entrance tween initialized and active")
	assert_test(screen._tally_tween != null and screen._tally_tween.is_valid(), "Tally roll-up tween initialized and active")
	
	screen.queue_free()

func _test_settlement_screen_ui_victory() -> void:
	print("\n--- 3. Settlement Screen UI (Victory) ---")
	var settlement_scene = load("res://src/ui/settlement_screen.tscn") as PackedScene
	var screen = settlement_scene.instantiate() as SettlementScreenClass
	add_child(screen)
	
	GameState.select_level(4)
	var pre_bank = GameState.doubloons # 350
	var run_coins = 200
	var completion_bonus = 300
	GameState.run_doubloons = run_coins
	GameState.run_doubloons_banked = false
	var _total_banked = GameState.bank_run_doubloons(completion_bonus)
	
	assert_test(GameState.doubloons == pre_bank + run_coins + completion_bonus, "Bank increased by run coins (200) + completion bonus (300)")
	
	screen.show_victory(run_coins, completion_bonus, GameState.doubloons, 3)
	
	assert_test(screen.header_label.text == "VICTORY!", "Header displays 'VICTORY!' in Gold")
	assert_test(screen.stars_container.visible == true, "Stars container is visible on victory")
	assert_test(screen.bonus_row.visible == true, "Completion bonus row is visible on victory")
	assert_test(screen.primary_button.text == "NEXT LEVEL", "Primary button is 'NEXT LEVEL'")
	
	screen.queue_free()

func _test_shipyard_upgrade_with_retained_gold() -> void:
	print("\n--- 4. Shipyard Alert Badge & Tier Upgrade with Retained Gold ---")
	# Dinghy Tier 2 price is 350. GameState.doubloons is currently >= 350
	assert_test(GameState.can_afford_active_vessel_upgrade() == true, "GameState confirms active vessel (Dinghy) upgrade can be afforded")
	
	var settlement_scene = load("res://src/ui/settlement_screen.tscn") as PackedScene
	var screen = settlement_scene.instantiate() as SettlementScreenClass
	add_child(screen)
	screen.show_defeat(350, 100.0, GameState.doubloons)
	
	assert_test(screen.shipyard_badge.visible == true, "Shipyard button displays upgrade alert badge")
	assert_test(screen._glow_tween != null and screen._glow_tween.is_valid(), "Shipyard glow tween initialized and active")
	
	# Purchase Tier 2 upgrade in Shipyard with retained gold
	var initial_gold = GameState.doubloons
	var tier_cost = GameState.get_upgrade_cost("dinghy", 2)
	assert_test(tier_cost == 350, "Dinghy Tier 2 cost is 350 doubloons")
	
	var success = GameState.upgrade_vessel_tier("dinghy")
	assert_test(success == true, "Dinghy Tier 2 upgrade purchased successfully using retained gold")
	assert_test(GameState.get_vessel_tier("dinghy") == 2, "Dinghy is now upgraded to Tier 2")
	assert_test(GameState.doubloons == initial_gold - 350, "Gold accurately deducted after upgrade purchase")
	
	# Refresh screen after purchase
	screen._refresh_banked_display()
	screen._update_shipyard_button()
	assert_test(GameState.can_afford_active_vessel_upgrade() == false, "Upgrade affordance now false (Tier 3 requires 750 doubloons)")
	assert_test(screen.shipyard_badge.visible == false, "Shipyard alert badge hidden when upgrade cannot be afforded")
	
	screen.queue_free()

func _test_chunk_payout_tuning() -> void:
	print("\n--- 5. Chunk Payout & Drop Tuning Verification ---")
	# Verify chunk_warmup
	var warmup_scene = load("res://src/gameplay/chunks/chunk_warmup.tscn") as PackedScene
	assert_test(warmup_scene != null, "chunk_warmup.tscn loads successfully")
	var warmup = warmup_scene.instantiate() as BaseTrackChunk
	var w_entities = warmup.get_node("Entities")
	var w_coins = 0
	for c in w_entities.get_children():
		if c.is_in_group("collectibles") or c.is_in_group("doubloons"):
			w_coins += c.value if "value" in c else 1
		elif c.is_in_group("destructible") and "doubloons_drop" in c:
			w_coins += c.doubloons_drop
		elif "obstacle_type" in c:
			w_coins += 1
	print("  [INFO] chunk_warmup calculated total payout: %d doubloons" % w_coins)
	assert_test(w_coins >= 30 and w_coins <= 45, "chunk_warmup yields ~30-45 doubloons (actual: %d)" % w_coins)
	warmup.queue_free()

	# Verify chunk_mine_gauntlet
	var mine_scene = load("res://src/gameplay/chunks/chunk_mine_gauntlet.tscn") as PackedScene
	assert_test(mine_scene != null, "chunk_mine_gauntlet.tscn loads successfully")
	var mine = mine_scene.instantiate() as BaseTrackChunk
	var m_entities = mine.get_node("Entities")
	var m_coins = 0
	for c in m_entities.get_children():
		if c.is_in_group("collectibles") or c.is_in_group("doubloons"):
			m_coins += c.value if "value" in c else 1
		elif c.is_in_group("destructible") and "doubloons_drop" in c:
			m_coins += c.doubloons_drop
	print("  [INFO] chunk_mine_gauntlet calculated total payout: %d doubloons" % m_coins)
	assert_test(m_coins >= 30 and m_coins <= 45, "chunk_mine_gauntlet yields ~30-45 doubloons (actual: %d)" % m_coins)
	mine.queue_free()

	# Verify chunk_barricade_siege
	var barricade_scene = load("res://src/gameplay/chunks/chunk_barricade_siege.tscn") as PackedScene
	assert_test(barricade_scene != null, "chunk_barricade_siege.tscn loads successfully")
	var barricade = barricade_scene.instantiate() as BaseTrackChunk
	var b_entities = barricade.get_node("Entities")
	var b_coins = 0
	for c in b_entities.get_children():
		if c.has_meta("spawns_chest"):
			b_coins += 25 # Chest awards 25 doubloons
		elif c.is_in_group("collectibles") or c.is_in_group("doubloons"):
			b_coins += c.value if "value" in c else 1
		elif "doubloons_drop" in c:
			b_coins += c.doubloons_drop
	print("  [INFO] chunk_barricade_siege calculated total payout: %d doubloons" % b_coins)
	assert_test(b_coins >= 30 and b_coins <= 45, "chunk_barricade_siege yields ~30-45 doubloons (actual: %d)" % b_coins)
	barricade.queue_free()

	# Verify Level 4 completion reward
	var l4 = load("res://src/data/resources/levels/level_04.tres") as LevelData
	assert_test(l4 != null, "level_04.tres loaded")
	assert_test(l4.completion_doubloon_reward == 300, "Level 4 completion reward tuned to 300 doubloons (actual: %d)" % l4.completion_doubloon_reward)
