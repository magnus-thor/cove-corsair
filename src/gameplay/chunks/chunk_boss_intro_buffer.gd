class_name ChunkBossIntroBuffer
extends BaseTrackChunk

## Custom controller for chunk_boss_intro_buffer.
## Converts the pre-boss transition into a high-octane Vanguard Swarm,
## eliminating downtime before the boss encounter with waves of rushing rowers and skiffs.

const ENEMY_SCENE: PackedScene = preload("res://src/gameplay/enemies/enemy_mob.tscn")
const ROWER_DATA: Resource = preload("res://src/data/resources/enemy_vessels/skeleton_rower.tres")
const SKIFF_DATA: Resource = preload("res://src/data/resources/enemy_vessels/raider_skiff.tres")

func _ready() -> void:
	super._ready()
	_spawn_pre_boss_swarm()

func _spawn_pre_boss_swarm() -> void:
	var entities: Node = get_node_or_null("Entities")
	if not entities:
		return
		
	var spawns: Array[Dictionary] = [
		{"pos": Vector3(-2.4, 0.1, -10.0), "data": ROWER_DATA, "hp": 2, "speed": 2.5},
		{"pos": Vector3(2.4, 0.1, -10.0), "data": ROWER_DATA, "hp": 2, "speed": 2.5},
		{"pos": Vector3(-3.2, 0.1, -18.0), "data": SKIFF_DATA, "hp": 2, "speed": 3.0},
		{"pos": Vector3(0.0, 0.1, -18.0), "data": ROWER_DATA, "hp": 2, "speed": 2.2},
		{"pos": Vector3(3.2, 0.1, -18.0), "data": SKIFF_DATA, "hp": 2, "speed": 3.0},
		{"pos": Vector3(-1.8, 0.1, -26.0), "data": SKIFF_DATA, "hp": 3, "speed": 3.2},
		{"pos": Vector3(1.8, 0.1, -26.0), "data": SKIFF_DATA, "hp": 3, "speed": 3.2},
		{"pos": Vector3(-3.0, 0.1, -34.0), "data": ROWER_DATA, "hp": 2, "speed": 2.6},
		{"pos": Vector3(-1.0, 0.1, -34.0), "data": ROWER_DATA, "hp": 2, "speed": 2.6},
		{"pos": Vector3(1.0, 0.1, -34.0), "data": ROWER_DATA, "hp": 2, "speed": 2.6},
		{"pos": Vector3(3.0, 0.1, -34.0), "data": ROWER_DATA, "hp": 2, "speed": 2.6},
		{"pos": Vector3(-2.0, 0.1, -42.0), "data": SKIFF_DATA, "hp": 2, "speed": 3.4},
		{"pos": Vector3(0.0, 0.1, -42.0), "data": ROWER_DATA, "hp": 3, "speed": 2.5},
		{"pos": Vector3(2.0, 0.1, -42.0), "data": SKIFF_DATA, "hp": 2, "speed": 3.4},
	]
	
	for i: int in range(spawns.size()):
		var s: Dictionary = spawns[i]
		var enemy: Area3D = ENEMY_SCENE.instantiate() as Area3D
		if not enemy:
			continue
		enemy.name = "PreBossMob_%d" % (i + 1)
		entities.add_child(enemy)
		enemy.position = s["pos"] as Vector3
		if enemy.has_method("apply_enemy_data"):
			enemy.call("apply_enemy_data", s["data"] as Resource)
		enemy.set("max_hp", s["hp"] as int)
		enemy.set("current_hp", s["hp"] as int)
		enemy.set("forward_speed", s["speed"] as float)
		enemy.set("doubloons_drop", 1)
