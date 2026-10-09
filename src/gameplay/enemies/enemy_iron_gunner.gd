class_name EnemyIronGunner
extends Area3D

@export var max_hp: int = 22
@export var current_hp: int = 22
@export var forward_speed: float = 2.6
@export var doubloons_drop: int = 4
@export var shoot_interval: float = 2.4
@export var can_shoot: bool = false
@export var is_gunner_vanguard: bool = false

@export var enemy_cannonball_scene: PackedScene = preload("res://src/gameplay/projectiles/enemy_cannonball.tscn")
@export var doubloon_scene: PackedScene = preload("res://src/gameplay/collectibles/collectible_doubloon.tscn")
@export var explosion_scene: PackedScene = preload("res://src/vfx/barrel_explosion.tscn")

@onready var sprite_node: Sprite3D = get_node_or_null("Sprite3D") as Sprite3D
@onready var collision_shape: CollisionShape3D = get_node_or_null("CollisionShape3D") as CollisionShape3D
@onready var health_bar_viewport: SubViewport = get_node_or_null("HealthBarViewport") as SubViewport
@onready var health_bar_sprite: Sprite3D = get_node_or_null("HealthBarSprite") as Sprite3D
@onready var progress_bar: ProgressBar = get_node_or_null("HealthBarViewport/HealthBarControl/ProgressBar") as ProgressBar

var _shoot_timer: float = 0.0
var _is_dead: bool = false
var _flash_tween: Tween
var _time: float = 0.0

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("destructible")
	if health_bar_sprite and health_bar_viewport:
		health_bar_sprite.texture = health_bar_viewport.get_texture()
	_apply_level_tuning()
	current_hp = max_hp
	_update_health_bar()
	_shoot_timer = randf_range(0.3, 0.8)

func _apply_level_tuning() -> void:
	var cur_lvl: int = 1
	var gs := get_node_or_null("/root/GameState")
	if gs and "current_level" in gs:
		cur_lvl = int(gs.current_level)
	if cur_lvl <= 3:
		max_hp = 4
		current_hp = 4
		forward_speed = 1.8
		shoot_interval = 2.8
	elif cur_lvl <= 5:
		max_hp = 5
		current_hp = 5
		forward_speed = 2.0
		shoot_interval = 2.6
	elif cur_lvl <= 9:
		max_hp = 10
		current_hp = 10
		forward_speed = 2.2
		shoot_interval = 2.4
	elif cur_lvl <= 15:
		max_hp = 22
		current_hp = 22
		forward_speed = 2.6
		shoot_interval = 2.2
	elif cur_lvl <= 30:
		max_hp = 36
		current_hp = 36
		forward_speed = 3.0
		shoot_interval = 1.9
	else:
		max_hp = 52
		current_hp = 52
		forward_speed = 3.4
		shoot_interval = 1.6

func _physics_process(delta: float) -> void:
	if _is_dead or not GameState.is_game_active:
		return
		
	_time += delta
	global_position.z += forward_speed * delta
	
	if sprite_node:
		sprite_node.position.y = 0.9 + sin(_time * 2.8) * 0.04
		
	# Shooting logic: only shoot if explicitly marked as gunner vanguard and not in boss fight
	var is_boss_active := GameState.boss_spawned or get_tree().get_first_node_in_group("boss") != null
	var player := get_tree().get_first_node_in_group("player")
	var player_z: float = player.global_position.z if player else 0.0
	var dist_to_player: Variant = abs(global_position.z - player_z)

	if (can_shoot or is_gunner_vanguard) and not is_boss_active and dist_to_player >= 14.0 and dist_to_player <= 45.0:
		_shoot_timer += delta
		if _shoot_timer >= shoot_interval:
			_shoot_timer = 0.0
			_fire_dual_cannons()
		
	if global_position.z > (player_z + 4.0):
		GameState.record_mob_leaked()
		if player and player.has_method("leak_threat"):
			player.leak_threat(self)
		queue_free()

func _fire_dual_cannons() -> void:
	if not enemy_cannonball_scene:
		return
		
	AudioManager.play_sfx("cannon_shots", 0.9, 1.1, 0.0)
	
	var cur_lvl: int = 1
	var gs := get_node_or_null("/root/GameState")
	if gs and "current_level" in gs:
		cur_lvl = int(gs.current_level)
		
	var offsets := [0.0] if cur_lvl <= 3 else [-0.6, 0.6]
	var player := get_tree().get_first_node_in_group("player")
	for offset_x in offsets:
		var ball := enemy_cannonball_scene.instantiate() as Area3D
		var root := get_tree().current_scene
		if root:
			root.add_child(ball)
		else:
			get_parent().add_child(ball)
		ball.global_position = global_position + Vector3(offset_x, 0.5, 1.2)
		if "speed" in ball:
			ball.speed = 12.5
		var fire_dir := Vector3(0, 0, 1)
		if player and is_instance_valid(player):
			var to_player: Vector3 = (player.global_position - ball.global_position)
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
	_update_health_bar()
	_flash()
	
	var ft_script := load("res://src/vfx/floating_text.gd")
	if ft_script:
		var fct: Variant = ft_script.new()
		var root := get_tree().current_scene
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
		var ratio := float(current_hp) / float(max_hp) if max_hp > 0 else 0.0
		progress_bar.modulate = Color(0.2, 0.9, 0.3).lerp(Color(1.0, 0.3, 0.1), 1.0 - ratio)

func die() -> void:
	if _is_dead:
		return
	# ── Engagement telemetry ─────────────────────────────────────────────────
	if EventBus and EventBus.has_signal("mob_killed"):
		var player_node: Node3D = get_tree().get_first_node_in_group("player") as Node3D
		var dist_to_player: float = 0.0
		if is_instance_valid(player_node):
			dist_to_player = absf(global_position.z - player_node.global_position.z)
		var river_dist: float = GameState.distance_traveled if GameState else 0.0
		EventBus.mob_killed.emit("iron_gunner", max_hp, dist_to_player, river_dist)

	GameState.targets_destroyed += 1
	AudioManager.play_sfx("barrel_breaks")
	
	if explosion_scene:
		var vfx := explosion_scene.instantiate() as Node3D
		var root := get_tree().current_scene
		if root:
			root.add_child(vfx)
		vfx.global_position = global_position
		vfx.scale = Vector3(1.6, 1.6, 1.6)
		
	if doubloon_scene:
		for i in range(doubloons_drop):
			var d := doubloon_scene.instantiate() as Area3D
			var root := get_tree().current_scene
			if root:
				root.add_child(d)
				d.global_position = global_position
				if d.has_method("_trigger_spawn_bounce"):
					d._trigger_spawn_bounce(Vector2(randf_range(-0.7, 0.7), randf_range(-0.7, 0.7)))
					
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("upgrade_ship"):
		player.upgrade_ship(1)
		
	queue_free()
