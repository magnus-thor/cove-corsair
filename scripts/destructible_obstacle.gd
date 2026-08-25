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

@export var wooden_barrel_tex: Texture2D = preload("res://assets/sprites/wooden barrell.png")
@export var fuse_barrel_tex: Texture2D = preload("res://assets/sprites/Barrell with fuse.png")
@export var rune_barrel_tex: Texture2D = preload("res://assets/sprites/Barrell with runes.png")
@export var sea_mine_tex: Texture2D = preload("res://assets/sprites/Spiked Sea Mine.png")
@export var coral_reef_tex: Texture2D = preload("res://assets/sprites/Indestructible Coral Reef.png")

@onready var obstacle_sprite: Sprite3D = get_node_or_null("ObstacleSprite") as Sprite3D
@onready var barrel_model: Node3D = get_node_or_null("BarrelModel")

func _ready() -> void:
	update_obstacle_visuals()

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
			ObstacleType.FUSE_BARREL:
				tex = fuse_barrel_tex
				p_size = 0.00125
			ObstacleType.RUNE_BARREL:
				tex = rune_barrel_tex
				p_size = 0.00125
			ObstacleType.SEA_MINE:
				tex = sea_mine_tex
				p_size = 0.0013
			ObstacleType.CORAL_REEF:
				tex = coral_reef_tex
				p_size = 0.0015
				
		obstacle_sprite.texture = tex
		obstacle_sprite.pixel_size = p_size
		obstacle_sprite.billboard = 2
		obstacle_sprite.alpha_cut = 1

func take_damage(amount: int) -> void:
	hp -= amount
	if hp <= 0:
		print("Target destroyed! Score added.")
		var player = get_tree().get_first_node_in_group("player")
		if player:
			player.upgrade_ship(1)
		queue_free()
