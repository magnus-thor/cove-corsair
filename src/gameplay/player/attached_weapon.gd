class_name AttachedWeapon
extends Node3D

@export var weapon_data: WeaponData:
	set(val):
		weapon_data = val
		if is_node_ready():
			_apply_weapon_data()

@export var projectile_scene: PackedScene = preload("res://src/gameplay/projectiles/cannonball.tscn")

@onready var sprite_3d: Sprite3D = $Sprite3D
@onready var muzzle: Marker3D = $Muzzle

var fire_timer: float = 0.0

func _ready() -> void:
	if weapon_data:
		_apply_weapon_data()

func _apply_weapon_data() -> void:
	if not weapon_data:
		return
	
	if sprite_3d:
		sprite_3d.texture = weapon_data.sprite_texture
		sprite_3d.pixel_size = weapon_data.pixel_size
		# Ensure we keep the visual tilt of -60.0 deg on X so it fits the ship's 2.5D perspective
		sprite_3d.rotation_degrees = Vector3(-60.0, 0, 0)
		
	# Apply default spread/offset angle if this is a static mount
	# (Deckhand sniper will dynamically target, but we start with default)
	rotation_degrees.y = weapon_data.spread_angle_deg
	
	# Reset timer so weapons don't immediately fire at the same time if not aligned
	fire_timer = randf_range(0.0, weapon_data.fire_rate * 0.5)

func _physics_process(delta: float) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player or player.is_game_over:
		return
		
	# If we target oncoming enemies, run targeting logic to rotate Y
	if weapon_data and weapon_data.weapon_type == "crew_musket":
		_process_targeting(delta)
		
	if player.is_shooting_enabled:
		fire_timer += delta
		if weapon_data and fire_timer >= weapon_data.fire_rate:
			fire_timer = 0.0
			fire()

func _process_targeting(delta: float) -> void:
	var player = get_tree().get_first_node_in_group("player")
	var player_z = player.global_position.z if player else global_position.z
	
	var enemies = get_tree().get_nodes_in_group("enemies")
	var best_enemy: Node3D = null
	var min_dist = INF
	
	for enemy in enemies:
		if not is_instance_valid(enemy) or not enemy is Node3D:
			continue
			
		# Check if enemy is oncoming (further upstream, meaning smaller Z coord)
		if enemy.global_position.z >= player_z:
			continue
			
		var dist = global_position.distance_to(enemy.global_position)
		if dist < min_dist:
			min_dist = dist
			best_enemy = enemy
			
	if best_enemy:
		# Calculate rotation to face the target horizontally (ignore Y differences)
		var diff = best_enemy.global_position - global_position
		var target_angle_rad = atan2(-diff.x, -diff.z)
		var target_angle_deg = rad_to_deg(target_angle_rad)
		
		# Smoothly rotate around Y to face enemy (e.g. 180 degrees/sec)
		rotation_degrees.y = rotate_toward(rotation_degrees.y, target_angle_deg, 180.0 * delta)
	else:
		# Return smoothly to default angle
		var default_angle = weapon_data.spread_angle_deg if weapon_data else 0.0
		rotation_degrees.y = rotate_toward(rotation_degrees.y, default_angle, 90.0 * delta)

func fire() -> void:
	if not weapon_data or not projectile_scene or not muzzle:
		return
		
	AudioManager.play_sfx("cannon_shots")
	
	var parent = get_tree().current_scene
	if not parent:
		parent = get_parent()
		
	var ball = projectile_scene.instantiate() as Area3D
	if ball:
		parent.add_child(ball)
		# Position at muzzle, rotate to match muzzle horizontal heading
		ball.global_position = muzzle.global_position
		ball.global_rotation = Vector3(0.0, muzzle.global_rotation.y, 0.0)
		
		# Assign custom ammo parameters
		if "ammo_data" in ball:
			ball.ammo_data = weapon_data.default_ammo
