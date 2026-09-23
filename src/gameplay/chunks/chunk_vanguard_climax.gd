class_name ChunkVanguardClimax
extends BaseTrackChunk

## Climax combat chunk with dynamic multi-wave enemy escalation.
## Ensures the final stretch of every level is densely packed with enemies
## and destructibles so players never sail into empty air.

const ENEMY_MOB_SCENE: PackedScene = preload("res://src/gameplay/enemies/enemy_mob.tscn")
const CUTTER_SCENE: PackedScene = preload("res://src/gameplay/enemies/enemy_tide_cutter.tscn")
const BARREL_SCENE: PackedScene = preload("res://src/gameplay/obstacles/destructible_barrel.tscn")
const ROWER_DATA: Resource = preload("res://src/data/resources/enemy_vessels/skeleton_rower.tres")

const GUNNER_SCENE: PackedScene = preload("res://src/gameplay/enemies/enemy_iron_gunner.tscn")

func _ready() -> void:
	super._ready()
	chunk_id = "vanguard_climax"
	_spawn_dynamic_climax_wave()

func _spawn_dynamic_climax_wave() -> void:
	var entities: Node = get_node_or_null("Entities")
	if not entities:
		return

	var cur_lvl: int = 1
	var gs: Node = get_node_or_null("/root/GameState")
	if gs and "current_level" in gs:
		cur_lvl = int(gs.get("current_level"))

	# Gatekeeper reinforcement: on levels 8, 15, 22, 30, 37, 44, add armored gunner vanguard
	if cur_lvl in [8, 15, 22, 30, 37, 44]:
		_spawn_gatekeeper_wave(entities, cur_lvl)

	# Multi-wave spawns to ensure dense, continuous combat
	# Wave 1: Front Skirmish (Z: -8 to -16)
	var wave_1_lanes: Array[float] = [-2.2, -0.8, 0.8, 2.2]
	for lx: float in wave_1_lanes:
		var mob: Area3D = ENEMY_MOB_SCENE.instantiate() as Area3D
		entities.add_child(mob)
		mob.position = Vector3(lx, 0.1, randf_range(-8.0, -12.0))
		if mob.has_method("apply_enemy_data"):
			mob.call("apply_enemy_data", ROWER_DATA)
		mob.set("max_hp", 2 if cur_lvl <= 5 else 4)
		mob.set("current_hp", 2 if cur_lvl <= 5 else 4)
		mob.set("forward_speed", 1.4)
		mob.set("doubloons_drop", 1)

	# Wave 2: Flanking Fast Cutters / Gunner Escorts (Z: -28 to -36)
	var cutter_l: Area3D = CUTTER_SCENE.instantiate() as Area3D
	entities.add_child(cutter_l)
	cutter_l.position = Vector3(-1.8, 0.1, -30.0)

	var cutter_r: Area3D = CUTTER_SCENE.instantiate() as Area3D
	entities.add_child(cutter_r)
	cutter_r.position = Vector3(1.8, 0.1, -30.0)

	# Wave 3: Destructible Gold Kegs / Obstacles for Overdrive Doubloon frenzy (Z: -38 to -44)
	var keg_lanes: Array[float] = [-1.5, 0.0, 1.5]
	for kx: float in keg_lanes:
		var keg: Area3D = BARREL_SCENE.instantiate() as Area3D
		entities.add_child(keg)
		keg.position = Vector3(kx, 0.05, -40.0)
		if "obstacle_type" in keg:
			keg.set("obstacle_type", 2) # Explosive Keg

func _spawn_gatekeeper_wave(entities: Node, _cur_lvl: int) -> void:
	var gunner_l: Area3D = GUNNER_SCENE.instantiate() as Area3D
	entities.add_child(gunner_l)
	gunner_l.position = Vector3(-2.2, 0.1, -22.0)
	gunner_l.set("is_gunner_vanguard", true)
	gunner_l.set("can_shoot", true)

	var gunner_r: Area3D = GUNNER_SCENE.instantiate() as Area3D
	entities.add_child(gunner_r)
	gunner_r.position = Vector3(2.2, 0.1, -22.0)
	gunner_r.set("is_gunner_vanguard", true)
	gunner_r.set("can_shoot", true)
