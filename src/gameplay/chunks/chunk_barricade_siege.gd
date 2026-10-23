class_name ChunkBarricadeSiege
extends BaseTrackChunk

## Custom controller for chunk_barricade_siege.
## Enforces safe buffer zones behind barricade walls and adapts hazards for early campaign levels.

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

func _apply_level_tuning() -> void:
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
	var barricade_z: float = barricade.position.z if barricade else -20.0
	
	# Minimum safe distance: at least 25m behind barricade wall
	var min_enemy_z: float = barricade_z - 25.0
	
	var enemies: Array[Node3D] = []
	for child: Node in entities.get_children():
		if child is Area3D and (child.is_in_group("enemies") or child.name.begins_with("EnemyMob") or "mob_type" in child or child.has_method("apply_enemy_data")):
			enemies.append(child as Node3D)

	var trailing_index: int = 0
	for enemy: Node3D in enemies:
		var z_pos: float = enemy.position.z
		# Enemy is trailing behind the barricade (more negative Z)
		if z_pos < barricade_z:
			if cur_level <= 3:
				# In early levels (Levels 1 to 3), replace trailing enemy skiffs with floating coin arcs or barrel pickups
				# so the player has a clear, readable recovery zone after breaching
				_replace_trailing_enemy_with_pickup(entities, enemy)
			else:
				# Apply biome vessel data and level-specific trailing formation while preserving doubloon drops
				var saved_drop: int = int(enemy.get("doubloons_drop")) if "doubloons_drop" in enemy else 3
				var saved_hp: int = int(enemy.get("max_hp")) if "max_hp" in enemy else 5
				if enemy.has_method("apply_enemy_data"):
					var use_secondary: bool = (trailing_index + variant) % 2 == 1
					enemy.call("apply_enemy_data", secondary_data if use_secondary else primary_data)
					enemy.set("doubloons_drop", saved_drop)
					enemy.set("max_hp", saved_hp)
					enemy.set("current_hp", saved_hp)

				# Vary trailing formation across levels while keeping z <= min_enemy_z (-47m)
				var lane_patterns: Array[Array] = [
					[-3.2, 1.2, 0.0, -1.4, 1.4, -2.6, 2.6],
					[-2.8, 2.8, -1.8, 1.8, -0.6, 0.6, 0.0],
					[-3.4, -1.2, 1.2, 3.4, -2.2, 0.0, 2.2],
					[-1.6, 1.6, -3.2, 3.2, -0.8, 0.8, 0.0],
				]
				var pattern: Array = lane_patterns[variant]
				if trailing_index < pattern.size():
					enemy.position.x = float(pattern[trailing_index])
				if enemy.position.z > min_enemy_z:
					enemy.position.z = min_enemy_z - float(trailing_index % 3) * 0.8
				trailing_index += 1
		else:
			# Enemy is in front of the barricade (e.g. Turtle Raft at Z = -12)
			if cur_level <= 3:
				# Ensure Level 1 (and early levels) does NOT spawn fortified 30 HP Turtle Rafts
				# Replace with gentle barrel pickup or floating coins yielding equivalent doubloons
				_replace_front_hazard_with_pickup(entities, enemy, cur_level)
			elif enemy.has_method("apply_enemy_data"):
				var saved_drop_f: int = int(enemy.get("doubloons_drop")) if "doubloons_drop" in enemy else 3
				var saved_hp_f: int = int(enemy.get("max_hp")) if "max_hp" in enemy else 5
				enemy.call("apply_enemy_data", secondary_data if enemy.name.contains("Turtle") else primary_data)
				enemy.set("doubloons_drop", saved_drop_f)
				var em := enemy as EnemyMob
				if em:
					var tuned_hp: int = 10 if (cur_level <= 10 and saved_hp_f > 15) else saved_hp_f
					em.max_hp = tuned_hp
					em.current_hp = tuned_hp

func _replace_trailing_enemy_with_pickup(entities: Node, enemy: Node3D) -> void:
	var pos: Vector3 = enemy.position
	var cur_lvl: int = 1
	if has_node("/root/GameState") and "current_level" in get_node("/root/GameState"):
		cur_lvl = int(get_node("/root/GameState").get("current_level"))
	var doubloons_amount: int = 1 if cur_lvl <= 2 else (int(enemy.get("doubloons_drop")) if "doubloons_drop" in enemy else 3)
	entities.remove_child(enemy)
	enemy.queue_free()
	
	# Spawn a wooden barrel pickup that drops doubloons when destroyed
	if BARREL_SCENE:
		var barrel := BARREL_SCENE.instantiate() as DestructibleObstacle
		if barrel:
			entities.add_child(barrel)
			barrel.add_to_group("destructible")
			barrel.position = Vector3(pos.x, 0.05, pos.z)
			barrel.hp = 1
			barrel.doubloons_drop = doubloons_amount
			barrel.obstacle_type = DestructibleObstacle.ObstacleType.WOODEN_BARREL

func _replace_front_hazard_with_pickup(entities: Node, enemy: Node3D, cur_lvl: int) -> void:
	var pos: Vector3 = enemy.position
	var doubloons_amount: int = 2 if cur_lvl <= 2 else (int(enemy.get("doubloons_drop")) if "doubloons_drop" in enemy else 4)
	entities.remove_child(enemy)
	enemy.queue_free()
	
	# In Level 1, shift front pickups to the channel margins (|X| >= 3.6m) so the center channel to the barricade is wide open
	var barrel_x: float = pos.x
	if cur_lvl <= 1 and absf(barrel_x) < 3.2:
		barrel_x = -3.8 if barrel_x <= 0.0 else 3.8
	
	# Spawn a wooden barrel pickup that drops doubloons when destroyed
	if BARREL_SCENE:
		var barrel := BARREL_SCENE.instantiate() as DestructibleObstacle
		if barrel:
			entities.add_child(barrel)
			barrel.add_to_group("destructible")
			barrel.position = Vector3(barrel_x, 0.05, pos.z)
			barrel.hp = 1
			barrel.doubloons_drop = doubloons_amount
			barrel.obstacle_type = DestructibleObstacle.ObstacleType.WOODEN_BARREL
