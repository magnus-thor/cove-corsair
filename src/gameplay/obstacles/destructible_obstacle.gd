class_name DestructibleObstacle
extends Area3D
## Destructible obstacle utilizing Area3D collision detection and GPUParticles3D VFX
## shatter behavior (barrel_explosion.tscn) rather than RigidBody3D physics to safeguard 60 FPS performance.

enum ObstacleType { WOODEN_BARREL, FUSE_BARREL, RUNE_BARREL, SEA_MINE, CORAL_REEF }

## Visual obstacle HP
@export var hp: int = 3
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
@export var barrel_explosion_scene: PackedScene = preload("res://src/gameplay/vfx/barrel_explosion.tscn")

@export var forward_speed: float = 0.0

@onready var obstacle_sprite: Sprite3D = get_node_or_null("ObstacleSprite") as Sprite3D
@onready var barrel_model: Node3D = get_node_or_null("BarrelModel")

var _is_destroyed: bool = false

func _ready() -> void:
	_clean_shadow_nodes(self)
	update_obstacle_visuals()

func _physics_process(delta: float) -> void:
	if _is_destroyed or not GameState.is_game_active:
		return
	if forward_speed > 0.0:
		global_position.z += forward_speed * delta
		
	var player = get_tree().get_first_node_in_group("player")
	var player_z = player.global_position.z if player else 0.0
	if global_position.z > (player_z + 3.0):
		if obstacle_type == ObstacleType.FUSE_BARREL or obstacle_type == ObstacleType.SEA_MINE:
			if player and player.has_method("leak_threat"):
				player.leak_threat(self)
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
				doubloons_drop = 2
			ObstacleType.CORAL_REEF:
				tex = coral_reef_tex
				p_size = 0.0028
				y_off = 2.00
				sc = Vector3(0.71, 0.71, 0.71)
				rot_deg = Vector3(0.0, 40.0, 0.0)
				doubloons_drop = 4
				
		obstacle_sprite.texture = tex
		obstacle_sprite.pixel_size = p_size
		obstacle_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		obstacle_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		
		# Set visual Y position relative to water plane
		obstacle_sprite.position = Vector3(0.0, y_off, 0.0)
		scale = sc
		rotation_degrees = rot_deg

func take_damage(amount: int) -> void:
	if _is_destroyed:
		return
	hp -= amount
	
	# Spawn floating combat text
	var ft_script = load("res://src/gameplay/vfx/floating_text.gd")
	if ft_script:
		var fct = ft_script.new()
		var root = get_tree().current_scene
		if root:
			root.add_child(fct)
			fct.global_position = global_position + Vector3(randf_range(-0.5, 0.5), 1.2, randf_range(-0.5, 0.5))
			fct.setup("-" + str(amount), Color(1.0, 0.3, 0.3))
			
	# NOTE: XP is awarded only on kill (in die()), not per hit, to prevent XP runaway.
	if hp <= 0:
		die()

func die() -> void:
	if _is_destroyed:
		return
	_is_destroyed = true
	
	GameState.targets_destroyed += 1
	AudioManager.play_sfx("barrel_breaks")
	_spawn_explosion()
	_spawn_doubloons()
	
	# Trigger camera shake on death!
	var camera = get_tree().get_first_node_in_group("game_camera")
	if camera and camera.has_method("shake"):
		var intensity = 0.25 if (obstacle_type == ObstacleType.FUSE_BARREL or obstacle_type == ObstacleType.SEA_MINE) else 0.12
		camera.shake(0.18, intensity)
		
	# Deal splash chain damage if explosive
	if obstacle_type == ObstacleType.FUSE_BARREL or obstacle_type == ObstacleType.SEA_MINE:
		_apply_explosion_damage()
	
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("upgrade_ship"):
		player.upgrade_ship(1)
		
	if has_meta("spawns_chest"):
		var chest_scene = load("res://src/gameplay/collectibles/collectible_chest.tscn")
		if chest_scene:
			var chest = chest_scene.instantiate() as Area3D
			var root = get_tree().current_scene
			if root:
				root.add_child(chest)
			chest.global_position = Vector3(global_position.x, 0.15, global_position.z)
			
	queue_free()

func _apply_explosion_damage() -> void:
	var radius = 3.5
	var dmg = 2
	
	# Spawn floating "+BOOM" text
	var ft_script = load("res://src/gameplay/vfx/floating_text.gd")
	if ft_script:
		var fct = ft_script.new()
		var root = get_tree().current_scene
		if root:
			root.add_child(fct)
			fct.global_position = global_position + Vector3(0, 1.2, 0)
			fct.setup("+BOOM", Color(1.0, 0.2, 0.1))
			
	# Trigger a punchy camera shake
	var camera = get_tree().get_first_node_in_group("game_camera")
	if camera and camera.has_method("shake"):
		camera.shake(0.22, 0.25)
		
	var targets: Array[Node] = []
	targets.append_array(get_tree().get_nodes_in_group("destructible"))
	targets.append_array(get_tree().get_nodes_in_group("enemies"))
	
	var player = get_tree().get_first_node_in_group("player")
	if player and is_instance_valid(player):
		targets.append(player)
		
	var processed: Dictionary = {}
	for obj in targets:
		if obj != null and obj != self and is_instance_valid(obj) and not processed.has(obj):
			processed[obj] = true
			if obj is Node3D:
				var dist = (obj as Node3D).global_position.distance_to(global_position)
				if dist <= radius and obj.has_method("take_damage"):
					obj.take_damage(dmg)

func _spawn_explosion() -> void:
	if barrel_explosion_scene:
		var vfx = barrel_explosion_scene.instantiate() as Node3D
		var root = get_tree().current_scene
		if root:
			root.add_child(vfx)
		elif get_parent():
			get_parent().add_child(vfx)
		vfx.global_position = global_position

func _spawn_doubloons() -> void:
	if not doubloon_scene or doubloons_drop <= 0:
		return
		
	var spawn_parent = get_tree().current_scene
	if not spawn_parent or spawn_parent == self:
		spawn_parent = get_parent()
		if spawn_parent == self or spawn_parent is DestructibleObstacle:
			return
		
	for i in range(doubloons_drop):
		var doubloon = doubloon_scene.instantiate() as Area3D
		if doubloon:
			spawn_parent.add_child(doubloon)
			doubloon.global_position = Vector3(global_position.x, 0.05, global_position.z)
			
			# Radial outward scatter on X and Z
			var scatter = Vector2(randf_range(-0.6, 0.6), randf_range(-0.6, 0.6))
			if doubloon.has_method("_trigger_spawn_bounce"):
				doubloon._trigger_spawn_bounce(scatter)

func _clean_shadow_nodes(node: Node) -> void:
	if not node:
		return
	var lower_name = node.name.to_lower()
	var is_shadow_node = false
	if "shadow" in lower_name or "decal" in lower_name or "projector" in lower_name or "card" in lower_name or "oblate" in lower_name or "shadow_sphere" in lower_name or "sphere_shadow" in lower_name:
		is_shadow_node = true
		
	if is_shadow_node:
		if node is Sprite3D or node is MeshInstance3D or node is Decal or node.get_class() == "Decal3D":
			node.queue_free()
			return
			
	if node is MeshInstance3D:
		if "shadow" in lower_name or "plane" in lower_name or "billboard" in lower_name or "card" in lower_name:
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			node.visible = false
			node.queue_free()
			return
			
	for child in node.get_children():
		_clean_shadow_nodes(child)
