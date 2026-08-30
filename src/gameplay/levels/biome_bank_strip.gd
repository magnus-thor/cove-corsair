extends Node3D

var side: String = "left" # or "right"
var strip_length: float = 40.0

func setup(p_side: String, p_length: float = 40.0) -> void:
	side = p_side
	strip_length = p_length
	generate_scenery()

func generate_scenery() -> void:
	# Clean up any existing children
	for child in get_children():
		child.queue_free()
		
	var sand_island_path = "res://assets/models/patch-sand.glb"
	var rock_island_path = "res://assets/models/rocks-sand-a.glb"
	var palm_straight_path = "res://assets/models/palm-detailed-straight.glb"
	var palm_bend_path = "res://assets/models/palm-detailed-bend.glb"
	
	var rocks_paths = [
		"res://assets/models/rocks-a.glb",
		"res://assets/models/rocks-b.glb",
		"res://assets/models/rocks-c.glb"
	]
	
	# Number of rocky/sandy zones along the 40m strip
	var steps = 4
	var step_size = strip_length / steps
	for i in range(steps):
		var z_pos = -strip_length / 2.0 + (i * step_size) + randf_range(-1.5, 1.5)
		
		# 1. Cliffs (placed further out)
		var cliff_x = randf_range(-18.0, -14.0) if side == "left" else randf_range(14.0, 18.0)
		var rock_res = load(rocks_paths.pick_random())
		if rock_res:
			var rock = rock_res.instantiate() as Node3D
			add_child(rock)
			rock.position = Vector3(cliff_x, -0.2, z_pos)
			# Towering cliff scale
			rock.scale = Vector3(randf_range(1.8, 2.8), randf_range(4.5, 7.0), randf_range(1.8, 2.8))
			rock.rotation.y = randf_range(0.0, TAU)
			rock.rotation.x = randf_range(-0.05, 0.05)
			rock.rotation.z = randf_range(-0.05, 0.05)
			_clean_shadow_nodes(rock)
			
		# 2. Sandy Shoals (placed closer to the water)
		var shoal_x = randf_range(-14.0, -9.5) if side == "left" else randf_range(9.5, 14.0)
		var shoal_res = load(sand_island_path if randf() < 0.6 else rock_island_path)
		if shoal_res:
			var shoal = shoal_res.instantiate() as Node3D
			add_child(shoal)
			shoal.position = Vector3(shoal_x, -0.1, z_pos + randf_range(-2.0, 2.0))
			shoal.scale = Vector3(randf_range(1.2, 1.8), randf_range(0.8, 1.2), randf_range(1.2, 1.8))
			shoal.rotation.y = randf_range(0.0, TAU)
			_clean_shadow_nodes(shoal)
			
			# 3. Add palms on sandy shoals
			if randf() < 0.7:
				var palm_res = load(palm_straight_path if randf() < 0.5 else palm_bend_path)
				if palm_res:
					var palm = palm_res.instantiate() as Node3D
					shoal.add_child(palm)
					palm.position = Vector3(randf_range(-0.5, 0.5), 0.0, randf_range(-0.5, 0.5))
					palm.scale = Vector3.ONE * randf_range(0.8, 1.3)
					palm.rotation.y = randf_range(0.0, TAU)
					_clean_shadow_nodes(palm)
					
func _clean_shadow_nodes(node: Node) -> void:
	if not node:
		return
		
	if node is GeometryInstance3D:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		
	var lower_name = node.name.to_lower()
	var is_shadow_node = false
	if "shadow" in lower_name or "decal" in lower_name or "projector" in lower_name or "card" in lower_name or "oblate" in lower_name or "sphere" in lower_name or "dark" in lower_name:
		is_shadow_node = true
		
	if is_shadow_node:
		node.queue_free()
		return
			
	for child in node.get_children():
		_clean_shadow_nodes(child)
