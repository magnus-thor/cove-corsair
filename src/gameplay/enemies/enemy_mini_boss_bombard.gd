class_name EnemyMiniBossBombard
extends Area3D

@export var max_hp: int = 120
@export var current_hp: int = 120
@export var forward_speed: float = 1.3
@export var doubloons_drop: int = 22
@export var bombard_interval: float = 2.6

@export var doubloon_scene: PackedScene = preload("res://src/gameplay/collectibles/collectible_doubloon.tscn")
@export var explosion_scene: PackedScene = preload("res://src/vfx/barrel_explosion.tscn")

@onready var sprite_node: Sprite3D = get_node_or_null("Sprite3D")
@onready var collision_shape: CollisionShape3D = get_node_or_null("CollisionShape3D")
@onready var progress_bar: ProgressBar = get_node_or_null("HealthBarViewport/HealthBarControl/ProgressBar")

var _bombard_timer: float = 0.0
var _is_dead: bool = false
var _flash_tween: Tween
var _time: float = 0.0

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("destructible")
	current_hp = max_hp
	_update_health_bar()
	_bombard_timer = 0.8

func _physics_process(delta: float) -> void:
	if _is_dead or not GameState.is_game_active:
		return
		
	_time += delta
	global_position.z += forward_speed * delta
	
	if sprite_node:
		sprite_node.position.y = 1.2 + sin(_time * 2.5) * 0.05
		
	_bombard_timer += delta
	if _bombard_timer >= bombard_interval:
		_bombard_timer = 0.0
		_launch_heavy_bombard()
		
	var player := get_tree().get_first_node_in_group("player")
	var player_z: float = player.global_position.z if player else 0.0
	if global_position.z > (player_z + 4.5):
		GameState.record_mob_leaked()
		if player and player.has_method("leak_threat"):
			player.leak_threat(self)
		queue_free()

func _launch_heavy_bombard() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if not player or not is_instance_valid(player):
		return
		
	var target_pos: Vector3 = player.global_position + Vector3(randf_range(-1.0, 1.0), 0, randf_range(-0.5, 0.5))
	
	var reticle := Sprite3D.new()
	reticle.axis = Vector3.AXIS_Y
	reticle.double_sided = true
	var reticle_tex := preload("res://assets/sprites/ui/bombard_target_reticle.png")
	reticle.texture = reticle_tex
	reticle.pixel_size = 0.0058
	reticle.modulate = Color(1.2, 0.45, 0.1, 0.35)
	reticle.render_priority = 2
	
	get_tree().current_scene.add_child(reticle)
	reticle.global_position = Vector3(target_pos.x, 0.04, target_pos.z)
	
	AudioManager.play_sfx("cannon_shots", 0.6, 0.8, 2.0)
	
	var tween := reticle.create_tween()
	var vfx_scene := explosion_scene
	var tree := get_tree()
	tween.tween_property(reticle, "modulate:a", 1.0, 1.1).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(reticle, "rotation:y", PI * 0.4, 1.1)
	tween.tween_callback(Callable(EnemyMiniBossBombard, "execute_bombard_detonation").bind(reticle.global_position, vfx_scene, tree))
	tween.tween_callback(reticle.queue_free)

static func execute_bombard_detonation(pos: Vector3, vfx_prefab: PackedScene, tree: SceneTree) -> void:
	if not tree:
		return
	AudioManager.play_sfx("barrel_breaks", 0.6, 0.8, 3.0)
	AudioManager.play_sfx("cannon_shots", 0.5, 0.7, 3.0)
	
	if vfx_prefab:
		var vfx := vfx_prefab.instantiate() as Node3D
		var root := tree.current_scene
		if root:
			root.add_child(vfx)
		vfx.global_position = pos
		vfx.scale = Vector3(3.0, 3.0, 3.0)
		vfx.modulate = Color(2.5, 0.8, 0.2, 1.0)
		
	var camera := tree.get_first_node_in_group("game_camera")
	if camera and camera.has_method("shake"):
		camera.shake(0.3, 0.28)
		
	var player := tree.get_first_node_in_group("player")
	if player and is_instance_valid(player):
		var dist: float = player.global_position.distance_to(pos)
		if dist <= 2.6 and player.has_method("damage_fleet"):
			player.damage_fleet(1)

func _detonate_bombard(pos: Vector3) -> void:
	execute_bombard_detonation(pos, explosion_scene, get_tree())

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
			fct.global_position = global_position + Vector3(randf_range(-0.6, 0.6), 1.5, randf_range(-0.6, 0.6))
			fct.setup("-" + str(amount), Color(1.0, 0.5, 0.1))
			
	if current_hp <= 0:
		die()

func _flash() -> void:
	if not sprite_node:
		return
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_property(sprite_node, "modulate", Color(3.0, 1.8, 1.0, 1.0), 0.06)
	_flash_tween.tween_property(sprite_node, "modulate", Color(1.2, 0.8, 0.6, 1.0), 0.1)

func _update_health_bar() -> void:
	if progress_bar:
		progress_bar.max_value = max_hp
		progress_bar.value = current_hp
		var ratio := float(current_hp) / float(max_hp) if max_hp > 0 else 0.0
		progress_bar.modulate = Color(1.0, 0.7, 0.1).lerp(Color(1.0, 0.1, 0.1), 1.0 - ratio)

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
		EventBus.mob_killed.emit("mini_boss_bombard", max_hp, dist_to_player, river_dist)

	GameState.targets_destroyed += 1
	AudioManager.play_sfx("barrel_breaks", 0.6, 0.8, 3.0)
	
	var camera := get_tree().get_first_node_in_group("game_camera")
	if camera and camera.has_method("shake"):
		camera.shake(0.38, 0.32)
		
	for i in range(5):
		get_tree().create_timer(i * 0.1).timeout.connect(func() -> void:
			if explosion_scene:
				var vfx := explosion_scene.instantiate() as Node3D
				get_tree().current_scene.add_child(vfx)
				vfx.global_position = global_position + Vector3(randf_range(-1.8, 1.8), 0.5, randf_range(-1.8, 1.8))
				vfx.scale = Vector3(2.0, 2.0, 2.0)
				vfx.modulate = Color(2.5, 0.9, 0.2, 1.0)
		)
		
	if doubloon_scene:
		for i in range(doubloons_drop):
			var d := doubloon_scene.instantiate() as Area3D
			var root := get_tree().current_scene
			if root:
				root.add_child(d)
				d.global_position = global_position
				if d.has_method("_trigger_spawn_bounce"):
					d._trigger_spawn_bounce(Vector2(randf_range(-1.6, 1.6), randf_range(-1.6, 1.6)))
					
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("upgrade_ship"):
		player.upgrade_ship(2)
		
	queue_free()
