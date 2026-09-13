class_name EnemyIronGunner
extends Area3D

@export var max_hp: int = 22
@export var current_hp: int = 22
@export var forward_speed: float = 2.6
@export var doubloons_drop: int = 4
@export var shoot_interval: float = 1.6

@export var enemy_cannonball_scene: PackedScene = preload("res://src/gameplay/projectiles/enemy_cannonball.tscn")
@export var doubloon_scene: PackedScene = preload("res://src/gameplay/collectibles/collectible_doubloon.tscn")
@export var explosion_scene: PackedScene = preload("res://src/gameplay/vfx/barrel_explosion.tscn")

@onready var sprite_node: Sprite3D = get_node_or_null("Sprite3D")
@onready var collision_shape: CollisionShape3D = get_node_or_null("CollisionShape3D")
@onready var progress_bar: ProgressBar = get_node_or_null("HealthBarViewport/HealthBarControl/ProgressBar")

var _shoot_timer: float = 0.0
var _is_dead: bool = false
var _flash_tween: Tween
var _time: float = 0.0

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("destructible")
	current_hp = max_hp
	_update_health_bar()
	_shoot_timer = randf_range(0.3, 0.8)

func _physics_process(delta: float) -> void:
	if _is_dead or not GameState.is_game_active:
		return
		
	_time += delta
	global_position.z += forward_speed * delta
	
	if sprite_node:
		sprite_node.position.y = 0.9 + sin(_time * 2.8) * 0.04
		
	_shoot_timer += delta
	if _shoot_timer >= shoot_interval:
		_shoot_timer = 0.0
		_fire_dual_cannons()
		
	var player = get_tree().get_first_node_in_group("player")
	var player_z = player.global_position.z if player else 0.0
	if global_position.z > (player_z + 4.0):
		GameState.record_mob_leaked()
		if player and player.has_method("leak_threat"):
			player.leak_threat(self)
		queue_free()

func _fire_dual_cannons() -> void:
	if not enemy_cannonball_scene:
		return
		
	AudioManager.play_sfx("cannon_shots", 0.9, 1.1, 0.0)
	
	var player = get_tree().get_first_node_in_group("player")
	for offset_x in [-0.6, 0.6]:
		var ball = enemy_cannonball_scene.instantiate() as Area3D
		var root = get_tree().current_scene
		if root:
			root.add_child(ball)
		else:
			get_parent().add_child(ball)
		ball.global_position = global_position + Vector3(offset_x, 0.5, 1.2)
		if "speed" in ball:
			ball.speed = 19.0
		var fire_dir = Vector3(0, 0, 1)
		if player and is_instance_valid(player):
			var to_player = (player.global_position - ball.global_position)
			to_player.y = 0.0
			if to_player.length_squared() > 0.01:
				fire_dir = to_player.normalized()
				if fire_dir.z < 0.1:
					fire_dir.z = 0.4
					fire_dir = fire_dir.normalized()
		if ball.has_method("setup"):
			ball.setup(fire_dir, null, null)
		if "direction" in ball:
			ball.direction = fire_dir
		ball.scale = Vector3(1.2, 1.2, 1.2)

func take_damage(amount: int) -> void:
	if _is_dead:
		return
	current_hp = max(0, current_hp - amount)
	if GameState.boss_spawned:
		print("[BOSS MINION HIT] Iron Gunner took %d dmg | HP: %d/%d" % [amount, current_hp, max_hp])
	_update_health_bar()
	_flash()
	
	var ft_script = load("res://src/gameplay/vfx/floating_text.gd")
	if ft_script:
		var fct = ft_script.new()
		var root = get_tree().current_scene
		if root:
			root.add_child(fct)
			fct.global_position = global_position + Vector3(randf_range(-0.4, 0.4), 1.3, randf_range(-0.4, 0.4))
			fct.setup("-" + str(amount), Color(1.0, 0.6, 0.2))
			
	if current_hp <= 0:
		die()

func _flash() -> void:
	if not sprite_node:
		return
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_property(sprite_node, "modulate", Color(2.5, 1.8, 1.2, 1.0), 0.05)
	_flash_tween.tween_property(sprite_node, "modulate", Color.WHITE, 0.1)

func _update_health_bar() -> void:
	if progress_bar:
		progress_bar.max_value = max_hp
		progress_bar.value = current_hp
		var ratio = float(current_hp) / float(max_hp) if max_hp > 0 else 0.0
		progress_bar.modulate = Color(0.2, 0.9, 0.3).lerp(Color(1.0, 0.3, 0.1), 1.0 - ratio)

func die() -> void:
	if _is_dead:
		return
	_is_dead = true
	GameState.targets_destroyed += 1
	AudioManager.play_sfx("barrel_breaks")
	
	if explosion_scene:
		var vfx = explosion_scene.instantiate() as Node3D
		var root = get_tree().current_scene
		if root:
			root.add_child(vfx)
		vfx.global_position = global_position
		vfx.scale = Vector3(1.6, 1.6, 1.6)
		
	if doubloon_scene:
		for i in range(doubloons_drop):
			var d = doubloon_scene.instantiate() as Area3D
			var root = get_tree().current_scene
			if root:
				root.add_child(d)
				d.global_position = global_position
				if d.has_method("_trigger_spawn_bounce"):
					d._trigger_spawn_bounce(Vector2(randf_range(-0.7, 0.7), randf_range(-0.7, 0.7)))
					
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("upgrade_ship"):
		player.upgrade_ship(1)
		
	queue_free()
