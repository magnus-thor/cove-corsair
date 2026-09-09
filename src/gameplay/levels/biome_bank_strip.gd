extends Node3D

var side: String = "left" # or "right"
var strip_length: float = 40.0
var biome: String = "smugglers_run"

func setup(p_side: String, p_length: float = 40.0, p_biome: String = "smugglers_run") -> void:
	side = p_side
	strip_length = p_length
	biome = p_biome
	generate_scenery()

func generate_scenery() -> void:
	for child in get_children():
		child.queue_free()
		
	_setup_bank_scenery_slots()
		
	match biome:
		"black_tide_bayou":
			_generate_bayou_scenery()
		"brimstone_bastion":
			_generate_bastion_scenery()
		_:
			_generate_tropical_scenery()

func _setup_bank_scenery_slots() -> void:
	var slots_container := Node3D.new()
	slots_container.name = "BankScenerySlots"
	add_child(slots_container)

	var multimesh_inst := MultiMeshInstance3D.new()
	multimesh_inst.name = "BankSceneryMultiMesh"
	slots_container.add_child(multimesh_inst)

	var step := 10.0
	var slot_count := ceili(strip_length / step)
	var shore_x := -7.5 if side == "left" else 7.5
	var start_z := -strip_length * 0.5

	for i in range(slot_count):
		var marker := Marker3D.new()
		marker.name = "Slot_%d" % i
		marker.position = Vector3(shore_x, 0.0, start_z + (i + 0.5) * step)
		slots_container.add_child(marker)

func _generate_tropical_scenery() -> void:
	var sand_island_path = "res://assets/models/patch-sand.glb"
	var rock_island_path = "res://assets/models/rocks-sand-a.glb"
	var palm_straight_path = "res://assets/models/palm-detailed-straight.glb"
	var palm_bend_path = "res://assets/models/palm-detailed-bend.glb"
	var rocks_paths = ["res://assets/models/rocks-a.glb", "res://assets/models/rocks-b.glb", "res://assets/models/rocks-c.glb"]
	
	var steps = 4
	var step_size = strip_length / steps
	for i in range(steps):
		var z_pos = -strip_length / 2.0 + (i * step_size) + randf_range(-1.5, 1.5)
		
		# 1. Cliffs (Outer band: roots strictly in [-10.5, -8.5] / [8.5, 10.5])
		var cliff_x = randf_range(-10.5, -8.5) if side == "left" else randf_range(8.5, 10.5)
		var rock_res = load(rocks_paths.pick_random())
		if rock_res:
			var rock = rock_res.instantiate() as Node3D
			add_child(rock)
			rock.position = Vector3(cliff_x, 0.05, z_pos)
			rock.scale = Vector3(randf_range(1.4, 2.0), randf_range(4.0, 6.0), randf_range(1.4, 2.0))
			rock.rotation.y = randf_range(0.0, TAU)
			_clean_shadow_nodes(rock)
			_enforce_navigable_clearance(rock)
			
		# 2. Sandy Shoals (Inner band: roots strictly in [-8.5, -6.5] / [6.5, 8.5])
		var shoal_x = randf_range(-8.5, -6.5) if side == "left" else randf_range(6.5, 8.5)
		var shoal_res = load(sand_island_path if randf() < 0.6 else rock_island_path)
		if shoal_res:
			var shoal = shoal_res.instantiate() as Node3D
			add_child(shoal)
			shoal.position = Vector3(shoal_x, 0.08, z_pos + randf_range(-1.5, 1.5))
			shoal.scale = Vector3(randf_range(1.1, 1.4), randf_range(0.7, 1.0), randf_range(1.1, 1.4))
			shoal.rotation.y = randf_range(0.0, TAU)
			_clean_shadow_nodes(shoal)
			
			if randf() < 0.7:
				var palm_res = load(palm_straight_path if randf() < 0.5 else palm_bend_path)
				if palm_res:
					var palm = palm_res.instantiate() as Node3D
					shoal.add_child(palm)
					palm.position = Vector3(randf_range(-0.2, 0.2), 0.0, randf_range(-0.2, 0.2))
					palm.scale = Vector3.ONE * randf_range(0.8, 1.2)
					palm.rotation.y = randf_range(0.0, TAU)
					_clean_shadow_nodes(palm)

			_enforce_navigable_clearance(shoal)

