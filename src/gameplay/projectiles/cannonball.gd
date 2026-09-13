class_name Cannonball
extends Area3D

## Speed of the cannonball moving forward
@export var speed: float = 25.0

## Total time the cannonball remains active before self-destruction
@export var lifetime: float = 5.0

## Maximum travel distance from spawn position before self-destructing
@export var max_range: float = 38.0

## Height of parabolic ballistic arc (0.0 = flat naval trajectory)
@export var arc_height: float = 0.0

## Whether this projectile tumbles/spins in flight (e.g. Throwing Axe)
@export var spins_in_flight: bool = false
@export var spin_speed: float = 16.0

## Base damage dealt to obstacles
@export var damage: int = 1

## Whether this projectile was fired by an enemy/hostile craft
@export var is_hostile: bool = false

## Splash radius multiplier applied when cannonballs exceed soft cap
@export var splash_radius_multiplier: float = 1.0

var crew_id: String = ""
var crew_level: int = 1

## Hit splash VFX to spawn on impact or expiration
@export var hit_splash_scene: PackedScene = preload("res://src/gameplay/vfx/hit_splash.tscn")

## Custom ammo data assigned at initialization (optional)
var ammo_data: AmmoData:
	set(val):
		ammo_data = val
		if is_node_ready():
			_apply_ammo_data()

var weapon_data: WeaponData = null

var _is_destroyed: bool = false
var direction: Vector3 = Vector3.ZERO
var _spawn_pos: Vector3 = Vector3.ZERO
var _spawn_pos_initialized: bool = false
var _distance_traveled: float = 0.0
var _base_spawn_y: float = 0.48

func set_spawn_pos(pos: Vector3) -> void:
	_spawn_pos = pos
	_base_spawn_y = pos.y
	_spawn_pos_initialized = true

func setup(p_direction: Vector3, p_ammo_data: AmmoData, p_weapon_data: WeaponData = null) -> void:
	if p_direction != Vector3.ZERO:
		direction = p_direction.normalized()
	else:
		direction = Vector3(0, 0, 1) if (is_hostile or is_in_group("enemy_projectiles") or has_meta("is_hostile")) else Vector3(0, 0, -1)
		
	# Hostile craft projectiles MUST travel downriver in +Z toward the player
	if (is_hostile or is_in_group("enemy_projectiles") or has_meta("is_hostile")) and direction.z < 0.0:
		direction.z = abs(direction.z)
		if direction.length_squared() > 0.001:
			direction = direction.normalized()
	elif not (is_hostile or is_in_group("enemy_projectiles") or has_meta("is_hostile")) and direction.z > 0.0:
		# Player and follower fleet projectiles MUST travel upriver in -Z toward enemies
		direction.z = -abs(direction.z)
		if direction.length_squared() > 0.001:
			direction = direction.normalized()
			
	weapon_data = p_weapon_data
	ammo_data = p_ammo_data
	
	# Determine speed
	var base_spd = ammo_data.projectile_speed if ammo_data else 24.0
	var spd_mult = weapon_data.projectile_speed_mult if (weapon_data and "projectile_speed_mult" in weapon_data) else 1.0
	speed = base_spd * spd_mult
	
	# Determine damage
	damage = ammo_data.damage if ammo_data else 1
	
	# Determine crew overrides
	if has_meta("crew_id"):
		crew_id = str(get_meta("crew_id"))
	if has_meta("crew_level"):
		crew_level = int(get_meta("crew_level"))
		
	if crew_id == "monkey_bomber":
		if crew_level == 1:
			damage = 3
			splash_radius_multiplier = 1.0
		elif crew_level == 2:
			damage = 5
			splash_radius_multiplier = 1.12
		else:
			damage = 5
			splash_radius_multiplier = 1.12
	elif crew_id == "skeleton_tosser":
		if crew_level == 1:
			damage = 4
			splash_radius_multiplier = 0.8
		elif crew_level == 2:
			damage = 6
			splash_radius_multiplier = 1.12
		else:
			damage = 6
			splash_radius_multiplier = 1.12

	# Determine scale
	if ammo_data and ammo_data.scale_multiplier != 1.0:
		scale = Vector3.ONE * ammo_data.scale_multiplier
		
	# Determine max_range
	if ammo_data and "max_range_override" in ammo_data and ammo_data.max_range_override > 0.0:
		max_range = ammo_data.max_range_override
	elif weapon_data:
		if weapon_data.has_method("get_effective_max_range"):
			max_range = weapon_data.get_effective_max_range()
		elif "max_range" in weapon_data and weapon_data.max_range > 0.0:
			max_range = weapon_data.max_range
		elif "max_throw_range" in weapon_data and weapon_data.max_throw_range > 0.0:
			max_range = weapon_data.max_throw_range
		else:
			max_range = 38.0
	else:
		max_range = 38.0
		
	# Determine arc_height
	var base_arc = 0.0
	if weapon_data:
		if weapon_data.has_method("get_effective_arc_height"):
			base_arc = weapon_data.get_effective_arc_height()
		elif "arc_height" in weapon_data:
			base_arc = weapon_data.arc_height
	if ammo_data and "arc_height_bonus" in ammo_data:
		base_arc += ammo_data.arc_height_bonus
	arc_height = base_arc
	
	# Determine spinning
	if ammo_data and "spins_in_flight" in ammo_data and ammo_data.spins_in_flight:
		spins_in_flight = true
	elif ammo_data and ammo_data.ammo_name == "Throwing Axe":
		spins_in_flight = true
	else:
		spins_in_flight = false

