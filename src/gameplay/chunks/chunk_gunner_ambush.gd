class_name ChunkGunnerAmbush
extends BaseTrackChunk

## Custom controller for chunk_gunner_ambush.
## Spawns escort enemy craft on early levels to provide balanced density and combat engagement.

const ENEMY_SCENE: PackedScene = preload("res://src/gameplay/enemies/enemy_mob.tscn")
const GRAVE_SKIFF_SCENE: PackedScene = preload("res://src/gameplay/enemies/enemy_grave_skiff.tscn")
const ROWER_DATA: Resource = preload("res://src/data/resources/enemy_vessels/skeleton_rower.tres")
const RAIDER_DATA: Resource = preload("res://src/data/resources/enemy_vessels/raider_skiff.tres")
const GHOST_DATA: Resource = preload("res://src/data/resources/enemy_vessels/ghost_sloop.tres")
const ELITE_IRONCLAD_DATA: Resource = preload("res://src/data/resources/enemy_vessels/enemy_elite_ironclad.tres")

func _ready() -> void:
	super._ready()
	_apply_level_tuning()

var _ambush_tuning_applied: bool = false

func _apply_level_tuning() -> void:
	if _ambush_tuning_applied:
		return
	_ambush_tuning_applied = true
	var cur_lvl: int = 1
	var gs: Node = get_node_or_null("/root/GameState")
	if gs and "current_level" in gs:
		cur_lvl = int(gs.get("current_level"))
	# Skip extra ambush rowers if chunk is opener
	if chunk_id.begins_with("opener"):
		return
	_spawn_escort_rowers(cur_lvl)

func _spawn_escort_rowers(cur_lvl: int) -> void:
	var entities: Node = get_node_or_null("Entities")
	if not entities:
		return
	var active_biome: String = resolve_chunk_biome(cur_lvl)
	var variant: int = posmod(cur_lvl, 4)
	var spawns: Array[Vector3] = [
		Vector3(-2.0, 0.1, -4.5),
		Vector3(2.0, 0.1, -8.0),
		Vector3(-1.8, 0.1, -20.0),
		Vector3(1.8, 0.1, -28.0),
		Vector3(-2.2, 0.1, -36.0),
		Vector3(2.2, 0.1, -41.5),
		Vector3(-1.6, 0.1, -46.5),
		Vector3(1.6, 0.1, -48.0),
	]
	if variant == 1:
		spawns = [
			Vector3(2.0, 0.1, -4.5),
			Vector3(-2.0, 0.1, -8.0),
			Vector3(1.8, 0.1, -20.0),
			Vector3(-1.8, 0.1, -28.0),
			Vector3(2.4, 0.1, -35.0),
			Vector3(-2.4, 0.1, -41.0),
			Vector3(1.5, 0.1, -46.0),
			Vector3(-1.5, 0.1, -48.0),
		]
	elif variant == 2:
		spawns = [
			Vector3(-2.4, 0.1, -4.5),
			Vector3(2.4, 0.1, -8.0),
			Vector3(0.0, 0.1, -20.0),
			Vector3(-2.6, 0.1, -28.0),
			Vector3(2.6, 0.1, -35.0),
			Vector3(-1.4, 0.1, -41.5),
			Vector3(1.4, 0.1, -46.0),
			Vector3(0.0, 0.1, -48.0),
		]
	elif variant == 3:
		spawns = [
			Vector3(0.0, 0.1, -4.5),
			Vector3(-2.2, 0.1, -8.5),
			Vector3(2.2, 0.1, -19.5),
			Vector3(-2.0, 0.1, -28.5),
			Vector3(2.0, 0.1, -35.0),
			Vector3(-3.0, 0.1, -41.5),
			Vector3(3.0, 0.1, -45.5),
			Vector3(0.0, 0.1, -48.0),
		]

	var reward_count: int = 2 if cur_lvl <= 1 else (3 if cur_lvl <= 3 else (4 if cur_lvl <= 10 else 5))
	for i: int in range(spawns.size()):
		var drop_coins: int = 1 if i < reward_count else 0
		if active_biome == "bayou" and i % 2 == 1 and GRAVE_SKIFF_SCENE:
			var g_skiff: Area3D = GRAVE_SKIFF_SCENE.instantiate() as Area3D
			if g_skiff:
				g_skiff.name = "AmbushGraveSkiff_%d" % (i + 1)
				entities.add_child(g_skiff)
				g_skiff.position = spawns[i]
				g_skiff.set("max_hp", 4)
				g_skiff.set("current_hp", 4)
				g_skiff.set("forward_speed", 2.4 + minf(1.2, float(cur_lvl) * 0.04))
				g_skiff.set("doubloons_drop", drop_coins)
			continue

		var rower: Area3D = ENEMY_SCENE.instantiate() as Area3D
		if not rower:
			continue
		rower.name = "AmbushRower_%d" % (i + 1)
		entities.add_child(rower)
		rower.position = spawns[i]
		var vessel_res: Resource = ROWER_DATA if (i % 2 == 0 or cur_lvl <= 4) else RAIDER_DATA
		if active_biome == "bayou":
			vessel_res = GHOST_DATA
		elif active_biome == "brimstone":
			vessel_res = ELITE_IRONCLAD_DATA if i == 0 else GHOST_DATA
		if rower.has_method("apply_enemy_data"):
			rower.call("apply_enemy_data", vessel_res)
		rower.set("max_hp", 2 if cur_lvl <= 5 else 3)
		rower.set("current_hp", 2 if cur_lvl <= 5 else 3)
		rower.set("forward_speed", 2.2 + minf(1.2, float(cur_lvl) * 0.05))
		rower.set("doubloons_drop", drop_coins)
