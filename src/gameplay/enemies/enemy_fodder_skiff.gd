class_name EnemyFodderSkiff
extends Area3D

## High-speed 1-HP fodder skiff designed to spawn in rapid swarms.
## Awards 0 doubloons upon destruction, but feeds into the Fire Frenzy streak system.

## Emitted when this vessel is destroyed (past-tense event, Rule 1).
signal vessel_died(world_pos: Vector3)

@export var max_hp: int = 1
@export var current_hp: int = 1
@export var forward_speed: float = 7.5
@export var doubloons_drop: int = 0

@export var explosion_scene: PackedScene = preload("res://src/gameplay/vfx/barrel_explosion.tscn")

@onready var sprite_node: Sprite3D = get_node_or_null("Sprite3D")
@onready var collision_shape: CollisionShape3D = get_node_or_null("CollisionShape3D")

var _is_dead: bool = false
var _flash_tween: Tween

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("destructible")
	add_to_group("fodder")
	current_hp = max_hp
	doubloons_drop = 0
	area_entered.connect(_on_area_entered)
	
	# Attach stern hydrodynamic water wake
	var wake_scene = preload("res://src/gameplay/vfx/boat_wake.tscn")
	if wake_scene:
		var wake = wake_scene.instantiate()
		add_child(wake)
		wake.position = Vector3(0, 0.02, -0.6)
		wake.rotation_degrees = Vector3(0, 180, 0)
		wake.scale = Vector3(0.5, 0.5, 0.5)

func _physics_process(delta: float) -> void:
	if _is_dead or not GameState.is_game_active:
		return
		
	# Move steadily down-channel toward the player
	global_position.z += forward_speed * delta

	var player = get_tree().get_first_node_in_group("player")
	var player_z = player.global_position.z if player else 0.0
	if global_position.z > (player_z + 3.0):
		GameState.record_mob_leaked()
		if player and player.has_method("leak_threat"):
			player.leak_threat(self)
		queue_free()

func _on_area_entered(area: Area3D) -> void:
	if _is_dead:
		return
	if area.is_in_group("player") or (area.get_parent() and area.get_parent().is_in_group("player")):
		var player = get_tree().get_first_node_in_group("player")
		if player and player.has_method("take_hit"):
			player.take_hit(1, "fodder_skiff_ram")
		die()

## Canonical damage entry point (Rule 2).
func take_hit(amount: int, _source_info: String = "") -> void:
	take_damage(amount)

func take_damage(amount: int) -> void:
	if _is_dead:
		return
	current_hp = max(0, current_hp - amount)
	_flash()
	if current_hp <= 0:
		die()

func _flash() -> void:
	HitFlashComponent.flash_node(self, 0.065)

func die() -> void:
	if _is_dead:
		return
	_is_dead = true

	# Rule 1 — Signal Up: emit past-tense event before dismantling self.
	vessel_died.emit(global_position)

	# Rule 4 — Immediate collider shutdown: prevent ghost contacts on the corpse frame.
	collision_layer = 0
	collision_mask = 0
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)

	GameState.targets_destroyed += 1
	GameState.record_fodder_kill()
	AudioManager.play_sfx("barrel_breaks")
	
	if explosion_scene:
		var vfx = explosion_scene.instantiate() as Node3D
		var root = get_tree().current_scene
		if root:
			root.add_child(vfx)
		vfx.global_position = global_position
		
	# Strictly award zero doubloons to maintain economy integrity
	queue_free()
