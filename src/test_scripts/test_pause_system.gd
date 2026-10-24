extends Node

## Test Suite: In-Game Pause Button & Pause System Verification
## Tests PauseButton existence, visibility during gameplay, clicking pause button,
## tree pause state, unpausing via continue button, and input triggers.

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
	print("      TESTING IN-GAME PAUSE BUTTON & MENU         ")
	print("==================================================")

	GameState.reset_save_data()
	GameState.select_level(1)
	GameState.should_auto_start = true
	GameState.should_auto_start_endless = false
	GameState.reset_level()

	# 1. Instantiate Main Game
	var main_scene: PackedScene = load("res://src/core/main_game.tscn") as PackedScene
	_check(main_scene != null, "main_game.tscn loaded successfully")
	var main_game: Node = main_scene.instantiate()
	add_child(main_game)
	await get_tree().process_frame
	await get_tree().process_frame

	# 2. Check TopHUD and PauseButton
	var hud: TopHUD = get_tree().get_first_node_in_group("top_hud") as TopHUD
	_check(hud != null, "TopHUD node found in scene tree")
	_check(hud.pause_button != null, "TopHUD has pause_button reference")
	_check(hud.pause_button.visible, "Pause button is visible during gameplay")
	_check(hud.pause_button.text == "⏸", "Pause button has correct pause symbol text")

	# 3. Simulate Pause Button Pressed
	_check(not get_tree().paused, "Game tree is initially not paused")
	hud.pause_button.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame

	# 4. Check PauseMenu is open and tree is paused
	var pause_menu: PauseMenu = get_tree().root.find_child("PauseMenu", true, false) as PauseMenu
	_check(pause_menu != null, "PauseMenu was instantiated and added to tree")
	_check(get_tree().paused, "Game tree is paused after pause button pressed")

	# 5. Check duplicate pause press doesn't instantiate multiple menus
	hud._on_pause_button_pressed()
	await get_tree().process_frame
	var pause_menus: Array[Node] = []
	for child: Node in main_game.get_children():
		if child is PauseMenu:
			pause_menus.append(child)
	_check(pause_menus.size() == 1, "Only single PauseMenu instance exists while paused")

	# 6. Unpause via Continue button
	_check(pause_menu.continue_button != null, "PauseMenu has continue_button")
	pause_menu._on_continue_pressed()
	await get_tree().process_frame
	await get_tree().create_timer(0.3).timeout # Wait for close tween
	_check(not get_tree().paused, "Game tree is unpaused after continue pressed")

	# Clean up
	main_game.queue_free()
	await get_tree().process_frame

	if _fails == 0:
		print("==================================================")
		print("  ALL PAUSE SYSTEM TESTS PASSED SUCCESSFULLY!     ")
		print("==================================================")
	else:
		push_error("%d pause system tests failed!" % _fails)
	
	get_tree().quit(0 if _fails == 0 else 1)
