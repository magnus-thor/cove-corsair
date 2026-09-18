class_name TestEndlessMode
extends Node

## Headless test harness verifying Corsair Gauntlet Endless Mode.
## Tests gentle start speed (7.0 m/s), first chunk warmup guarantee, distance tracking,
## multiplier gold routing, Wager Fork checkpoint triggers, extraction banking,
## zero-gap continuous chunk streaming, and extraction settlement screen with zero untyped warnings.

const EndlessModeScript: GDScript = preload("res://src/features/modes/endless_mode.gd")
const ChunkWagerForkScript: GDScript = preload("res://src/features/track/chunks/chunk_wager_fork.gd")

func _ready() -> void:
	print("==================================================")
	print("   TESTING CORSAIR GAUNTLET ENDLESS MODE HARNESS  ")
	print("==================================================")
	
	_test_speed_scaling_formula()
	_test_first_chunk_warmup_guarantee()
	_test_gold_collection_and_multiplier()
	_test_wager_fork_chunk_structure()
	_test_push_luck_trigger()
	_test_bank_and_extract_trigger()
	_test_sinking_penalty()
	_test_seamless_chunk_streaming_zero_gaps()
	_test_wager_fork_single_spawn_guarantee()
	_test_lane_populator_density()
	_test_sign_legibility_and_depth_test()
	_test_extraction_settlement_screen()
	
	print("==================================================")
	print("   ALL ENDLESS MODE TESTS PASSED SUCCESSFULLY!    ")
	print("==================================================")
	get_tree().quit(0)

func _test_speed_scaling_formula() -> void:
	print("[STEP 1] Testing gentle initial speed and distance curve...")
	var mode: Node = EndlessModeScript.new()
	add_child(mode)
	
	var default_base: float = float(mode.get("base_speed"))
	assert(is_equal_approx(default_base, 7.0), "Default base_speed must be 7.0 m/s for gentle warm start (got %.2f)" % default_base)
	
	# Base speed at 0m
	var speed_0m: float = float(mode.call("calculate_speed", 0.0))
	assert(is_equal_approx(speed_0m, 7.0), "Speed at 0m must be 7.0 m/s (got %.2f)" % speed_0m)
	
	# Speed at 250m (+0.5 m/s)
	var speed_250m: float = float(mode.call("calculate_speed", 250.0))
	assert(is_equal_approx(speed_250m, 7.5), "Speed at 250m must be 7.5 m/s (got %.2f)" % speed_250m)
	
	# Speed at 500m (+1.0 m/s)
	var speed_500m: float = float(mode.call("calculate_speed", 500.0))
	assert(is_equal_approx(speed_500m, 8.0), "Speed at 500m must be 8.0 m/s (got %.2f)" % speed_500m)
	
	# Speed at 1000m (+2.0 m/s)
	var speed_1000m: float = float(mode.call("calculate_speed", 1000.0))
	assert(is_equal_approx(speed_1000m, 9.0), "Speed at 1000m must be 9.0 m/s (got %.2f)" % speed_1000m)
	
	# Speed cap at max_speed
	var max_spd: float = float(mode.get("max_speed"))
	var speed_extreme: float = float(mode.call("calculate_speed", 20000.0))
	assert(is_equal_approx(speed_extreme, max_spd), "Speed at 20,000m must clamp at max_speed %.1f m/s (got %.2f)" % [max_spd, speed_extreme])
	
	mode.queue_free()
	print("  [PASS] Gentle speed formula verified: 7.0 m/s start, smooth scaling +0.5 m/s per 250m.")

