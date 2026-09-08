class_name TurtleRaft
extends EnemyMob

func _ready() -> void:
	mob_type = "turtle_raft"
	super._ready()

func die() -> void:
	if _is_dead:
		return
	if VFXManager:
		VFXManager.spawn_wood_debris(global_position)
	super.die()
