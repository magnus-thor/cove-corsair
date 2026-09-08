extends Node

const CHUNK_SCRIPT = preload("res://src/gameplay/chunks/base_track_chunk.gd")
const BARRICADE_SIEGE_SCRIPT = preload("res://src/gameplay/chunks/chunk_barricade_siege.gd")
const CHEST_MARKER_SCRIPT = preload("res://src/gameplay/chunks/chest_spawn_marker.gd")

const COIN_SCENE = preload("res://src/gameplay/collectibles/collectible_doubloon.tscn")
const BARREL_SCENE = preload("res://src/gameplay/obstacles/destructible_barrel.tscn")
const SEA_MINE_SCENE = preload("res://src/gameplay/obstacles/hazard_sea_mine.tscn")
const BARRICADE_SCENE = preload("res://src/gameplay/obstacles/barricade_wall.tscn")
const GATE_SCENE = preload("res://src/gameplay/obstacles/multiplier_gate.tscn")
const ENEMY_SCENE = preload("res://src/gameplay/enemies/enemy_mob.tscn")

const BOSS_IRONJAW = preload("res://src/gameplay/enemies/boss_war_barge.tscn")
const BOSS_DREDGE = preload("res://src/gameplay/enemies/boss_phantom_dredge.tscn")
const BOSS_FORTRESS = preload("res://src/gameplay/enemies/boss_siege_fortress.tscn")

# Bank Models
const DOCK_MODEL = preload("res://assets/models/structure-platform-dock.glb")
const PALM_MODEL = preload("res://assets/models/palm-detailed-straight.glb")
const ROCKS_A_MODEL = preload("res://assets/models/rocks-a.glb")
const ROCKS_B_MODEL = preload("res://assets/models/rocks-b.glb")
const FENCE_MODEL = preload("res://assets/models/structure-fence.glb")
const TOWER_MODEL = preload("res://assets/models/tower-complete-small.glb")

func _ready() -> void:
	print("[BUILD CHUNKS] Starting chunk scenes generation...")
	DirAccess.make_dir_recursive_absolute("res://src/gameplay/chunks")
	DirAccess.make_dir_recursive_absolute("res://src/data/resources/levels")
	
	build_warmup_chunk()
	build_mine_gauntlet_chunk()
	build_barricade_siege_chunk()
	build_boss_chunk("chunk_boss_ironjaw.tscn", "boss_ironjaw", BOSS_IRONJAW, "tropical")
	build_boss_chunk("chunk_boss_phantom_dredge.tscn", "boss_phantom_dredge", BOSS_DREDGE, "bayou")
	build_boss_chunk("chunk_boss_siege_fortress.tscn", "boss_siege_fortress", BOSS_FORTRESS, "brimstone")
	
	build_level_resources()
	print("[BUILD CHUNKS] All chunk scenes and level resources successfully built!")
	get_tree().quit(0)

func create_base_chunk_node(chunk_id: String, is_boss: bool = false) -> BaseTrackChunk:
	var root := BaseTrackChunk.new()
	root.name = chunk_id.capitalize().replace(" ", "")
	root.set_script(CHUNK_SCRIPT)
	root.chunk_id = chunk_id
	root.is_boss_chunk = is_boss
	
	var m_start := Marker3D.new()
	m_start.name = "ChunkStart"
	m_start.position = Vector3(0, 0, 0)
	root.add_child(m_start)
	m_start.owner = root
	
	var m_end := Marker3D.new()
	m_end.name = "ChunkEnd"
	m_end.position = Vector3(0, 0, -50.0)
	root.add_child(m_end)
	m_end.owner = root
	
	var banks := Node3D.new()
	banks.name = "Banks"
	root.add_child(banks)
	banks.owner = root
	
	var entities := Node3D.new()
	entities.name = "Entities"
	root.add_child(entities)
	entities.owner = root
	
	return root

