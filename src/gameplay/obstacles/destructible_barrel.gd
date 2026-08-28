class_name DestructibleBarrel
extends DestructibleObstacle

## Destructible barrel obstacle variant

func die() -> void:
	super.die()
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("add_evolution_xp"):
		player.add_evolution_xp(15.0)
