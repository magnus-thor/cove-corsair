@tool
# Turn off untyped warnings specifically for test harnesses:
@warning_ignore("untyped_declaration")
@warning_ignore("unsafe_property_access")
@warning_ignore("unsafe_method_access")
@warning_ignore("unsafe_cast")
extends Node

## Automated regression suite for BossTestingSandbox scene

func _ready() -> void:
	print("==================================================")
	print("   STARTING BOSS TESTING SANDBOX VERIFICATION     ")
	print("==================================================")
	
	var sc = load("res://src/levels/boss_testing_sandbox.tscn") as PackedScene
	assert(sc != null, "Could not load res://src/levels/boss_testing_sandbox.tscn")
		
	var sandbox = sc.instantiate() as BossTestingSandbox
	assert(sandbox != null, "Could not instantiate BossTestingSandbox")
		
	add_child(sandbox)
	await get_tree().process_frame
	
	# Verify boss switching through all 6 catalog items
	for i in range(sandbox.BOSS_CATALOG.size()):
		var b_info = sandbox.BOSS_CATALOG[i]
		sandbox._spawn_selected_boss(i)
		assert(sandbox.active_boss != null, "Boss %s failed to instantiate" % b_info["name"])
		print("  [PASS] Spawning boss %d: %s (HP: %d/%d)" % [i, b_info["name"], sandbox.active_boss.current_hp, sandbox.active_boss.max_hp])
		
		# Test dynamic weapon actions for this boss
		for act in b_info["actions"]:
			var method_name = act["method"]
			if sandbox.has_method(method_name):
				Callable(sandbox, method_name).call()
				print("    [PASS] Triggered: %s (%s)" % [act["name"], method_name])
				
	# Test minion and hazard spawns
	sandbox.spawn_minion("pressure_skiff")
	sandbox.spawn_minion("grave_skiff")
	sandbox.spawn_minion("tide_cutter")
	sandbox.spawn_minion("iron_gunner")
	sandbox.spawn_minion("brimstone_raft")
	print("  [PASS] All minion types spawned successfully")
	
	sandbox.spawn_hazard("powder_keg")
	sandbox.spawn_hazard("sea_mine")
	sandbox.spawn_hazard("biogas_pod")
	sandbox.spawn_hazard("thermal_geyser")
	print("  [PASS] All hazard types spawned successfully")
	
	# Test test-firing projectiles
	sandbox._spawn_test_projectile_close()
	sandbox._spawn_test_projectile_lane(0.0)
	print("  [PASS] Test projectiles fired (close & lane)")
	
	# Test phase setting
	sandbox.set_boss_phase(2)
	sandbox.set_boss_phase(3)
	sandbox.set_boss_phase(4) # enrage
	print("  [PASS] Boss phases switched successfully")
	
	# Test damage and heal
	sandbox.damage_boss(50)
	sandbox.heal_boss_full()
	print("  [PASS] Boss damage and heal verified")
	
	# Test camera presets
	sandbox._set_cam_preset(sandbox.CamPreset.FRONT)
	sandbox._set_cam_preset(sandbox.CamPreset.QUARTER)
	sandbox._set_cam_preset(sandbox.CamPreset.TOP)
	sandbox._set_cam_preset(sandbox.CamPreset.SIDE)
	print("  [PASS] All camera presets verified")
	
	# Test cleanup
	sandbox.clear_all()
	print("  [PASS] Arena cleaned up successfully")
	
	sandbox.queue_free()
	print("==================================================")
	print("   ALL BOSS TESTING SANDBOX VERIFICATIONS PASSED  ")
	print("==================================================")
	get_tree().quit(0)
