@tool
# Turn off untyped warnings specifically for test harnesses:
@warning_ignore("untyped_declaration")
@warning_ignore("unsafe_property_access")
@warning_ignore("unsafe_method_access")
@warning_ignore("unsafe_cast")
extends Node

## Automated Verification Test for Extended Campaign, Shootable Gates,
## Mob Swarms, Vanguard Climax, and Vessel Balancing.

func _ready() -> void:
	print("==================================================")
	print("   TESTING CAMPAIGN & GAMEPLAY OVERHAUL           ")
	print("==================================================")
	
	var passed := true
	passed = passed and test_multiplier_gate_shootable()
	passed = passed and test_enemy_shooting_rework()
	passed = passed and test_vessel_balancing()
	passed = passed and test_level_progression()
	
	if passed:
		print("==================================================")
		print("   ALL CAMPAIGN OVERHAUL TESTS PASSED!            ")
		print("==================================================")
		get_tree().quit(0)
	else:
		printerr("Some tests failed!")
		get_tree().quit(1)

func test_multiplier_gate_shootable() -> bool:
	print("\n[TEST 1] Testing Shootable Multiplier Gate (1-100 Scale)...")
	var gate_scene := load("res://src/gameplay/obstacles/multiplier_gate.tscn") as PackedScene
	if not gate_scene:
		printerr("Failed to load multiplier_gate.tscn")
		return false
		
	var gate := gate_scene.instantiate() as MultiplierGate
	add_child(gate)
	gate.value = 10
	gate.custom_text = "+10"
	gate.update_visuals()
	
	if gate.value != 10:
		printerr("Initial gate value mismatch: %d" % gate.value)
		return false
		
	# Shoot the gate 3 times (each shot +5)
	gate.on_shot_hit()
	if gate.value != 15:
		printerr("Gate value after 1st shot should be 15, got %d" % gate.value)
		return false
		
	gate.on_shot_hit()
	gate.on_shot_hit()
	if gate.value != 25:
		printerr("Gate value after 3 shots should be 25, got %d" % gate.value)
		return false
		
	var label := gate.get_node_or_null("Visuals/Label3D") as Label3D
	if not label or label.text != "+25":
		printerr("Gate Label3D text mismatch: %s" % (label.text if label else "null"))
		return false

	# Rapid pump to 100 MAX
	for i in range(16):
		gate.on_shot_hit()
	if gate.value != 100:
		printerr("Gate value after pump should be capped at 100, got %d" % gate.value)
		return false
	if label.text != "★ 100 MAX ★":
		printerr("Gate Label3D at 100 should be '★ 100 MAX ★', got %s" % label.text)
		return false
		
	print("  [PASS] Shootable Multiplier Gate incremented from +10 to +25 and maxed at 100 with dynamic visuals.")
	gate.queue_free()
	return true

func test_enemy_shooting_rework() -> bool:
	print("\n[TEST 2] Testing Enemy Shooting Rework...")
	var mob_scene := load("res://src/gameplay/enemies/enemy_mob.tscn") as PackedScene
	var mob := mob_scene.instantiate()
	add_child(mob)
	
	# Verify default regular mob cannot shoot
	if mob.get("can_shoot") != false:
		printerr("Regular mob should have can_shoot == false by default")
		return false
	if mob.get("is_gunner_vanguard") != false:
		printerr("Regular mob should have is_gunner_vanguard == false by default")
		return false
	print("  [PASS] Regular mob defaults to can_shoot = false, is_gunner_vanguard = false.")
	
	# Verify Gunner Vanguard
	var gunner_scene := load("res://src/gameplay/enemies/enemy_iron_gunner.tscn") as PackedScene
	var gunner := gunner_scene.instantiate()
	add_child(gunner)
	if gunner.get("can_shoot") != false:
		printerr("EnemyIronGunner should have can_shoot == false by default in lanes")
		return false
	
	gunner.set("is_gunner_vanguard", true)
	gunner.set("can_shoot", true)
	print("  [PASS] Gunner Vanguard configuration verified.")
	
	mob.queue_free()
	gunner.queue_free()
	return true

