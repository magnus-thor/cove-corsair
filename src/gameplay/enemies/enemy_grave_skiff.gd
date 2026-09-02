class_name EnemyGraveSkiff
extends Area3D

@export var max_hp: int = 14
@export var current_hp: int = 14
@export var forward_speed: float = 3.2
@export var doubloons_drop: int = 3
@export var shoot_interval: float = 1.3
@export var burst_count: int = 2

@export var enemy_cannonball_scene: PackedScene = preload("res://src/gameplay/projectiles/enemy_cannonball.tscn")
@export var doubloon_scene: PackedScene = preload("res://src/gameplay/collectibles/collectible_doubloon.tscn")
@export var explosion_scene: PackedScene = preload("res://src/gameplay/vfx/barrel_explosion.tscn")

@onready var sprite_node: Sprite3D = get_node_or_null("Sprite3D")
@onready var collision_shape: CollisionShape3D = get_node_or_null("CollisionShape3D")
@onready var progress_bar: ProgressBar = get_node_or_null("HealthBarViewport/HealthBarControl/ProgressBar")

var _shoot_timer: float = 0.0
var _is_dead: bool = false
var _time: float = 0.0
var _flash_tween: Tween

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("destructible")
	current_hp = max_hp
	_update_health_bar()
	_time = randf_range(0.0, TAU)
	_shoot_timer = randf_range(0.2, 0.8)

func _physics_process(delta: float) -> void:
	if _is_dead or not GameState.is_game_active:
		return
		
	_time += delta
	global_position.z += forward_speed * delta
	
	if sprite_node:
		sprite_node.position.y = 1.0 + sin(_time * 4.0) * 0.05
		
	# Shooting logic - rapid blowdart burst
	_shoot_timer += delta
	if _shoot_timer >= shoot_interval:
		_shoot_timer = 0.0
		_fire_dart_burst()
		
	var player = get_tree().get_first_node_in_group("player")
	var player_z = player.global_position.z if player else 0.0
	if global_position.z > (player_z + 4.0):
		if player and player.has_method("leak_threat"):
			player.leak_threat(self)
		queue_free()

func _fire_dart_burst() -> void:
	if not enemy_cannonball_scene:
		return
	
	for i in range(burst_count):
		get_tree().create_timer(i * 0.18).timeout.connect(func():
			if _is_dead or not is_instance_valid(self):
				return
			var dart = enemy_cannonball_scene.instantiate() as Area3D
			var root = get_tree().current_scene
			if root:
				root.add_child(dart)
			else:
				get_parent().add_child(dart)
			dart.global_position = global_position + Vector3(randf_range(-0.3, 0.3), 0.4, 1.0)
			dart.scale = Vector3(0.85, 0.85, 0.85)
			var fire_mesh = dart.get_node_or_null("FireCore")
			if fire_mesh:
				fire_mesh.scale = Vector3(0.8, 0.8, 1.6)
			if "speed" in dart:
				dart.speed = 12.0
			if dart.has_method("set_color"):
				dart.set_color(Color(0.2, 1.0, 0.35)) # Toxic green glow
			AudioManager.play_sfx("cannon_shots", 1.4, 1.8, -4.0)
		)


func take_damage(amount: int) -> void:
	if _is_dead:
		return
	current_hp = max(0, current_hp - amount)
	print("[MOB HIT] Grave Skiff took %d damage | HP: %d/%d" % [amount, current_hp, max_hp])
	_update_health_bar()
	_flash()
	
	var ft_script = load("res://src/gameplay/vfx/floating_text.gd")
	if ft_script:
		var fct = ft_script.new()
		var root = get_tree().current_scene
		if root:
			root.add_child(fct)
			fct.global_position = global_position + Vector3(randf_range(-0.4, 0.4), 1.2, randf_range(-0.4, 0.4))
			fct.setup("-" + str(amount), Color(0.4, 1.0, 0.5))
			
	if current_hp <= 0:
		die()

func _flash() -> void:
	if not sprite_node:
		return
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_property(sprite_node, "modulate", Color(2.0, 2.5, 2.0, 1.0), 0.05)
	_flash_tween.tween_property(sprite_node, "modulate", Color.WHITE, 0.1)

func _update_health_bar() -> void:
	if progress_bar:
		progress_bar.max_value = max_hp
		progress_bar.value = current_hp
		var ratio = float(current_hp) / float(max_hp) if max_hp > 0 else 0.0
		progress_bar.modulate = Color(0.2, 0.9, 0.3).lerp(Color(0.9, 0.2, 0.2), 1.0 - ratio)

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
		
	if doubloon_scene:
		for i in range(doubloons_drop):
			var d = doubloon_scene.instantiate() as Area3D
			var root = get_tree().current_scene
			if root:
				root.add_child(d)
				d.global_position = global_position
				if d.has_method("_trigger_spawn_bounce"):
					d._trigger_spawn_bounce(Vector2(randf_range(-0.6, 0.6), randf_range(-0.6, 0.6)))
					
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("upgrade_ship"):
		player.upgrade_ship(1)
		
	queue_free()
