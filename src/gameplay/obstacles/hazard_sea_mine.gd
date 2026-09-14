class_name HazardSeaMine
extends DestructibleObstacle

## Emitted when the mine detonates (past-tense event, Rule 1).
## Carries world position so listeners can apply area damage without coupling to mine internals.
signal mine_detonated(world_pos: Vector3)

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
			if area.has_method("take_hit"):
				area.take_hit(20, "sea_mine_collision")
			elif area.has_method("take_damage"):
				area.take_damage(20)
			elif "current_hp" in area:
				area.current_hp -= 20
				if area.current_hp <= 0 and area.has_method("die"):
					area.die()
		die()

## Canonical damage entry point — any hit detonates the mine.
func take_hit(_amount: int = 1, _source_info: String = "") -> void:
	die()

## Backward-compatible bridge so existing callers (cannonball._on_hit) keep working.
func take_damage(_amount: int = 1) -> void:
	die()

func die() -> void:
	if _is_destroyed:
		return
	var explosion_pos = global_position
	explosion_pos.y = 0.05
	_is_destroyed = true

	# Rule 4 — Immediate collider shutdown: prevent ghost contacts after detonation.
	collision_layer = 0
	collision_mask = 0
	for child in get_children():
		if child is CollisionShape3D:
			child.set_deferred("disabled", true)
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
	
	# Rule 2 — Call Down: the mine calls player.take_hit; player owns its own response
	# (camera shake, i-frames, lateral drift — all handled inside player.take_hit).
	# We never write to player.target_x or player.position directly.
	var player = get_tree().get_first_node_in_group("player")
	if player and is_instance_valid(player):
		var dist = explosion_pos.distance_to(player.global_position)
		if dist < 2.8:
			if player.has_method("take_hit"):
				player.take_hit(1, "sea_mine_knockback")
			elif player.has_method("leak_threat"):
				player.leak_threat(self)

	# Detonate / damage any nearby enemy vessels in explosion radius.
	# Rule 2 — Call Down: each enemy owns its own health; mine calls take_hit and stops there.
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and not enemy.is_in_group("boss") and not enemy.is_queued_for_deletion():
			if explosion_pos.distance_to(enemy.global_position) < 3.0:
				if enemy.has_method("take_hit"):
					enemy.take_hit(20, "sea_mine_explosion")
				elif enemy.has_method("take_damage"):
					enemy.take_damage(20)
				elif "current_hp" in enemy:
					enemy.current_hp -= 20
					if enemy.current_hp <= 0 and enemy.has_method("die"):
						enemy.die()
	
	doubloons_drop = 0 # Mine is a hazard and does not drop gold

	# Rule 1 — Signal Up: broadcast past-tense event.
	mine_detonated.emit(explosion_pos)
	
	# Safe removal
	queue_free()
