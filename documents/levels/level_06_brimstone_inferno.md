# Level 6: Brimstone Inferno - Technical Specification

**Brimstone Inferno** is the ultimate campaign level of **Cove Corsair**, set in a roaring molten magma abyss guarded by erupting Thermal Geysers, armored Iron Gunners, hyper-velocity Brimstone Rafts, an upgraded Bombard Siege Ship mini-boss, and the monumental **Infernal Siege Fortress** boss ($1000\text{ HP}$).

---

## 1. Level Identity & Environment Configuration

* **Level Resource:** [`level_06_brimstone_inferno.tres`](file:///f:/projects/cove-corsair/src/data/resources/levels/level_06_brimstone_inferno.tres)
* **Biome Identifier:** `brimstone_bastion` (Infernal Volcanic Caldera / Magma Abyss)
* **Target Distance:** $320.0\text{m}$ (Scripted timeline from $0\text{m} \rightarrow 320\text{m}$, Boss encounter triggers at $320\text{m}$)
* **Base Scroll Speed:** $11.0\text{ m/s}$
* **River Width (World Units):** $12.0\text{m}$ ($X \in [-6.0, +6.0]$)
* **Starting Vessel:** [The Ironclad](file:///f:/projects/cove-corsair/src/data/resources/user_vessels/ironclad_ship.tres) (8 Starting Hull Points)
* **Environment Palette:**
  * **Water Albedo:** Infernal Molten Lava Red `Color(0.35, 0.08, 0.04, 0.95)`
  * **Fog Color:** Blazing Ash Orange/Red `Color(0.45, 0.15, 0.08, 1.0)`
  * **Fog Density:** `0.02` (Dense volcanic ash and glowing ember storm)

---

## 2. Entity Roster & Mechanics

| Entity Class | Type Name | HP / Profile | Behavior & Mechanics |
| :--- | :--- | :--- | :--- |
| **Hazard** | Thermal Geyser | Indestructible | Erupts periodically with high-temperature thermal plumes, dealing instant hull damage. |
| **Mob** | Iron Gunner | $30\text{-}38\text{ HP}$ ($2.8\text{-}3.2\text{ m/s}$) | Heavy volcanic gunboats firing long-range cannonball salvos down player lanes. |
| **Mob** | Brimstone Raft | $22\text{-}28\text{ HP}$ ($8.2\text{-}9.0\text{ m/s}$) | Ultra-fast magma rafts charging downriver that explode violently upon destruction or contact. |
| **Mini-Boss** | Bombard Siege Ship | $140\text{ HP}$ ($1.4\text{ m/s}$) | Heavy mortar mini-boss spawning mid-run ($122\text{m}$) launching targeted mortar fire. |
| **Gate** | Fleet Gate | Translucent Arch | Fleet Gates ($+2$ Fleet Members) enabling maximum follower fleet assembly. |
| **Collectible**| Coin Arc | $8\text{-}10$ Doubloons | Long doubloon arcs guiding maneuver paths through geyser openings. |

---

## 3. Timeline Wave Structure

The level contains 28 timeline events structured into four intense tactical phases across $320\text{m}$:

```
[0m] Start ───► [54m] Fleet Gate (+2) ───► [122m] Bombard Mini-Boss ───► [222m] Fleet Gate (+2) ───► [320m] Boss Battle
```

### Phase Breakdown:
1. **$0\text{m} - 54\text{m}$ (The Infernal Pass):**
   * Early dual Thermal Geysers at $8\text{m}$ ($X = \pm 0.4$) followed by Iron Gunner ($30\text{ HP}$) at $18\text{m}$.
   * High-speed Brimstone Rafts ($22\text{ HP}, 8.2\text{ m/s}$) at $30\text{m}$ paired with triple Thermal Geysers at $42\text{m}$.
   * $+2$ Fleet Gate at $54\text{m}$ provides early fleet reinforcement.
2. **$54\text{m} - 122\text{m}$ (Magma Gauntlet & Bombard Spawn):**
   * Coin arc ($8$ coins) followed by dual Iron Gunners ($34\text{ HP}$) at $78\text{m}$.
   * Triple Brimstone Rafts ($24\text{ HP}, 8.5\text{ m/s}$) at $106\text{m}$ passing through narrow geyser lanes.
   * **Bombard Siege Ship Mini-Boss** ($140\text{ HP}$) spawns at $122\text{m}$.
3. **$122\text{m} - 222\text{m}$ (Fortress Resupply & Heavy Waves):**
   * Coin arc ($9$ coins) and $+2$ Fleet Gate at $154\text{m}$.
   * Interlocking dual Iron Gunners ($36\text{ HP}$) and dual Brimstone Rafts ($26\text{ HP}, 8.8\text{ m/s}$).
   * Central Thermal Geyser at $210\text{m}$ preceding the $+2$ Fleet Gate at $222\text{m}$.
4. **$222\text{m} - 320\text{m}$ (Inferno Gauntlet & Final Siege):**
   * Triple Iron Gunner formation ($38\text{ HP}$ each at $X = -0.5, 0.0, +0.5$) at $236\text{m}$.
   * 10-coin arc sequence followed by dual Thermal Geysers and triple high-speed Brimstone Rafts ($28\text{ HP}, 9.0\text{ m/s}$).
   * Boss warning banner at $302\text{m}$ ("THE INFERNAL SIEGE FORTRESS AWAKENS (1000 HP)!").

---

## 4. Boss Specification: Infernal Siege Fortress

* **Boss Scene:** [`boss_siege_fortress.tscn`](file:///f:/projects/cove-corsair/src/gameplay/enemies/boss_siege_fortress.tscn) / [`boss_siege_fortress.gd`](file:///f:/projects/cove-corsair/src/gameplay/enemies/boss_siege_fortress.gd)
* **Total Health:** $1000\text{ HP}$ (Upgraded from Level 3's $800\text{ HP}$)
* **Boss Archetype:** Floating Iron Fortress / Dreadnought Citadel
* **Destructible Sub-Components & Scaling:**
  * **Port Mortar Turret:** $188\text{ HP}$ (Scaled dynamically from $1000\text{ HP}$ total pool)
  * **Starboard Mortar Turret:** $188\text{ HP}$
  * **Frontal Prow Ram:** $188\text{ HP}$
  * **Central Magma Core:** $436\text{ HP}$
* **Boss Behavior & Attack Phases:**
  * **Phase 1: Dual Siege Mortar Salvos (100% - 70% HP):** Mortar turrets lock onto player coordinates with rapid red telegraph circles.
  * **Phase 2: Lateral Magma Vents & Raft Escorts (70% - 30% HP):** Side vents spew lava streams while spawning escort rafts.
  * **Phase 3: Core Meltdown (Below 30% HP):** Central Magma Core exposes, launching continuous screen-shaking mortar barrages until reduced to $0\text{ HP}$.
  * **Victory Condition:** Core destruction triggers campaign completion, end-of-game victory UI, and total campaign stats summary.
