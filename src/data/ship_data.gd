class_name ShipData
extends Resource

@export var ship_id: String = ""
@export var ship_name: String = ""
@export var model_scene: PackedScene = null
@export var sprite_texture: Texture2D
@export var pixel_size: float = 0.006
@export var y_offset: float = 0.485
@export var scale: Vector3 = Vector3(1.0, 1.0, 1.0)
@export var rotation_degrees: Vector3 = Vector3(-60.0, 0.0, 0.0)
@export var collision_size: Vector3 = Vector3(1.6, 1.0, 2.8)
@export var max_health: int = 100
@export var move_speed: float = 8.0
@export var fire_rate: float = 0.35
@export var base_cannons: int = 1
@export var hardpoint_offsets: Dictionary = {} # Maps socket names ("BowMount", etc.) to Vector3
@export var hardpoint_rotations: Dictionary = {} # Maps socket names to Vector3(pitch, yaw, roll) deg
@export var hardpoint_scales: Dictionary = {} # Maps socket names to Vector3 scale
## Optional per-vessel socket weapon overrides (maps socket name to WeaponData or resource path)
@export var socket_weapons: Dictionary = {}

## Normalized 3-tier upgrade schema (Section 2 of Progression Architecture doc)
## current_tier: the vessel's default/canonical starting tier (1–3)
@export var current_tier: int = 1
## upgrade_costs: index 0 = Tier 1 base cost (always 0), index 1 = cost to unlock Tier 2, index 2 = cost to unlock Tier 3
@export var upgrade_costs: Array[int] = [0, 350, 750]
## tier_descriptions: one human-readable summary string per tier for Shipyard UI tooltips
@export var tier_descriptions: Array[String] = []
## tier_sockets: array of string arrays — each sub-array lists the active socket names for that tier (index 0 = Tier 1)
@export var tier_sockets: Array[Array] = []
