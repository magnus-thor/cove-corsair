extends Node3D

## Verification suite for Campaign Master Balancing & Progression adjustments

var passed_count: int = 0
var failed_count: int = 0

func assert_test(cond: bool, test_name: String) -> void:
	if cond:
		passed_count += 1
		print("  [PASS] %s" % test_name)
	else:
		failed_count += 1
		printerr("  [FAIL] %s" % test_name)

func _ready() -> void:
	print("==========================================================")
	print("  TESTING CAMPAIGN BALANCING SPECIFICATION (ALL 6 TASKS)  ")
	print("==========================================================")

	test_barricade_segment_die_collision()
	test_camera_trauma_and_fire_cap()
	test_level_2_boss_ironjaw_and_properties()
	test_phantom_dredge_tuning()
	test_rune_barrel_level_gating()
	test_vessel_stats_and_economy_matrix()
	test_settlement_2x_bonus_button()

	print("==========================================================")
	print("  TOTAL RESULTS: %d / %d PASSED" % [passed_count, passed_count + failed_count])
	print("==========================================================")

	if failed_count == 0:
		print("ALL CAMPAIGN BALANCING VERIFICATION TESTS PASSED!")
		get_tree().quit(0)
	else:
		printerr("SOME TESTS FAILED!")
		get_tree().quit(1)

func test_barricade_segment_die_collision() -> void:
	print("\n--- 1. Barricade Segment Die Collision Disabling ---")
	var seg_scene = load("res://src/gameplay/obstacles/barricade_segment.tscn") as PackedScene
	assert_test(seg_scene != null, "barricade_segment.tscn loads")
	var seg = seg_scene.instantiate() as BarricadeSegment
	add_child(seg)
	seg._ready()

	var col = seg.get_node_or_null("CollisionShape3D") as CollisionShape3D
	assert_test(col != null, "CollisionShape3D exists on segment")
	assert_test(col.disabled == false, "CollisionShape3D is initially enabled")
	assert_test(seg.monitoring == true, "Segment monitoring is initially enabled")
	assert_test(seg.monitorable == true, "Segment monitorable is initially enabled")

	seg.die()
	assert_test(seg.collision_layer == 0, "Segment collision_layer set to 0 immediately on die()")
	assert_test(seg.collision_mask == 0, "Segment collision_mask set to 0 immediately on die()")
	assert_test(seg.is_queued_for_deletion(), "Segment is queued for deletion on die()")

	# Pass-by leak_threat safety test
	var mock_player = Node3D.new()
	mock_player.add_to_group("player")
	var p_script = GDScript.new()
	p_script.source_code = "extends Node3D\nvar leak_calls: int = 0\nfunc leak_threat(_threat): leak_calls += 1\n"
	p_script.reload()
	mock_player.set_script(p_script)
	add_child(mock_player)
	mock_player.global_position = Vector3.ZERO

	var pass_seg = seg_scene.instantiate() as BarricadeSegment
	add_child(pass_seg)
	pass_seg._ready()
	pass_seg.global_position = Vector3(2.0, 0.0, 5.0) # 5m past player_z
	pass_seg._physics_process(0.016)
	assert_test(mock_player.get("leak_calls") == 0, "Intact BarricadeSegment passing player does NOT call leak_threat")
	assert_test(not pass_seg.is_queued_for_deletion(), "Intact BarricadeSegment not prematurely freed (+5m behind player)")

	var barrel_scene = load("res://src/gameplay/obstacles/destructible_barrel.tscn") as PackedScene
	if barrel_scene:
		var barrel = barrel_scene.instantiate() as DestructibleObstacle
		add_child(barrel)
		barrel.obstacle_type = DestructibleObstacle.ObstacleType.WOODEN_BARREL
		barrel._ready()
		barrel.global_position = Vector3(-2.0, 0.0, 5.0)
		barrel._physics_process(0.016)
		assert_test(mock_player.get("leak_calls") == 0, "Wooden barrel passing player does NOT call leak_threat")
		barrel.queue_free()

	pass_seg.queue_free()
	mock_player.queue_free()

func test_camera_trauma_and_fire_cap() -> void:
	print("\n--- 2. Camera Trauma Decay & Rapid Fire Guard ---")
	var cam_scene = load("res://src/core/game_camera.gd")
	var cam = Camera3D.new()
	cam.set_script(cam_scene)
	add_child(cam)
	cam._ready()

	assert_test(is_equal_approx(cam.trauma_reduction_rate, 2.8), "Camera trauma reduction rate is 2.8 (snappy decay)")

	# Test rapid fire cap
	cam.trauma = 0.0
	cam.add_trauma(0.08, 0.35)
	assert_test(is_equal_approx(cam.trauma, 0.08), "Initial fire adds 0.08 trauma")

	# Fire repeatedly past cap
	for i in range(10):
		cam.add_trauma(0.08, 0.35)
	assert_test(is_equal_approx(cam.trauma, 0.35), "Continuous cannon fire capped at 0.35 trauma")

	# Heavy hits can still exceed 0.35 up to 1.0
	cam.add_trauma(0.5)
	assert_test(cam.trauma > 0.35, "Heavy impact adds trauma beyond 0.35 cap (trauma: %.2f)" % cam.trauma)

	cam.queue_free()

