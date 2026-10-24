@tool
@warning_ignore("untyped_declaration")
@warning_ignore("unsafe_property_access")
@warning_ignore("unsafe_method_access")
@warning_ignore("unsafe_cast")
extends Node

const MODEL_FOUNDATION: PackedScene = preload("res://assets/models/cove/SM_Plot_Foundation.glb")
const MODEL_TAVERN: PackedScene = preload("res://assets/models/cove/SM_Tavern_Inn.glb")
const MODEL_FORGE: PackedScene = preload("res://assets/models/cove/SM_Blacksmith_Forge.glb")
const MODEL_HARBOR: PackedScene = preload("res://assets/models/cove/SM_Harbor_Office.glb")
const PLOT_SCENE: PackedScene = preload("res://scenes/cove_hub/building_plot.tscn")

func _ready() -> void:
	print("==================================================")
	print("   TESTING COVE 3D MODELS IMPORT & COLLISION AABB ")
	print("==================================================")

	assert(MODEL_FOUNDATION != null, "SM_Plot_Foundation.glb must load")
	assert(MODEL_TAVERN != null, "SM_Tavern_Inn.glb must load")
	assert(MODEL_FORGE != null, "SM_Blacksmith_Forge.glb must load")
	assert(MODEL_HARBOR != null, "SM_Harbor_Office.glb must load")
	print("[PASS] All 4 GLB models loaded successfully.")

	# Test Plot instantiation with Foundation
	var plot: BuildingPlot = PLOT_SCENE.instantiate() as BuildingPlot
	assert(plot != null, "BuildingPlot must instantiate")
	plot.foundation_scene = MODEL_FOUNDATION
	plot.building_scene = MODEL_TAVERN
	plot.is_unlocked = false
	add_child(plot)

	await get_tree().process_frame

	print("[STEP 1] Testing Foundation collision fitting (locked plot)...")
	var shape: CollisionShape3D = plot.collision_shape
	assert(shape != null and shape.shape != null, "Collision shape must exist")
	var box: BoxShape3D = shape.shape as BoxShape3D
	assert(box != null, "Shape must be BoxShape3D")
	print("  Foundation box size: %s, position: %s" % [box.size, shape.position])
	assert(box.size.x > 2.0 and box.size.x < 2.6, "Foundation width should be ~2.3m")
	assert(box.size.y > 0.5 and box.size.y < 1.0, "Foundation height should be ~0.7m")
	assert(shape.position.y > 0.2 and shape.position.y < 0.5, "Center Y should be around 0.35m")
	print("[PASS] Foundation collision shape fitted accurately.")

	print("[STEP 2] Testing Tavern collision fitting (unlocked plot)...")
	plot.is_unlocked = true
	await get_tree().process_frame
	box = plot.collision_shape.shape as BoxShape3D
	print("  Tavern box size: %s, position: %s" % [box.size, plot.collision_shape.position])
	assert(box.size.x > 2.5 and box.size.x < 3.0, "Tavern width should be ~2.7m")
	assert(box.size.y > 2.8 and box.size.y < 3.3, "Tavern height should be ~3.1m")
	print("[PASS] Tavern collision shape fitted accurately.")

	print("[STEP 3] Testing Forge collision fitting...")
	plot.building_scene = MODEL_FORGE
	await get_tree().process_frame
	box = plot.collision_shape.shape as BoxShape3D
	print("  Forge box size: %s, position: %s" % [box.size, plot.collision_shape.position])
	assert(box.size.x > 2.7 and box.size.x < 3.2, "Forge width should be ~3.0m")
	assert(box.size.y > 2.1 and box.size.y < 2.5, "Forge height should be ~2.35m")
	print("[PASS] Forge collision shape fitted accurately.")

	print("[STEP 4] Testing Harbor Office collision fitting...")
	plot.building_scene = MODEL_HARBOR
	await get_tree().process_frame
	box = plot.collision_shape.shape as BoxShape3D
	print("  Harbor Office box size: %s, position: %s" % [box.size, plot.collision_shape.position])
	assert(box.size.x > 2.2 and box.size.x < 2.7, "Harbor Office width should be ~2.4m")
	assert(box.size.y > 3.4 and box.size.y < 3.9, "Harbor Office height should be ~3.7m")
	print("[PASS] Harbor Office collision shape fitted accurately.")

	print("==================================================")
	print("   ALL PHASE 4 COLLISION TESTS PASSED!            ")
	print("==================================================")
	get_tree().quit(0)
