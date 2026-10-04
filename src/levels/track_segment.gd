class_name TrackSegment
extends Node3D

## The length of this segment along the Z-axis.
@export var segment_length: float = 40.0

## The barrel prefab to instantiate dynamically
@export var barrel_prefab: PackedScene = preload("res://src/gameplay/obstacles/destructible_barrel.tscn")

## The multiplier gate prefab to instantiate dynamically
@export var multiplier_gate_prefab: PackedScene = preload("res://src/gameplay/obstacles/multiplier_gate.tscn")

## The enemy mob scenes / prefabs to instantiate dynamically
@export var enemy_mob_scenes: Array[PackedScene] = [preload("res://src/gameplay/enemies/enemy_mob.tscn")]
@export var enemy_mob_prefab: PackedScene = preload("res://src/gameplay/enemies/enemy_mob.tscn")

@onready var obstacles_container: Node3D = $Obstacles

## Signal emitted when this segment moves off-screen and needs recycling.
signal off_screen(segment: TrackSegment)

var level_config_data: Dictionary = {}

func _ready() -> void:
	var notifier: VisibleOnScreenNotifier3D = get_node_or_null("VisibleOnScreenNotifier3D") as VisibleOnScreenNotifier3D
	if notifier:
		notifier.screen_exited.connect(_on_screen_exited)
	
	spawn_obstacles()
	spawn_gates()
	spawn_scenery()

func _on_screen_exited() -> void:
	# Signal to the TrackManager that this segment is ready to be recycled
	off_screen.emit(self)

## Allows TrackManager to pass down current level configuration dictionary
func apply_level_data(data: Dictionary) -> void:
	level_config_data = data
	spawn_obstacles()
	spawn_gates()
	spawn_scenery()

## Hook called by the TrackManager when this segment is recycled.
func recycle_segment_with_config(data: Dictionary) -> void:
	level_config_data = data
	recycle_segment()

## Reset and randomize segment contents
func recycle_segment() -> void:
	spawn_obstacles()
	spawn_gates()
	spawn_scenery()

## Clean up all obstacle and enemy nodes from this segment
func clear_obstacles() -> void:
	if obstacles_container:
		for child: Node in obstacles_container.get_children():
			obstacles_container.remove_child(child)
			child.queue_free()

