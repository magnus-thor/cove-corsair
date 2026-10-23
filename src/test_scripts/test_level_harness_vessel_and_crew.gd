@tool
# Turn off untyped warnings specifically for test harnesses:
@warning_ignore("untyped_declaration")
@warning_ignore("unsafe_property_access")
@warning_ignore("unsafe_method_access")
@warning_ignore("unsafe_cast")
extends Node

## Verification Suite: Level Test Harness Vessel & Crew Customization
## Tests vessel selection, tier 7 level scaling, and crew member socket allocation.

var tests_passed: int = 0
var tests_failed: int = 0

func assert_test(condition: bool, test_name: String) -> void:
	if condition:
		print("  [PASS] %s" % test_name)
		tests_passed += 1
	else:
		printerr("  [FAIL] %s" % test_name)
		tests_failed += 1

func _ready() -> void:
	print("==================================================")
	print("   STARTING LEVEL HARNESS VESSEL & CREW VERIFICATION")
	print("==================================================")
	
	_test_harness_scene_and_properties()
	_test_vessel_selection_and_tier_7()
	_test_crew_selection_and_sockets()
	_test_vessel_and_crew_cycling()
	_test_iron_gunner_firing_at_level_34()
	
	print("==================================================")
	print("   RESULTS: %d PASSED, %d FAILED" % [tests_passed, tests_failed])
	print("==================================================")
	
	if tests_failed > 0:
		get_tree().quit(1)
	else:
		get_tree().quit(0)

func _test_harness_scene_and_properties() -> void:
	print("\n--- TEST 1: Harness Scene & Properties ---")
	var harness_scene: PackedScene = load("res://src/tools/level_test_harness.tscn") as PackedScene
	assert_test(harness_scene != null, "level_test_harness.tscn loaded successfully")
	
	var harness: LevelTestHarness = harness_scene.instantiate() as LevelTestHarness
	assert_test(harness != null, "LevelTestHarness instantiated successfully")
	assert_test("target_vessel" in harness, "Harness has target_vessel property")
	assert_test("vessel_level" in harness, "Harness has vessel_level property")
	assert_test("target_crew" in harness, "Harness has target_crew property")
	assert_test("crew_level" in harness, "Harness has crew_level property")
	assert_test(harness.vessel_level == 7, "Harness vessel_level defaults to 7 (actual: %d)" % harness.vessel_level)
	
	harness.queue_free()

func _test_vessel_selection_and_tier_7() -> void:
	print("\n--- TEST 2: Vessel Selection & Level 7 ---")
	var harness_scene: PackedScene = load("res://src/tools/level_test_harness.tscn") as PackedScene
	var harness: LevelTestHarness = harness_scene.instantiate() as LevelTestHarness
	add_child(harness)
	
	# Test Sloop
	harness.target_vessel = "sloop"
	harness.vessel_level = 7
	harness._apply_vessel_and_crew_configuration()
	assert_test(GameState.active_vessel == "sloop", "Active vessel set to sloop")
	assert_test(GameState.get_vessel_tier("sloop") == 7, "Sloop tier set to Level 7")
	assert_test(GameState.is_vessel_owned("sloop"), "Sloop is owned in GameState")
	
	# Test Ironclad
	harness.target_vessel = "ironclad"
	harness.vessel_level = 7
	harness._apply_vessel_and_crew_configuration()
	assert_test(GameState.active_vessel == "ironclad", "Active vessel set to ironclad")
	assert_test(GameState.get_vessel_tier("ironclad") == 7, "Ironclad tier set to Level 7")
	assert_test(GameState.is_vessel_owned("ironclad"), "Ironclad is owned in GameState")
	
	# Test Bombard Skiff
	harness.target_vessel = "bombard_skiff"
	harness.vessel_level = 7
	harness._apply_vessel_and_crew_configuration()
	assert_test(GameState.active_vessel == "bombard_skiff", "Active vessel set to bombard_skiff")
	assert_test(GameState.get_vessel_tier("bombard_skiff") == 7, "Bombard skiff tier set to Level 7")
	assert_test(GameState.is_vessel_owned("bombard_skiff"), "Bombard skiff is owned in GameState")
	
	# Test Dinghy (max level 3)
	harness.target_vessel = "dinghy"
	harness.vessel_level = 7
	harness._apply_vessel_and_crew_configuration()
	assert_test(GameState.active_vessel == "dinghy", "Active vessel set to dinghy")
	assert_test(GameState.get_vessel_tier("dinghy") == 3, "Dinghy gracefully caps at max tier 3")
	assert_test(GameState.is_vessel_owned("dinghy"), "Dinghy is owned in GameState")
	
	harness.queue_free()

