@tool
# Turn off untyped warnings specifically for test harnesses:
@warning_ignore("untyped_declaration")
@warning_ignore("unsafe_property_access")
@warning_ignore("unsafe_method_access")
@warning_ignore("unsafe_cast")
extends Node

## Comprehensive Verification Suite for Campaign Overhaul:
## 1. 45-Level Schema & Monotonic Scaling
## 2. 5-Level Boss Cadence & Finish Line Gates
## 3. Boss Invulnerability During Approach
## 4. Riverbank Navigable Clearance (|X| >= 6.6m)
## 5. Multi-Biome Horizon Texture Assets
## 6. Modular Chunks Integrity (Finish Line, Reef Slalom, Gunner Ambush)

var passed_count: int = 0
var failed_count: int = 0

func assert_test(condition: bool, message: String) -> void:
	if condition:
		print("  [PASS] %s" % message)
		passed_count += 1
	else:
		printerr("  [FAIL] %s" % message)
		failed_count += 1

func _ready() -> void:
	print("==========================================================")
	print("  STARTING CAMPAIGN OVERHAUL VERIFICATION SUITE           ")
	print("==========================================================")
	
	test_horizon_texture_assets()
	test_campaign_levels_schema_and_cadence()
	test_modular_chunks_integrity()
	test_no_floating_coins_in_chunks()
	test_boss_invulnerability_and_arena_lock()
	test_riverbank_scenery_clearance()
	test_level_endings_and_start_clearance()
	
	print("==========================================================")
	print("  VERIFICATION RESULTS: %d / %d PASSED" % [passed_count, passed_count + failed_count])
	print("==========================================================")
	
	if failed_count == 0:
		print("ALL CAMPAIGN OVERHAUL TESTS PASSED SUCCESSFULLY!")
		get_tree().quit(0)
	else:
		printerr("FAILURES DETECTED IN CAMPAIGN OVERHAUL VERIFICATION!")
		get_tree().quit(1)

func test_horizon_texture_assets() -> void:
	print("\n--- TEST 1: Horizon Skybox Texture Assets ---")
	var horizons = [
		"res://assets/textures/horizon_smugglers_run.png",
		"res://assets/textures/horizon_bayou.png",
		"res://assets/textures/horizon_citadel.png",
		"res://assets/textures/horizon_brimstone.png"
	]
	for h_path in horizons:
		var tex = load(h_path) as Texture2D
		assert_test(tex != null, "Horizon texture loaded: %s (size: %s)" % [h_path, str(tex.get_size()) if tex else "null"])

func test_campaign_levels_schema_and_cadence() -> void:
	print("\n--- TEST 2: All 45 Levels Schema, Cadence & Monotonic Progression ---")
	var prev_speed: float = 6.0
	var boss_levels = [5, 10, 15, 20, 25, 30, 35, 40, 45]
	
	for lvl in range(1, 46):
		var path = "res://src/data/resources/levels/level_%02d.tres" % lvl
		var res = load(path) as LevelData
		assert_test(res != null, "Loaded level resource: %s" % path)
		if not res:
			continue
			
		assert_test(res.level_id == lvl, "Level %d ID matches %d" % [lvl, res.level_id])
		assert_test(res.base_scroll_speed >= prev_speed, "Level %d speed (%.1f) >= prev (%.1f)" % [lvl, res.base_scroll_speed, prev_speed])
		prev_speed = res.base_scroll_speed
		
		var b_str = res.biome_name.to_lower()
		var is_valid_biome = "tropical" in b_str or "bayou" in b_str or "citadel" in b_str or "brimstone" in b_str
		assert_test(is_valid_biome, "Level %d valid biome '%s'" % [lvl, res.biome_name])
		var min_expected_chunks = 4 if lvl == 1 else 5
		assert_test(res.chunk_scenes.size() >= min_expected_chunks, "Level %d has >= %d chunks (has %d)" % [lvl, min_expected_chunks, res.chunk_scenes.size()])
		
		var last_chunk_scene = res.chunk_scenes[res.chunk_scenes.size() - 1]
		assert_test(last_chunk_scene != null, "Level %d last chunk is valid scene" % lvl)
		
		var last_chunk = last_chunk_scene.instantiate() as BaseTrackChunk
		assert_test(last_chunk != null, "Level %d last chunk instantiates BaseTrackChunk" % lvl)
		
		if lvl in boss_levels:
			assert_test(last_chunk.is_boss_chunk, "Level %d is BOSS LEVEL -> last chunk has is_boss_chunk = true" % lvl)
			assert_test(last_chunk.boss_scene != null, "Level %d boss chunk has valid boss_scene" % lvl)
			assert_test(res.completion_doubloon_reward >= 200, "Level %d boss reward is generous (reward: %d)" % [lvl, res.completion_doubloon_reward])
		else:
			assert_test(last_chunk.chunk_id == "finish_line" or "chunk_finish_line" in last_chunk_scene.resource_path, "Level %d is RUNNER -> ends with Finish Line Gate" % lvl)
			
		last_chunk.free()

