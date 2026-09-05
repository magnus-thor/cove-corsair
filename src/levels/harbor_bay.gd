class_name HarborBay
extends Node3D

## HarborBay manages the calm 3D harbor presentation for the main menu.
## Frames the active player vessel peacefully resting on water with gentle bobbing,
## docks, tropical palm trees, and coastal rocks.

@onready var water_mesh: MeshInstance3D = $CalmWater

func _ready() -> void:
	add_to_group("harbor_bay")
	_apply_biome_theme(GameState.current_level)

func _apply_biome_theme(level_num: int) -> void:
	if not water_mesh:
		return
	var mat = water_mesh.get_surface_override_material(0) as ShaderMaterial
	if not mat:
		mat = water_mesh.material_override as ShaderMaterial
	if not mat:
		return
		
	# Subtle tint shifts reflecting the upcoming expedition destination
	match level_num:
		2, 5: # Black Tide Bayou / Abyss
			mat.set_shader_parameter("albedo", Color(0.08, 0.45, 0.42, 0.92))
		3, 6: # Brimstone Bastion / Inferno
			mat.set_shader_parameter("albedo", Color(0.22, 0.38, 0.48, 0.94))
		_: # Smuggler's Run / Tropical Cove
			mat.set_shader_parameter("albedo", Color(0.12, 0.62, 0.78, 0.90))

func on_expedition_changed(level_num: int) -> void:
	_apply_biome_theme(level_num)

func transition_out(duration: float = 0.8) -> void:
	var tween = create_tween().set_parallel(true)
	# Smoothly slide harbor props slightly backward and fade them
	tween.tween_property(self, "position:z", position.z + 10.0, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	for child in get_children():
		if child is GeometryInstance3D:
			tween.tween_property(child, "transparency", 1.0, duration * 0.8).set_trans(Tween.TRANS_SINE)
			
	tween.chain().tween_callback(func():
		visible = false
		queue_free()
	)
