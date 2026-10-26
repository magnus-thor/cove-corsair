class_name DestructibleObstacle
extends Area3D
## Destructible obstacle utilizing Area3D collision detection and GPUParticles3D VFX
## shatter behavior (barrel_explosion.tscn) rather than RigidBody3D physics to safeguard 60 FPS performance.

enum ObstacleType { WOODEN_BARREL, FUSE_BARREL, RUNE_BARREL, SEA_MINE, CORAL_REEF }

## Emitted when this obstacle is destroyed (past-tense event, SSOT Rule 1).
## Listeners (GameState, LevelController) use this to award score/XP — the obstacle
## never pushes directly into the player or other peers.
signal obstacle_destroyed(obstacle_type: ObstacleType, world_pos: Vector3)

## Visual obstacle HP (exported for editor convenience; SSOT is HealthComponent).
var _base_hp: int = 1

@export var hp: int:
	set(val):
		_base_hp = val
		if health_component:
			health_component.reset(val)
	get:
		if health_component:
			return health_component.current_health
		return _base_hp
@export var obstacle_type: ObstacleType = ObstacleType.WOODEN_BARREL:
	set(val):
		obstacle_type = val
		if is_node_ready():
			update_obstacle_visuals()

@export var doubloons_drop: int = 1
@export var doubloon_scene: PackedScene = preload("res://src/gameplay/collectibles/collectible_doubloon.tscn")

@export var wooden_barrel_tex: Texture2D = preload("res://assets/sprites/lane_objects/wooden barrell.png")
@export var fuse_barrel_tex: Texture2D = preload("res://assets/sprites/lane_objects/Barrell with fuse.png")
@export var rune_barrel_tex: Texture2D = preload("res://assets/sprites/lane_objects/Barrell with runes.png")
@export var sea_mine_tex: Texture2D = preload("res://assets/sprites/lane_objects/Spiked Sea Mine.png")
@export var coral_reef_tex: Texture2D = preload("res://assets/sprites/lane_objects/Indestructible Coral Reef.png")

## Barrel destruction explosion VFX to spawn when destroyed
@export var barrel_explosion_scene: PackedScene = preload("res://src/vfx/barrel_explosion.tscn")

@export var forward_speed: float = 0.0

@onready var obstacle_sprite: Sprite3D = get_node_or_null("ObstacleSprite") as Sprite3D
@onready var barrel_model: Node3D = get_node_or_null("BarrelModel")
@onready var health_component: HealthComponent = get_node_or_null("HealthComponent")

var _is_destroyed: bool = false
var _hits_taken: int = 0

func _ready() -> void:
	_clean_shadow_nodes(self)
	update_obstacle_visuals()
	
	# Wire HealthComponent (Blueprint 1)
	if health_component:
		health_component.max_health = hp
		health_component.reset()
		health_component.died.connect(die)
	else:
		var hc := HealthComponent.new()
		hc.name = "HealthComponent"
		hc.max_health = hp
		add_child(hc)
		health_component = hc
		health_component.died.connect(die)

func _physics_process(delta: float) -> void:
	if _is_destroyed or not GameState.is_game_active:
		return
	if forward_speed > 0.0:
		global_position.z += forward_speed * delta
		
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var player_z: float = player.global_position.z if player else 0.0
	if global_position.z > (player_z + 3.0):
		# Only active explosive hazards (fuse barrels, sea mines) deal pass-by leak damage.
		# Barricades and loot barrels (wooden barrels, rune barrels) must NEVER deal leak damage.
		if not is_in_group("barricade") and (obstacle_type == ObstacleType.FUSE_BARREL or obstacle_type == ObstacleType.SEA_MINE):
			if player and player.has_method("leak_threat"):
				player.call("leak_threat", self)
		queue_free()

