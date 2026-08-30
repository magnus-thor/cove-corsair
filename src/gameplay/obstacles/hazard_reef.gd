extends Area3D

func _ready() -> void:
	add_to_group("hazard_reef")
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)

func _on_area_entered(area: Area3D) -> void:
	var player = _get_player(area)
	if player:
		if "active_reef_overlaps" in player:
			player.active_reef_overlaps += 1

func _on_area_exited(area: Area3D) -> void:
	var player = _get_player(area)
	if player:
		if "active_reef_overlaps" in player:
			player.active_reef_overlaps = max(0, player.active_reef_overlaps - 1)

func _get_player(area: Area3D) -> Node:
	if area.name == "CollisionArea" or area.is_in_group("player"):
		var parent = area.get_parent()
		if parent and parent.is_in_group("player"):
			return parent
		return get_tree().get_first_node_in_group("player")
	return null