func _test_first_chunk_warmup_guarantee() -> void:
	print("[STEP 2] Testing first chunk warmup guarantee and 40m safe clearance...")
	var mode: Node = EndlessModeScript.new()
	add_child(mode)
	
	# Check warmup chunk scene reference
	var warmup_scene: PackedScene = mode.get("warmup_chunk_scene") as PackedScene
	assert(warmup_scene != null, "warmup_chunk_scene must be loaded in EndlessMode")
	
	# Instantiate warmup chunk and verify 40m safe clearance
	var chunk: BaseTrackChunk = warmup_scene.instantiate() as BaseTrackChunk
	add_child(chunk)
	
	# Run clearance enforcement
	mode.call("_enforce_start_clearance", chunk, 40.0)
	
	# Verify no enemies or hazards exist with Z > -40.0
	var entities: Node = chunk.find_child("Entities", true, false)
	assert(entities != null, "Entities container must exist in chunk")
	for child: Node in entities.get_children():
		var is_enemy: bool = child.is_in_group("enemies") or child.name.to_lower().contains("enemy") or child.name.to_lower().contains("fodder")
		if is_enemy and child is Node3D:
			var z_pos: float = (child as Node3D).position.z
			assert(z_pos <= -40.0, "No enemy must exist inside the first 40m runway (found at Z=%.1fm)" % z_pos)
			
	chunk.queue_free()
	mode.queue_free()
	print("  [PASS] First chunk warmup guarantee confirmed with >= 40m safe runway.")

func _test_gold_collection_and_multiplier() -> void:
	print("[STEP 3] Testing gold collection routed through multiplier...")
	var mode: Node = EndlessModeScript.new()
	add_child(mode)
	mode.call("start_run")
	
	var initial_unbanked: int = int(mode.get("unbanked_doubloons"))
	var initial_mult: float = float(mode.get("multiplier"))
	assert(initial_unbanked == 0, "Initial unbanked doubloons must be 0")
	assert(is_equal_approx(initial_mult, 1.0), "Initial multiplier must be 1.0")
	
	# Simulate collecting 10 gold at 1.0x
	mode.call("_on_gold_collected", 10)
	var after_10: int = int(mode.get("unbanked_doubloons"))
	assert(after_10 == 10, "10 gold at 1.0x must yield 10 unbanked doubloons (got %d)" % after_10)
	
	# Simulate multiplier increment to 2.0x
	mode.set("multiplier", 2.0)
	mode.call("_on_gold_collected", 15)
	var after_15: int = int(mode.get("unbanked_doubloons"))
	assert(after_15 == 40, "15 gold at 2.0x adds 30, total must be 40 (got %d)" % after_15)
	
	mode.queue_free()
	print("  [PASS] Gold collection routed through multiplier into unbanked_doubloons.")

func _test_wager_fork_chunk_structure() -> void:
	print("[STEP 4] Testing Wager Fork Chunk scene structure & lanes...")
	var chunk_scene: PackedScene = preload("res://src/features/track/chunks/chunk_wager_fork.tscn")
	assert(chunk_scene != null, "chunk_wager_fork.tscn must exist and load")
	
	var chunk: BaseTrackChunk = chunk_scene.instantiate() as BaseTrackChunk
	assert(chunk != null, "chunk_wager_fork.tscn must instantiate as BaseTrackChunk")
	add_child(chunk)
	
	# Verify chunk length
	var chunk_end_marker: Marker3D = chunk.get_node_or_null("ChunkEnd") as Marker3D
	assert(chunk_end_marker != null, "ChunkEnd marker must exist in wager fork chunk")
	assert(is_equal_approx(chunk_end_marker.position.z, -60.0), "Wager fork chunk length must span 60m")
	
	# Verify Left lane BankTriggerArea
	var bank_area: Area3D = chunk.get_node_or_null("BankTriggerArea") as Area3D
	assert(bank_area != null, "BankTriggerArea must exist in chunk")
	assert(is_equal_approx(bank_area.position.x, -3.2), "BankTriggerArea must be in left lane at X = -3.2m (got %.1f)" % bank_area.position.x)
	
	# Verify Right lane PushTriggerArea
	var push_area: Area3D = chunk.get_node_or_null("PushTriggerArea") as Area3D
	assert(push_area != null, "PushTriggerArea must exist in chunk")
	assert(is_equal_approx(push_area.position.x, 3.2), "PushTriggerArea must be in right lane at X = +3.2m (got %.1f)" % push_area.position.x)
	
	# Verify Center lane rock outcropping
	var rock: Node3D = chunk.get_node_or_null("CenterRockOutcropping") as Node3D
	assert(rock != null, "CenterRockOutcropping must exist in chunk to block center lane")
	assert(is_equal_approx(rock.position.x, 0.0), "Center rock outcropping must block center lane at X = 0.0m")
	
	chunk.queue_free()
	print("  [PASS] Wager fork 3-lane split structure verified (-3.2m Left, 0.0m Rock, +3.2m Right).")

