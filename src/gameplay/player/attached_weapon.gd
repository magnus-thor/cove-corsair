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

func _is_crew() -> bool:
	if not weapon_data:
		return false
	if weapon_data is CrewData or (weapon_data.has_method("is_crew_member") and weapon_data.is_crew_member()):
		return true
	var w_type = weapon_data.weapon_type.to_lower()
	var w_name = weapon_data.weapon_name.to_lower()
	return (w_type == "crew_thrower" or w_type == "crew_musket" or "crew" in w_name or "monkey" in w_name or "skeleton" in w_name)

func _apply_weapon_data() -> void:
	if not weapon_data:
		return
	
	if sprite_3d:
		sprite_3d.texture = weapon_data.sprite_texture
		
		var w_name = weapon_data.weapon_name.to_lower()
		var w_type = weapon_data.weapon_type.to_lower()
		var is_crew = _is_crew()
		
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
		
	var is_crew = _is_crew()
	
	if is_crew:
		_process_deck_idle(delta)
		_process_targeting(delta)
	else:
		aim_direction = Vector3(0, 0, -1)

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
	
	# Priority 1: Active enemy mobs, destructibles, and destructible obstacles
	var spawn_candidates: Array[Node] = []
	for grp in ["enemies", "destructible", "destructible_obstacles", "obstacles"]:
		for node in get_tree().get_nodes_in_group(grp):
			if is_instance_valid(node) and not node.is_in_group("boss") and not (node is BossWarBarge) and not (node is BossComponentDelegate):
				# Must be something that can actually take damage
				if node.has_method("take_damage") or (node.get_parent() and node.get_parent().has_method("take_damage")):
					spawn_candidates.append(node)
				
	# Check other crew targets to avoid redundant targeting
	var claimed_targets: Dictionary = {}
	if player and "equipped_weapons" in player:
		for w in player.equipped_weapons.values():
			if is_instance_valid(w) and w != self and "current_target" in w and is_instance_valid(w.current_target):
				claimed_targets[w.current_target] = true

	var best_target: Node3D = null
	var best_unclaimed: Node3D = null
	var min_dist = INF
	var min_unclaimed_dist = INF
	var max_range = 32.0
	if "detection_range" in weapon_data and weapon_data.detection_range > 0.0:
		max_range = weapon_data.detection_range
	if is_crew:
		max_range = min(max_range, 20.0)
	var m_pos_ref = muzzle_point.global_position if muzzle_point else global_position

	var processed: Dictionary = {}
	for target in spawn_candidates:
		if not is_instance_valid(target) or not target is Node3D or processed.has(target):
			continue
		processed[target] = true
		
		var node3d = target as Node3D
		# Must be in front of the boat
		if node3d.global_position.z > (boat_z - 0.2):
			continue
			
		var to_target = (node3d.global_position - m_pos_ref)
		to_target.y = 0.0
		var dir_norm = to_target.normalized()
		# Forward combat arc: reject targets beyond +/- 70 degrees from upstream (-Z)
		if -dir_norm.z < 0.35:
			continue
			
		var dist = global_position.distance_to(node3d.global_position)
		if dist <= max_range:
			if dist < min_dist:
				min_dist = dist
				best_target = node3d
			if not claimed_targets.has(node3d) and dist < min_unclaimed_dist:
				min_unclaimed_dist = dist
				best_unclaimed = node3d
				
	best_target = best_unclaimed if best_unclaimed else best_target
			
	# If no spawns or threats are alive, fallback to targeting the boss
	if not best_target:
		var boss_candidates: Array[Node] = []
		for node in get_tree().get_nodes_in_group("boss"):
			if is_instance_valid(node) and node is Node3D:
				if "visible" in node and not node.visible:
					continue
				if node is BossComponentDelegate and node.boss_node:
					var comp_name = node.component_name
					if "hp_" + comp_name in node.boss_node and node.boss_node.get("hp_" + comp_name) <= 0:
						continue
				boss_candidates.append(node)

		processed.clear()
		min_dist = INF
		var max_boss_range = 20.0 if is_crew else 28.0
		for target in boss_candidates:
			if not is_instance_valid(target) or not target is Node3D or processed.has(target):
				continue
			processed[target] = true
			
			var node3d = target as Node3D
			if node3d.global_position.z > (boat_z - 0.2):
				continue
				
			var to_target = (node3d.global_position - m_pos_ref)
			to_target.y = 0.0
			var dir_norm = to_target.normalized()
			if -dir_norm.z < 0.35:
				continue
				
			var dist = global_position.distance_to(node3d.global_position)
			if dist <= max_boss_range and dist < min_dist:
				min_dist = dist
				best_target = node3d
			
	current_target = best_target
	
	if current_target and is_instance_valid(current_target):
		var m_pos = muzzle_point.global_position if muzzle_point else global_position
		var dir_to_target = (current_target.global_position - m_pos)
		dir_to_target.y = 0.0 # Maintain flat water level trajectory
		if dir_to_target.z >= -0.2:
			dir_to_target.z = -0.2 # Clamp to forward
		aim_direction = dir_to_target.normalized() if dir_to_target.length_squared() > 0.001 else Vector3(0, 0, -1)
		
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
		
	var is_crew = _is_crew()
	
	if is_crew:
		_trigger_throw_anim()
		
	AudioManager.play_sfx("cannon_shots")
	
	var ball = proj_scene.instantiate() as Area3D
	if ball:
		var spawn_pos = muzzle_point.global_position
		spawn_pos.y = max(0.48, spawn_pos.y)
		
		# Mark projectile as fired from BowMount for boss weakpoint checks
		var socket_name = get_parent().name.to_lower() if get_parent() else ""
		if "bow" in socket_name:
			ball.set_meta("from_bow", true)
		
		var proj_dir: Vector3
		if is_crew:
			proj_dir = aim_direction if aim_direction != Vector3.ZERO else Vector3(0, 0, -1)
		else:
			# Naval weapons fire forward along the vessel's heading with their calibrated spread angle
			if weapon_data.has_method("get_firing_direction"):
				proj_dir = weapon_data.get_firing_direction(Vector3(0, 0, -1))
			else:
				var spread = deg_to_rad(weapon_data.spread_angle_deg)
				proj_dir = Vector3(0, 0, -1).rotated(Vector3.UP, spread).normalized()
		
		world_container.add_child(ball)
		ball.top_level = true
		ball.global_position = spawn_pos
		
		if "max_range" in ball:
			if is_crew:
				var crew_max: float = 20.0
				if "max_throw_range" in weapon_data and weapon_data.max_throw_range > 0.0:
					crew_max = weapon_data.max_throw_range
				elif "detection_range" in weapon_data and weapon_data.detection_range > 0.0:
					crew_max = min(20.0, weapon_data.detection_range)
				ball.max_range = min(ball.max_range, crew_max)
			else:
				ball.max_range = 35.0
				
		if ball.has_method("set_spawn_pos"):
			ball.set_spawn_pos(spawn_pos)
		
		if ball.has_method("setup"):
			ball.setup(proj_dir, weapon_data.default_ammo)
			
		var player = get_tree().get_first_node_in_group("player")
		if player and "base_damage_bonus" in player and "damage" in ball:
			ball.damage += player.base_damage_bonus
			
		if GameState.boss_spawned:
			print("[WEAPON FIRE] %s (Socket: %s) fired at %s | Dir: %s | Target: %s" % [
				weapon_data.weapon_name,
				socket_name,
				ball.global_position,
				proj_dir,
				current_target.name if (current_target and is_instance_valid(current_target)) else "none"
			])

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