func add_model_to_node(parent: Node, root_owner: Node, glb_scene: PackedScene, node_name: String, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO, sc: Vector3 = Vector3.ONE) -> Node3D:
	if not glb_scene:
		return null
	var inst = glb_scene.instantiate()
	inst.name = node_name
	parent.add_child(inst)
	inst.position = pos
	inst.rotation_degrees = rot_deg
	inst.scale = sc
	inst.owner = root_owner
	return inst

func save_chunk(root: Node, path: String) -> void:
	var packed := PackedScene.new()
	var result = packed.pack(root)
	if result == OK:
		var err = ResourceSaver.save(packed, path)
		if err == OK:
			print("Saved: ", path)
		else:
			printerr("Failed to save: ", path, " err: ", err)
	else:
		printerr("Failed to pack scene for: ", path, " result: ", result)
	root.free()

# 1. Warmup Chunk
func build_warmup_chunk() -> void:
	var root := create_base_chunk_node("warmup")
	var banks := root.get_node("Banks")
	var entities := root.get_node("Entities")
	
	# Scenery on left bank (X approx -8.5)
	add_model_to_node(banks, root, DOCK_MODEL, "Dock_Left", Vector3(-8.0, 0, -12), Vector3(0, 90, 0), Vector3(1.2, 1, 1.5))
	add_model_to_node(banks, root, PALM_MODEL, "Palm_Left", Vector3(-9.5, 0, -22), Vector3(0, 30, 0), Vector3(1.5, 1.5, 1.5))
	add_model_to_node(banks, root, ROCKS_A_MODEL, "RocksA_Left", Vector3(-9.8, 0, -36), Vector3(0, 45, 0), Vector3(1.6, 1.6, 1.6))
	
	# Scenery on right bank (X approx +8.5)
	add_model_to_node(banks, root, PALM_MODEL, "Palm_Right", Vector3(9.5, 0, -14), Vector3(0, -40, 0), Vector3(1.5, 1.5, 1.5))
	add_model_to_node(banks, root, ROCKS_B_MODEL, "RocksB_Right", Vector3(9.8, 0, -28), Vector3(0, -20, 0), Vector3(1.8, 1.8, 1.8))
	add_model_to_node(banks, root, DOCK_MODEL, "Dock_Right", Vector3(8.0, 0, -42), Vector3(0, -90, 0), Vector3(1.2, 1, 1.5))
	
	# Coins arc (Z = -8 to -16)
	for i in range(5):
		var t = float(i) / 4.0
		var x = lerp(-2.0, 2.0, t)
		var z = -8.0 - (i * 2.0)
		var coin = COIN_SCENE.instantiate()
		coin.name = "Doubloon_%d" % (i + 1)
		entities.add_child(coin)
		coin.position = Vector3(x, 0.13, z)
		coin.owner = root
		
	# Center wooden barrel at Z = -22
	var b1 = BARREL_SCENE.instantiate()
	b1.name = "Barrel_Center"
	entities.add_child(b1)
	b1.position = Vector3(0, 0.05, -22.0)
	b1.hp = 1
	b1.owner = root
	
	# Skeleton rower at Z = -28
	var mob = ENEMY_SCENE.instantiate()
	mob.name = "EnemyMob_Rower"
	entities.add_child(mob)
	mob.position = Vector3(-1.8, 0.1, -28.0)
	mob.max_hp = 2
	mob.current_hp = 2
	mob.forward_speed = 1.5
	mob.owner = root
	
	# Flanking wooden barrels at Z = -34
	var b2 = BARREL_SCENE.instantiate()
	b2.name = "Barrel_Left"
	entities.add_child(b2)
	b2.position = Vector3(-2.8, 0.05, -34.0)
	b2.hp = 1
	b2.owner = root
	
	var b3 = BARREL_SCENE.instantiate()
	b3.name = "Barrel_Right"
	entities.add_child(b3)
	b3.position = Vector3(2.8, 0.05, -34.0)
	b3.hp = 1
	b3.owner = root
	
	# Multiplier gate (+1 Fleet) at Z = -42
	var gate = GATE_SCENE.instantiate()
	gate.name = "MultiplierGate"
	entities.add_child(gate)
	gate.position = Vector3(0, 0.0, -42.0)
	gate.operation = 0 # ADD
	gate.value = 1
	gate.custom_text = "+1"
	gate.gate_action = "add_fleet_1"
	gate.owner = root
	
	save_chunk(root, "res://src/gameplay/chunks/chunk_warmup.tscn")

