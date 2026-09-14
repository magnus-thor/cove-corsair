Godot 4 Scalable Architecture & System Design GuideCore Philosophy: Loose Coupling, High Cohesion. Build small, isolated systems that communicate through explicit contracts and can run in isolation.1. Project Organization: Feature-First StructureAvoid organizing files by type (/scripts, /scenes, /textures). Organize by Feature Encapsulation. Everything needed for a feature to function lives together in the same folder.Plaintextres://
├── src/
│   ├── core/                      # Global singletons / base primitives
│   │   ├── event_bus.gd           # Lean, centralized event routing
│   │   └── game_state.gd          # Pure data persistence (SSOT)
│   │
│   ├── components/                # Reusable node components (plug-and-play)
│   │   ├── health_component.gd
│   │   ├── hitbox_component.gd
│   │   └── hurtbox_component.gd
│   │
│   ├── features/
│   │   ├── player/                # Everything player-related
│   │   │   ├── player.tscn
│   │   │   ├── player.gd
│   │   │   └── player_movement.gd
│   │   ├── enemies/               # Base enemy scenes and inherited variants
│   │   │   ├── base_enemy.tscn
│   │   │   ├── base_enemy.gd
│   │   │   ├── fodder_skiff/
│   │   │   └── phantom_dredge/
│   │   ├── hazards/               # Mines, barricades, barrels
│   │   └── shipyard/              # Store, outfitting, crew cards
│   │
│   └── vfx/                       # Shared shaders, ribbon trails, explosion particles
2. The 4 Fundamental Communication RulesRule A: "Signal Up, Call Down"Call Down: Parents hold @onready references to child nodes and control them by calling functions directly:GDScript$CollisionShape3D.set_deferred("disabled", true)
$HealthComponent.take_damage(amount)
Signal Up: Children never use get_parent() or call methods on ancestor nodes. Children emit signals upwards for any parent or manager to observe:GDScriptsignal health_depleted()
Rule B: Signals Report Events, Never CommandsSignals describe what happened in the past, not what another system should do:❌ Command: signal update_hud_gold(amount)✅ Event: signal gold_collected(amount: int, new_total: int)The emitter broadcasts the event with context data and immediately moves on; it does not care who is listening or what they do with the data.Rule C: Single Source of Truth (SSOT)Every piece of game data exists in exactly one place:Health lives in the HealthComponent, not duplicated in the player script and HUD.An obstacle owns its destruction, collider disabling, and death particle instantiation at its own global_position.The attacker does not modify the victim's position or health directly; it calls victim.take_hit(damage, context).Rule D: Strict Static TypingTurn on strict warnings in Project Settings $\rightarrow$ Debug $\rightarrow$ GDScript:untyped_declaration = Warningunsafe_property_access = Warningunsafe_method_access = WarningExplicit types clarify intent, enable autocomplete, and catch bugs before runtime:GDScriptfunc apply_damage(amount: int, source_id: String) -> void:
3. Core Component BlueprintsBlueprint 1: Universal HealthComponentA self-contained node that handles health, clamping, and death signals for any damageable entity (Player, Enemy, Obstacle, Boss).GDScriptclass_name HealthComponent
extends Node

signal health_changed(current: int, max_hp: int)
signal damage_taken(amount: int, source_info: String)
signal died()

@export var max_health: int = 10
var current_health: int
var is_dead: bool = false

func _ready() -> void:
	current_health = max_health

func take_damage(amount: int, source_info: String = "") -> void:
	if is_dead or amount <= 0:
		return
	
	current_health = max(0, current_health - amount)
	damage_taken.emit(amount, source_info)
	health_changed.emit(current_health, max_health)
	
	if current_health <= 0:
		is_dead = true
		died.emit()

func heal(amount: int) -> void:
	if is_dead:
		return
	current_health = min(max_health, current_health + amount)
	health_changed.emit(current_health, max_health)
Blueprint 2: Decoupled Hitbox3D & Hurtbox3DSeparating the ability to deal damage from the ability to receive damage allows full reusability (e.g., a spike trap only needs a Hitbox, a breakable crate only needs a Hurtbox).Hurtbox3D.gd (Receives Damage)GDScriptclass_name Hurtbox3D
extends Area3D

signal hit_received(damage: int, source_info: String)

@export var health_component: HealthComponent

func take_hit(damage: int, source_info: String = "") -> void:
	hit_received.emit(damage, source_info)
	if health_component:
		health_component.take_damage(damage, source_info)
Hitbox3D.gd (Deals Damage)GDScriptclass_name Hitbox3D
extends Area3D

@export var damage: int = 1
@export var damage_type: String = "kinetic"

func _ready() -> void:
	area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area3D) -> void:
	if area is Hurtbox3D:
		area.take_hit(damage, damage_type)
Blueprint 3: Self-Contained Destructible Entity (BaseDestructible)Handles its own death sequence, collider shutdown, and world-space particle emission without relying on the attacker.GDScriptclass_name BaseDestructible
extends Area3D

signal destroyed(death_position: Vector3)

@export var health_component: HealthComponent
@export var death_vfx_scene: PackedScene
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

func _ready() -> void:
	if health_component:
		health_component.died.connect(_on_died)

func take_hit(amount: int, source_info: String = "") -> void:
	if health_component:
		health_component.take_damage(amount, source_info)

func _on_died() -> void:
	# 1. Immediate collider shutdown to prevent multi-hit phantom frames
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	collision_layer = 0
	collision_mask = 0
	
	var death_pos: Vector3 = global_position
	destroyed.emit(death_pos)
	
	# 2. Spawn death VFX in world root so it outlives this entity
	if death_vfx_scene:
		var vfx = death_vfx_scene.instantiate()
		get_tree().current_scene.add_child(vfx)
		vfx.global_position = death_pos
	
	# 3. Clean up
	queue_free()
Blueprint 4: Lean Event Bus (EventBus.gd)Use Autoloads strictly for cross-boundary event broadcasting, not for storing game logic or monolithic dependencies.GDScriptextends Node

# Global game events (Strictly past-tense, reporting what occurred)
signal level_started(level_index: int)
signal level_completed(level_index: int, score: int)
signal player_sunk()
signal doubloons_changed(new_balance: int, delta: int)
signal combo_streak_reached(streak_count: int, buff_type: String)
4. Architectural Rules Checklist for Code ReviewsBefore committing new features, run through this check:[ ] No Monoliths: Does any single script handle input, movement, health, inventory, and rendering together? If so, extract components.[ ] Collider Safety: Are colliders disabled via set_deferred("disabled", true) on the exact frame an object dies?[ ] World Space VFX: Are lingering VFX instantiated and added to get_tree().current_scene at global_position instead of attached to dying nodes?[ ] Signal Semantics: Do signal names describe past events (item_unlocked) rather than imperative orders (unlock_item)?[ ] No Direct Parent Mutations: Does any child node call get_parent().some_method()? If yes, refactor to emit a signal upwards instead.[ ] Static Typing: Are all function arguments, return types, and member variables explicitly typed?