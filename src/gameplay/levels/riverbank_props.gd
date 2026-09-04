extends Node3D

# ──────────────────────────────────────────────────────────────────────────────
# RIVERBANK PROPS  –  Layer 2 of the 3-Layer Parallax Environment System
#
# One recycled chunk (left or right side).  Spawns 3–4 rock / cliff / foliage
# props strictly outside the playable corridor:
#   Left  side: outer centres X ≈ –11.5, inner centres X ≈ –10.2
#   Right side: outer centres X ≈ +11.5, inner centres X ≈ +10.2
#
# X bounds are kept far enough from ±7.5 lane edge that even the largest scaled
# mesh geometry cannot reach the playable corridor.
#
# Material strategy:
#   - Tropical biome → _kill_shadows() only; GLB textures/colours preserved.
#   - Biome-tinted props → _apply_tint() replaces material with flat colour.
# ──────────────────────────────────────────────────────────────────────────────

var side         : String = "left"
var chunk_length : float  = 40.0
var biome        : String = "smugglers_run"

func _ready() -> void:
	add_to_group("riverbank_chunk")

# ── Public API ────────────────────────────────────────────────────────────────

func setup(p_side: String, p_length: float = 40.0, p_biome: String = "smugglers_run") -> void:
	side         = p_side
	chunk_length = p_length
	biome        = p_biome
	_generate()

# ── Internal ──────────────────────────────────────────────────────────────────

func _generate() -> void:
	# Clear previous props (called on recycle)
	for child in get_children():
		child.queue_free()

	match biome:
		"black_tide_bayou":
			_spawn_bayou()
		"brimstone_bastion":
			_spawn_bastion()
		_:
			_spawn_tropical()

# ── X helpers ─────────────────────────────────────────────────────────────────
# Bank Chunk Root Anchor Offsets:
#   Left Bank Meshes:  roots strictly at X <= -6.5 (ranging outward from -6.5 to -10.5).
#   Right Bank Meshes: roots strictly at X >= +6.5 (ranging outward from +6.5 to +10.5).
# OUTER band: cliff / rock masses.  Range -10.5 .. -8.5 (left), +8.5 .. +10.5 (right).
# INNER band: shoals / foliage.     Range  -8.5 .. -6.5 (left), +6.5 ..  +8.5 (right).

func _rand_x_outer() -> float:
	if side == "left":
		return randf_range(-10.5, -8.5)
	return randf_range(8.5, 10.5)

func _rand_x_inner() -> float:
	if side == "left":
		return randf_range(-8.5, -6.5)
	return randf_range(6.5, 8.5)

# ── Biome: Tropical / Smuggler's Run ──────────────────────────────────────────

func _spawn_tropical() -> void:
	var rock_paths   := [
		"res://assets/models/rocks-a.glb",
		"res://assets/models/rocks-b.glb",
		"res://assets/models/rocks-c.glb",
	]
	var shoal_paths  := [
		"res://assets/models/patch-sand.glb",
		"res://assets/models/rocks-sand-a.glb",
		"res://assets/models/rocks-sand-c.glb",
	]
	var palm_paths   := [
		"res://assets/models/palm-detailed-straight.glb",
		"res://assets/models/palm-detailed-bend.glb",
	]

	var prop_count := randi_range(3, 5)
	var step       := chunk_length / float(prop_count)

	for i in range(prop_count):
		var z_pos := -chunk_length * 0.5 + i * step + randf_range(-1.5, 1.5)

		# Natural Tropical Coastal Boulders (no vertical stretching)
		var rock_res := load(rock_paths[randi() % rock_paths.size()])
		if rock_res:
			var rock := rock_res.instantiate() as Node3D
			add_child(rock)
			rock.position = Vector3(_rand_x_outer(), -0.2, z_pos)
			var base_s := randf_range(1.4, 2.0)
			rock.scale    = Vector3(
				base_s,
				base_s * randf_range(0.7, 1.1),
				base_s * randf_range(0.9, 1.2)
			)
			rock.rotation.y = randf_range(0.0, TAU)
			_kill_shadows(rock)
			_enforce_navigable_clearance(rock)

		# Sandy Shoals & Palm Clusters – inner band
		if randf() < 0.85:
			var shoal_res := load(shoal_paths[randi() % shoal_paths.size()])
			if shoal_res:
				var shoal := shoal_res.instantiate() as Node3D
				add_child(shoal)
				shoal.position = Vector3(
					_rand_x_inner(),
					-0.08,
					z_pos + randf_range(-1.5, 1.5)
				)
				shoal.scale    = Vector3(
					randf_range(1.1, 1.4),
					randf_range(0.7, 1.0),
					randf_range(1.1, 1.4)
				)
				shoal.rotation.y = randf_range(0.0, TAU)
				_kill_shadows(shoal)

				# Palm Tree Cluster on Shoal
				if randf() < 0.85:
					var palm_res := load(palm_paths[randi() % palm_paths.size()])
					if palm_res:
						var palm := palm_res.instantiate() as Node3D
						shoal.add_child(palm)
						palm.position    = Vector3(
							randf_range(-0.2, 0.2), 0.0, randf_range(-0.2, 0.2)
						)
						palm.scale       = Vector3.ONE * randf_range(0.8, 1.2)
						# Orient palm lean away from the river corridor
						var palm_lean_rot: float = randf_range(0.0, TAU)
						palm.rotation.y  = palm_lean_rot
						_kill_shadows(palm)

				_enforce_navigable_clearance(shoal)

