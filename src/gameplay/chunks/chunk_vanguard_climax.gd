class_name ChunkVanguardClimax
extends BaseTrackChunk

## Climax combat chunk with StarCraft Zergling-style Swarm Rush.
## Deploys high-density multi-lane waves of fast hostile skiffs rushing
## downriver at high speeds to test player fleet DPS and survivability before the finish line.

const ENEMY_MOB_SCENE: PackedScene = preload("res://src/gameplay/enemies/enemy_mob.tscn")
const CUTTER_SCENE: PackedScene = preload("res://src/gameplay/enemies/enemy_tide_cutter.tscn")
const BARREL_SCENE: PackedScene = preload("res://src/gameplay/obstacles/destructible_barrel.tscn")
const ROWER_DATA: Resource = preload("res://src/data/resources/enemy_vessels/skeleton_rower.tres")
const RAIDER_DATA: Resource = preload("res://src/data/resources/enemy_vessels/raider_skiff.tres")
const GUNNER_SCENE: PackedScene = preload("res://src/gameplay/enemies/enemy_iron_gunner.tscn")

func _ready() -> void:
	super._ready()
	chunk_id = "vanguard_climax"
	_spawn_dynamic_swarm_climax()

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

	# Mob HP and speed scaled by level and gate escalation
	var swarm_hp: int = 2 if cur_lvl <= 4 else (3 if cur_lvl <= 12 else 4)
	var rush_speed: float = 3.6 + minf(1.8, float(escalation_tier) * 0.35 + float(cur_lvl) * 0.04)

	# ── Wave 1: Vanguard Skiff Swarm (Z: -6 to -14) ──
	var wave_1_lanes: Array[float] = [-3.3, -2.2, -1.1, 0.0, 1.1, 2.2, 3.3]
	for lx: float in wave_1_lanes:
		var mob: EnemyMob = ENEMY_MOB_SCENE.instantiate() as EnemyMob
		if mob:
			entities.add_child(mob)
			mob.position = Vector3(lx, 0.1, randf_range(-7.0, -13.0))
			if mob.has_method("apply_enemy_data"):
				mob.call("apply_enemy_data", ROWER_DATA)
			mob.max_hp = swarm_hp
			mob.forward_speed = rush_speed
			mob.doubloons_drop = 1

	# ── Wave 2: Fast Raider Flotilla (Z: -18 to -26) ──
	var wave_2_lanes: Array[float] = [-3.0, -1.8, -0.6, 0.6, 1.8, 3.0]
	for lx: float in wave_2_lanes:
		var mob: EnemyMob = ENEMY_MOB_SCENE.instantiate() as EnemyMob
		if mob:
			entities.add_child(mob)
			mob.position = Vector3(lx, 0.1, randf_range(-19.0, -25.0))
			if mob.has_method("apply_enemy_data"):
				mob.call("apply_enemy_data", RAIDER_DATA)
			mob.max_hp = swarm_hp + 1
			mob.forward_speed = rush_speed + 0.4
			mob.doubloons_drop = 2

	# Center Obstacle Hazards in Wave 2
	for keg_x: float in [-1.0, 1.0]:
		var keg: DestructibleObstacle = BARREL_SCENE.instantiate() as DestructibleObstacle
		if keg:
			entities.add_child(keg)
			keg.position = Vector3(keg_x, 0.05, -22.0)
			keg.obstacle_type = DestructibleObstacle.ObstacleType.FUSE_BARREL

	# ── Gatekeeper Reinforcements on Milestone Levels ──
	if cur_lvl in [8, 15, 22, 30, 37, 44] or escalation_tier >= 2:
		_spawn_gatekeeper_wave(entities, cur_lvl)

	# ── Wave 3: Heavy Cutter Prows + Flank Skiffs (Z: -30 to -37) ──
	var cutter_l: Node3D = CUTTER_SCENE.instantiate() as Node3D
	if cutter_l:
		entities.add_child(cutter_l)
		cutter_l.position = Vector3(-2.2, 0.1, -32.0)
		if "forward_speed" in cutter_l:
			cutter_l.set("forward_speed", rush_speed * 0.8)

	var cutter_r: Node3D = CUTTER_SCENE.instantiate() as Node3D
	if cutter_r:
		entities.add_child(cutter_r)
		cutter_r.position = Vector3(2.2, 0.1, -32.0)
		if "forward_speed" in cutter_r:
			cutter_r.set("forward_speed", rush_speed * 0.8)

	for flank_x: float in [-0.8, 0.8]:
		var escort: EnemyMob = ENEMY_MOB_SCENE.instantiate() as EnemyMob
		if escort:
			entities.add_child(escort)
			escort.position = Vector3(flank_x, 0.1, -34.0)
			if escort.has_method("apply_enemy_data"):
				escort.call("apply_enemy_data", RAIDER_DATA)
			escort.max_hp = swarm_hp
			escort.forward_speed = rush_speed

	# ── Wave 4: Final Breakthrough Swarm (Z: -41 to -47) ──
	var wave_4_lanes: Array[float] = [-3.4, -2.5, -1.7, -0.8, 0.0, 0.8, 1.7, 2.5, 3.4]
	for lx: float in wave_4_lanes:
		var mob: EnemyMob = ENEMY_MOB_SCENE.instantiate() as EnemyMob
		if mob:
			entities.add_child(mob)
			mob.position = Vector3(lx, 0.1, randf_range(-42.0, -46.5))
			if mob.has_method("apply_enemy_data"):
				mob.call("apply_enemy_data", ROWER_DATA)
			mob.max_hp = swarm_hp
			mob.forward_speed = rush_speed + 0.6
			mob.doubloons_drop = 1

func _spawn_gatekeeper_wave(entities: Node, _cur_lvl: int) -> void:
	var gunner_l: Node3D = GUNNER_SCENE.instantiate() as Node3D
	if gunner_l:
		entities.add_child(gunner_l)
		gunner_l.position = Vector3(-2.2, 0.1, -28.0)
		gunner_l.set("is_gunner_vanguard", true)
		gunner_l.set("can_shoot", true)

	var gunner_r: Node3D = GUNNER_SCENE.instantiate() as Node3D
	if gunner_r:
		entities.add_child(gunner_r)
		gunner_r.position = Vector3(2.2, 0.1, -28.0)
		gunner_r.set("is_gunner_vanguard", true)
		gunner_r.set("can_shoot", true)
