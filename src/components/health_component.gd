class_name HealthComponent
extends Node

## Universal HealthComponent (ARCHITECTURE.md Blueprint 1).
##
## Self-contained node managing health, clamping, and death notifications for
## any entity. Drop this as a child node and wire up the signals — the parent
## entity never needs to manage raw HP integers again.
##
## Usage:
##   @onready var health_component: HealthComponent = $HealthComponent
##   health_component.died.connect(_on_died)
##   health_component.health_changed.connect(_on_health_changed)

## Emitted whenever health changes (both damage and healing).
signal health_changed(current: int, max_hp: int)

## Emitted on every successful damage application.
signal damage_taken(amount: int, source_info: String)

## Emitted once when health reaches zero. Guaranteed to fire exactly once.
signal died()

@export var max_health: int = 10

## Read-only current health. Use take_damage() / heal() to modify.
var current_health: int:
	get:
		return _current_health
	set(_v):
		push_warning("HealthComponent: do not set current_health directly. Use take_damage() / heal().")

## True from the moment health reaches zero. Prevents duplicate died signals.
var is_dead: bool = false

var _current_health: int = 0

func _ready() -> void:
	_current_health = max_health

## Apply damage. No-ops if dead or amount <= 0.
func take_damage(amount: int, source_info: String = "") -> void:
	if is_dead or amount <= 0:
		return

	_current_health = max(0, _current_health - amount)
	damage_taken.emit(amount, source_info)
	health_changed.emit(_current_health, max_health)

	if _current_health <= 0:
		is_dead = true
		died.emit()

## Apply healing. No-ops if dead.
func heal(amount: int) -> void:
	if is_dead or amount <= 0:
		return
	_current_health = min(max_health, _current_health + amount)
	health_changed.emit(_current_health, max_health)

## Hard-reset to full health (e.g. after applying EnemyData on a recycled mob).
func reset(new_max: int = -1) -> void:
	if new_max > 0:
		max_health = new_max
	_current_health = max_health
	is_dead = false