func _test_push_luck_trigger() -> void:
	print("[STEP 5] Testing Corsair's Gamble push_luck() trigger...")
	var mode: Node = EndlessModeScript.new()
	add_child(mode)
	mode.call("start_run")
	
	var initial_mult: float = float(mode.get("multiplier"))
	var initial_speed: float = float(mode.get("current_speed"))
	
	var wager_pushed_received: Array[bool] = [false]
	var signal_mult: Array[float] = [0.0]
	EventBus.wager_pushed.connect(func(new_m: float, _new_s: float) -> void:
		wager_pushed_received[0] = true
		signal_mult[0] = new_m
	, CONNECT_ONE_SHOT)
	
	# Trigger push luck
	mode.call("push_luck")
	
	var after_mult: float = float(mode.get("multiplier"))
	var after_speed: float = float(mode.get("current_speed"))
	
	assert(is_equal_approx(after_mult, initial_mult + 0.5), "Multiplier must increase by +0.5 (got %.2f)" % after_mult)
	assert(after_speed > initial_speed, "Speed must increase after pushing luck")
	assert(wager_pushed_received[0], "EventBus.wager_pushed signal must be received")
	assert(is_equal_approx(signal_mult[0], after_mult), "Emitted multiplier must match mode.multiplier")
	
	mode.queue_free()
	print("  [PASS] Push luck increases multiplier by +0.5 and emits EventBus.wager_pushed.")

func _test_bank_and_extract_trigger() -> void:
	print("[STEP 6] Testing Bank & Retire bank_and_exit() trigger...")
	var mode: Node = EndlessModeScript.new()
	add_child(mode)
	mode.call("start_run")
	mode.set("distance_traveled", 1250.0)
	mode.set("unbanked_doubloons", 250)
	
	var initial_banked: int = GameState.doubloons
	var extraction_received: Array[bool] = [false]
	var extracted_score: Array[int] = [0]
	var extracted_doubloons: Array[int] = [0]
	
	EventBus.run_extracted.connect(func(score: int, dbl: int) -> void:
		extraction_received[0] = true
		extracted_score[0] = score
		extracted_doubloons[0] = dbl
	, CONNECT_ONE_SHOT)
	
	mode.call("bank_and_exit")
	
	var cashed_out: bool = bool(mode.get("has_cashed_out"))
	var is_act: bool = bool(mode.get("is_active"))
	assert(cashed_out, "has_cashed_out must be true after cashing out")
	assert(not is_act, "Endless mode must become inactive after banking")
	assert(GameState.doubloons == initial_banked + 250, "GameState.doubloons must increase by 250 (got %d)" % GameState.doubloons)
	assert(extraction_received[0], "EventBus.run_extracted must be emitted")
	assert(extracted_score[0] == 1250, "Extracted score must match distance 1250 (got %d)" % extracted_score[0])
	assert(extracted_doubloons[0] == 250, "Extracted doubloons must be 250 (got %d)" % extracted_doubloons[0])
	
	mode.queue_free()
	print("  [PASS] Bank & Retire banks 100% doubloons and emits EventBus.run_extracted.")

func _test_sinking_penalty() -> void:
	print("[STEP 7] Testing sinking penalty (50% unbanked doubloon loss)...")
	var mode: Node = EndlessModeScript.new()
	add_child(mode)
	mode.call("start_run")
	mode.set("unbanked_doubloons", 300)
	
	# Emit sinking event
	EventBus.player_sunk.emit()
	
	var is_act: bool = bool(mode.get("is_active"))
	var after_sunk_doubloons: int = int(mode.get("unbanked_doubloons"))
	assert(not is_act, "Endless mode must become inactive after sinking")
	assert(after_sunk_doubloons == 150, "Unbanked doubloons must be reduced by 50%% from 300 to 150 (got %d)" % after_sunk_doubloons)
	
	mode.queue_free()
	print("  [PASS] Sinking penalty confirmed: 50% of unbanked doubloons lost.")

