class_name WeaponData
extends Resource

## Weapon Data Class
## Defines naval weapon mounts (Cannons, Swivel Guns, Mortars) that shoot forward
## along the vessel's heading with calibrated spread angles and ammo compatibility.

@export var weapon_name: String = "Forward Chaser"
@export var weapon_type: String = "cannon" # "cannon", "swivel_gun", "deck_mortar", "crew_musket", "crew_thrower"
@export var model_scene: PackedScene
@export var model_scale: Vector3 = Vector3(0.4, 0.4, 0.4)
@export var model_rotation_degrees: Vector3 = Vector3(0, 90, 0)
@export var model_offset: Vector3 = Vector3.ZERO
@export var sprite_texture: Texture2D
@export var pixel_size: float = 0.005
@export var fire_rate: float = 0.2 # Cooldown in seconds
@export var spread_angle_deg: float = 0.0 # Forward cone offset angle in degrees
@export var max_range: float = 38.0 # Maximum effective range in meters
@export var projectile_speed_mult: float = 1.0 # Multiplier applied to ammo projectile speed
@export var arc_height: float = 0.0 # Height of ballistic arc in meters (0.0 = flat naval trajectory)
@export var default_ammo: AmmoData
@export var compatible_ammo: Array[Resource] = []
@export var is_scatter: bool = false
@export var pellet_count: int = 5
@export var scatter_spread_deg: float = 30.0 # Horizontal cone spread angle (-15° to +15°)
@export var projectile_lifetime: float = 0.0 # If > 0, overrides projectile lifetime

func can_use_ammo(ammo: Resource) -> bool:
	if not ammo:
		return false
	if ammo == default_ammo:
		return true
	return compatible_ammo.has(ammo)

func get_firing_direction(base_forward: Vector3 = Vector3(0, 0, -1)) -> Vector3:
	return base_forward.rotated(Vector3.UP, deg_to_rad(spread_angle_deg)).normalized()
