class_name EnemyFodderSkiff
extends Area3D

## High-speed 1-HP fodder skiff designed to spawn in rapid swarms.
## Awards 0 doubloons upon destruction, but feeds into the Fire Frenzy streak system.

## Emitted when this vessel is destroyed (past-tense event, Rule 1).
signal vessel_died(world_pos: Vector3)

@export var max_hp: int = 1
@export var forward_speed: float = 7.5
@export var doubloons_drop: int = 0

@export var explosion_scene: PackedScene = preload("res://src/vfx/barrel_explosion.tscn")

@onready var sprite_node: Sprite3D = get_node_or_null("Sprite3D")
@onready var collision_shape: CollisionShape3D = get_node_or_null("CollisionShape3D")
@onready var health_component: HealthComponent = get_node_or_null("HealthComponent")

var _is_dead: bool = false

## Read-only passthrough to HealthComponent for legacy compatibility.
var current_hp: int:
	get:
		return health_component._current_health if health_component else max_hp

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("destructible")
	add_to_group("fodder")
	doubloons_drop = 0
	area_entered.connect(_on_area_entered)
	
	var cur_lvl: int = GameState.current_level if GameState else 1
	if cur_lvl > 30:
		max_hp = 2
		forward_speed = 5.5
	elif cur_lvl > 15:
		max_hp = 1
		forward_speed = 4.0
	elif cur_lvl > 5:
		max_hp = 1
		forward_speed = 3.0
	else:
		max_hp = 1
		forward_speed = 2.0

	# Wire HealthComponent (Blueprint 1)
	if health_component:
		health_component.max_health = max_hp
		health_component.reset()
		health_component.died.connect(die)
	else:
		# Fallback: create one at runtime if scene doesn't have the node yet
		var hc := HealthComponent.new()
		hc.name = "HealthComponent"
		hc.max_health = max_hp
		add_child(hc)
		health_component = hc
		health_component.died.connect(die)
	
	# Attach stern hydrodynamic water wake
	var wake_scene: PackedScene = preload("res://src/vfx/boat_wake.tscn")
	if wake_scene:
		var wake: Node3D = wake_scene.instantiate() as Node3D
		if wake:
			add_child(wake)
			wake.position = Vector3(0, 0.02, -0.6)
			wake.rotation_degrees = Vector3(0, 180, 0)
			wake.scale = Vector3(0.5, 0.5, 0.5)

func _physics_process(delta: float) -> void:
	if _is_dead or not GameState.is_game_active:
		return
		
	# Move steadily down-channel toward the player
	global_position.z += forward_speed * delta

	var player := get_tree().get_first_node_in_group("player") as PlayerSwerve
	var player_z: float = player.global_position.z if player else 0.0
	if global_position.z > (player_z + 3.0):
		GameState.record_mob_leaked()
		queue_free()

func _on_area_entered(area: Area3D) -> void:
	if _is_dead:
		return
	if area.is_in_group("player") or (area.get_parent() and area.get_parent().is_in_group("player")):
		var player := get_tree().get_first_node_in_group("player") as PlayerSwerve
		if player:
			player.take_hit(1, "fodder_skiff_ram")
		die()

## Canonical damage entry point (Rule 2).
func take_hit(amount: int, source_info: String = "") -> void:
	if _is_dead:
		return
	if health_component:
		health_component.take_damage(amount, source_info)
		if not _is_dead:
			_flash()

func take_damage(amount: int) -> void:
	take_hit(amount, "")

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

	# ── Engagement telemetry ─────────────────────────────────────────────────
	if EventBus and EventBus.has_signal("mob_killed"):
		var player_node: Node3D = get_tree().get_first_node_in_group("player") as Node3D
		var dist_to_player: float = 0.0
		if is_instance_valid(player_node):
			dist_to_player = absf(global_position.z - player_node.global_position.z)
		var river_dist: float = GameState.distance_traveled if GameState else 0.0
		EventBus.mob_killed.emit("fodder_skiff", max_hp, dist_to_player, river_dist)
	
	if explosion_scene:
		var vfx := explosion_scene.instantiate() as Node3D
		var root: Node = get_tree().current_scene
		if root and vfx:
			root.add_child(vfx)
			vfx.global_position = global_position
		
	# Strictly award zero doubloons to maintain economy integrity
	queue_free()