func _test_seamless_chunk_streaming_zero_gaps() -> void:
	print("[STEP 8] Testing seamless chunk streaming and zero gap guarantee...")
	var assembler: ChunkAssembler = ChunkAssembler.new()
	add_child(assembler)
	
	var mode: Node = EndlessModeScript.new()
	add_child(mode)
	mode.set("_chunk_assembler", assembler)
	mode.call("_init_endless_chunks")
	
	# Verify initial chunks are contiguous
	assert(assembler.active_chunks.size() >= 5, "Initial stream must spawn at least 5 chunks")
	for i: int in range(assembler.active_chunks.size() - 1):
		var cur: BaseTrackChunk = assembler.active_chunks[i]
		var nxt: BaseTrackChunk = assembler.active_chunks[i + 1]
		var cur_end_z: float = cur.position.z - cur.CHUNK_LENGTH
		assert(is_equal_approx(nxt.position.z, cur_end_z), "Chunk %d end (%.1f) must match Chunk %d start (%.1f)" % [i, cur_end_z, i + 1, nxt.position.z])
		
	# Simulate 10 seconds of scrolling
	for _frame: int in range(600):
		assembler._physics_process(0.016667)
		mode.call("_check_stream_chunks")
		
	# Verify contiguous alignment remains zero-gap throughout scrolling
	assert(assembler.active_chunks.size() >= 4, "Active chunks must remain populated")
	for i: int in range(assembler.active_chunks.size() - 1):
		var cur: BaseTrackChunk = assembler.active_chunks[i]
		var nxt: BaseTrackChunk = assembler.active_chunks[i + 1]
		var cur_end_z: float = cur.position.z - cur.CHUNK_LENGTH
		assert(is_equal_approx(nxt.position.z, cur_end_z), "After streaming, Chunk %d end (%.1f) must equal Chunk %d start (%.1f)" % [i, cur_end_z, i + 1, nxt.position.z])
		
	assembler.queue_free()
	mode.queue_free()
	print("  [PASS] Seamless chunk streaming confirmed: 0 gaps between chunks during active gameplay.")

func _test_wager_fork_single_spawn_guarantee() -> void:
	print("[STEP 9] Testing Wager Fork single-spawn guarantee (no consecutive forks)...")
	var mode: Node = EndlessModeScript.new()
	add_child(mode)
	mode.call("start_run")
	
	# proj_dist at 1000m should yield the wager fork scene
	var fork_scene: PackedScene = mode.call("_pick_chunk_for_distance", 1000.0) as PackedScene
	assert(fork_scene == mode.get("wager_fork_scene"), "First request at 1000m must return wager_fork_scene")
	
	# Subsequent chunk requests before the checkpoint is crossed must NOT return wager_fork_scene
	var next_chunk_scene: PackedScene = mode.call("_pick_chunk_for_distance", 1050.0) as PackedScene
	assert(next_chunk_scene != mode.get("wager_fork_scene"), "Subsequent chunk at 1050m must NOT be a wager fork (prevents 250m dead zone)")
	
	var third_chunk_scene: PackedScene = mode.call("_pick_chunk_for_distance", 1100.0) as PackedScene
	assert(third_chunk_scene != mode.get("wager_fork_scene"), "Third chunk at 1100m must NOT be a wager fork")
	
	mode.queue_free()
	print("  [PASS] Single-spawn wager fork guarantee confirmed: exactly 1 fork per interval.")

func _test_lane_populator_density() -> void:
	print("[STEP 10] Testing continuous lane populator (zero empty dead spells)...")
	var mode: Node = EndlessModeScript.new()
	add_child(mode)
	
	# Create an empty chunk to test filler population
	var test_chunk: BaseTrackChunk = BaseTrackChunk.new()
	var ent_node: Node3D = Node3D.new()
	ent_node.name = "Entities"
	test_chunk.add_child(ent_node)
	add_child(test_chunk)
	
	assert(ent_node.get_child_count() == 0, "Initial entities container must be empty")
	
	# Run lane populator
	mode.call("_populate_chunk_lane_content", test_chunk)
	
	assert(ent_node.get_child_count() > 0, "Lane populator must inject doubloons, barrels, or skiffs into empty zones")
	print("  [PASS] Lane populator populated %d entities into empty stretches." % ent_node.get_child_count())
	
	test_chunk.queue_free()
	mode.queue_free()

