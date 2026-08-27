class_name WeaponData
extends Resource

@export var weapon_name: String = "Forward Chaser"
@export var weapon_type: String = "cannon" # "cannon", "swivel_gun", "deck_mortar", "crew_musket"
@export var sprite_texture: Texture2D # Visual sprite attached to ship deck
@export var pixel_size: float = 0.005
@export var fire_rate: float = 0.35 # Cooldown in seconds
@export var spread_angle_deg: float = 0.0 # Offset angle in degrees
@export var default_ammo: AmmoData
