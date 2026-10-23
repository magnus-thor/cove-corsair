class_name ChunkReefSlalom
extends BaseTrackChunk

## Custom controller for chunk_reef_slalom.
## Spawns escort enemy craft on early levels and adapts enemy vessels to the active biome.

const ENEMY_SCENE: PackedScene = preload("res://src/gameplay/enemies/enemy_mob.tscn")
const ROWER_DATA: Resource = preload("res://src/data/resources/enemy_vessels/skeleton_rower.tres")
const GHOST_DATA: Resource = preload("res://src/data/resources/enemy_vessels/ghost_sloop.tres")
const GRAVE_SKIFF_SCENE: PackedScene = preload("res://src/gameplay/enemies/enemy_grave_skiff.tscn")
const BRIMSTONE_RAFT_SCENE: PackedScene = preload("res://src/gameplay/enemies/enemy_brimstone_raft.tscn")

func _ready() -> void:
	super._ready()
	_apply_level_tuning()

func _apply_level_tuning() -> void:
	# Skip extra close escort rowers if chunk is an opener
	if chunk_id.begins_with("opener"):
		return
	var cur_lvl: int = 1
	var gs: Node = get_node_or_null("/root/GameState")
	if gs and "current_level" in gs:
		cur_lvl = int(gs.get("current_level"))
	if cur_lvl <= 5:
		_spawn_escort_rowers()
	else:
		_apply_biome_mob_variation(cur_lvl)

func _spawn_escort_rowers() -> void:
	var entities: Node = get_node_or_null("Entities")
	if not entities:
		return
	var cur_lvl: int = 1
	var gs: Node = get_node_or_null("/root/GameState")
	if gs and "current_level" in gs:
		cur_lvl = int(gs.get("current_level"))

	var spawns: Array[Vector3] = []
	if cur_lvl <= 2:
		# Paced early tutorial encounter: give player 3+ seconds to react, avoid instant ramming
		spawns = [
			Vector3(1.8, 0.1, -24.0),
			Vector3(-1.2, 0.1, -38.0),
		]
	else:
		spawns = [
			Vector3(-1.8, 0.1, -18.0),
			Vector3(1.8, 0.1, -26.0),
			Vector3(-1.2, 0.1, -34.0),
			Vector3(1.5, 0.1, -43.0),
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

func _apply_biome_mob_variation(cur_lvl: int) -> void:
	var entities: Node = get_node_or_null("Entities")
	if not entities:
		return
	if cur_lvl >= 16 and cur_lvl <= 30:
		# Bayou biome: convert generic EnemyMob rowers to Ghost Sloops
		for child: Node in entities.get_children():
			if child is EnemyMob and child.has_method("apply_enemy_data"):
				child.call("apply_enemy_data", GHOST_DATA)
	elif cur_lvl >= 31:
		# Brimstone biome: spawn Brimstone Raft escorts alongside volcanic reefs
		var raft: Area3D = BRIMSTONE_RAFT_SCENE.instantiate() as Area3D
		if raft:
			raft.name = "SlalomBrimstoneEscort"
			entities.add_child(raft)
			raft.position = Vector3(-1.6 if (cur_lvl % 2 == 0) else 1.6, 0.1, -32.0)
