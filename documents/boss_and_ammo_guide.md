# Cove Corsair - Boss & Ammo Modification Guide

This guide explains how to edit boss encounters, change boss visual models and 2D billboard sprites, configure boss combat phases and attack patterns, and customize or re-skin the projectiles and ammo sprites that bosses fire.

---

## 👹 1. Boss Architecture Overview

In Cove Corsair, bosses are triggered when the player reaches the final boss chunk of a level. 
Boss chunks (such as [chunk_boss_ironjaw.tscn](file:///f:/projects/cove-corsair/src/gameplay/chunks/chunk_boss_ironjaw.tscn)) have:
- `is_boss_chunk = true`
- `boss_scene = preload("res://src/gameplay/enemies/boss_war_barge.tscn")` (or other boss prefab)

When the chunk is reached, [BaseTrackChunk](file:///f:/projects/cove-corsair/src/gameplay/chunks/base_track_chunk.gd#L70-L81) instantiates the boss ahead of the player at $Z = -35.0$, and the camera activates boss focus mode.

### Boss Prefab Catalog (`src/gameplay/enemies/`)

| Boss Scene | Script | Typical Boss Identity |
| :--- | :--- | :--- |
| [boss_war_barge.tscn](file:///f:/projects/cove-corsair/src/gameplay/enemies/boss_war_barge.tscn) | [boss_war_barge.gd](file:///f:/projects/cove-corsair/src/gameplay/enemies/boss_war_barge.gd) | **Ironjaw** — Armored steam war barge with broadsides, steam venting, and mortar barrage. |
| [boss_bone_beard.tscn](file:///f:/projects/cove-corsair/src/gameplay/enemies/boss_bone_beard.tscn) | [boss_bone_beard.gd](file:///f:/projects/cove-corsair/src/gameplay/enemies/boss_bone_beard.gd) | **Captain Bone-Beard** — Fast twin-frigate with high weave speed, rolling powder keg drops, and Fire Twin Cannon Salvos. |
| [boss_phantom_dredge.tscn](file:///f:/projects/cove-corsair/src/gameplay/enemies/boss_phantom_dredge.tscn) | [boss_phantom_dredge.gd](file:///f:/projects/cove-corsair/src/gameplay/enemies/boss_phantom_dredge.gd) | **Phantom Dredge** — Submerging bayou dredger with dive and surface combat cycles. |
| [boss_siege_fortress.tscn](file:///f:/projects/cove-corsair/src/gameplay/enemies/boss_siege_fortress.tscn) | [boss_siege_fortress.gd](file:///f:/projects/cove-corsair/src/gameplay/enemies/boss_siege_fortress.gd) | **Siege Fortress** — Heavy volcanic citadel craft with multi-turret crossfire. |

---

## ⚙️ 2. Editing Boss Stats, Phases & Attacks

Select the root node of any boss scene in the Godot Inspector to tune its exported properties:

### Core Combat Parameters

| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `max_hp` / `current_hp` | `int` | `100` – `250` | Total hit points. Determines length and endurance of the fight. |
| `approach_speed` | `float` | `12.0` – `14.0` | Speed ($m/s$) the boss sails in downriver before engaging. |
| `combat_z_offset` | `float` | `-18.0` | Distance ahead of the player vessel maintained during combat. |
| `weave_speed` | `float` | `1.3` – `1.8` | Lateral sinusoidal strafing frequency across the river channel. |
| `patrol_width` | `float` | `2.8` | Maximum left/right movement extent ($X = -2.8$ to $+2.8$). |
| `attack_interval` | `float` | `2.0` – `2.5` | Cooldown period between cannon volleys or special attacks. |
| `spawn_hazard_enabled` | `bool` | `true` | Enables dropping sea mines, powder kegs, or spawning minion adds. |
| `hazard_telegraph_time` | `float` | `1.8` | Warning window duration before hazardous strikes trigger. |
| `max_active_adds` | `int` | `2` | Maximum concurrent escort skiffs the boss can summon. |

### Advanced Phase Variables (in `boss_war_barge.gd`)
- `steam_duration` (`2.5s`) / `steam_cooldown` (`4.0s`): Phase 2 defensive steam blast that deflects standard cannonballs.
- `enraged_shoot_timer`: Rapid-fire frequency when boss health drops below 50%.

---

## 🎨 3. Changing Boss Visuals: 3D Models vs. 2D Sprites

Boss scripts detect their visual representation automatically via:
```gdscript
@onready var boss_sprite: Node3D = get_node_or_null("BossMesh") if get_node_or_null("BossMesh") else get_node_or_null("BossSprite")
```

### Option A: Swapping the 3D Model
1. Open the boss `.tscn` (e.g., [boss_bone_beard.tscn](file:///f:/projects/cove-corsair/src/gameplay/enemies/boss_bone_beard.tscn)).
2. Under the root node, locate the child node named `BossMesh`.
3. In the Inspector, change the instantiated scene or replace the node with another `.glb` model (found in `assets/models/enemy/vessels/`).
4. Adjust `transform` (scale, position Y) so the hull floats properly on the water plane ($Y \approx 0.2\text{m}$ to $0.4\text{m}$).

### Option B: Using a 2D Billboard Sprite
If you want an illustrated or retro pixel/stylized 2D boss graphic:
1. Open the boss `.tscn`.
2. Delete or disable the `BossMesh` node.
3. Add a new `Sprite3D` child node named `BossSprite`.
4. In the Inspector for `BossSprite`:
   - Set **Texture** to your 2D PNG image.
   - Set **Billboard** to `Y-Billboard` (1) or `Spherical Billboard` (2).
   - Set **Pixel Size** (e.g. `0.005` to `0.015`) to scale the sprite appropriately.
   - Set position $Y$ so the base touches the water.

---

## 💥 4. Modifying Boss Projectiles & Ammo Sprites

Bosses and enemy craft shoot projectiles through the exported scene property:
```gdscript
@export var enemy_cannonball_scene: PackedScene = preload("res://src/gameplay/projectiles/enemy_cannonball.tscn")
```

### Option 1: Changing the Standard Enemy Projectile Visuals
The default enemy projectile is [enemy_cannonball.tscn](file:///f:/projects/cove-corsair/src/gameplay/projectiles/enemy_cannonball.tscn), powered by [enemy_cannonball.gd](file:///f:/projects/cove-corsair/src/gameplay/projectiles/enemy_cannonball.gd).

By default, it uses two 3D meshes: `FireCore` and `FireGlow` (unshaded glowing spheres).

#### To Convert It to a 2D Sprite Projectile:
1. Open `res://src/gameplay/projectiles/enemy_cannonball.tscn`.
2. In the scene tree, delete or hide `FireCore` and `FireGlow`.
3. Add a `Sprite3D` node as a child of `EnemyCannonball`:
   - Name it `AmmoSprite`.
   - Assign your texture in **Texture** (e.g. `assets/sprites/ammo/ammo_fire_bomb.png` or any custom projectile PNG).
   - In **Flags**, set **Billboard** to `Enabled`.
   - Adjust **Pixel Size** (e.g. `0.005`) so it matches the collision sphere radius ($0.4\text{m}$).
4. Save the scene. All bosses and enemies firing `enemy_cannonball.tscn` will now project your 2D ammo sprite.

### Option 2: Creating a Unique Custom Projectile Per Boss
If you want **Phantom Dredge** to shoot green cursed souls while **Ironjaw** fires flaming mortar shells:

1. Create a new scene: `res://src/gameplay/projectiles/enemy_spectral_skull.tscn`.
2. Set the root node to `Area3D`, and attach [enemy_cannonball.gd](file:///f:/projects/cove-corsair/src/gameplay/projectiles/enemy_cannonball.gd).
3. Add a `CollisionShape3D` with a `SphereShape3D` (radius $\approx 0.4$).
4. Add your visual element:
   - A `Sprite3D` with your custom sprite texture (set **Billboard** to `Enabled`), OR
   - A custom `MeshInstance3D` / Particle effect.
5. In the root node's script properties:
   - Tune `speed` (default `11.0` $m/s$).
   - Tune `lifetime` (default `4.5` seconds).
6. Open your boss scene (e.g. [boss_phantom_dredge.tscn](file:///f:/projects/cove-corsair/src/gameplay/enemies/boss_phantom_dredge.tscn)).
7. In the Inspector, drag `enemy_spectral_skull.tscn` into the boss's **Enemy Cannonball Scene** slot.

### Option 3: Dynamic Projectile Color Tinting
The script [enemy_cannonball.gd](file:///f:/projects/cove-corsair/src/gameplay/projectiles/enemy_cannonball.gd#L24-L39) exposes a `set_color(color: Color)` helper.
If using the default meshes, you can dynamically tint ammo in code when instantiated:
```gdscript
var ball = enemy_cannonball_scene.instantiate() as EnemyCannonball
add_child(ball)
ball.global_position = left_cannon_node.global_position
ball.set_color(Color(0.2, 0.9, 0.3)) # Emerald cursed projectile!
```

### Option 4: Dedicated Boss Multi-Projectile & Salvo Prefabs
Bosses with specialized multi-shot attacks (such as **Captain Bone-Beard's** twin catamaran hulls) use dedicated salvo projectile scenes:
- **Sprite Texture**: `res://assets/sprites/ammo/boss_ammo_fire_twin_cannon_salvo.png`
- **Scene**: [boss_projectile_twin_cannon_salvo.tscn](file:///f:/projects/cove-corsair/src/gameplay/projectiles/boss_projectile_twin_cannon_salvo.tscn) (script: [boss_projectile_twin_cannon_salvo.gd](file:///f:/projects/cove-corsair/src/gameplay/projectiles/boss_projectile_twin_cannon_salvo.gd))
- **Ammo Data**: [ammo_fire_twin_cannon_salvo.tres](file:///f:/projects/cove-corsair/src/data/resources/user_ammo/ammo_fire_twin_cannon_salvo.tres)
- **Mechanics**: Combines dual blazing cannonballs into a single wide-lane salvo hitbox (`BoxShape3D(2.4, 1.2, 1.2)`), traveling downriver at $12\text{ m/s}$ with auto-detected spherical billboard rendering.
- **Trigger**: Called in combat via `_fire_twin_cannon_salvo()` and testable via the `💥 Fire Twin Cannon Salvo` button in the Boss Sandbox.

---

## 🧪 5. Interactive Boss & Weapon Testing Sandbox

For rapid design iteration, hitbox calibration, and attack animation testing, use the dedicated **Boss & Weapon Testing Sandbox**:

- **Scene Path**: `res://src/levels/boss_testing_sandbox.tscn`
- **Controller Script**: [boss_testing_sandbox.gd](file:///f:/projects/cove-corsair/src/levels/boss_testing_sandbox.gd)

### How to Run:
1. In the Godot Editor FileSystem dock, navigate to `res://src/levels/boss_testing_sandbox.tscn`.
2. Right-click the scene and select **Play Scene** (or press **F6** with the scene open).

### Key Features:
- **Boss Selector & Phases**:
  - Switch instantly between **Captain Ironjaw**, **Captain Bone-Beard**, **The Phantom Dredge**, **The Siege Fortress**, and mini-bosses (**Bombard Skiff**, **Toxic Harvester**).
  - Modify HP in real-time (`-10`, `-50`, `-200`, `Full Heal`) or trigger instant defeat animations.
  - Switch combat phases (`Phase 1`, `Phase 2`, `Phase 3`, `Enraged`).
  - Freeze boss movement in place for precise aiming and hitbox tests (`Freeze Movement: ON/OFF`).
  - Component-level destruction tests for the **Siege Fortress** (*Port Turret*, *Starboard Turret*, *Prow Ram*, *Furnace Core*).
- **Weapons & Attack Triggers**:
  - Toggle automated attacks (`Auto-Attacks: ON/OFF`) or test individual attacks with dedicated trigger buttons:
    - *Ironjaw*: Alternating Cannons, Targeted Mortar Barrage, Steam Venting, Ram Charge.
    - *Bone-Beard*: Powder Keg Barrage.
    - *Phantom Dredge*: Spectral Volley, Poison Mortar, Dive/Submerge, Water Shockwaves, Resurface.
    - *Siege Fortress*: Multi-Turret Broadside, Thermal Geyser Slam, Ram Overdrive.
  - Projectile customization: Live speed slider (4–24 m/s) and live color tints (*Default Steel*, *Blazing Fire*, *Spectral Cyan*, *Void Purple*, *Toxic Acid*).
  - Test-fire projectiles down specific river lanes (Left `-3m`, Center `0m`, Right `+3m`).
- **Minion & Hazard Spawns**:
  - Spawn individual minion adds (*Pressure Skiffs*, *Grave Skiffs*, *Tide Cutters*, *Iron Gunners*, *Brimstone Rafts*, or full *Bayou Swarms*).
  - Deploy river hazards (*Powder Kegs*, *Spiked Sea Mines*, *Biogas Pods*, *Thermal Geysers*).
  - Instant cleanup buttons: `Clear Minions`, `Clear Hazards`, `Clear Projectiles`, and `💥 CLEAR ALL`.
- **Direct Boss Director & Animation Showcase**:
  - No player ship or gameplay interruptions: you have complete puppeteer control over the boss.
  - An invisible/subtle target buoy handles all attack landings and impact explosions.
  - Camera presets: `[Front Framing]` (inspection framing right in front of boss), `[3/4 Quarter]` (isometric), `[Top-Down]` (tactical), and `[Waterline]` (profile view).
  - Time scale controls: `Pause (||)`, `0.1x Slow-Mo`, `0.25x`, `0.5x`, `1x`, `2x` for frame-by-frame inspection of muzzle flashes, projectile trajectories, and telegraph markers.
  - Press **H** to toggle the controls GUI on/off for clean screenshot and video capture.
