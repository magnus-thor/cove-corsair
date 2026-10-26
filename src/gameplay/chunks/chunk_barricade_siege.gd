class_name ChunkBarricadeSiege
extends BaseTrackChunk

## Custom controller for chunk_barricade_siege.
## Maintains continuous enemy waves before and after the barricade wall across all campaign levels.

const ENEMY_SCENE: PackedScene = preload("res://src/gameplay/enemies/enemy_mob.tscn")
const BARREL_SCENE: PackedScene = preload("res://src/gameplay/obstacles/destructible_barrel.tscn")
const ROWER_DATA: Resource = preload("res://src/data/resources/enemy_vessels/skeleton_rower.tres")
const RAIDER_DATA: Resource = preload("res://src/data/resources/enemy_vessels/raider_skiff.tres")
const TURTLE_DATA: Resource = preload("res://src/data/resources/enemy_vessels/turtle_raft.tres")
const GHOST_SLOOP_DATA: Resource = preload("res://src/data/resources/enemy_vessels/ghost_sloop.tres")
const ELITE_IRONCLAD_DATA: Resource = preload("res://src/data/resources/enemy_vessels/enemy_elite_ironclad.tres")

func _ready() -> void:
	super._ready()
	_apply_level_tuning()

func _resolve_siege_biome(cur_lvl: int) -> String:
	return resolve_chunk_biome(cur_lvl)

var _siege_tuning_applied: bool = false

func _apply_level_tuning() -> void:
	if _siege_tuning_applied:
		return
	_siege_tuning_applied = true
	var cur_level: int = 1
	if has_node("/root/GameState"):
		var gs: Node = get_node("/root/GameState")
		if "current_level" in gs:
			cur_level = int(gs.get("current_level"))
			
	var entities: Node = get_node_or_null("Entities")
	if not entities:
		return

	var active_biome: String = _resolve_siege_biome(cur_level)
	var variant: int = posmod(cur_level, 4)
	var primary_data: Resource = ROWER_DATA
	var secondary_data: Resource = RAIDER_DATA
	if active_biome == "bayou":
		primary_data = GHOST_SLOOP_DATA
		secondary_data = TURTLE_DATA
	elif active_biome == "brimstone":
		primary_data = GHOST_SLOOP_DATA
		secondary_data = ELITE_IRONCLAD_DATA
		
	var barricade: BarricadeWall = find_child("BarricadeWall", true, false) as BarricadeWall
	var barricade_z: float = barricade.position.z if barricade else -22.0
	
	var enemies: Array[Node3D] = []
	for child: Node in entities.get_children():
		if child is Area3D and (child.is_in_group("enemies") or child.name.begins_with("EnemyMob") or "mob_type" in child or child.has_method("apply_enemy_data")):
			enemies.append(child as Node3D)

	var trailing_z_slots: Array[float] = [-27.0, -30.5, -34.0, -38.5, -42.0, -45.5, -48.0]
	var lane_patterns: Array[Array] = [
		[-2.8, 2.2, -1.4, 2.6, 0.0, -2.2, 2.2],
		[-2.6, 2.6, -1.6, 1.6, 0.0, -2.8, 2.8],
		[-3.0, -1.2, 1.4, 3.0, -1.8, 0.0, 2.2],
		[-1.8, 1.8, -3.0, 3.0, -0.8, 0.8, -2.4],
	]
	var pattern: Array = lane_patterns[variant]

	var front_index: int = 0
	var trailing_index: int = 0
	for enemy: Node3D in enemies:
		var z_pos: float = enemy.position.z
		# Enemy is trailing behind the barricade (more negative Z)
		if z_pos < barricade_z:
			var saved_drop: int = 1 if (trailing_index % 2 == 0) else 0
			if cur_level <= 1:
				saved_drop = 0
			elif cur_level <= 4:
				saved_drop = 1 if trailing_index < 3 else 0
			var tuned_trail_hp: int = 2 if cur_level <= 3 else (3 if cur_level <= 5 else (5 if cur_level <= 10 else 8))
			if enemy.has_method("apply_enemy_data"):
				var use_secondary: bool = (trailing_index + variant) % 2 == 1 and cur_level > 2
				enemy.call("apply_enemy_data", secondary_data if use_secondary else primary_data)
				enemy.set("doubloons_drop", saved_drop)
				var scaled_hp: int = maxi(tuned_trail_hp, int(enemy.get("max_hp")) if cur_level > 10 else tuned_trail_hp)
				enemy.set("max_hp", scaled_hp)
				enemy.set("current_hp", scaled_hp)
				if cur_level <= 3:
					enemy.set("forward_speed", 1.8)

			if trailing_index < pattern.size():
				enemy.position.x = float(pattern[trailing_index])
			if trailing_index < trailing_z_slots.size():
				enemy.position.z = trailing_z_slots[trailing_index]
			trailing_index += 1
		else:
			# Enemy is in front of the barricade (Z = -12 to -14)
			var is_turtle: bool = enemy.name.contains("Turtle")
			var saved_drop_f: int = 2 if is_turtle else 1
			if cur_level <= 1:
				saved_drop_f = 0
			elif cur_level <= 3:
				saved_drop_f = 1
			if enemy.has_method("apply_enemy_data"):
				var front_data: Resource = ROWER_DATA if cur_level <= 2 else (secondary_data if is_turtle else primary_data)
				enemy.call("apply_enemy_data", front_data)
				enemy.set("doubloons_drop", saved_drop_f)
				var em := enemy as EnemyMob
				if em:
					var tuned_hp: int = 2
					if cur_level <= 2:
						tuned_hp = 2
					elif cur_level == 3:
						tuned_hp = 3
					elif cur_level <= 5:
						tuned_hp = 6 if is_turtle else 4
					elif cur_level <= 10:
						tuned_hp = 12 if is_turtle else 6
					else:
						tuned_hp = maxi(14 if is_turtle else 8, em.max_hp)
					em.max_hp = tuned_hp
					em.current_hp = tuned_hp
					if cur_level <= 3:
						em.forward_speed = 1.6
			front_index += 1

	# Spawn entry vanguard wave at Z = -4.5 and -8.0 so there is zero empty space at the start of chunk_barricade_siege
	var entry_spawns: Array[Vector3] = [
		Vector3(-2.0, 0.1, -4.5),
		Vector3(2.0, 0.1, -5.5),
		Vector3(0.0, 0.1, -8.5),
	]
	var entry_hp: int = 2 if cur_level <= 3 else (4 if cur_level <= 10 else 6)
	var entry_spd: float = 1.8 if cur_level <= 3 else 2.4
	for e_idx: int in range(entry_spawns.size()):
		if ENEMY_SCENE:
			var e_mob: Area3D = ENEMY_SCENE.instantiate() as Area3D
			if e_mob:
				e_mob.name = "SiegeEntryVanguard_%d" % (e_idx + 1)
				entities.add_child(e_mob)
				e_mob.position = entry_spawns[e_idx]
				if e_mob.has_method("apply_enemy_data"):
					e_mob.call("apply_enemy_data", primary_data)
				e_mob.set("max_hp", entry_hp)
				e_mob.set("current_hp", entry_hp)
				e_mob.set("forward_speed", entry_spd)
				e_mob.set("doubloons_drop", 0)
