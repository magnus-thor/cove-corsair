class_name EnemyCannonball
extends Area3D

@export var speed: float = 18.0
@export var lifetime: float = 3.5
var direction: Vector3 = Vector3(0, 0, 1)

func _ready() -> void:
	add_to_group("enemy_projectiles")
	area_entered.connect(_on_hit)
	body_entered.connect(_on_hit)

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

func _on_hit(target: Node) -> void:
	var is_player = target.is_in_group("player") or (target.get_parent() and target.get_parent().is_in_group("player"))
	var is_follower = target.is_in_group("follower") or (target.get_parent() and target.get_parent().is_in_group("follower"))
	
	if is_player or is_follower:
		var player = get_tree().get_first_node_in_group("player")
		if player:
			if is_follower:
				var follower = target
				if not follower.has_method("destroy_follower") and target.get_parent() and target.get_parent().has_method("destroy_follower"):
					follower = target.get_parent()
				if player.has_method("leak_threat"):
					player.leak_threat(follower)
				elif follower.has_method("destroy_follower"):
					follower.destroy_follower()
			else:
				if player.has_method("leak_threat"):
					player.leak_threat(player)
				else:
					player.current_health -= 1
					if player.has_signal("health_changed"):
						player.health_changed.emit(player.current_health, player.max_health)
					if player.current_health <= 0 and player.has_method("game_over"):
						player.game_over(false)
						
		var splash_scene = preload("res://src/gameplay/vfx/hit_splash.tscn")
		if splash_scene:
			var splash = splash_scene.instantiate() as Node3D
			var root = get_tree().current_scene
			if root:
				root.add_child(splash)
			splash.global_position = global_position
		queue_free()
