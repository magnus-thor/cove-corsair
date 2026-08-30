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
var idle_timer: float = 0.0
var wander_timer: float = 0.0
var aim_direction: Vector3 = Vector3(0, 0, -1)
var current_target: Node3D = null
var throw_tween: Tween = null
var wander_tween: Tween = null
var hop_in_done: bool = false

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
		
		var w_name = weapon_data.weapon_name.to_lower()
		var w_type = weapon_data.weapon_type.to_lower()
		
		var is_crew = (w_type == "crew_thrower" or w_type == "crew_musket" or "crew" in w_name or "monkey" in w_name or "skeleton" in w_name)
		
		if is_crew:
			sprite_3d.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
			sprite_3d.rotation_degrees = Vector3.ZERO
			sprite_3d.render_priority = 4
			sprite_3d.pixel_size = 0.0022
			sprite_3d.position.y = 0.12
		elif "swivel" in w_name or "bow" in w_name or "chaser" in w_name or w_type == "swivel_gun" or w_type == "cannon":
			sprite_3d.pixel_size = weapon_data.pixel_size if weapon_data.pixel_size > 0.0 else 0.0016
			sprite_3d.billboard = BaseMaterial3D.BILLBOARD_DISABLED
			sprite_3d.rotation_degrees = Vector3(-60.0, 0, 0)
			sprite_3d.render_priority = 3
			sprite_3d.position.y = 0.05
		else:
			sprite_3d.pixel_size = weapon_data.pixel_size if weapon_data.pixel_size > 0.0 else 0.0028
			sprite_3d.billboard = BaseMaterial3D.BILLBOARD_DISABLED
			sprite_3d.rotation_degrees = Vector3(-60.0, 0, 0)
			sprite_3d.render_priority = 3
			sprite_3d.position.y = 0.05
			
		sprite_3d.centered = true
		sprite_3d.offset = Vector2(0, 0)
		
		# Energetic hop-in tween when crew member first equips
		if is_crew and not hop_in_done:
			hop_in_done = true
			sprite_3d.scale = Vector3.ZERO
			var tween = create_tween()
			tween.tween_property(sprite_3d, "scale", Vector3(1.2, 1.2, 1.2), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.tween_property(sprite_3d, "scale", Vector3.ONE, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			AudioManager.play_sfx("gate_passes")
		elif not is_crew:
			sprite_3d.scale = Vector3.ONE
		
	rotation_degrees.y = weapon_data.spread_angle_deg
	
	match weapon_data.weapon_type:
		"crew_thrower", "crew_musket":
			scale = Vector3(1.0, 1.0, 1.0)
		"swivel_gun":
			scale = Vector3(0.5, 0.5, 0.5)
		"cannon":
			scale = Vector3(0.7, 0.7, 0.7)
		_:
			scale = Vector3(0.6, 0.6, 0.6)
	
	fire_timer = randf_range(0.0, weapon_data.fire_rate * 0.5)
	wander_timer = randf_range(2.0, 3.5)
	idle_timer = randf_range(0.0, TAU)

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
	if Engine.is_editor_hint():
		return
		
	var player = get_tree().get_first_node_in_group("player")
	if player and player.is_game_over:
		return
		
	if not weapon_data:
		return
		
	var w_type = weapon_data.weapon_type.to_lower()
	var w_name = weapon_data.weapon_name.to_lower()
	var is_crew = (w_type == "crew_thrower" or w_type == "crew_musket" or "crew" in w_name or "monkey" in w_name or "skeleton" in w_name)
	
	if is_crew:
		_process_deck_idle(delta)
		_process_targeting(delta)

func _process_deck_idle(delta: float) -> void:
	if not sprite_3d:
		return
		
	idle_timer += delta * 5.0
	
	# Idle Bob & Squash/Stretch
	if not (throw_tween and throw_tween.is_running()):
		sprite_3d.scale.y = 1.0 + sin(idle_timer) * 0.06
		sprite_3d.scale.x = 1.0 - sin(idle_timer) * 0.04
		sprite_3d.rotation_degrees.z = sin(idle_timer * 0.8) * 3.0
	
	# Deck Shuffling / Pacing
	wander_timer -= delta
	if wander_timer <= 0.0:
		wander_timer = randf_range(2.0, 3.5)
		var offset_x = randf_range(-0.12, 0.12)
		var offset_z = randf_range(-0.08, 0.08)
		
		if wander_tween and wander_tween.is_running():
			wander_tween.kill()
		wander_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		wander_tween.tween_property(sprite_3d, "position:x", offset_x, 0.4)
		wander_tween.parallel().tween_property(sprite_3d, "position:z", offset_z, 0.4)

func _process_targeting(delta: float) -> void:
	var player = get_tree().get_first_node_in_group("player")
	var boat_z = player.global_position.z if (player and is_instance_valid(player)) else global_position.z
	
	var candidates: Array[Node] = []
	for grp in ["enemies", "destructible_obstacles", "destructible", "boss"]:
		candidates.append_array(get_tree().get_nodes_in_group(grp))
		
	var best_target: Node3D = null
	var min_dist = INF
	
	var processed: Dictionary = {}
	for target in candidates:
		if not is_instance_valid(target) or not target is Node3D or processed.has(target):
			continue
		processed[target] = true
		
		var node3d = target as Node3D
		# Approaching enemies are upstream (smaller Z coordinate than boat)
		if node3d.global_position.z >= (boat_z + 0.5):
			continue
			
		var dist = global_position.distance_to(node3d.global_position)
		if dist <= 18.0 and dist < min_dist:
			min_dist = dist
			best_target = node3d
			
	current_target = best_target
	
	if current_target and is_instance_valid(current_target):
		var m_pos = muzzle_point.global_position if muzzle_point else global_position
		aim_direction = (current_target.global_position - m_pos).normalized()
		
		# Flip sprite left/right based on target relative to boat
		if sprite_3d:
			var relative_x = current_target.global_position.x - global_position.x
			sprite_3d.flip_h = (relative_x < 0.0)
	else:
		# Default forward direction upstream (-Z) towards approaching enemies
		aim_direction = Vector3(0, 0, -1)
		if sprite_3d:
			sprite_3d.flip_h = false

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
		
	var w_type = weapon_data.weapon_type.to_lower()
	var w_name = weapon_data.weapon_name.to_lower()
	var is_crew = (w_type == "crew_thrower" or w_type == "crew_musket" or "crew" in w_name or "monkey" in w_name or "skeleton" in w_name)
	
	if is_crew:
		_trigger_throw_anim()
		
	AudioManager.play_sfx("cannon_shots")
	
	var ball = proj_scene.instantiate() as Area3D
	if ball:
		world_container.add_child(ball)
		ball.global_position = muzzle_point.global_position
		
		# Mark projectile as fired from BowMount for boss weakpoint checks
		if get_parent() and get_parent().name == "BowMount":
			ball.set_meta("from_bow", true)
		
		var proj_dir: Vector3
		if is_crew:
			proj_dir = aim_direction if (aim_direction != Vector3.ZERO and aim_direction.z < 0.0) else Vector3(0, 0, -1)
		else:
			proj_dir = -global_transform.basis.z.rotated(Vector3.UP, deg_to_rad(weapon_data.spread_angle_deg)).normalized()
			if proj_dir.z > 0.0 and weapon_data.spread_angle_deg == 0.0:
				proj_dir.z = -abs(proj_dir.z)
				proj_dir = proj_dir.normalized()
		
		if ball.has_method("setup"):
			ball.setup(proj_dir, weapon_data.default_ammo)
			
		var player = get_tree().get_first_node_in_group("player")
		if player and "base_damage_bonus" in player and "damage" in ball:
			ball.damage += player.base_damage_bonus

func _trigger_throw_anim() -> void:
	if not sprite_3d:
		return
	if throw_tween and throw_tween.is_running():
		throw_tween.kill()
		
	throw_tween = create_tween()
	throw_tween.tween_property(sprite_3d, "scale", Vector3(1.3, 0.7, 1.0), 0.08)
	throw_tween.tween_property(sprite_3d, "position:y", 0.24, 0.12).set_trans(Tween.TRANS_BOUNCE)
	throw_tween.tween_property(sprite_3d, "position:y", 0.12, 0.14)
	throw_tween.parallel().tween_property(sprite_3d, "scale", Vector3(1.0, 1.0, 1.0), 0.14)
