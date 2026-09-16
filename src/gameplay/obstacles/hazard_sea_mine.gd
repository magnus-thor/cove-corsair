class_name HazardSeaMine
extends DestructibleObstacle

## Emitted when the mine detonates (past-tense event, Rule 1).
## Carries world position so listeners can apply area damage without coupling to mine internals.
signal mine_detonated(world_pos: Vector3)

@export var explosion_scene: PackedScene = preload("res://src/vfx/vfx_mine_explosion.tscn")

## Blast radius for Area3D-based AoE damage (replaces the legacy group loop).
@export var blast_radius: float = 3.0

func _ready() -> void:
	obstacle_type = ObstacleType.SEA_MINE
	super._ready()
	add_to_group("destructible")
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area3D) -> void:
	if _is_destroyed:
		return
	# Any contact from player, followers, or cannonballs detonates the mine.
	# Enemy contacts that collide mid-lane also trigger detonation (but not bosses).
	if area.is_in_group("player") or area.is_in_group("follower") or area.is_in_group("cannonballs"):
		die()
	elif area.is_in_group("enemies") and not area.is_in_group("boss"):
		# Mine caught in enemy lane — detonate and deal blast damage to that enemy via take_hit
		if area.has_method("take_hit"):
			area.take_hit(20, "sea_mine_collision")
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

	# Rule D — Immediate collider shutdown: prevent ghost contacts after detonation.
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

	if VFXManager and VFXManager.has_method("hit_stop"):
		VFXManager.hit_stop(0.05)
	AudioManager.play_sfx("sfx_mine_detonate")

	# ── Rule C (SSOT): Area3D overlap scan replaces get_nodes_in_group loop. ─────────────────────
	# We query this Area3D's overlapping areas immediately before monitoring is disabled.
	# Each hit target handles its own damage response — no direct property mutation here.
	_apply_blast_damage(explosion_pos)

	doubloons_drop = 0 # Mine is a hazard and does not drop gold

	# Rule B — Signal Up: broadcast past-tense event.
	mine_detonated.emit(explosion_pos)
	
	# Safe removal
	queue_free()

## Applies blast-radius damage using the mine's own overlapping areas.
## This replaces the legacy get_nodes_in_group() loop and duck-typed current_hp mutations.
func _apply_blast_damage(explosion_pos: Vector3) -> void:
	# Player proximity check (player uses take_hit directly as it has no Hurtbox3D yet)
	var player = get_tree().get_first_node_in_group("player")
	if player and is_instance_valid(player):
		var dist = explosion_pos.distance_to(player.global_position)
		if dist < 2.8:
			if player.has_method("take_hit"):
				player.take_hit(1, "sea_mine_explosion")
			elif player.has_method("leak_threat"):
				player.leak_threat(self)

	# Enemy blast damage via already-overlapping areas (no tree scan needed)
	for area in get_overlapping_areas():
		if not is_instance_valid(area) or area.is_in_group("boss") or area.is_in_group("player"):
			continue
		if area.is_in_group("enemies") or area.is_in_group("destructible"):
			var dist = explosion_pos.distance_to((area as Node3D).global_position)
			if dist <= blast_radius:
				if area is Hurtbox3D:
					(area as Hurtbox3D).take_hit(20, "sea_mine_explosion")
				elif area.has_method("take_hit"):
					area.take_hit(20, "sea_mine_explosion")
				elif area.has_method("take_damage"):
					area.take_damage(20)

