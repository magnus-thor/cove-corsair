extends Node

var passed_count: int = 0
var total_count: int = 0

func assert_test(condition: bool, test_name: String) -> void:
	total_count += 1
	if condition:
		passed_count += 1
		print("[PASS] " + test_name)
	else:
		printerr("[FAIL] " + test_name)
		push_error("Assertion failed: " + test_name)

func _ready() -> void:
	print("\n========================================================")
	print("  VERIFYING BOMBARD SKIFF IN LEVEL 4 & SCATTERSHOT SPREAD  ")
	print("========================================================\n")

	# 1. Setup GameState for Level 4 & Bombard Skiff
	GameState.doubloons = 10000
	GameState.buy_vessel("bombard_skiff")
	GameState.equip_vessel("bombard_skiff")
	GameState.vessel_tiers["bombard_skiff"] = 1
	GameState.select_level(4)

	assert_test(GameState.active_vessel == "bombard_skiff", "Active vessel is 'bombard_skiff'")
	assert_test(GameState.current_level == 4, "Current level is 4")

	# 2. Instantiate Level 4 with PlayerBoat
	var main_scene = load("res://src/core/main_game.tscn")
	var main_game = main_scene.instantiate()
	add_child(main_game)

	# Ensure game is active and shooting enabled
	GameState.is_game_active = true
	var player = get_tree().get_first_node_in_group("player") as PlayerSwerve
	assert_test(player != null, "Player node found in group 'player'")
	assert_test(player.ship_data != null and player.ship_data.ship_id == "bombard_skiff", "Player equipped with Bombard Skiff ShipData")
	assert_test(player.current_tier == 1, "Player boat is at Tier 1")
	assert_test(player.equipped_weapons.has("BowMortarMount"), "Tier 1 equips BowMortarMount")

	# 3. Simulate Level 4 Barricade AoE Mortar Impact
	# Create two barricades side-by-side (2.0m apart, within 3.5m splash radius)
	var barricade_scene = load("res://src/gameplay/obstacles/barricade_segment.tscn")
	var b1 = barricade_scene.instantiate()
	var b2 = barricade_scene.instantiate()
	main_game.add_child(b1)
	main_game.add_child(b2)
	b1.global_position = Vector3(0.0, 0.5, -12.0)
	b2.global_position = Vector3(2.0, 0.5, -12.0)

	var b1_initial_hp = b1.hp
	var b2_initial_hp = b2.hp

	var bow_mortar = player.equipped_weapons.get("BowMortarMount") as AttachedWeapon
	assert_test(bow_mortar != null, "BowMortarMount weapon instance is active")

	# Fire heavy mortar forward
	bow_mortar._execute_fire(bow_mortar.projectile_scene, main_game)

	# Find the mortar ball
	var mortar_ball: Cannonball = null
	for child in main_game.get_children():
		if child is Cannonball and not child.is_queued_for_deletion():
			mortar_ball = child
			break

	assert_test(mortar_ball != null, "Mortar ball spawned into world")
	if mortar_ball:
		assert_test(mortar_ball.damage == 5, "Mortar shell has 5 direct damage")
		assert_test(mortar_ball.ammo_data != null and mortar_ball.ammo_data.aoe_damage == 3, "Mortar shell has 3 AoE damage")
		assert_test(mortar_ball.ammo_data != null and mortar_ball.ammo_data.splash_radius == 3.5, "Mortar shell has 3.5m splash radius")

		# Simulate direct hit on b1
		mortar_ball.global_position = b1.global_position
		mortar_ball._on_hit(b1)

		assert_test(b1.hp == b1_initial_hp - 5, "Direct hit obstacle b1 took 5 direct damage")
		assert_test(b2.hp == b2_initial_hp - 3, "Adjacent obstacle b2 (2.0m away) took 3 AoE splash damage")

	b1.queue_free()
	b2.queue_free()

	# 4. Upgrade to Tier 3 and verify Scattershot Carronades
	print("\n--- Upgrading Bombard Skiff to Tier 3 ---")
	GameState.upgrade_vessel_tier("bombard_skiff")
	GameState.upgrade_vessel_tier("bombard_skiff")
	assert_test(GameState.get_vessel_tier("bombard_skiff") == 3, "Bombard Skiff upgraded to Tier 3 in GameState")

	player.apply_tier(3)
	assert_test(player.current_tier == 3, "Player boat applied Tier 3")
	assert_test(player.equipped_weapons.has("BowMortarMount"), "Tier 3 has BowMortarMount")
	assert_test(player.equipped_weapons.has("QuarterdeckCrew"), "Tier 3 has QuarterdeckCrew")
	assert_test(player.equipped_weapons.has("PortRailMount"), "Tier 3 has PortRailMount")
	assert_test(player.equipped_weapons.has("StarboardRailMount"), "Tier 3 has StarboardRailMount")

	var port_w = player.equipped_weapons.get("PortRailMount") as AttachedWeapon
	var stbd_w = player.equipped_weapons.get("StarboardRailMount") as AttachedWeapon
	assert_test(port_w != null and port_w.weapon_data.weapon_type == "scattershot", "PortRailMount is Scattershot Carronade")
	assert_test(stbd_w != null and stbd_w.weapon_data.weapon_type == "scattershot", "StarboardRailMount is Scattershot Carronade")

	# Fire PortRailMount
	port_w.fire_scattershot(Vector3.ZERO, main_game)
	var port_pellets: Array = []
	for child in main_game.get_children():
		if child is Cannonball and child.is_inside_tree() and not child.is_queued_for_deletion():
			port_pellets.append(child)

	assert_test(port_pellets.size() == 5, "Port Scattershot Carronade fired 5 pellets simultaneously")
	var port_all_left = true
	for p in port_pellets:
		if p.direction.x >= 0.0:
			port_all_left = false
		p.queue_free()
	assert_test(port_all_left, "All Port pellets spray outward into the adjacent PORT (left) lane")

	# Fire StarboardRailMount
	stbd_w.fire_scattershot(Vector3.ZERO, main_game)
	var stbd_pellets: Array = []
	for child in main_game.get_children():
		if child is Cannonball and child.is_inside_tree() and not child.is_queued_for_deletion():
			stbd_pellets.append(child)

	assert_test(stbd_pellets.size() == 5, "Starboard Scattershot Carronade fired 5 pellets simultaneously")
	var stbd_all_right = true
	for p in stbd_pellets:
		if p.direction.x <= 0.0:
			stbd_all_right = false
		p.queue_free()
	assert_test(stbd_all_right, "All Starboard pellets spray outward into the adjacent STARBOARD (right) lane")

	main_game.queue_free()

	print("\n========================================================")
	print("  TEST RESULTS: %d / %d PASSED  " % [passed_count, total_count])
	print("========================================================\n")

	if passed_count == total_count:
		print(">>> LEVEL 4 & SCATTERSHOT VERIFICATION COMPLETE! <<<\n")
		get_tree().quit(0)
	else:
		printerr(">>> SOME TESTS FAILED! <<<\n")
		get_tree().quit(1)