func _ready() -> void:
	top_level = true
	add_to_group("cannonballs")
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	damage = ammo_data.damage if ammo_data else 1
	_apply_visual_styling()
	if ammo_data:
		_apply_ammo_data()
	call_deferred("_enable_collisions")

func _enable_collisions() -> void:
	if not _is_destroyed and is_inside_tree():
		collision_layer = 2
		collision_mask = 0xFFFFFFFF
		monitoring = true
		monitorable = true
		area_entered.connect(_on_hit)
		body_entered.connect(_on_hit)

static var _flare_texture_cache: GradientTexture2D = null

static func _get_flare_texture() -> GradientTexture2D:
	if not _flare_texture_cache:
		var grad = Gradient.new()
		grad.colors = PackedColorArray([Color(1.0, 1.0, 0.85, 1.0), Color(1.0, 0.65, 0.15, 0.8), Color(1.0, 0.3, 0.0, 0.0)])
		grad.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
		var tex = GradientTexture2D.new()
		tex.gradient = grad
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(0.5, 0.0)
		tex.width = 64
		tex.height = 64
		_flare_texture_cache = tex
	return _flare_texture_cache

func _apply_visual_styling() -> void:
	var model = get_node_or_null("CannonBallModel")
	if model:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.18, 0.18, 0.20) # Authentic dark cast iron
		mat.metallic = 0.95
		mat.roughness = 0.25
		mat.emission_enabled = false
		if model is MeshInstance3D:
			model.material_override = mat
		else:
			for child in model.get_children():
				if child is MeshInstance3D:
					child.material_override = mat

