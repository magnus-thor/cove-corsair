@tool
class_name AttachedWeapon
extends Node3D

@export var weapon_data: WeaponData:
	set(val):
		weapon_data = val
		if is_node_ready():
			_apply_weapon_data()

@export var projectile_scene: PackedScene = preload("res://src/gameplay/projectiles/cannonball.tscn")

@onready var sprite_3d: Sprite3D = $Sprite3D
@onready var muzzle_point: Marker3D = $MuzzlePoint

var fire_timer: float = 0.0

func _ready() -> void:
	if weapon_data:
		_apply_weapon_data()

func setup_weapon(data: WeaponData) -> void:
	weapon_data = data
	if is_node_ready():
		_apply_weapon_data()

func _apply_weapon_data() -> void:
	if not weapon_data:
		return
	
	if sprite_3d:
		sprite_3d.texture = weapon_data.sprite_texture
		
		# Check weapon_type or data name to scale correctly
		var w_name = weapon_data.weapon_name.to_lower()
		var w_type = weapon_data.weapon_type.to_lower()
		
		if "swivel" in w_name or "bow" in w_name or "chaser" in w_name or w_type == "swivel_gun" or w_type == "cannon":
			sprite_3d.pixel_size = 0.0016
			sprite_3d.billboard = BaseMaterial3D.BILLBOARD_DISABLED
			sprite_3d.rotation_degrees = Vector3(-60.0, 0, 0)
		elif "crew" in w_name or "sniper" in w_name or "monkey" in w_name or w_type == "crew_musket":
			sprite_3d.pixel_size = 0.0018
			sprite_3d.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
			sprite_3d.rotation_degrees = Vector3(0.0, 0, 0)
		else:
			sprite_3d.pixel_size = 0.0028
			sprite_3d.billboard = BaseMaterial3D.BILLBOARD_DISABLED
			sprite_3d.rotation_degrees = Vector3(-60.0, 0, 0)
			
		sprite_3d.centered = true
		sprite_3d.offset = Vector2(0, 0)
		
		# Prevent z-fighting with the deck
		sprite_3d.render_priority = 3
		sprite_3d.position.y = 0.05
		
	# Apply default spread/offset angle if this is a static mount
	rotation_degrees.y = weapon_data.spread_angle_deg
	
	# Scale down the weapon node to fit the vessel appropriately
	match weapon_data.weapon_type:
		"swivel_gun":
			scale = Vector3(0.5, 0.5, 0.5)
		"crew_musket":
			scale = Vector3(0.55, 0.55, 0.55)
		"cannon":
			scale = Vector3(0.7, 0.7, 0.7)
		_:
			scale = Vector3(0.6, 0.6, 0.6)
	
	# Reset timer so weapons don't immediately fire at the same time if not aligned
	fire_timer = randf_range(0.0, weapon_data.fire_rate * 0.5)

	# If sprite_texture is null, show fallback mesh barrel
	var fallback = get_node_or_null("FallbackMesh") as MeshInstance3D
	if weapon_data.sprite_texture == null:
		if not fallback:
			fallback = MeshInstance3D.new()
			fallback.name = "FallbackMesh"
			var cylinder = CylinderMesh.new()
			cylinder.height = 0.5
			cylinder.top_radius = 0.1
			cylinder.bottom_radius = 0.1
			fallback.mesh = cylinder
			fallback.position = Vector3(0, 0.1, -0.25)
			fallback.rotation_degrees = Vector3(90, 0, 0)
			add_child(fallback)
		fallback.visible = true
	else:
		if fallback:
			fallback.visible = false

func _physics_process(delta: float) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player or player.is_game_over:
		return
		
	# If we target oncoming enemies, run targeting logic to rotate Y
	if weapon_data and weapon_data.weapon_type == "crew_musket":
		_process_targeting(delta)

func try_fire(projectile_scene, world_container = null) -> void:
	if projectile_scene is float or projectile_scene is int:
		var delta = float(projectile_scene)
		if not weapon_data:
			return
		fire_timer += delta
		if fire_timer >= weapon_data.fire_rate:
			fire_timer = 0.0
			var parent = get_tree().current_scene
			if not parent:
				parent = get_parent()
			_execute_fire(self.projectile_scene, parent)
	else:
		_execute_fire(projectile_scene, world_container)


func _execute_fire(proj_scene: PackedScene, world_container: Node) -> void:
	if not weapon_data or not proj_scene or not world_container or not muzzle_point:
		return
		
	AudioManager.play_sfx("cannon_shots")
	
	var ball = proj_scene.instantiate() as Area3D
	if ball:
		world_container.add_child(ball)
		# Set starting position strictly to $MuzzlePoint.global_position
		ball.global_position = muzzle_point.global_position
		
		# Calculate firing direction
		var fire_dir = -global_transform.basis.z.rotated(Vector3.UP, deg_to_rad(weapon_data.spread_angle_deg)).normalized()
		
		# Pass this direction and AmmoData parameters directly into cannonball.setup
		if ball.has_method("setup"):
			ball.setup(fire_dir, weapon_data.default_ammo)


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