func update_obstacle_visuals() -> void:
	if obstacle_sprite:
		obstacle_sprite.visible = true
		if barrel_model:
			barrel_model.visible = false
			
		var tex: Texture2D = wooden_barrel_tex
		var p_size: float = 0.0017
		var y_off: float = 0.78
		var sc: Vector3 = Vector3(0.94, 0.94, 0.94)
		var rot_deg: Vector3 = Vector3(0.0, 23.0, 0.0)
		
		match obstacle_type:
			ObstacleType.WOODEN_BARREL:
				tex = wooden_barrel_tex
				p_size = 0.0017
				y_off = 0.78
				sc = Vector3(0.94, 0.94, 0.94)
				rot_deg = Vector3(0.0, 23.0, 0.0)
				doubloons_drop = 1
			ObstacleType.FUSE_BARREL:
				tex = fuse_barrel_tex
				p_size = 0.0017
				y_off = 0.70
				sc = Vector3(1.0, 1.0, 1.0)
				rot_deg = Vector3(0.0, 0.0, 0.0)
				doubloons_drop = 2
			ObstacleType.RUNE_BARREL:
				tex = rune_barrel_tex
				p_size = 0.0017
				y_off = 0.68
				sc = Vector3(1.0, 1.0, 1.0)
				rot_deg = Vector3(0.0, 0.0, 0.0)
				doubloons_drop = 3
			ObstacleType.SEA_MINE:
				tex = sea_mine_tex
				p_size = 0.0021
				y_off = 0.37
				sc = Vector3(1.0, 1.0, 1.0)
				rot_deg = Vector3(0.0, 0.0, 0.0)
				doubloons_drop = 0
			ObstacleType.CORAL_REEF:
				tex = coral_reef_tex
				p_size = 0.0028
				y_off = 2.00
				sc = Vector3(0.71, 0.71, 0.71)
				rot_deg = Vector3(0.0, 40.0, 0.0)
				doubloons_drop = 0
				
		obstacle_sprite.texture = tex
		obstacle_sprite.pixel_size = p_size
		obstacle_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		obstacle_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		
		# Set visual Y position relative to water plane
		obstacle_sprite.position = Vector3(0.0, y_off, 0.0)
		scale = sc
		rotation_degrees = rot_deg

## Canonical damage entry point (Signal Up / Call Down Rule 2).
## Ammo-aware overrides go in subclasses (e.g. barricade takes 2x from battering_shot).
func take_hit(amount: int, source_info: String = "") -> void:
	if _is_destroyed:
		return
	_hits_taken += 1
	if health_component:
		health_component.take_damage(amount, source_info)
		# Sensory Polish: 3D & Sprite Hit Flash
		HitFlashComponent.flash_node(self, 0.065)
		# Spawn floating combat text
		var ft_script := load("res://src/vfx/floating_text.gd") as GDScript
		if ft_script:
			var fct: Node3D = ft_script.new() as Node3D
			var root := get_tree().current_scene
			if root and fct:
				root.add_child(fct)
				fct.global_position = global_position + Vector3(randf_range(-0.5, 0.5), 1.2, randf_range(-0.5, 0.5))
				if fct.has_method("setup"):
					fct.call("setup", "-" + str(amount), Color(1.0, 0.3, 0.3))

## Backward-compatible bridge — existing callers continue to work.
func take_damage(amount: int) -> void:
	take_hit(amount, "")

