class_name BarricadeSegment
extends DestructibleObstacle

var hp_label: Label3D

static func get_tier_hp(level: int) -> int:
	if level <= 3:
		return 2
	elif level <= 10:
		return 6
	elif level <= 25:
		return 12
	else:
		return 20

func _ready() -> void:
	doubloons_drop = 1
	add_to_group("destructible")
	add_to_group("barricade")
	
	var cur_level: int = 1
	if has_node("/root/GameState"):
		var gs = get_node("/root/GameState")
		if "current_level" in gs:
			cur_level = int(gs.current_level)
			
	var tier_hp = get_tier_hp(cur_level)
	if cur_level <= 10:
		if hp <= 1 or hp > tier_hp:
			hp = tier_hp
	elif cur_level <= 25:
		if hp <= 1 or hp == 20:
			hp = tier_hp
	else:
		if hp <= 1:
			hp = tier_hp

	
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

func _physics_process(delta: float) -> void:
	if _is_destroyed or not GameState.is_game_active:
		return
	if forward_speed > 0.0:
		global_position.z += forward_speed * delta
	# Barricade slats are static river wall components.
	# When the player shoots a gap and steers through, the remaining intact slats
	# must NEVER inflict leak_threat damage.
	# The parent chunk cleans up at +30m behind the camera; as a fallback,
	# slats clean up if they drift > 35m behind the player.
	var player = get_tree().get_first_node_in_group("player")
	var player_z = player.global_position.z if player else 0.0
	if global_position.z > (player_z + 35.0):
		queue_free()

func _update_label_visuals() -> void:
	if not hp_label:
		return
	hp_label.text = str(hp)
	if hp <= 5:
		hp_label.modulate = Color(0.2, 1.0, 0.2) # green  – almost dead
	elif hp <= 25:
		hp_label.modulate = Color(1.0, 0.8, 0.2) # orange – half health
	else:
		hp_label.modulate = Color(1.0, 0.2, 0.2) # red    – full health

## Canonical damage entry point (Rule 2). Delegates to take_damage so label stays in sync.
func take_hit(amount: int, _source_info: String = "") -> void:
	take_damage(amount)

func take_damage(amount: int) -> void:
	super.take_damage(amount)
	_update_label_visuals()

func die() -> void:
	if _is_destroyed:
		return
	collision_layer = 0
	collision_mask = 0
	var col = get_node_or_null("CollisionShape3D")
	if col:
		col.set_deferred("disabled", true)
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	if VFXManager:
		VFXManager.spawn_wood_debris(global_position)
	AudioManager.play_sfx("sfx_wood_smash")
	super()
