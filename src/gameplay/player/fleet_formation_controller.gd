class_name FleetFormationController
extends Node

## Manages follower escort boat spawning, removal, fleet size caps,
## formation offset tables, and tween-animated repositioning.
## Owned by PlayerSwerve (player.gd).

signal follower_added(follower: Node3D)
signal follower_removed(follower: Node3D)

## Maximum number of escort followers (not counting the player ship itself).
const MAX_FOLLOWERS: int = 4

## The follower boat scene to instantiate.
@export var follower_scene: PackedScene

## Internal roster — ordered front-to-back; index 0 is the newest addition.
var _followers: Array[Node3D] = []

## Reference to the player CharacterBody3D (for parent and offset origin).
var _owner_body: CharacterBody3D = null


## Called by PlayerSwerve._ready() to wire up the owner body reference.
func setup(owner_body: CharacterBody3D) -> void:
	_owner_body = owner_body


# ── Public API ───────────────────────────────────────────────────────────────

## Add a single escort follower at the player's current position.
func add_follower() -> void:
	if _followers.size() >= MAX_FOLLOWERS or not follower_scene or not _owner_body:
		return
	var follower: Node3D = follower_scene.instantiate()
	var parent: Node = _owner_body.get_parent()
	if parent:
		parent.add_child(follower)
		follower.global_position = _owner_body.global_position
		follower.global_transform.basis = _owner_body.global_transform.basis
		_followers.append(follower)
		_update_formation()
		follower_added.emit(follower)


## Add multiple escort followers up to the fleet cap.
func add_followers(amount: int) -> void:
	var can_add: int = MAX_FOLLOWERS - _followers.size()
	var to_add: int = min(amount, can_add)
	for i: int in range(to_add):
		add_follower()


## Scale total fleet size by a multiplier (rounds to nearest integer, caps at 5 total ships).
func multiply_followers(multiplier: float) -> void:
	var current_total: int = _followers.size() + 1
	var new_total: int = int(round(current_total * multiplier))
	new_total = mini(new_total, 5)
	var extra_needed: int = new_total - current_total
	if extra_needed > 0:
		add_followers(extra_needed)


## Remove a specific follower from the formation.
func remove_follower(follower: Node3D) -> void:
	if follower in _followers:
		_followers.erase(follower)
		_update_formation()
		follower_removed.emit(follower)


## Returns the array of active escort followers.
func get_followers() -> Array[Node3D]:
	return _followers


## Returns the number of active escort followers.
func get_follower_count() -> int:
	return _followers.size()


## Returns the rearmost (outermost) follower, or null if the armada is empty.
func get_last_follower() -> Node3D:
	if _followers.is_empty():
		return null
	return _followers.back()


## Trigger a formation tween without adding or removing a ship.
func update_formation() -> void:
	_update_formation()


# ── Formation Tables ─────────────────────────────────────────────────────────

## Returns the local-space offsets for each ship given total fleet size
## (player ship counted as slot 0, followers fill slots 1…N).
func get_fleet_offsets(size: int) -> Array[Vector3]:
	match size:
		1:
			return [Vector3(0.0, 0.0, 0.0)]
		2:
			return [Vector3(-0.55, 0.0, 0.2), Vector3(0.55, 0.0, 0.2)]
		3:
			return [Vector3(0.0, 0.0, -0.35), Vector3(-0.65, 0.0, 0.35), Vector3(0.65, 0.0, 0.35)]
		4:
			return [Vector3(0.0, 0.0, -0.45), Vector3(-0.75, 0.0, 0.0), Vector3(0.75, 0.0, 0.0), Vector3(0.0, 0.0, 0.45)]
		5:
			return [Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.0, -0.55), Vector3(-0.75, 0.0, 0.0), Vector3(0.75, 0.0, 0.0), Vector3(0.0, 0.0, 0.55)]
		_:
			return [Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.0, -0.55), Vector3(-0.75, 0.0, 0.0), Vector3(0.75, 0.0, 0.0), Vector3(0.0, 0.0, 0.55)]


## Returns the uniform scale factor to apply to all ships at a given fleet size.
func get_fleet_scale_factor(size: int) -> float:
	match size:
		1: return 1.0
		2: return 0.80
		3: return 0.68
		4: return 0.58
		5: return 0.50
		_: return 0.50


# ── Internal ─────────────────────────────────────────────────────────────────

func _update_formation() -> void:
	if not _owner_body:
		return

	var size: int = _followers.size() + 1
	var offsets: Array[Vector3] = get_fleet_offsets(size)
	var target_sf: float = get_fleet_scale_factor(size)

	var tween: Tween = _owner_body.create_tween().set_parallel(true)

	# Reposition the player visuals and hardpoints to slot 0
	var visuals: Node3D = _owner_body.get_node_or_null("BoatVisuals")
	if visuals:
		tween.tween_property(visuals, "position:x", offsets[0].x, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(visuals, "position:z", offsets[0].z, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

		var sprite: Sprite3D = visuals.get_node_or_null("BoatSprite")
		if sprite:
			tween.tween_property(sprite, "scale", Vector3.ONE * target_sf, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	var hardpoints: Node3D = _owner_body.get_node_or_null("Hardpoints")
	if hardpoints:
		tween.tween_property(hardpoints, "position:x", offsets[0].x, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(hardpoints, "position:z", offsets[0].z, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(hardpoints, "scale", Vector3.ONE * target_sf, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	var body_col: CollisionShape3D = _owner_body.get_node_or_null("CollisionShape3D")
	if body_col:
		tween.tween_property(body_col, "scale", Vector3.ONE * target_sf, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	var area_col: CollisionShape3D = _owner_body.get_node_or_null("CollisionArea/CollisionShape3D")
	if area_col:
		tween.tween_property(area_col, "scale", Vector3.ONE * target_sf, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Reposition each follower escort to its slot
	for i: int in range(_followers.size()):
		var follower: Node3D = _followers[i]
		if is_instance_valid(follower):
			var f_offset: Vector3 = offsets[i + 1]
			if follower.has_method("set_target_offset"):
				follower.call("set_target_offset", f_offset)
			if follower.has_method("tween_scale"):
				follower.call("tween_scale", target_sf, 0.4)
