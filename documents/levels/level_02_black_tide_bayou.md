# Level 2: Black Tide Bayou - Technical Specification

**Black Tide Bayou** escalates the campaign challenge with foggy, low-visibility swamp waters, toxic Biogas hazard pods, fast-strafing Grave Skiffs, mini-boss Harvesters, and the terrifying multi-phase **Phantom Dredge** boss.

---

## 1. Level Identity & Environment Configuration

* **Level Resource:** [`level_02_black_tide_bayou.tres`](file:///f:/projects/cove-corsair/src/data/resources/levels/level_02_black_tide_bayou.tres)
* **Biome Identifier:** `black_tide_bayou` (Dark Swampland / Cypress Bayou)
* **Target Distance:** $280.0\text{m}$ (Scripted timeline from $0\text{m} \rightarrow 280\text{m}$, Boss encounter triggers at $280\text{m}$)
* **Base Scroll Speed:** $10.0\text{ m/s}$
* **River Width (World Units):** $12.0\text{m}$ ($X \in [-6.0, +6.0]$)
* **Starting Vessel:** [The Sloop](file:///f:/projects/cove-corsair/src/data/resources/user_vessels/sloop_ship.tres) (5 Starting Hull Points)
* **Environment Palette:**
  * **Water Albedo:** Murky Dark Swamp Green `Color(0.04, 0.28, 0.22, 0.92)`
  * **Fog Color:** Deep Marsh Moss Fog `Color(0.06, 0.18, 0.14, 1.0)`
  * **Fog Density:** `0.022` (Atmospheric atmospheric haze limiting long-range visibility)

---

## 2. Entity Roster & Mechanics

| Entity Class | Type Name | HP / Profile | Behavior & Mechanics |
| :--- | :--- | :--- | :--- |
| **Obstacle** | Wooden / Reinforced Barrel | $2\text{-}6\text{ HP}$ | Standard obstacle layout forming gate funnels and lane barriers. |
| **Hazard** | Biogas Pod | $2\text{ HP}$ | Toxic organic pods. Upon destruction or collision, detonates into a lingering poison cloud area. |
| **Mob** | Grave Skiff | $6\text{-}12\text{ HP}$ | Fast swamp skiffs strafing laterally across lanes to disrupt player line of fire. |
| **Mob** | Tide Cutter | $10\text{-}18\text{ HP}$ | Armor-plated swamp cutter charging directly toward the player vessel. |
| **Mini-Boss** | Harvester | $120\text{ HP}$ | Heavy swamp harvester mini-boss spawning mid-run ($160\text{m}$). Fires broadsides and demands focused DPS. |
| **Gate** | Fleet & Multiplier Gate | Translucent Arch | Fleet Gates ($+1, +2$ Fleet Members) and Cannonball Multipliers ($+2, \times 2$). |

---

## 3. Timeline Wave Structure

The level contains 96 scripted timeline events structured into four distinct tactical phases across $280\text{m}$:

```
[0m] Start ───► [70m] Bayou Bottleneck ───► [160m] Harvester Mini-Boss ───► [240m] Toxic Storm ───► [280m] Boss Battle
```

### Phase Breakdown:
1. **$0\text{m} - 70\text{m}$ (The Murky Approach):**
   * Dense placement of Biogas Pods alongside wooden and reinforced barrels.
   * Introduces Grave Skiffs ($6\text{ HP}$) strafing between $X = -2.5$ and $X = +2.5$.
   * Fleet Gate at $45\text{m}$ ($+1$ Fleet) expands player broadside coverage.
2. **$70\text{m} - 160\text{m}$ (Swamp Ambushes & Tide Cutters):**
   * Rapid spawn sequences of Tide Cutters ($12\text{-}18\text{ HP}$) attacking in pairs.
   * Multiplier Gates ($\times 2$ Cannonballs) at $110\text{m}$ require precise swerve positioning amidst Biogas Pod clusters.
3. **$160\text{m} - 220\text{m}$ (Harvester Encounter & High-Density Gates):**
   * At $160\text{m}$, a **Harvester Mini-Boss** ($120\text{ HP}$) blocks the main channel.
   * Supported by dual $+1$ Fleet Gates at $185\text{m}$ and $210\text{m}$ to rebuild lost follower vessels.
4. **$220\text{m} - 280\text{m}$ (Toxic Gauntlet & Pre-Boss Rush):**
   * Maximum hazard density featuring interlocking Biogas Pods and charging Tide Cutters.
   * Final $+2$ Fleet Gate at $260\text{m}$ prepares player fleet for the boss fight.

---

## 4. Boss Specification: The Phantom Dredge

* **Boss Scene:** [`boss_phantom_dredge.tscn`](file:///f:/projects/cove-corsair/src/gameplay/enemies/boss_phantom_dredge.tscn) / [`boss_phantom_dredge.gd`](file:///f:/projects/cove-corsair/src/gameplay/enemies/boss_phantom_dredge.gd)
* **Total Health:** $450\text{ HP}$
* **Boss Archetype:** Ghostly Steam-Dredger Paddlewheel Ironclad
* **Attack Phases & Special Mechanics:**
  * **Phase 1: Dredge Wheel Shockwaves (100% - 60% HP):**
    * The Dredge sweeps across lanes, creating forward-moving swamp shockwave hazards.
    * Fires spectral green cannon volleys targeted at player lane positions.
  * **Phase 2: Ghostly Submersion & Toxic Surge (60% - 25% HP):**
    * The Dredge temporarily submerges underwater, becoming invulnerable for $4.0\text{ seconds}$ while spawning Biogas Pod waves.
    * Re-emerges with an explosive splash, launching broadside mortars into adjacent lanes.
  * **Phase 3: Desperate Frenzy (Below 25% HP):**
    * Maximum scroll speed acceleration ($14.0\text{ m/s}$).
    * Continuous paddlewheel ramming attempts demanding non-stop lateral swerving.
