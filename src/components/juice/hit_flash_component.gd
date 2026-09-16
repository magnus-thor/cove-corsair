class_name HitFlashComponent
extends Node

## Universal Hit Flash Component for 3D Meshes and Sprites.
## Provides tactile instant white-flash feedback on hit.

@export var target_root: Node3D
@export var flash_duration: float = 0.06

static var _shared_flash_mat: StandardMaterial3D = null

var _cached_materials: Dictionary = {} # MeshInstance3D -> Material
var _cached_modulates: Dictionary = {} # Sprite3D -> Color
var _flash_timer: SceneTreeTimer = null

static func get_flash_material() -> StandardMaterial3D:
	if _shared_flash_mat == null:
		_shared_flash_mat = StandardMaterial3D.new()
		_shared_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_shared_flash_mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	return _shared_flash_mat

func _ready() -> void:
	if target_root == null and get_parent() is Node3D:
		target_root = get_parent() as Node3D

## Triggers the white hit flash on all meshes and sprites under target_root
func flash(duration: float = -1.0) -> void:
	var d = duration if duration > 0.0 else flash_duration
	var root = target_root if target_root else (get_parent() as Node3D)
	if not root or not is_instance_valid(root):
		return
	HitFlashComponent.flash_node(root, d)

## Static utility to flash any node hierarchy without requiring component instantiation
static func flash_node(root_node: Node, duration: float = 0.06) -> void:
	if not root_node or not is_instance_valid(root_node):
		return
	
	var tree = root_node.get_tree()
	if not tree:
		return

	var flash_mat = get_flash_material()
	var meshes: Array[MeshInstance3D] = []
	var sprites: Array[SpriteBase3D] = []

	_gather_visuals(root_node, meshes, sprites)

	var orig_materials: Dictionary = {}
	for m in meshes:
		if is_instance_valid(m):
			if m.has_meta("_hit_flash_orig_mat"):
				orig_materials[m] = m.get_meta("_hit_flash_orig_mat")
			else:
				orig_materials[m] = m.material_override
				m.set_meta("_hit_flash_orig_mat", m.material_override)
			m.material_override = flash_mat

	var orig_modulates: Dictionary = {}
	for s in sprites:
		if is_instance_valid(s):
			if s.has_meta("_hit_flash_orig_mod"):
				orig_modulates[s] = s.get_meta("_hit_flash_orig_mod")
			else:
				orig_modulates[s] = s.modulate
				s.set_meta("_hit_flash_orig_mod", s.modulate)
			var cur_alpha = orig_modulates[s].a
			s.modulate = Color(3.5, 3.5, 3.5, cur_alpha)

	var timer = tree.create_timer(duration, true, false, true)
	timer.timeout.connect(func():
		for m in orig_materials.keys():
			if is_instance_valid(m):
				m.material_override = orig_materials[m]
				if m.has_meta("_hit_flash_orig_mat"):
					m.remove_meta("_hit_flash_orig_mat")
		for s in orig_modulates.keys():
			if is_instance_valid(s):
				s.modulate = orig_modulates[s]
				if s.has_meta("_hit_flash_orig_mod"):
					s.remove_meta("_hit_flash_orig_mod")
	)

static func _gather_visuals(node: Node, out_meshes: Array[MeshInstance3D], out_sprites: Array[SpriteBase3D]) -> void:
	# SpriteBase3D MUST be checked before GeometryInstance3D because SpriteBase3D extends GeometryInstance3D in Godot 4
	if node is SpriteBase3D:
		var lower_name = node.name.to_lower()
		# Skip health bars, UI elements, and HUD sprites
		if not ("health" in lower_name or "hp" in lower_name or "bar" in lower_name):
			out_sprites.append(node)
	elif node is MeshInstance3D:
		out_meshes.append(node)
	
	for child in node.get_children():
		_gather_visuals(child, out_meshes, out_sprites)
