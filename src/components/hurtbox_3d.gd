class_name Hurtbox3D
extends Area3D

## Hurtbox3D — Receives damage and routes to HealthComponent (Blueprint 2).
##
## Attach as a child Area3D to any entity that can take damage. Wire
## health_component to the sibling HealthComponent node. The parent entity
## listens to HealthComponent.died for its death logic — Hurtbox3D itself
## never triggers death or VFX directly.
##
## Legacy entry point: take_hit() is also called directly by scripts that
## predate the Hitbox3D system (cannonball.gd, hazard scripts). This keeps
## backward compatibility while the codebase migrates.

## Emitted on every successful damage received, before HealthComponent updates.
## Listeners can react (e.g. hit flash, screen shake) without coupling.
signal hit_received(damage: int, source_info: String)

## Linked HealthComponent. If null, damage is still signaled but not tracked.
@export var health_component: HealthComponent

func take_hit(damage: int, source_info: String = "") -> void:
	hit_received.emit(damage, source_info)
	if health_component and is_instance_valid(health_component):
		health_component.take_damage(damage, source_info)
