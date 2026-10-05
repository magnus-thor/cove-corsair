class_name TestPlaytestTelemetry
extends Node

## Automated Verification Script for Playtest Telemetry & Save Reset
## Strictly statically typed — zero untyped warnings.

const PlaytestTelemetryScript: GDScript = preload("res://src/core/playtest_telemetry.gd")

var passed_count: int = 0
var total_count: int = 0

func assert_test(condition: bool, test_name: String) -> void:
	total_count += 1
	if condition:
		passed_count += 1
		print("[PASS] " + test_name)
	else:
		printerr("[FAIL] " + test_name)

func _ready() -> void:
	print("\n========================================================")
	print("  TESTING PLAYTEST TELEMETRY & FRESH SAVE SYSTEM         ")
	print("========================================================\n")

	# 1. Fresh save reset & backup
	print("--- 1. Testing Save Reset ---")
	GameState.init_playtest_fresh_save()
	assert_test(GameState.doubloons == 0, "Vault balance reset to 0 🪙")
	assert_test(GameState.highest_unlocked_level == 1, "Level progression reset to Level 1")
	assert_test(GameState.active_vessel == "dinghy", "Active vessel reset to Dinghy")

	# 2. Verify PlaytestTelemetry Autoload
	print("\n--- 2. Testing PlaytestTelemetry Autoload ---")
	var telemetry: Node = null
	if get_tree().root.has_node("PlaytestTelemetry"):
		telemetry = get_tree().root.get_node("PlaytestTelemetry")
	else:
		telemetry = PlaytestTelemetryScript.new() as Node
		telemetry.name = "PlaytestTelemetry"
		get_tree().root.add_child(telemetry)

	assert_test(telemetry != null, "PlaytestTelemetry autoload is loaded and valid")
	if telemetry != null:
		telemetry.set("is_telemetry_enabled", true)
		if telemetry.has_method("_init_session_if_needed"):
			telemetry.call("_init_session_if_needed")

	# 3. Test Level Run Start
	print("\n--- 3. Testing Run Start ---")
	EventBus.level_started.emit(1)
	var is_active: bool = bool(telemetry.get("is_run_active"))
	var cur_run: Dictionary = telemetry.get("current_run") as Dictionary
	assert_test(is_active == true, "Telemetry run is marked active")
	assert_test(int(cur_run.get("level_index", 0)) == 1, "Telemetry recorded current level as 1")

	# 4. Test Combat Hit Logging
	print("\n--- 4. Testing Combat Telemetry ---")
	EventBus.player_hit_taken.emit(1, 2, 3, "Hazard Sea Mine", 45.5)
	cur_run = telemetry.get("current_run") as Dictionary
	var hits: Array = cur_run.get("hits_taken", []) as Array
	assert_test(hits.size() == 1, "Combat hit recorded in current run")
	if not hits.is_empty():
		var hit: Dictionary = hits[0] as Dictionary
		assert_test(str(hit.get("source", "")) == "Hazard Sea Mine", "Hit source correctly tagged as 'Hazard Sea Mine'")
		assert_test(int(hit.get("damage", 0)) == 1, "Hit damage recorded correctly")

	# 5. Test Economy Telemetry
	print("\n--- 5. Testing Economy Telemetry ---")
	GameState.add_doubloons(25, "chest")
	cur_run = telemetry.get("current_run") as Dictionary
	assert_test(int(cur_run.get("coins_collected", 0)) == 25, "Doubloons collected updated in run telemetry")
	var sources: Dictionary = cur_run.get("coins_by_source", {}) as Dictionary
	assert_test(int(sources.get("chest", 0)) == 25, "Chest earnings tagged correctly in run sources")

	# 6. Test Mob Escape Logging
	print("\n--- 6. Testing Mob Escape Telemetry ---")
	GameState.record_mob_leaked("Skiff Raider")
	cur_run = telemetry.get("current_run") as Dictionary
	assert_test(int(cur_run.get("mobs_leaked", 0)) == 1, "Mob escape recorded in run telemetry")

	# 7. Test Level Completion
	print("\n--- 7. Testing Run Completion ---")
	EventBus.level_completed.emit(25, 5)
	is_active = bool(telemetry.get("is_run_active"))
	var all_runs: Array[Dictionary] = telemetry.get("runs") as Array[Dictionary]
	assert_test(is_active == false, "Run marked completed")
	assert_test(all_runs.size() == 1, "Run stored in session runs ledger")
	if not all_runs.is_empty():
		var last_run: Dictionary = all_runs[0] as Dictionary
		assert_test(str(last_run.get("status", "")) == "VICTORY", "Run status is VICTORY")

	# 8. Test Shipyard Activity
	print("\n--- 8. Testing Shipyard Telemetry ---")
	EventBus.shipyard_item_action.emit("sloop", "vessel", 400, 175, false, "insufficient_funds")
	EventBus.shipyard_item_action.emit("standard_iron", "ammo", 0, 175, true, "purchased")
	var sy_events: Array[Dictionary] = telemetry.get("shipyard_events") as Array[Dictionary]
	assert_test(sy_events.size() >= 2, "Shipyard purchase and deficit events recorded")

	# 9. Test Disk Persistence
	print("\n--- 9. Testing Disk Persistence ---")
	telemetry.call("save_telemetry_to_disk")
	var file_exists: bool = FileAccess.file_exists("user://playtest_session.json") or FileAccess.file_exists("res://playtest_session.json")
	assert_test(file_exists, "Session file user://playtest_session.json exists")

	# 10. Clean up test artifacts so user has a pristine 0-gold Level 1 session ready
	GameState.init_playtest_fresh_save()
	(telemetry.get("runs") as Array).clear()
	(telemetry.get("current_run") as Dictionary).clear()
	telemetry.set("is_run_active", false)
	(telemetry.get("shipyard_events") as Array).clear()
	(telemetry.get("lifetime_damage_sources") as Dictionary).clear()
	(telemetry.get("lifetime_coins_by_source") as Dictionary).clear()
	telemetry.set("total_doubloons_earned_session", 0)
	telemetry.set("total_doubloons_spent_session", 0)
	
	var s_proj: String = str(telemetry.get("session_file_project"))
	var s_user: String = str(telemetry.get("session_file_user"))
	if "playtest_session_" in s_proj:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(s_proj))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(s_user))
	if FileAccess.file_exists("res://playtest_session_latest.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("res://playtest_session_latest.json"))
	if FileAccess.file_exists("user://playtest_session_latest.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://playtest_session_latest.json"))

	if telemetry != null:
		telemetry.set("is_telemetry_enabled", false)

	print("\n========================================================")
	print("  TESTS FINISHED: %d / %d PASSED" % [passed_count, total_count])
	print("========================================================\n")

	get_tree().quit(0 if passed_count == total_count else 1)
