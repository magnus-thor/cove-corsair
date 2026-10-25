class_name ChunkVanguardClimax
extends BaseTrackChunk

## Climax combat chunk with StarCraft Zergling-style Swarm Rush.
## Deploys high-density multi-lane waves of fast hostile skiffs rushing
## downriver at high speeds to test player fleet DPS and survivability before the finish line.

const ENEMY_MOB_SCENE: PackedScene = preload("res://src/gameplay/enemies/enemy_mob.tscn")
const CUTTER_SCENE: PackedScene = preload("res://src/gameplay/enemies/enemy_tide_cutter.tscn")
const GRAVE_SKIFF_SCENE: PackedScene = preload("res://src/gameplay/enemies/enemy_grave_skiff.tscn")
const GUNNER_SCENE: PackedScene = preload("res://src/gameplay/enemies/enemy_iron_gunner.tscn")
const BRIMSTONE_RAFT_SCENE: PackedScene = preload("res://src/gameplay/enemies/enemy_brimstone_raft.tscn")
const BARREL_SCENE: PackedScene = preload("res://src/gameplay/obstacles/destructible_barrel.tscn")
const BIOGAS_SCENE: PackedScene = preload("res://src/gameplay/obstacles/hazard_biogas_pod.tscn")
const GEYSER_SCENE: PackedScene = preload("res://src/gameplay/obstacles/hazard_thermal_geyser.tscn")

const ROWER_DATA: Resource = preload("res://src/data/resources/enemy_vessels/skeleton_rower.tres")
const RAIDER_DATA: Resource = preload("res://src/data/resources/enemy_vessels/raider_skiff.tres")
const TURTLE_DATA: Resource = preload("res://src/data/resources/enemy_vessels/turtle_raft.tres")
const GHOST_SLOOP_DATA: Resource = preload("res://src/data/resources/enemy_vessels/ghost_sloop.tres")
const ELITE_IRONCLAD_DATA: Resource = preload("res://src/data/resources/enemy_vessels/enemy_elite_ironclad.tres")

func _ready() -> void:
	super._ready()
	chunk_id = "vanguard_climax"
	_spawn_dynamic_swarm_climax()

func _resolve_climax_biome(cur_lvl: int) -> String:
	return resolve_chunk_biome(cur_lvl)

