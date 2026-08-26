class_name EnemyMob
extends Area3D

## Enemy Mob Type identifier: "skeleton_rower", "goblin_skiff", "turtle_raft"
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

## Prefabs
@export var doubloon_scene: PackedScene = preload("res://prefabs/collectible_doubloon.tscn")
@export var barrel_explosion_scene: PackedScene = preload("res://prefabs/vfx/barrel_explosion.tscn")

@onready var enemy_sprite: Sprite3D = $EnemySprite
@onready var health_bar_viewport: SubViewport = get_node_or_null("HealthBarViewport")
@onready var health_bar_progress: ProgressBar = get_node_or_null("HealthBarViewport/HealthBarControl/ProgressBar")
@onready var health_bar_sprite: Sprite3D = get_node_or_null("HealthBarSprite")

var _flash_tween: Tween
var _time: float = 0.0
var _is_dead: bool = false

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
	var p_size: float = 0.0016
	
	match mob_type:
		"skeleton_rower":
			tex = skeleton_rower_tex
			p_size = 0.0016
			max_hp = 3 if max_hp == 3 else max_hp
			doubloons_drop = 2
		"goblin_skiff":
			tex = goblin_skiff_tex
			p_size = 0.0018
			max_hp = 4 if max_hp == 3 else max_hp
			forward_speed = max(forward_speed, 2.8)
			doubloons_drop = 3
		"turtle_raft":
			tex = turtle_raft_tex
			p_size = 0.0020
			max_hp = 6 if max_hp == 3 else max_hp
			forward_speed = min(forward_speed, 1.4)
			doubloons_drop = 4
		"ghost_sloop":
			tex = ghost_sloop_tex
			p_size = 0.0019
			max_hp = 5 if max_hp == 3 else max_hp
			doubloons_drop = 3
		_:
			tex = skeleton_rower_tex
			p_size = 0.0016
			
	enemy_sprite.texture = tex
	enemy_sprite.pixel_size = p_size
	current_hp = max_hp
	_update_health_bar()

func _physics_process(delta: float) -> void:
	if _is_dead:
		return
		
	_time += delta
	
	# Move forward down the track along +Z toward the player
	global_position.z += forward_speed * delta
	
	# Gentle water bobbing
	if enemy_sprite:
		enemy_sprite.position.y = 0.35 + sin(_time * 3.0) * 0.04
		
	# Clean up when past the player to prevent memory leaks
	var player = get_tree().get_first_node_in_group("player")
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
	if not doubloon_scene:
		return
		
	var root = get_tree().current_scene
	var spawn_parent = root if root else get_parent()
	if not spawn_parent:
		return
		
	for i in range(doubloons_drop):
		var doubloon = doubloon_scene.instantiate() as Area3D
		if doubloon:
			spawn_parent.add_child(doubloon)
			doubloon.global_position = global_position + Vector3(0, 0.5, 0)
			
			# Scatter slightly in X and Z
			var angle = randf_range(0.0, TAU)
			var dist = randf_range(0.6, 1.6)
			var scatter = Vector2(cos(angle) * dist, sin(angle) * dist)
			if doubloon.has_method("_trigger_spawn_bounce"):
				doubloon._trigger_spawn_bounce(scatter)

func _on_area_entered(area: Area3D) -> void:
	if _is_dead:
		return
		
	# Check if collided with player's boat detection area
	if area.is_in_group("player") or (area.get_parent() and area.get_parent().is_in_group("player")):
		die()