# ── Biome: Black Tide Bayou ────────────────────────────────────────────────────

func _spawn_bayou() -> void:
	var rock_paths   := [
		"res://assets/models/rocks-a.glb",
		"res://assets/models/rocks-c.glb",
	]
	var shoal_path   := "res://assets/models/rocks-sand-b.glb"
	var tint_cliff   := Color(0.28, 0.42, 0.32)
	var tint_shoal   := Color(0.22, 0.35, 0.28)

	var prop_count := randi_range(3, 4)
	var step       := chunk_length / float(prop_count)

	for i in range(prop_count):
		var z_pos := -chunk_length * 0.5 + i * step + randf_range(-1.5, 1.5)

		# Dark mossy cliff mass
		var rock_res := load(rock_paths[randi() % rock_paths.size()])
		if rock_res:
			var rock := rock_res.instantiate() as Node3D
			add_child(rock)
			rock.position    = Vector3(_rand_x_outer(), -0.3, z_pos)
			rock.scale       = Vector3(
				randf_range(1.3, 1.8),
				randf_range(3.0, 5.0),
				randf_range(1.3, 1.8)
			)
			rock.rotation.y  = randf_range(0.0, TAU)
			_apply_tint(rock, tint_cliff)
			_enforce_navigable_clearance(rock)

		# Mangrove shoal with optional bioluminescent lantern
		if randf() < 0.75:
			var shoal_res := load(shoal_path)
			if shoal_res:
				var shoal := shoal_res.instantiate() as Node3D
				add_child(shoal)
				shoal.position   = Vector3(
					_rand_x_inner(), -0.15, z_pos + randf_range(-1.5, 1.5)
				)
				shoal.scale      = Vector3(
					randf_range(0.9, 1.3),
					randf_range(0.5, 0.9),
					randf_range(0.9, 1.3)
				)
				shoal.rotation.y = randf_range(0.0, TAU)
				_apply_tint(shoal, tint_shoal)

				if randf() < 0.6:
					_spawn_lantern(shoal)

				_enforce_navigable_clearance(shoal)

func _spawn_lantern(parent: Node3D) -> void:
	var post      := MeshInstance3D.new()
	var cyl       := CylinderMesh.new()
	cyl.top_radius    = 0.07
	cyl.bottom_radius = 0.09
	cyl.height        = 1.2
	post.mesh         = cyl
	var mat           := StandardMaterial3D.new()
	mat.albedo_color  = Color(0.18, 0.15, 0.12)
	mat.shading_mode  = BaseMaterial3D.SHADING_MODE_UNSHADED
	post.material_override = mat
	post.cast_shadow  = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(post)
	post.position = Vector3(randf_range(-0.3, 0.3), 0.6, randf_range(-0.3, 0.3))

	var orb      := MeshInstance3D.new()
	var sphere   := SphereMesh.new()
	sphere.radius = 0.18
	sphere.height = 0.36
	orb.mesh      = sphere
	var orb_mat  := StandardMaterial3D.new()
	orb_mat.albedo_color      = Color(0.2, 0.95, 0.7)
	orb_mat.emission_enabled  = true
	orb_mat.emission          = Color(0.3, 1.8, 1.2)
	orb_mat.shading_mode      = BaseMaterial3D.SHADING_MODE_UNSHADED
	orb.material_override     = orb_mat
	orb.cast_shadow           = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	post.add_child(orb)
	orb.position = Vector3(0.0, 0.55, 0.0)