func test_modular_chunks_integrity() -> void:
	print("\n--- TEST 3: Modular Chunks Integrity ---")
	# 1. Finish Line Gate
	var finish_scene = preload("res://src/gameplay/chunks/chunk_finish_line.tscn")
	assert_test(finish_scene != null, "chunk_finish_line.tscn loaded")
	var finish_chunk = finish_scene.instantiate()
	add_child(finish_chunk)
	assert_test(finish_chunk.chunk_id == "finish_line", "Finish line chunk_id is 'finish_line'")
	assert_test(finish_chunk.find_child("FinishTrigger") != null, "Finish line has FinishTrigger Area3D")
	finish_chunk.queue_free()
	
	# 2. Reef Slalom
	var reef_scene = preload("res://src/gameplay/chunks/chunk_reef_slalom.tscn")
	assert_test(reef_scene != null, "chunk_reef_slalom.tscn loaded")
	var reef_chunk = reef_scene.instantiate()
	add_child(reef_chunk)
	assert_test(reef_chunk.chunk_id == "reef_slalom", "Reef slalom chunk_id is 'reef_slalom'")
	var reef_entities = reef_chunk.find_child("Entities")
	assert_test(reef_entities != null and reef_entities.get_child_count() >= 3, "Reef slalom has >= 3 entities (has %d)" % (reef_entities.get_child_count() if reef_entities else 0))
	reef_chunk.queue_free()
	
	# 3. Gunner Ambush
	var ambush_scene = preload("res://src/gameplay/chunks/chunk_gunner_ambush.tscn")
	assert_test(ambush_scene != null, "chunk_gunner_ambush.tscn loaded")
	var ambush_chunk = ambush_scene.instantiate()
	add_child(ambush_chunk)
	assert_test(ambush_chunk.chunk_id == "gunner_ambush", "Gunner ambush chunk_id is 'gunner_ambush'")
	var ambush_entities = ambush_chunk.find_child("Entities")
	assert_test(ambush_entities != null and ambush_entities.get_child_count() >= 3, "Gunner ambush has >= 3 entities (has %d)" % (ambush_entities.get_child_count() if ambush_entities else 0))
	ambush_chunk.queue_free()

func test_no_floating_coins_in_chunks() -> void:
	print("\n--- TEST 3B: Zero Floating Coins in Track Chunks ---")
	var chunk_paths = [
		"res://src/gameplay/chunks/chunk_warmup.tscn",
		"res://src/gameplay/chunks/chunk_mine_gauntlet.tscn",
		"res://src/gameplay/chunks/chunk_reef_slalom.tscn",
		"res://src/gameplay/chunks/chunk_gunner_ambush.tscn",
		"res://src/gameplay/chunks/chunk_finish_line.tscn",
		"res://src/gameplay/chunks/chunk_boss_intro_buffer.tscn",
		"res://src/gameplay/chunks/chunk_barricade_siege.tscn",
	]
	
	for cp in chunk_paths:
		var scene = load(cp) as PackedScene
		assert_test(scene != null, "Loaded chunk scene: %s" % cp)
		if not scene:
			continue
		var chunk = scene.instantiate() as BaseTrackChunk
		add_child(chunk)
		
		var loose_coins = 0
		for child in chunk.find_children("*", "", true, false):
			if child is Area3D and (child.is_in_group("doubloons") or child.name.to_lower().begins_with("doubloon")):
				loose_coins += 1
				
		assert_test(loose_coins == 0, "%s: 0 floating coins detected (found %d)" % [cp.get_file(), loose_coins])
		chunk.queue_free()

