class_name ChunkReefSlalom
extends BaseTrackChunk

## Custom controller for chunk_reef_slalom.
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
	if cur_lvl <= 5:
		_spawn_escort_rowers()

func _spawn_escort_rowers() -> void:
	var entities: Node = get_node_or_null("Entities")
	if not entities:
		return
	var spawns: Array[Vector3] = [
		Vector3(-1.8, 0.1, -12.0),
		Vector3(1.8, 0.1, -18.0),
		Vector3(-1.2, 0.1, -30.0),
		Vector3(1.5, 0.1, -38.0),
	]
	for i: int in range(spawns.size()):
		var rower: Area3D = ENEMY_SCENE.instantiate() as Area3D
		rower.name = "EscortRower_%d" % (i + 1)
		entities.add_child(rower)
		rower.position = spawns[i]
		if rower.has_method("apply_enemy_data"):
			rower.call("apply_enemy_data", ROWER_DATA)
		rower.set("max_hp", 2)
		rower.set("current_hp", 2)
		rower.set("forward_speed", 1.6)
		rower.set("doubloons_drop", 1)
