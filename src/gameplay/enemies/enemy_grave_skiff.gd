class_name EnemyGraveSkiff
extends Area3D

@export var max_hp: int = 14
@export var current_hp: int = 14
@export var forward_speed: float = 3.2
@export var doubloons_drop: int = 2
@export var shoot_interval: float = 1.3
@export var burst_count: int = 2
@export var can_shoot: bool = false

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
var _time: float = 0.0
var _flash_tween: Tween

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("destructible")
	if health_bar_sprite and health_bar_viewport:
		health_bar_sprite.texture = health_bar_viewport.get_texture()
	current_hp = max_hp
	_update_health_bar()
	_time = randf_range(0.0, TAU)
	_shoot_timer = randf_range(0.2, 0.8)

func _physics_process(delta: float) -> void:
	if _is_dead or not GameState.is_game_active:
		return
		
	_time += delta
	if sprite_node:
		sprite_node.position.y = 1.0 + sin(_time * 4.0) * 0.05
		
	if global_position.z < -55.0:
		return
		
	global_position.z += forward_speed * delta
		
	# Shooting logic - only if can_shoot is enabled and not during boss fight
	var is_boss_active: bool = GameState.boss_spawned or get_tree().get_first_node_in_group("boss") != null
	var player: PlayerSwerve = get_tree().get_first_node_in_group("player") as PlayerSwerve
	var player_z: float = player.global_position.z if player else 0.0
	var dist_to_player: float = abs(global_position.z - player_z)
	
	if can_shoot and not is_boss_active and dist_to_player >= 14.0 and dist_to_player <= 45.0:
		_shoot_timer += delta
		if _shoot_timer >= shoot_interval:
			_shoot_timer = 0.0
			_fire_dart_burst()
		
	if global_position.z > (player_z + 4.0):
		GameState.record_mob_leaked()
		if player:
			player.leak_threat(self)
		queue_free()

func _fire_dart_burst() -> void:
	if not enemy_cannonball_scene:
		return
	var boss_node: Node = get_tree().get_first_node_in_group("boss")
	if boss_node != null and is_instance_valid(boss_node) and bool(boss_node.get("is_barrage_active")):
		return
	
	for i in range(burst_count):
		get_tree().create_timer(i * 0.18).timeout.connect(func() -> void:
			if _is_dead or not is_instance_valid(self):
				return
			var dart: EnemyCannonball = enemy_cannonball_scene.instantiate() as EnemyCannonball
			var root: Node = get_tree().current_scene
			if root:
				root.add_child(dart)
			else:
				get_parent().add_child(dart)
			dart.global_position = global_position + Vector3(randf_range(-0.3, 0.3), 0.4, 1.0)
			dart.scale = Vector3(0.85, 0.85, 0.85)
			var fire_mesh: Node3D = dart.get_node_or_null("FireCore") as Node3D
			if fire_mesh:
				fire_mesh.scale = Vector3(0.8, 0.8, 1.6)
			dart.speed = 18.0
			var player: PlayerSwerve = get_tree().get_first_node_in_group("player") as PlayerSwerve
			var fire_dir: Vector3 = Vector3(0, 0, 1)
			if player and is_instance_valid(player):
				var to_player: Vector3 = (player.global_position - dart.global_position)
				to_player.y = 0.0
				if to_player.length_squared() > 0.01:
					fire_dir = to_player.normalized()
					if fire_dir.z < 0.1:
						fire_dir.z = 0.4
						fire_dir = fire_dir.normalized()
			dart.setup(fire_dir, null, null)
			dart.direction = fire_dir
			dart.set_color(Color(0.2, 1.0, 0.35)) # Toxic green glow
			AudioManager.play_sfx("cannon_shots", 1.4, 1.8, -4.0)
		)


func take_damage(amount: int) -> void:
	if _is_dead:
		return
	current_hp = max(0, current_hp - amount)
	_update_health_bar()
	_flash()
	
	var fct: FloatingText = FloatingText.new()
	var root: Node = get_tree().current_scene
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
		var ratio := float(current_hp) / float(max_hp) if max_hp > 0 else 0.0
		progress_bar.modulate = Color(0.2, 0.9, 0.3).lerp(Color(0.9, 0.2, 0.2), 1.0 - ratio)

func die() -> void:
	if _is_dead:
		return
	_is_dead = true
	collision_layer = 0
	collision_mask = 0
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	# ── Engagement telemetry ─────────────────────────────────────────────────
	if EventBus and EventBus.has_signal("mob_killed"):
		var player_node: Node3D = get_tree().get_first_node_in_group("player") as Node3D
		var dist_to_player: float = 0.0
		if is_instance_valid(player_node):
			dist_to_player = absf(global_position.z - player_node.global_position.z)
		var river_dist: float = GameState.distance_traveled if GameState else 0.0
		EventBus.mob_killed.emit("grave_skiff", max_hp, dist_to_player, river_dist)

	GameState.targets_destroyed += 1
	AudioManager.play_sfx("barrel_breaks")
	
	if explosion_scene:
		var vfx := explosion_scene.instantiate() as Node3D
		var root := get_tree().current_scene
		if root:
			root.add_child(vfx)
		vfx.global_position = global_position
		
	if doubloon_scene:
		for i: int in range(doubloons_drop):
			var d: CollectibleDoubloon = doubloon_scene.instantiate() as CollectibleDoubloon
			var root: Node = get_tree().current_scene
			if root:
				root.add_child(d)
				d.global_position = global_position
				d._trigger_spawn_bounce(Vector2(randf_range(-0.6, 0.6), randf_range(-0.6, 0.6)))
					
	var player: PlayerSwerve = get_tree().get_first_node_in_group("player") as PlayerSwerve
	if player:
		player.upgrade_ship(1)
		
	queue_free()
