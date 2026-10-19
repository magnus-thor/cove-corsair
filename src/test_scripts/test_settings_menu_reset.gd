extends Node

func _ready() -> void:
	print("\n========================================================")
	print("  RUNNING SETTINGS MENU RESET & RELOAD TEST")
	print("========================================================\n")

	var settings_scene: PackedScene = load("res://src/ui/settings_menu.tscn")
	assert(settings_scene != null, "settings_menu.tscn failed to load")
	print("  [PASS] settings_menu.tscn loaded successfully")

	var settings_node: SettingsMenu = settings_scene.instantiate() as SettingsMenu
	assert(settings_node != null, "settings_node failed to instantiate")
	add_child(settings_node)
	print("  [PASS] settings_node instantiated and added to tree")

	var reset_btn: Button = settings_node.get_node("%ResetButton") as Button
	assert(reset_btn != null, "ResetButton (%ResetButton) not found")
	print("  [PASS] %ResetButton found")
	assert(reset_btn.text == "⚠️ RESET GAME & TUTORIAL", "Button text is '%s'" % reset_btn.text)
	print("  [PASS] ResetButton initial text is '%s'" % reset_btn.text)

	var has_tutorial_btn: bool = settings_node.has_node("%ResetTutorialButton")
	assert(!has_tutorial_btn, "ResetTutorialButton should no longer exist in settings menu")
	print("  [PASS] Old ResetTutorialButton successfully removed")

	# Simulate populated progress
	GameState.doubloons = 500
	GameState.highest_unlocked_level = 4
	GameState.current_level = 4
	GameState.tutorial_step = GameState.TutorialStep.LEVEL_3_COMPLETED

	# First press on reset button (triggers confirmation prompt)
	reset_btn.pressed.emit()
	assert(settings_node.is_confirming_reset == true, "SettingsMenu is_confirming_reset should be true")
	assert(reset_btn.text == "⚠️ CONFIRM RESET? (CLICK AGAIN)", "ResetButton text updated for confirmation")
	print("  [PASS] Confirmation state active: '%s'" % reset_btn.text)

	# Second press on reset button (confirms reset)
	reset_btn.pressed.emit()
	assert(settings_node.is_confirming_reset == false, "SettingsMenu is_confirming_reset should be reset")
	assert(GameState.doubloons == 0, "Doubloons reset to 0")
	assert(GameState.highest_unlocked_level == 1, "highest_unlocked_level reset to 1")
	assert(GameState.tutorial_step == GameState.TutorialStep.NOT_STARTED, "tutorial_step reset to NOT_STARTED")
	print("  [PASS] GameState and Tutorial successfully reset to 0 / NOT_STARTED")

	settings_node.queue_free()
	print("\n========================================================")
	print("  SETTINGS MENU RESET & RELOAD TEST PASSED! ✓")
	print("========================================================\n")
	get_tree().quit(0)