func test_level_2_boss_ironjaw_and_properties() -> void:
	print("\n--- 3. Level 2 Boss (Ironjaw) & Palm Shallows Config ---")
	var l2 = load("res://src/data/resources/levels/level_02.tres") as LevelData
	assert_test(l2 != null, "level_02.tres loaded")
	assert_test(l2.level_title == "Level 2: Palm Shallows", "Level 2 title is 'Level 2: Palm Shallows'")
	assert_test(is_equal_approx(l2.base_scroll_speed, 7.0), "Level 2 scroll speed is 7.0 m/s")
	assert_test(l2.completion_doubloon_reward == 65, "Level 2 reward is 65 doubloons")

	# Verify final chunk is Ironjaw
	var last_chunk_scene = l2.chunk_scenes[l2.chunk_scenes.size() - 1]
	var last_chunk = last_chunk_scene.instantiate() as BaseTrackChunk
	assert_test(last_chunk.chunk_id == "boss_ironjaw", "Level 2 final chunk is 'boss_ironjaw'")

	# Test Ironjaw HP on Level 2
	GameState.current_level = 2
	var boss_scene = last_chunk.boss_scene
	assert_test(boss_scene != null, "Ironjaw boss_scene is assigned")
	var boss = boss_scene.instantiate() as BossWarBarge
	add_child(boss)
	boss._ready()
	assert_test(boss.max_hp == 35, "Ironjaw War-Barge has 35 max HP on Level 2 (actual: %d)" % boss.max_hp)
	assert_test(boss.current_hp == 35, "Ironjaw War-Barge has 35 current HP on Level 2 (actual: %d)" % boss.current_hp)

	# Test minion suppression on Level 2
	var prev_enemies = get_tree().get_nodes_in_group("enemies").size()
	boss._deploy_side_minions()
	var post_enemies = get_tree().get_nodes_in_group("enemies").size()
	assert_test(post_enemies == prev_enemies, "Ironjaw spawns 0 minion adds on Level 2")

	boss.queue_free()
	last_chunk.queue_free()

func test_phantom_dredge_tuning() -> void:
	print("\n--- 4. Boss Phantom Dredge Telegraph & Minion Cap ---")
	var dredge_scene = load("res://src/gameplay/enemies/boss_phantom_dredge.tscn") as PackedScene
	assert_test(dredge_scene != null, "boss_phantom_dredge.tscn loaded")
	var dredge = dredge_scene.instantiate() as BossPhantomDredge
	add_child(dredge)
	dredge._ready()

	# Create 2 mock enemies
	var mock1 = Area3D.new()
	mock1.add_to_group("enemies")
	add_child(mock1)
	var mock2 = Area3D.new()
	mock2.add_to_group("enemies")
	add_child(mock2)

	var enemy_count_before = get_tree().get_nodes_in_group("enemies").filter(func(e): return is_instance_valid(e) and not e.is_in_group("boss")).size()
	assert_test(enemy_count_before >= 2, "2 active non-boss enemies present in scene")

	# Summon adds while 2 enemies are active
	dredge._spawn_bayou_adds()
	var enemy_count_after = get_tree().get_nodes_in_group("enemies").filter(func(e): return is_instance_valid(e) and not e.is_in_group("boss")).size()
	assert_test(enemy_count_after == enemy_count_before, "Phantom Dredge respects hard cap: cannot spawn adds when >= 2 enemies active")

	mock1.queue_free()
	mock2.queue_free()
	dredge.queue_free()

func test_rune_barrel_level_gating() -> void:
	print("\n--- 5. Rune Barrel Level-Gating (Chest vs Inline Coins) ---")
	var barrel_scene = load("res://src/gameplay/obstacles/destructible_barrel.tscn") as PackedScene
	assert_test(barrel_scene != null, "destructible_barrel.tscn loaded")

	# Case A: Level < 5 -> Drops 3 inline coins
	GameState.current_level = 2
	var barrel_l2 = barrel_scene.instantiate() as DestructibleObstacle
	add_child(barrel_l2)
	barrel_l2.obstacle_type = DestructibleObstacle.ObstacleType.RUNE_BARREL
	barrel_l2.update_obstacle_visuals()

	# Count collectible chests before
	var chests_before = get_tree().get_nodes_in_group("collectibles").filter(func(c): return c is CollectibleChest).size()
	barrel_l2.die()
	var chests_after_l2 = get_tree().get_nodes_in_group("collectibles").filter(func(c): return c is CollectibleChest).size()
	assert_test(chests_after_l2 == chests_before, "Rune Barrel on Level 2 does NOT spawn a treasure chest")

	# Case B: Level >= 5 -> Spawns 50 doubloon chest
	GameState.current_level = 5
	var barrel_l5 = barrel_scene.instantiate() as DestructibleObstacle
	add_child(barrel_l5)
	barrel_l5.obstacle_type = DestructibleObstacle.ObstacleType.RUNE_BARREL
	barrel_l5.update_obstacle_visuals()

	barrel_l5.die()
	var chests_after_l5 = get_tree().get_nodes_in_group("collectibles").filter(func(c): return c is CollectibleChest)
	assert_test(chests_after_l5.size() > chests_before, "Rune Barrel on Level 5 spawns a CollectibleChest")
	if not chests_after_l5.is_empty():
		var spawned_chest = chests_after_l5[chests_after_l5.size() - 1] as CollectibleChest
		assert_test(spawned_chest.chest_value == 50, "Rune Barrel spawned chest awards 50 doubloons (actual: %d)" % spawned_chest.chest_value)
		spawned_chest.queue_free()

