class_name HazardThermalGeyser
extends Node3D

@export var forward_speed: float = 6.0
@export var telegraph_duration: float = 1.8
@export var eruption_duration: float = 1.8
@export var eruption_radius: float = 1.6
@export var damage: int = 1
@export var auto_destroy_behind_player: bool = true

@onready var geyser_sprite: Sprite3D = get_node_or_null("GeyserSprite") as Sprite3D
@onready var damage_area: Area3D = get_node_or_null("DamageArea") as Area3D
@onready var telegraph_decal: MeshInstance3D = get_node_or_null("TelegraphDecal") as MeshInstance3D

var _state: int = 0 # 0 = telegraph, 1 = erupting, 2 = done
var _timer: float = 0.0
var _has_damaged_player: bool = false

func _ready() -> void:
	add_to_group("hazards")
	scale = Vector3(1.12, 1.12, 1.12)
	telegraph_duration = maxf(1.6, telegraph_duration) # Enforce at least 1.6s warning
	if geyser_sprite:
		geyser_sprite.visible = true
	if damage_area:
		damage_area.monitoring = false
		if not damage_area.area_entered.is_connected(_on_damage_area_entered):
			damage_area.area_entered.connect(_on_damage_area_entered)
	if telegraph_decal:
		telegraph_decal.visible = true
		
	AudioManager.play_sfx("water_splashes", 1.4, 1.8, -2.0)

func _physics_process(delta: float) -> void:
	_timer += delta
	
	# Move downriver towards player vessel
	if forward_speed > 0.0 and GameState.is_game_active:
		global_position.z += forward_speed * delta
		
	var player = get_tree().get_first_node_in_group("player")
	var player_z = player.global_position.z if player and is_instance_valid(player) else 0.0
	if auto_destroy_behind_player and global_position.z > (player_z + 4.0):
		queue_free()
		return
	
	if _state == 0:
		# Sprite heat build-up pulse
		var heat_pulse = 1.0 + sin(_timer * 14.0) * 0.15
		if geyser_sprite:
			geyser_sprite.modulate = Color(1.0 + heat_pulse * 0.5, 0.8 + heat_pulse * 0.2, 0.7)
		if telegraph_decal and telegraph_decal.material_override:
			var mat = telegraph_decal.material_override as StandardMaterial3D
			if mat:
				mat.albedo_color.a = clampf(0.3 + sin(_timer * 10.0) * 0.25, 0.15, 0.75)
			
		if _timer >= telegraph_duration:
			_state = 1
			_timer = 0.0
			_erupt()
			
	elif _state == 1:
		_check_eruption_hits()
		if _timer >= eruption_duration:
			_state = 2
			queue_free()

func _erupt() -> void:
	if telegraph_decal:
		telegraph_decal.visible = false
	if geyser_sprite:
		geyser_sprite.visible = true
		geyser_sprite.modulate = Color(2.2, 1.3, 0.5)
		var tween = create_tween()
		tween.tween_property(geyser_sprite, "scale", Vector3(1.3, 1.5, 1.3), 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(geyser_sprite, "scale", Vector3(1.0, 1.0, 1.0), eruption_duration - 0.20)

	if damage_area:
		damage_area.monitoring = true
		
	AudioManager.play_sfx("barrel_breaks", 0.6, 0.8, 3.0)
	AudioManager.play_sfx("water_splashes", 0.7, 0.9, 2.0)
	
	# Camera shake
	var camera = get_tree().get_first_node_in_group("game_camera")
	if camera and camera.has_method("shake"):
		camera.shake(0.28, 0.25)
		
	_check_eruption_hits()

var _damaged_enemies: Dictionary = {}

func _on_damage_area_entered(area: Area3D) -> void:
	if _state == 1:
		if area.is_in_group("player") or area.is_in_group("follower"):
			_check_eruption_hits()
		elif (area.is_in_group("enemies") or area.is_in_group("destructible")) and not area.is_in_group("boss"):
			_damage_enemy(area)

func _damage_enemy(enemy: Node) -> void:
	if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
		return
	var id = enemy.get_instance_id()
	if _damaged_enemies.has(id) and (_timer - _damaged_enemies[id]) < 0.35:
		return
	_damaged_enemies[id] = _timer
	
	if enemy.has_method("take_damage"):
		enemy.take_damage(14)
	elif "current_hp" in enemy:
		enemy.current_hp -= 14
		if enemy.current_hp <= 0 and enemy.has_method("die"):
			enemy.die()
			
	AudioManager.play_sfx("barrel_breaks", 0.7, 0.9, 2.0)
	AudioManager.play_sfx("water_splashes", 0.8, 1.1, 1.0)

func _check_eruption_hits() -> void:
	# 1. Player check
	if not _has_damaged_player:
		var player = get_tree().get_first_node_in_group("player")
		if player and is_instance_valid(player):
			var dist = player.global_position.distance_to(global_position)
			if dist <= eruption_radius:
				_has_damaged_player = true
				if player.has_method("damage_fleet"):
					player.damage_fleet(damage)
				# Horizontal push / knockback
				var push_dir = (player.global_position - global_position).normalized()
				var push_x = push_dir.x if abs(push_dir.x) > 0.1 else (1.0 if randf() < 0.5 else -1.0)
				player.global_position.x += push_x * 2.0

	# 2. Enemy checks: damage any enemies within eruption radius or overlapping DamageArea
	if damage_area and is_instance_valid(damage_area) and damage_area.monitoring:
		for overlapping in damage_area.get_overlapping_areas():
			if is_instance_valid(overlapping) and (overlapping.is_in_group("enemies") or overlapping.is_in_group("destructible")) and not overlapping.is_in_group("boss"):
				_damage_enemy(overlapping)
				
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and not enemy.is_in_group("boss") and not enemy.is_queued_for_deletion():
			if enemy.global_position.distance_to(global_position) <= eruption_radius:
				_damage_enemy(enemy)