func _generate_bayou_scenery() -> void:
	var rock_island_path = "res://assets/models/rocks-sand-b.glb"
	var rocks_paths = ["res://assets/models/rocks-a.glb", "res://assets/models/rocks-c.glb"]
	
	var steps = 4
	var step_size = strip_length / steps
	for i in range(steps):
		var z_pos = -strip_length / 2.0 + (i * step_size) + randf_range(-1.5, 1.5)
		
		# 1. Dark Mossy Mangrove Cliffs (Outer band: roots strictly in [-10.5, -8.5] / [8.5, 10.5])
		var cliff_x = randf_range(-10.5, -8.5) if side == "left" else randf_range(8.5, 10.5)
		var rock_res = load(rocks_paths.pick_random())
		if rock_res:
			var rock = rock_res.instantiate() as Node3D
			add_child(rock)
			rock.position = Vector3(cliff_x, 0.05, z_pos)
			rock.scale = Vector3(randf_range(1.4, 2.0), randf_range(3.5, 5.5), randf_range(1.4, 2.0))
			rock.rotation.y = randf_range(0.0, TAU)
			_tint_node(rock, Color(0.35, 0.48, 0.38))
			_clean_shadow_nodes(rock)
			_enforce_navigable_clearance(rock)
			
		# 2. Mangrove Shoals & Root Archs (Inner band: roots strictly in [-8.5, -6.5] / [6.5, 8.5])
		var shoal_x = randf_range(-8.5, -6.5) if side == "left" else randf_range(6.5, 8.5)
		var shoal_res = load(rock_island_path)
		if shoal_res:
			var shoal = shoal_res.instantiate() as Node3D
			add_child(shoal)
			shoal.position = Vector3(shoal_x, 0.08, z_pos + randf_range(-1.5, 1.5))
			shoal.scale = Vector3(randf_range(1.0, 1.3), randf_range(0.6, 0.9), randf_range(1.0, 1.3))
			shoal.rotation.y = randf_range(0.0, TAU)
			_tint_node(shoal, Color(0.28, 0.42, 0.32))
			_clean_shadow_nodes(shoal)
			
			# Bioluminescent Lantern on wooden post
			if randf() < 0.65:
				_spawn_bayou_lantern(shoal)

			_enforce_navigable_clearance(shoal)

func _spawn_bayou_lantern(parent_node: Node3D) -> void:
	var post = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.08
	cyl.bottom_radius = 0.1
	cyl.height = 1.4
	post.mesh = cyl
	var post_mat = StandardMaterial3D.new()
	post_mat.albedo_color = Color(0.2, 0.18, 0.14)
	post.material_override = post_mat
	parent_node.add_child(post)
	post.position = Vector3(randf_range(-0.4, 0.4), 0.7, randf_range(-0.4, 0.4))
	
	# Lantern Orb
	var lantern = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.22
	sphere.height = 0.44
	lantern.mesh = sphere
	var lantern_mat = StandardMaterial3D.new()
	lantern_mat.albedo_color = Color(0.2, 0.95, 0.7, 1.0)
	lantern_mat.emission_enabled = true
	lantern_mat.emission = Color(0.3, 1.8, 1.2, 1.0)
	lantern.material_override = lantern_mat
	post.add_child(lantern)
	lantern.position = Vector3(0.0, 0.6, 0.0)

func _generate_bastion_scenery() -> void:
	var wall_path = "res://assets/models/castle-wall.glb"
	var tower_path = "res://assets/models/tower-top.glb"
	var rocks_paths = ["res://assets/models/rocks-a.glb", "res://assets/models/rocks-b.glb"]
	
	var steps = 4
	var step_size = strip_length / steps
	for i in range(steps):
		var z_pos = -strip_length / 2.0 + (i * step_size) + randf_range(-1.5, 1.5)
		
		# 1. Towering Basalt Columns (Outer band: roots strictly in [-10.5, -8.5] / [8.5, 10.5])
		var cliff_x = randf_range(-10.5, -8.5) if side == "left" else randf_range(8.5, 10.5)
		var rock_res = load(rocks_paths.pick_random())
		if rock_res:
			var rock = rock_res.instantiate() as Node3D
			add_child(rock)
			rock.position = Vector3(cliff_x, 0.05, z_pos)
			rock.scale = Vector3(randf_range(1.4, 2.0), randf_range(4.0, 6.5), randf_range(1.4, 2.0))
			rock.rotation.y = randf_range(0.0, TAU)
			_tint_node(rock, Color(0.18, 0.18, 0.22)) # Dark basalt
			_clean_shadow_nodes(rock)
			_enforce_navigable_clearance(rock)
			
		# 2. Iron Fortress Battlements (Inner band: roots strictly in [-8.5, -6.5] / [6.5, 8.5])
		var wall_x = randf_range(-8.5, -6.5) if side == "left" else randf_range(6.5, 8.5)
		var is_tower = (i % 2 == 0)
		var res = load(tower_path if is_tower else wall_path)
		if res:
			var fortress_piece = res.instantiate() as Node3D
			add_child(fortress_piece)
			fortress_piece.position = Vector3(wall_x, 0.0, z_pos)
			fortress_piece.scale = Vector3.ONE * randf_range(0.9, 1.2)
			fortress_piece.rotation.y = 0.0 if side == "left" else PI
			_tint_node(fortress_piece, Color(0.3, 0.25, 0.25))
			_clean_shadow_nodes(fortress_piece)
			
			# Lava Brazier on battlement
			if is_tower or randf() < 0.5:
				_spawn_lava_brazier(fortress_piece)

			_enforce_navigable_clearance(fortress_piece)