## Helper to clean up existing obstacles and spawn new barrels dynamically using level config
func spawn_obstacles() -> void:
	if not obstacles_container or not barrel_prefab:
		return
		
	clear_obstacles()
		
	# Cove Corsair campaign levels (1-6) are strictly deterministic and scripted by LevelController
	if GameState.current_level in [1, 2, 3, 4, 5, 6] or level_config_data.get("is_scripted", false) or GameState.get_current_level_resource() != null:
		return
		
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	if player and "is_calibration_mode" in player and player.get("is_calibration_mode") == true:
		return
		
	var player_z: float = player.global_position.z if player else 0.0
	var min_safe_z: float = player_z - 45.0 # Never spawn within 45m ahead of the player vessel
		
	var level_idx: int = int(level_config_data.get("level_index", 1))
	var rarities: Array = level_config_data.get("obstacle_rarities_allowed", ["common"])
	var is_boss: bool = level_config_data.get("is_boss_level", false) == true
	
	# Determine barrel count based on level index and boss status
	var count: int = randi_range(2, 2 + int(level_idx / 3.0))
	if is_boss:
		count += 1
		
	var base_min_hp: int = 2 + int(level_idx * 0.5)
	var base_max_hp: int = 3 + level_idx
	
	for i: int in range(count):
		var rand_z: float = -randf_range(5.0, segment_length - 5.0)
		var world_z: float = global_position.z + rand_z
		if world_z > min_safe_z:
			continue # Enforce minimum safe distance from player vessel
			
		var barrel: Area3D = barrel_prefab.instantiate() as Area3D
		if not barrel:
			continue
			
		obstacles_container.add_child(barrel)
		
		# Boss Level Special Handling for first obstacle
		if is_boss and i == 0:
			barrel.set("hp", 12 + level_idx * 2)
			barrel.scale = Vector3(1.75, 1.75, 1.75)
			barrel.position = Vector3(0.0, 0.0, -30.0)
			if "obstacle_type" in barrel:
				barrel.set("obstacle_type", DestructibleObstacle.ObstacleType.CORAL_REEF)
			continue
			
		# Regular / Rare barrel generation
		var hp_mult: float = 1.0
		if "rare" in rarities and randf() < 0.25:
			hp_mult = 2.0
		elif "normal" in rarities and randf() < 0.40:
			hp_mult = 1.5
			
		barrel.set("hp", int(randi_range(base_min_hp, base_max_hp) * hp_mult))
		
		# Pick obstacle visual variant based on HP and rarity
		if "obstacle_type" in barrel:
			var b_hp: int = int(barrel.get("hp"))
			if b_hp >= 8:
				barrel.set("obstacle_type", DestructibleObstacle.ObstacleType.CORAL_REEF)
			elif b_hp >= 6:
				barrel.set("obstacle_type", DestructibleObstacle.ObstacleType.RUNE_BARREL)
			elif b_hp >= 4:
				barrel.set("obstacle_type", DestructibleObstacle.ObstacleType.FUSE_BARREL)
			elif randf() < 0.2:
				barrel.set("obstacle_type", DestructibleObstacle.ObstacleType.SEA_MINE)
			else:
				barrel.set("obstacle_type", DestructibleObstacle.ObstacleType.WOODEN_BARREL)
				
		var lane_x: float = randf_range(-4.5, 4.5)
		barrel.position = Vector3(lane_x, 0.0, rand_z)

	# Dynamic enemy mob spawning based on level difficulty
	var enemy_mob_count: int = 0
	if level_idx >= 2:
		enemy_mob_count = randi_range(1, 2)
	if level_idx >= 5:
		enemy_mob_count = randi_range(2, 3)
		
	var enemy_types: Array[String] = ["skeleton_rower"]
	if level_idx >= 3:
		enemy_types.append("goblin_skiff")
	if level_idx >= 5:
		enemy_types.append("turtle_raft")

	var enemy_res_map: Dictionary = {
		"skeleton_rower": "res://src/data/resources/enemy_vessels/skeleton_rower.tres",
		"raider_skiff": "res://src/data/resources/enemy_vessels/raider_skiff.tres",
		"goblin_skiff": "res://src/data/resources/enemy_vessels/raider_skiff.tres",
		"turtle_raft": "res://src/data/resources/enemy_vessels/turtle_raft.tres"
	}
		
	for e: int in range(enemy_mob_count):
		var rand_z: float = -randf_range(8.0, segment_length - 8.0)
		var world_z: float = global_position.z + rand_z
		if world_z > min_safe_z:
			continue # Enforce minimum safe distance from player vessel
			
		if enemy_mob_prefab:
			var enemy: Area3D = enemy_mob_prefab.instantiate() as Area3D
			if enemy:
				obstacles_container.add_child(enemy)
				var chosen_type: String = enemy_types.pick_random()
				if enemy_res_map.has(chosen_type):
					var res: EnemyData = load(enemy_res_map[chosen_type]) as EnemyData
					if res and enemy.has_method("apply_enemy_data"):
						enemy.call("apply_enemy_data", res)
				elif "mob_type" in enemy:
					enemy.set("mob_type", chosen_type)
				
				var lane_x: float = randf_range(-3.8, 3.8)
				enemy.position = Vector3(lane_x, 0.0, rand_z)

## Spawns Multiplier Gates on this segment according to level config frequency
func spawn_gates() -> void:
	var gates_container: Node3D = get_node_or_null("Gates") as Node3D
	if not gates_container:
		gates_container = Node3D.new()
		gates_container.name = "Gates"
		add_child(gates_container)
		
	for child: Node in gates_container.get_children():
		gates_container.remove_child(child)
		child.queue_free()

