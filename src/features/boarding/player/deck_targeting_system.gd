class_name DeckTargetingSystem
extends Node

## Handles screen-to-world raycasting for mobile touch and desktop clicks,
## resolving priority targets (Ropes > Boarders > Deck Zones).

signal target_acquired(target_node: Node3D, world_position: Vector3)
signal zone_focused(zone_id: String)

@export var camera: Camera3D = null
@export var ray_length: float = 120.0
@export_flags_3d_physics var target_collision_mask: int = (1 << 0) | (1 << 2) | (1 << 3) # Layer 1 (Deck), Layer 3 (Enemies), Layer 4 (Ropes)

func process_input_event(event: InputEvent) -> void:
	if not is_instance_valid(camera):
		return
		
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_cast_selection_ray(mb.position)
	elif event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event as InputEventScreenTouch
		if st.pressed:
			_cast_selection_ray(st.position)

func _cast_selection_ray(screen_pos: Vector2) -> void:
	if not is_instance_valid(camera):
		return
		
	var from: Vector3 = camera.project_ray_origin(screen_pos)
	var to: Vector3 = from + camera.project_ray_normal(screen_pos) * ray_length
	
	var space_state: PhysicsDirectSpaceState3D = camera.get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, target_collision_mask)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	
	var result: Dictionary = space_state.intersect_ray(query)
	if result.is_empty():
		return
		
	var hit_collider: Object = result["collider"]
	var hit_pos: Vector3 = result["position"]
	
	# Resolve node hierarchy
	var resolved_node: Node3D = null
	if hit_collider is Node3D:
		var n: Node3D = hit_collider as Node3D
		if n is BoarderEnemy or n.is_in_group("boarder"):
			resolved_node = n
		elif n is BoardingPlank:
			resolved_node = n
		elif n.get_parent() is BoardingPlank:
			resolved_node = n.get_parent() as Node3D
		elif n is BoardingZone:
			var zone: BoardingZone = n as BoardingZone
			zone_focused.emit(zone.zone_id)
			_select_priority_in_zone(zone, hit_pos)
			return
		elif n.get_parent() is BoardingZone:
			var p_zone: BoardingZone = n.get_parent() as BoardingZone
			zone_focused.emit(p_zone.zone_id)
			_select_priority_in_zone(p_zone, hit_pos)
			return

	target_acquired.emit(resolved_node, hit_pos)

func _select_priority_in_zone(zone: BoardingZone, fallback_pos: Vector3) -> void:
	# Priority 1: Active boarding plank on this zone
	if not zone.active_planks.is_empty():
		var plank: Node3D = zone.active_planks[0]
		if is_instance_valid(plank):
			target_acquired.emit(plank, plank.global_position)
			return
	elif not zone.active_grapples.is_empty():
		var rope: Node3D = zone.active_grapples[0]
		if is_instance_valid(rope):
			target_acquired.emit(rope, rope.global_position)
			return
		
	# Priority 2: Closest active enemy in zone
	if not zone.active_boarders.is_empty():
		var enemy: Node3D = zone.active_boarders[0]
		if is_instance_valid(enemy):
			target_acquired.emit(enemy, enemy.global_position)
			return
		
	# Priority 3: Zone station anchor
	if is_instance_valid(zone.station_marker):
		target_acquired.emit(null, zone.station_marker.global_position)
	elif is_instance_valid(zone.grapple_anchor):
		target_acquired.emit(null, zone.grapple_anchor.global_position)
	else:
		target_acquired.emit(null, fallback_pos)
