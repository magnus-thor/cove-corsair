class_name HazardReef
extends Area3D

var _has_damaged_player: bool = false

func _ready() -> void:
	add_to_group("hazard_reef")
	add_to_group("obstacles")
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

func _physics_process(_delta: float) -> void:
	var player = get_tree().get_first_node_in_group("player")
	var player_z = player.global_position.z if player else 0.0
	if global_position.z > (player_z + 8.0):
		queue_free()

func _on_area_entered(area: Area3D) -> void:
	_check_collision(area)

func _on_body_entered(body: Node3D) -> void:
	_check_collision(body)

func _check_collision(node: Node) -> void:
	if not node or not is_instance_valid(node):
		return

	# 1. Check enemy craft collision: solid jagged reef wrecks any enemy vessel that crashes into it!
	var is_enemy: bool = node.is_in_group("enemies") or (node.get_parent() and node.get_parent().is_in_group("enemies"))
	if is_enemy and not node.is_in_group("player"):
		var enemy_node: Node = node if node.is_in_group("enemies") else node.get_parent()
		if enemy_node and is_instance_valid(enemy_node):
			AudioManager.play_sfx("barrel_breaks", 0.75, 1.05)
			var explosion_scene: PackedScene = preload("res://src/vfx/barrel_explosion.tscn")
			if explosion_scene:
				var vfx: Node3D = explosion_scene.instantiate() as Node3D
				var root: Node = get_tree().current_scene
				if root and vfx:
					root.add_child(vfx)
					vfx.global_position = (enemy_node as Node3D).global_position if enemy_node is Node3D else global_position
			if enemy_node.has_method("die"):
				enemy_node.call("die")
			elif enemy_node.has_method("take_damage"):
				enemy_node.call("take_damage", 999)
			else:
				enemy_node.queue_free()
		return

	# 2. Check player collision: damages fleet/hull
	if _has_damaged_player:
		return
	var player: Node = _get_player(node)
	if player and is_instance_valid(player):
		_has_damaged_player = true
		if player.has_method("damage_fleet"):
			player.damage_fleet(1, "hazard_reef")
		AudioManager.play_sfx("barrel_breaks", 0.7, 0.9, 2.0)
		var camera: Node = get_tree().get_first_node_in_group("game_camera")
		if camera and camera.has_method("shake"):
			camera.call("shake", 0.25, 0.2)

func _get_player(node: Node) -> Node:
	if not node:
		return null
	if node.is_in_group("player"):
		return node
	if node.get_parent() and node.get_parent().is_in_group("player"):
		return node.get_parent()
	return null

func take_damage(_amount: int) -> void:
	# Indestructible coral reef: deflects shots without losing HP
	AudioManager.play_sfx("barrel_hits", 0.6, 0.8)
