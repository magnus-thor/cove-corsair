class_name DestructibleObstacle
extends Area3D

enum ObstacleType { WOODEN_BARREL, FUSE_BARREL, RUNE_BARREL, SEA_MINE, CORAL_REEF }

## Visual obstacle HP
@export var hp: int = 3
@export var obstacle_type: ObstacleType = ObstacleType.WOODEN_BARREL:
	set(val):
		obstacle_type = val
		if is_node_ready():
			update_obstacle_visuals()

@export var doubloons_drop: int = 1
@export var doubloon_scene: PackedScene = preload("res://prefabs/collectible_doubloon.tscn")

@export var wooden_barrel_tex: Texture2D = preload("res://assets/sprites/wooden barrell.png")
@export var fuse_barrel_tex: Texture2D = preload("res://assets/sprites/Barrell with fuse.png")
@export var rune_barrel_tex: Texture2D = preload("res://assets/sprites/Barrell with runes.png")
@export var sea_mine_tex: Texture2D = preload("res://assets/sprites/Spiked Sea Mine.png")
@export var coral_reef_tex: Texture2D = preload("res://assets/sprites/Indestructible Coral Reef.png")

## Barrel destruction explosion VFX to spawn when destroyed
@export var barrel_explosion_scene: PackedScene = preload("res://prefabs/vfx/barrel_explosion.tscn")

@export var forward_speed: float = 0.0

@onready var obstacle_sprite: Sprite3D = get_node_or_null("ObstacleSprite") as Sprite3D
@onready var barrel_model: Node3D = get_node_or_null("BarrelModel")

var _is_destroyed: bool = false

func _ready() -> void:
	update_obstacle_visuals()

func _physics_process(delta: float) -> void:
	if _is_destroyed:
		return
	if forward_speed > 0.0:
		global_position.z += forward_speed * delta
		var player = get_tree().get_first_node_in_group("player")
		var player_z = player.global_position.z if player else 0.0
		if global_position.z > (player_z + 8.0):
			queue_free()

func update_obstacle_visuals() -> void:
	if obstacle_sprite:
		obstacle_sprite.visible = true
		if barrel_model:
			barrel_model.visible = false
			
		var tex: Texture2D = wooden_barrel_tex
		var p_size: float = 0.0012
		match obstacle_type:
			ObstacleType.WOODEN_BARREL:
				tex = wooden_barrel_tex
				p_size = 0.0012
				doubloons_drop = 1
			ObstacleType.FUSE_BARREL:
				tex = fuse_barrel_tex
				p_size = 0.00125
				doubloons_drop = 2
			ObstacleType.RUNE_BARREL:
				tex = rune_barrel_tex
				p_size = 0.00125
				doubloons_drop = 3
			ObstacleType.SEA_MINE:
				tex = sea_mine_tex
				p_size = 0.0013
				doubloons_drop = 2
			ObstacleType.CORAL_REEF:
				tex = coral_reef_tex
				p_size = 0.0015
				doubloons_drop = 4
				
		obstacle_sprite.texture = tex
		obstacle_sprite.pixel_size = p_size
		obstacle_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		obstacle_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD

func take_damage(amount: int) -> void:
	if _is_destroyed:
		return
	hp -= amount
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
	
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("upgrade_ship"):
		player.upgrade_ship(1)
	queue_free()

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
