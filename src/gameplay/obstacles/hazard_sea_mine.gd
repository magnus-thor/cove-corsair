class_name HazardSeaMine
extends DestructibleObstacle

@export var explosion_scene: PackedScene = preload("res://src/vfx/vfx_mine_explosion.tscn")

func _ready() -> void:
	obstacle_type = ObstacleType.SEA_MINE
	super._ready()
	add_to_group("destructible")
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area3D) -> void:
	if _is_destroyed:
		return
	if area.is_in_group("player") or area.is_in_group("follower") or area.is_in_group("cannonballs") or area.is_in_group("enemies"):
		if area.is_in_group("enemies") and not area.is_in_group("boss"):
			if area.has_method("take_damage"):
				area.take_damage(20)
			elif "current_hp" in area:
				area.current_hp -= 20
				if area.current_hp <= 0 and area.has_method("die"):
					area.die()
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
	explosion_pos.y = 0.05
	_is_destroyed = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	
	# Spawn explosion VFX strictly at the mine's world coordinates
	if VFXManager and VFXManager.has_method("spawn_mine_explosion"):
		VFXManager.spawn_mine_explosion(explosion_pos)
	elif VFXManager and VFXManager.has_method("spawn_explosion"):
		VFXManager.spawn_explosion(explosion_pos)
	elif explosion_scene:
		var vfx = explosion_scene.instantiate() as Node3D
		vfx.top_level = true
		vfx.position = explosion_pos
		var root = get_tree().current_scene if get_tree() else null
		if root:
			root.add_child(vfx)
		vfx.global_position = explosion_pos

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

	# Detonate / damage any nearby enemy vessels in explosion radius
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and not enemy.is_in_group("boss") and not enemy.is_queued_for_deletion():
			if explosion_pos.distance_to(enemy.global_position) < 3.0:
				if enemy.has_method("take_damage"):
					enemy.take_damage(20)
				elif "current_hp" in enemy:
					enemy.current_hp -= 20
					if enemy.current_hp <= 0 and enemy.has_method("die"):
						enemy.die()
	
	doubloons_drop = 0 # Mine is a hazard and does not drop gold
	
	# Safe removal
	queue_free()
