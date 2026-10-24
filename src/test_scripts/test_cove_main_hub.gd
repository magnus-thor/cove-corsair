@tool
# Turn off untyped warnings specifically for test harness:
@warning_ignore("untyped_declaration")
@warning_ignore("unsafe_property_access")
@warning_ignore("unsafe_method_access")
@warning_ignore("unsafe_cast")
extends Node

func _ready() -> void:
	print("==================================================")
	print("   TESTING COVE MAIN HUB PHASE 5 INTEGRATION      ")
	print("==================================================")

	var hub_scene: PackedScene = preload("res://scenes/cove_hub/cove_main_hub.tscn")
	assert(hub_scene != null, "cove_main_hub.tscn must load successfully")

	var hub: CoveMainHub = hub_scene.instantiate() as CoveMainHub
	assert(hub != null, "cove_main_hub must instantiate cleanly")
	add_child(hub)

	await get_tree().process_frame
	await get_tree().process_frame

	print("[STEP 1] Verifying Camera3D & Frustum Backdrop...")
	assert(hub.hub_camera != null, "HubCamera must exist")
	assert(hub.hub_camera.current, "HubCamera must be active/current")
	assert(is_equal_approx(hub.hub_camera.fov, 36.0), "HubCamera FOV must be 36 degrees")
	assert(hub.background_quad != null, "BackgroundQuad must exist")
	assert(hub.background_quad.mesh != null, "BackgroundQuad must have a Mesh")
	print("[PASS] Camera3D and Background Quad configured correctly.")

	print("[STEP 2] Verifying Directional Moonlight & Shadow Tuning...")
	assert(hub.moonlight != null, "DirectionalLight3D 'Moonlight' must exist")
	assert(hub.moonlight.shadow_enabled, "Moonlight must have shadows enabled")
	assert(is_equal_approx(hub.moonlight.shadow_bias, 0.03), "Shadow bias should be 0.03")
	assert(hub.dock_anchor != null, "DockAnchor Marker3D must exist")
	assert(hub.dock_anchor.get_child_count() > 0, "DockAnchor must have docked vessel")
	print("[PASS] Lighting, shadows, and Dock Anchor verified.")

	print("[STEP 3] Verifying 3D Building Models Wired to Plots...")
	assert(hub.plot_forge != null, "Plot_Forge must exist")
	assert(hub.plot_tavern != null, "Plot_Tavern must exist")
	assert(hub.plot_chart_house != null, "Plot_ChartHouse must exist")
	assert(hub.plot_expansion != null, "Plot_Expansion must exist")

	# Verify Forge model is loaded and instantiated
	assert(hub.plot_forge.is_unlocked == true, "Plot_Forge should start unlocked")
	var forge_mesh: Node = hub.plot_forge.mesh_root.get_node_or_null("BuildingMesh")
	assert(forge_mesh != null, "Plot_Forge must have BuildingMesh instantiated")

	# Verify Tavern model is loaded and instantiated
	assert(hub.plot_tavern.is_unlocked == true, "Plot_Tavern should start unlocked")
	var tavern_mesh: Node = hub.plot_tavern.mesh_root.get_node_or_null("BuildingMesh")
	assert(tavern_mesh != null, "Plot_Tavern must have BuildingMesh instantiated")

	# Verify ChartHouse starts locked with Foundation
	assert(hub.plot_chart_house.is_unlocked == false, "Plot_ChartHouse should start locked")
	var harbor_foundation: Node = hub.plot_chart_house.mesh_root.get_node_or_null("FoundationMesh")
	assert(harbor_foundation != null, "Plot_ChartHouse must have FoundationMesh instantiated while locked")

	# Verify Expansion starts locked with Foundation
	assert(hub.plot_expansion.is_unlocked == false, "Plot_Expansion should start locked")
	var exp_foundation: Node = hub.plot_expansion.mesh_root.get_node_or_null("FoundationMesh")
	assert(exp_foundation != null, "Plot_Expansion must have FoundationMesh instantiated")

	print("[STEP 4] Testing Dynamic Unlock Transition on Chart House...")
	hub.set_plot_unlocked("chart_house", true)
	await get_tree().process_frame
	assert(hub.plot_chart_house.is_unlocked == true, "Plot_ChartHouse should be unlocked")
	var harbor_mesh: Node = hub.plot_chart_house.mesh_root.get_node_or_null("BuildingMesh")
	assert(harbor_mesh != null, "Plot_ChartHouse must now have BuildingMesh (Harbor Office) instantiated")

	print("[STEP 5] Testing Click & Hover Interactions...")
	var clicked_plot: Array[String] = [""]
	hub.plot_selected.connect(func(id: String, _name: String) -> void: clicked_plot[0] = id)

	# Simulate hover
	hub.plot_tavern.interaction_area.mouse_entered.emit()
	assert(hub.plot_tavern.is_hovered == true, "Plot_Tavern should register hover")
	hub.plot_tavern.interaction_area.mouse_exited.emit()
	assert(hub.plot_tavern.is_hovered == false, "Plot_Tavern should unregister hover")

	# Simulate click
	hub.plot_forge.plot_clicked.emit(hub.plot_forge)
	assert(clicked_plot[0] == "forge", "Plot click must propagate to hub.plot_selected signal")

	print("[PASS] All interactions and transitions verified.")
	print("==================================================")
	print("   ALL PHASE 5 HUB INTEGRATION TESTS PASSED!      ")
	print("==================================================")
	get_tree().quit(0)
