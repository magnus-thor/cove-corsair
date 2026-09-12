extends Node

func _ready() -> void:
	print("==================================================")
	print("   DIAGNOSTIC TEST: 3D VISUAL BLINKING ISOLATION  ")
	print("==================================================")
	
	GameState.should_auto_start = true
	GameState.current_level = 1
	
	var main_scene = load("res://src/core/main_game.tscn") as PackedScene
	var main_inst = main_scene.instantiate()
	add_child(main_inst)
	
	for i in range(5):
		await get_tree().process_frame
		
	print("\n--- 1. Node Count & Tree Audit ---")
	print("Total active node count: %d" % get_tree().get_node_count())
	var level_ctrl = get_tree().get_first_node_in_group("level_controller")
	if level_ctrl and level_ctrl.has_method("run_blinking_diagnostic"):
		level_ctrl.run_blinking_diagnostic()
	
	var all_meshes: Array[MeshInstance3D] = []
	_find_all_meshes(main_inst, all_meshes)
	print("Total MeshInstance3D nodes in tree: %d" % all_meshes.size())
	
	var visible_meshes = all_meshes.filter(func(m): return m.is_visible_in_tree())
	print("Visible MeshInstance3D nodes: %d" % visible_meshes.size())
	
	print("\n--- 2. Water Mesh Audit ---")
	var water_meshes: Array[MeshInstance3D] = []
	for m in all_meshes:
		var is_water = false
		if "water" in m.name.to_lower():
			is_water = true
		if m.material_override and m.material_override is ShaderMaterial:
			var sm = m.material_override as ShaderMaterial
			if sm.shader and "water" in sm.shader.resource_path.to_lower():
				is_water = true
		if is_water:
			water_meshes.append(m)
			var parent_name = String(m.get_parent().name) if m.get_parent() else "root"
			print("Water mesh: '%s' | parent: '%s' | visible: %s | Y: %.3f | global_pos: %s" % [
				m.name, parent_name, m.is_visible_in_tree(), m.global_position.y, str(m.global_position)
			])

	print("\n--- 3. Visibility Rapid-Toggling Monitor (60 Frames) ---")
	# Check if any nodes are rapidly flipping .visible true/false
	var vis_toggle_counts = {}
	var prev_states = {}
	for m in all_meshes:
		if is_instance_valid(m):
			prev_states[m.get_instance_id()] = m.visible
			vis_toggle_counts[m.get_instance_id()] = 0

	for tick in range(60):
		await get_tree().process_frame
		for m in all_meshes:
			if is_instance_valid(m):
				var id = m.get_instance_id()
				var cur_vis = m.visible
				if prev_states.has(id) and prev_states[id] != cur_vis:
					vis_toggle_counts[id] = vis_toggle_counts.get(id, 0) + 1
				prev_states[id] = cur_vis
				
	var total_toggles = 0
	for id in vis_toggle_counts:
		if vis_toggle_counts[id] > 0:
			total_toggles += vis_toggle_counts[id]
			print("[VISIBILITY FLIP] Mesh instance %d flipped %d times!" % [id, vis_toggle_counts[id]])
	if total_toggles == 0:
		print("[PASS] Zero nodes are rapidly flipping .visible true/false!")
	else:
		print("[FAIL] Rapid visibility flips detected: %d total toggles!" % total_toggles)

	print("\n--- 4. Riverbank Props Isolation Test (Turning riverbanks OFF) ---")
	var riverbank_chunks = get_tree().get_nodes_in_group("riverbank_chunk")
	print("Disabling visibility on all %d riverbank chunks..." % riverbank_chunks.size())
	for c in riverbank_chunks:
		if is_instance_valid(c):
			c.visible = false

	# Let game scroll for 60 frames with riverbanks OFF
	var dupes_without_banks = 0
	for tick in range(60):
		await get_tree().physics_frame
		if tick % 15 == 0:
			var cur_meshes: Array[MeshInstance3D] = []
			_find_all_meshes(main_inst, cur_meshes)
			var pos_map = {}
			for m in cur_meshes:
				if is_instance_valid(m) and m.is_inside_tree() and m.is_visible_in_tree():
					if "water" in m.name.to_lower() or "backdrop" in m.name.to_lower() or "quad" in m.name.to_lower():
						continue
					var k = "%0.1f_%0.1f" % [m.global_position.x, m.global_position.z]
					if pos_map.has(k):
						dupes_without_banks += 1
					pos_map[k] = m.name

	print("Duplicates without riverbanks: %d" % dupes_without_banks)
	if dupes_without_banks == 0:
		print("[ISOLATION RESULT] With riverbanks disabled, track chunks have 0 duplicates and 0 flickering geometry!")
	else:
		print("[ISOLATION RESULT] Duplicates still found even without riverbanks!")

	print("\n--- 5. Riverbank Props Re-enabled & Frustum Culling / Margin Check ---")
	for c in riverbank_chunks:
		if is_instance_valid(c):
			c.visible = true

	var bank_geoms: Array[GeometryInstance3D] = []
	for c in riverbank_chunks:
		_find_all_geom(c, bank_geoms)
	print("Total GeometryInstance3Ds in riverbanks: %d" % bank_geoms.size())
	
	var zero_margin_count = 0
	for g in bank_geoms:
		if g.extra_cull_margin < 1.0:
			zero_margin_count += 1
	print("Meshes with extra_cull_margin == 0.0: %d / %d" % [zero_margin_count, bank_geoms.size()])

	print("\n==================================================")
	print("   DIAGNOSTIC TEST COMPLETE                       ")
	print("==================================================")
	get_tree().quit(0)

func _find_all_meshes(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		_find_all_meshes(child, result)

func _find_all_geom(node: Node, result: Array[GeometryInstance3D]) -> void:
	if node is GeometryInstance3D:
		result.append(node)
	for child in node.get_children():
		_find_all_geom(child, result)