func _apply_ammo_data() -> void:
	damage = ammo_data.damage if ammo_data else 1
	if not ammo_data:
		return
	var base_spd = ammo_data.projectile_speed if ammo_data else 24.0
	var spd_mult = weapon_data.projectile_speed_mult if (weapon_data and "projectile_speed_mult" in weapon_data) else 1.0
	speed = base_spd * spd_mult
	
	if ammo_data.splash_radius > 0.0:
		splash_radius_multiplier = ammo_data.splash_radius / 2.5
	
	var base_sc = ammo_data.scale_multiplier if ammo_data.scale_multiplier > 0.0 else 1.0
	scale = Vector3.ONE * base_sc
		
	var model = get_node_or_null("CannonBallModel")
	var flare = get_node_or_null("TracerFlare") as Sprite3D
	
	match ammo_data.ammo_name:
		"Coconut Bomb":
			if model:
				var mat = StandardMaterial3D.new()
				mat.albedo_color = Color(0.42, 0.25, 0.12) # Textured coconut husk brown
				mat.roughness = 0.85
				mat.metallic = 0.05
				mat.emission_enabled = true
				mat.emission = Color(0.2, 0.35, 0.08) # Jungle green accent
				mat.emission_energy_multiplier = 0.9
				if model is MeshInstance3D:
					model.material_override = mat
				else:
					for child in model.get_children():
						if child is MeshInstance3D:
							child.material_override = mat
			if flare:
				flare.visible = false
				
		"Fire Bomb":
			if model:
				var mat = StandardMaterial3D.new()
				mat.albedo_color = Color(1.0, 0.28, 0.05) # Blazing fire sphere
				mat.roughness = 0.25
				mat.metallic = 0.1
				mat.emission_enabled = true
				mat.emission = Color(3.5, 1.2, 0.2) # High intensity fire glow
				mat.emission_energy_multiplier = 1.8
				if model is MeshInstance3D:
					model.material_override = mat
				else:
					for child in model.get_children():
						if child is MeshInstance3D:
							child.material_override = mat
			if not flare:
				flare = Sprite3D.new()
				flare.name = "TracerFlare"
				flare.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				flare.texture = _get_flare_texture()
				flare.pixel_size = 0.012
				flare.modulate = Color(4.0, 1.4, 0.2, 0.95)
				add_child(flare)
			else:
				flare.visible = true
				flare.texture = _get_flare_texture()
				flare.modulate = Color(4.0, 1.4, 0.2, 0.95)
				
		_:
			# Standard vessel cannonball (pure authentic dark cast iron, no yellow)
			if model:
				var mat = StandardMaterial3D.new()
				mat.albedo_color = Color(0.18, 0.18, 0.20) # Pure dark cast iron
				mat.metallic = 0.95
				mat.roughness = 0.25
				mat.emission_enabled = false
				if model is MeshInstance3D:
					model.material_override = mat
				else:
					for child in model.get_children():
						if child is MeshInstance3D:
							child.material_override = mat
			if flare:
				flare.visible = false
		
	if ammo_data.sprite_texture:
		if model:
			model.visible = false
			
		var sprite_node = get_node_or_null("Sprite3D") as Sprite3D
		if not sprite_node:
			sprite_node = Sprite3D.new()
			sprite_node.name = "Sprite3D"
			sprite_node.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			sprite_node.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
			add_child(sprite_node)
		sprite_node.texture = ammo_data.sprite_texture
		sprite_node.pixel_size = ammo_data.pixel_size if ammo_data.pixel_size > 0.0 else 0.005
		if "y_offset" in ammo_data and ammo_data.y_offset != 0.0:
			sprite_node.position.y = ammo_data.y_offset


func _physics_process(delta: float) -> void:
	if _is_destroyed:
		return
	if not _spawn_pos_initialized:
		_spawn_pos = global_position
		_base_spawn_y = _spawn_pos.y
		_spawn_pos_initialized = true

	var step = speed * delta
	_distance_traveled += step

	# Move horizontal direction
	var forward_dir = direction
	if forward_dir == Vector3.ZERO:
		if is_hostile or is_in_group("enemy_projectiles") or has_meta("is_hostile"):
			forward_dir = Vector3(0, 0, 1)
		else:
			forward_dir = -global_transform.basis.z
	elif (is_hostile or is_in_group("enemy_projectiles") or has_meta("is_hostile")) and forward_dir.z < 0.0:
		forward_dir.z = abs(forward_dir.z)
		forward_dir = forward_dir.normalized()
		
	global_position.x += forward_dir.x * step
	global_position.z += forward_dir.z * step
	
	# Parabolic Ballistic Arc Calculation
	if arc_height > 0.0 and max_range > 0.0:
		var t = clampf(_distance_traveled / max_range, 0.0, 1.0)
		var arc_y = 4.0 * arc_height * t * (1.0 - t)
		global_position.y = lerp(_base_spawn_y, 0.08, t) + arc_y
	else:
		global_position.y += forward_dir.y * step
		
	# Flight spin for throwing axes / tumbling projectiles
	if spins_in_flight:
		var sprite_node = get_node_or_null("Sprite3D") as Sprite3D
		if sprite_node:
			sprite_node.rotation.z += spin_speed * delta
		var model = get_node_or_null("CannonBallModel")
		if model and model.visible:
			model.rotate_x(spin_speed * delta)

	# Travel distance clamp (primary check: total travel progress vs max_range)
	if _distance_traveled >= max_range or global_position.distance_to(_spawn_pos) >= max_range:
		_is_destroyed = true
		set_deferred("monitoring", false)
		set_deferred("monitorable", false)
		AudioManager.play_sfx("water_splashes")
		_spawn_splash(true)
		queue_free()
		return

	lifetime -= delta
	if lifetime <= 0.0:
		_is_destroyed = true
		set_deferred("monitoring", false)
		set_deferred("monitorable", false)
		if GameState.boss_spawned:
			print("[CANNON EXPIRED] %s lifetime ended at %s" % [name, global_position])
		AudioManager.play_sfx("water_splashes")
		_spawn_splash(true)
		queue_free()