# 2. Mine Gauntlet Chunk (Vector A Chokepoints)
func build_mine_gauntlet_chunk() -> void:
	var root := create_base_chunk_node("mine_gauntlet")
	var banks := root.get_node("Banks")
	var entities := root.get_node("Entities")
	
	# Rugged rocky banks
	add_model_to_node(banks, root, ROCKS_B_MODEL, "RocksB_Left1", Vector3(-9.5, 0, -10), Vector3(0, 15, 0), Vector3(2.0, 2.0, 2.0))
	add_model_to_node(banks, root, ROCKS_A_MODEL, "RocksA_Left2", Vector3(-9.2, 0, -32), Vector3(0, 60, 0), Vector3(1.8, 1.8, 1.8))
	add_model_to_node(banks, root, ROCKS_A_MODEL, "RocksA_Right1", Vector3(9.5, 0, -16), Vector3(0, -30, 0), Vector3(1.9, 1.9, 1.9))
	add_model_to_node(banks, root, ROCKS_B_MODEL, "RocksB_Right2", Vector3(9.2, 0, -38), Vector3(0, -75, 0), Vector3(2.1, 2.1, 2.1))
	
	# Gate 1 (Z = -12.0): Left passage (centers -3.45 and -0.15, gap = 2.1m)
	var m1_l = SEA_MINE_SCENE.instantiate()
	m1_l.name = "MineGate1_Left"
	entities.add_child(m1_l)
	m1_l.position = Vector3(-3.45, 0.0, -12.0)
	m1_l.owner = root
	
	var m1_r = SEA_MINE_SCENE.instantiate()
	m1_r.name = "MineGate1_Right"
	entities.add_child(m1_r)
	m1_r.position = Vector3(-0.15, 0.0, -12.0)
	m1_r.owner = root
	
	var d1 = COIN_SCENE.instantiate()
	d1.name = "Doubloon1"
	entities.add_child(d1)
	d1.position = Vector3(-1.8, 0.13, -12.0)
	d1.value = 8
	d1.owner = root
	
	# Gate 2 (Z = -24.0): Center passage (centers -1.65 and 1.65, gap = 2.1m)
	var m2_l = SEA_MINE_SCENE.instantiate()
	m2_l.name = "MineGate2_Left"
	entities.add_child(m2_l)
	m2_l.position = Vector3(-1.65, 0.0, -24.0)
	m2_l.owner = root
	
	var m2_r = SEA_MINE_SCENE.instantiate()
	m2_r.name = "MineGate2_Right"
	entities.add_child(m2_r)
	m2_r.position = Vector3(1.65, 0.0, -24.0)
	m2_r.owner = root
	
	var d2 = COIN_SCENE.instantiate()
	d2.name = "Doubloon2"
	entities.add_child(d2)
	d2.position = Vector3(0.0, 0.13, -24.0)
	d2.value = 8
	d2.owner = root
	
	# Gate 3 (Z = -36.0): Right passage (centers 0.15 and 3.45, gap = 2.1m)
	var m3_l = SEA_MINE_SCENE.instantiate()
	m3_l.name = "MineGate3_Left"
	entities.add_child(m3_l)
	m3_l.position = Vector3(0.15, 0.0, -36.0)
	m3_l.owner = root
	
	var m3_r = SEA_MINE_SCENE.instantiate()
	m3_r.name = "MineGate3_Right"
	entities.add_child(m3_r)
	m3_r.position = Vector3(3.45, 0.0, -36.0)
	m3_r.owner = root
	
	var d3 = COIN_SCENE.instantiate()
	d3.name = "Doubloon3"
	entities.add_child(d3)
	d3.position = Vector3(1.8, 0.13, -36.0)
	d3.value = 8
	d3.owner = root
	
	# Gate 4 (Z = -46.0): Center passage (centers -1.65 and 1.65, gap = 2.1m)
	var m4_l = SEA_MINE_SCENE.instantiate()
	m4_l.name = "MineGate4_Left"
	entities.add_child(m4_l)
	m4_l.position = Vector3(-1.65, 0.0, -46.0)
	m4_l.owner = root
	
	var m4_r = SEA_MINE_SCENE.instantiate()
	m4_r.name = "MineGate4_Right"
	entities.add_child(m4_r)
	m4_r.position = Vector3(1.65, 0.0, -46.0)
	m4_r.owner = root
	
	var d4 = COIN_SCENE.instantiate()
	d4.name = "Doubloon4"
	entities.add_child(d4)
	d4.position = Vector3(0.0, 0.13, -46.0)
	d4.value = 8
	d4.owner = root
	
	# Chest spawn markers for hazard pockets
	var m_left = Marker3D.new()
	m_left.name = "ChestSpawnMarker_HazardLeft"
	m_left.set_script(CHEST_MARKER_SCRIPT)
	m_left.chest_value = 75
	m_left.min_level = 5
	m_left.position = Vector3(-3.4, 0.05, -16.0)
	entities.add_child(m_left)
	m_left.owner = root

	var m_right = Marker3D.new()
	m_right.name = "ChestSpawnMarker_HazardRight"
	m_right.set_script(CHEST_MARKER_SCRIPT)
	m_right.chest_value = 100
	m_right.min_level = 5
	m_right.position = Vector3(3.4, 0.05, -40.0)
	entities.add_child(m_right)
	m_right.owner = root
	
	save_chunk(root, "res://src/gameplay/chunks/chunk_mine_gauntlet.tscn")

