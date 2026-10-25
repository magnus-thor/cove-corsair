class_name ChunkFodderSwarm
extends BaseTrackChunk

## Dynamic biome- and level-varied controller for chunk_fodder_swarm.
## Varies fodder wave formations across campaign levels so no two consecutive swarm levels
## repeat the same 5-ship V-formation, and injects biome-specific lead/flank threats.

const ENEMY_MOB_SCENE: PackedScene = preload("res://src/gameplay/enemies/enemy_mob.tscn")
const FODDER_SKIFF_SCENE: PackedScene = preload("res://src/gameplay/enemies/enemy_fodder_skiff.tscn")
const GRAVE_SKIFF_SCENE: PackedScene = preload("res://src/gameplay/enemies/enemy_grave_skiff.tscn")
const BRIMSTONE_RAFT_SCENE: PackedScene = preload("res://src/gameplay/enemies/enemy_brimstone_raft.tscn")
const IRON_GUNNER_SCENE: PackedScene = preload("res://src/gameplay/enemies/enemy_iron_gunner.tscn")
const BIOGAS_POD_SCENE: PackedScene = preload("res://src/gameplay/obstacles/hazard_biogas_pod.tscn")
const THERMAL_GEYSER_SCENE: PackedScene = preload("res://src/gameplay/obstacles/hazard_thermal_geyser.tscn")

const ROWER_DATA: Resource = preload("res://src/data/resources/enemy_vessels/skeleton_rower.tres")
const RAIDER_DATA: Resource = preload("res://src/data/resources/enemy_vessels/raider_skiff.tres")
const GHOST_DATA: Resource = preload("res://src/data/resources/enemy_vessels/ghost_sloop.tres")
const ELITE_IRONCLAD_DATA: Resource = preload("res://src/data/resources/enemy_vessels/enemy_elite_ironclad.tres")

func _ready() -> void:
	super._ready()
	chunk_id = "fodder_swarm"
	_apply_level_and_biome_swarm_variation()

var _swarm_variation_applied: bool = false

