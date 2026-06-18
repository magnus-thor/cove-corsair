class_name DestructibleObstacle
extends Area3D

## Visual obstacle HP
@export var hp: int = 3

func take_damage(amount: int) -> void:
	hp -= amount
	if hp <= 0:
		print("Target destroyed! Score added.")
		var player = get_tree().get_first_node_in_group("player")
		if player:
			player.upgrade_ship(1)
		queue_free()
