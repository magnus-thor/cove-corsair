extends Node

## Cove Main Hub regression test: empty lots, build-on-first-direction, Quartermaster guidance,
## 3D click picking, pier -> river map, hub HUD and persistence of built houses.

var _fail_count: int = 0
var _last_selected_plot: String = ""

func _check(condition: bool, label: String) -> void:
	if condition:
		print("  [PASS] %s" % label)
	else:
		_fail_count += 1
		push_error("  [FAIL] %s" % label)
		print("  [FAIL] %s" % label)

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func _spawn_hub() -> CoveMainHub:
	var hub_scene: PackedScene = load("res://scenes/cove_hub/cove_main_hub.tscn") as PackedScene
	var hub: CoveMainHub = hub_scene.instantiate() as CoveMainHub
	add_child(hub)
	return hub

func _ready() -> void:
	print("==================================================")
	print("   TESTING COVE MAIN HUB (TUTORIAL-DRIVEN BUILD)  ")
	print("==================================================")
	await _run_tests()

	# Never leave test progression in the player's save.
	if FileAccess.file_exists(GameState.SAVE_PATH):
		DirAccess.remove_absolute(GameState.SAVE_PATH)

	if _fail_count == 0:
		print("ALL COVE HUB TESTS PASSED!")
		get_tree().quit(0)
	else:
		print("COVE HUB TESTS FAILED: %d" % _fail_count)
		get_tree().quit(1)

func _run_tests() -> void:
	GameState.reset_save_data()
	GameState.tutorial_step = GameState.TutorialStep.NOT_STARTED

	var hub: CoveMainHub = _spawn_hub()
	await get_tree().process_frame
	await get_tree().process_frame

	print("[STEP 1] Scene, backdrop, HUD and empty lots on a fresh game")
	_check(hub.hub_camera != null and hub.hub_camera.current, "HubCamera is current")
	_check(is_equal_approx(hub.hub_camera.fov, 36.0), "HubCamera FOV is 36")
	var mat: StandardMaterial3D = hub.background_quad.mesh.material as StandardMaterial3D
	_check(mat != null and mat.albedo_texture != null and mat.albedo_texture.resource_path.ends_with("cove_background_clean.png"), "Backdrop uses the clean cove plate")
	_check(hub.hud != null, "Hub HUD exists")
	_check(hub.hud != null and hub.hud.settings_button != null, "Settings button exists")
	_check(hub.hud != null and hub.hud.doubloons_label != null and hub.hud.doubloons_label.text.contains("DOUBLOONS"), "Doubloon balance is shown")
	_check(hub.hud != null and hub.hud.vessel_label != null and hub.hud.vessel_label.text.contains("TIER"), "Vessel badge is shown")
	for plot: BuildingPlot in hub.all_plots:
		_check(not plot.is_unlocked and plot.mesh_root.get_child_count() == 0, "Lot '%s' starts empty" % plot.plot_id)
	_check(hub.get_guidance_config().get("target", "") == "dock", "First-run guidance points at the pier/vessel")
	_check(hub._tutorial_overlay != null and hub._tutorial_overlay.visible, "Guidance overlay is visible on a fresh hub")

	print("[STEP 2] Shipyard is built when the tutorial directs the player to it")
	GameState.highest_unlocked_level = 3
	GameState.advance_tutorial_to(GameState.TutorialStep.LEVEL_2_COMPLETED)
	await get_tree().process_frame
	_check(not hub.plot_shipyard.is_unlocked, "Lots are still empty right after the level is won")
	await _wait(0.95)
	_check(hub.plot_shipyard.is_unlocked, "Shipyard house is built")
	_check(hub.plot_shipyard.mesh_root.get_node_or_null("BuildingMesh") != null, "Shipyard has its 3D model")
	_check(GameState.is_hub_building_built("shipyard"), "Shipyard build is persisted")
	_check(not hub.plot_skull_outpost.is_unlocked, "Skull Outpost is still an empty lot")
	_check(not hub.plot_future.is_unlocked, "Future lot is still an empty lot")
	await _wait(1.4)
	_check(hub._active_guidance_key.contains("shipyard"), "Quartermaster now directs the player into the shipyard")
	_check(hub._tutorial_overlay.visible, "Guidance overlay is visible for the shipyard")

	print("[STEP 3] Tapping the shipyard in 3D enters it")
	_last_selected_plot = ""
	hub.plot_selected.connect(func(id: String, _name: String) -> void: _last_selected_plot = id)
	for i: int in range(3):
		await get_tree().physics_frame
	var click_pos: Vector2 = hub._pins["shipyard"].get_global_rect().get_center()
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = click_pos
	press.global_position = click_pos
	# Headless windows are tiny and stretched, so inject the click in viewport (local) coordinates.
	get_viewport().push_input(press, true)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(_last_selected_plot == "shipyard", "Tapping the shipyard is registered")
	var shipyard_open: bool = false
	for child: Node in hub.get_children():
		if child is ShipyardUI:
			shipyard_open = true
			child.queue_free()
	_check(shipyard_open, "Shipyard UI opens from the house")
	await get_tree().process_frame

	print("[STEP 4] The pier starts river levels")
	hub._on_dock_activated()
	await get_tree().process_frame
	_check(hub._river_map_layer != null, "Tapping the pier opens the river map")
	hub._close_river_map()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(hub._river_map_layer == null, "River map closes back to the cove")

	print("[STEP 5] Skull Outpost is built when first loss occurs at L5+; future lot stays empty")
	GameState.highest_unlocked_level = 6
	GameState.advance_tutorial_to(GameState.TutorialStep.COMPLETED)
	await _wait(0.5)
	_check(not hub.plot_skull_outpost.is_unlocked, "Skull Outpost is not yet built before first loss")

	# Sinking triggers first loss
	EventBus.player_sunk.emit()
	hub._build_pending_houses()
	hub._check_tutorial_guidance()
	await _wait(0.95)
	_check(hub.plot_skull_outpost.is_unlocked, "Skull Outpost is built")
	_check(GameState.is_hub_building_built("skull_outpost"), "Skull Outpost build is persisted")
	_check(not hub.plot_future.is_unlocked, "Future lot is never built")
	await _wait(1.4)
	_check(hub._active_guidance_key.contains("skull_outpost"), "Quartermaster directs the player to the Skull Outpost")

	print("[STEP 6] Built houses reappear instantly on the next visit")
	hub.queue_free()
	await get_tree().process_frame
	var hub2: CoveMainHub = _spawn_hub()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(hub2.plot_shipyard.is_unlocked and hub2.plot_skull_outpost.is_unlocked, "Built houses are restored")
	_check(hub2.plot_shipyard.mesh_root.scale.is_equal_approx(Vector3.ONE), "Restored houses skip the build animation")
	_check(not hub2.plot_future.is_unlocked, "Future lot still empty")
	hub2.queue_free()
	await get_tree().process_frame
