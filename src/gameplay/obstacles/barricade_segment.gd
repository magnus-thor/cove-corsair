class_name BarricadeSegment
extends DestructibleObstacle

func _ready() -> void:
	hp = 2
	doubloons_drop = 1
	add_to_group("destructible")
	
	# Hide the default Sprite3D if it exists, as we will use a 3D log mesh
	var default_sprite = get_node_or_null("ObstacleSprite")
	if default_sprite:
		default_sprite.visible = false
