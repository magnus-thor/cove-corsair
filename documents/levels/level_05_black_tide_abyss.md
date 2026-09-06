# Level 5: Black Tide Abyss - Technical Specification

**Black Tide Abyss** escalates the swamp campaign to maximum intensity with dark abyssal waters, dense toxic Biogas hazard clusters, accelerated Tide Cutters, an upgraded Harvester mini-boss, and the terrifying **Phantom Dredge (Abyssal Dreadnought)** boss ($550\text{ HP}$).

---

## 1. Level Identity & Environment Configuration

* **Level Resource:** [`level_05_black_tide_abyss.tres`](file:///f:/projects/cove-corsair/src/data/resources/levels/level_05_black_tide_abyss.tres)
* **Biome Identifier:** `black_tide_bayou` (Abyssal Bayou / Deep Toxic Swampland)
* **Target Distance:** $280.0\text{m}$ (Scripted timeline from $0\text{m} \rightarrow 280\text{m}$, Boss encounter triggers at $280\text{m}$)
* **Base Scroll Speed:** $11.0\text{ m/s}$
* **River Width (World Units):** $12.0\text{m}$ ($X \in [-6.0, +6.0]$)
* **Starting Vessel:** [The Sloop](file:///f:/projects/cove-corsair/src/data/resources/user_vessels/sloop_ship.tres) (5 Starting Hull Points)
* **Environment Palette:**
  * **Water Albedo:** Deep Abyssal Toxic Green `Color(0.02, 0.18, 0.12, 0.95)`
  * **Fog Color:** Dark Swamp Fog `Color(0.10, 0.25, 0.15, 1.0)`
  * **Fog Density:** `0.015` (Dense abyssal swamp atmosphere)

---

## 2. Entity Roster & Mechanics

| Entity Class | Type Name | HP / Profile | Behavior & Mechanics |
| :--- | :--- | :--- | :--- |
| **Hazard** | Biogas Pod | Indestructible / Area Hazard | Toxic organic pods spawning in trios and pairs, releasing poison clouds upon collision. |
| **Mob** | Grave Skiff | $16\text{-}20\text{ HP}$ ($3.4\text{-}3.8\text{ m/s}$) | Reinforced swamp skiffs strafing across lanes with aggressive fire patterns. |
| **Mob** | Tide Cutter | $20\text{-}24\text{ HP}$ ($7.2\text{-}7.8\text{ m/s}$) | Heavy armor-plated cutters charging downriver at ultra-high speeds. |
| **Mini-Boss** | Harvester | $130\text{ HP}$ ($1.4\text{ m/s}$) | Heavy swamp harvester mini-boss spawning mid-run ($104\text{m}$) blocking central navigation. |
| **Gate** | Fleet Gate | Translucent Arch | Fleet Gates ($+1, +2$ Fleet Members) positioned to rebuild follower capacity. |
| **Collectible**| Coin Arc | $7\text{-}8$ Doubloons | Curved doubloon pickup sequences guiding safe swerve paths. |

---

## 3. Timeline Wave Structure

The level progresses through 31 timeline events structured into four high-pacing tactical phases across $280\text{m}$:

```
[0m] Start ───► [46m] Fleet Gate (+2) ───► [104m] Harvester Mini-Boss ───► [196m] Fleet Gate (+1) ───► [280m] Boss Battle
```

### Phase Breakdown:
1. **$0\text{m} - 46\text{m}$ (The Abyssal Entrance):**
   * Early dual Biogas Pods at $8\text{m}$ ($X = \pm 0.4$) followed by Grave Skiff ($16\text{ HP}$) at $16\text{m}$.
   * Triple Biogas Pod barrier at $26\text{m}$ ($X = -0.55, 0.0, +0.55$) and high-speed Tide Cutter ($20\text{ HP}, 7.2\text{ m/s}$) at $36\text{m}$.
   * $+2$ Fleet Gate at $46\text{m}$ enables broadside expansion.
2. **$46\text{m} - 104\text{m}$ (Swamp Ambush & Harvester Spawn):**
   * Coin arc sequence ($7$ coins) followed by dual Grave Skiffs ($18\text{ HP}$) at $68\text{m}$.
   * Fast Tide Cutter ($22\text{ HP}, 7.4\text{ m/s}$) at $92\text{m}$ immediately preceding the mini-boss.
   * **Harvester Mini-Boss** ($130\text{ HP}$) spawns at $104\text{m}$.
3. **$104\text{m} - 196\text{m}$ (Abyssal Channel Gauntlet):**
   * Coin arc ($8$ coins) and $+2$ Fleet Gate at $132\text{m}$.
   * Dual Grave Skiffs ($18\text{ HP}$) and dual Tide Cutters ($24\text{ HP}, 7.6\text{ m/s}$) separated by Biogas Pod clusters.
   * $+1$ Fleet Gate at $196\text{m}$ provides late-run recovery.
4. **$196\text{m} - 280\text{m}$ (Toxic Gauntlet & Pre-Boss Climax):**
   * Triple Grave Skiff formation ($20\text{ HP}$ each at $X = -0.5, 0.0, +0.5$) at $210\text{m}$.
   * High-speed central Tide Cutter ($24\text{ HP}, 7.8\text{ m/s}$) at $240\text{m}$ flanked by Biogas Pods.
   * Boss warning banner at $266\text{m}$ ("THE PHANTOM DREDGE RISES FROM THE ABYSS!").

---

## 4. Boss Specification: The Phantom Dredge (Abyssal Dreadnought)

* **Boss Scene:** [`boss_phantom_dredge.tscn`](file:///f:/projects/cove-corsair/src/gameplay/enemies/boss_phantom_dredge.tscn) / [`boss_phantom_dredge.gd`](file:///f:/projects/cove-corsair/src/gameplay/enemies/boss_phantom_dredge.gd)
* **Total Health:** $550\text{ HP}$ (Upgraded from Level 2's $450\text{ HP}$)
* **Boss Archetype:** Ghostly Steam-Dredger Paddlewheel Ironclad
* **Attack Behavior & Pacing:**
  * **Enhanced Health Pool:** $550\text{ HP}$ requires sustained firepower from a full follower fleet.
  * **Accelerated Submersion Cycle:** Ghostly submersion phases occur more rapidly, launching dense toxic shockwaves and broadside mortar salvos upon re-emergence.
  * **High-Speed Ramming:** Phase 3 acceleration forces rapid lateral maneuverability across the river channel.
