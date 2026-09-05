# Cove Corsair - Vessels & Mobs Architecture

This document provides a comprehensive technical reference for all naval vessels in **Cove Corsair**, including Player Flagships, Follower Escort Skiffs, Hostile Mobs, Mini-Bosses, and Phase Bosses.

---

## ⛵ 1. Player Flagships (User Vessels)

Player vessels define handling speed, hull durability, collision boundaries, and hardpoint weapon sockets for deck crew and naval cannons. Flagships maintain their archetype throughout a campaign run.

### Vessel Comparison Table

| Attribute | [The Dinghy](file:///f:/projects/cove-corsair/src/data/resources/user_vessels/dinghy_ship.tres) | [The Sloop](file:///f:/projects/cove-corsair/src/data/resources/user_vessels/sloop_ship.tres) | [The Ironclad](file:///f:/projects/cove-corsair/src/data/resources/user_vessels/ironclad_ship.tres) |
| :--- | :--- | :--- | :--- |
| **Archetype** | Agility / Rapid Swerve | Balanced Standard | Heavy Armored Brawler |
| **Max Hull HP** | $1\text{ HP}$ (Light) | $5\text{ HP}$ (Standard) | $8\text{ HP}$ (Armored) |
| **Lateral Move Speed** | $12.0\text{ m/s}$ | $11.0\text{ m/s}$ | $7.5\text{ m/s}$ |
| **Base Fire Rate Cooldown** | $0.20\text{s}$ | $0.16\text{s}$ | $0.15\text{s}$ |
| **Base Frontal Cannons** | $1$ Cannon | $2$ Cannons | $3$ Cannons |
| **Collision Size ($X, Y, Z$)** | $(1.6, 1.0, 2.8)$ | $(1.4, 1.0, 2.5)$ | $(2.4, 1.4, 3.8)$ |
| **Primary Level Availability** | Level 1 (Smuggler's Run) | Level 2 (Black Tide Bayou) | Level 3 (Brimstone Bastion) |

---

### Hardpoint Sockets & Upgrade Roadmaps

#### 🚤 1.1 The Dinghy ([`dinghy_ship.tres`](file:///f:/projects/cove-corsair/src/data/resources/user_vessels/dinghy_ship.tres))
* **3D Model:** `res://assets/models/user/vessels/the_dinghy.glb`
* **Calibrated Transform:** `y_offset = 0.26`, `scale = Vector3(3.80, 3.80, 3.80)`, `rotation = Vector3(0, 0, 0)`
* **Hardpoint Sockets:**
  * `BowMount`: Front chaser mount (scale: $1.0$)
  * `MidDeckCrew`: Center deck socket (scale: $0.35$)
  * `AftDeckCrew`: Aft deck socket (scale: $0.35$)
* **Tier Progression:**
  * **Tier 1:** Instantiates [`weapon_bow_chaser.tres`](file:///f:/projects/cove-corsair/src/data/resources/user_crew/weapon_bow_chaser.tres) at `BowMount`.
  * **Tier 2:** Adds [`crew_monkey_bomber.tres`](file:///f:/projects/cove-corsair/src/data/resources/user_crew/crew_monkey_bomber.tres) at `MidDeckCrew`.
  * **Tier 3:** Adds [`crew_skeleton_tosser.tres`](file:///f:/projects/cove-corsair/src/data/resources/user_crew/crew_skeleton_tosser.tres) at `AftDeckCrew`.

#### ⛵ 1.2 The Sloop ([`sloop_ship.tres`](file:///f:/projects/cove-corsair/src/data/resources/user_vessels/sloop_ship.tres))
* **3D Model:** `res://assets/models/user/vessels/the_sloop.glb`
* **Calibrated Transform:** `y_offset = 0.33`, `scale = Vector3(2.00, 2.00, 2.00)`, `rotation = Vector3(0, -90, 0)`
* **Hardpoint Sockets:** `BowMount`, `MidDeckCrew`, `AftDeckCrew`, `PortSwivelMount`, `StarboardSwivelMount`
* **Tier Progression:**
  * **Tier 1:** [`weapon_bow_chaser.tres`](file:///f:/projects/cove-corsair/src/data/resources/user_crew/weapon_bow_chaser.tres) on `BowMount`.
  * **Tier 2:** Adds `Monkey Bomber` (`MidDeckCrew`) & `Skeleton Tosser` (`AftDeckCrew`).
  * **Tier 3:** Adds dual `Port & Starboard Swivel Guns` for broadside coverage.

#### 🛡️ 1.3 The Ironclad ([`ironclad_ship.tres`](file:///f:/projects/cove-corsair/src/data/resources/user_vessels/ironclad_ship.tres))
* **3D Model:** `res://assets/models/user/vessels/the_ironclad.glb`
* **Calibrated Transform:** `y_offset = 0.35`, `scale = Vector3(2.00, 2.00, 2.00)`, `rotation = Vector3(0, -90, 0)`
* **Hardpoint Sockets:** `BowMount`, `MonkeyCrew`, `SkeletonCrew`, `PortSwivelMount1`, `PortSwivelMount2`, `StarboardSwivelMount1`, `StarboardSwivelMount2`
* **Tier Progression:**
  * **Tier 1:** Frontal Cannon Battery (`BowMount`).
  * **Tier 2:** Mid-deck `Monkey Bomber` and `Skeleton Tosser`.
  * **Tier 3:** Full battery layout with 4 lateral swivel gun mounts.

---

## 🛶 2. Follower Fleet Skiffs

When passing through **Fleet Summon Gates** ($+1, +2$), escort skiffs join the player's flotilla ([`follower_boat.gd`](file:///f:/projects/cove-corsair/src/gameplay/player/follower_boat.gd)):
* **Formation Behavior:** Dynamic formation array flanking the player ship.
* **Firepower:** Synchronized forward and broadside cannon volleys that fire in lockstep with the player boat.
* **Durability:** Escort skiffs act as ablative shields, absorbing collisions with hazards or enemy fire before damage reaches the player flagship.

---

## ⚔️ 3. Enemy Mobs & Mini-Bosses

Hostile craft adhere to the [Tiered Color Rarity System](file:///f:/projects/cove-corsair/documents/Ahoy%21%20Pirate%20Arcade%20Runner_%20Master%20Game%20Design%20&%20Strategic%20Roadmap.md#3-tiered-color-rarity-system):

| Mob Class | Biome | HP Profile | Forward Speed | Rarity Tier | Behavior & Attack Pattern |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Skeleton Rowers** | Level 1 | $3\text{ HP}$ | $1.5\text{ m/s}$ | Common (White) | Slow-moving forward enemy craft; low damage target. |
| **Raider Skiff** | Level 1 | $8\text{-}10\text{ HP}$ | $2.5\text{-}3.5\text{ m/s}$ | Normal (Green) | Fast-moving mob advancing down-river. |
| **Turtle Raft** | Level 1 | $20\text{-}30\text{ HP}$ | $1.5\text{ m/s}$ | Elite (Purple) | Heavy armored raft requiring focused DPS. |
| **Kamikaze Raft** | Level 1 | $10\text{-}12\text{ HP}$ | $6.0\text{-}6.5\text{ m/s}$ | Rare (Blue) | High-speed ramming craft charging directly down lane. |
| **Grave Skiff** | Level 2 | $6\text{-}12\text{ HP}$ | $2.0\text{-}3.0\text{ m/s}$ | Normal (Green) | Fast swamp skiff strafing laterally across lanes. |
| **Tide Cutter** | Level 2 | $10\text{-}18\text{ HP}$ | $3.5\text{ m/s}$ | Rare (Blue) | Armor-plated swamp cutter charging forward. |
| **Harvester (Mini-Boss)**| Level 2 | $120\text{ HP}$ | $1.0\text{ m/s}$ | Legendary (Gold) | Heavy swamp harvester mini-boss firing broadside volleys. |
| **Iron Gunner** | Level 3 | $14\text{-}22\text{ HP}$ | $2.0\text{ m/s}$ | Rare (Blue) | Armored gunboat firing long-range cannonballs. |
| **Brimstone Raft** | Level 3 | $18\text{-}30\text{ HP}$ | $2.5\text{ m/s}$ | Elite (Purple) | Volcanic magma raft exploding violently upon destruction. |
| **Bombard (Mini-Boss)** | Level 3 | $180\text{ HP}$ | $1.0\text{ m/s}$ | Legendary (Gold) | Heavy mortar siege vessel firing high-arc AoE shells. |

---

## 👑 4. World Bosses

Campaign levels culminate in multi-phase boss encounters with custom telegraphing and destructible components:

### 1. Captain Ironjaw's War-Barge (Level 1)
* **Script:** [`boss_war_barge.gd`](file:///f:/projects/cove-corsair/src/gameplay/enemies/boss_war_barge.gd) | **HP:** $220\text{ HP}$
* **3D Model:** `res://assets/models/enemy/vessels/boss_war_barge.glb`
* **Calibrated Transform:** `y_offset = 0.22`, `scale = Vector3(3.36, 3.36, 3.36)`, `rotation = Vector3(0, 92, 0)`
* **Components:** Port Swivel ($30\text{ HP}$), Starboard Swivel ($30\text{ HP}$), Front Armor ($40\text{ HP}$).
* **Mechanics:** Locks scroll speed to $6.0\text{ m/s}$, fires swivel gun salvos, and vents steam to expose its Boiler Core ($2\times$ critical hit multiplier).

### 2. The Phantom Dredge (Level 2)
* **Script:** [`boss_phantom_dredge.gd`](file:///f:/projects/cove-corsair/src/gameplay/enemies/boss_phantom_dredge.gd) | **HP:** $450\text{ HP}$
* **3D Model:** `res://assets/models/enemy/vessels/boss_phantom_dredge.glb`
* **Calibrated Transform:** `y_offset = 1.45`, `scale = Vector3(1.00, 1.00, 1.00)`, `rotation = Vector3(0, 0, 0)`
* **Components:** Ghostly Paddlewheel & Spectral Boiler.
* **Mechanics:** Dredge wheel shockwaves, spectral cannon volleys, ghostly submersion invulnerability phases, and high-speed frenzy charges.

### 3. Brimstone Siege Fortress (Level 3)
* **Script:** [`boss_siege_fortress.gd`](file:///f:/projects/cove-corsair/src/gameplay/enemies/boss_siege_fortress.gd) | **HP:** $800\text{ HP}$
* **3D Model:** `res://assets/models/enemy/vessels/boss_siege_fortress.glb`
* **Calibrated Transform:** `y_offset = 0.50`, `scale = Vector3(4.74, 4.74, 4.74)`, `rotation = Vector3(0, 0, 0)`
* **Components:** Port Turret ($150\text{ HP}$), Starboard Turret ($150\text{ HP}$), Prow Ram ($150\text{ HP}$), Furnace Core ($350\text{ HP}$).
* **Mechanics:** Dual mortar siege telegraphing, lateral magma vent eruption streams, and exposed Furnace Core meltdown.

### 4. Captain Bone-Beard (Bonus / Special Boss)
* **Script:** [`boss_bone_beard.gd`](file:///f:/projects/cove-corsair/src/gameplay/enemies/boss_bone_beard.gd) | **HP:** $500\text{ HP}$
* **3D Model:** `res://assets/models/enemy/vessels/captain_bone-beard’s_twin_frigate.glb`
* **Calibrated Transform:** `y_offset = 2.15`, `scale = Vector3(4.48, 4.48, 4.48)`, `rotation = Vector3(0, 0, 0)`
* **Mechanics:** Ghostly pirate captain vessel spawning skeleton minion rowers and firing cursed skull ordnance.
