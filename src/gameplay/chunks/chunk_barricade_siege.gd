class_name ChunkBarricadeSiege
extends BaseTrackChunk

## Custom controller for chunk_barricade_siege.
## Enforces safe buffer zones behind barricade walls and adapts hazards for early campaign levels.

const BARREL_SCENE: PackedScene = preload("res://src/gameplay/obstacles/destructible_barrel.tscn")

func _ready() -> void:
	super._ready()
	_apply_level_tuning()

func _apply_level_tuning() -> void:
	var cur_level: int = 1
	if has_node("/root/GameState"):
		var gs = get_node("/root/GameState")
		if "current_level" in gs:
			cur_level = int(gs.current_level)
			
	var entities = get_node_or_null("Entities")
	if not entities:
		return
		
	var barricade = find_child("BarricadeWall", true, false) as BarricadeWall
	var barricade_z = barricade.position.z if barricade else -20.0
	
	# Minimum safe distance: at least 25m behind barricade wall
	var min_enemy_z = barricade_z - 25.0
	
	var enemies: Array[Node] = []
	for child in entities.get_children():
		if child is Area3D and (child.is_in_group("enemies") or child.name.begins_with("EnemyMob") or "mob_type" in child or child.has_method("apply_enemy_data")):
			enemies.append(child)
			
	for enemy in enemies:
		var z_pos = enemy.position.z
		# Enemy is trailing behind the barricade (more negative Z)
		if z_pos < barricade_z:
			if cur_level <= 3:
				# In early levels (Levels 1 to 3), replace trailing enemy skiffs with floating coin arcs or barrel pickups
				# so the player has a clear, readable recovery zone after breaching
				_replace_trailing_enemy_with_pickup(entities, enemy)
			else:
				# In higher levels, ensure enemy does NOT spawn within 25m behind barricade wall
				if enemy.position.z > min_enemy_z:
					enemy.position.z = min_enemy_z
		else:
			# Enemy is in front of the barricade (e.g. Turtle Raft at Z = -12)
			if cur_level <= 3:
				# Ensure Level 1 (and early levels) does NOT spawn fortified 30 HP Turtle Rafts
				# Replace with gentle barrel pickup or floating coins yielding equivalent doubloons
				_replace_front_hazard_with_pickup(entities, enemy, cur_level)
			elif enemy.has_method("apply_enemy_data"):
				# Tune mid levels if needed
				if cur_level <= 10 and enemy.max_hp > 15:
					enemy.max_hp = 10
					enemy.current_hp = 10

func _replace_trailing_enemy_with_pickup(entities: Node, enemy: Node) -> void:
	var pos = enemy.position
	var cur_lvl: int = 1
	if has_node("/root/GameState") and "current_level" in get_node("/root/GameState"):
		cur_lvl = int(get_node("/root/GameState").current_level)
	var doubloons_amount = 1 if cur_lvl <= 2 else (enemy.doubloons_drop if "doubloons_drop" in enemy else 3)
	entities.remove_child(enemy)
	enemy.queue_free()
	
	# Spawn a wooden barrel pickup that drops doubloons when destroyed
	if BARREL_SCENE:
		var barrel = BARREL_SCENE.instantiate() as Area3D
		entities.add_child(barrel)
		barrel.add_to_group("destructible")
		barrel.position = Vector3(pos.x, 0.05, pos.z)
		barrel.hp = 1
		barrel.doubloons_drop = doubloons_amount
		barrel.obstacle_type = DestructibleObstacle.ObstacleType.WOODEN_BARREL

func _replace_front_hazard_with_pickup(entities: Node, enemy: Node, cur_level: int) -> void:
	var pos = enemy.position
	var doubloons_amount = 2 if cur_level <= 2 else (enemy.doubloons_drop if "doubloons_drop" in enemy else 4)
	entities.remove_child(enemy)
	enemy.queue_free()
	
	# In Level 1, shift front pickups to the channel margins (|X| >= 3.6m) so the center channel to the barricade is wide open
	var barrel_x = pos.x
	if cur_level <= 1 and absf(barrel_x) < 3.2:
		barrel_x = -3.8 if barrel_x <= 0.0 else 3.8
	
	# Spawn a wooden barrel pickup that drops doubloons when destroyed
	if BARREL_SCENE:
		var barrel = BARREL_SCENE.instantiate() as Area3D
		entities.add_child(barrel)
		barrel.add_to_group("destructible")
		barrel.position = Vector3(barrel_x, 0.05, pos.z)
		barrel.hp = 1
		barrel.doubloons_drop = doubloons_amount
		barrel.obstacle_type = DestructibleObstacle.ObstacleType.WOODEN_BARREL
