# Cove Corsair — Architecture & Game Feel Ground Truth Audit
> **Date:** September 2026  
> **Methodology:** Direct static analysis and cross-comparison of `ARCHITECTURE.md` against the active codebase (`src/`, `assets/`, `project.godot`).  
> **Status:** Read-only audit & implementation checklist (NO code changes applied).

---

## 1. Executive Summary & Compliance Scorecard

A thorough comparison of [ARCHITECTURE.md](file:///f:/projects/cove-corsair/ARCHITECTURE.md) against the current codebase reveals that while the project exhibits strong foundational mechanics (such as a trauma-based Perlin camera shake and pooled randomized SFX), **the architectural blueprints defined in `ARCHITECTURE.md` are largely absent from the codebase**.

Instead, the project relies on legacy monolithic patterns, extensive duck-typing (`has_method("take_hit")`), string-based name queries, and direct scene-tree lookups (`get_parent()`, `get_tree().get_first_node_in_group()`). Furthermore, while initial game feel systems exist, key tactile elements—such as 3D mesh hit flashing, firing/impact recoil, hit stop (micro-pauses), water wakes for non-player entities, and spatial audio—are unaddressed.

### Architecture Compliance Matrix

| Architecture Standard / Blueprint | Specified in ARCHITECTURE.md | Current Codebase State | Status |
|---|---|---|---|
| **Feature-First Folder Structure** | `res://src/components/`, `res://src/features/` | Split by legacy type (`src/gameplay/`, `src/ui/`, `src/vfx/`, `src/core/`) | ❌ **Non-Compliant** |
| **Rule A: Signal Up, Call Down** | Strict hierarchical calls; children never call parents | Widespread `get_parent().take_hit()`, `get_parent().destroy_follower()` | ❌ **Non-Compliant** |
| **Rule B: Past-Tense Event Signals** | Signals report past events, never imperative commands | Mostly adhered to, but `GameState` has many `@warning_ignore("unused_signal")` | ⚠️ **Partial** |
| **Rule C: Single Source of Truth (SSOT)** | Victim handles death/VFX; attacker only reports damage | `cannonball.gd` inspects target names, applies custom boss interrupts | ❌ **Non-Compliant** |
| **Rule D: Immediate Collider Shutdown** | Deferred disable + zero layers on death frame | Implemented ad-hoc in loops across some enemies/destructibles | ⚠️ **Partial** |
| **Rule E: Strict Static Typing** | GDScript warning flags enabled in Project Settings | All GDScript debug warning flags are missing from `project.godot` | ❌ **Non-Compliant** |
| **Blueprint 1: `HealthComponent.gd`** | Universal self-contained health & death tracking | Does not exist; HP is copy-pasted as raw integers in 15+ scripts | ❌ **Missing** |
| **Blueprint 2: `Hitbox3D` & `Hurtbox3D`** | Decoupled damage dealing & receiving components | Does not exist; collision handled via monolithic `Area3D` checks | ❌ **Missing** |
| **Blueprint 3: `BaseDestructible.gd`** | Standard base class with automated cleanup & VFX | Does not exist; monolithic `destructible_obstacle.gd` (328 lines) | ❌ **Missing** |
| **Blueprint 4: `EventBus.gd`** | Global lean signal broker autoload singleton | Does not exist; not in `project.godot`; `GameState` used as god-object | ❌ **Missing** |
| **Blueprint 5: `HitFlashComponent.gd`** | Pure white unshaded material flash on impact | Does not exist; ad-hoc sprite modulation exists; 3D meshes don't flash | ❌ **Missing** |
| **Blueprint 6: `AudioManager.gd`** | Pooled 2D/3D SFX with random pitch variation | 2D audio pool exists with pitch jitter; 3D spatial audio missing | ⚠️ **Partial** |
| **Blueprint 7: `CameraShake.gd`** | Trauma-based camera shake with quadratic decay | Implemented in [game_camera.gd](file:///f:/projects/cove-corsair/src/core/game_camera.gd) with Perlin noise | ✅ **Compliant** |

---

## 2. Deep-Dive Architecture Discrepancies

### 2.1 Missing `EventBus` & Overloaded `GameState`
- **Specification:** `ARCHITECTURE.md` calls for a dedicated, lean `EventBus.gd` singleton reserved strictly for cross-boundary event broadcasting (`doubloons_changed`, `player_sunk`, `level_started`, `level_completed`, `screen_shake_requested`).
- **Reality:** No `EventBus` autoload exists in [project.godot](file:///f:/projects/cove-corsair/project.godot). Instead, [game_state.gd](file:///f:/projects/cove-corsair/src/core/game_state.gd) (1,033 lines) functions as a combination of persistent save manager, economy controller, fodder streak tracker, boss battle state machine, and event broadcaster. It has accumulated unused signals with `@warning_ignore("unused_signal")`.
- **Impact:** Systems across UI, camera, and gameplay are tightly coupled to `GameState`, violating separation of concerns.

### 2.2 Monolithic Entity Scripts
- **Specification:** Section 5 Checklist: *"Does any single script handle input, movement, health, inventory, and rendering together? If so, extract components."*
- **Reality:**
  - [player.gd](file:///f:/projects/cove-corsair/src/gameplay/player/player.gd) (**1,012 lines**): Handles touch/keyboard input, dynamic `Area3D` collider generation (`CollisionArea`, `MagnetArea`), swerve interpolation, boat mesh loading, hardpoint socketing, follower armada layout tweening, weapon shooting orchestration, HP management, ram absorption, hit i-frames, scrape timers, end-game UI instantiating, and shadow node pruning.
  - [cannonball.gd](file:///f:/projects/cove-corsair/src/gameplay/projectiles/cannonball.gd) (**696 lines**): Handles ballistic curves, projectile spinning, trail attachment/detachment, chain shot mine sweeping, multiplier gate interaction, group searching, string-matching on target names (`"barricade"`, `"grave"`, `"phantom"`, `"dredge"`), target channel interrupts, and AoE splash logic.
  - [attached_weapon.gd](file:///f:/projects/cove-corsair/src/gameplay/player/attached_weapon.gd) (**603 lines**): Handles 3D model swapping, crew idle animations, deck pacing, multi-group target scanning, aiming lerps, and firing dispatch.
  - [destructible_obstacle.gd](file:///f:/projects/cove-corsair/src/gameplay/obstacles/destructible_obstacle.gd) (**328 lines**): Handles 5 obstacle types via `match` statements, sprite texture assignment, coin/chest spawning, explosion damage, and camera shake.

### 2.3 Violation of Rule A & Rule C (Coupling & SSOT)
- In [cannonball.gd](file:///f:/projects/cove-corsair/src/gameplay/projectiles/cannonball.gd#L530-L558), the projectile queries the target's name string, inspects internal variables (`is_barrage_active`), and executes specific target methods (`interrupt_channel()`). Under Rule C, the attacker simply reports incoming damage; the victim is the Single Source of Truth for how it reacts to damage or ammo types.
- In [hazard_sea_mine.gd](file:///f:/projects/cove-corsair/src/gameplay/obstacles/hazard_sea_mine.gd#L86-L96), the mine queries `get_tree().get_nodes_in_group("enemies")`, checks distance manually, and mutates enemy properties directly (`area.current_hp -= 20`).
- Across many scripts, child nodes call `get_parent().take_hit()` or `get_parent().destroy_follower()` directly rather than signaling upward.

### 2.4 Duplicate & Fragmented Assets
- Two separate VFX directories exist:
  - `res://src/vfx/` (contains `trail_3d.gd`, `vfx_coin_burst.tscn`, `vfx_mine_explosion.tscn`, `vfx_mortar_geyser.tscn`, `vfx_wood_splinter.tscn`)
  - `res://src/gameplay/vfx/` (contains `barrel_explosion.tscn`, `boat_wake.tscn`, `coin_pickup_vfx.tscn`, `floating_text.gd`, `hit_splash.tscn`, `telegraph_spectral_geyser.tscn`)

---

## 3. Game Feel & "Juice" Deep-Dive Analysis

Game feel ("juice") is what transforms an arcade runner from mechanically functional into visceral and addictive. Below is an audit of each sensory dimension.

### 3.1 Hit Feedback & Impact Weight
- **Current State:**
  - When enemies take damage, `_flash()` in 2D sprite enemies modulates their `Sprite3D` via a quick tween (`modulate = Color(2.5, 2.5, 2.5, 1.0)`).
  - **Critical Gap:** The player ship and 3D enemy vessels (e.g. `dinghy.glb`, boss meshes, 3D destructibles) **do not have a hit flash at all**. When the player boat takes a hit, only the 2D HUD edge triggers a red flash. The 3D hull looks completely non-reactive.
  - Standard cannonball hits against wooden skiffs or barrels do not consistently spawn the splinter debris (`vfx_wood_splinter.tscn`).
  - No surface impact distinction exists: hitting iron/metal vs wood vs stone vs ghost/spectral entities produces identical generic feedback (`barrel_hits` sound, small generic splash).

### 3.2 Hit Stop / Micro-Pause (The Missing "Crunch")
- **Current State:** There is currently **zero hit stop** anywhere in the codebase.
- **Why It Matters:** In arcade combat, when a heavy blow lands (e.g. sinking an elite ship, detonating a sea mine, or hitting a boss with a mortar), freezing the game for 30–60 milliseconds (`Engine.time_scale = 0.05`) gives instantaneous tactile weight to the impact before the explosion erupts.

### 3.3 Recoil, Knockback & Physicalized Motion
- **Current State:**
  - [attached_weapon.gd](file:///f:/projects/cove-corsair/src/gameplay/player/attached_weapon.gd#L387-L389) applies a minor 0.08m Z-axis tween on cannon models when firing.
  - **Critical Gap:** The player boat hull has **no recoil whatsoever**. Firing a heavy bow chaser, deck mortar, or broadside volley does not rock the ship backward or pitch the bow upward.
  - When taking damage or colliding with obstacles (e.g. barricade graze), the boat does not shudder or experience directional impulse—it simply continues on rails with an i-frame timer.

### 3.4 Water Interaction & Hydrodynamic Feel
- **Current State:**
  - The player ship has a wake effect ([boat_wake.tscn](file:///f:/projects/cove-corsair/src/gameplay/vfx/boat_wake.tscn)) and basic sinusoidal bobbing.
  - **Critical Gap:** Escort/follower boats and enemy vessels have **no water wakes at all**. They appear to slide across ice rather than navigate an ocean channel.
  - Dynamic water spray is missing during aggressive swerving (hard left/right turning should generate bow spray and stern wash).
  - Low-flying cannonballs that graze the water surface do not create ripples or micro-plumes.

### 3.5 Audio Dynamics & Spatial Feedback
- **Current State:**
  - [audio_manager.gd](file:///f:/projects/cove-corsair/src/core/audio_manager.gd) has a 24-voice 2D pool with pitch jitter (`randf_range(min_pitch, max_pitch)`), which prevents machine-gun fatigue.
  - **Critical Gap:**
    - **No 3D Positional Audio:** `play_sfx_3d` is not implemented. A mine exploding on the far left or a boss firing from the right sounds identically centered in stereo.
    - **SFX Overuse:** The single sound key `"barrel_hits"` is used for: player taking damage, player ramming barricades, player taking leak damage, cannonballs hitting obstacles, and cannonballs hitting multiplier gates.
    - **No Pitch Escalation on Pickups:** Collecting a streak of doubloons plays coins at random pitches rather than an ascending melodic scale (e.g. 1.0x -> 1.05x -> 1.1x -> 1.15x -> 1.25x), which is a proven dopamine mechanic in arcade runners.
    - **No Low-Health Audio Filter:** When the player is reduced to 1 HP, there is no muffled low-pass filter, heartbeat, or heightened audio tension.

### 3.6 Visual Distress & Damage Visualization
- **Current State:** Damage is communicated primarily through the top HUD health hearts and floating combat text (`-HULL`).
- **Critical Gap:** The ship model shows no physical distress. At 2/3 HP, the hull should emit slight trailing black smoke; at 1/3 HP, visible sparks/embers and heavy smoke should trail behind the vessel.

---

## 4. Master Enhancement Checklist

Below is the prioritized, actionable checklist organized into three phases.

### Phase 1: High-Impact Game Feel & "Juice" (Sensory Polish)
*These enhancements directly elevate the moment-to-moment game feel without altering core game loop architecture.*

- [x] **1.1 Universal 3D Mesh Hit Flash (`HitFlashComponent`)**
  - Implement a reusable component supporting both `MeshInstance3D` (using unshaded white material override for 0.06s) and `Sprite3D` (modulate overshoot).
  - Attach to player boat visuals (`BoatMesh`), enemy models, boss components, and destructible obstacles.
- [x] **1.2 Arcade Hit Stop (Micro-Freeze Frame)**
  - Implement a global `HitStop` utility (e.g. `hit_stop(duration_sec: float = 0.045)` using `Engine.time_scale = 0.05`).
  - Trigger on: elite enemy deaths, sea mine detonations, boss weak-point breaks, and player heavy collisions.
- [x] **1.3 Ship Firing Recoil & Impact Shudder**
  - Add hull pitch/recoil to `player.gd`: when cannons fire, apply a brief backward impulse (`rotation_degrees.x += 1.5`, smoothly decaying).
  - Mortar launches trigger a heavier bow-dip and camera trauma pulse.
  - Taking a hit applies a sudden lateral shudder (directional tilt + damped oscillation) to simulate hull impact.
- [x] **1.4 Hydrodynamic Water Feedback & Wakes**
  - Attach `boat_wake.tscn` to follower escort boats and enemy vessels so all craft feel anchored to the water.
  - Add dynamic bow spray particles to the player vessel that scale emission based on horizontal swerve velocity (`x_velocity`).
- [x] **1.5 Audio Spatialization & Feedback Loops**
  - Implement `play_sfx_3d(stream_key: String, global_pos: Vector3, min_pitch: float, max_pitch: float)` in `AudioManager.gd`.
  - Add chromatic pitch escalation to doubloon collection: rapid coin pickups step up in pitch (1.0 -> 1.06 -> 1.12 -> 1.18 -> 1.25) before resetting.
  - Diversify impact sounds: separate sound profiles for wood smash, iron ricochet, water plume, and gate ringing.
  - Implement low-HP audio tension: engage an AudioServer low-pass filter bus or heartbeat audio cue when `current_health == 1`.
- [x] **1.6 Vessel Damage States (Hull Distress VFX)**
  - Add trailing smoke particles to the player vessel:
    - 2/3 HP: faint gray wisps.
    - 1/3 HP: thick black smoke plume and orange embers.
- [x] **1.7 Projectile Surface Impact Decoupling**
  - When cannonballs expire or hit:
    - Water hit -> spawn vertical geyser + concentric ripple shockwave.
    - Wood hit -> spawn bursting splinters with gravity (`vfx_wood_splinter.tscn`).
    - Iron/Armored hit -> spawn bright sparks.
- [x] **1.8 Overdrive & Frenzy Sensory Celebration**
  - When **Fire Frenzy** or **Armada Overdrive** activates:
    - Add subtle golden/fiery edge vignette distortion.
    - Enhance weapon muzzle flash brightness during the buff duration.

---

### Phase 2: Architectural Decoupling & Blueprint Implementation
*Refactoring the core communication pathways to align with `ARCHITECTURE.md` standards.*

- [x] **2.1 Implement `EventBus.gd` Autoload**
  - Created `src/core/event_bus.gd` and registered in `project.godot`.
  - Migrated global event broadcasts (`level_completed`, `campaign_completed`, `boss_spawned_event`, `boss_health_changed`, `distance_target_reached`, `player_sunk`, `run_failed`, `screen_shake_requested`) from `GameState` to `EventBus`.
  - Removed 6 dead signals and all `@warning_ignore("unused_signal")` from `GameState`.
  - Updated `top_hud.gd` (both variants) to connect boss signals from `EventBus`.
- [x] **2.2 Implement `HealthComponent.gd` (Blueprint 1)**
  - Created `src/components/health_component.gd` with `current_health`, `max_health`, `take_damage()`, `heal()`, `reset()`, emitting `health_changed`, `damage_taken`, `died`.
  - Wired into `EnemyFodderSkiff`, `EnemyMob`, `DestructibleObstacle` with runtime fallback creation for scenes without a pre-placed node.
  - Legacy `current_hp` reads kept as passthrough properties for backward compatibility.
- [x] **2.3 Implement Decoupled `Hitbox3D` & `Hurtbox3D` (Blueprint 2)**
  - Created `src/components/hitbox_3d.gd` with `damage`, `damage_type`, `one_shot` exports.
  - Created `src/components/hurtbox_3d.gd` routing to `HealthComponent` with backward-compat `take_hit()` entry point.
  - `HazardSeaMine._apply_blast_damage()` checks `area is Hurtbox3D` first before falling back.
- [x] **2.4 Implement `BaseDestructible.gd` (Blueprint 3)**
  - Created `src/components/base_destructible.gd` with automated collision shutdown (Rule D), world-space VFX spawn, `destroyed(death_position)` signal, and doubloon drop centralization.
- [x] **2.5 Refactor `cannonball.gd` for SSOT Compliance (Rule C)**
  - Stripped `is_barricade` 2× multiplier and `is_spectral` `interrupt_channel`/`is_barrage_active` mutations from `cannonball.gd`.
  - Added ammo-aware `take_hit(amount, ammo_id)` to `BossPhantomDredge` (spectral_salt → 1.5× + `interrupt_channel()`).
  - Added ammo-aware `take_hit(amount, ammo_id)` to `BarricadeSegment` (battering_shot → 2× damage).
- [x] **2.6 Refactor `hazard_sea_mine.gd` Detonation**
  - Replaced tree-wide `get_nodes_in_group("enemies")` loop with `get_overlapping_areas()` scan in `_apply_blast_damage()`.
  - Eliminated all `area.current_hp -= 20` direct property mutations.
  - Mine now routes blast through `Hurtbox3D.take_hit()` if available, falls back to `take_hit()/take_damage()`.

---

### Phase 3: Codebase Cleanliness & Standards Enforcement
*Enforcing static typing, file consolidation, and repository organization.*

- [ ] **3.1 Consolidate Fragmented VFX Folders**
  - Merge `src/gameplay/vfx/` into `src/vfx/`.
  - Update resource references in scenes and preload scripts.
- [ ] **3.2 Modularize `player.gd` Monolith**
  - Extract movement/swerve logic into `player_movement.gd`.
  - Extract follower armada formation logic into `fleet_formation_controller.gd`.
  - Maintain `player.gd` strictly as an input & high-level orchestrator.
- [ ] **3.3 Enable GDScript Static Typing Warnings (Rule E)**
  - Add to `project.godot` under `[debug]`:
    ```ini
    gdscript/warnings/untyped_declaration=1
    gdscript/warnings/unsafe_property_access=1
    gdscript/warnings/unsafe_method_access=1
    ```
  - Add explicit types to function parameters, return values, and exported variables across gameplay scripts.

---

## 5. Recommended Implementation Roadmap

```mermaid
graph TD
    subgraph "Phase 1: Immediate Game Feel (Zero-Risk Juice)"
        A1[Universal 3D Mesh Hit Flash] --> A2[Arcade Hit Stop 40ms]
        A2 --> A3[Ship Hull Firing & Hit Recoil]
        A3 --> A4[Wakes on Followers & Enemies]
        A4 --> A5[Coin Pickup Pitch Escalation & 3D SFX]
        A5 --> A6[Vessel Low-HP Distress Smoke]
    end

    subgraph "Phase 2: Architectural Blueprints"
        B1[Register EventBus Autoload] --> B2[Create HealthComponent & HitFlashComponent]
        B2 --> B3[Create Hitbox3D & Hurtbox3D]
        B3 --> B4[Refactor Destructibles & Mines to BaseDestructible]
        B4 --> B5[Decouple Cannonball from Victim Internals SSOT]
    end

    subgraph "Phase 3: Cleanliness & Modularization"
        C1[Consolidate src/vfx/ Directories] --> C2[Split player.gd into Movement & Armada Controllers]
        C2 --> C3[Enable GDScript Strict Typing Warnings in project.godot]
    end

    Phase 1 --> Phase 2
    Phase 2 --> Phase 3
```

By tackling **Phase 1** first, the game immediately achieves a dramatic upgrade in visual crunch, tactile responsiveness, and immersion without destabilizing existing game systems. **Phase 2** then cleanly refactors the foundation to match `ARCHITECTURE.md`, and **Phase 3** locks in long-term maintainability.
