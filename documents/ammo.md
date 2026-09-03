# Cove Corsair - Ammunition Architecture & Projectile Mechanics

This document provides a technical specification for all **Ammunition Types** and projectile mechanics in **Cove Corsair**.

---

## 💣 1. Ammunition Data Schema (`AmmoData`)

Ammunition types are defined via strongly typed [`AmmoData`](file:///f:/projects/cove-corsair/src/data/ammo_data.gd) resources. Each resource dictates base hit damage, forward/parabolic projectile velocity, AoE splash radius, scale multipliers, and visual textures.

```gdscript
class_name AmmoData
extends Resource

@export var ammo_name: String = "Standard Ball"
@export var damage: int = 1
@export var projectile_speed: float = 18.0
@export var splash_radius: float = 0.0      # AoE explosion radius if > 0.0
@export var sprite_texture: Texture2D
@export var scale_multiplier: float = 1.0
```

---

## 💥 2. Complete Ammunition Roster

| Ammunition Type | Resource Path | Damage Profile | Projectile Speed | Splash Radius (AoE) | Scale Multiplier | Primary Users / Weapon Mounts |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Standard Ball** | [`ammo_standard_ball.tres`](file:///f:/projects/cove-corsair/src/data/resources/user_ammo/ammo_standard_ball.tres) | $1\text{ Damage}$ | $24.0\text{ m/s}$ | $0.0\text{m}$ (Single target) | $1.00\times$ | Bow Chaser, Swivel Guns, Base Cannons |
| **Grape Shot** | [`ammo_grape_shot.tres`](file:///f:/projects/cove-corsair/src/data/resources/user_ammo/ammo_grape_shot.tres) | $1\text{ Damage}$ | $22.0\text{ m/s}$ | $0.0\text{m}$ (Cone spread) | $0.60\times$ | Port & Starboard Swivel Guns |
| **Heavy Shot** | [`ammo_heavy_shot.tres`](file:///f:/projects/cove-corsair/src/data/resources/user_ammo/ammo_heavy_shot.tres) | $3\text{ Damage}$ | $14.0\text{ m/s}$ | $2.0\text{m}$ | $1.30\times$ | Bow Chaser, Aft Mortar, Deckhand Sniper |
| **Fire Bomb** | [`ammo_fire_bomb.tres`](file:///f:/projects/cove-corsair/src/data/resources/user_ammo/ammo_fire_bomb.tres) | $4\text{ Damage}$ | $20.0\text{ m/s}$ | $2.0\text{m}$ | $1.15\times$ | Monkey Bomber, Aft Mortar |
| **Coconut Bomb** | [`ammo_coconut_bomb.tres`](file:///f:/projects/cove-corsair/src/data/resources/user_ammo/ammo_coconut_bomb.tres) | $3\text{ Damage}$ | $18.0\text{ m/s}$ | $2.5\text{m}$ | $1.30\times$ | Monkey Bomber, Skeleton Tosser |
| **Throwing Axe** | [`ammo_throwing_axe.tres`](file:///f:/projects/cove-corsair/src/data/resources/user_ammo/ammo_throwing_axe.tres) | $3\text{ Damage}$ | $16.0\text{ m/s}$ | $0.0\text{m}$ (Single target) | $1.00\times$ | Skeleton Tosser |

### 🖼️ Ammunition Art Gallery (Transparent PNG Sprites)

````carousel
![Fire Bomb](file:///C:/Users/Magnus/.gemini/antigravity-ide/brain/a15dc124-9380-4e4f-82f3-a23d3405db55/ammo_fire_bomb.png)
<!-- slide -->
![Coconut Bomb](file:///C:/Users/Magnus/.gemini/antigravity-ide/brain/a15dc124-9380-4e4f-82f3-a23d3405db55/ammo_coconut_bomb.png)
<!-- slide -->
![Throwing Axe](file:///C:/Users/Magnus/.gemini/antigravity-ide/brain/a15dc124-9380-4e4f-82f3-a23d3405db55/ammo_throwing_axe.png)
<!-- slide -->
![Heavy Shot](file:///C:/Users/Magnus/.gemini/antigravity-ide/brain/a15dc124-9380-4e4f-82f3-a23d3405db55/ammo_heavy_shot.png)
````


---


## ⚡ 3. Multiplier Gate Interactions & AoE Explosion Mechanics

### Multiplier Gate Duplication
When any projectile passes through a **Multiplier Gate** ([`multiplier_gate.gd`](file:///f:/projects/cove-corsair/src/gameplay/obstacles/multiplier_gate.gd)):
* **Add Gates ($+N$):** Adds $N$ extra parallel projectiles retaining original damage and speed.
* **Multiply Gates ($\times N$):** Multiplies the projectile count by factor $N$ (clamped to max density threshold).
* **Visual Trail:** Translucent flame trails and particle scaling are applied to duplicated projectiles.

### AoE Splash Radius Calculations
For projectiles with `splash_radius > 0.0` (Heavy Shot, Fire Bomb, Coconut Bomb):
* On collision with an obstacle or mob, an area query identifies all surrounding targets within `splash_radius`.
* Full base damage is applied to the primary target, and $50\%$ splash damage is applied to adjacent entities.
* Can trigger immediate chain reactions when detonating red **Fuse Barrels**.
