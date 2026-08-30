class_name EnemyCannonball
extends Area3D

@export var speed: float = 18.0
@export var lifetime: float = 3.5

func _ready() -> void:
	add_to_group("enemy_projectiles")
	area_entered.connect(_on_hit)
	body_entered.connect(_on_hit)

func _physics_process(delta: float) -> void:
	global_position.z += speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

func _on_hit(target: Node) -> void:
	var hit_player = false
	if target.is_in_group("player"):
		hit_player = true
	elif target.get_parent() and target.get_parent().is_in_group("player"):
		hit_player = true
		
	if hit_player:
		var player = get_tree().get_first_node_in_group("player")
		if player and "current_health" in player:
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
