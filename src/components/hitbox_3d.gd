class_name Hitbox3D
extends Area3D

## Hitbox3D — Deals damage on area contact (ARCHITECTURE.md Blueprint 2).
##
## Attach as a child Area3D to any entity that deals damage on contact
## (projectiles, hazard zones, melee swings, explosion radii).
##
## On area_entered, checks whether the overlapping area is a Hurtbox3D and
## routes damage through it. The Hurtbox3D then feeds into its HealthComponent.
##
## The attacker NEVER reads the victim's health state or spawns victim VFX.

## Base damage delivered per contact.
@export var damage: int = 1

## Semantic damage type string — targets inspect this in their take_hit() to
## apply vulnerability/resistance multipliers (e.g. "spectral_salt" vs ghosts,
## "battering_shot" vs barricades).
@export var damage_type: String = "kinetic"

## Optional reference to the emitting entity for source attribution in signals.
@export var source_node: Node = null

## When true, this hitbox deactivates itself after the first successful hit.
## Useful for single-contact projectiles.
@export var one_shot: bool = false

func _ready() -> void:
	area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area3D) -> void:
	if area is Hurtbox3D:
		(area as Hurtbox3D).take_hit(damage, damage_type)
		if one_shot:
			set_deferred("monitoring", false)
			set_deferred("monitorable", false)
