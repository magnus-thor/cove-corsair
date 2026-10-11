class_name EnemyMiniBossHarvester
extends Area3D

@export var max_hp: int = 110
@export var current_hp: int = 110
@export var forward_speed: float = 1.4
@export var doubloons_drop: int = 18
@export var mortar_interval: float = 2.8

@export var enemy_cannonball_scene: PackedScene = preload("res://src/gameplay/projectiles/enemy_cannonball.tscn")
@export var biogas_pod_scene: PackedScene = preload("res://src/gameplay/obstacles/hazard_biogas_pod.tscn")
@export var doubloon_scene: PackedScene = preload("res://src/gameplay/collectibles/collectible_doubloon.tscn")
@export var explosion_scene: PackedScene = preload("res://src/vfx/barrel_explosion.tscn")

@onready var sprite_node: Sprite3D = get_node_or_null("Sprite3D") as Sprite3D
@onready var collision_shape: CollisionShape3D = get_node_or_null("CollisionShape3D") as CollisionShape3D
@onready var health_bar_viewport: SubViewport = get_node_or_null("HealthBarViewport") as SubViewport
@onready var health_bar_sprite: Sprite3D = get_node_or_null("HealthBarSprite") as Sprite3D
@onready var progress_bar: ProgressBar = get_node_or_null("HealthBarViewport/HealthBarControl/ProgressBar") as ProgressBar

var _mortar_timer: float = 0.0
var _is_dead: bool = false
var _flash_tween: Tween
var _time: float = 0.0

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("destructible")
	if health_bar_sprite and health_bar_viewport:
		health_bar_sprite.texture = health_bar_viewport.get_texture()
	current_hp = max_hp
	_update_health_bar()
	_mortar_timer = 1.0

func _physics_process(delta: float) -> void:
	if _is_dead or not GameState.is_game_active:
		return
		
	_time += delta
	global_position.z += forward_speed * delta
	
	# Slight sway and paddle rocking
	global_position.x += sin(_time * 1.5) * 0.8 * delta
	global_position.x = clampf(global_position.x, -4.1, 4.1)
	if sprite_node:
		sprite_node.position.y = 1.2 + sin(_time * 3.0) * 0.06
		
	var is_boss_active := GameState.boss_spawned or get_tree().get_first_node_in_group("boss") != null
	if not is_boss_active:
		_mortar_timer += delta
		if _mortar_timer >= mortar_interval:
			_mortar_timer = 0.0
			_launch_toxic_mortar()
		
	var player: PlayerSwerve = get_tree().get_first_node_in_group("player") as PlayerSwerve
	var player_z: float = player.global_position.z if player else 0.0
	if global_position.z > (player_z + 4.5):
		GameState.record_mob_leaked()
		if player:
			player.leak_threat(self)
		queue_free()

func _launch_toxic_mortar() -> void:
	var player: PlayerSwerve = get_tree().get_first_node_in_group("player") as PlayerSwerve
	if not player or not is_instance_valid(player):
		return
		
	var target_pos: Vector3 = player.global_position + Vector3(randf_range(-1.2, 1.2), 0, randf_range(-1.0, 1.0))
	
	# Telegraphed reticle on water
	var reticle := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 2.2
	disc.bottom_radius = 2.2
	disc.height = 0.02
	reticle.mesh = disc
	
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.2, 1.0, 0.4, 0.45)
	reticle.material_override = mat
	get_tree().current_scene.add_child(reticle)
	reticle.global_position = Vector3(target_pos.x, 0.03, target_pos.z)
	
	AudioManager.play_sfx("cannon_shots", 0.7, 0.9, 1.0)
	
	var tween := reticle.create_tween()
	var vfx_scene := explosion_scene
	var tree := get_tree()
	tween.tween_property(mat, "albedo_color:a", 0.8, 1.2).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(Callable(EnemyMiniBossHarvester, "execute_toxic_mortar_detonation").bind(reticle.global_position, vfx_scene, tree))
	tween.tween_callback(reticle.queue_free)

static func execute_toxic_mortar_detonation(pos: Vector3, vfx_prefab: PackedScene, tree: SceneTree) -> void:
	if not tree:
		return
	AudioManager.play_sfx("barrel_breaks", 0.8, 1.1, 2.0)
	AudioManager.play_sfx("water_splashes", 0.8, 1.0)
	
	if vfx_prefab:
		var vfx: Node3D = vfx_prefab.instantiate() as Node3D
		var root: Node = tree.current_scene
		if root:
			root.add_child(vfx)
		vfx.global_position = pos
		vfx.scale = Vector3(2.2, 2.2, 2.2)
		if "modulate" in vfx:
			vfx.set("modulate", Color(0.3, 1.8, 0.5, 1.0))
		
	var camera: GameCamera = tree.get_first_node_in_group("game_camera") as GameCamera
	if camera:
		camera.shake(0.25, 0.22)
		
	var player: PlayerSwerve = tree.get_first_node_in_group("player") as PlayerSwerve
	if player and is_instance_valid(player):
		var dist: float = player.global_position.distance_to(pos)
		if dist <= 2.2:
			player.damage_fleet(1)

func _detonate_toxic_mortar(pos: Vector3) -> void:
	execute_toxic_mortar_detonation(pos, explosion_scene, get_tree())

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
		fct.global_position = global_position + Vector3(randf_range(-0.6, 0.6), 1.5, randf_range(-0.6, 0.6))
		fct.setup("-" + str(amount), Color(0.2, 1.0, 0.6))
			
	if current_hp <= 0:
		die()

func _flash() -> void:
	if not sprite_node:
		return
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_property(sprite_node, "modulate", Color(2.5, 2.5, 2.0, 1.0), 0.06)
	_flash_tween.tween_property(sprite_node, "modulate", Color.WHITE, 0.1)

func _update_health_bar() -> void:
	if progress_bar:
		progress_bar.max_value = max_hp
		progress_bar.value = current_hp
		var ratio := float(current_hp) / float(max_hp) if max_hp > 0 else 0.0
		progress_bar.modulate = Color(0.2, 0.95, 0.4).lerp(Color(1.0, 0.2, 0.2), 1.0 - ratio)

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
		EventBus.mob_killed.emit("mini_boss_harvester", max_hp, dist_to_player, river_dist)

	GameState.targets_destroyed += 1
	AudioManager.play_sfx("barrel_breaks", 0.7, 0.9, 3.0)
	
	var camera: GameCamera = get_tree().get_first_node_in_group("game_camera") as GameCamera
	if camera:
		camera.shake(0.35, 0.3)
		
	# Multiple hull explosions
	for i in range(4):
		get_tree().create_timer(i * 0.12).timeout.connect(func() -> void:
			if explosion_scene:
				var vfx: Node3D = explosion_scene.instantiate() as Node3D
				get_tree().current_scene.add_child(vfx)
				vfx.global_position = global_position + Vector3(randf_range(-1.5, 1.5), 0.4, randf_range(-1.5, 1.5))
				vfx.scale = Vector3(1.8, 1.8, 1.8)
		)
		
	if doubloon_scene:
		for i in range(doubloons_drop):
			var d: CollectibleDoubloon = doubloon_scene.instantiate() as CollectibleDoubloon
			var root: Node = get_tree().current_scene
			if root:
				root.add_child(d)
				d.global_position = global_position
				d._trigger_spawn_bounce(Vector2(randf_range(-1.5, 1.5), randf_range(-1.5, 1.5)))
					
	var player: PlayerSwerve = get_tree().get_first_node_in_group("player") as PlayerSwerve
	if player:
		player.upgrade_ship(2)
		
	queue_free()