func _apply_level_and_biome_swarm_variation() -> void:
	if _swarm_variation_applied:
		return
	_swarm_variation_applied = true
	var entities: Node = get_node_or_null("Entities")
	if not entities:
		return

	var cur_lvl: int = 1
	var gs: Node = get_node_or_null("/root/GameState")
	if gs and "current_level" in gs:
		cur_lvl = int(gs.get("current_level"))

	var active_biome: String = resolve_chunk_biome(cur_lvl)
	var variant: int = posmod(cur_lvl + int(cur_lvl / 5), 4)

	# Spawn 6 additional fodder skiffs so the 50m chunk (Z = -4.0 to -48.0) has zero empty gap at the start or end
	if FODDER_SKIFF_SCENE:
		for extra_i: int in range(6):
			var extra_fodder: Area3D = FODDER_SKIFF_SCENE.instantiate() as Area3D
			if extra_fodder:
				extra_fodder.name = "Fodder_Extra_%d" % (extra_i + 1)
				entities.add_child(extra_fodder)
				extra_fodder.set("doubloons_drop", 0 if cur_lvl <= 1 else 1)

	var fodder_nodes: Array[Node3D] = []
	for child: Node in entities.get_children():
		if child is Node3D and child.is_in_group("fodder"):
			fodder_nodes.append(child as Node3D)

	# Rearrange all fodder skiffs across Z = -4.0 to -48.0 (eliminating the old 0 to -18m empty gap)
	for idx: int in range(fodder_nodes.size()):
		var skiff: Node3D = fodder_nodes[idx]
		match variant:
			0:
				# Variant 0: Twin Parallel Columns + Staggered Center Surge (Z = -4.5 to -47.5)
				var col_x: float = (-2.8 if idx % 2 == 0 else 2.8) if idx < 14 else (-1.4 + float(idx % 3) * 1.4)
				var row_z: float = -4.5 - float(int(idx / 2)) * 3.5
				skiff.position = Vector3(col_x, 0.1, clampf(row_z, -48.0, -4.0))
			1:
				# Variant 1 (e.g. Level 21): Diagonal Echelon Sweep (Port-to-Starboard Slash + Reverse Slash)
				var wave_group: int = int(idx / 7)
				var pos_in_wave: int = idx % 7
				var dir_sign: float = 1.0 if wave_group % 2 == 0 else -1.0
				var ech_x: float = dir_sign * (-3.6 + float(pos_in_wave) * 1.2)
				var ech_z: float = -4.5 - float(wave_group) * 11.5 - float(pos_in_wave) * 1.5
				skiff.position = Vector3(clampf(ech_x, -3.8, 3.8), 0.1, clampf(ech_z, -48.0, -4.0))
			2:
				# Variant 2 (e.g. Level 43): Outer Pincer Jaws + Hollow Center Ambush
				var side_sign: float = -1.0 if idx % 2 == 0 else 1.0
				var ring_step: int = int(idx / 2)
				var pincer_x: float = side_sign * (3.6 - float(ring_step % 3) * 0.9)
				var pincer_z: float = -4.5 - float(ring_step) * 3.5
				skiff.position = Vector3(pincer_x, 0.1, clampf(pincer_z, -48.0, -4.0))
			_:
				# Variant 3: Diamond Cluster Waves
				var cluster: int = int(idx / 5)
				var slot: int = idx % 5
				var diamond_offsets: Array[Vector3] = [
					Vector3(0.0, 0.1, 0.0),
					Vector3(-1.8, 0.1, -2.0),
					Vector3(1.8, 0.1, -2.0),
					Vector3(0.0, 0.1, -4.0),
					Vector3(-3.2 if cluster % 2 == 0 else 3.2, 0.1, -3.0),
				]
				var base_z: float = -4.5 - float(cluster) * 8.5
				var off: Vector3 = diamond_offsets[slot]
				skiff.position = Vector3(off.x, 0.1, clampf(base_z + off.z, -48.0, -4.0))

	# Add biome-specific escort leaders & hazards across both front and back of the chunk
	if active_biome == "bayou":
		var bayou_x_pair: Array[float] = [-2.4, 2.4]
		if variant % 2 != 0:
			bayou_x_pair = [-1.6, 1.6]
		for z_slot: float in [-13.0, -27.0, -43.0]:
			for gx: float in bayou_x_pair:
				var g_mob: EnemyMob = ENEMY_MOB_SCENE.instantiate() as EnemyMob
				if g_mob:
					entities.add_child(g_mob)
					g_mob.position = Vector3(gx, 0.1, z_slot)
					if g_mob.has_method("apply_enemy_data"):
						g_mob.call("apply_enemy_data", GHOST_DATA)
					g_mob.max_hp = 6 + int((cur_lvl - 15) * 0.4)
					g_mob.current_hp = g_mob.max_hp
					g_mob.forward_speed = 2.6
					g_mob.doubloons_drop = 0
		if GRAVE_SKIFF_SCENE:
			for g_z: float in [-19.0, -36.0]:
				var g_skiff: Area3D = GRAVE_SKIFF_SCENE.instantiate() as Area3D
				if g_skiff:
					entities.add_child(g_skiff)
					g_skiff.position = Vector3(0.0 if variant % 2 == 1 else -2.8, 0.1, g_z)
					g_skiff.set("doubloons_drop", 0)
		if BIOGAS_POD_SCENE:
			var pod: Node3D = BIOGAS_POD_SCENE.instantiate() as Node3D
			if pod:
				entities.add_child(pod)
				pod.position = Vector3(1.8 if variant % 2 == 0 else -1.8, 0.05, -33.0)
	elif active_biome == "brimstone":
		var brim_x_pair: Array[float] = [-2.6, 2.6]
		if variant % 2 != 0:
			brim_x_pair = [-1.5, 1.5]
		for z_slot: float in [-12.0, -26.0, -42.0]:
			for rx: float in brim_x_pair:
				if BRIMSTONE_RAFT_SCENE:
					var b_raft: Area3D = BRIMSTONE_RAFT_SCENE.instantiate() as Area3D
					if b_raft:
						entities.add_child(b_raft)
						b_raft.position = Vector3(rx, 0.1, z_slot)
						b_raft.set("doubloons_drop", 0)
		if IRON_GUNNER_SCENE:
			for g_z: float in [-19.0, -37.0]:
				var i_gunner: Area3D = IRON_GUNNER_SCENE.instantiate() as Area3D
				if i_gunner:
					entities.add_child(i_gunner)
					i_gunner.position = Vector3(0.0 if variant % 2 == 0 else 2.4, 0.1, g_z)
					i_gunner.set("doubloons_drop", 0)
		if THERMAL_GEYSER_SCENE:
			var geyser: Node3D = THERMAL_GEYSER_SCENE.instantiate() as Node3D
			if geyser:
				entities.add_child(geyser)
				geyser.position = Vector3(-1.8 if variant % 2 == 0 else 1.8, 0.0, -32.0)
	else:
		# Tropical levels: Raider/Rower swarm leaders at front (-12m) and rear (-36m)
		var lead_hp: int = 2 if cur_lvl <= 3 else (3 if cur_lvl <= 5 else 4)
		var lead_data: Resource = ROWER_DATA if cur_lvl <= 2 else RAIDER_DATA
		for l_z: float in [-12.0, -36.0]:
			var leader: EnemyMob = ENEMY_MOB_SCENE.instantiate() as EnemyMob
			if leader:
				entities.add_child(leader)
				leader.position = Vector3(0.0 if variant % 2 == 0 else -2.2, 0.1, l_z)
				if leader.has_method("apply_enemy_data"):
					leader.call("apply_enemy_data", lead_data)
				leader.max_hp = lead_hp
				leader.current_hp = lead_hp
				leader.forward_speed = 2.2 if cur_lvl <= 3 else 2.8
				leader.doubloons_drop = 0