func die() -> void:
	if _is_destroyed:
		return
	_is_destroyed = true
	if health_component and not health_component.is_dead:
		health_component.take_damage(health_component.current_health)

	# Rule 4 — Immediate collider shutdown: prevent ghost collisions on the corpse frame.
	collision_layer = 0
	collision_mask = 0
	for child in get_children():
		if child is CollisionShape3D:
			child.set_deferred("disabled", true)
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	
	GameState.targets_destroyed += 1
	if is_in_group("barricade"):
		AudioManager.play_sfx("sfx_wood_smash")
	else:
		AudioManager.play_sfx("barrel_breaks")
	var explosion_pos := global_position
	if obstacle_type == ObstacleType.SEA_MINE:
		explosion_pos.y = 0.05
		if VFXManager and VFXManager.has_method("hit_stop"):
			VFXManager.hit_stop(0.05)
		AudioManager.play_sfx("sfx_mine_detonate")
		if VFXManager and VFXManager.has_method("spawn_mine_explosion"):
			VFXManager.spawn_mine_explosion(explosion_pos)
		elif VFXManager and VFXManager.has_method("spawn_explosion"):
			VFXManager.spawn_explosion(explosion_pos)
		else:
			_spawn_explosion()
	elif obstacle_type == ObstacleType.FUSE_BARREL:
		explosion_pos.y = 0.05
		if VFXManager and VFXManager.has_method("hit_stop"):
			VFXManager.hit_stop(0.04)
		AudioManager.play_sfx("barrel_breaks")
		if VFXManager and VFXManager.has_method("spawn_mine_explosion"):
			VFXManager.spawn_mine_explosion(explosion_pos)
		if VFXManager and VFXManager.has_method("spawn_wood_debris"):
			VFXManager.spawn_wood_debris(explosion_pos)
	else:
		if is_in_group("barricade") or obstacle_type == ObstacleType.WOODEN_BARREL:
			if VFXManager and VFXManager.has_method("spawn_wood_debris"):
				VFXManager.spawn_wood_debris(explosion_pos)
		_spawn_explosion()
	
	# Doubloons / Chest drop logic:
	# Rune Barrels gate chests behind level 5+:
	# - For current_level >= 5: drop a 50-doubloon chest.
	# - For current_level < 5: drop 3 standard coins inline.
	if obstacle_type == ObstacleType.RUNE_BARREL:
		var cur_lvl: int = 1
		if has_node("/root/GameState"):
			var gs: Node = get_node("/root/GameState")
			if "current_level" in gs:
				cur_lvl = int(gs.get("current_level"))
		if cur_lvl >= 5:
			var chest_scene := load("res://src/gameplay/collectibles/collectible_chest.tscn") as PackedScene
			if chest_scene:
				var chest := chest_scene.instantiate() as Area3D
				if chest and "chest_value" in chest:
					chest.set("chest_value", 50)
				var root := get_tree().current_scene
				if root and chest:
					root.add_child(chest)
					chest.global_position = Vector3(global_position.x, 0.15, global_position.z)
		else:
			doubloons_drop = 3
			_spawn_doubloons()
	else:
		_spawn_doubloons()

	# ── Engagement telemetry ─────────────────────────────────────────────────
	if EventBus and EventBus.has_signal("obstacle_destroyed_telemetry"):
		var obs_label: String
		# Check barricade group first — BarricadeSegment inherits obstacle_type
		# WOODEN_BARREL as its default, so the group check must precede the
		# obstacle_type match to avoid mis-labelling barricades as wooden_barrel.
		if is_in_group("barricade"):
			obs_label = "barricade"
		else:
			match obstacle_type:
				ObstacleType.WOODEN_BARREL: obs_label = "wooden_barrel"
				ObstacleType.FUSE_BARREL:   obs_label = "fuse_barrel"
				ObstacleType.RUNE_BARREL:   obs_label = "rune_barrel"
				ObstacleType.SEA_MINE:      obs_label = "sea_mine"
				ObstacleType.CORAL_REEF:    obs_label = "coral_reef"
				_:                          obs_label = "obstacle"
		var river_dist: float = GameState.distance_traveled if GameState else 0.0
		EventBus.obstacle_destroyed_telemetry.emit(obs_label, _hits_taken, river_dist)
		if has_meta("spawns_chest"):
			var cur_lvl_meta: int = GameState.current_level if GameState else 1
			if cur_lvl_meta >= 6:
				var chest_scene := load("res://src/gameplay/collectibles/collectible_chest.tscn") as PackedScene
				if chest_scene:
					var chest := chest_scene.instantiate() as Area3D
					if chest and "chest_value" in chest:
						chest.set("chest_value", 15)
					var root := get_tree().current_scene
					if root and chest:
						root.add_child(chest)
						chest.global_position = Vector3(global_position.x, 0.15, global_position.z)
	
	# Trigger camera shake on death!
	var camera := get_tree().get_first_node_in_group("game_camera") as GameCamera
	if camera:
		var intensity: float = 0.25 if (obstacle_type == ObstacleType.FUSE_BARREL or obstacle_type == ObstacleType.SEA_MINE) else 0.12
		camera.shake(0.18, intensity)
		
	# Deal splash chain damage if explosive
	if obstacle_type == ObstacleType.FUSE_BARREL or obstacle_type == ObstacleType.SEA_MINE:
		_apply_explosion_damage()

	# Rule 1 — Signal Up: broadcast past-tense event with data payload.
	# Listeners (LevelController, GameState, HUD) subscribe to award score/XP without
	# the obstacle coupling to the player hierarchy directly.
	obstacle_destroyed.emit(obstacle_type, global_position)
		
	queue_free()

