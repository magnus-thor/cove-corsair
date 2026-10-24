@tool
# Turn off untyped warnings specifically for test harness:
@warning_ignore("untyped_declaration")
@warning_ignore("unsafe_property_access")
@warning_ignore("unsafe_method_access")
@warning_ignore("unsafe_cast")
extends Node

func _ready() -> void:
	print("==================================================")
	print("   TESTING COVE MAIN HUB 2.5D SCENE ARCHITECTURE  ")
	print("==================================================")

	var hub_scene: PackedScene = preload("res://scenes/cove_hub/cove_main_hub.tscn")
	assert(hub_scene != null, "cove_main_hub.tscn must load successfully")

	var hub: CoveMainHub = hub_scene.instantiate() as CoveMainHub
	assert(hub != null, "cove_main_hub must instantiate cleanly")
	add_child(hub)

	await get_tree().process_frame
	await get_tree().process_frame

	print("[STEP 1] Verifying Camera3D & Background Quad...")
	assert(hub.hub_camera != null, "HubCamera must exist")
	assert(hub.hub_camera.current, "HubCamera must be active/current")
	assert(is_equal_approx(hub.hub_camera.fov, 36.0), "HubCamera FOV must be 36 degrees")
	assert(hub.background_quad != null, "BackgroundQuad must exist")
	assert(hub.background_quad.mesh != null, "BackgroundQuad must have a Mesh")
	print("[PASS] Camera3D and Background Quad configured correctly.")

	print("[STEP 2] Verifying Directional Moonlight & Environment...")
	assert(hub.moonlight != null, "DirectionalLight3D 'Moonlight' must exist")
	assert(hub.moonlight.shadow_enabled, "Moonlight must have shadows enabled")
	assert(hub.dock_anchor != null, "DockAnchor Marker3D must exist")
	print("[PASS] Lighting and Dock Anchor verified.")

	print("[STEP 3] Verifying Building Plot Anchors & Interactions...")
	assert(hub.plot_forge != null, "Plot_Forge must exist")
	assert(hub.plot_tavern != null, "Plot_Tavern must exist")
	assert(hub.plot_chart_house != null, "Plot_ChartHouse must exist")
	assert(hub.plot_expansion != null, "Plot_Expansion must exist")

	assert(hub.plot_forge.is_unlocked == true, "Plot_Forge should start unlocked")
	assert(hub.plot_tavern.is_unlocked == true, "Plot_Tavern should start unlocked")
	assert(hub.plot_chart_house.is_unlocked == false, "Plot_ChartHouse should start locked")
	assert(hub.plot_expansion.is_unlocked == false, "Plot_Expansion should start locked")

	var clicked_plot: Array[String] = [""]
	hub.plot_selected.connect(func(id: String, _name: String) -> void: clicked_plot[0] = id)

	# Simulate click
	hub.plot_forge.plot_clicked.emit(hub.plot_forge)
	assert(clicked_plot[0] == "forge", "Plot click must propagate to hub.plot_selected signal")

	# Test unlock toggle
	hub.set_plot_unlocked("chart_house", true)
	assert(hub.plot_chart_house.is_unlocked == true, "Plot_ChartHouse should now be unlocked")

	print("[PASS] All 4 building plots and interaction signals functioning cleanly.")
	print("==================================================")
	print("   ALL PHASE 2 HUB TESTS PASSED SUCCESSFULLY!    ")
	print("==================================================")
	get_tree().quit(0)
