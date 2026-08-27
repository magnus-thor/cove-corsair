class_name EnemyData
extends Resource

@export var mob_name: String = ""
@export var sprite_texture: Texture2D
@export var pixel_size: float = 0.006
@export var max_hp: int = 3
@export var forward_speed: float = 2.0
@export var doubloon_drop_count: int = 2
@export var is_boss: bool = false
@export var y_offset: float = 1.0
@export var collision_size: Vector3 = Vector3(1.6, 1.2, 1.8)
