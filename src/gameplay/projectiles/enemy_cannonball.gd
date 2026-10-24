class_name EnemyCannonball
extends Area3D

@export var speed: float = 18.0
@export var lifetime: float = 4.5
var direction: Vector3 = Vector3(0, 0, 1)

const TRAIL_3D_SCENE: PackedScene = preload("res://src/vfx/trail_3d.tscn")
var _trail: Node3D = null

func attach_fire_trail() -> void:
	if _trail and is_instance_valid(_trail):
		return
	if TRAIL_3D_SCENE:
		var t := TRAIL_3D_SCENE.instantiate() as Node3D
		if t:
			add_child(t)
			_trail = t

func _detach_trail() -> void:
	if _trail and is_instance_valid(_trail):
		if _trail.has_method("detach_and_fade"):
			_trail.call("detach_and_fade")
		_trail = null

func _check_and_attach_fire_trail() -> void:
	if _trail and is_instance_valid(_trail):
		return
	if has_meta("is_fire") or has_meta("is_incendiary") or has_meta("is_volcanic") or has_meta("is_magma") or has_meta("is_brimstone"):
		attach_fire_trail()

func setup(p_direction: Vector3 = Vector3.ZERO, _p_ammo_data: Resource = null, _p_weapon_data: Resource = null) -> void:
	if p_direction != Vector3.ZERO:
		direction = p_direction.normalized()
	else:
		var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D if get_tree() else null
		if player and is_instance_valid(player):
			var to_player: Vector3 = (player.global_position - global_position)
			to_player.y = 0.0
			if to_player.length_squared() > 0.01:
				direction = to_player.normalized()
			else:
				direction = Vector3(0, 0, 1)
		else:
			direction = Vector3(0, 0, 1)

	# Safeguard: Enemy projectiles must travel downriver (+Z) toward player
	if direction.z < 0.0:
		direction.z = abs(direction.z)
	if direction.length_squared() > 0.001:
		direction = direction.normalized()

func _ready() -> void:
	add_to_group("enemy_projectiles")
	area_entered.connect(_on_hit)
	body_entered.connect(_on_hit)
	
	# Auto-detect 2D billboard sprite: if present, hide default 3D sphere meshes
	var spr := get_node_or_null("AmmoSprite") as Sprite3D
	if not spr:
		spr = get_node_or_null("Sprite3D") as Sprite3D
	if spr:
		var core := get_node_or_null("FireCore") as Node3D
		if core: core.visible = false
		var glow := get_node_or_null("FireGlow") as Node3D
		if glow: glow.visible = false
		
	# If direction is default, aim toward player vessel at current position
	if direction == Vector3(0, 0, 1):
		var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
		if player and is_instance_valid(player):
			var to_player: Vector3 = (player.global_position - global_position)
			to_player.y = 0.0
			if to_player.length_squared() > 0.01 and to_player.z > 0.1:
				direction = to_player.normalized()
				
	_check_and_attach_fire_trail()

func set_color(color: Color) -> void:
	var spr := get_node_or_null("AmmoSprite") as Sprite3D
	if not spr:
		spr = get_node_or_null("Sprite3D") as Sprite3D
	if spr:
		spr.modulate = color

	var core := get_node_or_null("FireCore") as MeshInstance3D
	if core:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = color
		core.material_override = mat
	var glow := get_node_or_null("FireGlow") as MeshInstance3D
	if glow:
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(color.r, color.g, color.b, 0.45)
		glow.material_override = mat


var _time: float = 0.0

func _physics_process(delta: float) -> void:
	_time += delta
	var spr := get_node_or_null("AmmoSprite") as Sprite3D
	if spr:
		spr.scale = Vector3.ONE * (1.0 + sin(_time * 16.0) * 0.05)
		
	var fwd := direction if direction != Vector3.ZERO else Vector3(0, 0, 1)
	if fwd.z < 0.0:
		fwd.z = abs(fwd.z)
	global_position += fwd * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		_detach_trail()
		queue_free()

func _on_hit(target: Node) -> void:
	var is_player := target.is_in_group("player") or (target.get_parent() and target.get_parent().is_in_group("player"))
	var is_follower := target.is_in_group("follower") or (target.get_parent() and target.get_parent().is_in_group("follower"))
	
	if is_player or is_follower:
		GameState.record_hit()
		var player: Node = get_tree().get_first_node_in_group("player")
		if player:
			if is_follower:
				var follower: Node = target
				if not follower.has_method("destroy_follower") and target.get_parent() and target.get_parent().has_method("destroy_follower"):
					follower = target.get_parent()
				if player.has_method("leak_threat"):
					player.call("leak_threat", follower)
				elif follower.has_method("destroy_follower"):
					follower.call("destroy_follower")
			else:
				var cur_lvl: int = GameState.current_level if GameState else 1
				var dmg: int = 1 if cur_lvl <= 5 else 2
				if player.has_method("take_hit"):
					player.call("take_hit", dmg, "enemy_cannonball")
				elif player.has_method("leak_threat"):
					player.call("leak_threat", player)
						
		var splash_scene := preload("res://src/vfx/hit_splash.tscn")
		if splash_scene:
			var splash := splash_scene.instantiate() as Node3D
			var root := get_tree().current_scene
			if root:
				root.add_child(splash)
			splash.global_position = global_position
		_detach_trail()
		queue_free()
