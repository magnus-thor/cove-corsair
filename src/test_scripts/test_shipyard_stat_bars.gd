@tool
extends Node

# Automated Verification Script for Shipyard Stat Bars Fully-Upgraded Ceiling Scaling

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
	print("  TESTING SHIPYARD STAT BAR MAX UPGRADE SCALING         ")
	print("========================================================\n")

	var shipyard_scene: PackedScene = load("res://src/ui/shipyard/shipyard_ui.tscn") as PackedScene
	assert_test(shipyard_scene != null, "shipyard_ui.tscn loads successfully")

	var shipyard: CanvasLayer = shipyard_scene.instantiate() as CanvasLayer
	add_child(shipyard)

	# 1. Verify dynamic fully upgraded max ceilings
	print("\n--- 1. Testing Fully Upgraded Ceilings ---")
	var max_stats: Dictionary = shipyard.call("_get_max_fully_upgraded_stats") as Dictionary
	assert_test(is_equal_approx(float(max_stats["hp"]), 10.0), "Max Hull Armor ceiling is 10.0 HP (Ironclad Tier 3)")
	assert_test(is_equal_approx(float(max_stats["speed"]), 14.5), "Max Top Speed ceiling is 14.5 m/s (Sloop Tier 3)")
	assert_test(is_equal_approx(float(max_stats["firepower"]), 7.0), "Max Firepower ceiling is 7.0x (Ironclad Tier 3 with 7 mounts)")
	assert_test(is_equal_approx(float(max_stats["agility"]), 100.0), "Max Agility ceiling is 100.0")

	# Save original state
	var orig_owned: Array[String] = GameState.owned_vessels.duplicate()
	var orig_tiers: Dictionary = GameState.vessel_tiers.duplicate()

	# 2. Inspect Tier 1 Sloop (Unowned / Tier 1 baseline: 4 HP, 11.5 m/s, 2x cannons)
	print("\n--- 2. Inspecting Sloop at Tier 1 ---")
	GameState.owned_vessels = ["dinghy"]
	GameState.vessel_tiers["sloop"] = 1

	shipyard.set("selected_vessel_id", "sloop")
	shipyard.call("_update_inspection_drawer")

	var bar_hp: UIStatBar = shipyard.get("stat_bar_hull_armor") as UIStatBar
	var bar_speed: UIStatBar = shipyard.get("stat_bar_top_speed") as UIStatBar
	var bar_fp: UIStatBar = shipyard.get("stat_bar_firepower") as UIStatBar

	var prog_hp: ProgressBar = bar_hp.get("progress_bar") as ProgressBar
	var prog_speed: ProgressBar = bar_speed.get("progress_bar") as ProgressBar
	var prog_fp: ProgressBar = bar_fp.get("progress_bar") as ProgressBar

	var expected_hp_pct: float = (4.0 / 10.0) * 100.0
	assert_test(is_equal_approx(prog_hp.value, expected_hp_pct), "Sloop Tier 1 HP bar is exactly 40.0% (4/10)")

	var expected_speed_pct: float = (11.5 / 14.5) * 100.0
	assert_test(is_equal_approx(prog_speed.value, expected_speed_pct), "Sloop Tier 1 Speed bar is exactly %.1f%% (11.5/14.5)" % expected_speed_pct)

	var expected_fp_pct: float = (2.0 / 7.0) * 100.0
	assert_test(absf(prog_fp.value - expected_fp_pct) < 0.1, "Sloop Tier 1 Firepower bar is approximately 28.6% (2/7)")

	# 3. Simulate Owned Level 10 Ironclad (Should fill HP and Firepower to 100%)
	print("\n--- 3. Testing Fully Upgraded Ironclad (100% Ceilings) ---")
	if not GameState.owned_vessels.has("ironclad"):
		GameState.owned_vessels.append("ironclad")
	GameState.vessel_tiers["ironclad"] = 10

	shipyard.set("selected_vessel_id", "ironclad")
	shipyard.call("_update_inspection_drawer")

	assert_test(is_equal_approx(prog_hp.value, 100.0), "Ironclad Level 10 HP bar is 100% full (10/10)")
	assert_test(is_equal_approx(prog_fp.value, 100.0), "Ironclad Level 10 Firepower bar is 100% full (7/7)")

	# 4. Simulate Owned Level 10 Sloop (Should fill Speed to 100%)
	print("\n--- 4. Testing Fully Upgraded Sloop Speed (100% Ceiling) ---")
	if not GameState.owned_vessels.has("sloop"):
		GameState.owned_vessels.append("sloop")
	GameState.vessel_tiers["sloop"] = 10

	shipyard.set("selected_vessel_id", "sloop")
	shipyard.call("_update_inspection_drawer")

	assert_test(is_equal_approx(prog_speed.value, 100.0), "Sloop Level 10 Speed bar is 100% full (14.5/14.5)")

	# Restore state
	GameState.owned_vessels = orig_owned
	GameState.vessel_tiers = orig_tiers

	# Clean up
	remove_child(shipyard)
	shipyard.free()

	print("\n========================================================")
	print("  TEST RESULTS: %d / %d PASSED" % [passed_count, total_count])
	print("========================================================\n")

	if passed_count == total_count:
		print(">>> ALL SHIPYARD STAT BAR TESTS PASSED! <<<")
	else:
		printerr(">>> SOME TESTS FAILED! <<<")

	get_tree().quit(0 if passed_count == total_count else 1)