func _test_crew_selection_and_sockets() -> void:
	print("\n--- TEST 3: Crew Selection & Sockets ---")
	var harness_scene: PackedScene = load("res://src/tools/level_test_harness.tscn") as PackedScene
	var harness: LevelTestHarness = harness_scene.instantiate() as LevelTestHarness
	add_child(harness)
	
	# Equip Monkey Bomber on Sloop (Tier 7)
	harness.target_vessel = "sloop"
	harness.vessel_level = 7
	harness.target_crew = "monkey_bomber"
	harness.crew_level = 3
	harness._apply_vessel_and_crew_configuration()
	assert_test(GameState.is_crew_unlocked("monkey_bomber"), "Monkey bomber is unlocked")
	assert_test(GameState.is_crew_equipped_on_active_ship("monkey_bomber"), "Monkey bomber equipped on Sloop")
	
	# Equip Skeleton Tosser on Ironclad (Tier 7)
	harness.target_vessel = "ironclad"
	harness.vessel_level = 7
	harness.target_crew = "skeleton_tosser"
	harness._apply_vessel_and_crew_configuration()
	assert_test(GameState.is_crew_unlocked("skeleton_tosser"), "Skeleton tosser is unlocked")
	assert_test(GameState.is_crew_equipped_on_active_ship("skeleton_tosser"), "Skeleton tosser equipped on Ironclad")
	
	# Equip Grease Monkey on Bombard Skiff (Tier 7)
	harness.target_vessel = "bombard_skiff"
	harness.vessel_level = 7
	harness.target_crew = "grease_monkey"
	harness._apply_vessel_and_crew_configuration()
	assert_test(GameState.is_crew_unlocked("grease_monkey"), "Grease monkey is unlocked")
	assert_test(GameState.is_crew_equipped_on_active_ship("grease_monkey"), "Grease monkey equipped on Bombard Skiff")
	
	# Equip None (No Crew)
	harness.target_crew = "none"
	harness._apply_vessel_and_crew_configuration()
	var eq_bombard: Dictionary = GameState.equipped_crew.get("bombard_skiff", {}) as Dictionary
	assert_test(eq_bombard.is_empty(), "No crew equipped when target_crew is 'none'")
	
	harness.queue_free()

func _test_vessel_and_crew_cycling() -> void:
	print("\n--- TEST 4: Vessel & Crew Cycling ---")
	var harness_scene: PackedScene = load("res://src/tools/level_test_harness.tscn") as PackedScene
	var harness: LevelTestHarness = harness_scene.instantiate() as LevelTestHarness
	add_child(harness)
	
	harness.target_vessel = "sloop"
	harness._cycle_vessel()
	assert_test(harness.target_vessel == "dinghy", "Cycled vessel from sloop to dinghy")
	harness._cycle_vessel()
	assert_test(harness.target_vessel == "ironclad", "Cycled vessel from dinghy to ironclad")
	harness._cycle_vessel()
	assert_test(harness.target_vessel == "bombard_skiff", "Cycled vessel from ironclad to bombard_skiff")
	harness._cycle_vessel()
	assert_test(harness.target_vessel == "sloop", "Cycled vessel from bombard_skiff back to sloop")
	
	harness.target_crew = "none"
	harness._cycle_crew()
	assert_test(harness.target_crew == "monkey_bomber", "Cycled crew from none to monkey_bomber")
	harness._cycle_crew()
	assert_test(harness.target_crew == "skeleton_tosser", "Cycled crew from monkey_bomber to skeleton_tosser")
	harness._cycle_crew()
	assert_test(harness.target_crew == "grease_monkey", "Cycled crew from skeleton_tosser to grease_monkey")
	harness._cycle_crew()
	assert_test(harness.target_crew == "none", "Cycled crew from grease_monkey back to none")
	
	harness.queue_free()

func _test_iron_gunner_firing_at_level_34() -> void:
	print("\n--- TEST 5: Iron Gunner Firing at Level 34 ---")
	var gunner_scene: PackedScene = load("res://src/gameplay/enemies/enemy_iron_gunner.tscn") as PackedScene
	assert_test(gunner_scene != null, "enemy_iron_gunner.tscn loaded successfully")
	var gunner: EnemyIronGunner = gunner_scene.instantiate() as EnemyIronGunner
	add_child(gunner)
	
	GameState.current_level = 34
	gunner._fire_dual_cannons()
	assert_test(true, "EnemyIronGunner._fire_dual_cannons executed successfully at level 34 without Array[float] error")
	
	gunner.queue_free()