func test_vessel_stats_and_economy_matrix() -> void:
	print("\n--- 6. Vessel Stats & Level Rewards Matrix ---")
	var dinghy = load("res://src/data/resources/user_vessels/dinghy_ship.tres") as ShipData
	assert_test(dinghy.max_health == 2, "Dinghy max_health is 2")
	assert_test(Array(dinghy.upgrade_costs) == [0, 250, 1000], "Dinghy upgrade_costs is [0, 250, 1000]")

	var sloop = load("res://src/data/resources/user_vessels/sloop_ship.tres") as ShipData
	assert_test(sloop.max_health == 4, "Sloop max_health is 4")
	assert_test(Array(sloop.upgrade_costs) == [500, 700, 1600], "Sloop upgrade_costs is [500, 700, 1600]")

	var catalog = GameState.VESSEL_CATALOG
	assert_test(catalog["dinghy"]["base_hp"] == 2, "Catalog Dinghy base_hp is 2")
	assert_test(catalog["dinghy"]["tier_prices"][2] == 250 and catalog["dinghy"]["tier_prices"][3] == 1000, "Catalog Dinghy tier prices: T2=250, T3=1000")
	assert_test(catalog["sloop"]["base_hp"] == 4, "Catalog Sloop base_hp is 4")
	assert_test(catalog["sloop"]["purchase_price"] == 500, "Catalog Sloop purchase price is 500")
	assert_test(catalog["sloop"]["tier_prices"][2] == 700 and catalog["sloop"]["tier_prices"][3] == 1600, "Catalog Sloop tier prices: T2=700, T3=1600")

	# Verify Level Rewards L1-L12
	var expected_rewards = {
		1: 50, 2: 65, 3: 75, 4: 85, 5: 100, 6: 90,
		7: 100, 8: 105, 9: 115, 10: 145, 11: 120, 12: 125
	}
	for lvl in range(1, 13):
		var path = GameState.LEVEL_RESOURCES[lvl]
		var ldata = load(path) as LevelData
		assert_test(ldata.completion_doubloon_reward == expected_rewards[lvl], "Level %d reward is %d doubloons (actual: %d)" % [lvl, expected_rewards[lvl], ldata.completion_doubloon_reward])

func test_settlement_2x_bonus_button() -> void:
	print("\n--- 7. Settlement Screen Opt-In 2X Bonus Doubloons ---")
	var screen_scene = load("res://src/ui/settlement_screen.tscn") as PackedScene
	assert_test(screen_scene != null, "settlement_screen.tscn loaded")
	var screen = screen_scene.instantiate() as SettlementScreen
	add_child(screen)

	# Defeat check: button hidden
	screen.show_defeat(100, 50.0, 1000)
	assert_test(screen.bonus_claim_button != null and screen.bonus_claim_button.visible == false, "BonusClaimButton hidden on defeat")

	# Victory check: button visible, claim doubles run payout
	GameState.doubloons = 500
	var run_drops = 150
	var clear_bonus = 65
	screen.show_victory(run_drops, clear_bonus, GameState.doubloons, 3)

	assert_test(screen.bonus_claim_button.visible == true, "BonusClaimButton visible on victory")
	assert_test(screen.bonus_claim_button.disabled == false, "BonusClaimButton initially enabled")
	assert_test(screen.bonus_claim_button.text == "✦ CLAIM 2X BONUS DOUBLOONS", "Initial button text is '✦ CLAIM 2X BONUS DOUBLOONS'")

	# Claim 2X bonus
	var pre_claim_gold = GameState.doubloons
	screen._on_bonus_claim_pressed()

	assert_test(screen.bonus_claim_button.disabled == true, "BonusClaimButton disabled after claim")
	assert_test(screen.bonus_claim_button.text == "BONUS CLAIMED! ✦", "Button text updated to 'BONUS CLAIMED! ✦'")
	assert_test(GameState.doubloons == pre_claim_gold + (run_drops + clear_bonus), "GameState banked gold increased by exactly run payout (doubled total: +%d)" % (run_drops + clear_bonus))

	# Re-click does nothing
	var post_claim_gold = GameState.doubloons
	screen._on_bonus_claim_pressed()
	assert_test(GameState.doubloons == post_claim_gold, "Double claim safely prevented")

	screen.queue_free()
