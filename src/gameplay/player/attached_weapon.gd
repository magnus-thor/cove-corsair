@tool
class_name AttachedWeapon
extends Node3D

@export var weapon_data: WeaponData:
	set(val):
		weapon_data = val
		if is_node_ready():
			_apply_weapon_data()

@export var crew_id: String = ""
@export var crew_level: int = 1

@export var projectile_scene: PackedScene = preload("res://src/gameplay/projectiles/cannonball.tscn")

@onready var sprite_3d: Sprite3D = $Sprite3D
@onready var model_container: Node3D = $ModelContainer
@onready var muzzle_point: Marker3D = $MuzzlePoint

var fire_timer: float = 0.0
var idle_timer: float = 0.0
var wander_timer: float = 0.0
var aim_direction: Vector3 = Vector3(0, 0, -1)
var current_target: Node3D = null
var throw_tween: Tween = null
var wander_tween: Tween = null
var hop_in_done: bool = false

const TARGETING_INTERVAL: float = 0.12
var targeting_timer: float = 0.0
static var _last_cannon_sfx_time: float = -1.0

var fire_rate: float:
	get:
		return weapon_data.fire_rate if weapon_data else 1.0

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
	if weapon_data is CrewData or (weapon_data.has_method("is_crew_member") and weapon_data.call("is_crew_member")):
		return true
	var w_type := weapon_data.weapon_type.to_lower()
	var w_name := weapon_data.weapon_name.to_lower()
	return (w_type == "crew_thrower" or w_type == "crew_musket" or "crew" in w_name or "monkey" in w_name or "skeleton" in w_name)