## Spawns landscape scenery pieces along the segment shores.
## Each zone may spawn a sand/rock shoal base (with optional palm), plus a dock
## ruin accent prop (30 % chance) to create an organic, jagged shoreline.
func spawn_scenery() -> void:
	var scenery_container: Node3D = get_node_or_null("Scenery") as Node3D
	if not scenery_container:
		return
		
	for child: Node in scenery_container.get_children():
		scenery_container.remove_child(child)
		child.queue_free()

	# ── Asset paths ───────────────────────────────────────────────────────────
	# Swap these to res://assets/models/environment/*.glb for the art-pass.
	var sand_island_path    := "res://assets/models/patch-sand.glb"
	var rock_island_path    := "res://assets/models/rocks-sand-a.glb"
	var palm_straight_path  := "res://assets/models/palm-detailed-straight.glb"
	var palm_bend_path      := "res://assets/models/palm-detailed-bend.glb"
	var palm_island_path    := "res://assets/models/scenery/Low_Poly_Palm_Island.glb"
	var mangrove_grove_path := "res://assets/models/scenery/Emerald_Mangrove_Grov.glb"
	var dock_ruin_paths: Array[String] = [
		"res://assets/models/structure-platform-dock-small.glb",
		"res://assets/models/structure.glb",
	]

	var zones: Array[Vector2] = [
		Vector2(-40.0, -32.5),
		Vector2(-32.5, -25.0),
		Vector2(-25.0, -17.5),
		Vector2(-17.5, -10.0)
	]
	
	for zone: Vector2 in zones:
		var shore := randi() % 3
		if shore == 0:
			continue
			
		var rand_x := 0.0
		var is_left: bool = (shore == 1)
		if is_left:
			# Left bank: roots strictly at X <= -6.5 (ranging outward from -6.5 to -10.5)
			rand_x = randf_range(-10.5, -6.5)
		else:
			# Right bank: roots strictly at X >= +6.5 (ranging outward from +6.5 to +10.5)
			rand_x = randf_range(6.5, 10.5)
			
		var rand_z := randf_range(zone.x, zone.y)
		
		# ── Shoal base (custom palm island, mangrove grove, or Kenney sand/rock shoal) ──
		var roll: float = randf()
		if roll < 0.25 and ResourceLoader.exists(palm_island_path):
			var island_scene := load(palm_island_path) as PackedScene
			if island_scene:
				var island_inst := island_scene.instantiate() as Node3D
				scenery_container.add_child(island_inst)
				var s_val: float = randf_range(1.1, 1.4)
				island_inst.scale = Vector3.ONE * s_val
				island_inst.position = Vector3(rand_x, 0.65 * s_val, rand_z)
				island_inst.rotation.y = randf_range(0.0, TAU)
				_clean_shadow_nodes(island_inst)
				_enforce_navigable_clearance(island_inst, is_left)
		elif roll < 0.45 and ResourceLoader.exists(mangrove_grove_path):
			var mangrove_scene := load(mangrove_grove_path) as PackedScene
			if mangrove_scene:
				var mangrove_inst := mangrove_scene.instantiate() as Node3D
				scenery_container.add_child(mangrove_inst)
				var s_val: float = randf_range(1.2, 1.5)
				mangrove_inst.scale = Vector3.ONE * s_val
				mangrove_inst.position = Vector3(rand_x, 0.50 * s_val, rand_z)
				mangrove_inst.rotation.y = randf_range(0.0, TAU)
				_clean_shadow_nodes(mangrove_inst)
				_enforce_navigable_clearance(mangrove_inst, is_left)
		else:
			var base_path := sand_island_path if randf() < 0.5 else rock_island_path
			var base_scene: PackedScene = load(base_path) as PackedScene
			if base_scene:
				var base_inst := base_scene.instantiate() as Node3D
				scenery_container.add_child(base_inst)
				base_inst.position = Vector3(rand_x, 0.06, rand_z)
				base_inst.scale = Vector3(randf_range(1.0, 1.3), randf_range(0.7, 1.0), randf_range(1.0, 1.3))
				base_inst.rotation.y = randf_range(0.0, TAU)
				_clean_shadow_nodes(base_inst)
				
				# Palm on shoal (60 % chance)
				if randf() < 0.6:
					var palm_path := palm_straight_path if randf() < 0.5 else palm_bend_path
					var palm_scene: PackedScene = load(palm_path) as PackedScene
					if palm_scene:
						var palm_inst := palm_scene.instantiate() as Node3D
						base_inst.add_child(palm_inst)
						palm_inst.position = Vector3(randf_range(-0.2, 0.2), 0.0, randf_range(-0.2, 0.2))
						palm_inst.scale    = Vector3.ONE * randf_range(0.8, 1.2)
						palm_inst.rotation.y = randf_range(0.0, TAU)
						_clean_shadow_nodes(palm_inst)

				# buffer=0.0 — allow rocks to kiss ±6.0 for an organic jagged silhouette.
				_enforce_navigable_clearance(base_inst, is_left)

		# ── Dock ruins accent prop (30 % chance) ──────────────────────────────
		if randf() < 0.30:
			var ruin_path: String = dock_ruin_paths[randi() % dock_ruin_paths.size()]
			var ruin_scene: PackedScene = load(ruin_path) as PackedScene
			if ruin_scene:
				var ruin_inst := ruin_scene.instantiate() as Node3D
				scenery_container.add_child(ruin_inst)
				var ruin_x := randf_range(-8.5, -6.5) if is_left else randf_range(6.5, 8.5)
				ruin_inst.position   = Vector3(ruin_x, 0.0, rand_z + randf_range(-2.0, 2.0))
				ruin_inst.scale      = Vector3.ONE * randf_range(0.8, 1.2)
				ruin_inst.rotation.y = randf_range(0.0, TAU)
				_clean_shadow_nodes(ruin_inst)
				_enforce_navigable_clearance(ruin_inst, is_left)