func _apply_explosion_damage() -> void:
	var radius: float = 3.5
	var dmg: int = 2
	
	# Spawn floating "+BOOM" text
	var ft_script := load("res://src/vfx/floating_text.gd") as GDScript
	if ft_script:
		var fct: Node3D = ft_script.new() as Node3D
		var root := get_tree().current_scene
		if root and fct:
			root.add_child(fct)
			fct.global_position = global_position + Vector3(0, 1.2, 0)
			if fct.has_method("setup"):
				fct.call("setup", "+BOOM", Color(1.0, 0.2, 0.1))
			
	# Trigger a punchy camera shake
	var camera := get_tree().get_first_node_in_group("game_camera") as GameCamera
	if camera:
		camera.shake(0.22, 0.25)
		
	var targets: Array[Node] = []
	targets.append_array(get_tree().get_nodes_in_group("destructible"))
	targets.append_array(get_tree().get_nodes_in_group("enemies"))
	
	var player: Node = get_tree().get_first_node_in_group("player")
		
	var processed: Dictionary = {}
	for obj: Node in targets:
		if obj != null and obj != self and is_instance_valid(obj) and not processed.has(obj):
			processed[obj] = true
			if obj is Node3D:
				var dist: float = (obj as Node3D).global_position.distance_to(global_position)
				if dist <= radius and obj.has_method("take_damage"):
					obj.call("take_damage", dmg)
					
	# Player uses leak_threat, not take_damage — route correctly.
	if player and is_instance_valid(player) and player is Node3D:
		var player_dist: float = (player as Node3D).global_position.distance_to(global_position)
		if player_dist <= radius and player.has_method("leak_threat"):
			player.call("leak_threat", self)

func _spawn_explosion() -> void:
	if barrel_explosion_scene:
		var vfx := barrel_explosion_scene.instantiate() as Node3D
		vfx.top_level = true
		vfx.position = global_position
		var root := get_tree().current_scene
		if root:
			root.add_child(vfx)
		elif get_parent():
			get_parent().add_child(vfx)
		vfx.global_position = global_position

func _spawn_doubloons() -> void:
	if not doubloon_scene:
		return
		
	var drop_count := doubloons_drop
	if drop_count <= 0 and (obstacle_type == ObstacleType.WOODEN_BARREL or obstacle_type == ObstacleType.FUSE_BARREL or obstacle_type == ObstacleType.RUNE_BARREL):
		drop_count = 1 if obstacle_type == ObstacleType.WOODEN_BARREL else (2 if obstacle_type == ObstacleType.FUSE_BARREL else 3)
		
	if drop_count <= 0:
		return
		
	var spawn_parent := get_tree().current_scene
	if not spawn_parent or spawn_parent == self:
		spawn_parent = get_parent()
		if spawn_parent == self or spawn_parent is DestructibleObstacle:
			return
		
	for i in range(drop_count):
		var doubloon := doubloon_scene.instantiate() as CollectibleDoubloon
		if doubloon:
			spawn_parent.add_child(doubloon)
			doubloon.global_position = Vector3(global_position.x, 0.05, global_position.z)
			
			# Radial outward scatter on X and Z
			var scatter := Vector2(randf_range(-0.6, 0.6), randf_range(-0.6, 0.6))
			doubloon._trigger_spawn_bounce(scatter)

func _clean_shadow_nodes(node: Node) -> void:
	if not node:
		return
	var lower_name: String = str(node.name).to_lower()
	var is_shadow_node: bool = false
	if "shadow" in lower_name or "decal" in lower_name or "projector" in lower_name or "card" in lower_name or "oblate" in lower_name or "shadow_sphere" in lower_name or "sphere_shadow" in lower_name:
		is_shadow_node = true
		
	if is_shadow_node:
		if node is Sprite3D or node is MeshInstance3D or node is Decal or node.get_class() == "Decal3D":
			node.queue_free()
			return
			
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		if "shadow" in lower_name or "plane" in lower_name or "billboard" in lower_name or "card" in lower_name:
			mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mesh_node.visible = false
			mesh_node.queue_free()
			return
			
	for child: Node in node.get_children():
		_clean_shadow_nodes(child)