# 3. Barricade Siege Chunk (Vector B)
func build_barricade_siege_chunk() -> void:
	var root := create_base_chunk_node("barricade_siege")
	root.set_script(BARRICADE_SIEGE_SCRIPT)
	var banks := root.get_node("Banks")
	var entities := root.get_node("Entities")
	
	# Fortified ramparts on banks
	add_model_to_node(banks, root, FENCE_MODEL, "Fence_Left", Vector3(-7.5, 0, -18), Vector3(0, 0, 0), Vector3(1.5, 1.5, 2.0))
	add_model_to_node(banks, root, TOWER_MODEL, "Tower_Left", Vector3(-9.5, 0, -32), Vector3(0, 45, 0), Vector3(1.2, 1.2, 1.2))
	add_model_to_node(banks, root, FENCE_MODEL, "Fence_Right", Vector3(7.5, 0, -18), Vector3(0, 0, 0), Vector3(1.5, 1.5, 2.0))
	add_model_to_node(banks, root, TOWER_MODEL, "Tower_Right", Vector3(9.5, 0, -32), Vector3(0, -45, 0), Vector3(1.2, 1.2, 1.2))
	
	# Turtle raft armored front at Z = -12
	var turtle = ENEMY_SCENE.instantiate()
	turtle.name = "EnemyMob_TurtleRaft"
	entities.add_child(turtle)
	turtle.position = Vector3(0.0, 0.1, -12.0)
	var turtle_data = preload("res://src/data/resources/enemy_vessels/turtle_raft.tres")
	if turtle.has_method("apply_enemy_data"):
		turtle.apply_enemy_data(turtle_data)
	turtle.max_hp = 6
	turtle.current_hp = 6
	turtle.forward_speed = 1.6
	turtle.owner = root
	
	# Barricade wall at Z = -22
	var wall = BARRICADE_SCENE.instantiate()
	wall.name = "BarricadeWall"
	entities.add_child(wall)
	wall.position = Vector3(0.0, 0.0, -22.0)
	wall.owner = root
	
	# Armored chest rune barrel at Z = -30
	var chest_barrel = BARREL_SCENE.instantiate()
	chest_barrel.name = "Barrel_RuneChest"
	entities.add_child(chest_barrel)
	chest_barrel.position = Vector3(0.0, 0.05, -30.0)
	chest_barrel.obstacle_type = 2 # RUNE_BARREL
	chest_barrel.hp = 2
	chest_barrel.set_meta("spawns_chest", true)
	chest_barrel.owner = root
	
	# Multiplier gate (+2 Fleet) reward at Z = -38
	var gate = GATE_SCENE.instantiate()
	gate.name = "MultiplierGate"
	entities.add_child(gate)
	gate.position = Vector3(0, 0.0, -38.0)
	gate.operation = 0 # ADD
	gate.value = 2
	gate.custom_text = "+2"
	gate.gate_action = "add_fleet_2"
	gate.owner = root
	
	# Dual skeleton rowers at Z = -48 (enforcing >= 25m safe buffer zone behind barricade)
	var r1 = ENEMY_SCENE.instantiate()
	r1.name = "EnemyMob_RowerLeft"
	entities.add_child(r1)
	r1.position = Vector3(-2.2, 0.1, -48.0)
	r1.max_hp = 2
	r1.current_hp = 2
	r1.forward_speed = 1.8
	r1.owner = root
	
	var r2 = ENEMY_SCENE.instantiate()
	r2.name = "EnemyMob_RowerRight"
	entities.add_child(r2)
	r2.position = Vector3(2.2, 0.1, -48.0)
	r2.max_hp = 2
	r2.current_hp = 2
	r2.forward_speed = 1.8
	r2.owner = root
	
	# Hazard flank chest spawn marker
	var m_flank = Marker3D.new()
	m_flank.name = "ChestSpawnMarker_HazardFlank"
	m_flank.set_script(CHEST_MARKER_SCRIPT)
	m_flank.chest_value = 50
	m_flank.min_level = 5
	m_flank.position = Vector3(3.4, 0.05, -34.0)
	entities.add_child(m_flank)
	m_flank.owner = root
	
	save_chunk(root, "res://src/gameplay/chunks/chunk_barricade_siege.tscn")

