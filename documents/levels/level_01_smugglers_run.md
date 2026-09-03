# Level 1: Smuggler's Run - Technical Specification

**Smuggler's Run** serves as the introductory campaign level for **Cove Corsair**. It introduces basic movement, barrier destruction, multiplier gates, follower boat acquisition, and the multi-component boss encounter against Captain Ironjaw's War-Barge.

---

## 1. Level Identity & Environment Configuration

* **Level Resource:** [`level_01_smugglers_run.tres`](file:///f:/projects/cove-corsair/src/data/resources/levels/level_01_smugglers_run.tres)
* **Biome Identifier:** `smugglers_run` (Coastal / Tropical Archipelago)
* **Target Distance:** $250.0\text{m}$ (Scripted timeline from $0\text{m} \rightarrow 250\text{m}$, Boss encounter triggers at $250\text{m}$)
* **Base Scroll Speed:** $10.0\text{ m/s}$
* **River Width (World Units):** $12.0\text{m}$ ($X \in [-6.0, +6.0]$)
* **Starting Vessel:** [The Dinghy](file:///f:/projects/cove-corsair/src/data/resources/user_vessels/dinghy_ship.tres) (1 Starting Hull Point)
* **Environment Palette:**
  * **Water Albedo:** Clear Turquoise Cyan `Color(0.08, 0.58, 0.82, 0.88)`
  * **Fog Color:** Tropical Sky Blue `Color(0.48, 0.76, 0.94, 1.0)`
  * **Fog Density:** `0.0` (Crystal clear visibility)

---

## 2. Entity Roster & Mechanics

| Entity Class | Type Name | HP / Profile | Behavior & Mechanics |
| :--- | :--- | :--- | :--- |
| **Obstacle** | Wooden Barrel | $2\text{ HP}$ | Basic target practice barrel. Yields doubloons upon destruction. |
| **Obstacle** | Fuse Barrel | $3\text{-}4\text{ HP}$ | Red explosive barrel; detonates on destruction to clear adjacent lane obstacles. |
| **Obstacle** | Rune Barrel | $4\text{-}10\text{ HP}$ | Heavy obstacle requiring high firepower or multiplier support. |
| **Obstacle** | Armored Barrel Chest | $6\text{ HP}$ | High-tier obstacle dropping bonus doubloons / chest rewards. |
| **Hazard** | Reef Outcrop | Indestructible | Environmental rock barrier occupying $X = 0.0$ ($scale_x = 2.0, scale_z = 5.0$). Forces player to swerve left or right. |
| **Mob** | Skeleton Rowers | $3\text{ HP}$ ($1.5\text{ m/s}$) | Slow-moving forward enemy craft. |
| **Mob** | Raider Skiffs | $8\text{-}10\text{ HP}$ ($2.5\text{-}3.5\text{ m/s}$) | Fast-moving aggressive hostile skiff. |
| **Mob** | Turtle Rafts | $20\text{-}30\text{ HP}$ ($1.5\text{ m/s}$) | Heavy armored enemy barge requiring sustained fire. |
| **Mob** | Kamikaze Rafts | $10\text{-}12\text{ HP}$ ($6.0\text{-}6.5\text{ m/s}$) | High-speed ramming craft charging straight down river. |
| **Gate** | Multiplier Gate | Translucent Arch | Fleet Gates ($+1, +2$ Fleet Members) and Cannonball Multipliers ($+2, \times 2$). |

---

## 3. Timeline Wave Structure

The level progresses through key milestones across the $250\text{m}$ course:

```
[0m] Start ───► [60m] Gate (+1 Fleet) ───► [130m] Gate (+1 Fleet) ───► [144m] Reef Hazard ───► [210m] Gate (+2 Fleet) ───► [250m] Boss Battle
```

### Key Milestones:
* **$0\text{m} - 50\text{m}$ (Warmup & Calibration):**
  * Spawns light wooden barrel clusters at $X = \pm 0.3, \pm 0.5$.
  * First enemy encounter: Skeleton Rowers ($3\text{ HP}$) at $30\text{m}$ and $36\text{m}$.
* **$60\text{m}$ (First Fleet Gate):**
  * Spawns a **$+1$ Fleet Gate** at lane center ($X = 0.0$), granting the player their first follower skiff.
* **$68\text{m} - 124\text{m}$ (Rune Barrels & Raider Skiffs):**
  * Introduces Rune Barrels ($4\text{-}6\text{ HP}$) and Raider Skiffs ($8\text{ HP}$).
  * First heavy mob: Turtle Raft ($20\text{ HP}$) at $118\text{m}$.
* **$130\text{m}$ (Second Fleet Gate & Reef Bottleneck):**
  * **$+1$ Fleet Gate** at $130\text{m}$.
  * At $144\text{m}$, a central **Reef Hazard** splits the channel, followed by high-speed Kamikaze Rafts ($6.0\text{ m/s}$) at $162\text{m}$ and $167\text{m}$.
* **$170\text{m} - 247\text{m}$ (Pre-Boss Climax):**
  * Heavy enemy combinations: Turtle Rafts ($30\text{ HP}$), dense Raider Skiff double formations, and Kamikaze Rafts ($12\text{ HP}, 6.5\text{ m/s}$).
  * **$+2$ Fleet Gate** at $210\text{m}$ allows max fleet capacity before the boss encounter.
* **$250\text{m}$ (Boss Spawn):**
  * Spawns **Captain Ironjaw's War-Barge**.

---

## 4. Boss Specification: Captain Ironjaw's War-Barge

* **Boss Scene:** [`boss_war_barge.tscn`](file:///f:/projects/cove-corsair/src/gameplay/enemies/boss_war_barge.tscn) / [`boss_war_barge.gd`](file:///f:/projects/cove-corsair/src/gameplay/enemies/boss_war_barge.gd)
* **Total Health:** $220\text{ HP}$ (Main Hull / Boiler Core)
* **Destructible Sub-Components:**
  * **Port Swivel Gun:** $30\text{ HP}$ (Fires telegraphed mortar shots into player lanes)
  * **Starboard Swivel Gun:** $30\text{ HP}$ (Fires telegraphed mortar shots into player lanes)
  * **Front Armor Plating:** $40\text{ HP}$ (Protects main core until destroyed)
* **Boss Behavior & Phase Mechanics:**
  * **Phase 1 (Gun & Armor Barrage):** War-Barge locks scroll speed at $6.0\text{ m/s}$, maintaining forward positioning. Fires alternating swivel gun salvos.
  * **Phase 2 (Boiler Overheat):** When side guns or armor are destroyed, the War-Barge periodically vents steam, exposing the Boiler Core for critical hit damage ($2\times$ multiplier).
  * **Victory Condition:** Reducing main boss HP to $0$ triggers massive explosions, UI victory banner, and unlocks Level 2.
