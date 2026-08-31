class_name EnemyBrimstoneRaft
extends Area3D

@export var max_hp: int = 18
@export var current_hp: int = 18
@export var forward_speed: float = 7.8
@export var steer_speed: float = 4.5
@export var doubloons_drop: int = 3

@export var doubloon_scene: PackedScene = preload("res://src/gameplay/collectibles/collectible_doubloon.tscn")
@export var explosion_scene: PackedScene = preload("res://src/gameplay/vfx/barrel_explosion.tscn")

@onready var sprite_node: Sprite3D = get_node_or_null("Sprite3D")
@onready var progress_bar: ProgressBar = get_node_or_null("HealthBarViewport/HealthBarControl/ProgressBar")

var _is_dead: bool = false
var _flash_tween: Tween

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("destructible")
	current_hp = max_hp
	_update_health_bar()
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	if _is_dead or not GameState.is_game_active:
		return
		
	# High-speed rush
	global_position.z += forward_speed * delta
	
	# Homing towards player
	var player = get_tree().get_first_node_in_group("player")
	if player and is_instance_valid(player):
		var target_x = player.global_position.x
		global_position.x = move_toward(global_position.x, target_x, steer_speed * delta)
		
	var player_z = player.global_position.z if player else 0.0
	if global_position.z > (player_z + 3.0):
		if player and player.has_method("leak_threat"):
			player.leak_threat(self)
		queue_free()

func _on_area_entered(area: Area3D) -> void:
	if _is_dead:
		return
	if area.is_in_group("player") or (area.get_parent() and area.get_parent().is_in_group("player")):
		var player = get_tree().get_first_node_in_group("player")
		if player and "current_health" in player:
			player.current_health -= 1
			if player.has_signal("health_changed"):
				player.health_changed.emit(player.current_health, player.max_health)
			if player.current_health <= 0 and player.has_method("game_over"):
				player.game_over(false)
		die()

func take_damage(amount: int) -> void:
	if _is_dead:
		return
	current_hp = max(0, current_hp - amount)
	_update_health_bar()
	_flash()
	
	var ft_script = load("res://src/gameplay/vfx/floating_text.gd")
	if ft_script:
		var fct = ft_script.new()
		var root = get_tree().current_scene
		if root:
			root.add_child(fct)
			fct.global_position = global_position + Vector3(randf_range(-0.3, 0.3), 1.2, randf_range(-0.3, 0.3))
			fct.setup("-" + str(amount), Color(1.0, 0.3, 0.1))
			
	if current_hp <= 0:
		die()

func _flash() -> void:
	if not sprite_node:
		return
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_property(sprite_node, "modulate", Color(3.0, 1.5, 0.5, 1.0), 0.05)
	_flash_tween.tween_property(sprite_node, "modulate", Color(1.5, 0.6, 0.3, 1.0), 0.1)

func _update_health_bar() -> void:
	if progress_bar:
		progress_bar.max_value = max_hp
		progress_bar.value = current_hp
		var ratio = float(current_hp) / float(max_hp) if max_hp > 0 else 0.0
		progress_bar.modulate = Color(1.0, 0.8, 0.2).lerp(Color(1.0, 0.15, 0.1), 1.0 - ratio)

func die() -> void:
	if _is_dead:
		return
	_is_dead = true
	GameState.targets_destroyed += 1
	AudioManager.play_sfx("barrel_breaks", 0.8, 1.1, 2.0)
	
	if explosion_scene:
		var vfx = explosion_scene.instantiate() as Node3D
		var root = get_tree().current_scene
		if root:
			root.add_child(vfx)
		vfx.global_position = global_position
		vfx.scale = Vector3(2.0, 2.0, 2.0)
		vfx.modulate = Color(2.5, 0.8, 0.2, 1.0)
		
	var camera = get_tree().get_first_node_in_group("game_camera")
	if camera and camera.has_method("shake"):
		camera.shake(0.25, 0.22)
		
	if doubloon_scene:
		for i in range(doubloons_drop):
			var d = doubloon_scene.instantiate() as Area3D
			var root = get_tree().current_scene
			if root:
				root.add_child(d)
				d.global_position = global_position
				if d.has_method("_trigger_spawn_bounce"):
					d._trigger_spawn_bounce(Vector2(randf_range(-0.8, 0.8), randf_range(-0.8, 0.8)))
					
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("upgrade_ship"):
		player.upgrade_ship(1)
		
	queue_free()