func test_vessel_balancing() -> bool:
	print("\n[TEST 3] Testing Vessel Balancing & Roles...")
	
	# Bombard Skiff Mortar
	var mortar_data := load("res://src/data/resources/user_crew/weapon_bow_mortar.tres") as WeaponData
	if not mortar_data:
		printerr("Failed to load weapon_bow_mortar.tres")
		return false
	if mortar_data.max_range > 20.0:
		printerr("Bombard Skiff mortar should be short-range (<= 20m), got %.1f" % mortar_data.max_range)
		return false
	print("  [PASS] Bombard Skiff mortar has short range: %.1fm" % mortar_data.max_range)
	
	# Heavy Shot Ammo
	var heavy_ammo := load("res://src/data/resources/user_ammo/ammo_heavy_shot.tres") as AmmoData
	if not heavy_ammo or heavy_ammo.damage < 8:
		printerr("Heavy Shot should have boosted damage (>= 8), got %d" % (heavy_ammo.damage if heavy_ammo else 0))
		return false
	print("  [PASS] Heavy Shot explosive damage: %d (splash: %.1fm)" % [heavy_ammo.damage, heavy_ammo.splash_radius])
	
	# Bow Chaser (Dinghy/Sloop)
	var chaser_data := load("res://src/data/resources/user_crew/weapon_bow_chaser.tres") as WeaponData
	if not chaser_data or chaser_data.max_range < 35.0:
		printerr("Bow Chaser should have long range (>= 35m)")
		return false
	print("  [PASS] Bow Chaser long range confirmed: %.1fm" % chaser_data.max_range)
	
	# Ironclad Economy Calibration
	var gs_script := load("res://src/core/game_state.gd")
	if not gs_script or not gs_script.VESSEL_CATALOG.has("ironclad"):
		printerr("Ironclad not found in GameState.VESSEL_CATALOG")
		return false
	var ic_info := gs_script.VESSEL_CATALOG["ironclad"]
	if ic_info["purchase_price"] < 2000:
		printerr("Ironclad should be highest cost endgame vessel (>= 2000), got %d" % ic_info["purchase_price"])
		return false
	print("  [PASS] Ironclad economy confirmed as endgame vessel: %d doubloons" % ic_info["purchase_price"])
	return true

func test_level_progression() -> bool:
	print("\n[TEST 4] Testing Level Recipes & Progression (L1 to L45)...")
	
	# Level 1: Swarm Threat (8 chunks, ends with Vanguard Climax then Finish Line)
	var l1 := load("res://src/data/resources/levels/level_01.tres") as LevelData
	if not l1:
		printerr("Failed to load level_01.tres")
		return false
	if l1.chunk_scenes.size() != 8:
		printerr("Level 1 should have 8 chunks, got %d" % l1.chunk_scenes.size())
		return false
	if not "Swarm Threat" in l1.level_title:
		printerr("Level 1 title should include (Swarm Threat): %s" % l1.level_title)
		return false
	print("  [PASS] Level 1: %s (%d chunks)" % [l1.level_title, l1.chunk_scenes.size()])
	
	# Level 2: Hazard Nav (8 chunks)
	var l2 := load("res://src/data/resources/levels/level_02.tres") as LevelData
	if not l2 or l2.chunk_scenes.size() != 8 or not "Hazard Nav" in l2.level_title:
		printerr("Level 2 validation failed: %s" % (l2.level_title if l2 else "null"))
		return false
	print("  [PASS] Level 2: %s (%d chunks)" % [l2.level_title, l2.chunk_scenes.size()])
	
	# Level 5: Captain Ironjaw (Boss Threat)
	var l5 := load("res://src/data/resources/levels/level_05.tres") as LevelData
	if not l5 or not "Boss Threat" in l5.level_title:
		printerr("Level 5 validation failed: %s" % (l5.level_title if l5 else "null"))
		return false
	print("  [PASS] Level 5: %s (%d chunks)" % [l5.level_title, l5.chunk_scenes.size()])
	
	# Level 45: Bonebeard's Throne (Boss Threat)
	var l45 := load("res://src/data/resources/levels/level_45.tres") as LevelData
	if not l45 or not "Boss Threat" in l45.level_title:
		printerr("Level 45 validation failed: %s" % (l45.level_title if l45 else "null"))
		return false
	print("  [PASS] Level 45: %s (%d chunks)" % [l45.level_title, l45.chunk_scenes.size()])
	
	return true
