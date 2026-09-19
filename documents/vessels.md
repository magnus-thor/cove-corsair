# Cove Corsair - Vessels & Mobs Architecture

This document provides a comprehensive technical reference for all naval vessels in **Cove Corsair**, including Player Flagships, Follower Escort Skiffs, Hostile Mobs, Mini-Bosses, and Phase Bosses.

---

## ⛵ 1. Player Flagships (User Vessels)

Player vessels define handling speed, hull durability, collision boundaries, and hardpoint weapon sockets for deck crew and naval cannons. The flotilla is structured around **The Dinghy** as an introductory starter boat (Jack Sparrow stepping off a sinking rowboat) alongside **three primary tactical flagships** forming a distinct mobility, range, and firepower spectrum:
* **The Sloop:** Lightweight, agile, high-speed runner with long-range but light firepower.
* **The Bombard Skiff:** Heavy, slow-moving siege vessel with short-range high-impact explosive AoE mortar fire.
* **The Ironclad:** Heavily armored frontline brawler sitting squarely between them in speed and range, delivering devastating triple-cannon frontal volleys.

### Vessel Comparison Table

| Attribute | [The Dinghy](file:///f:/projects/cove-corsair/src/data/resources/user_vessels/dinghy_ship.tres) | [The Sloop](file:///f:/projects/cove-corsair/src/data/resources/user_vessels/sloop_ship.tres) | [The Bombard Skiff](file:///f:/projects/cove-corsair/src/data/resources/user_vessels/bombard_skiff_ship.tres) | [The Ironclad](file:///f:/projects/cove-corsair/src/data/resources/user_vessels/ironclad_ship.tres) |
| :--- | :--- | :--- | :--- | :--- |
| **Archetype** | Starter Rowboat (Tutorial) | Agile Long-Range Runner | Heavy Siege Artillery | Armored Brawler (Mid-Spectrum) |
| **Purchase Price** | **$0\text{ Doubloons}$** | **$500\text{ Doubloons}$** | **$1,000\text{ Doubloons}$** | **$2,500\text{ Doubloons}$** |
| **Tier 2 Upgrade Cost** | **$50\text{ Doubloons}$** (Tutorial) | **$700\text{ Doubloons}$** | **$1,200\text{ Doubloons}$** | **$3,000\text{ Doubloons}$** |
| **Tier 3 Upgrade Cost** | **$100\text{ Doubloons}$** (Tutorial) | **$1,600\text{ Doubloons}$** | **$2,200\text{ Doubloons}$** | **$5,000\text{ Doubloons}$** |
| **Base Hull HP** | $2\text{ HP}$ (Fragile) | $4\text{ HP}$ (Light) | $4\text{ HP}$ (Medium) | $8\text{ HP}$ (Heavy Armor) |
| **Lateral Move Speed** | $10.5\text{ m/s}$ | $11.5\text{ m/s}$ (Fastest) | $6.5\text{ m/s}$ (Slowest) | $8.5\text{ m/s}$ (Balanced) |
| **Base Fire Rate Cooldown** | $0.20\text{s}$ | $0.18\text{s}$ | $1.30\text{s}$ | $0.22\text{s}$ |
| **Frontal Armament** | $1$ Bow Chaser ($1\text{ dmg}$) | $2$ Bow Chasers ($2\times 1\text{ dmg}$, parallel) | $1$ Heavy Mortar ($4\text{ dir} + 3\text{ AoE}$) | $3$ Heavy Cannons ($3\times 2\text{ dmg}$, volley) |
| **Effective Range** | $38.0\text{m}$ (Standard) | $38.0\text{m}$ (Long Range) | $13.0\text{m}$ (Short Range Mortar) | $24.0\text{m}$ (Mid Range Battery) |
| **Collision Size ($X, Y, Z$)** | $(1.6, 1.0, 2.8)$ | $(1.4, 1.0, 2.5)$ | $(1.8, 1.2, 3.0)$ | $(2.4, 1.4, 3.8)$ |
| **Primary Tactical Role** | Learning river navigation | Long-range sniping, reef slaloms | Dense barricade & mob cluster siege | Frontline brawling, battering ram |

---

### Hardpoint Sockets & Upgrade Roadmaps

#### 🚤 1.1 The Dinghy ([`dinghy_ship.tres`](file:///f:/projects/cove-corsair/src/data/resources/user_vessels/dinghy_ship.tres))
* **Lore / Concept:** The humble, leaky rowboat the player arrives in (Jack Sparrow style). Not intended for late-game or competitive endless runs.
* **3D Model:** `res://assets/models/user/vessels/dinghy.glb`
* **Calibrated Transform:** `y_offset = 0.26`, `scale = Vector3(3.80, 3.80, 3.80)`, `rotation = Vector3(0, 0, 0)`
* **Upgrade Costs:** Tier 1: $0$ | Tier 2: $50$ | Tier 3: $100$ (Token onboarding upgrades)
* **Hardpoint Sockets:**
  * `BowMount`: Front single chaser mount (offset: `(0.00, 0.46, -1.70)`, scale: $1.00$)
  * `MidDeckCrew`: Center deck socket (offset: `(0.00, 0.45, -1.08)`, scale: $1.25$)
  * `AftDeckCrew`: Aft deck socket (offset: `(0.05, 0.46, 0.55)`, scale: $2.48$)
* **Tier Progression:**
  * **Tier 1:** Base Single Bow Chaser cannon ([`weapon_bow_chaser.tres`](file:///f:/projects/cove-corsair/src/data/resources/user_crew/weapon_bow_chaser.tres)) firing 1 standard ball ($1\text{ dmg}$).
  * **Tier 2:** Patched Planks ($3\text{ HP}$, $+15\%$ Firepower) adding Monkey Bomber Crew socket.
  * **Tier 3:** Reinforced Rowboat ($4\text{ HP}$, $+30\%$ Firepower) unlocking Aft Crew socket.

#### ⛵ 1.2 The Sloop ([`sloop_ship.tres`](file:///f:/projects/cove-corsair/src/data/resources/user_vessels/sloop_ship.tres))
* **Archetype:** Agile Long-Range Runner. High maneuverability, fast river swerving, long-distance engagement.
* **3D Model:** `res://assets/models/user/vessels/the_sloop.glb`
* **Calibrated Transform:** `y_offset = 0.33`, `scale = Vector3(2.00, 2.00, 2.00)`, `rotation = Vector3(0, -90, 0)`
* **Upgrade Costs:** Tier 1: $500$ | Tier 2: $700$ | Tier 3: $1,600$
* **Hardpoint Sockets:**
  * `BowMount`: Dual bow chaser cannons ([`weapon_sloop_twin_chaser.tres`](file:///f:/projects/cove-corsair/src/data/resources/user_crew/weapon_sloop_twin_chaser.tres)) firing 2 parallel high-velocity cannonballs ($1\text{ dmg}$ each, $38\text{m}$ range).
  * `MidDeckCrew`: Mid-deck crew socket (scale: $0.63$)
  * `AftDeckCrew`: Aft-deck crew socket (scale: $1.40$)
  * `PortSwivelMount` & `StarboardSwivelMount`: Lateral swivel mounts (scale: $3.10$)
* **Tier Progression:**
  * **Tier 1:** Standard Oak ($4\text{ HP}$) with Twin Bow Chasers.
  * **Tier 2:** Reinforced Oak ($5\text{ HP}$, $+15\%$ Firepower) adding Monkey Bomber & Skeleton Tosser support.
  * **Tier 3:** Fleet Flagship ($6\text{ HP}$, $+30\%$ Firepower) adding Port & Starboard Swivel Guns for broadside defense.

#### 💣 1.3 The Bombard Skiff ([`bombard_skiff_ship.tres`](file:///f:/projects/cove-corsair/src/data/resources/user_vessels/bombard_skiff_ship.tres))
* **Archetype:** Heavy Siege Artillery. Slow lateral speed ($6.5\text{ m/s}$), high tactical risk, devastating short-range mortar AoE.
* **3D Model:** `res://assets/models/user/vessels/the_bombard_skiff.glb`
* **Calibrated Transform:** `y_offset = 1.00`, `scale = Vector3(3.50, 3.50, 3.50)`, `rotation = Vector3(0, -90, 0)`
* **Upgrade Costs:** Tier 1: $1,000$ | Tier 2: $1,200$ | Tier 3: $2,200$
* **Hardpoint Sockets:**
  * `BowMortarMount`: Heavy frontal mortar ([`weapon_bow_mortar.tres`](file:///f:/projects/cove-corsair/src/data/resources/user_crew/weapon_bow_mortar.tres)) firing parabolic AoE shells ([`ammo_heavy_shot.tres`](file:///f:/projects/cove-corsair/src/data/resources/user_ammo/ammo_heavy_shot.tres)) with $4\text{ direct} + 3\text{ AoE}$ damage across a $3.2\text{m}$ splash radius and $13\text{m}$ short range.
  * `QuarterdeckCrew`: Elevated quarterdeck socket (scale: $1.30$)
  * `PortRailMount` & `StarboardRailMount`: Flank scattershot mounts (scale: $1.80$)
* **Tier Progression:**
  * **Tier 1:** Artillery Skiff ($4\text{ HP}$) with Heavy Siege Mortar.
  * **Tier 2:** Reinforced Keel ($5\text{ HP}$, $+15\%$ Firepower) adding Quarterdeck Crew Support.
  * **Tier 3:** Siege Dreadnought ($6\text{ HP}$, $+30\%$ Firepower) adding Dual Side Scattershot Carronades.

#### 🛡️ 1.4 The Ironclad ([`ironclad_ship.tres`](file:///f:/projects/cove-corsair/src/data/resources/user_vessels/ironclad_ship.tres))
* **Archetype:** Armored Brawler. Medium speed ($8.5\text{ m/s}$), $8\text{ HP}$ armored hull, massive forward line-clearing punch.
* **3D Model:** `res://assets/models/user/vessels/the_ironclad.glb`
* **Calibrated Transform:** `y_offset = 0.35`, `scale = Vector3(2.00, 2.00, 2.00)`, `rotation = Vector3(0, -90, 0)`
* **Upgrade Costs:** Tier 1: $2,500$ | Tier 2: $3,000$ | Tier 3: $5,000$
* **Hardpoint Sockets:**
  * `BowMount`: Triple Heavy Bow Battery ([`weapon_ironclad_battery.tres`](file:///f:/projects/cove-corsair/src/data/resources/user_crew/weapon_ironclad_battery.tres)) firing 3 heavy iron shots in a forward cluster ($2\text{ dmg}$ each = $6\text{ total dmg}$ per volley, $24\text{m}$ mid range).
  * `MonkeyCrew` & `SkeletonCrew`: Deck crew sockets (scales: $0.79$, $1.24$)
  * `PortSwivelMount1/2` & `StarboardSwivelMount1/2`: Quad lateral swivel mounts (scale: $3.20$)
* **Tier Progression:**
  * **Tier 1:** Armored Plating ($8\text{ HP}$) with Triple Heavy Bow Battery.
  * **Tier 2:** Reinforced Iron ($9\text{ HP}$, $+15\%$ Firepower) adding Dual Deck Crew support.
  * **Tier 3:** Dreadnought Hull ($10\text{ HP}$, $+30\%$ Firepower) adding Quad Lateral Swivel Guns.

---

### 📈 1.5 Per-Stat Micro-Upgrade Progression Architecture

To support long-term player retention and align with rewarded ad doubloon multipliers after runs, each vessel features **4 Core Micro-Upgrade Tracks** (Levels 1–10):
1. **Hull Armor Track:** Increases base hull HP incrementally ($+1\text{ HP}$ per milestone tier).
2. **Sail & Rudder Handling Track:** Increases lateral swerve speed ($+3\text{--}5\%$ per rank) and river banking response.
3. **Cannon Reload & Mastery Track:** Reduces firing cooldown ($+3\text{--}5\%$ fire rate) and adds projectile damage bonuses at elite ranks.
4. **Deck Expansion Track:** Milestones unlock physical weapon sockets (Mid Crew, Aft Crew, and Port/Starboard Swivels/Scatter mounts).

> [!NOTE]
> The Dinghy has access only to Levels 1–3 at minimal token prices ($50\text{--}100\text{ doubloons}$) for onboarding. Flagship progression (Sloop, Bombard Skiff, Ironclad) scales up to Level 10 to serve as the primary doubloon sink.

---

## 🛶 2. Follower Fleet Skiffs

When passing through **Fleet Summon Gates** ($+1, +2$), escort skiffs join the player's flotilla ([`follower_boat.gd`](file:///f:/projects/cove-corsair/src/gameplay/player/follower_boat.gd)):
* **Formation Behavior:** Dynamic formation array flanking the player ship.
* **Firepower:** Synchronized forward and broadside cannon volleys that fire in lockstep with the player boat.
* **Durability:** Escort skiffs absorb collisions with hazards or enemy fire before damage reaches the player flagship.

---

## ⚔️ 3. Enemy Mobs & Mini-Bosses

Hostile craft adhere to the [Tiered Color Rarity System](file:///f:/projects/cove-corsair/documents/Ahoy%21%20Pirate%20Arcade%20Runner_%20Master%20Game%20Design%20&%20Strategic%20Roadmap.md#3-tiered-color-rarity-system):

| Mob Class | Biome | HP Profile | Forward Speed | Rarity Tier | Behavior & Attack Pattern |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Skeleton Rowers** | Tropical | $3\text{ HP}$ | $1.5\text{ m/s}$ | Common (White) | Slow-moving forward enemy craft; low damage target. |
| **Raider Skiff** | Tropical | $8\text{-}10\text{ HP}$ | $2.5\text{-}3.5\text{ m/s}$ | Normal (Green) | Fast-moving mob advancing down-river. |
| **Turtle Raft** | Tropical / Bayou | $20\text{-}30\text{ HP}$ | $1.5\text{ m/s}$ | Elite (Purple) | Heavy armored raft requiring focused DPS. |
| **Kamikaze Raft** | Tropical | $10\text{-}12\text{ HP}$ | $6.0\text{-}6.5\text{ m/s}$ | Rare (Blue) | High-speed ramming craft charging directly down lane. |
| **Grave Skiff** | Bayou | $6\text{-}12\text{ HP}$ | $2.0\text{-}3.0\text{ m/s}$ | Normal (Green) | Fast swamp skiff strafing laterally across lanes. |
| **Tide Cutter** | Bayou | $10\text{-}18\text{ HP}$ | $3.5\text{ m/s}$ | Rare (Blue) | Armor-plated swamp cutter charging forward. |
| **Harvester (Mini-Boss)**| Bayou | $120\text{ HP}$ | $1.0\text{ m/s}$ | Legendary (Gold) | Heavy swamp harvester mini-boss firing broadside volleys. |
| **Iron Gunner** | Brimstone | $14\text{-}22\text{ HP}$ | $2.0\text{ m/s}$ | Rare (Blue) | Armored gunboat firing long-range cannonballs. |
| **Brimstone Raft** | Brimstone | $18\text{-}30\text{ HP}$ | $2.5\text{ m/s}$ | Elite (Purple) | Volcanic magma raft exploding violently upon destruction. |
| **Bombard (Mini-Boss)** | Brimstone | $180\text{ HP}$ | $1.0\text{ m/s}$ | Legendary (Gold) | Heavy mortar siege vessel firing high-arc AoE shells. |

---

## 👑 4. World & Campaign Bosses

Campaign levels feature milestone boss encounters every 5 levels across the 45-level campaign:

### 1. Captain Ironjaw's War-Barge (Levels 10, 35)
* **Script:** [`boss_war_barge.gd`](file:///f:/projects/cove-corsair/src/gameplay/enemies/boss_war_barge.gd) | **HP:** $220\text{--}400\text{ HP}$
* **3D Model:** `res://assets/models/enemy/vessels/boss_war_barge.glb`
* **Calibrated Transform:** `y_offset = 0.22`, `scale = Vector3(3.36, 3.36, 3.36)`, `rotation = Vector3(0, 92, 0)`
* **Components:** Port Swivel ($30\text{ HP}$), Starboard Swivel ($30\text{ HP}$), Front Armor ($40\text{ HP}$).
* **Mechanics:** Locks scroll speed, fires swivel gun salvos, and vents steam to expose its Boiler Core ($2\times$ critical hit multiplier).

### 2. The Phantom Dredge (Levels 5, 25)
* **Script:** [`boss_phantom_dredge.gd`](file:///f:/projects/cove-corsair/src/gameplay/enemies/boss_phantom_dredge.gd) | **HP:** $500\text{--}650\text{ HP}$
* **3D Model:** `res://assets/models/enemy/vessels/boss_phantom_dredge.glb`
* **Calibrated Transform:** `y_offset = 1.45`, `scale = Vector3(1.00, 1.00, 1.00)`, `rotation = Vector3(0, 0, 0)`
* **Components:** Ghostly Paddlewheel & Spectral Boiler.
* **Mechanics:** Dredge wheel shockwaves, spectral cannon volleys, ghostly submersion invulnerability, and high-speed charges.

### 3. Brimstone Siege Fortress (Levels 20, 40)
* **Script:** [`boss_siege_fortress.gd`](file:///f:/projects/cove-corsair/src/gameplay/enemies/boss_siege_fortress.gd) | **HP:** $800\text{--}1,200\text{ HP}$
* **3D Model:** `res://assets/models/enemy/vessels/boss_siege_fortress.glb`
* **Calibrated Transform:** `y_offset = 0.50`, `scale = Vector3(4.74, 4.74, 4.74)`, `rotation = Vector3(0, 0, 0)`
* **Components:** Port Turret, Starboard Turret, Prow Ram, Furnace Core.
* **Mechanics:** Dual mortar siege telegraphing, lateral magma vent eruption streams, and exposed Furnace Core meltdown.

### 4. Captain Bone-Beard (Levels 15, 30, 45)
* **Script:** [`boss_bone_beard.gd`](file:///f:/projects/cove-corsair/src/gameplay/enemies/boss_bone_beard.gd) | **HP:** $500\text{--}1,000\text{ HP}$
* **3D Model:** `res://assets/models/enemy/vessels/captain_bone-beard’s_twin_frigate.glb`
* **Calibrated Transform:** `y_offset = 2.15`, `scale = Vector3(4.48, 4.48, 4.48)`, `rotation = Vector3(0, 0, 0)`
* **Mechanics:** Catamaran twin frigate spawning skeleton minion rowers, cursed broadside salvos, and the final campaign throne showdown at Level 45.