func _on_hit(target: Node) -> void:
	if _is_destroyed or not target or not is_instance_valid(target):
		return
		
	var hostile = is_hostile or is_in_group("enemy_projectiles") or has_meta("is_hostile")
	if hostile:
		var is_player = target.is_in_group("player") or (target.get_parent() and target.get_parent().is_in_group("player"))
		var is_follower = target.is_in_group("follower") or (target.get_parent() and target.get_parent().is_in_group("follower"))
		if is_player or is_follower:
			_is_destroyed = true
			set_deferred("monitoring", false)
			set_deferred("monitorable", false)
			for child in get_children():
				if child is CollisionShape3D:
					child.set_deferred("disabled", true)
			GameState.record_hit()
			var player = get_tree().get_first_node_in_group("player")
			if player:
				if is_follower:
					var follower = target
					if not follower.has_method("destroy_follower") and target.get_parent() and target.get_parent().has_method("destroy_follower"):
						follower = target.get_parent()
					if player.has_method("leak_threat"):
						player.leak_threat(follower)
					elif follower.has_method("destroy_follower"):
						follower.destroy_follower()
				else:
					if player.has_method("leak_threat"):
						player.leak_threat(player)
					elif player.has_method("take_hit"):
						player.take_hit(damage, "enemy_cannonball")
			AudioManager.play_sfx("barrel_hits")
			_spawn_splash(false)
			queue_free()
		return
		
	# Ignore player, followers, other cannonballs, and non-combat items
	if target.is_in_group("player") or target.is_in_group("follower") or target.is_in_group("cannonballs") or target.is_in_group("collectibles") or target.is_in_group("multiplier_gate"):
		return

	# Ignore already destroyed boss subparts
	if target is BossComponentDelegate and is_instance_valid(target.boss_node):
		var comp_var = "hp_" + target.component_name
		if comp_var in target.boss_node and target.boss_node.get(comp_var) <= 0:
			return
		
	if target.is_in_group("destructible") or target.is_in_group("enemies") or target.is_in_group("boss") or target.has_method("take_damage"):
		_is_destroyed = true
		set_deferred("monitoring", false)
		set_deferred("monitorable", false)
		for child in get_children():
			if child is CollisionShape3D:
				child.set_deferred("disabled", true)
				
		var target_pos = (target as Node3D).global_position if target is Node3D else Vector3.ZERO
		if GameState.boss_spawned:
			print("[CANNON HIT] %s HIT %s (groups: %s, pos: %s) at ball pos: %s | Dmg: %d" % [
				name,
				target.name,
				target.get_groups(),
				target_pos,
				global_position,
				damage
			])
		
		AudioManager.play_sfx("barrel_hits")
		if target.has_method("take_damage"):
			target.take_damage(damage)
		elif target.get_parent() and target.get_parent().has_method("take_damage"):
			target.get_parent().take_damage(damage)
			
		# Apply splash AoE to nearby destructibles if ammo has splash_radius
		if (ammo_data and ammo_data.splash_radius > 0.0) or splash_radius_multiplier > 1.0:
			_apply_splash_damage(target)
				
		_spawn_splash(false)
		queue_free()

func _spawn_splash(at_water_level: bool = false) -> void:
	if hit_splash_scene:
		var splash = hit_splash_scene.instantiate() as Node3D
		var root = get_tree().current_scene
		if root:
			root.add_child(splash)
		elif get_parent():
			get_parent().add_child(splash)
		var splash_pos = global_position
		if at_water_level:
			splash_pos.y = 0.02
		splash.global_position = splash_pos

