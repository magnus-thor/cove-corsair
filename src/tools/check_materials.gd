@tool
extends SceneTree

func _init() -> void:
	print("--- CHECKING MODEL MATERIALS ---")
	var paths: Array[String] = [
		"res://assets/models/user/vessels/the_sloop.glb",
		"res://assets/models/enemy/vessels/boss_war_barge.glb",
		"res://assets/models/enemy/vessels/captain_bone-beard’s_twin_frigate.glb",
		"res://assets/models/enemy/vessels/boss_siege_fortress.glb",
		"res://assets/models/enemy/vessels/ghost_sloop.glb"
	]
	for p in paths:
		var scn: PackedScene = load(p) as PackedScene
		var inst: Node3D = scn.instantiate() as Node3D
		print("Model: ", p.get_file())
		var stack: Array[Node] = [inst]
		while not stack.is_empty():
			var cur: Node = stack.pop_back()
			if cur is MeshInstance3D:
				var mi: MeshInstance3D = cur as MeshInstance3D
				print("  MeshInstance3D: ", mi.name, " layers=", mi.layers, " cast_shadow=", mi.cast_shadow)
				for s in range(mi.get_surface_override_material_count()):
					print("    override_mat[", s, "]: ", mi.get_surface_override_material(s))
				if mi.mesh:
					for s in range(mi.mesh.get_surface_count()):
						var mat = mi.mesh.surface_get_material(s)
						if mat is BaseMaterial3D:
							print("    surface_mat[", s, "]: cull_mode=", mat.cull_mode, " transparency=", mat.transparency, " shading_mode=", mat.shading_mode)
			for child in cur.get_children():
				stack.append(child)
		inst.free()
	quit(0)
