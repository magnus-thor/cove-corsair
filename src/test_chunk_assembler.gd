extends Node

func _ready() -> void:
	print("==================================================")
	print("   STARTING MODULAR CHUNK ASSEMBLER VERIFICATION  ")
	print("==================================================")
	
	test_level_data_resources()
	test_chunk_scenes_and_assembler()
	test_spawner_and_cleanup_lifecycle()
	test_boss_chunks_wiring()
	
	print("==================================================")
	print("   ALL VERIFICATION TESTS PASSED SUCCESSFULLY!    ")
	print("==================================================")
	get_tree().quit(0)

func test_level_data_resources() -> void:
	print("\n--- TEST 1: LevelData Resources Schema ---")
	var l1 = load("res://src/data/resources/levels/level_01.tres") as LevelData
	assert(l1 != null, "level_01.tres should load as LevelData")
	assert(l1.level_id == 1, "Level 1 ID must be 1")
	assert(l1.level_title == "Level 1: Smuggler's Run", "Level 1 title mismatch")
	assert(l1.biome_name == "tropical", "Level 1 biome must be tropical")
	assert(l1.chunk_scenes.size() == 5, "Level 1 must have 5 chunk scenes")
	assert(l1.base_scroll_speed == 6.5, "Level 1 base_scroll_speed must be 6.5")
	assert(l1.completion_doubloon_reward == 50, "Level 1 reward must be 50")
	print("[PASS] Level 1 schema verified.")
	
	var l2 = load("res://src/data/resources/levels/level_02.tres") as LevelData
	assert(l2 != null, "level_02.tres should load as LevelData")
	assert(l2.level_id == 2, "Level 2 ID must be 2")
	assert(l2.level_title == "Level 2: Palm Shallows", "Level 2 title mismatch")
	assert(l2.biome_name in ["lagoon", "tropical"], "Level 2 biome must be lagoon/tropical")
	assert(l2.chunk_scenes.size() == 5, "Level 2 must have 5 chunk scenes")
	print("[PASS] Level 2 schema verified.")

	var l3 = load("res://src/data/resources/levels/level_03.tres") as LevelData
	assert(l3 != null, "level_03.tres should load as LevelData")
	assert(l3.level_id == 3, "Level 3 ID must be 3")
	assert(l3.level_title == "Level 3: Brimstone Bastion", "Level 3 title mismatch")
	assert(l3.biome_name == "brimstone", "Level 3 biome must be brimstone")
	assert(l3.chunk_scenes.size() == 5, "Level 3 must have 5 chunk scenes")
	print("[PASS] Level 3 schema verified.")

func test_chunk_scenes_and_assembler() -> void:
	print("\n--- TEST 2: Chunk Assembly & Seamless Alignment ---")
	var assembler := ChunkAssembler.new()
	add_child(assembler)
	
	var l1 = load("res://src/data/resources/levels/level_01.tres") as LevelData
	assembler.assemble_level(l1)
	
	assert(assembler.active_chunks.size() == 5, "Assembler must have 5 active chunks")
	
	var expected_z: float = 0.0
	for i in range(assembler.active_chunks.size()):
		var chunk = assembler.active_chunks[i]
		assert(chunk is BaseTrackChunk, "Each chunk must inherit BaseTrackChunk")
		assert(is_equal_approx(chunk.position.z, expected_z), "Chunk %d Z must be %.1f, got %.1f" % [i, expected_z, chunk.position.z])
		assert(is_equal_approx(chunk.get_start_z(), expected_z), "Chunk %d Start Z must match origin" % i)
		assert(is_equal_approx(chunk.get_end_z(), expected_z - 50.0), "Chunk %d End Z must be Start - 50m" % i)
		
		# Check that NO water plane geometry exists inside chunk
		var water_in_chunk = chunk.find_child("*Water*", true, false)
		assert(water_in_chunk == null, "Chunks must NOT contain water plane geometry (water is persistent under camera)")
		
		# Check seamless alignment: previous chunk end == current chunk start
		if i > 0:
			var prev_chunk = assembler.active_chunks[i - 1]
			assert(is_equal_approx(prev_chunk.get_end_z(), chunk.get_start_z()), "Visual seam detected between Chunk %d and %d!" % [i - 1, i])
			
		expected_z -= 50.0
		
	print("[PASS] Chunks assembled end-to-end with 0 gaps, 0 overlaps, and 0 water meshes.")
	
	# Verify persistent water plane exists
	var persistent_water = get_tree().get_first_node_in_group("persistent_water")
	assert(persistent_water != null, "Persistent water surface must exist")
	print("[PASS] Persistent water plane verified under camera.")
	
	assembler.queue_free()