func _apply_splash_damage(exclude_target: Node = null) -> void:
	var is_mortar = has_meta("is_mortar") or (weapon_data and ("mortar" in weapon_data.weapon_name.to_lower() or "mortar" in weapon_data.weapon_type.to_lower())) or (ammo_data and ("mortar" in ammo_data.ammo_name.to_lower() or ammo_data.splash_radius >= 3.0))
	if is_mortar:
		AudioManager.play_sfx("sfx_mortar_impact")
		if VFXManager:
			VFXManager.spawn_mortar_splash(global_position)
		var camera = get_tree().get_first_node_in_group("game_camera")
		if camera and camera.has_method("add_trauma"):
			camera.add_trauma(0.45)

	var base_radius = ammo_data.splash_radius if (ammo_data and ammo_data.splash_radius > 0.0) else 2.5
	var radius = base_radius * splash_radius_multiplier
	var splash_dmg = ammo_data.aoe_damage if (ammo_data and "aoe_damage" in ammo_data and ammo_data.aoe_damage > 0) else damage
	var targets: Array[Node] = []
	targets.append_array(get_tree().get_nodes_in_group("destructible"))
	targets.append_array(get_tree().get_nodes_in_group("enemies"))
	
	var processed: Dictionary = {}
	for obj in targets:
		if obj != null and is_instance_valid(obj) and obj != self and not processed.has(obj):
			processed[obj] = true
			if obj == exclude_target or (exclude_target and obj == exclude_target.get_parent()):
				continue
			if obj is Node3D:
				var dist = (obj as Node3D).global_position.distance_to(global_position)
				if dist <= radius and obj.has_method("take_damage"):
					obj.take_damage(splash_dmg)

	if crew_id == "monkey_bomber" and crew_level >= 3 and not has_meta("is_cluster_sub"):
		_trigger_cluster_bounce()
	elif crew_id == "skeleton_tosser" and crew_level >= 3:
		_trigger_lingering_napalm()

func _trigger_cluster_bounce() -> void:
	var root = get_tree().current_scene if get_tree() else get_parent()
	if not root:
		return
	var ball_scene = load("res://src/gameplay/projectiles/cannonball.tscn")
	if not ball_scene:
		return
	for offset_x in [-1.0, 1.0]:
		var mini = ball_scene.instantiate() as Area3D
		mini.set_meta("is_cluster_sub", true)
		root.add_child(mini)
		mini.global_position = global_position + Vector3(offset_x, 0.4, randf_range(-0.4, 0.4))
		mini.damage = 3
		mini.speed = 8.0
		mini.max_range = 3.5
		var dir = Vector3(offset_x * 0.4, 0.2, -0.8).normalized()
		mini.setup(dir, ammo_data, null)
		mini.scale = Vector3(0.5, 0.5, 0.5)

func _trigger_lingering_napalm() -> void:
	var root = get_tree().current_scene if get_tree() else get_parent()
	if not root:
		return
	var puddle = Area3D.new()
	puddle.collision_layer = 2
	puddle.collision_mask = 5 # hits enemies and destructibles
	root.add_child(puddle)
	puddle.global_position = Vector3(global_position.x, 0.05, global_position.z)
	
	var col = CollisionShape3D.new()
	var shape = CylinderShape3D.new()
	shape.radius = 2.4
	shape.height = 1.0
	col.shape = shape
	puddle.add_child(col)
	
	# Visual fire pool
	var mesh_inst = MeshInstance3D.new()
	var disc = CylinderMesh.new()
	disc.top_radius = 2.4
	disc.bottom_radius = 2.4
	disc.height = 0.02
	mesh_inst.mesh = disc
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.4, 0.05, 0.6)
	mesh_inst.material_override = mat
	puddle.add_child(mesh_inst)
	
	# Napalm damage ticks over 2 seconds
	var napalm_tween = puddle.create_tween()
	for i in range(4):
		napalm_tween.tween_callback(func():
			if is_instance_valid(puddle):
				for body in puddle.get_overlapping_areas():
					if is_instance_valid(body) and body.is_in_group("enemies") and not body.is_in_group("player"):
						if body.has_method("take_damage"):
							body.take_damage(2)
		)
		napalm_tween.tween_interval(0.5)
	napalm_tween.tween_property(mat, "albedo_color:a", 0.0, 0.4)
	napalm_tween.tween_callback(puddle.queue_free)

func apply_gate_glow() -> void:
	var sprite_node = get_node_or_null("Sprite3D") as Sprite3D
	if sprite_node:
		sprite_node.modulate = Color(2.5, 2.0, 0.5, 1.0)
	
	var model = get_node_or_null("CannonBallModel")
	if model:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.6, 0.1)
		mat.emission_enabled = true
		mat.emission = Color(2.5, 1.5, 0.2)
		if model is MeshInstance3D:
			model.material_override = mat
		else:
			for child in model.get_children():
				if child is MeshInstance3D:
					child.material_override = mat
