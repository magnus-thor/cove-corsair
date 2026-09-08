class_name EnemyCannonball
extends Area3D

@export var speed: float = 11.0
@export var lifetime: float = 4.5
var direction: Vector3 = Vector3(0, 0, 1)

func setup(p_direction: Vector3 = Vector3.ZERO, _p_ammo_data = null, _p_weapon_data = null) -> void:
	if p_direction != Vector3.ZERO:
		direction = p_direction.normalized()
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

func set_color(color: Color) -> void:
	var core = get_node_or_null("FireCore") as MeshInstance3D
	if core:
		var mat = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = color
		core.material_override = mat
	var glow = get_node_or_null("FireGlow") as MeshInstance3D
	if glow:
		var mat = StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(color.r, color.g, color.b, 0.45)
		glow.material_override = mat


func _physics_process(delta: float) -> void:
	var fwd = direction if direction != Vector3.ZERO else Vector3(0, 0, 1)
	if fwd.z < 0.0:
		fwd.z = abs(fwd.z)
	global_position += fwd * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

func _on_hit(target: Node) -> void:
	var is_player = target.is_in_group("player") or (target.get_parent() and target.get_parent().is_in_group("player"))
	var is_follower = target.is_in_group("follower") or (target.get_parent() and target.get_parent().is_in_group("follower"))
	
	if is_player or is_follower:
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
					player.take_hit(1, "enemy_cannonball")
						
		var splash_scene = preload("res://src/gameplay/vfx/hit_splash.tscn")
		if splash_scene:
			var splash = splash_scene.instantiate() as Node3D
			var root = get_tree().current_scene
			if root:
				root.add_child(splash)
			splash.global_position = global_position
		queue_free()
