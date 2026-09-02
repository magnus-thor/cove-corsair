class_name EnemyMob
extends Area3D

@export var enemy_data: EnemyData = preload("res://src/data/resources/enemy_vessels/skeleton_rower.tres"):
	set(val):
		if enemy_data == val:
			return
		enemy_data = val
		if is_node_ready():
			apply_enemy_data(enemy_data)

## Fallback mob type string for backwards compatibility
@export var mob_type: String = "skeleton_rower":
	set(val):
		mob_type = val
		if is_node_ready() and not enemy_data:
			_apply_mob_type_fallback()

@export var max_hp: int = 3
@export var current_hp: int = 3
@export var forward_speed: float = 2.0
@export var doubloons_drop: int = 2

@export_group("Enemy Sprite Orientation")
@export var enemy_pitch_deg: float = -40.0

## Prefabs
@export var doubloon_scene: PackedScene = preload("res://src/gameplay/collectibles/collectible_doubloon.tscn")
@export var barrel_explosion_scene: PackedScene = preload("res://src/gameplay/vfx/barrel_explosion.tscn")
@export var enemy_cannonball_scene: PackedScene = preload("res://src/gameplay/projectiles/enemy_cannonball.tscn")

@onready var enemy_sprite: Sprite3D = $EnemySprite
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var health_bar_viewport: SubViewport = get_node_or_null("HealthBarViewport")
@onready var health_bar_progress: ProgressBar = get_node_or_null("HealthBarViewport/HealthBarControl/ProgressBar")
@onready var health_bar_sprite: Sprite3D = get_node_or_null("HealthBarSprite")

var _flash_tween: Tween
var _time: float = 0.0
var _is_dead: bool = false
var _current_base_y: float = 1.25
var shoot_cooldown_timer: float = 0.0

func _ready() -> void:
	_clean_shadow_nodes(self)
	add_to_group("enemies")
	add_to_group("destructible")
	
	area_entered.connect(_on_area_entered)
	
	if enemy_data:
		apply_enemy_data(enemy_data)
	else:
		_apply_mob_type_fallback()
		
	_update_health_bar()
	_time = randf_range(0.0, TAU)

func apply_enemy_data(data: EnemyData) -> void:
	if not data:
		return
		
	max_hp = data.max_hp
	current_hp = data.max_hp
	forward_speed = data.forward_speed
	doubloons_drop = data.doubloon_drop_count
	_current_base_y = data.y_offset
	
	if enemy_sprite:
		enemy_sprite.texture = data.sprite_texture
		enemy_sprite.pixel_size = data.pixel_size
		enemy_sprite.rotation_degrees = Vector3(enemy_pitch_deg, 0, 0)
		enemy_sprite.position = Vector3(0, data.y_offset, 0)
		enemy_sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		enemy_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		
	if collision_shape:
		var box = collision_shape.shape as BoxShape3D
		if not box:
			box = BoxShape3D.new()
			collision_shape.shape = box
		box.size = data.collision_size
		collision_shape.position = Vector3(0, data.collision_size.y * 0.5, 0)
		
	if health_bar_sprite:
		health_bar_sprite.position = Vector3(0, data.y_offset + 0.85, 0)
		
	_update_health_bar()

func _apply_mob_type_fallback() -> void:
	var path_map = {
		"skeleton_rower": "res://src/data/resources/enemy_vessels/skeleton_rower.tres",
		"raider_skiff": "res://src/data/resources/enemy_vessels/raider_skiff.tres",
		"goblin_skiff": "res://src/data/resources/enemy_vessels/raider_skiff.tres",
		"turtle_raft": "res://src/data/resources/enemy_vessels/turtle_raft.tres",
		"bone_beard": "res://src/data/resources/enemy_bosses/boss_bone_beard.tres"
	}
	if path_map.has(mob_type):
		var res = load(path_map[mob_type]) as EnemyData
		if res:
			apply_enemy_data(res)

func _physics_process(delta: float) -> void:
	if _is_dead or not GameState.is_game_active:
		return
		
	_time += delta
	
	# Constant downward river movement
	global_position.z += forward_speed * delta
	
	# Gentle floating bobbing
	if enemy_sprite:
		enemy_sprite.position.y = _current_base_y + sin(_time * 3.0) * 0.04
		
	var player = get_tree().get_first_node_in_group("player")
	var player_z = player.global_position.z if player else 0.0
	
	# Active Combatant Homing / Steering
	if has_meta("is_kamikaze") and get_meta("is_kamikaze") and player and is_instance_valid(player):
		global_position.x = move_toward(global_position.x, player.global_position.x, 2.5 * delta)
		
	# Active Combatant Shooting
	var mob_name_lower = ""
	if enemy_data:
		mob_name_lower = enemy_data.mob_name.to_lower()
	elif mob_type:
		mob_name_lower = mob_type.to_lower()
		
	if "raider" in mob_name_lower or "skiff" in mob_name_lower or "elite" in mob_name_lower or "ironclad" in mob_name_lower:
		shoot_cooldown_timer += delta
		var shoot_interval = 1.8
		if "elite" in mob_name_lower or "ironclad" in mob_name_lower:
			shoot_interval = 1.5
		if shoot_cooldown_timer >= shoot_interval:
			shoot_cooldown_timer = 0.0
			_fire_forward_cannonball()
		
	# Clean up and leak threat if passed behind the player boat
	if global_position.z > (player_z + 3.0):
		if player and player.has_method("leak_threat"):
			player.leak_threat(self)
		queue_free()

