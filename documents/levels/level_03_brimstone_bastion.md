# Level 3: Brimstone Bastion - Technical Specification

**Brimstone Bastion** is the climactic campaign level of **Cove Corsair**, set in a boiling volcanic caldera channel guarded by lava geysers, heavy Iron Gunner artillery boats, explosive Brimstone Rafts, Bombard mini-bosses, and the massive **Brimstone Siege Fortress** boss.

---

## 1. Level Identity & Environment Configuration

* **Level Resource:** [`level_03_brimstone_bastion.tres`](file:///f:/projects/cove-corsair/src/data/resources/levels/level_03_brimstone_bastion.tres)
* **Biome Identifier:** `brimstone_bastion` (Volcanic Caldera / Magma Fortress Channel)
* **Target Distance:** $320.0\text{m}$ (Scripted timeline from $0\text{m} \rightarrow 320\text{m}$, Boss encounter triggers at $320\text{m}$)
* **Base Scroll Speed:** $10.0\text{ m/s}$
* **River Width (World Units):** $12.0\text{m}$ ($X \in [-6.0, +6.0]$)
* **Starting Vessel:** [The Ironclad](file:///f:/projects/cove-corsair/src/data/resources/user_vessels/ironclad_ship.tres) (2 Starting Hull Points)
* **Environment Palette:**
  * **Water Albedo:** Fiery Molten Volcanic Red `Color(0.22, 0.06, 0.04, 1.0)`
  * **Fog Color:** Smoky Ash Red `Color(0.25, 0.08, 0.04, 1.0)`
  * **Fog Density:** `0.024` (Dense atmospheric ash and ember haze)

---

## 2. Entity Roster & Mechanics

| Entity Class | Type Name | HP / Profile | Behavior & Mechanics |
| :--- | :--- | :--- | :--- |
| **Obstacle** | Reinforced / Magma Barrel | $4\text{-}10\text{ HP}$ | Heavy obstacle barricades requiring sustained volley fire. |
| **Hazard** | Thermal Geyser | Indestructible | Erupts periodically with telegraphed thermal plumes, dealing instant hull damage on contact. |
| **Mob** | Iron Gunner | $14\text{-}22\text{ HP}$ | Heavily armored gunboats firing long-range cannonballs down player lanes. |
| **Mob** | Brimstone Raft | $18\text{-}30\text{ HP}$ | Volcanic magma-filled rafts that explode violently upon destruction or collision. |
| **Mini-Boss** | Bombard Siege Ship | $180\text{ HP}$ | Massive mortar mini-boss spawning at $180\text{m}$. Fires high-arc mortar shells targeting player coordinates. |
| **Gate** | Multiplier Gate | Translucent Arch | Dense placement of $+2, +4$ Fleet Gates and $\times 2, \times 3$ Cannonball Multipliers. |

---

## 3. Timeline Wave Structure

Containing 223 detailed timeline events, **Brimstone Bastion** represents the highest entity density and pacing curve in the campaign:

```
[0m] Start ───► [90m] Geyser Alley ───► [180m] Bombard Siege Ship ───► [280m] Inferno Gauntlet ───► [320m] Boss Battle
```

### Phase Breakdown:
1. **$0\text{m} - 90\text{m}$ (The Volcanic Pass):**
   * Immediate onslaught of Iron Gunners ($14\text{ HP}$) and Thermal Geysers telegraphing eruptive zones.
   * $+2$ Fleet Gate at $40\text{m}$ enables early fleet mobilization to handle high obstacle HP pools.
2. **$90\text{m} - 180\text{m}$ (Geyser Alley & Magma Rafts):**
   * Interlocking Thermal Geysers narrow navigable channels down to single lanes.
   * High-speed Brimstone Rafts ($22\text{-}30\text{ HP}$) charge through geyser openings, requiring rapid target switching.
3. **$180\text{m} - 270\text{m}$ (Bombard Siege Encounter & Fleet Resupply):**
   * At $180\text{m}$, the **Bombard Siege Ship** ($180\text{ HP}$) launches heavy mortar bombardments.
   * Multiple $+2$ and $+4$ Fleet Gates ($210\text{m}, 250\text{m}$) allow players to max out follower skiff capacity.
4. **$270\text{m} - 320\text{m}$ (Inferno Gauntlet & Fortress Gates):**
   * Final 50-meter barrage featuring simultaneous Iron Gunners, Brimstone Rafts, and Thermal Geysers.
   * Multiplier gates ($\times 3$ Cannonballs) at $304\text{m}$ maximize firepower immediately before boss entry.

---

## 4. Boss Specification: Brimstone Siege Fortress

* **Boss Scene:** [`boss_siege_fortress.tscn`](file:///f:/projects/cove-corsair/src/gameplay/enemies/boss_siege_fortress.tscn) / [`boss_siege_fortress.gd`](file:///f:/projects/cove-corsair/src/gameplay/enemies/boss_siege_fortress.gd)
* **Total Health:** $800\text{ HP}$
* **Boss Archetype:** Floating Iron Fortress / Dreadnought Citadel
* **Destructible Sub-Components:**
  * **Port Mortar Turret:** $100\text{ HP}$
  * **Starboard Mortar Turret:** $100\text{ HP}$
  * **Central Magma Core Shield:** $150\text{ HP}$
* **Boss Behavior & Attack Phases:**
  * **Phase 1: Dual Mortar Siege (100% - 70% HP):**
    * The Fortress anchors across all 3 center lanes. Mortar turrets target player positions with red telegraph circles.
  * **Phase 2: Magma Vent Eruption (70% - 30% HP):**
    * Side magma vents open, creating lateral flame streams across lanes.
    * Summons escort Brimstone Rafts from rear flank positions.
  * **Phase 3: Core Meltdown (Below 30% HP):**
    * Central Magma Core becomes exposed and vulnerable to direct cannon fire ($2.5\times$ damage).
    * Screen-shake eruption effects and continuous mortar barrages until destroyed.
  * **Victory Condition:** Core destruction triggers grand victory sequence, campaign victory UI, and total doubloon summary.
