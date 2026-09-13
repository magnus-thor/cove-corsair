class_name BossProjectileTwinCannonSalvo
extends EnemyCannonball

const SPRITE_PATH: String = "res://assets/sprites/ammo/boss_ammo_fire_twin_cannon_salvo.png"

@export var sprite_texture: Texture2D

func _ready() -> void:
	var spr = get_node_or_null("AmmoSprite") as Sprite3D
	if not spr:
		spr = get_node_or_null("Sprite3D") as Sprite3D
	
	if spr:
		if sprite_texture:
			spr.texture = sprite_texture
		elif not spr.texture:
			if ResourceLoader.exists(SPRITE_PATH):
				var res = load(SPRITE_PATH)
				if res is Texture2D:
					spr.texture = res
			if not spr.texture and FileAccess.file_exists(SPRITE_PATH):
				var img = Image.load_from_file(SPRITE_PATH)
				if img:
					spr.texture = ImageTexture.create_from_image(img)
					
	set_meta("is_fire", true)
	super._ready()
	attach_fire_trail()