func test_boss_invulnerability_and_arena_lock() -> void:
	print("\n--- TEST 4: Boss Approach Invulnerability & Arena Lock Gate ---")
	var boss_scenes = [
		preload("res://src/gameplay/enemies/boss_war_barge.tscn"),
		preload("res://src/gameplay/enemies/boss_phantom_dredge.tscn"),
		preload("res://src/gameplay/enemies/boss_siege_fortress.tscn"),
		preload("res://src/gameplay/enemies/boss_bone_beard.tscn"),
	]
	
	for b_scene in boss_scenes:
		var boss = b_scene.instantiate()
		add_child(boss)
		var b_name = boss.name
		
		# Boss must NOT have arena active initially
		assert_test(not boss.is_arena_active, "%s: is_arena_active is false on spawn" % b_name)
		
		# Test approach invulnerability
		if "SiegeFortress" in b_name or boss.has_method("damage_component"):
			var hp_before = boss.current_hp
			boss.take_damage(25)
			assert_test(boss.current_hp == hp_before, "%s: immune before arena lock (HP stayed %d)" % [b_name, boss.current_hp])
			boss.activate_arena()
			assert_test(boss.is_arena_active, "%s: activate_arena() sets is_arena_active = true" % b_name)
			boss.take_damage(10)
			assert_test(boss.current_hp == hp_before - 10, "%s: vulnerable after arena lock (HP reduced to %d)" % [b_name, boss.current_hp])
		elif "current_hull_hp" in boss: # BossPhantomDredge
			var hp_before = boss.current_hull_hp
			boss.take_damage(25)
			assert_test(boss.current_hull_hp == hp_before, "%s: immune to take_damage before arena lock (HP stayed %d)" % [b_name, boss.current_hull_hp])
			boss.activate_arena()
			assert_test(boss.is_arena_active, "%s: activate_arena() sets is_arena_active = true" % b_name)
			boss.take_damage(10)
			assert_test(boss.current_hull_hp == hp_before - 10, "%s: vulnerable after arena lock (HP reduced to %d)" % [b_name, boss.current_hull_hp])
		elif "current_hp" in boss: # BossWarBarge or BossBoneBeard
			var hp_before = boss.current_hp
			boss.take_damage(25)
			assert_test(boss.current_hp == hp_before, "%s: immune to take_damage before arena lock (HP stayed %d)" % [b_name, boss.current_hp])
			boss.activate_arena()
			assert_test(boss.is_arena_active, "%s: activate_arena() sets is_arena_active = true" % b_name)
			boss.take_damage(10)
			assert_test(boss.current_hp == hp_before - 10, "%s: vulnerable after arena lock (HP reduced to %d)" % [b_name, boss.current_hp])
			
		boss.queue_free()

func test_riverbank_scenery_clearance() -> void:
	print("\n--- TEST 5: Riverbank Scenery Clearance (|X| >= 6.6m) ---")
	var riverbank_script = load("res://src/gameplay/levels/riverbank_props.gd")
	assert_test(riverbank_script != null, "riverbank_props.gd script loaded")
	
	var biomes = ["tropical", "bayou", "citadel", "brimstone"]
	for biome in biomes:
		for side in ["left", "right"]:
			var props = Node3D.new()
			props.set_script(riverbank_script)
			add_child(props)
			
			props.setup(side, 40.0, biome)
			
			var encroaching_vertices = 0
			var total_mesh_instances = 0
			
			# Inspect all child MeshInstance3D positions & bounding boxes
			for child in props.find_children("*", "MeshInstance3D", true, false):
				var mi = child as MeshInstance3D
				if not mi.mesh:
					continue
				total_mesh_instances += 1
				var aabb = mi.mesh.get_aabb()
				var xform = props.global_transform.affine_inverse() * mi.global_transform
				
				for c_idx in range(8):
					var corner = aabb.position + Vector3(
						aabb.size.x if (c_idx & 1) else 0.0,
						aabb.size.y if (c_idx & 2) else 0.0,
						aabb.size.z if (c_idx & 4) else 0.0
					)
					var pt = xform * corner
					# Playable navigable lane is strictly [-6.0, +6.0]
					if pt.x > -6.0 and pt.x < 6.0:
						encroaching_vertices += 1
						
			assert_test(encroaching_vertices == 0, "%s %s bank: 0/%d scenery meshes encroached on [-6.0, 6.0] navigable lane" % [biome.capitalize(), side, total_mesh_instances])
			props.queue_free()