func _spawn_dynamic_swarm_climax() -> void:
	var entities: Node = get_node_or_null("Entities")
	if not entities:
		return

	var cur_lvl: int = 1
	var gs: Node = get_node_or_null("/root/GameState")
	if gs and "current_level" in gs:
		cur_lvl = int(gs.get("current_level"))

	var escalation_tier: int = 1
	var lc: Node = get_tree().get_first_node_in_group("level_controller")
	if lc and lc.has_method("get_gate_escalation_tier"):
		escalation_tier = maxi(1, int(lc.call("get_gate_escalation_tier")))

	var active_biome: String = _resolve_climax_biome(cur_lvl)
	var variant: int = posmod(cur_lvl, 4)

	var primary_data: Resource = ROWER_DATA
	var secondary_data: Resource = RAIDER_DATA
	if active_biome == "bayou":
		primary_data = GHOST_SLOOP_DATA
		secondary_data = TURTLE_DATA
	elif active_biome == "brimstone":
		primary_data = GHOST_SLOOP_DATA
		secondary_data = ELITE_IRONCLAD_DATA

	# Mob HP and speed scaled by level and gate escalation
	var swarm_hp: int = 2 if cur_lvl <= 4 else (3 if cur_lvl <= 12 else 4)
	var rush_speed: float = 3.6 + minf(1.8, float(escalation_tier) * 0.35 + float(cur_lvl) * 0.04)

	# ── Wave 1: Vanguard Skiff Swarm (Z: -4 to -12) ──
	var wave_1_lanes: Array[float] = [-3.3, -2.2, -1.1, 0.0, 1.1, 2.2, 3.3]
	if variant == 1:
		wave_1_lanes = [-3.6, -2.6, -1.6, 0.0, 1.6, 2.6, 3.6]
	elif variant == 2:
		wave_1_lanes = [-3.4, -2.0, -0.8, 0.8, 2.0, 3.4]
	elif variant == 3:
		wave_1_lanes = [-3.2, -1.8, -0.6, 0.0, 0.6, 1.8, 3.2]

	for i: int in range(wave_1_lanes.size()):
		var lx: float = wave_1_lanes[i]
		var mob: EnemyMob = ENEMY_MOB_SCENE.instantiate() as EnemyMob
		if mob:
			entities.add_child(mob)
			var z_offset: float = -4.0 - float(i % 3) * 2.2
			mob.position = Vector3(lx, 0.1, z_offset)
			if mob.has_method("apply_enemy_data"):
				mob.call("apply_enemy_data", primary_data)
			mob.max_hp = swarm_hp
			mob.current_hp = swarm_hp
			mob.forward_speed = rush_speed
			mob.doubloons_drop = 1

	# ── Wave 2: Fast Raider Flotilla (Z: -15 to -23) ──
	var wave_2_lanes: Array[float] = [-3.0, -1.8, -0.6, 0.6, 1.8, 3.0]
	if variant == 1:
		wave_2_lanes = [-3.4, -2.2, -1.0, 1.0, 2.2, 3.4]
	elif variant == 2:
		wave_2_lanes = [-2.8, -1.4, 0.0, 1.4, 2.8]
	elif variant == 3:
		wave_2_lanes = [-3.2, -2.0, -0.8, 0.8, 2.0, 3.2]

	for i: int in range(wave_2_lanes.size()):
		var lx: float = wave_2_lanes[i]
		var mob: EnemyMob = ENEMY_MOB_SCENE.instantiate() as EnemyMob
		if mob:
			entities.add_child(mob)
			var z_offset: float = -15.5 - float((i + variant) % 3) * 2.2
			mob.position = Vector3(lx, 0.1, z_offset)
			if mob.has_method("apply_enemy_data"):
				mob.call("apply_enemy_data", secondary_data)
			mob.max_hp = swarm_hp + 1
			mob.current_hp = swarm_hp + 1
			mob.forward_speed = rush_speed + 0.4
			mob.doubloons_drop = 2

	# Biome-Themed Center Hazards in Wave 2
	for hazard_x: float in [-1.2, 1.2]:
		if active_biome == "bayou":
			var pod: Node3D = BIOGAS_SCENE.instantiate() as Node3D
			if pod:
				entities.add_child(pod)
				pod.position = Vector3(hazard_x, 0.05, -22.0)
		elif active_biome == "brimstone":
			var geyser: Node3D = GEYSER_SCENE.instantiate() as Node3D
			if geyser:
				entities.add_child(geyser)
				geyser.position = Vector3(hazard_x, 0.0, -22.0)
		else:
			var keg: DestructibleObstacle = BARREL_SCENE.instantiate() as DestructibleObstacle
			if keg:
				entities.add_child(keg)
				keg.position = Vector3(hazard_x, 0.05, -22.0)
				keg.obstacle_type = DestructibleObstacle.ObstacleType.FUSE_BARREL

	# ── Gatekeeper Reinforcements on Milestone Levels ──
	if cur_lvl in [8, 15, 22, 30, 37, 44] or escalation_tier >= 2:
		_spawn_gatekeeper_wave(entities, cur_lvl, active_biome)

	# ── Wave 3: Biome Heavy Prows + Flank Escorts (Z: -30 to -37) ──
	var heavy_scene: PackedScene = CUTTER_SCENE
	if active_biome == "bayou":
		heavy_scene = GRAVE_SKIFF_SCENE if variant % 2 == 0 else CUTTER_SCENE
	elif active_biome == "brimstone":
		heavy_scene = BRIMSTONE_RAFT_SCENE if variant % 2 == 1 else GUNNER_SCENE

	var heavy_x_pair: Array[float] = [-2.2, 2.2]
	if variant % 2 != 0:
		heavy_x_pair = [-1.6, 1.6]
	for hx: float in heavy_x_pair:
		var heavy_mob: Node3D = heavy_scene.instantiate() as Node3D
		if heavy_mob:
			entities.add_child(heavy_mob)
			heavy_mob.position = Vector3(hx, 0.1, -32.0)
			if "forward_speed" in heavy_mob:
				heavy_mob.set("forward_speed", rush_speed * 0.8)

	var flank_x_pair: Array[float] = [-0.8, 0.8]
	if variant % 2 != 0:
		flank_x_pair = [-3.0, 3.0]
	for flank_x: float in flank_x_pair:
		var escort: EnemyMob = ENEMY_MOB_SCENE.instantiate() as EnemyMob
		if escort:
			entities.add_child(escort)
			escort.position = Vector3(flank_x, 0.1, -34.0)
			if escort.has_method("apply_enemy_data"):
				escort.call("apply_enemy_data", secondary_data)
			escort.max_hp = swarm_hp
			escort.current_hp = swarm_hp
			escort.forward_speed = rush_speed

	# ── Wave 4: Final Breakthrough Swarm (Z: -39 to -48) ──
	var wave_4_lanes: Array[float] = [-3.4, -2.5, -1.7, -0.8, 0.0, 0.8, 1.7, 2.5, 3.4]
	if variant == 1:
		wave_4_lanes = [-3.6, -2.7, -1.8, -0.9, 0.9, 1.8, 2.7, 3.6]
	elif variant == 2:
		wave_4_lanes = [-3.2, -2.4, -1.6, -0.8, 0.0, 0.8, 1.6, 2.4, 3.2]
	elif variant == 3:
		wave_4_lanes = [-3.5, -2.3, -1.2, -0.4, 0.4, 1.2, 2.3, 3.5]

	for i: int in range(wave_4_lanes.size()):
		var lx: float = wave_4_lanes[i]
		var mob: EnemyMob = ENEMY_MOB_SCENE.instantiate() as EnemyMob
		if mob:
			entities.add_child(mob)
			var z_offset: float = -39.5 - float((i + variant) % 4) * 2.5
			mob.position = Vector3(lx, 0.1, z_offset)
			if mob.has_method("apply_enemy_data"):
				mob.call("apply_enemy_data", primary_data if i % 2 == 0 else secondary_data)
			mob.max_hp = swarm_hp
			mob.current_hp = swarm_hp
			mob.forward_speed = rush_speed + 0.6
			mob.doubloons_drop = 1

func _spawn_gatekeeper_wave(entities: Node, _cur_lvl: int, active_biome: String = "tropical") -> void:
	var gk_scene: PackedScene = GRAVE_SKIFF_SCENE if active_biome == "bayou" else GUNNER_SCENE
	var gk_l: Node3D = gk_scene.instantiate() as Node3D
	if gk_l:
		entities.add_child(gk_l)
		gk_l.position = Vector3(-2.2, 0.1, -28.0)
		if "is_gunner_vanguard" in gk_l:
			gk_l.set("is_gunner_vanguard", true)
		if "can_shoot" in gk_l:
			gk_l.set("can_shoot", true)

	var gk_r: Node3D = gk_scene.instantiate() as Node3D
	if gk_r:
		entities.add_child(gk_r)
		gk_r.position = Vector3(2.2, 0.1, -28.0)
		if "is_gunner_vanguard" in gk_r:
			gk_r.set("is_gunner_vanguard", true)
		if "can_shoot" in gk_r:
			gk_r.set("can_shoot", true)
