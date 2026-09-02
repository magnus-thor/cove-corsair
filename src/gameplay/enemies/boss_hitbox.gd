class_name BossHitbox
extends Area3D

func take_damage(amount: int) -> void:
	var parent = get_parent()
	if parent and parent.has_method("take_damage"):
		parent.take_damage(amount)
