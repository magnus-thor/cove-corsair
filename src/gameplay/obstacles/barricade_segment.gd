class_name BarricadeSegment
extends DestructibleObstacle

var hp_label: Label3D

func _ready() -> void:
	doubloons_drop = 1
	add_to_group("destructible")
	
	# Hide the default Sprite3D if it exists, as we will use a 3D log mesh
	var default_sprite = get_node_or_null("ObstacleSprite")
	if default_sprite:
		default_sprite.visible = false
		
	# Create dynamic HP Label3D
	hp_label = Label3D.new()
	hp_label.name = "HpLabel"
	hp_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	hp_label.no_depth_test = true
	hp_label.font_size = 64
	hp_label.outline_size = 16
	hp_label.outline_modulate = Color.BLACK
	
	add_child(hp_label)
	# Position the label slightly above the log mesh
	hp_label.position = Vector3(0.0, 1.2, 0.0)
	
	_update_label_visuals()

func _update_label_visuals() -> void:
	if not hp_label:
		return
	hp_label.text = str(hp)
	if hp <= 5:
		hp_label.modulate = Color(0.2, 1.0, 0.2) # green
	elif hp <= 15:
		hp_label.modulate = Color(1.0, 0.8, 0.2) # orange
	else:
		hp_label.modulate = Color(1.0, 0.2, 0.2) # red

func take_damage(amount: int) -> void:
	super.take_damage(amount)
	_update_label_visuals()