func test_spawner_and_cleanup_lifecycle() -> void:
	print("\n--- TEST 3: Spawner Activation & Memory Cleanup ---")
	var assembler := ChunkAssembler.new()
	add_child(assembler)
	
	var l1 = load("res://src/data/resources/levels/level_01.tres") as LevelData
	assembler.assemble_level(l1)
	
	GameState.is_game_active = true
	
	# Chunk 0 (Z=0) should be activated upon assembly
	assert(assembler.active_chunks[0].is_active, "Chunk 0 should be active")
	# Chunk 1 (Z=-50) should be dormant until entering camera activation range (-75m)
	assert(not assembler.active_chunks[1].is_active, "Chunk 1 should initially be dormant")
	
	# Simulate 1 frame of physics process
	assembler._physics_process(0.1)
	
	# Scroll world forward so Chunk 1 enters camera range
	# Chunk 1 starts at -50; when chunks scroll +25m, Chunk 1 is at -25m >= -75m
	for chunk in assembler.active_chunks:
		chunk.global_position.z += 25.0
	assembler._physics_process(0.016)
	assert(assembler.active_chunks[1].is_active, "Chunk 1 should activate when entering camera range")
	print("[PASS] Spawner hook activated upon entering camera range.")
	
	# Test memory cleanup: scroll Chunk 0 past +30m behind camera
	# Chunk 0 start is at +100m, end is at +50m > 30m
	var chunk_0 = assembler.active_chunks[0]
	chunk_0.global_position.z = 85.0 # End is at 85 - 50 = 35m > 30m
	assembler._physics_process(0.016)
	
	assert(chunk_0 not in assembler.active_chunks, "Chunk 0 must be removed from active_chunks when +30m past camera")
	print("[PASS] Memory cleanup verified: chunk freed past +30m behind camera.")
	
	GameState.is_game_active = false
	assembler.queue_free()

func test_boss_chunks_wiring() -> void:
	print("\n--- TEST 4: Boss Chunks Wiring ---")
	# Level 1: Captain Ironjaw
	var c1 = load("res://src/gameplay/chunks/chunk_boss_ironjaw.tscn").instantiate() as BaseTrackChunk
	add_child(c1)
	assert(c1.is_boss_chunk, "Chunk 1 boss must be boss chunk")
	assert(c1.boss_scene != null, "Chunk 1 must have boss_scene assigned")
	assert("boss_war_barge" in c1.boss_scene.resource_path, "Level 1 boss must be War Barge (Captain Ironjaw)")
	c1.activate_spawners()
	var b1 = c1.find_child("*Boss*", true, false)
	assert(b1 != null, "Ironjaw boss must be spawned in chunk")
	c1.free()
	print("[PASS] Level 1 Boss (Captain Ironjaw) correctly wired.")
	
	# Level 2: The Phantom Dredge
	var c2 = load("res://src/gameplay/chunks/chunk_boss_phantom_dredge.tscn").instantiate() as BaseTrackChunk
	add_child(c2)
	assert(c2.is_boss_chunk, "Chunk 2 boss must be boss chunk")
	assert(c2.boss_scene != null, "Chunk 2 must have boss_scene assigned")
	assert("boss_phantom_dredge" in c2.boss_scene.resource_path, "Level 2 boss must be Phantom Dredge")
	c2.activate_spawners()
	var b2 = c2.find_child("*Boss*", true, false)
	assert(b2 != null, "Phantom Dredge boss must be spawned in chunk")
	c2.free()
	print("[PASS] Level 2 Boss (The Phantom Dredge) correctly wired.")

	# Level 3: Brimstone Siege Fortress
	var c3 = load("res://src/gameplay/chunks/chunk_boss_siege_fortress.tscn").instantiate() as BaseTrackChunk
	add_child(c3)
	assert(c3.is_boss_chunk, "Chunk 3 boss must be boss chunk")
	assert(c3.boss_scene != null, "Chunk 3 must have boss_scene assigned")
	assert("boss_siege_fortress" in c3.boss_scene.resource_path, "Level 3 boss must be Siege Fortress")
	c3.activate_spawners()
	var b3 = c3.find_child("*Boss*", true, false)
	assert(b3 != null, "Siege Fortress boss must be spawned in chunk")
	c3.free()
	print("[PASS] Level 3 Boss (Brimstone Siege Fortress) correctly wired.")
	get_tree().quit(0)