func _spawn_lava_brazier(parent_node: Node3D) -> void:
	var brazier = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.35
	cyl.bottom_radius = 0.2
	cyl.height = 0.5
	brazier.mesh = cyl
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.2, 0.2)
	mat.metallic = 0.8
	brazier.material_override = mat
	parent_node.add_child(brazier)
	brazier.position = Vector3(0.0, 1.2, 0.0)
	
	# Fiery Ember Core
	var fire = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.25
	sphere.height = 0.4
	fire.mesh = sphere
	var fire_mat = StandardMaterial3D.new()
	fire_mat.albedo_color = Color(1.0, 0.4, 0.05)
	fire_mat.emission_enabled = true
	fire_mat.emission = Color(3.0, 1.0, 0.1)
	fire.material_override = fire_mat
	brazier.add_child(fire)
	fire.position = Vector3(0.0, 0.25, 0.0)

func _tint_node(node: Node, tint: Color) -> void:
	if node is MeshInstance3D:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = tint
		mat.roughness = 0.8
		node.material_override = mat
	for child in node.get_children():
		_tint_node(child, tint)
					
func _clean_shadow_nodes(node: Node) -> void:
	if not node:
		return
		
	if node is GeometryInstance3D:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		
	var lower_name = node.name.to_lower()
	var is_shadow_node = false
	if "shadow" in lower_name or "decal" in lower_name or "projector" in lower_name or "card" in lower_name or "oblate" in lower_name or "shadow_sphere" in lower_name or "sphere_shadow" in lower_name or "dark" in lower_name:
		is_shadow_node = true
		
	if is_shadow_node:
		node.queue_free()
		return
			
	for child in node.get_children():
		_clean_shadow_nodes(child)

# ── Navigable corridor clearance enforcement ──────────────────────────────────

## Recursively collects all MeshInstance3D nodes in the given hierarchy.
func _collect_mesh_instances(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		result.append(node as MeshInstance3D)
	for child in node.get_children():
		_collect_mesh_instances(child, result)

## Computes the local transform of node relative to root by walking parent transforms.
func _get_relative_transform(node: Node3D, root: Node3D) -> Transform3D:
	var xform := Transform3D.IDENTITY
	var curr: Node = node
	while curr and curr != root and curr is Node3D:
		xform = (curr as Node3D).transform * xform
		curr = curr.get_parent()
	return xform

## Enforces that no visual geometry in the prop hierarchy crosses the +/- 6.0 navigable lane boundary.
## If any geometry overshoots the channel limit, the prop is shifted outward.
func _enforce_navigable_clearance(prop: Node3D, buffer: float = 0.05) -> void:
	if not prop:
		return
	
	var min_x := INF
	var max_x := -INF
	var mesh_instances: Array[MeshInstance3D] = []
	_collect_mesh_instances(prop, mesh_instances)
	
	for mi in mesh_instances:
		if not mi.mesh:
			continue
		var aabb: AABB = mi.mesh.get_aabb()
		var rel_xform: Transform3D = _get_relative_transform(mi, self)
		for i in range(8):
			var corner := aabb.position + Vector3(
				aabb.size.x if (i & 1) else 0.0,
				aabb.size.y if (i & 2) else 0.0,
				aabb.size.z if (i & 4) else 0.0
			)
			var pt := rel_xform * corner
			min_x = minf(min_x, pt.x)
			max_x = maxf(max_x, pt.x)
			
	if min_x == INF or max_x == -INF:
		return
		
	var lane_limit: float = 6.0 + buffer
	if side == "left":
		# Left bank: navigable water is X >= -6.0. Visual geometry must be strictly <= -lane_limit (-6.05).
		if max_x > -lane_limit:
			var overshoot: float = max_x - (-lane_limit)
			prop.position.x -= overshoot
	else:
		# Right bank: navigable water is X <= +6.0. Visual geometry must be strictly >= +lane_limit (+6.05).
		if min_x < lane_limit:
			var undershoot: float = lane_limit - min_x
			prop.position.x += undershoot
