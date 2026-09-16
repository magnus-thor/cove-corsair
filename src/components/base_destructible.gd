class_name BaseDestructible
extends Area3D

## BaseDestructible — Self-contained obstacle base pattern (Blueprint 3).
##
## Encapsulates the three responsibilities every destructible entity shares:
##   1. Immediate collision shutdown protocol (Rule D) on death.
##   2. Decoupled world-space VFX spawn (outlives the dying node).
##   3. Past-tense destroyed(death_position) signal emission (Rule B).
##
## Subclasses (DestructibleObstacle, BarricadeSegment, HazardSeaMine) inherit
## _on_died() and override it to add type-specific behavior (e.g. doubloon
## drops, boss interrupts) before or after calling super._on_died().

## Emitted immediately before the node is freed. Carries world position so
## listeners (GameState, LevelController) can react without accessing the
## dying node.
signal destroyed(death_position: Vector3)

## Linked HealthComponent — drives the death lifecycle.
@export var health_component: HealthComponent

## Optional VFX scene to spawn at death position, attached to scene root
## so it outlives this node (Rule: Decoupled World VFX).
@export var death_vfx_scene: PackedScene

## Doubloons to award on destruction (0 = no drop).
@export var doubloons_drop: int = 0

## Doubloon collectible scene to spawn per coin drop.
@export var doubloon_scene: PackedScene

var _is_destroyed: bool = false

func _ready() -> void:
	if health_component and is_instance_valid(health_component):
		health_component.died.connect(_on_died)

## Canonical external damage entry point — supports both take_hit and take_damage.
func take_hit(amount: int, source_info: String = "") -> void:
	if _is_destroyed:
		return
	if health_component and is_instance_valid(health_component):
		health_component.take_damage(amount, source_info)

## Backward-compat bridge for scripts that call take_damage() directly.
func take_damage(amount: int) -> void:
	take_hit(amount, "")

## Called automatically by health_component.died signal.
## Subclasses should call super._on_died() AFTER adding their own pre-death logic.
func _on_died() -> void:
	if _is_destroyed:
		return
	_is_destroyed = true

	var death_pos: Vector3 = global_position

	# ── Rule D: Immediate Collision Shutdown ────────────────────────────────
	collision_layer = 0
	collision_mask = 0
	for child in get_children():
		if child is CollisionShape3D:
			child.set_deferred("disabled", true)
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)

	# ── Rule B: Signal Up ───────────────────────────────────────────────────
	destroyed.emit(death_pos)

	# ── Decoupled World VFX ─────────────────────────────────────────────────
	if death_vfx_scene and get_tree():
		var vfx := death_vfx_scene.instantiate() as Node3D
		if vfx:
			vfx.top_level = true
			get_tree().current_scene.add_child(vfx)
			vfx.global_position = death_pos

	# ── Doubloon Drops ──────────────────────────────────────────────────────
	_spawn_doubloon_drops(death_pos)

	queue_free()

## Spawns doubloon collectibles scattered around death_pos.
func _spawn_doubloon_drops(death_pos: Vector3) -> void:
	if doubloons_drop <= 0 or not doubloon_scene or not get_tree():
		return
	var root = get_tree().current_scene
	if not root:
		return
	for i in range(doubloons_drop):
		var coin := doubloon_scene.instantiate() as Node3D
		if coin:
			root.add_child(coin)
			coin.global_position = death_pos + Vector3(
				randf_range(-0.6, 0.6), 0.3, randf_range(-0.6, 0.6)
			)