func _apply_weapon_data() -> void:
	if not weapon_data:
		return
	
	var is_crew := _is_crew()
	var w_name := weapon_data.weapon_name.to_lower()
	var w_type := weapon_data.weapon_type.to_lower()

	if is_crew:
		if sprite_3d:
			sprite_3d.visible = false
		if model_container:
			model_container.visible = true
			var glb_path := "res://assets/models/user/crew/monkey_crew.glb"
			if "skeleton" in w_name or "tosser" in w_name:
				glb_path = "res://assets/models/user/crew/skeleton_crew.glb"
			elif "grease" in w_name or "mechanic" in w_name or crew_id == "grease_monkey":
				glb_path = "res://assets/models/user/crew/artillery_grease__monkey.glb"
			
			var model_mesh: Node3D = model_container.get_node_or_null("CrewMesh") as Node3D
			if not model_mesh or model_mesh.get_meta("glb_path", "") != glb_path:
				for child in model_container.get_children():
					child.queue_free()
				if ResourceLoader.exists(glb_path):
					var scene := load(glb_path) as PackedScene
					if scene:
						model_mesh = scene.instantiate() as Node3D
						model_mesh.name = "CrewMesh"
						model_mesh.set_meta("glb_path", glb_path)
						model_container.add_child(model_mesh)
			
			if model_mesh:
				model_mesh.visible = true
				var crew_scale := Vector3(0.525, 0.525, 0.525)
				if "grease" in w_name or "mechanic" in w_name or crew_id == "grease_monkey":
					crew_scale = Vector3(0.55, 0.55, 0.55)
				elif "model_scale" in weapon_data and weapon_data.model_scale != Vector3.ZERO and weapon_data.model_scale != Vector3(0.4, 0.4, 0.4):
					crew_scale = weapon_data.model_scale * 1.5
				model_mesh.scale = crew_scale
				model_mesh.position = Vector3.ZERO

			if not hop_in_done and model_container:
				hop_in_done = true
				model_container.scale = Vector3.ZERO
				var tween := create_tween()
				tween.tween_property(model_container, "scale", Vector3(1.1, 1.1, 1.1), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				tween.tween_property(model_container, "scale", Vector3.ONE, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
				AudioManager.play_sfx("gate_passes")
	else:
		var cannon_glb := "res://assets/models/user/weapons/cannon.glb"
		var model_to_load: PackedScene = null
		if "model_scene" in weapon_data and weapon_data.model_scene:
			model_to_load = weapon_data.model_scene
		elif ResourceLoader.exists(cannon_glb) and ("cannon" in w_type or "cannon" in w_name or "chaser" in w_name or "swivel" in w_name or "mortar" in w_name):
			model_to_load = load(cannon_glb)
		
		if model_to_load:
			if sprite_3d:
				sprite_3d.visible = false
			if model_container:
				model_container.visible = true
				var model_mesh: Node3D = model_container.get_node_or_null("WeaponMesh") as Node3D
				if not model_mesh or model_mesh.get_meta("model_source", null) != model_to_load:
					for child in model_container.get_children():
						child.queue_free()
					model_mesh = model_to_load.instantiate() as Node3D
					model_mesh.name = "WeaponMesh"
					model_mesh.set_meta("model_source", model_to_load)
					model_container.add_child(model_mesh)
				
				if model_mesh:
					model_mesh.visible = true
					var m_scale := weapon_data.model_scale if ("model_scale" in weapon_data and weapon_data.model_scale != Vector3.ZERO) else Vector3(0.4, 0.4, 0.4)
					model_mesh.scale = m_scale
					var m_rot := weapon_data.model_rotation_degrees if ("model_rotation_degrees" in weapon_data and weapon_data.model_rotation_degrees != Vector3.ZERO) else Vector3(0, 90, 0)
					model_mesh.rotation_degrees = m_rot
					var m_offset := weapon_data.model_offset if "model_offset" in weapon_data else Vector3(0, 0.12, 0)
					model_mesh.position = m_offset
		else:
			if model_container:
				model_container.visible = false
			if sprite_3d:
				sprite_3d.visible = true
				sprite_3d.texture = weapon_data.sprite_texture
				if "swivel" in w_name or "bow" in w_name or "chaser" in w_name or w_type == "swivel_gun" or w_type == "cannon":
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
				sprite_3d.scale = Vector3.ONE
		
	rotation_degrees.y = weapon_data.spread_angle_deg
	
	match weapon_data.weapon_type:
		"crew_thrower", "crew_musket":
			scale = Vector3(1.0, 1.0, 1.0)
		"swivel_gun":
			scale = Vector3(0.5, 0.5, 0.5)
		"cannon":
			scale = Vector3(0.7, 0.7, 0.7)
		"scattershot":
			scale = Vector3(0.7, 0.7, 0.7)
		"deck_mortar":
			scale = Vector3(0.8, 0.8, 0.8)
		_:
			scale = Vector3(0.6, 0.6, 0.6)
	
	if is_crew:
		if crew_id == "monkey_bomber" or "monkey" in w_name:
			weapon_data.fire_rate = 1.2 if crew_level == 1 else 1.0
		elif crew_id == "skeleton_tosser" or "skeleton" in w_name:
			weapon_data.fire_rate = 1.4 if crew_level == 1 else 1.2
		elif crew_id == "grease_monkey" or "grease" in w_name or "mechanic" in w_name:
			weapon_data.fire_rate = clampf(1.3 - (0.12 * float(crew_level - 1)), 0.8, 1.3)

	fire_timer = randf_range(0.0, weapon_data.fire_rate * 0.5)
	wander_timer = randf_range(2.0, 3.5)
	idle_timer = randf_range(0.0, TAU)

	var fallback := get_node_or_null("FallbackMesh") as MeshInstance3D
	if weapon_data.sprite_texture == null and not is_crew:
		if not fallback:
			fallback = MeshInstance3D.new()
			fallback.name = "FallbackMesh"
			var cylinder := CylinderMesh.new()
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

func _is_mortar() -> bool:
	if not weapon_data:
		return false
	var socket_name: String = get_parent().name.to_lower() if get_parent() else ""
	var w_type: String = weapon_data.weapon_type.to_lower()
	var w_name: String = weapon_data.weapon_name.to_lower()
	return ("mortar" in socket_name) or ("mortar" in w_type) or ("mortar" in w_name)

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
		
	var player: Node = get_tree().get_first_node_in_group("player")
	if player and player.get("is_game_over") == true:
		return
		
	if not weapon_data:
		return
		
	var is_crew: bool = _is_crew()
	var is_mortar: bool = _is_mortar()
	
	targeting_timer += delta
	var should_retarget: bool = (targeting_timer >= TARGETING_INTERVAL) or not is_instance_valid(current_target)

	if is_crew:
		_process_deck_idle(delta)
		if should_retarget:
			targeting_timer = 0.0
			_process_targeting(delta)
		_update_aim_rotation(delta)
	elif is_mortar:
		if should_retarget:
			targeting_timer = 0.0
			_process_targeting(delta)
		_update_aim_rotation(delta)
	else:
		aim_direction = Vector3(0, 0, -1)

func _update_aim_rotation(delta: float) -> void:
	if current_target and is_instance_valid(current_target):
		var m_pos: Vector3 = muzzle_point.global_position if muzzle_point else global_position
		var to_target: Vector3 = (current_target.global_position - m_pos)
		to_target.y = 0.0
		if to_target.length_squared() > 0.001:
			var target_yaw: float = atan2(-to_target.x, -to_target.z)
			rotation.y = lerp_angle(rotation.y, target_yaw, 10.0 * delta)
	else:
		rotation.y = lerp_angle(rotation.y, deg_to_rad(weapon_data.spread_angle_deg), 5.0 * delta)

func _process_deck_idle(delta: float) -> void:
	idle_timer += delta * 5.0
	
	if model_container and model_container.visible:
		if not (throw_tween and throw_tween.is_running()):
			model_container.position.y = sin(idle_timer * 0.8) * 0.02
	elif sprite_3d and sprite_3d.visible:
		if not (throw_tween and throw_tween.is_running()):
			sprite_3d.scale.y = 1.0 + sin(idle_timer) * 0.06
			sprite_3d.scale.x = 1.0 - sin(idle_timer) * 0.04
			sprite_3d.rotation_degrees.z = sin(idle_timer * 0.8) * 3.0
	
	# Deck Shuffling / Pacing
	wander_timer -= delta
	if wander_timer <= 0.0:
		wander_timer = randf_range(2.0, 3.5)
		var offset_x := randf_range(-0.12, 0.12)
		var offset_z := randf_range(-0.08, 0.08)
		
		if wander_tween and wander_tween.is_running():
			wander_tween.kill()
		var active_node: Node3D = model_container if (model_container and model_container.visible) else sprite_3d
		if active_node:
			wander_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			wander_tween.tween_property(active_node, "position:x", offset_x, 0.4)
			wander_tween.parallel().tween_property(active_node, "position:z", offset_z, 0.4)

func _process_targeting(_delta: float) -> void:
	var is_crew: bool = _is_crew()
	var is_mortar: bool = _is_mortar()
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	var boat_z: float = player.global_position.z if (player and is_instance_valid(player)) else global_position.z
	
	# Priority 1: Active enemy mobs, destructibles, barricades, sea mines, and destructible obstacles
	var spawn_candidates: Array[Node] = []
	for grp: String in ["enemies", "destructible", "destructible_obstacles", "barricade", "sea_mine", "obstacles"]:
		for node in get_tree().get_nodes_in_group(grp):
			if is_instance_valid(node) and not node.is_in_group("boss") and not (node is BossWarBarge) and not (node is BossComponentDelegate):
				if node.has_method("take_damage") or node.has_method("take_hit") or (node.get_parent() and (node.get_parent().has_method("take_damage") or node.get_parent().has_method("take_hit"))):
					spawn_candidates.append(node)
				
	# Check other crew targets to avoid redundant targeting (crew only)
	var claimed_targets: Dictionary = {}
	if is_crew and player is PlayerSwerve:
		var swerve := player as PlayerSwerve
		for w: Node in swerve.equipped_weapons.values():
			if is_instance_valid(w) and w != self and "current_target" in w and is_instance_valid(w.get("current_target")):
				claimed_targets[w.get("current_target")] = true

	var best_target: Node3D = null
	var best_unclaimed: Node3D = null
	var min_dist: float = INF
	var min_unclaimed_dist: float = INF
	var max_range: float = 32.0
	if "detection_range" in weapon_data and float(weapon_data.get("detection_range")) > 0.0:
		max_range = float(weapon_data.get("detection_range"))
	elif "max_range" in weapon_data and float(weapon_data.get("max_range")) > 0.0:
		max_range = float(weapon_data.get("max_range"))
	if is_crew:
		max_range = min(max_range, 20.0)
	elif is_mortar:
		max_range = min(max_range, 18.5)
	var m_pos_ref := muzzle_point.global_position if muzzle_point else global_position

	var processed: Dictionary = {}
	for target in spawn_candidates:
		if not is_instance_valid(target) or not target is Node3D or processed.has(target):
			continue
		processed[target] = true
		
		var node3d := target as Node3D
		if node3d.global_position.z > (boat_z - 0.2):
			continue
			
		var to_target := (node3d.global_position - m_pos_ref)
		to_target.y = 0.0
		var dir_norm := to_target.normalized()
		if -dir_norm.z < 0.25:
			continue
			
		var dist := global_position.distance_to(node3d.global_position)
		if dist <= max_range:
			if dist < min_dist:
				min_dist = dist
				best_target = node3d
			if not claimed_targets.has(node3d) and dist < min_unclaimed_dist:
				min_unclaimed_dist = dist
				best_unclaimed = node3d
				
	if is_crew:
		best_target = best_unclaimed if best_unclaimed else best_target
	# Mortar weapons intentionally use best_target (min_dist) to fire directly at the closest threat!
			
	# Fallback to boss
	if not best_target:
		var boss_candidates: Array[Node] = []
		for node in get_tree().get_nodes_in_group("boss"):
			if is_instance_valid(node) and node is Node3D:
				var node3d := node as Node3D
				if not node3d.visible:
					continue
				if node is BossComponentDelegate:
					var delegate := node as BossComponentDelegate
					if delegate.boss_node:
						var comp_name: String = delegate.component_name
						if "hp_" + comp_name in delegate.boss_node and delegate.boss_node.get("hp_" + comp_name) <= 0:
							continue
				boss_candidates.append(node)

		processed.clear()
		min_dist = INF
		var max_boss_range: float = 20.0 if is_crew else (18.5 if is_mortar else 28.0)
		for target in boss_candidates:
			if not is_instance_valid(target) or not target is Node3D or processed.has(target):
				continue
			processed[target] = true
			
			var node3d := target as Node3D
			if node3d.global_position.z > (boat_z - 0.2):
				continue
				
			var to_target := (node3d.global_position - m_pos_ref)
			to_target.y = 0.0
			var dir_norm := to_target.normalized()
			if -dir_norm.z < 0.25:
				continue
				
			var dist := global_position.distance_to(node3d.global_position)
			if dist <= max_boss_range and dist < min_dist:
				min_dist = dist
				best_target = node3d
			
	current_target = best_target
	
	if current_target and is_instance_valid(current_target):
		var m_pos := muzzle_point.global_position if muzzle_point else global_position
		var dir_to_target := (current_target.global_position - m_pos)
		dir_to_target.y = 0.0
		if dir_to_target.z >= -0.2:
			dir_to_target.z = -0.2
		aim_direction = dir_to_target.normalized() if dir_to_target.length_squared() > 0.001 else Vector3(0, 0, -1)
	else:
		aim_direction = Vector3(0, 0, -1)

func try_fire(p_projectile_scene: Variant = null, world_container: Node = null) -> void:
	if p_projectile_scene is float or p_projectile_scene is int:
		var delta := float(p_projectile_scene)
		if not weapon_data:
			return
		fire_timer += delta
		var eff_fire_rate: float = weapon_data.fire_rate
		if not _is_hostile_vessel() and _is_mortar():
			if GameState and GameState.is_crew_equipped_on_active_ship("grease_monkey"):
				var b_lvl: int = GameState.get_crew_level("grease_monkey")
				var rof_boost: float = 0.20 + 0.06 * float(b_lvl)
				eff_fire_rate *= (1.0 - rof_boost)
		if fire_timer >= eff_fire_rate:
			fire_timer = 0.0
			var parent := get_tree().current_scene
			if not parent:
				parent = get_parent()
			_execute_fire(self.projectile_scene, parent)
	else:
		_execute_fire(p_projectile_scene, world_container)

func _is_hostile_vessel() -> bool:
	var node: Node = self
	while node:
		if node.is_in_group("enemies") or node.is_in_group("boss"):
			return true
		node = node.get_parent()
	return false

func _execute_fire(proj_scene: PackedScene, world_container: Node) -> void:
	if not weapon_data or not proj_scene or not world_container or not muzzle_point:
		return
		
	var is_crew := _is_crew()
	var is_hostile := _is_hostile_vessel()
	var default_fwd := Vector3(0, 0, 1) if is_hostile else Vector3(0, 0, -1)
	
	if is_crew:
		_trigger_throw_anim()
	elif model_container and model_container.visible:
		var recoil_tween := create_tween()
		recoil_tween.tween_property(model_container, "position:z", 0.08, 0.04).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		recoil_tween.tween_property(model_container, "position:z", 0.0, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		
	var spawn_pos := muzzle_point.global_position
	spawn_pos.y = max(0.48, spawn_pos.y)
	
	var socket_name := get_parent().name.to_lower() if get_parent() else ""
	var from_bow := ("bow" in socket_name)
	var is_mortar := ("mortar" in socket_name) or (weapon_data and ("mortar" in weapon_data.weapon_name.to_lower() or "mortar" in weapon_data.weapon_type.to_lower()))
	
	var proj_dir: Vector3
	if is_crew or is_mortar:
		proj_dir = aim_direction if aim_direction != Vector3.ZERO else default_fwd
	else:
		var mount_fwd := -global_transform.basis.z if is_hostile else global_transform.basis.z
		mount_fwd.y = 0.0
		if mount_fwd.length_squared() > 0.001:
			proj_dir = mount_fwd.normalized()
		elif weapon_data.has_method("get_firing_direction"):
			proj_dir = weapon_data.get_firing_direction(default_fwd)
		else:
			var spread := deg_to_rad(weapon_data.spread_angle_deg)
			proj_dir = default_fwd.rotated(Vector3.UP, spread).normalized()

	if is_hostile and proj_dir.z < 0.0:
		proj_dir.z = abs(proj_dir.z)
		proj_dir = proj_dir.normalized()
	elif not is_hostile and proj_dir.z > 0.0:
		# Player flagship and follower fleet vessels must NEVER fire backward downriver (+Z)
		proj_dir.z = -abs(proj_dir.z)
		proj_dir = proj_dir.normalized()

	var player := get_tree().get_first_node_in_group("player")
	var is_scatter_weapon: bool = (weapon_data.get("is_scatter") == true or weapon_data.weapon_type == "scattershot" or "scatter" in weapon_data.weapon_name.to_lower())
	var camera := get_tree().get_first_node_in_group("game_camera")

	if is_scatter_weapon:
		fire_scattershot(proj_dir, world_container, proj_scene)
	elif is_mortar:
		AudioManager.play_sfx("sfx_mortar_fire")
		if not is_hostile and player and player.has_method("apply_firing_recoil"):
			player.call("apply_firing_recoil", 3.5, true)
		if camera and camera.has_method("add_trauma"):
			camera.call("add_trauma", 0.25)
			
		var ball := proj_scene.instantiate() as Cannonball
		if ball:
			ball.set_meta("is_mortar", true)
			if from_bow:
				ball.set_meta("from_bow", true)
			if is_hostile:
				ball.add_to_group("enemy_projectiles")
				ball.set_meta("is_hostile", true)
				ball.is_hostile = true
			world_container.add_child(ball)
			ball.top_level = true
			ball.global_position = spawn_pos
			ball.set_spawn_pos(spawn_pos)
			
			ball.crew_id = crew_id
			ball.set_meta("crew_id", crew_id)
			ball.crew_level = crew_level
			ball.set_meta("crew_level", crew_level)
			if crew_id == "skeleton_tosser" or (weapon_data and ("skeleton" in weapon_data.weapon_name.to_lower() or "fire" in weapon_data.weapon_name.to_lower() or "incendiary" in weapon_data.weapon_name.to_lower())):
				ball.set_meta("is_incendiary", true)

			if not is_hostile and GameState:
				var a_id := GameState.get_active_ammo()
				ball.set_meta("ammo_id", a_id)
				ball.ammo_id = a_id

			if current_target and is_instance_valid(current_target):
				ball.target_node = current_target
				ball.target_range = global_position.distance_to(current_target.global_position)
			else:
				var def_range: float = weapon_data.max_range if (weapon_data and "max_range" in weapon_data and weapon_data.max_range > 0.0) else 18.0
				ball.target_range = def_range
				ball.target_node = null

			if not is_hostile and GameState and GameState.is_crew_equipped_on_active_ship("grease_monkey"):
				var b_lvl: int = GameState.get_crew_level("grease_monkey")
				ball.speed *= (1.15 + 0.05 * float(b_lvl))
				ball.target_range *= (1.15 + 0.05 * float(b_lvl))
				ball.splash_radius_multiplier *= (1.20 + 0.06 * float(b_lvl))

			ball.setup(proj_dir, weapon_data.default_ammo, weapon_data)
				
			if player and "base_damage_bonus" in player and not is_hostile:
				ball.damage += int(round(float(player.get("base_damage_bonus"))))
	else:
		var cur_time: float = Time.get_ticks_msec() / 1000.0
		if cur_time - _last_cannon_sfx_time >= 0.05:
			_last_cannon_sfx_time = cur_time
			AudioManager.play_sfx("cannon_shots")
		if not is_hostile and player and player.has_method("apply_firing_recoil"):
			player.call("apply_firing_recoil", 1.8, false)
		if camera and camera.has_method("add_trauma"):
			camera.call("add_trauma", 0.08, 0.35)
			
		var num_cannons: int = weapon_data.cannon_count if ("cannon_count" in weapon_data and weapon_data.cannon_count > 1) else 1
		if num_cannons == 1 and from_bow and player and "ship_data" in player and player.ship_data and player.ship_data.base_cannons > 1:
			num_cannons = player.ship_data.base_cannons

		var spacing: float = weapon_data.barrel_spacing if ("barrel_spacing" in weapon_data and weapon_data.barrel_spacing > 0.0) else 0.44
		var offsets: Array[float] = []
		if num_cannons <= 1:
			offsets = [0.0]
		elif num_cannons == 2:
			offsets = [-spacing * 0.5, spacing * 0.5]
		elif num_cannons == 3:
			offsets = [-spacing, 0.0, spacing]
		else:
			var total_span: float = spacing * float(num_cannons - 1)
			for idx: int in range(num_cannons):
				offsets.append(-total_span * 0.5 + float(idx) * spacing)

		var right_dir: Vector3 = global_transform.basis.x.normalized()
		for offset_x: float in offsets:
			var ball := proj_scene.instantiate() as Cannonball
			if ball:
				if from_bow:
					ball.set_meta("from_bow", true)
				if is_hostile:
					ball.add_to_group("enemy_projectiles")
					ball.set_meta("is_hostile", true)
					ball.is_hostile = true
				world_container.add_child(ball)
				ball.top_level = true
				var shot_pos: Vector3 = spawn_pos + right_dir * offset_x
				ball.global_position = shot_pos
				ball.set_spawn_pos(shot_pos)
				
				ball.crew_id = crew_id
				ball.set_meta("crew_id", crew_id)
				ball.crew_level = crew_level
				ball.set_meta("crew_level", crew_level)
				if crew_id == "skeleton_tosser" or (weapon_data and ("skeleton" in weapon_data.weapon_name.to_lower() or "fire" in weapon_data.weapon_name.to_lower() or "incendiary" in weapon_data.weapon_name.to_lower())):
					ball.set_meta("is_incendiary", true)

				if not is_hostile and GameState:
					var a_id := GameState.get_active_ammo()
					ball.set_meta("ammo_id", a_id)
					ball.ammo_id = a_id

				ball.setup(proj_dir, weapon_data.default_ammo, weapon_data)
					
				if crew_id == "grease_monkey" or (weapon_data and ("grease" in weapon_data.weapon_name.to_lower() or "mechanic" in weapon_data.weapon_name.to_lower())):
					ball.speed = 18.0
					ball.damage = 4 + (crew_level - 1)

				if player and "base_damage_bonus" in player and not is_hostile:
					ball.damage += int(round(float(player.get("base_damage_bonus"))))

func fire_scattershot(_proj_dir: Vector3 = Vector3.ZERO, world_container: Node = null, p_proj_scene: PackedScene = null) -> void:
	if not world_container:
		var parent := get_tree().current_scene if get_tree() else null
		if not parent:
			parent = get_parent()
		world_container = parent
	if not world_container or not muzzle_point:
		return

	# Play sfx_scattershot ONCE per volley and trigger lateral camera jitter trauma
	AudioManager.play_sfx("sfx_scattershot")
	var is_hostile := _is_hostile_vessel()
	var p: Node = get_tree().get_first_node_in_group("player") if get_tree() else null
	if not is_hostile and p and p.has_method("apply_firing_recoil"):
		p.call("apply_firing_recoil", 2.2, false)
	var camera := get_tree().get_first_node_in_group("game_camera")
	if camera and camera.has_method("add_trauma"):
		camera.call("add_trauma", 0.15, 0.35)

	var scene_to_use: PackedScene = p_proj_scene
	if not scene_to_use:
		if weapon_data and "projectile_scene" in weapon_data and weapon_data.projectile_scene:
			scene_to_use = weapon_data.projectile_scene
		else:
			scene_to_use = self.projectile_scene
			
	if not scene_to_use:
		return

	var pellets_count: int = 4
	var max_spread_deg: float = 12.0
	var socket_name := get_parent().name.to_lower() if get_parent() else ""
	var from_bow: bool = ("bow" in socket_name)

	# Read base forward direction
	var base_forward := -global_transform.basis.z.normalized()
	if aim_direction != Vector3.ZERO:
		base_forward = aim_direction.normalized()

	var spawn_pos := muzzle_point.global_position

	for i in range(pellets_count):
		# Spread evenly between -max_spread_deg and +max_spread_deg
		var t: float = float(i) / float(pellets_count - 1)
		var angle_offset: float = lerp(-max_spread_deg, max_spread_deg, t)
		var angle_rad: float = deg_to_rad(angle_offset)
		var pellet_dir := base_forward.rotated(Vector3.UP, angle_rad).normalized()

		var pellet := scene_to_use.instantiate() as Cannonball
		if pellet:
			if from_bow:
				pellet.set_meta("from_bow", true)
			if is_hostile:
				pellet.add_to_group("enemy_projectiles")
				pellet.set_meta("is_hostile", true)
				pellet.is_hostile = true
			world_container.add_child(pellet)
			pellet.top_level = true
			pellet.global_position = spawn_pos
			pellet.set_spawn_pos(spawn_pos)
			pellet.setup(pellet_dir, weapon_data.default_ammo if weapon_data else null, weapon_data)
			if weapon_data and "projectile_lifetime" in weapon_data and weapon_data.projectile_lifetime > 0.0:
				pellet.lifetime = weapon_data.projectile_lifetime
			elif pellet.speed > 0.0:
				pellet.lifetime = min(pellet.lifetime, (pellet.max_range / pellet.speed) + 0.05)
			if p and "base_damage_bonus" in p and not is_hostile:
				pellet.damage += int(round(float(p.get("base_damage_bonus"))))

func _trigger_throw_anim() -> void:
	if model_container and model_container.visible:
		if throw_tween and throw_tween.is_running():
			throw_tween.kill()
		throw_tween = create_tween()
		# 0.15s procedural pitch tilt tween (pitch back and forward) to simulate axe/bomb toss
		throw_tween.tween_property(model_container, "rotation_degrees:x", -25.0, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		throw_tween.tween_property(model_container, "rotation_degrees:x", 15.0, 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		throw_tween.tween_property(model_container, "rotation_degrees:x", 0.0, 0.04).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	elif sprite_3d and sprite_3d.visible:
		if throw_tween and throw_tween.is_running():
			throw_tween.kill()
		throw_tween = create_tween()
		throw_tween.tween_property(sprite_3d, "scale", Vector3(1.3, 0.7, 1.0), 0.08)
		throw_tween.tween_property(sprite_3d, "position:y", 0.24, 0.12).set_trans(Tween.TRANS_BOUNCE)
		throw_tween.tween_property(sprite_3d, "position:y", 0.12, 0.14)
		throw_tween.parallel().tween_property(sprite_3d, "scale", Vector3(1.0, 1.0, 1.0), 0.14)
