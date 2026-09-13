extends Node

func _ready() -> void:
	print("==================================================")
	print("   TESTING BOSS BONE-BEARD RAPID HIT SCALE STABILITY ")
	print("==================================================")
	
	var boss_scene = load("res://src/gameplay/enemies/boss_bone_beard.tscn") as PackedScene
	assert(boss_scene != null, "Failed to load boss_bone_beard.tscn")
	
	var boss = boss_scene.instantiate() as BossBoneBeard
	assert(boss != null, "Failed to instantiate BossBoneBeard")
	
	add_child(boss)
	await get_tree().process_frame
	
	var base_scale = boss._base_scale
	print("  [INFO] Initial boss scale: %s" % str(boss.boss_sprite.scale))
	assert(boss.boss_sprite.scale.is_equal_approx(base_scale), "Boss scale must match base scale on start")
	
	boss.activate_arena()
	
	# Simulate 100 rapid hits in quick succession
	for i in range(100):
		boss.take_damage(1)
		# Assert scale never blows up
		var cur_scale = boss.boss_sprite.scale
		assert(cur_scale.x <= base_scale.x * 1.15, "Scale must not exceed 1.15x base scale during rapid hits! Found: %s" % str(cur_scale))
	
	print("  [PASS] 100 rapid hits sustained without scale inflation: max scale remained bounded!")
	
	# Wait for flash tween to finish
	await get_tree().create_timer(0.2).timeout
	var final_scale = boss.boss_sprite.scale
	print("  [INFO] Final settled scale after hits: %s" % str(final_scale))
	assert(final_scale.is_equal_approx(base_scale), "Boss scale must settle back exactly to base scale!")
	print("  [PASS] Boss settled back to exact base scale (%s)" % str(base_scale))
	
	boss.queue_free()
	print("==================================================")
	print("   ALL BONE-BEARD SCALE TESTS PASSED              ")
	print("==================================================")
	get_tree().quit(0)
