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
	var gs = get_node_or_null("/root/GameState")
	if gs and "current_level" in gs:
		cur_lvl = int(gs.current_level)
	if cur_lvl <= 3:
		_spawn_escort_rowers()

func _spawn_escort_rowers() -> void:
	var entities = get_node_or_null("Entities")
	if not entities:
		return
	var spawns = [
		Vector3(-1.5, 0.1, -18.0),
		Vector3(1.5, 0.1, -28.0),
		Vector3(0.0, 0.1, -44.0),
	]
	for i in range(spawns.size()):
		var rower = ENEMY_SCENE.instantiate() as Area3D
		rower.name = "AmbushRower_%d" % (i + 1)
		entities.add_child(rower)
		rower.position = spawns[i]
		if rower.has_method("apply_enemy_data"):
			rower.apply_enemy_data(ROWER_DATA)
		rower.max_hp = 2
		rower.current_hp = 2
		rower.forward_speed = 1.8
		rower.doubloons_drop = 1
