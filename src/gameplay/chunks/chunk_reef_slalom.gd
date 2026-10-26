class_name ChunkReefSlalom
extends BaseTrackChunk

## Custom controller for chunk_reef_slalom.
## Spawns escort enemy craft on early levels and adapts enemy vessels to the active biome.

const ENEMY_SCENE: PackedScene = preload("res://src/gameplay/enemies/enemy_mob.tscn")
const ROWER_DATA: Resource = preload("res://src/data/resources/enemy_vessels/skeleton_rower.tres")
const RAIDER_DATA: Resource = preload("res://src/data/resources/enemy_vessels/raider_skiff.tres")
const GHOST_DATA: Resource = preload("res://src/data/resources/enemy_vessels/ghost_sloop.tres")
const GRAVE_SKIFF_SCENE: PackedScene = preload("res://src/gameplay/enemies/enemy_grave_skiff.tscn")
const BRIMSTONE_RAFT_SCENE: PackedScene = preload("res://src/gameplay/enemies/enemy_brimstone_raft.tscn")
const SEA_MINE_SCENE: PackedScene = preload("res://src/gameplay/obstacles/hazard_sea_mine.tscn")
const BIOGAS_POD_SCENE: PackedScene = preload("res://src/gameplay/obstacles/hazard_biogas_pod.tscn")
const THERMAL_GEYSER_SCENE: PackedScene = preload("res://src/gameplay/obstacles/hazard_thermal_geyser.tscn")

func _ready() -> void:
	super._ready()
	_apply_level_tuning()

var _slalom_tuning_applied: bool = false

func _apply_level_tuning() -> void:
	if _slalom_tuning_applied:
		return
	_slalom_tuning_applied = true
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

	if is_bombard_or_obstacle_level(cur_lvl):
		_spawn_bombard_slalom_obstacles(cur_lvl)
	else:
		_spawn_continuous_slalom_enemies(cur_lvl)

func _spawn_bombard_slalom_obstacles(cur_lvl: int) -> void:
	var entities: Node = get_node_or_null("Entities")
	if not entities:
		return
	var active_biome: String = resolve_chunk_biome(cur_lvl)
	var hazard_slots: Array[Vector3] = [
		Vector3(-2.2, 0.0, -8.5),
		Vector3(2.4, 0.0, -15.5),
		Vector3(-1.8, 0.0, -28.0),
		Vector3(2.2, 0.0, -35.5),
		Vector3(-2.4, 0.0, -42.5),
	]
	for idx: int in range(hazard_slots.size()):
		var hpos: Vector3 = hazard_slots[idx]
		if active_biome == "bayou" and idx % 2 == 1 and BIOGAS_POD_SCENE:
			var pod: Node3D = BIOGAS_POD_SCENE.instantiate() as Node3D
			if pod:
				pod.name = "SlalomBiogasHazard_%d" % (idx + 1)
				entities.add_child(pod)
				pod.position = Vector3(hpos.x, 0.05, hpos.z)
		elif active_biome == "brimstone" and idx % 2 == 1 and THERMAL_GEYSER_SCENE:
			var geyser: Node3D = THERMAL_GEYSER_SCENE.instantiate() as Node3D
			if geyser:
				geyser.name = "SlalomGeyserHazard_%d" % (idx + 1)
				entities.add_child(geyser)
				geyser.position = hpos
		elif SEA_MINE_SCENE:
			var mine: Node3D = SEA_MINE_SCENE.instantiate() as Node3D
			if mine:
				mine.name = "SlalomMineHazard_%d" % (idx + 1)
				entities.add_child(mine)
				mine.position = hpos

func _spawn_continuous_slalom_enemies(cur_lvl: int) -> void:
	var entities: Node = get_node_or_null("Entities")
	if not entities or not ENEMY_SCENE:
		return
	var active_biome: String = resolve_chunk_biome(cur_lvl)
	var extra_waves: Array[Vector3] = [
		Vector3(-2.0, 0.1, -4.5),
		Vector3(2.0, 0.1, -6.5),
		Vector3(0.0, 0.1, -10.5),
		Vector3(-2.4, 0.1, -19.5),
		Vector3(2.4, 0.1, -21.5),
		Vector3(-1.6, 0.1, -29.5),
		Vector3(1.8, 0.1, -36.5),
		Vector3(-2.2, 0.1, -43.0),
		Vector3(2.2, 0.1, -44.5),
	]
	var mob_hp: int = 2 if cur_lvl <= 3 else (3 if cur_lvl <= 5 else (5 if cur_lvl <= 10 else 7))
	var mob_spd: float = 1.8 if cur_lvl <= 3 else 2.5
	for i: int in range(extra_waves.size()):
		if active_biome == "bayou" and i % 3 == 1 and GRAVE_SKIFF_SCENE:
			var g_skiff: Area3D = GRAVE_SKIFF_SCENE.instantiate() as Area3D
			if g_skiff:
				g_skiff.name = "SlalomWaveSkiff_%d" % (i + 1)
				entities.add_child(g_skiff)
				g_skiff.position = extra_waves[i]
				g_skiff.set("max_hp", mob_hp + 1)
				g_skiff.set("current_hp", mob_hp + 1)
				g_skiff.set("forward_speed", mob_spd)
				g_skiff.set("doubloons_drop", 0)
			continue
		elif active_biome == "brimstone" and i % 3 == 1 and BRIMSTONE_RAFT_SCENE:
			var b_raft: Area3D = BRIMSTONE_RAFT_SCENE.instantiate() as Area3D
			if b_raft:
				b_raft.name = "SlalomWaveRaft_%d" % (i + 1)
				entities.add_child(b_raft)
				b_raft.position = extra_waves[i]
				b_raft.set("max_hp", mob_hp + 1)
				b_raft.set("current_hp", mob_hp + 1)
				b_raft.set("forward_speed", mob_spd + 0.8)
				b_raft.set("doubloons_drop", 0)
			continue
		var mob: Area3D = ENEMY_SCENE.instantiate() as Area3D
		if mob:
			mob.name = "SlalomWaveMob_%d" % (i + 1)
			entities.add_child(mob)
			mob.position = extra_waves[i]
			var v_data: Resource = ROWER_DATA if (i % 2 == 0 or cur_lvl <= 3) else RAIDER_DATA
			if active_biome == "bayou" or active_biome == "brimstone":
				v_data = GHOST_DATA
			if mob.has_method("apply_enemy_data"):
				mob.call("apply_enemy_data", v_data)
			mob.set("max_hp", mob_hp)
			mob.set("current_hp", mob_hp)
			mob.set("forward_speed", mob_spd)
			mob.set("doubloons_drop", 0)

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