# 4. Boss Arena Chunks
func build_boss_chunk(filename: String, chunk_id: String, boss_prefab: PackedScene, theme: String) -> void:
	var root := create_base_chunk_node(chunk_id, true)
	root.boss_scene = boss_prefab
	var banks := root.get_node("Banks")
	var entities := root.get_node("Entities")
	
	# Arena entrance decor
	if theme == "tropical":
		add_model_to_node(banks, root, TOWER_MODEL, "Tower_Left", Vector3(-9.0, 0, -8), Vector3(0, 45, 0), Vector3(1.4, 1.4, 1.4))
		add_model_to_node(banks, root, TOWER_MODEL, "Tower_Right", Vector3(9.0, 0, -8), Vector3(0, -45, 0), Vector3(1.4, 1.4, 1.4))
		add_model_to_node(banks, root, ROCKS_B_MODEL, "RocksB_Left", Vector3(-10.0, 0, -30), Vector3(0, 0, 0), Vector3(2.2, 2.2, 2.2))
		add_model_to_node(banks, root, ROCKS_B_MODEL, "RocksB_Right", Vector3(10.0, 0, -30), Vector3(0, 0, 0), Vector3(2.2, 2.2, 2.2))
	elif theme == "bayou":
		add_model_to_node(banks, root, ROCKS_A_MODEL, "RocksA_Left", Vector3(-9.5, 0, -12), Vector3(0, 30, 0), Vector3(2.0, 1.5, 2.0))
		add_model_to_node(banks, root, ROCKS_A_MODEL, "RocksA_Right", Vector3(9.5, 0, -12), Vector3(0, -30, 0), Vector3(2.0, 1.5, 2.0))
	elif theme == "brimstone":
		add_model_to_node(banks, root, TOWER_MODEL, "Tower_Left", Vector3(-9.5, 0, -10), Vector3(0, 20, 0), Vector3(1.8, 1.8, 1.8))
		add_model_to_node(banks, root, TOWER_MODEL, "Tower_Right", Vector3(9.5, 0, -10), Vector3(0, -20, 0), Vector3(1.8, 1.8, 1.8))
		add_model_to_node(banks, root, FENCE_MODEL, "Fence_Left", Vector3(-7.5, 0, -25), Vector3(0, 0, 0), Vector3(1.5, 1.5, 2.5))
		add_model_to_node(banks, root, FENCE_MODEL, "Fence_Right", Vector3(7.5, 0, -25), Vector3(0, 0, 0), Vector3(1.5, 1.5, 2.5))
		
	# Arena pre-boss skull totems / warning buoys
	var totem_left = BARREL_SCENE.instantiate()
	totem_left.name = "Barrel_TotemLeft"
	entities.add_child(totem_left)
	totem_left.position = Vector3(-4.8, 0.05, -6.0)
	totem_left.obstacle_type = 2 # RUNE
	totem_left.hp = 1
	totem_left.owner = root
	
	var totem_right = BARREL_SCENE.instantiate()
	totem_right.name = "Barrel_TotemRight"
	entities.add_child(totem_right)
	totem_right.position = Vector3(4.8, 0.05, -6.0)
	totem_right.obstacle_type = 2 # RUNE
	totem_right.hp = 1
	totem_right.owner = root
	
	save_chunk(root, "res://src/gameplay/chunks/" + filename)

