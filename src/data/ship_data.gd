class_name ShipData
extends Resource

@export var ship_name: String = ""
@export var sprite_texture: Texture2D
@export var pixel_size: float = 0.006
@export var base_cannons: int = 1
@export var fire_rate: float = 0.35
@export var max_health: int = 100
@export var move_speed: float = 8.0
@export var y_offset: float = 0.485
@export var collision_size: Vector3 = Vector3(1.6, 1.0, 2.8)
