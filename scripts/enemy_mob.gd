class_name EnemyMob
extends Area3D

## Enemy Mob Type identifier: "skeleton_rower", "goblin_skiff", "turtle_raft", "ghost_sloop", "bone_beard"
@export var mob_type: String = "skeleton_rower":
	set(val):
		mob_type = val
		if is_node_ready():
			_apply_mob_type()

@export var max_hp: int = 3
@export var current_hp: int = 3
@export var forward_speed: float = 2.0
@export var doubloons_drop: int = 2

## References to sprites
@export var skeleton_rower_tex: Texture2D = preload("res://assets/sprites/Skeleton Rower.png")
@export var goblin_skiff_tex: Texture2D = preload("res://assets/sprites/Goblin Skiff 2.png")
@export var turtle_raft_tex: Texture2D = preload("res://assets/sprites/Armored Turtle-Raft.png")
@export var ghost_sloop_tex: Texture2D = preload("res://assets/sprites/Ghost Sloop.png")
@export var bone_beard_tex: Texture2D = preload("res://assets/sprites/Captain Bone-Beard’s Twin Frigate.png")

@export_group("Enemy Sprite Pixel Sizes")
@export var skeleton_rower_pixel_size: float = 0.00250
@export var goblin_skiff_pixel_size: float = 0.00300
@export var turtle_raft_pixel_size: float = 0.00300
@export var ghost_sloop_pixel_size: float = 0.00300
@export var bone_beard_pixel_size: float = 0.00550

@export_group("Enemy Sprite Y Offsets")
@export var skeleton_rower_y_offset: float = 0.968
@export var goblin_skiff_y_offset: float = 1.555
@export var turtle_raft_y_offset: float = 1.555
@export var ghost_sloop_y_offset: float = 1.625
@export var bone_beard_y_offset: float = 2.612

@export_group("Enemy Sprite Orientation")
@export var enemy_pitch_deg: float = -40.0

@export_group("Enemy Collision Sizes")
@export var skeleton_rower_collision_size: Vector3 = Vector3(1.6, 1.2, 1.8)
@export var goblin_skiff_collision_size: Vector3 = Vector3(1.9, 1.2, 2.0)
@export var turtle_raft_collision_size: Vector3 = Vector3(2.4, 1.3, 2.4)
@export var ghost_sloop_collision_size: Vector3 = Vector3(2.1, 1.3, 2.4)
@export var bone_beard_collision_size: Vector3 = Vector3(4.4, 1.6, 2.8)

## Prefabs
@export var doubloon_scene: PackedScene = preload("res://prefabs/collectible_doubloon.tscn")
@export var barrel_explosion_scene: PackedScene = preload("res://prefabs/vfx/barrel_explosion.tscn")

@onready var enemy_sprite: Sprite3D = $EnemySprite
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var health_bar_viewport: SubViewport = get_node_or_null("HealthBarViewport")
@onready var health_bar_progress: ProgressBar = get_node_or_null("HealthBarViewport/HealthBarControl/ProgressBar")
@onready var health_bar_sprite: Sprite3D = get_node_or_null("HealthBarSprite")

var _flash_tween: Tween
var _time: float = 0.0
var _is_dead: bool = false
var _current_base_y: float = 1.25

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("destructible")
	
	area_entered.connect(_on_area_entered)
	
	_apply_mob_type()
	_update_health_bar()
	
	# Initial random phase for water bobbing
	_time = randf_range(0.0, TAU)