func test_level_endings_and_start_clearance() -> void:
	print("\n--- TEST 6: All 45 Levels Start Clearance (>= 42m) & Multi-Biome Ending Variety ---")
	var opener_paths: Array[String] = [
		"res://src/gameplay/chunks/chunk_warmup.tscn",
		"res://src/gameplay/chunks/chunk_opener_slalom.tscn",
		"res://src/gameplay/chunks/chunk_opener_ambush.tscn",
		"res://src/gameplay/chunks/chunk_opener_gauntlet.tscn",
	]
	for op_path: String in opener_paths:
		var op_scene: PackedScene = load(op_path) as PackedScene
		assert_test(op_scene != null, "Opener scene loaded: %s" % op_path)
		if not op_scene:
			continue
		var op_chunk: BaseTrackChunk = op_scene.instantiate() as BaseTrackChunk
		add_child(op_chunk)
		var entities: Node = op_chunk.get_node_or_null("Entities")
		var close_hostiles: int = 0
		if entities:
			for child: Node in entities.get_children():
				var n3d: Node3D = child as Node3D
				if not n3d:
					continue
				var is_hostile: bool = child.is_in_group("enemies") or child.name.begins_with("Enemy") or child.name.begins_with("Mine")
				if child is DestructibleObstacle and (child as DestructibleObstacle).obstacle_type != DestructibleObstacle.ObstacleType.WOODEN_BARREL:
					is_hostile = true
				if is_hostile and n3d.position.z > -42.0:
					close_hostiles += 1
					printerr("  [VIOLATION] %s has hostile '%s' at z=%.1f (> -42.0m)" % [op_path.get_file(), child.name, n3d.position.z])
		assert_test(close_hostiles == 0, "%s: 0 hostile mobs/mines within 42m bullet-range settle zone" % op_path.get_file())
		op_chunk.queue_free()

	var boss_levels: Array[int] = [5, 10, 15, 20, 25, 30, 35, 40, 45]
	var gs: Node = get_node_or_null("/root/GameState")
	var biome_arch_styles: Dictionary = {"tropical": {}, "bayou": {}, "brimstone": {}}
	var biome_wave_styles: Dictionary = {"tropical": {}, "bayou": {}, "brimstone": {}}
	var specific_arch_styles: Dictionary = {}
	var specific_wave_styles: Dictionary = {}

	for lvl: int in range(1, 46):
		if lvl in boss_levels:
			continue
		if gs:
			gs.set("current_level", lvl)
		var lvl_res: LevelData = load("res://src/data/resources/levels/level_%02d.tres" % lvl) as LevelData
		if not lvl_res:
			continue
		var finish_packed: PackedScene = lvl_res.chunk_scenes[lvl_res.chunk_scenes.size() - 1]
		var finish_chunk: ChunkFinishLine = finish_packed.instantiate() as ChunkFinishLine
		add_child(finish_chunk)
		var theme_data: ThemeSceneryData = lvl_res.get_effective_theme()
		finish_chunk.populate_scenery(theme_data, lvl * 7919 + 42, false)

		var arch_node: Node3D = finish_chunk.find_child("FinishArch", true, false) as Node3D
		assert_test(arch_node != null and arch_node.get_child_count() >= 4, "Level %02d (%s) FinishArch survived populate_scenery (%d props, arch='%s', wave='%s')" % [lvl, lvl_res.biome_name, arch_node.get_child_count() if arch_node else 0, finish_chunk.active_arch_style, finish_chunk.active_wave_style])

		var b_key: String = lvl_res.biome_name.to_lower()
		if biome_arch_styles.has(b_key):
			biome_arch_styles[b_key][finish_chunk.active_arch_style] = true
			biome_wave_styles[b_key][finish_chunk.active_wave_style] = true

		if lvl in [21, 34, 43]:
			specific_arch_styles[finish_chunk.active_arch_style] = true
			specific_wave_styles[finish_chunk.active_wave_style] = true

		finish_chunk.queue_free()

	for b_name: String in ["tropical", "bayou", "brimstone"]:
		assert_test((biome_arch_styles[b_name] as Dictionary).size() >= 3, "Biome '%s' has >= 3 distinct finish arch styles across campaign (%s)" % [b_name, str((biome_arch_styles[b_name] as Dictionary).keys())])
		assert_test((biome_wave_styles[b_name] as Dictionary).size() >= 4, "Biome '%s' has >= 4 distinct finish mob wave formations across campaign (%s)" % [b_name, str((biome_wave_styles[b_name] as Dictionary).keys())])

	assert_test(specific_arch_styles.size() == 3, "Levels 21, 34, and 43 have 3 distinct finish arch styles (%s)" % str(specific_arch_styles.keys()))
	assert_test(specific_wave_styles.size() == 3, "Levels 21, 34, and 43 have 3 distinct finish mob wave formations (%s)" % str(specific_wave_styles.keys()))
	if gs:
		gs.set("current_level", 1)
