extends Node

## First-run regression test: on a brand new save the very first run (River Level 1) must show
## the swerve prompt, and it must disappear as soon as the player steers.

var _fails: int = 0

func _check(condition: bool, label: String) -> void:
	if condition:
		print("  [PASS] %s" % label)
	else:
		_fails += 1
		push_error("  [FAIL] %s" % label)
		print("  [FAIL] %s" % label)

func _ready() -> void:
	print("==================================================")
	print("   TESTING FIRST-RUN TUTORIAL (SWERVE PROMPT)     ")
	print("==================================================")

	GameState.reset_save_data()
	# Same state the boot loading screen prepares for a first-time player.
	GameState.select_level(1)
	GameState.should_auto_start = true
	GameState.should_auto_start_endless = false
	GameState.reset_level()
	GameState.advance_tutorial_to(GameState.TutorialStep.LEVEL_1_IN_PROGRESS)

	var main_scene: PackedScene = load("res://src/core/main_game.tscn") as PackedScene
	var main_game: Node = main_scene.instantiate()
	add_child(main_game)
	await get_tree().process_frame
	await get_tree().process_frame

	var hud: TopHUD = get_tree().get_first_node_in_group("top_hud") as TopHUD
	_check(hud != null, "TopHUD exists in the run scene")
	var prompt: Node = hud.get_node_or_null("TutorialSwipePrompt") if hud else null
	_check(prompt != null, "Swerve prompt is shown on the first run")

	EventBus.player_swerved.emit()
	await get_tree().create_timer(0.6).timeout
	var prompt_after: Node = hud.get_node_or_null("TutorialSwipePrompt") if hud else null
	_check(prompt_after == null or prompt_after.is_queued_for_deletion(), "Swerve prompt disappears after steering")

	main_game.queue_free()
	await get_tree().process_frame

	# A returning player (tutorial past level 1) must NOT see the prompt.
	GameState.reset_save_data()
	GameState.advance_tutorial_to(GameState.TutorialStep.LEVEL_2_COMPLETED)
	GameState.should_auto_start = true
	var main_game2: Node = main_scene.instantiate()
	add_child(main_game2)
	await get_tree().process_frame
	await get_tree().process_frame
	var hud2: TopHUD = get_tree().get_first_node_in_group("top_hud") as TopHUD
	_check(hud2 != null and hud2.get_node_or_null("TutorialSwipePrompt") == null, "No swerve prompt after the tutorial moved on")
	main_game2.queue_free()
	await get_tree().process_frame

	if FileAccess.file_exists(GameState.SAVE_PATH):
		DirAccess.remove_absolute(GameState.SAVE_PATH)
	if _fails == 0:
		print("ALL FIRST-RUN TUTORIAL TESTS PASSED!")
		get_tree().quit(0)
	else:
		get_tree().quit(1)
