class_name HazardWhirlpool
extends Area3D

## Suction / Pull force parameters
@export var pull_radius: float = 6.0
@export var inner_damage_radius: float = 2.4
@export var pull_strength: float = 4.5
@export var damage: int = 1
@export var spin_speed_deg: float = 120.0

@onready var whirlpool_sprite: Sprite3D = get_node_or_null("Visuals/WhirlpoolSprite") as Sprite3D
@onready var collision_shape: CollisionShape3D = get_node_or_null("CollisionShape3D") as CollisionShape3D

var _time: float = 0.0
var _cooldown_timer: float = 0.0

func _ready() -> void:
	add_to_group("hazards")
	add_to_group("obstacles")
	scale = Vector3(0.76, 0.76, 0.76)
	
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if not GameState.is_game_active:
		return
		
	_time += delta
	_cooldown_timer -= delta
	
	# Continuous vortex swirl animation
	if whirlpool_sprite:
		whirlpool_sprite.rotation_degrees.z += spin_speed_deg * delta
		var pulse: float = 1.0 + sin(_time * 3.0) * 0.04
		whirlpool_sprite.scale = Vector3(pulse, pulse, 1.0)
		
	# Suction pull logic for player boat and floating items nearby
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D if get_tree() else null
	if player and is_instance_valid(player):
		var dx: float = global_position.x - player.global_position.x
		var dz: float = global_position.z - player.global_position.z
		var h_dist: float = sqrt(dx * dx + dz * dz)
		if h_dist <= pull_radius:
			# Pull player towards whirlpool center
			var dir_to_center: Vector3 = Vector3(dx, 0.0, dz).normalized()
			var pull_force: float = (1.0 - (h_dist / pull_radius)) * pull_strength
			player.global_position += dir_to_center * pull_force * delta
			
			# If player gets sucked into the inner core, take damage
			if h_dist <= inner_damage_radius and _cooldown_timer <= 0.0:
				_cooldown_timer = 1.2
				if player.has_method("damage_fleet"):
					player.call("damage_fleet", damage)
				elif player.has_method("take_hit"):
					player.call("take_hit", damage, "whirlpool_vortex")
				AudioManager.play_sfx("water_splashes", 0.8, 1.2, 2.0)
				var camera: Node = get_tree().get_first_node_in_group("game_camera")
				if camera and camera.has_method("shake"):
					camera.call("shake", 0.25, 0.22)

	# Despawn if passed beyond player
	var player_z: float = player.global_position.z if player else 0.0
	if global_position.z > (player_z + 10.0):
		queue_free()

func _on_area_entered(area: Area3D) -> void:
	_check_vortex_entry(area)

func _on_body_entered(body: Node3D) -> void:
	if not body or not is_instance_valid(body):
		return
	if body.is_in_group("player") or body is PlayerSwerve:
		if _cooldown_timer <= 0.0:
			_cooldown_timer = 1.2
			if body.has_method("damage_fleet"):
				body.call("damage_fleet", damage)
			elif body.has_method("take_hit"):
				body.call("take_hit", damage, "whirlpool_vortex")
			AudioManager.play_sfx("water_splashes", 0.8, 1.2, 2.0)
			var camera: Node = get_tree().get_first_node_in_group("game_camera")
			if camera and camera.has_method("shake"):
				camera.call("shake", 0.25, 0.22)
	_check_vortex_entry(body)

func _check_vortex_entry(node: Node) -> void:
	if not node:
		return
	if node.is_in_group("collectibles") or node.is_in_group("doubloons"):
		var tween: Tween = create_tween()
		tween.tween_property(node, "global_position", global_position + Vector3(0.0, 0.05, 0.0), 0.5)
