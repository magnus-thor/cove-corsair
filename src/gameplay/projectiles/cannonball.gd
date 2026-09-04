class_name Cannonball
extends Area3D

## Speed of the cannonball moving forward
@export var speed: float = 50.0

## Total time the cannonball remains active before self-destruction
@export var lifetime: float = 5.0

## Maximum travel distance from spawn position before self-destructing
@export var max_range: float = 35.0

## Base damage dealt to obstacles
@export var damage: int = 1

## Splash radius multiplier applied when cannonballs exceed soft cap
@export var splash_radius_multiplier: float = 1.0

## Hit splash VFX to spawn on impact or expiration
@export var hit_splash_scene: PackedScene = preload("res://src/gameplay/vfx/hit_splash.tscn")

## Custom ammo data assigned at initialization (optional)
var ammo_data: AmmoData:
	set(val):
		ammo_data = val
		if is_node_ready():
			_apply_ammo_data()

var _is_destroyed: bool = false
var direction: Vector3 = Vector3.ZERO
var _spawn_pos: Vector3 = Vector3.ZERO
var _spawn_pos_initialized: bool = false

func set_spawn_pos(pos: Vector3) -> void:
	_spawn_pos = pos
	_spawn_pos_initialized = true

func setup(p_direction: Vector3, p_ammo_data: AmmoData) -> void:
	direction = p_direction.normalized()
	ammo_data = p_ammo_data
	if ammo_data:
		speed = ammo_data.projectile_speed
		damage = ammo_data.damage
		if ammo_data.scale_multiplier != 1.0:
			scale = Vector3.ONE * ammo_data.scale_multiplier

func _ready() -> void:
	top_level = true
	add_to_group("cannonballs")
	monitoring = false
	monitorable = false
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
	speed = max(24.0, ammo_data.projectile_speed)
	
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
		_spawn_pos_initialized = true

	# Move forward along the direction if set, otherwise along the local negative Z-axis
	if direction != Vector3.ZERO:
		global_position += direction * speed * delta
	else:
		global_position += -global_transform.basis.z * speed * delta
	
	# Travel distance clamp (primary check: 3D Euclidean distance from spawn position)
	if global_position.distance_to(_spawn_pos) >= max_range:
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
			_apply_splash_damage()
				
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

func _apply_splash_damage() -> void:
	var radius = 2.5 * splash_radius_multiplier
	var targets: Array[Node] = []
	targets.append_array(get_tree().get_nodes_in_group("destructible"))
	targets.append_array(get_tree().get_nodes_in_group("enemies"))
	
	var processed: Dictionary = {}
	for obj in targets:
		if obj != null and is_instance_valid(obj) and obj != self and not processed.has(obj):
			processed[obj] = true
			if obj is Node3D:
				var dist = (obj as Node3D).global_position.distance_to(global_position)
				if dist <= radius and obj.has_method("take_damage"):
					obj.take_damage(damage)

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
