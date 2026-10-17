class_name ChunkGunnerAmbush
extends BaseTrackChunk

## Custom controller for chunk_gunner_ambush.
## Spawns escort enemy craft on early levels to provide balanced density and combat engagement.

const ENEMY_SCENE: PackedScene = preload("res://src/gameplay/enemies/enemy_mob.tscn")
const ROWER_DATA: Resource = preload("res://src/data/resources/enemy_vessels/skeleton_rower.tres")

func _ready() -> void:
	super._ready()
	_apply_level_tuning()

func _apply_level_tuning() -> void:
	var cur_lvl: int = 1
	var gs: Node = get_node_or_null("/root/GameState")
	if gs and "current_level" in gs:
		cur_lvl = int(gs.get("current_level"))
	# Skip extra ambush rowers if chunk is opener, at start of track, or level 1
	if chunk_id == "opener_ambush" or position.z >= -10.0 or cur_lvl <= 1:
		return
	_spawn_escort_rowers(cur_lvl)

func _spawn_escort_rowers(cur_lvl: int) -> void:
	var entities: Node = get_node_or_null("Entities")
	if not entities:
		return
	var spawns: Array[Vector3] = [
		Vector3(-1.8, 0.1, -28.0),
		Vector3(1.8, 0.1, -32.0),
		Vector3(-2.2, 0.1, -36.0),
		Vector3(2.2, 0.1, -40.0),
		Vector3(0.0, 0.1, -44.0),
	]
	var count: int = 3 if cur_lvl <= 3 else (4 if cur_lvl <= 10 else 5)
	for i: int in range(count):
		var rower: Area3D = ENEMY_SCENE.instantiate() as Area3D
		if not rower:
			continue
		rower.name = "AmbushRower_%d" % (i + 1)
		entities.add_child(rower)
		rower.position = spawns[i]
		if rower.has_method("apply_enemy_data"):
			rower.call("apply_enemy_data", ROWER_DATA)
		rower.set("max_hp", 2 if cur_lvl <= 5 else 3)
		rower.set("forward_speed", 2.2 + minf(1.2, float(cur_lvl) * 0.05))
		rower.set("doubloons_drop", 1)