func build_level_resources() -> void:
	var warmup = load("res://src/gameplay/chunks/chunk_warmup.tscn")
	var mine = load("res://src/gameplay/chunks/chunk_mine_gauntlet.tscn")
	var barricade = load("res://src/gameplay/chunks/chunk_barricade_siege.tscn")
	var boss_1 = load("res://src/gameplay/chunks/chunk_boss_ironjaw.tscn")
	var boss_2 = load("res://src/gameplay/chunks/chunk_boss_phantom_dredge.tscn")
	var boss_3 = load("res://src/gameplay/chunks/chunk_boss_siege_fortress.tscn")
	
	var horizon_smugglers = load("res://assets/textures/horizon_smugglers_run.png")
	
	# Level 1: Smuggler's Run (250m)
	var l1 := LevelData.new()
	l1.level_id = 1
	l1.level_title = "Level 1: Smuggler's Run"
	l1.biome_name = "tropical"
	l1.base_scroll_speed = 6.5
	l1.completion_doubloon_reward = 150
	l1.horizon_texture = horizon_smugglers
	l1.water_albedo = Color(0.08, 0.58, 0.82, 0.88)
	l1.fog_color = Color(0.48, 0.76, 0.94, 1.0)
	l1.fog_density = 0.0
	l1.river_width_world = 12.0
	l1.chunk_scenes = [warmup, mine, barricade, mine, boss_1]
	ResourceSaver.save(l1, "res://src/data/resources/levels/level_01.tres")
	ResourceSaver.save(l1, "res://src/data/resources/levels/level_01_smugglers_run.tres")
	print("Saved level_01.tres and level_01_smugglers_run.tres")
	
	# Level 2: Black Tide Bayou (250m)
	var l2 := LevelData.new()
	l2.level_id = 2
	l2.level_title = "Level 2: Black Tide Bayou"
	l2.biome_name = "bayou"
	l2.base_scroll_speed = 7.5
	l2.completion_doubloon_reward = 250
	l2.horizon_texture = horizon_smugglers
	l2.water_albedo = Color(0.12, 0.25, 0.18, 0.92) # Murky green swamp water
	l2.fog_color = Color(0.22, 0.35, 0.28, 1.0)
	l2.fog_density = 0.015
	l2.river_width_world = 12.0
	l2.chunk_scenes = [warmup, barricade, mine, barricade, boss_2]
	ResourceSaver.save(l2, "res://src/data/resources/levels/level_02.tres")
	ResourceSaver.save(l2, "res://src/data/resources/levels/level_02_black_tide_bayou.tres")
	print("Saved level_02.tres and level_02_black_tide_bayou.tres")
	
	# Level 3: Brimstone Bastion (250m)
	var l3 := LevelData.new()
	l3.level_id = 3
	l3.level_title = "Level 3: Brimstone Bastion"
	l3.biome_name = "brimstone"
	l3.base_scroll_speed = 8.0
	l3.completion_doubloon_reward = 350
	l3.horizon_texture = horizon_smugglers
	l3.water_albedo = Color(0.35, 0.10, 0.08, 0.95) # Volcanic lava / dark brimstone
	l3.fog_color = Color(0.45, 0.18, 0.12, 1.0)
	l3.fog_density = 0.02
	l3.river_width_world = 12.0
	l3.chunk_scenes = [mine, barricade, mine, barricade, boss_3]
	ResourceSaver.save(l3, "res://src/data/resources/levels/level_03.tres")
	ResourceSaver.save(l3, "res://src/data/resources/levels/level_03_brimstone_bastion.tres")
	print("Saved level_03.tres and level_03_brimstone_bastion.tres")
	
	# Level 4: Smuggler's Nightmare (250m)
	var l4 := LevelData.new()
	l4.level_id = 4
	l4.level_title = "Level 4: Smuggler's Nightmare"
	l4.biome_name = "tropical"
	l4.base_scroll_speed = 8.5
	l4.completion_doubloon_reward = 300
	l4.horizon_texture = horizon_smugglers
	l4.water_albedo = Color(0.04, 0.35, 0.55, 0.92)
	l4.fog_color = Color(0.18, 0.28, 0.42, 1.0)
	l4.fog_density = 0.008
	l4.river_width_world = 12.0
	l4.chunk_scenes = [warmup, mine, barricade, mine, boss_1]
	ResourceSaver.save(l4, "res://src/data/resources/levels/level_04_smugglers_nightmare.tres")
	print("Saved level_04_smugglers_nightmare.tres")

	# Level 5: Black Tide Abyss (250m)
	var l5 := LevelData.new()
	l5.level_id = 5
	l5.level_title = "Level 5: Black Tide Abyss"
	l5.biome_name = "bayou"
	l5.base_scroll_speed = 9.0
	l5.completion_doubloon_reward = 400
	l5.horizon_texture = horizon_smugglers
	l5.water_albedo = Color(0.06, 0.18, 0.14, 0.95)
	l5.fog_color = Color(0.15, 0.25, 0.20, 1.0)
	l5.fog_density = 0.02
	l5.river_width_world = 12.0
	l5.chunk_scenes = [mine, barricade, mine, barricade, boss_2]
	ResourceSaver.save(l5, "res://src/data/resources/levels/level_05_black_tide_abyss.tres")
	print("Saved level_05_black_tide_abyss.tres")

	# Level 6: Brimstone Inferno (250m)
	var l6 := LevelData.new()
	l6.level_id = 6
	l6.level_title = "Level 6: Brimstone Inferno"
	l6.biome_name = "brimstone"
	l6.base_scroll_speed = 9.5
	l6.completion_doubloon_reward = 500
	l6.horizon_texture = horizon_smugglers
	l6.water_albedo = Color(0.40, 0.08, 0.05, 0.98)
	l6.fog_color = Color(0.50, 0.15, 0.10, 1.0)
	l6.fog_density = 0.025
	l6.river_width_world = 12.0
	l6.chunk_scenes = [mine, barricade, mine, barricade, boss_3]
	ResourceSaver.save(l6, "res://src/data/resources/levels/level_06_brimstone_inferno.tres")
	print("Saved level_06_brimstone_inferno.tres")
