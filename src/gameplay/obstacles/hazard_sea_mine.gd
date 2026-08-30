class_name HazardSeaMine
extends DestructibleObstacle

func _ready() -> void:
	obstacle_type = ObstacleType.SEA_MINE
	super._ready()
	add_to_group("destructible")

func die() -> void:
	if _is_destroyed:
		return
	_is_destroyed = true
	
	_spawn_explosion()
	AudioManager.play_sfx("barrel_breaks")
	
	# Apply knockback to the player if close (meaning they touched the mine)
	var player = get_tree().get_first_node_in_group("player")
	if player and is_instance_valid(player):
		var dist = global_position.distance_to(player.global_position)
		if dist < 2.8:
			var knockback_dir = sign(player.global_position.x - global_position.x)
			if knockback_dir == 0.0:
				knockback_dir = 1.0 if randf() < 0.5 else -1.0
			
			if "target_x" in player and "half_width" in player:
				player.target_x = clamp(player.target_x + knockback_dir * 2.8, -player.half_width, player.half_width)
				player.position.x = player.target_x
	
	doubloons_drop = 0 # Mine is a hazard and does not drop gold
	
	# Safe removal
	queue_free()
