class_name ShipData
extends Resource

@export var ship_id: String = ""
@export var ship_name: String = ""
@export var sprite_texture: Texture2D
@export var pixel_size: float = 0.006
@export var y_offset: float = 0.485
@export var collision_size: Vector3 = Vector3(1.6, 1.0, 2.8)
@export var max_health: int = 100
@export var move_speed: float = 8.0
@export var fire_rate: float = 0.35
@export var base_cannons: int = 1
@export var hardpoint_offsets: Dictionary = {} # Maps socket names ("BowMount", etc.) to Vector3
@export var hardpoint_rotations: Dictionary = {} # Maps socket names to Vector3(pitch, yaw, roll) deg
@export var hardpoint_scales: Dictionary = {} # Maps socket names to Vector3 scale
@export var tier_upgrades: Array[Dictionary] = [] # Complete upgrade roadmap per ship
