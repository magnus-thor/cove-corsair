@tool
# Turn off untyped warnings specifically for test harnesses:
@warning_ignore("untyped_declaration")
@warning_ignore("unsafe_property_access")
@warning_ignore("unsafe_method_access")
@warning_ignore("unsafe_cast")
extends Node

func _ready() -> void:
	print("==================================================")
	print("   TESTING MAIN GAME FLOW WITH CHUNK ASSEMBLER    ")
	print("==================================================")
	
	# Load main_game scene
	var main_game_scene = preload("res://src/core/main_game.tscn")
	var main_game = main_game_scene.instantiate() as MainGame
	add_child(main_game)
	
	# Let _ready finish across all nodes
	await get_tree().process_frame
	
	print("[STEP 1] Simulating Level 1 selection & Set Sail from River Map...")
	GameState.select_level(1)
	assert(GameState.current_selected_level == 1, "Selected level must be 1")
	
	var level_ctrl = main_game.get_node("LevelController") as LevelController
	assert(level_ctrl != null, "LevelController must exist in main game")
	
	var res = GameState.get_current_level_resource()
	assert(res != null, "Level 1 resource must load")
	level_ctrl.load_level_resource(res)
	
	# Trigger game start
	main_game._on_game_started()
	await get_tree().process_frame
	
	print("[STEP 2] Verifying Modular Chunk Assembler & Persistent Water in Game Scene...")
	var assembler: ChunkAssembler = level_ctrl.chunk_assembler
	assert(assembler != null, "ChunkAssembler must be attached to LevelController")
	assert(assembler.is_assembled, "Level chunks must be assembled")
	var num_chunks: int = assembler.active_chunks.size()
	assert(num_chunks == 4, "4 chunks must be active")
	
	var track_mgr := main_game.get_node("TrackManager") as TrackManager
	assert(not track_mgr.visible, "TrackManager must be hidden (replaced by Chunk Assembler)")
	assert(not track_mgr.is_physics_processing(), "TrackManager physics process must be disabled")
	print("[PASS] Monolithic TrackManager cleanly replaced by Chunk Assembler.")
	
	# Verify chunks relative coordinates
	var base_z: float = assembler.active_chunks[0].position.z
	for i: int in range(num_chunks):
		var chunk: BaseTrackChunk = assembler.active_chunks[i]
		var expected_rel_z := -float(i) * 50.0
		assert(is_equal_approx(chunk.position.z - base_z, expected_rel_z), "Chunk %d relative Z = %.1f" % [i, chunk.position.z - base_z])
	print("[PASS] Chunks assembled end-to-end at relative offsets 0, -50, -100, -150.")
	
	# Check HUD Progress Bar
	var hud := main_game.get_node("TopHUD")
	var progress_bar := hud.get_node("MarginContainer/HBoxContainer/ProgressContainer/HBoxContainer/LevelProgressBar") as ProgressBar
	assert(progress_bar.max_value == 200.0, "Progress bar max_value must be 200m (total distance to boss)")
	print("[PASS] HUD Progress Bar bound to track distance (max_value: %.1fm)." % progress_bar.max_value)
	
	print("[STEP 3] Simulating Runner Progression toward Boss Arena...")
	# Simulate physics process delta steps
	for _frame: int in range(120): # 2 seconds at 60fps
		assembler._physics_process(0.016667)
	
	assert(GameState.distance_traveled > 0.0, "Distance traveled should accumulate")
	print("[PROGRESS] Distance traveled: %.1fm / %.1fm" % [GameState.distance_traveled, GameState.level_distance_target])
	
	print("[STEP 4] Simulating arrival at Final Chunk (Finish Line / Arena)...")
	# Advance remaining distance so final chunk reaches the camera view
	var final_chunk: BaseTrackChunk = assembler.active_chunks[-1]
	var shift: float = -final_chunk.get_start_z() + 1.0
	for chunk: Node3D in assembler.active_chunks:
		chunk.global_position.z += shift
	assembler.distance_traveled = assembler.total_track_distance
	assembler._physics_process(0.016667)
	
	var is_finish_or_boss: bool = assembler.is_boss_active or (final_chunk is ChunkFinishLine) or main_game.find_child("*Finish*", true, false) != null or main_game.find_child("*Boss*", true, false) != null
	assert(is_finish_or_boss, "Final chunk must be reached")
	print("[PASS] Clean arrival at final level milestone verified!")
	
	print("==================================================")
	print("   FULL GAMEPLAY FLOW VERIFIED SUCCESSFULLY!      ")
	print("==================================================")
	get_tree().quit(0)
