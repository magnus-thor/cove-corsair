extends Node

func _ready() -> void:
	print("==================================================")
	print("   SYSTEMATIC ISOLATION OF SCREEN BLINKING        ")
	print("==================================================")
	
	# First test: In Harbor Mode (before game starts)
	GameState.should_auto_start = false
	GameState.is_game_active = false
	
	var main_scene = load("res://src/core/main_game.tscn") as PackedScene
	var main_inst = main_scene.instantiate()
	add_child(main_inst)
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	print("\n--- TEST 1A: Cameras in Harbor Mode (Start Screen) ---")
	var all_cams = _find_all_cams(get_tree().root)
	print("Total Camera3D nodes in tree: %d" % all_cams.size())
	for c in all_cams:
		print("  - Camera '%s' (parent: '%s', path: '%s'): current = %s, visible = %s, global_pos = %s" % [
			c.name, c.get_parent().name if c.get_parent() else "null", c.get_path(), c.current, c.is_visible_in_tree(), str(c.global_position)
		])
	var active_cam = get_viewport().get_camera_3d()
	print("Viewport active camera: %s" % (active_cam.get_path() if active_cam else "NULL!"))

	# Start the game via MainGame._start_game_immediately() or simulating button press
	print("\n--- TEST 1B: Starting Gameplay & Checking Cameras ---")
	main_inst._start_game_immediately()
	await get_tree().process_frame
	await get_tree().process_frame
	
	all_cams = _find_all_cams(get_tree().root)
	print("Total Camera3D nodes in tree during gameplay: %d" % all_cams.size())
	for c in all_cams:
		print("  - Camera '%s' (path: '%s'): current = %s, visible = %s, global_pos = %s" % [
			c.name, c.get_path(), c.current, c.is_visible_in_tree(), str(c.global_position)
		])
	active_cam = get_viewport().get_camera_3d()
	print("Viewport active camera during gameplay: %s" % (active_cam.get_path() if active_cam else "NULL!"))

	print("\n--- TEST 1C: Monitoring Active Camera Across 60 Frames ---")
	var camera_switches = 0
	var last_cam = active_cam
	for frame in range(60):
		await get_tree().process_frame
		var cur = get_viewport().get_camera_3d()
		if cur != last_cam:
			camera_switches += 1
			print("[CAMERA SWITCH at frame %d] from %s to %s" % [
				frame,
				last_cam.name if last_cam else "NULL",
				cur.name if cur else "NULL"
			])
		last_cam = cur
	print("Total camera switches across 60 frames: %d" % camera_switches)

	print("\n--- TEST 2: Camera Shake NaN / Inf / Offset Audit ---")
	var game_cam = get_tree().get_first_node_in_group("game_camera") as GameCamera
	if game_cam:
		print("GameCamera found: %s" % game_cam.get_path())
		print("  - noise: %s" % str(game_cam.noise))
		if game_cam.noise:
			print("  - noise.seed: %d" % game_cam.noise.seed)
			var val = game_cam.noise.get_noise_2d(game_cam.noise.seed, 1.0)
			print("  - noise.get_noise_2d(seed, 1.0) = %f (is_nan: %s)" % [val, is_nan(val)])
			var val_fixed = game_cam.noise.get_noise_2d(1.0, 100.0)
			print("  - noise.get_noise_2d(1.0, 100.0) = %f (is_nan: %s)" % [val_fixed, is_nan(val_fixed)])
		print("  - trauma: %f (is_nan: %s, is_inf: %s)" % [game_cam.trauma, is_nan(game_cam.trauma), is_inf(game_cam.trauma)])
		print("  - position: %s (is_nan: %s)" % [str(game_cam.position), is_nan(game_cam.position.x) or is_nan(game_cam.position.y) or is_nan(game_cam.position.z)])
		print("  - rotation_degrees: %s" % str(game_cam.rotation_degrees))
		print("  - current: %s" % game_cam.current)
		
		# Test trauma burst
		game_cam.add_trauma(1.0)
		for f in range(10):
			await get_tree().process_frame
			print("Frame %d: pos=%s, rot=%s, trauma=%f" % [
				f, str(game_cam.position), str(game_cam.rotation_degrees), game_cam.trauma
			])
			if is_nan(game_cam.position.x) or is_inf(game_cam.position.x):
				print("[ALERT] Camera position became NaN/Inf during trauma!")

	print("\n--- TEST 3: DirectionalLight3D & Shadows ---")
	var sun = main_inst.find_child("*DirectionalLight3D*", true, false) as DirectionalLight3D
	if sun:
		print("DirectionalLight3D found: shadow_enabled = %s, shadow_mode = %d" % [
			sun.shadow_enabled, sun.directional_shadow_mode
		])
	else:
		print("No DirectionalLight3D found in main_inst")

	print("\n--- TEST 4: Full-Screen CanvasLayers & Overlays ---")
	var canvas_layers: Array[CanvasLayer] = []
	_find_all_canvas_layers(get_tree().root, canvas_layers)
	print("Total CanvasLayers in tree: %d" % canvas_layers.size())
	for cl in canvas_layers:
		print("  - CanvasLayer '%s' (path: '%s', visible = %s, layer = %d)" % [
			cl.name, cl.get_path(), cl.visible, cl.layer
		])
		for child in cl.find_children("*", "Control", true, false):
			var ctrl = child as Control
			if ctrl.anchor_right >= 1.0 and ctrl.anchor_bottom >= 1.0:
				print("      * Fullscreen Control: '%s' (visible = %s, modulate = %s)" % [
					ctrl.name, ctrl.is_visible_in_tree(), str(ctrl.modulate)
				])

	print("\n--- TEST 5: WorldEnvironment & Post-Processing ---")
	var env_node = main_inst.find_child("*WorldEnvironment*", true, false) as WorldEnvironment
	if env_node and env_node.environment:
		var env = env_node.environment
		print("Environment settings: background_mode = %d, glow_enabled = %s, tonemap_mode = %d, fog_enabled = %s" % [
			env.background_mode, env.glow_enabled, env.tonemap_mode, env.fog_enabled
		])

	print("\n==================================================")
	print("   ISOLATION TEST COMPLETED                       ")
	print("==================================================")
	get_tree().quit(0)

func _find_all_cams(n: Node) -> Array[Camera3D]:
	var res: Array[Camera3D] = []
	if n is Camera3D:
		res.append(n)
	for c in n.get_children():
		res.append_array(_find_all_cams(c))
	return res

func _find_all_canvas_layers(n: Node, res: Array[CanvasLayer]) -> void:
	if n is CanvasLayer:
		res.append(n)
	for c in n.get_children():
		_find_all_canvas_layers(c, res)
