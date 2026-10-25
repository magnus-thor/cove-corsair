class_name ChunkBossIntroBuffer
extends BaseTrackChunk

## Custom controller for chunk_boss_intro_buffer.
## Converts the pre-boss transition into a high-octane Vanguard Swarm,
## eliminating downtime before the boss encounter with waves of rushing rowers and skiffs.

const ENEMY_SCENE: PackedScene = preload("res://src/gameplay/enemies/enemy_mob.tscn")
const ROWER_DATA: Resource = preload("res://src/data/resources/enemy_vessels/skeleton_rower.tres")
const SKIFF_DATA: Resource = preload("res://src/data/resources/enemy_vessels/raider_skiff.tres")
const GHOST_DATA: Resource = preload("res://src/data/resources/enemy_vessels/ghost_sloop.tres")
const IRONCLAD_DATA: Resource = preload("res://src/data/resources/enemy_vessels/enemy_elite_ironclad.tres")

func _ready() -> void:
	super._ready()
	_spawn_pre_boss_swarm()

func _spawn_pre_boss_swarm() -> void:
	var entities: Node = get_node_or_null("Entities")
	if not entities:
		return

	var cur_lvl: int = 1
	var gs: Node = get_node_or_null("/root/GameState")
	if gs and "current_level" in gs:
		cur_lvl = int(gs.get("current_level"))

	var active_biome: String = resolve_chunk_biome(cur_lvl)
	var primary_data: Resource = ROWER_DATA
	var secondary_data: Resource = SKIFF_DATA
	if active_biome == "bayou":
		primary_data = GHOST_DATA
		secondary_data = SKIFF_DATA
	elif active_biome == "brimstone":
		primary_data = GHOST_DATA
		secondary_data = IRONCLAD_DATA

	var base_hp: int = 2 if cur_lvl <= 5 else (4 if cur_lvl <= 15 else (6 if cur_lvl <= 30 else 8))
		
	var spawns: Array[Dictionary] = [
		{"pos": Vector3(-2.6, 0.1, -4.5), "data": primary_data, "hp": base_hp, "speed": 2.6},
		{"pos": Vector3(0.0, 0.1, -5.5), "data": secondary_data, "hp": base_hp, "speed": 2.8},
		{"pos": Vector3(2.6, 0.1, -4.5), "data": primary_data, "hp": base_hp, "speed": 2.6},
		{"pos": Vector3(-3.2, 0.1, -11.5), "data": secondary_data, "hp": base_hp, "speed": 3.0},
		{"pos": Vector3(-1.1, 0.1, -12.5), "data": primary_data, "hp": base_hp, "speed": 2.6},
		{"pos": Vector3(1.1, 0.1, -12.5), "data": primary_data, "hp": base_hp, "speed": 2.6},
		{"pos": Vector3(3.2, 0.1, -11.5), "data": secondary_data, "hp": base_hp, "speed": 3.0},
		{"pos": Vector3(-2.4, 0.1, -19.5), "data": secondary_data, "hp": base_hp + 1, "speed": 3.2},
		{"pos": Vector3(0.0, 0.1, -20.5), "data": primary_data, "hp": base_hp, "speed": 2.8},
		{"pos": Vector3(2.4, 0.1, -19.5), "data": secondary_data, "hp": base_hp + 1, "speed": 3.2},
		{"pos": Vector3(-3.2, 0.1, -27.5), "data": primary_data, "hp": base_hp, "speed": 2.8},
		{"pos": Vector3(-1.2, 0.1, -28.5), "data": secondary_data, "hp": base_hp + 1, "speed": 3.1},
		{"pos": Vector3(1.2, 0.1, -28.5), "data": secondary_data, "hp": base_hp + 1, "speed": 3.1},
		{"pos": Vector3(3.2, 0.1, -27.5), "data": primary_data, "hp": base_hp, "speed": 2.8},
		{"pos": Vector3(-2.8, 0.1, -35.5), "data": primary_data, "hp": base_hp, "speed": 2.9},
		{"pos": Vector3(-0.9, 0.1, -36.5), "data": primary_data, "hp": base_hp, "speed": 2.9},
		{"pos": Vector3(0.9, 0.1, -36.5), "data": primary_data, "hp": base_hp, "speed": 2.9},
		{"pos": Vector3(2.8, 0.1, -35.5), "data": primary_data, "hp": base_hp, "speed": 2.9},
		{"pos": Vector3(-3.0, 0.1, -43.5), "data": secondary_data, "hp": base_hp, "speed": 3.4},
		{"pos": Vector3(-1.0, 0.1, -45.0), "data": primary_data, "hp": base_hp + 1, "speed": 3.0},
		{"pos": Vector3(1.0, 0.1, -45.0), "data": primary_data, "hp": base_hp + 1, "speed": 3.0},
		{"pos": Vector3(3.0, 0.1, -43.5), "data": secondary_data, "hp": base_hp, "speed": 3.4},
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
		enemy.set("doubloons_drop", 1 if i < 10 else 0)
