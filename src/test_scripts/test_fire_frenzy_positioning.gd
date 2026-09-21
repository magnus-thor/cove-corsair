@tool
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
	print("  TESTING FIRE FRENZY VESSEL TRACKING & SCREEN POSITION ")
	print("========================================================\n")

	# 1. Fallback positioning when no player exists
	var vignette_scene: PackedScene = load("res://src/ui/hud/frenzy_vignette.tscn") as PackedScene
	assert_test(vignette_scene != null, "frenzy_vignette.tscn loads successfully")
	var vignette: FrenzyVignette = vignette_scene.instantiate() as FrenzyVignette
	add_child(vignette)

	var banner_cont: Control = vignette.get_node_or_null("BannerContainer") as Control
	assert_test(banner_cont != null, "BannerContainer exists in FrenzyVignette")

	vignette._update_banner_position()
	assert_test(banner_cont.position.y > 200.0, "Without player/camera, fallback position is in lower screen area (found Y = %.1f)" % banner_cont.position.y)

	# 2. Setup Camera3D and Player vessel
	var cam: Camera3D = Camera3D.new()
	cam.position = Vector3(0.0, 14.5, 12.0)
	cam.rotation_degrees = Vector3(-24.5, 0.0, 0.0)
	cam.current = true
	add_child(cam)

	var player_scene: PackedScene = load("res://src/gameplay/player/player_boat.tscn") as PackedScene
	var player: PlayerSwerve = player_scene.instantiate() as PlayerSwerve
	add_child(player)
	player.global_position = Vector3(0.0, 0.0, 0.0)

	# 3. Position banner with player at center lane (0, 0, 0)
	vignette._update_banner_position()
	var center_screen_pos: Vector2 = banner_cont.global_position
	var expected_center: Vector2 = cam.unproject_position(player.global_position + Vector3(0.0, 2.2, -0.4))
	assert_test(center_screen_pos.distance_to(expected_center) < 1.0, "Banner position matches unprojected vessel position at center lane")
	assert_test(center_screen_pos.y > 250.0, "Banner is shown close to the user vessel in mid/lower view (Y = %.1f, not at top Y = 80)" % center_screen_pos.y)

	# 4. Swerve player to left lane (-3.2)
	player.global_position = Vector3(-3.2, 0.0, 0.0)
	vignette._update_banner_position()
	var left_screen_pos: Vector2 = banner_cont.global_position
	assert_test(left_screen_pos.x < center_screen_pos.x - 30.0, "Banner dynamically tracks left as player swerves to left lane (X = %.1f vs %.1f)" % [left_screen_pos.x, center_screen_pos.x])

	# 5. Swerve player to right lane (+3.2)
	player.global_position = Vector3(3.2, 0.0, 0.0)
	vignette._update_banner_position()
	var right_screen_pos: Vector2 = banner_cont.global_position
	assert_test(right_screen_pos.x > center_screen_pos.x + 30.0, "Banner dynamically tracks right as player swerves to right lane (X = %.1f vs %.1f)" % [right_screen_pos.x, center_screen_pos.x])

	# 6. Trigger frenzy celebratory flow
	vignette.trigger_frenzy(2.5)
	var banner_panel: PanelContainer = vignette.get_node_or_null("%BannerPanel") as PanelContainer
	assert_test(banner_panel != null and banner_panel.visible, "BannerPanel becomes visible upon trigger_frenzy")

	# Clean up
	player.queue_free()
	cam.queue_free()
	vignette.queue_free()

	print("\n========================================================")
	print("  TEST RESULTS: %d / %d PASSED" % [passed_count, total_count])
	print("========================================================\n")
	get_tree().quit(0 if passed_count == total_count else 1)
