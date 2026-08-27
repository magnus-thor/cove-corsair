class_name AmmoData
extends Resource

@export var ammo_name: String = "Standard Ball"
@export var damage: int = 1
@export var projectile_speed: float = 18.0
@export var splash_radius: float = 0.0 # AoE explosion radius if > 0
@export var sprite_texture: Texture2D # custom projectile visual
@export var scale_multiplier: float = 1.0