# ── Biome: Brimstone Bastion ───────────────────────────────────────────────────

func _spawn_bastion() -> void:
	var rock_paths := [
		"res://assets/models/rocks-a.glb",
		"res://assets/models/rocks-b.glb",
	]
	var wall_path  := "res://assets/models/castle-wall.glb"
	var tower_path := "res://assets/models/tower-top.glb"
	var tint_rock  := Color(0.15, 0.15, 0.18)
	var tint_wall  := Color(0.28, 0.22, 0.22)

	var prop_count := randi_range(3, 4)
	var step       := chunk_length / float(prop_count)

	for i in range(prop_count):
		var z_pos := -chunk_length * 0.5 + i * step + randf_range(-1.5, 1.5)

		# Basalt column outer band
		var rock_res := load(rock_paths[randi() % rock_paths.size()])
		if rock_res:
			var rock := rock_res.instantiate() as Node3D
			add_child(rock)
			rock.position    = Vector3(_rand_x_outer(), -0.3, z_pos)
			rock.scale       = Vector3(
				randf_range(1.4, 2.0),
				randf_range(4.0, 6.0),
				randf_range(1.4, 2.0)
			)
			rock.rotation.y  = randf_range(0.0, TAU)
			_apply_tint(rock, tint_rock)
			_enforce_navigable_clearance(rock)

		# Fortress piece inner band
		if randf() < 0.75:
			var is_tower   := (i % 2 == 0)
			var struct_res := load(tower_path if is_tower else wall_path)
			if struct_res:
				var piece := struct_res.instantiate() as Node3D
				add_child(piece)
				piece.position    = Vector3(
					_rand_x_inner(), 0.0, z_pos
				)
				piece.scale       = Vector3.ONE * randf_range(0.9, 1.2)
				piece.rotation.y  = 0.0 if side == "left" else PI
				_apply_tint(piece, tint_wall)

				if is_tower or randf() < 0.5:
					_spawn_brazier(piece)

				_enforce_navigable_clearance(piece)

func _spawn_brazier(parent: Node3D) -> void:
	var bowl     := MeshInstance3D.new()
	var cyl      := CylinderMesh.new()
	cyl.top_radius    = 0.30
	cyl.bottom_radius = 0.18
	cyl.height        = 0.40
	bowl.mesh         = cyl
	var mat           := StandardMaterial3D.new()
	mat.albedo_color  = Color(0.2, 0.2, 0.2)
	mat.shading_mode  = BaseMaterial3D.SHADING_MODE_UNSHADED
	bowl.material_override = mat
	bowl.cast_shadow  = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(bowl)
	bowl.position = Vector3(0.0, 1.1, 0.0)

	var fire     := MeshInstance3D.new()
	var sphere   := SphereMesh.new()
	sphere.radius = 0.22
	sphere.height = 0.36
	fire.mesh     = sphere
	var fire_mat := StandardMaterial3D.new()
	fire_mat.albedo_color     = Color(1.0, 0.35, 0.05)
	fire_mat.emission_enabled = true
	fire_mat.emission         = Color(3.0, 0.9, 0.1)
	fire_mat.shading_mode     = BaseMaterial3D.SHADING_MODE_UNSHADED
	fire.material_override    = fire_mat
	fire.cast_shadow          = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bowl.add_child(fire)
	fire.position = Vector3(0.0, 0.2, 0.0)

# ── Material / shadow helpers ──────────────────────────────────────────────────

## Recursively disables shadows WITHOUT touching any material.
## Use this for tropical biome props so their original GLB textures show through.
func _kill_shadows(node: Node) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).cast_shadow = \
			GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_kill_shadows(child)

## Applies a flat tint colour + UNSHADED + shadow OFF to every MeshInstance3D.
## Use for biome-specific colour grading (bayou greens, bastion darks).
func _apply_tint(node: Node, tint: Color) -> void:
	if node is MeshInstance3D:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		if tint != Color.WHITE:
			mat.albedo_color = tint
		node.material_override = mat
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).cast_shadow = \
			GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_apply_tint(child, tint)

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
