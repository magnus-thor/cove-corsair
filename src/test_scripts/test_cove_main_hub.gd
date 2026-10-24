@tool
# Turn off untyped warnings specifically for test harness:
@warning_ignore("untyped_declaration")
@warning_ignore("unsafe_property_access")
@warning_ignore("unsafe_method_access")
@warning_ignore("unsafe_cast")
extends Node

func _ready() -> void:
	print("==================================================")
	print("   TESTING COVE MAIN HUB DYNAMIC FEATURE UNLOCKS  ")
	print("==================================================")

	var hub_scene: PackedScene = preload("res://scenes/cove_hub/cove_main_hub.tscn")
	assert(hub_scene != null, "cove_main_hub.tscn must load successfully")

	var hub: CoveMainHub = hub_scene.instantiate() as CoveMainHub
	assert(hub != null, "cove_main_hub must instantiate cleanly")
	add_child(hub)

	await get_tree().process_frame
	await get_tree().process_frame

	print("[STEP 1] Verifying Clean Cove Frustum Backdrop...")
	assert(hub.hub_camera != null, "HubCamera must exist")
	assert(hub.hub_camera.current, "HubCamera must be active/current")
	assert(is_equal_approx(hub.hub_camera.fov, 36.0), "HubCamera FOV must be 36 degrees")
	assert(hub.background_quad != null, "BackgroundQuad must exist")
	assert(hub.background_quad.mesh != null, "BackgroundQuad must have a Mesh")
	var mat: StandardMaterial3D = hub.background_quad.mesh.material as StandardMaterial3D
	assert(mat != null and mat.albedo_texture != null, "Backdrop must have albedo texture")
	assert(mat.albedo_texture.resource_path.ends_with("cove_background_clean.png"), "Backdrop must point to cove_background_clean.png")
	print("[PASS] Clean cove backdrop verified.")

	print("[STEP 2] Verifying Barren Plots on Initial State (No premature buildings)...")
	# In a fresh game, locked plots should NOT have buildings spawned on screen
	assert(hub.plot_forge.is_unlocked == false, "Plot_Forge must start locked")
	assert(hub.plot_tavern.is_unlocked == false, "Plot_Tavern must start locked")
	assert(hub.plot_expansion.is_unlocked == false, "Plot_Expansion must start locked")
	assert(hub.plot_forge.mesh_root.get_child_count() == 0, "Plot_Forge must have no meshes cluttering barren clearing")
	assert(hub.plot_tavern.mesh_root.get_child_count() == 0, "Plot_Tavern must have no meshes cluttering barren clearing")
	print("[PASS] Initial cove state is clean and barren with empty plots.")

	print("[STEP 3] Verifying Dynamic Building Addition upon Feature Unlock...")
	# Unlock Forge (Simulating Level 2 completion / Shipyard open)
	hub.set_plot_unlocked("forge", true)
	await get_tree().process_frame
	assert(hub.plot_forge.is_unlocked == true, "Plot_Forge should now be unlocked")
	var forge_mesh: Node = hub.plot_forge.mesh_root.get_node_or_null("BuildingMesh")
	assert(forge_mesh != null, "Plot_Forge must now have 3D BuildingMesh added to clearing")

	# Unlock Tavern (Simulating Level 5 reach / Endless open)
	hub.set_plot_unlocked("tavern", true)
	await get_tree().process_frame
	assert(hub.plot_tavern.is_unlocked == true, "Plot_Tavern should now be unlocked")
	var tavern_mesh: Node = hub.plot_tavern.mesh_root.get_node_or_null("BuildingMesh")
	assert(tavern_mesh != null, "Plot_Tavern must now have 3D BuildingMesh added to clearing")

	# Unlock Chart House (Campaign embarkation)
	hub.set_plot_unlocked("chart_house", true)
	await get_tree().process_frame
	assert(hub.plot_chart_house.is_unlocked == true, "Plot_ChartHouse should now be unlocked")
	var harbor_mesh: Node = hub.plot_chart_house.mesh_root.get_node_or_null("BuildingMesh")
	assert(harbor_mesh != null, "Plot_ChartHouse must have 3D BuildingMesh added to clearing")

	print("[STEP 4] Testing Click & Hover Interactions on Plots & Clearings...")
	var clicked_plot: Array[String] = [""]
	hub.plot_selected.connect(func(id: String, _name: String) -> void: clicked_plot[0] = id)

	# Simulate click on empty/locked plot
	hub.plot_expansion.plot_clicked.emit(hub.plot_expansion)
	assert(clicked_plot[0] == "expansion", "Clicking empty expansion clearing must propagate signal")

	# Simulate click on unlocked forge
	hub.plot_forge.plot_clicked.emit(hub.plot_forge)
	assert(clicked_plot[0] == "forge", "Clicking unlocked forge must propagate signal")

	print("[PASS] All interactions and transitions verified.")
	print("==================================================")
	print("   ALL COVE HUB DYNAMIC UNLOCK TESTS PASSED!      ")
	print("==================================================")
	get_tree().quit(0)
