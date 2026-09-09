class_name HazardSeaMine
extends DestructibleObstacle

func _ready() -> void:
	obstacle_type = ObstacleType.SEA_MINE
	super._ready()
	add_to_group("destructible")
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area3D) -> void:
	if _is_destroyed:
		return
	if area.is_in_group("player") or area.is_in_group("follower") or area.is_in_group("cannonballs"):
		die()

## Override base take_damage so cannonball hits route through HazardSeaMine.die() only.
## The base class die() calls _apply_explosion_damage() which incorrectly spawns VFX
## and damage checks near the player rather than at the mine's position.
func take_damage(_amount: int) -> void:
	die()

func die() -> void:
	if _is_destroyed:
		return
	var explosion_pos = global_position
	_is_destroyed = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	
	# Sea mine explosion VFX/smoke completely removed per user request
	AudioManager.play_sfx("sfx_mine_detonate")
	
	# Apply knockback and deal 1 fleet damage to the player if close (direct contact)
	var player = get_tree().get_first_node_in_group("player")
	if player and is_instance_valid(player):
		var dist = explosion_pos.distance_to(player.global_position)
		if dist < 2.8:
			var knockback_dir = sign(player.global_position.x - explosion_pos.x)
			if knockback_dir == 0.0:
				knockback_dir = 1.0 if randf() < 0.5 else -1.0
			
			if "target_x" in player and "half_width" in player:
				player.target_x = clamp(player.target_x + knockback_dir * 2.8, -player.half_width, player.half_width)
				player.position.x = player.target_x
			
			# Deal 1 fleet/hull damage on direct contact
			if player.has_method("leak_threat"):
				player.leak_threat(self)
	
	doubloons_drop = 0 # Mine is a hazard and does not drop gold
	
	# Safe removal
	queue_free()
