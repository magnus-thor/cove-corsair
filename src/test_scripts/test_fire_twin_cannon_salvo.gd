@tool
# Turn off untyped warnings specifically for test harnesses:
@warning_ignore("untyped_declaration")
@warning_ignore("unsafe_property_access")
@warning_ignore("unsafe_method_access")
@warning_ignore("unsafe_cast")
extends Node

func _ready() -> void:
	print("==================================================")
	print("   TESTING FIRE TWIN CANNON SALVO PROJECTILE      ")
	print("==================================================")
	
	var salvo_scene = load("res://src/gameplay/projectiles/boss_projectile_twin_cannon_salvo.tscn") as PackedScene
	assert(salvo_scene != null, "Failed to load boss_projectile_twin_cannon_salvo.tscn")
	print("  [PASS] Successfully loaded boss_projectile_twin_cannon_salvo.tscn")
	
	var salvo = salvo_scene.instantiate() as Area3D
	assert(salvo != null, "Failed to instantiate salvo scene")
	print("  [PASS] Successfully instantiated salvo projectile")
	
	add_child(salvo)
	await get_tree().process_frame
	
	var spr = salvo.get_node_or_null("AmmoSprite") as Sprite3D
	assert(spr != null, "AmmoSprite node not found in salvo projectile")
	assert(spr.texture != null, "AmmoSprite texture was not loaded")
	print("  [PASS] AmmoSprite verified with texture size: %s" % str(spr.texture.get_size()))
	assert(salvo.is_in_group("enemy_projectiles"), "Salvo projectile must belong to enemy_projectiles group")
	print("  [PASS] Salvo projectile verified in 'enemy_projectiles' group")
	
	var col = salvo.get_node_or_null("CollisionShape3D") as CollisionShape3D
	assert(col != null, "CollisionShape3D not found")
	assert(col.shape != null, "Collision shape is null")
	print("  [PASS] Collision shape verified (%s)" % col.shape.get_class())
	
	# Verify movement
	var init_z = salvo.global_position.z
	salvo._physics_process(0.1)
	assert(salvo.global_position.z > init_z, "Salvo should travel downriver (+Z) toward player")
	print("  [PASS] Physics trajectory verified (downriver +Z forward motion)")
	
	salvo.queue_free()
	
	# Test AmmoData resource
	var ammo_res = load("res://src/data/resources/user_ammo/ammo_fire_twin_cannon_salvo.tres")
	assert(ammo_res != null, "ammo_fire_twin_cannon_salvo.tres resource should exist")
	print("  [PASS] ammo_fire_twin_cannon_salvo.tres loaded successfully")
	
	print("==================================================")
	print("   ALL FIRE TWIN CANNON SALVO TESTS PASSED        ")
	print("==================================================")
	get_tree().quit(0)
