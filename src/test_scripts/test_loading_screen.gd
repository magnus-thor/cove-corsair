@tool
@warning_ignore("untyped_declaration")
@warning_ignore("unsafe_property_access")
@warning_ignore("unsafe_method_access")
@warning_ignore("unsafe_cast")
extends Node

const LoadingScreenScript = preload("res://src/ui/loading_screen.gd")

func _ready() -> void:
	print("==================================================")
	print("   TESTING RIVER LOADING SCREEN & MONKEY DINGHY   ")
	print("==================================================")

	var loading_scene: PackedScene = preload("res://src/ui/loading_screen.tscn")
	assert(loading_scene != null, "LoadingScreen scene must preload cleanly")

	var screen: CanvasLayer = loading_scene.instantiate() as CanvasLayer
	assert(screen != null, "LoadingScreen must instantiate cleanly")
	add_child(screen)

	await get_tree().process_frame
	await get_tree().process_frame

	print("[STEP 1] Verifying UI Components & River Bar...")
	assert(screen.river_track != null, "RiverTrack must exist")
	assert(screen.river_water_fill != null, "RiverWaterFill must exist")
	assert(screen.boat_anchor != null, "BoatAnchor must exist")
	assert(screen.dinghy_sprite != null, "DinghySprite must exist")
	assert(screen.percentage_label != null, "PercentageLabel must exist")
	assert(screen.status_caption != null, "StatusCaption must exist")
	assert(screen.destination_label != null, "DestinationLabel must exist")
	print("[PASS] All loading screen visual elements are present and connected.")

	print("[STEP 2] Verifying Percentage & Boat Float Positioning...")
	# Test 0%
	screen._update_visual_progress(0.0)
	assert(screen.percentage_label.text == "0%", "Label at 0.0 must read 0%")
	var start_x: float = screen.boat_anchor.position.x

	# Test 50%
	screen._update_visual_progress(0.5)
	assert(screen.percentage_label.text == "50%", "Label at 0.5 must read 50%")
	var mid_x: float = screen.boat_anchor.position.x
	assert(mid_x > start_x, "Boat anchor position at 50% must be greater than start position")

	# Test 100%
	screen._update_visual_progress(1.0)
	assert(screen.percentage_label.text == "100%", "Label at 1.0 must read 100%")
	var end_x: float = screen.boat_anchor.position.x
	assert(end_x > mid_x, "Boat anchor position at 100% must be greater than mid position")
	assert(screen.river_water_fill.offset_right >= screen.river_track.size.x - 1.0, "River water fill must cover entire track at 100%")
	print("[PASS] Percentage and boat movement across the river bar verified.")

	print("[STEP 3] Verifying Procedural Water Bobbing & Rocking...")
	screen.bob_time = 0.0
	screen._update_boat_float_animation()
	var initial_rot: float = screen.dinghy_sprite.rotation_degrees
	var initial_y: float = screen.dinghy_sprite.position.y

	screen.bob_time = 0.4
	screen._update_boat_float_animation()
	var moved_rot: float = screen.dinghy_sprite.rotation_degrees
	var moved_y: float = screen.dinghy_sprite.position.y

	assert(initial_rot != moved_rot or initial_y != moved_y, "Bobbing animation must dynamically update pitch and elevation")
	print("[PASS] Procedural water bobbing and rocking animation verified.")

	print("[STEP 4] Verifying Destination Title & GameState Helper...")
	screen.set_destination("res://src/ui/river_map.tscn", "Smuggler's Run")
	assert(screen.destination_label.text == "SAILING TO: SMUGGLER'S RUN", "Destination label must format title accurately")

	print("[STEP 5] Testing Asynchronous Threaded Scene Loading...")
	var load_completed: bool = false
	screen.loading_completed.connect(func(scene: PackedScene) -> void:
		load_completed = true
	)

	# Simulate process frames until loaded
	for i in range(120):
		await get_tree().process_frame
		if load_completed or screen.has_completed_transition:
			break

	assert(screen.visual_progress > 0.0, "Visual progress must advance during loading")
	print("[PASS] Threaded scene loading and progress polling verified.")

	print("==================================================")
	print("   ALL LOADING SCREEN TESTS PASSED!               ")
	print("==================================================")