func _clean_shadow_nodes(node: Node) -> void:
	if not node:
		return
		
	if node is GeometryInstance3D:
		var geom := node as GeometryInstance3D
		geom.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		
	var lower_name: String = node.name.to_lower()
	var is_shadow_node: bool = false
	if "shadow" in lower_name or "decal" in lower_name or "projector" in lower_name or "card" in lower_name or "oblate" in lower_name or "shadow_sphere" in lower_name or "sphere_shadow" in lower_name or "quad" in lower_name or "dark" in lower_name:
		is_shadow_node = true
		
	if is_shadow_node:
		node.queue_free()
		return
			
	for child: Node in node.get_children():
		_clean_shadow_nodes(child)

# ── Navigable corridor clearance enforcement ──────────────────────────────────

func _collect_mesh_instances(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		result.append(node as MeshInstance3D)
	for child in node.get_children():
		_collect_mesh_instances(child, result)

func _get_relative_transform(node: Node3D, root: Node3D) -> Transform3D:
	var xform := Transform3D.IDENTITY
	var curr: Node = node
	while curr and curr != root and curr is Node3D:
		xform = (curr as Node3D).transform * xform
		curr = curr.get_parent()
	return xform

## buffer=0.0 allows props to touch the ±6.0 corridor edge for organic silhouette.
func _enforce_navigable_clearance(prop: Node3D, is_left: bool, buffer: float = 0.0) -> void:
	if not prop:
		return
	
	var min_x := INF
	var max_x := -INF
	var mesh_instances: Array[MeshInstance3D] = []
	_collect_mesh_instances(prop, mesh_instances)
	
	for mi in mesh_instances:
		if not mi.mesh:
			continue
		var aabb: AABB = mi.mesh.get_aabb()
		var rel_xform: Transform3D = _get_relative_transform(mi, self)
		for i in range(8):
			var corner := aabb.position + Vector3(
				aabb.size.x if (i & 1) else 0.0,
				aabb.size.y if (i & 2) else 0.0,
				aabb.size.z if (i & 4) else 0.0
			)
			var pt := rel_xform * corner
			min_x = minf(min_x, pt.x)
			max_x = maxf(max_x, pt.x)
			
	if min_x == INF or max_x == -INF:
		return
		
	var lane_limit: float = 6.0 + buffer
	if is_left:
		# Left bank: navigable water is X >= -6.0. Visual geometry must be strictly <= -lane_limit (-6.05).
		if max_x > -lane_limit:
			var overshoot: float = max_x - (-lane_limit)
			prop.position.x -= overshoot
	else:
		# Right bank: navigable water is X <= +6.0. Visual geometry must be strictly >= +lane_limit (+6.05).
		if min_x < lane_limit:
			var undershoot: float = lane_limit - min_x
			prop.position.x += undershoot