func _fire_forward_cannonball() -> void:
	if not enemy_cannonball_scene:
		return
		
	var ball = enemy_cannonball_scene.instantiate() as Area3D
	var root = get_tree().current_scene
	if root:
		root.add_child(ball)
	else:
		get_parent().add_child(ball)
		
	# Spawn slightly ahead in positive Z
	ball.global_position = global_position + Vector3(0.0, 0.4, 1.2)
	
	var ball_speed = 8.0
	var mob_name_lower = ""
	if enemy_data:
		mob_name_lower = enemy_data.mob_name.to_lower()
	elif mob_type:
		mob_name_lower = mob_type.to_lower()
		
	if "elite" in mob_name_lower or "ironclad" in mob_name_lower:
		ball_speed = 10.0
		
	if "direction" in ball:
		ball.direction = Vector3(0, 0, 1)
	if "speed" in ball:
		ball.speed = ball_speed
		
	AudioManager.play_sfx("cannon_shots", 0.9, 1.1, -4.0)

func _on_area_entered(area: Area3D) -> void:
	if _is_dead or not GameState.is_game_active:
		return
	# Colliding with player directly
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
	_flash_white()
	
	# Spawn floating combat text
	var ft_script = load("res://src/gameplay/vfx/floating_text.gd")
	if ft_script:
		var fct = ft_script.new()
		var root = get_tree().current_scene
		if root:
			root.add_child(fct)
			fct.global_position = global_position + Vector3(randf_range(-0.5, 0.5), 1.2, randf_range(-0.5, 0.5))
			fct.setup("-" + str(amount), Color(1.0, 0.3, 0.3))
			
	# NOTE: XP is awarded only on kill (in die()), not per hit, to prevent XP runaway.
	if current_hp <= 0:
		die()

func _flash_white() -> void:
	if not enemy_sprite:
		return
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
		
	_flash_tween = create_tween()
	_flash_tween.tween_property(enemy_sprite, "modulate", Color(2.5, 2.5, 2.5, 1.0), 0.06)
	_flash_tween.tween_property(enemy_sprite, "modulate", Color.WHITE, 0.1)

func _update_health_bar() -> void:
	if health_bar_progress:
		health_bar_progress.max_value = max_hp
		health_bar_progress.value = current_hp
		
		# Color lerp: Green -> Yellow -> Red
		var ratio = float(current_hp) / float(max_hp) if max_hp > 0 else 0.0
		if ratio > 0.5:
			health_bar_progress.modulate = Color(0.2, 0.9, 0.3).lerp(Color(1.0, 0.85, 0.1), (1.0 - ratio) * 2.0)
		else:
			health_bar_progress.modulate = Color(1.0, 0.85, 0.1).lerp(Color(0.95, 0.2, 0.2), (0.5 - ratio) * 2.0)

func die() -> void:
	if _is_dead:
		return
	_is_dead = true
	
	GameState.targets_destroyed += 1
	AudioManager.play_sfx("barrel_breaks")
	_spawn_explosion()
	_spawn_doubloons()
	
	# Trigger camera shake on death!
	var camera = get_tree().get_first_node_in_group("game_camera")
	if camera and camera.has_method("shake"):
		camera.shake(0.18, 0.16)
	
	var player = get_tree().get_first_node_in_group("player")
	if player:
		if player.has_method("upgrade_ship"):
			player.upgrade_ship(1)
		if player.has_method("add_evolution_xp"):
			player.add_evolution_xp(10.0)
		
	queue_free()

func _spawn_explosion() -> void:
	if barrel_explosion_scene:
		var vfx = barrel_explosion_scene.instantiate() as Node3D
		var root = get_tree().current_scene
		if root:
			root.add_child(vfx)
		elif get_parent():
			get_parent().add_child(vfx)
		vfx.global_position = global_position

func _spawn_doubloons() -> void:
	if not doubloon_scene or doubloons_drop <= 0:
		return
		
	var spawn_parent = get_tree().current_scene
	if not spawn_parent or spawn_parent == self:
		spawn_parent = get_parent()
		if spawn_parent == self or spawn_parent is EnemyMob:
			return
			
	for i in range(doubloons_drop):
		var doubloon = doubloon_scene.instantiate() as Area3D
		if doubloon:
			spawn_parent.add_child(doubloon)
			doubloon.global_position = Vector3(global_position.x, 0.05, global_position.z)
			var scatter = Vector2(randf_range(-0.8, 0.8), randf_range(-0.8, 0.8))
			if doubloon.has_method("_trigger_spawn_bounce"):
				doubloon._trigger_spawn_bounce(scatter)

func _clean_shadow_nodes(node: Node) -> void:
	if not node:
		return
	var lower_name = node.name.to_lower()
	var is_shadow_node = false
	if "shadow" in lower_name or "decal" in lower_name or "projector" in lower_name or "card" in lower_name or "oblate" in lower_name or "shadow_sphere" in lower_name or "sphere_shadow" in lower_name:
		is_shadow_node = true
		
	if is_shadow_node:
		if node is Sprite3D or node is MeshInstance3D or node is Decal or node.get_class() == "Decal3D":
			node.queue_free()
			return
			
	if node is MeshInstance3D:
		if "shadow" in lower_name or "plane" in lower_name or "billboard" in lower_name or "card" in lower_name:
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			node.visible = false
			node.queue_free()
			return
			
	for child in node.get_children():
		_clean_shadow_nodes(child)
