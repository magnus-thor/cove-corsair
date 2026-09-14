# Godot 4 Master Architecture & Game Feel Standards

## Core Philosophy

- **Architecture:** Loose Coupling, High Cohesion, Single Source of Truth (SSOT).
- **Game Feel (Juice):** Immediate tactile feedback for every action (Recoil, Flash, Debris, Audio Pitching).

---

## 1. Directory Structure: Feature Encapsulation

Resist organizing files by type (`/scripts`, `/scenes`, `/textures`). Organize by Feature Units. Everything needed for a feature to function lives together in the same folder.

```text
res://
├── src/
│   ├── core/                          # Project foundation & persistent data
│   │   ├── event_bus.gd               # Global lean signal broker
│   │   ├── game_state.gd              # Pure persistent player/run data (SSOT)
│   │   └── audio_manager.gd           # Pooled 2D/3D SFX with random pitch variation
│   │
│   ├── components/                    # Self-contained, reusable logic blocks
│   │   ├── health_component.gd        # Universal health, damage, and death tracking
│   │   ├── hitbox_component.gd        # Deals damage on contact
│   │   ├── hurtbox_component.gd       # Receives damage and routes to health
│   │   └── juice/
│   │       ├── hit_flash_component.gd # Flashes mesh pure white on impact
│   │       └── screen_shake.gd        # Camera trauma & impulse manager
│   │
│   ├── features/                      # Encapsulated gameplay features
│   │   ├── player/
│   │   │   ├── player.tscn
│   │   │   ├── player.gd              # Orchestrator (Input + Coordination only)
│   │   │   └── player_movement.gd
│   │   ├── enemies/
│   │   │   ├── base_enemy.tscn        # Base template (Inherited scene root)
│   │   │   ├── base_enemy.gd
│   │   │   ├── fodder_skiff/          # Enemy variant scenes & scripts
│   │   │   └── phantom_dredge/
│   │   ├── hazards/                   # Sea mines, Barricades, Destructibles
│   │   └── shipyard/                  # Store UI, Crew cards, Outfitting
│   │
│   └── vfx/                           # Reusable visual effects (Trails, Debris)
```

---

## 2. The 5 Fundamental Communication Rules

### Rule A: "Signal Up, Call Down"

- **Call Down:** Parents hold `@onready` references to child nodes and control them by calling functions directly:
  ```gdscript
  $HurtboxComponent.take_hit(amount, source)
  ```
- **Signal Up:** Children never use `get_parent()` or call methods on ancestor nodes. Children emit signals upwards for any parent or manager to observe:
  ```gdscript
  signal health_depleted()
  ```
- **Cross-Boundary:** Systems without direct hierarchy communicate through `EventBus`.

### Rule B: Signals Report Events, Never Instructions

Signals describe what happened in the past, not what another system should do:

- ❌ **Command:** `signal kill_player()`
- ❌ **Command:** `signal update_hud_gold(amount)`
- ✅ **Event:** `signal detonated(origin_position: Vector3, blast_radius: float)`
- ✅ **Event:** `signal doubloons_changed(new_balance: int, delta: int)`

### Rule C: Single Source of Truth (SSOT)

Every piece of game data exists in exactly one place:

- The victim handles disabling its colliders, queueing itself free, and spawning its death debris at its own `global_position`.
- The attacker does not calculate target health; it simply reports incoming damage via `target.take_hit(damage, source_info)`.

### Rule D: Immediate Collision Shutdown Protocol

On death or detonation, immediately eliminate phantom collisions on that exact physics tick:

```gdscript
collision_shape.set_deferred("disabled", true)
collision_layer = 0
collision_mask = 0
```

### Rule E: Strict Static Typing

Turn on strict warnings in **Project Settings** → **Debug** → **GDScript**:

```ini
untyped_declaration = Warning
unsafe_property_access = Warning
unsafe_method_access = Warning
```

---

## 3. Game Feel & "Juice" Standards

- **Never Let a Projectile Just Disappear:** On hit or miss, spawn a surface effect (splinter burst on wood, water plume on sea).
- **Hit Flash:** Any damageable entity flashes solid white (`Color(1, 1, 1, 1)`) for 0.05s–0.08s before returning to normal material texture.
- **Sound Pitch Variation:** Never play identical SFX consecutively. Always apply pitch randomization (`pitch_scale = randf_range(0.92, 1.08)`).
- **Recoil & Knockback:** Firing heavy weapons nudges the shooter slightly backward. Taking heavy damage nudges the victim slightly back.
- **Decoupled World VFX:** Lingering particles (smoke, fire, debris) must be added to `get_tree().current_scene` at cached `global_position` so they outlive the dying emitter.
- **Micro Screen Shake:** Apply low-frequency, fast-decaying trauma shakes to the active `Camera3D` on heavy impacts (sea mines, boss cannon hits).

---

## 4. Reusable Code Blueprints

### Blueprint 1: Universal HealthComponent (`HealthComponent.gd`)

Self-contained node managing health, clamping, and death notifications for any entity.

```gdscript
class_name HealthComponent
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
```

### Blueprint 2: Decoupled Hurtbox3D & Hitbox3D

Separates receiving damage from dealing damage so components can be mixed and matched.

#### `Hurtbox3D.gd` (Receives Damage)

