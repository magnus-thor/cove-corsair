class_name AmmoData
extends Resource

@export var ammo_name: String = "Standard Ball"
@export var damage: int = 1
@export var aoe_damage: int = 0 # AoE explosion damage if > 0 (defaults to damage if 0)
@export var projectile_speed: float = 18.0
@export var splash_radius: float = 0.0 # AoE explosion radius if > 0
@export var sprite_texture: Texture2D:
	get:
		if sprite_texture:
			return sprite_texture
		if sprite_texture_path != "" and FileAccess.file_exists(sprite_texture_path):
			var img = Image.load_from_file(sprite_texture_path)
			if img:
				sprite_texture = ImageTexture.create_from_image(img)
		return sprite_texture
@export var sprite_texture_path: String = ""
@export var scale_multiplier: float = 1.0
@export var pixel_size: float = 0.005
@export var y_offset: float = 0.0
@export var max_range_override: float = 0.0 # If > 0.0, overrides weapon's max range
@export var arc_height_bonus: float = 0.0 # Additional arc height in meters
@export var spins_in_flight: bool = false # Rotates end-over-end in flight (e.g. Throwing Axe)