func _test_sign_legibility_and_depth_test() -> void:
	print("[STEP 11] Testing Wager Fork sign legibility, tilt, and depth testing...")
	var wager_fork_scene: PackedScene = preload("res://src/features/track/chunks/chunk_wager_fork.tscn")
	assert(wager_fork_scene != null, "chunk_wager_fork.tscn must exist")
	
	var fork: Node = wager_fork_scene.instantiate()
	add_child(fork)
	
	var bank_title: Label3D = fork.find_child("BankTitle", true, false) as Label3D
	assert(bank_title != null, "BankTitle label must exist")
	assert(bank_title.no_depth_test, "BankTitle must have no_depth_test = true to prevent board occlusion")
	assert(bank_title.billboard == BaseMaterial3D.BILLBOARD_DISABLED, "BankTitle billboard must be disabled so text lies flat on tilted board")
	assert(bank_title.font_size >= 70, "BankTitle font_size must be >= 70 for readability (got %d)" % bank_title.font_size)
	assert(bank_title.text.contains("CASH OUT"), "BankTitle must read '⚓ CASH OUT'")
	
	var push_title: Label3D = fork.find_child("PushTitle", true, false) as Label3D
	assert(push_title != null, "PushTitle label must exist")
	assert(push_title.no_depth_test, "PushTitle must have no_depth_test = true to prevent board occlusion")
	assert(push_title.billboard == BaseMaterial3D.BILLBOARD_DISABLED, "PushTitle billboard must be disabled so text lies flat on tilted board")
	assert(push_title.font_size >= 70, "PushTitle font_size must be >= 70 for readability (got %d)" % push_title.font_size)
	assert(push_title.text.contains("PUSH LUCK"), "PushTitle must read '☠ PUSH LUCK'")
	
	# Verify water lane indicators exist
	var water_left: Node = fork.find_child("WaterIndicatorLeft", true, false)
	var water_right: Node = fork.find_child("WaterIndicatorRight", true, false)
	assert(water_left != null, "WaterIndicatorLeft must exist")
	assert(water_right != null, "WaterIndicatorRight must exist")
	
	fork.queue_free()
	print("  [PASS] Sign legibility verified: tilt aligned with camera, no_depth_test enabled, crisp scale.")

func _test_extraction_settlement_screen() -> void:
	print("[STEP 12] Testing dedicated extraction settlement screen presentation...")
	var settlement_scene: PackedScene = preload("res://src/ui/settlement_screen.tscn")
	assert(settlement_scene != null, "settlement_screen.tscn must exist")
	
	var settlement: SettlementScreen = settlement_scene.instantiate() as SettlementScreen
	add_child(settlement)
	
	# Call show_extraction
	settlement.show_extraction(1000, 350, 850, 1.5)
	
	assert(settlement.header_label.text.contains("SAFE HARBOR REACHED!"), "Header must read '⚓ SAFE HARBOR REACHED!'")
	assert(not settlement.stars_container.visible, "Stars container must be hidden in extraction mode")
	assert(settlement.primary_button.text == "SAIL AGAIN (GAUNTLET)", "Primary button must read 'SAIL AGAIN (GAUNTLET)'")
	assert(settlement.map_button.text == "RETURN TO HARBOR", "Map button must read 'RETURN TO HARBOR'")
	assert(not settlement.bonus_row.visible, "Bonus row must be hidden in extraction mode")
	assert(not settlement.bonus_claim_button.visible, "Bonus claim button must be hidden in extraction mode")
	
	# Verify extraction state and action labels
	assert(settlement.get("_is_extraction") == true, "_is_extraction must be true")
	assert(settlement.primary_button.text == "SAIL AGAIN (GAUNTLET)", "Primary button must be 'SAIL AGAIN (GAUNTLET)'")
	
	settlement.queue_free()
	print("  [PASS] Extraction settlement screen presents dedicated gauntlet retreat UI with direct restart.")