```gdscript
class_name Hurtbox3D
extends Area3D

signal hit_received(damage: int, source_info: String)

@export var health_component: HealthComponent

func take_hit(damage: int, source_info: String = "") -> void:
	hit_received.emit(damage, source_info)
	if health_component:
		health_component.take_damage(damage, source_info)
```

#### `Hitbox3D.gd` (Deals Damage)

```gdscript
class_name Hitbox3D
extends Area3D

@export var damage: int = 1
@export var damage_type: String = "kinetic"

func _ready() -> void:
	area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area3D) -> void:
	if area is Hurtbox3D:
		area.take_hit(damage, damage_type)
```

### Blueprint 3: Self-Contained Destructible (`BaseDestructible.gd`)

Obstacle base pattern that owns its death, collider zeroing, and detached world VFX.

```gdscript
class_name BaseDestructible
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
	# 1. Immediate collider shutdown
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	collision_layer = 0
	collision_mask = 0
	
	var death_pos: Vector3 = global_position
	destroyed.emit(death_pos)
	
	# 2. Spawn death VFX detached in world root
	if death_vfx_scene:
		var vfx = death_vfx_scene.instantiate()
		get_tree().current_scene.add_child(vfx)
		vfx.global_position = death_pos
	
	# 3. Clean up self
	queue_free()
```

### Blueprint 4: Lean Event Bus (`EventBus.gd`)

Autoload singleton reserved strictly for cross-boundary event broadcasting.

```gdscript
extends Node

# Global game events (strictly past-tense reporting)
signal level_started(level_index: int)
signal level_completed(level_index: int, score: int)
signal player_sunk()
signal doubloons_changed(new_balance: int, delta: int)
signal combo_streak_reached(streak_count: int, buff_type: String)
```

### Blueprint 5: Hit Flash Component (`HitFlashComponent.gd`)

Flashes mesh solid white on impact to provide instant visual hit feedback.

```gdscript
class_name HitFlashComponent
extends Node

@export var target_mesh: GeometryInstance3D
@export var flash_duration: float = 0.07

var _original_material: Material
var _flash_material: StandardMaterial3D

func _ready() -> void:
	if target_mesh and target_mesh.material_override:
		_original_material = target_mesh.material_override
	_flash_material = StandardMaterial3D.new()
	_flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash_material.albedo_color = Color.WHITE

func flash() -> void:
	if not target_mesh:
		return
	target_mesh.material_override = _flash_material
	get_tree().create_timer(flash_duration).timeout.connect(_reset_flash)

func _reset_flash() -> void:
	if is_instance_valid(target_mesh):
		target_mesh.material_override = _original_material
```

### Blueprint 6: Audio Manager with Pitch Variation (`AudioManager.gd`)

Prevents machine-gun audio fatigue by applying random pitch jitter.

```gdscript
extends Node

func play_sfx(stream: AudioStream, base_pitch: float = 1.0, pitch_spread: float = 0.08) -> void:
	var player = AudioStreamPlayer.new()
	player.stream = stream
	player.pitch_scale = randf_range(base_pitch - pitch_spread, base_pitch + pitch_spread)
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()

func play_sfx_3d(stream: AudioStream, global_pos: Vector3, base_pitch: float = 1.0) -> void:
	var player = AudioStreamPlayer3D.new()
	player.stream = stream
	player.pitch_scale = randf_range(base_pitch - 0.06, base_pitch + 0.06)
	get_tree().current_scene.add_child(player)
	player.global_position = global_pos
	player.finished.connect(player.queue_free)
	player.play()
```

### Blueprint 7: Trauma-Based Camera Shake (`CameraShake.gd`)

Applies non-linear decaying screen shake on heavy impacts.

```gdscript
class_name CameraShake
extends Camera3D

@export var max_offset: Vector3 = Vector3(0.4, 0.4, 0.2)
@export var decay_rate: float = 4.0

var trauma: float = 0.0

func _process(delta: float) -> void:
	if trauma > 0.0:
		trauma = max(trauma - decay_rate * delta, 0.0)
		_apply_shake()

func add_trauma(amount: float) -> void:
	trauma = clamp(trauma + amount, 0.0, 1.0)

func _apply_shake() -> void:
	var shake_amount = trauma * trauma # Non-linear decay
	h_offset = max_offset.x * shake_amount * randf_range(-1.0, 1.0)
	v_offset = max_offset.y * shake_amount * randf_range(-1.0, 1.0)
```

---

## 5. Architectural Quality Checklist

Run through this checklist before committing code or merging pull requests:

- [ ] **No Monoliths:** Does any single script handle input, movement, health, inventory, and rendering together? If so, extract components.
- [ ] **Collider Safety:** Are colliders disabled via `set_deferred("disabled", true)` and collision layers zeroed on the exact frame an entity dies?
- [ ] **World Space VFX:** Are lingering VFX instantiated and added to `get_tree().current_scene` at `global_position` instead of attached to dying nodes?
- [ ] **Signal Semantics:** Do signal names describe past events (`item_unlocked`) rather than imperative orders (`unlock_item`)?
- [ ] **No Direct Parent Mutations:** Does any child node call `get_parent().some_method()`? If yes, refactor to emit a signal upwards.
- [ ] **Static Typing:** Are all function arguments, return types, and member variables explicitly typed?
