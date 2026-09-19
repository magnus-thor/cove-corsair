@tool
# Turn off untyped warnings specifically for test harness:
@warning_ignore("untyped_declaration")
@warning_ignore("unsafe_property_access")
@warning_ignore("unsafe_method_access")
@warning_ignore("unsafe_cast")
extends Node

func _ready() -> void:
	print("==================================================")
	print("   TESTING 2D TOWN CANVAS + 3D SIDE-DOCK SHOWCASE ")
	print("==================================================")

	var hub_scene: PackedScene = preload("res://src/features/hub/pirate_lair_hub.tscn")
	assert(hub_scene != null, "PirateLairHub scene must be loaded")

	var hub: PirateLairHub = hub_scene.instantiate() as PirateLairHub
	assert(hub != null, "PirateLairHub must instantiate cleanly")
	add_child(hub)

	await get_tree().process_frame
	await get_tree().process_frame

	print("[STEP 1] Verifying 2D Town Canvas & Interactive Hotspot Areas...")
	var chart_hotspot: LairHotspotArea = hub.hotspot_chart_house
	assert(chart_hotspot != null, "Chart House hotspot must exist")
	assert(chart_hotspot.mode_id == "campaign", "Chart House mode_id must be 'campaign'")
	assert(chart_hotspot.required_level == 0, "Chart House required_level must be 0")
	assert(not chart_hotspot.is_locked, "Chart House must be unlocked by default")
	assert(chart_hotspot.display_title == "Chart House", "Chart House display_title must match")

	var skull_hotspot: LairHotspotArea = hub.hotspot_skull_outpost
	assert(skull_hotspot != null, "Skull Outpost hotspot must exist")
	assert(skull_hotspot.mode_id == "endless", "Skull Outpost mode_id must be 'endless'")
	assert(skull_hotspot.required_level == 5, "Skull Outpost required_level must be 5")
	assert(skull_hotspot.display_title == "Skull Outpost", "Skull Outpost display_title must match")

	var drydock_hotspot: LairHotspotArea = hub.hotspot_drydock
	assert(drydock_hotspot != null, "Drydock hotspot must exist")
	assert(drydock_hotspot.mode_id == "shipyard", "Drydock mode_id must be 'shipyard'")
	assert(drydock_hotspot.required_level == 0, "Drydock required_level must be 0")
	assert(not drydock_hotspot.is_locked, "Drydock must be unlocked by default")
	assert(drydock_hotspot.display_title == "Drydock & Forge", "Drydock display_title must match")
	print("[PASS] All 3 building hotspots initialized with correct metadata.")

	print("[STEP 2] Verifying Padlock Gating on Skull Outpost Hotspot (Level 5 requirement)...")
	var prev_highest: int = GameState.highest_unlocked_level
	GameState.highest_unlocked_level = 1
	skull_hotspot.refresh_lock_state()
	assert(skull_hotspot.is_locked, "Skull Outpost must be locked when highest level is 1")
	assert(skull_hotspot.lock_badge.visible, "Lock badge must be visible when locked")

	GameState.highest_unlocked_level = 5
	skull_hotspot.refresh_lock_state()
	assert(not skull_hotspot.is_locked, "Skull Outpost must unlock when highest level reaches 5")
	assert(not skull_hotspot.lock_badge.visible, "Lock badge must hide when unlocked")

	# Restore previous progression
	GameState.highest_unlocked_level = prev_highest
	skull_hotspot.refresh_lock_state()
	print("[PASS] Padlock gating and level unlock logic verified.")

	print("[STEP 3] Verifying 3D Side-Dock Vessel Showcase & Non-Submerged Waterline...")
	var anchor: Node3D = hub.basin_flagship_anchor
	assert(anchor != null, "Basin flagship anchor must exist in SubViewport")
	var flagship_mesh: Node3D = anchor.get_node_or_null("DockedFlagshipMesh") as Node3D
	assert(flagship_mesh != null, "DockedFlagshipMesh must be present in anchor")

	# Verify positive elevation above water (not sunken)
	assert(flagship_mesh.position.y >= 0.35, "Flagship position Y must be >= 0.35m to prevent sinking (current: %.2f)" % flagship_mesh.position.y)
	assert(hub._bob_tween != null and hub._bob_tween.is_valid(), "Flagship idle water bobbing tween must be active")
	print("[PASS] Side-dock flagship verified with elevated non-submerged waterline (Y = %.2f)." % flagship_mesh.position.y)

	print("[STEP 4] Testing Real-Time Flagship Swap on active_vessel_changed...")
	var prev_vessel: String = GameState.active_vessel
	GameState.active_vessel = "sloop"
	GameState.active_vessel_changed.emit("sloop")
	await get_tree().process_frame
	var updated_mesh: Node3D = anchor.get_node_or_null("DockedFlagshipMesh") as Node3D
	assert(updated_mesh != null, "Updated flagship mesh must be instantiated")
	assert(updated_mesh.position.y >= 0.35, "Sloop waterline elevation must also be >= 0.35m")

	# Restore previous vessel
	GameState.active_vessel = prev_vessel
	GameState.active_vessel_changed.emit(prev_vessel)
	await get_tree().process_frame
	print("[PASS] Real-time flagship swap verified in 3D side dock.")

	print("[STEP 5] Testing River Map Overlay Open & Close...")
	assert(not hub.river_map_layer.visible, "RiverMap layer must be hidden initially")
	hub._open_campaign_map()
	assert(hub.river_map_layer.visible, "RiverMap layer must become visible on open")
	hub._close_river_map()
	assert(not hub.river_map_layer.visible, "RiverMap layer must hide on close")
	print("[PASS] River Map overlay open/close flow verified.")

	print("==================================================")
	print("   ALL 2D TOWN + 3D SIDE-DOCK TESTS PASSED!       ")
	print("==================================================")
	get_tree().quit(0)
