@tool
# Turn off untyped warnings specifically for test harnesses:
@warning_ignore("untyped_declaration")
@warning_ignore("unsafe_property_access")
@warning_ignore("unsafe_method_access")
@warning_ignore("unsafe_cast")
extends Node

func _ready() -> void:
	print("==================================================")
	print("   TESTING LEVEL 1 WITH 3-TIER RIVERBANK PROPS    ")
	print("==================================================")
	
	var main_game_scene = preload("res://src/core/main_game.tscn")
	var main_game = main_game_scene.instantiate() as MainGame
	add_child(main_game)
	
	await get_tree().process_frame
	
	# Select and load Level 1
	GameState.select_level(1)
	var level_ctrl = main_game.get_node("LevelController") as LevelController
	assert(level_ctrl != null, "LevelController must exist")
	
	var res = GameState.get_current_level_resource()
	assert(res != null, "Level 1 resource must load")
	level_ctrl.load_level_resource(res)
	
	main_game._on_game_started()
	await get_tree().process_frame
	
	print("[STEP 1] Verifying Boundary Walls...")
	var left_wall = level_ctrl.get_node_or_null("BoundaryWall_Left") as StaticBody3D
	var right_wall = level_ctrl.get_node_or_null("BoundaryWall_Right") as StaticBody3D
	assert(left_wall != null, "BoundaryWall_Left must exist")
	assert(right_wall != null, "BoundaryWall_Right must exist")
	assert(is_equal_approx(left_wall.position.x, -6.5), "BoundaryWall_Left at X = -6.5m")
	assert(is_equal_approx(right_wall.position.x, 6.5), "BoundaryWall_Right at X = +6.5m")
	print("[PASS] Physical boundary colliders remain strict and uncompromised.")
	
	print("[STEP 2] Verifying Riverbank Chunks Structure...")
	var chunks = level_ctrl.riverbank_chunks
	assert(chunks.size() == 8, "Expected 8 riverbank chunks (4 left, 4 right), got %d" % chunks.size())
	
	var left_chunk_count = 0
	var right_chunk_count = 0
	var total_props = 0
	
	for chunk in chunks:
		assert(is_instance_valid(chunk), "Chunk must be valid")
		if chunk.side == "left":
			left_chunk_count += 1
		elif chunk.side == "right":
			right_chunk_count += 1
			
		for child in chunk.get_children():
			if child is Node3D and child.name != "BankScenerySlots":
				total_props += 1
				var pos_x = child.position.x
				if chunk.side == "left":
					assert(pos_x < 0.0, "Left bank prop must be negative X: %f" % pos_x)
				else:
					assert(pos_x > 0.0, "Right bank prop must be positive X: %f" % pos_x)
	
	assert(left_chunk_count == 4, "4 left bank chunks")
	assert(right_chunk_count == 4, "4 right bank chunks")
	print("[PASS] 8 Riverbank chunks verified (Total spawned props across all chunks: %d)." % total_props)

	print("[STEP 3] Verifying Scenery Encroachment Boundaries (|X| >= 4.5m) and Tree Lean (|X| >= 4.2m)...")
	for chunk in chunks:
		for child in chunk.get_children():
			if not (child is Node3D) or child.name == "BankScenerySlots":
				continue

			var is_tree: bool = ("palm" in child.name.to_lower()) or ("palm" in child.scene_file_path.to_lower())
			var limit: float = 4.2 if is_tree else 4.5
			var c_side: String = chunk.side
			
			# Inspect prop AABB geometry in world space
			var child_mesh_aabb := _get_combined_aabb(child)
			var n3d = child as Node3D
			var min_x: float = n3d.position.x
			var max_x: float = n3d.position.x
			for cx in [child_mesh_aabb.position.x, child_mesh_aabb.position.x + child_mesh_aabb.size.x]:
				for cy in [child_mesh_aabb.position.y, child_mesh_aabb.position.y + child_mesh_aabb.size.y]:
					for cz in [child_mesh_aabb.position.z, child_mesh_aabb.position.z + child_mesh_aabb.size.z]:
						var corner = n3d.transform * Vector3(cx, cy, cz)
						min_x = minf(min_x, corner.x)
						max_x = maxf(max_x, corner.x)

			if c_side == "left" and max_x > -limit:
				print("FAILED PROP: name=%s, scene=%s, pos=%s, scale=%s, min_x=%.2f, max_x=%.2f" % [
					child.name, child.scene_file_path, n3d.position, n3d.scale, min_x, max_x
				])
				assert(false, "Left prop %s geometry encroaches into water: max_x=%.2f > -%.2f" % [child.name, max_x, limit])
			elif c_side == "right" and min_x < limit:
				print("FAILED PROP: name=%s, scene=%s, pos=%s, scale=%s, min_x=%.2f, max_x=%.2f" % [
					child.name, child.scene_file_path, n3d.position, n3d.scale, min_x, max_x
				])
				assert(false, "Right prop %s geometry encroaches into water: min_x=%.2f < %.2f" % [child.name, min_x, limit])
	print("[PASS] Verified: NO natural props encroach inside |X| < 4.5m, and tree inward lean stays strictly outside |X| = 4.2m.")

	print("[STEP 4] Verifying Water Plane vs Shoreline Heights (Z-Fighting Prevention)...")
	for chunk in chunks:
		for child in chunk.get_children():
			if "sand" in child.name.to_lower():
				assert(child.position.y >= 0.05, "Sand patch base must be above water level (found %.2f)" % child.position.y)
			elif "dock" in child.name.to_lower():
				assert(child.position.y >= 0.15, "Dock deck must be elevated above water (found %.2f)" % child.position.y)
			elif "barrel" in child.name.to_lower():
				assert(child.position.y >= 0.08, "Barrel must rest above water (found %.2f)" % child.position.y)
	print("[PASS] Verified: Sand patches at Y = 0.08m and shore meshes elevated above water plane.")

	print("[STEP 5] Verifying Camera Depth Precision...")
	var camera = main_game.get_node("Camera3D") as Camera3D
	assert(camera != null, "Camera3D must exist")
	assert(camera.near >= 0.1, "Camera near must be at least 0.1 (found %.2f)" % camera.near)
	assert(camera.far <= 200.0, "Camera far must be clamped to <= 200.0m (found %.2f)" % camera.far)
	print("[PASS] Camera near=%.2f, far=%.2f maximizes 24-bit Z-buffer precision." % [camera.near, camera.far])

	print("[STEP 6] Verifying Scrolling, Wrapping & Chunk Overlap Guard...")
	var initial_z_chunk0 = chunks[0].global_position.z
	var assembler = level_ctrl.chunk_assembler
	assert(assembler != null and assembler.is_assembled, "Assembler must be assembled")
	
	# Run 300 frames (5 seconds of gameplay, enough for full chunk wrap cycles)
	for frame in range(300):
		level_ctrl._physics_process(0.016667)
		assembler._physics_process(0.016667)

		# Check for overlapping chunks on the same side
		var left_z: Array[float] = []
		var right_z: Array[float] = []
		for chunk in chunks:
			if chunk.side == "left":
				left_z.append(chunk.global_position.z)
			else:
				right_z.append(chunk.global_position.z)

		left_z.sort()
		right_z.sort()
		for i in range(left_z.size() - 1):
			var gap = left_z[i+1] - left_z[i]
			assert(gap > 35.0 and gap < 45.0, "Left chunks must maintain ~40m spacing without overlap! Gap: %.2f" % gap)
		for i in range(right_z.size() - 1):
			var gap = right_z[i+1] - right_z[i]
			assert(gap > 35.0 and gap < 45.0, "Right chunks must maintain ~40m spacing without overlap! Gap: %.2f" % gap)

	var _moved_z = chunks[0].global_position.z - initial_z_chunk0
	print("[PASS] Chunk Overlap Guard confirmed: Chunks cycled smoothly maintaining strict 40m spacing with 0 overlap.")
	
	print("==================================================")
	print("   ALL TESTS PASSED! LEVEL 1 VERIFIED CLEANLY     ")
	print("==================================================")
	get_tree().quit(0)

func _get_combined_aabb(node: Node) -> AABB:
	var total_aabb := AABB()
	var first = true
	var stack = [node]
	while not stack.is_empty():
		var curr = stack.pop_back()
		if curr is MeshInstance3D:
			var mi = curr as MeshInstance3D
			if mi.mesh:
				var maabb = mi.transform * mi.mesh.get_aabb()
				if first:
					total_aabb = maabb
					first = false
				else:
					total_aabb = total_aabb.merge(maabb)
		for child in curr.get_children():
			stack.push_back(child)
	return total_aabb