func _apply_mob_type() -> void:
	if not enemy_sprite:
		return
		
	var tex: Texture2D = skeleton_rower_tex
	var p_size: float = skeleton_rower_pixel_size
	var col_size: Vector3 = skeleton_rower_collision_size
	var base_y: float = skeleton_rower_y_offset
	var health_y: float = 2.1
	
	match mob_type:
		"skeleton_rower":
			tex = skeleton_rower_tex
			p_size = skeleton_rower_pixel_size
			col_size = skeleton_rower_collision_size
			base_y = skeleton_rower_y_offset
			max_hp = 3 if max_hp == 3 else max_hp
			doubloons_drop = 2
			health_y = base_y + 0.85
		"goblin_skiff":
			tex = goblin_skiff_tex
			p_size = goblin_skiff_pixel_size
			col_size = goblin_skiff_collision_size
			base_y = goblin_skiff_y_offset
			max_hp = 4 if max_hp == 3 else max_hp
			forward_speed = max(forward_speed, 2.8)
			doubloons_drop = 3
			health_y = base_y + 1.15
		"turtle_raft":
			tex = turtle_raft_tex
			p_size = turtle_raft_pixel_size
			col_size = turtle_raft_collision_size
			base_y = turtle_raft_y_offset
			max_hp = 6 if max_hp == 3 else max_hp
			forward_speed = min(forward_speed, 1.4)
			doubloons_drop = 4
			health_y = base_y + 1.15
		"ghost_sloop":
			tex = ghost_sloop_tex
			p_size = ghost_sloop_pixel_size
			col_size = ghost_sloop_collision_size
			base_y = ghost_sloop_y_offset
			max_hp = 5 if max_hp == 3 else max_hp
			doubloons_drop = 3
			health_y = base_y + 1.15
		"bone_beard", "boss_frigate", "twin_frigate":
			tex = bone_beard_tex
			p_size = bone_beard_pixel_size
			col_size = bone_beard_collision_size
			base_y = bone_beard_y_offset
			max_hp = 18 if max_hp == 3 else max_hp
			forward_speed = min(forward_speed, 1.0)
			doubloons_drop = 8
			health_y = base_y + 1.8
		_:
			tex = skeleton_rower_tex
			p_size = skeleton_rower_pixel_size
			col_size = skeleton_rower_collision_size
			base_y = skeleton_rower_y_offset
			health_y = base_y + 0.85
			
	_current_base_y = base_y
	enemy_sprite.texture = tex
	enemy_sprite.pixel_size = p_size
	enemy_sprite.position.y = base_y
	enemy_sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	enemy_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	enemy_sprite.rotation_degrees = Vector3(enemy_pitch_deg, 0, 0)
	
	# Adjust collision shape to match sprite size
	if collision_shape:
		var box = collision_shape.shape as BoxShape3D
		if not box:
			box = BoxShape3D.new()
			collision_shape.shape = box
		box.size = col_size
		collision_shape.position = Vector3(0, base_y * 0.5, 0)
		
	# Adjust health bar height
	if health_bar_sprite:
		health_bar_sprite.position.y = health_y
		
	current_hp = max_hp
	_update_health_bar()

func _physics_process(delta: float) -> void:
	if _is_dead:
		return
		
	var player = get_tree().get_first_node_in_group("player")
	if player and "is_calibration_mode" in player and player.is_calibration_mode:
		return
		
	if not GameState.is_game_active:
		return
		
	_time += delta
	
	# Move forward down the track along +Z toward the player
	global_position.z += forward_speed * delta
	
	# Gentle water bobbing around the calibrated base Y
	if enemy_sprite:
		enemy_sprite.position.y = _current_base_y + sin(_time * 3.0) * 0.04
		
	# Clean up when past the player to prevent memory leaks
	var player_z = player.global_position.z if player else 0.0
	if global_position.z > (player_z + 10.0):
		queue_free()

func take_damage(amount: int) -> void:
	if _is_dead:
		return
		
	current_hp = max(0, current_hp - amount)
	_update_health_bar()
	_flash_red()
	AudioManager.play_sfx("barrel_hits")
	
	if current_hp <= 0:
		die()

func _flash_red() -> void:
	if not enemy_sprite:
		return
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
		
	_flash_tween = create_tween()
	_flash_tween.tween_property(enemy_sprite, "modulate", Color(2.5, 0.2, 0.2, 1.0), 0.07)
	_flash_tween.tween_property(enemy_sprite, "modulate", Color.WHITE, 0.12)

func _update_health_bar() -> void:
	if health_bar_progress:
		health_bar_progress.max_value = max_hp
		health_bar_progress.value = current_hp
		
		# Change color based on health percentage
		var pct = float(current_hp) / float(max_hp) if max_hp > 0 else 0.0
		if pct > 0.5:
			health_bar_progress.modulate = Color(0.2, 0.9, 0.3, 1.0)
		elif pct > 0.25:
			health_bar_progress.modulate = Color(0.95, 0.8, 0.1, 1.0)
		else:
			health_bar_progress.modulate = Color(0.95, 0.2, 0.2, 1.0)

func die() -> void:
	if _is_dead:
		return
	_is_dead = true
	
	GameState.targets_destroyed += 1
	AudioManager.play_sfx("barrel_breaks")
	_spawn_death_explosion()
	_spawn_doubloons()
	
	# Upgrade / credit player
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("upgrade_ship"):
		player.upgrade_ship(1)
		
	queue_free()

func _spawn_death_explosion() -> void:
	if barrel_explosion_scene:
		var vfx = barrel_explosion_scene.instantiate() as Node3D
		var root = get_tree().current_scene
		if root:
			root.add_child(vfx)
		elif get_parent():
			get_parent().add_child(vfx)
		vfx.global_position = global_position + Vector3(0, 0.5, 0)

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
			# Spawn strictly at water surface level (Y = 0.05)
			doubloon.global_position = Vector3(global_position.x, 0.05, global_position.z)
			
			# Radial outward scatter on X and Z
			var scatter = Vector2(randf_range(-0.6, 0.6), randf_range(-0.6, 0.6))
			if doubloon.has_method("_trigger_spawn_bounce"):
				doubloon._trigger_spawn_bounce(scatter)

func _on_area_entered(area: Area3D) -> void:
	if _is_dead:
		return
		
	# Check if collided with player's boat detection area
	if area.is_in_group("player") or (area.get_parent() and area.get_parent().is_in_group("player")):
		die()
