# Level 4: Smuggler's Nightmare - Technical Specification

**Smuggler's Nightmare** ramps up the campaign difficulty by revisiting the coastal archipelago under nightfall and heavy waters, featuring faster wave spawns, barricade choke points, high-speed Kamikaze Rafts, and an upgraded **Captain Ironjaw's Nightmare Flagship** boss.

---

## 1. Level Identity & Environment Configuration

* **Level Resource:** [`level_04_smugglers_nightmare.tres`](file:///f:/projects/cove-corsair/src/data/resources/levels/level_04_smugglers_nightmare.tres)
* **Biome Identifier:** `smugglers_run` (Coastal Archipelago - Night / Midnight Ocean)
* **Target Distance:** $250.0\text{m}$ (Scripted timeline from $0\text{m} \rightarrow 250\text{m}$, Boss encounter triggers at $250\text{m}$)
* **Base Scroll Speed:** $10.5\text{ m/s}$
* **River Width (World Units):** $12.0\text{m}$ ($X \in [-6.0, +6.0]$)
* **Starting Vessel:** [The Dinghy](file:///f:/projects/cove-corsair/src/data/resources/user_vessels/dinghy_ship.tres) (1 Starting Hull Point)
* **Environment Palette:**
  * **Water Albedo:** Deep Midnight Ocean Blue `Color(0.04, 0.35, 0.55, 0.92)`
  * **Fog Color:** Dark Storm Blue `Color(0.18, 0.28, 0.42, 1.0)`
  * **Fog Density:** `0.008` (Light atmospheric night mist)

---

## 2. Entity Roster & Mechanics

| Entity Class | Type Name | HP / Profile | Behavior & Mechanics |
| :--- | :--- | :--- | :--- |
| **Obstacle** | Wooden / Fuse / Rune Barrels | $4\text{-}6\text{ HP}$ | Hardened obstacles requiring rapid concentrated fire. |
| **Obstacle** | Barricade Wall | $3\text{ HP}$ per segment | Interlocking wooden barricades spanning lanes with narrow gap passages. |
| **Hazard** | Sea Mine | Indestructible / Explosive | Floating explosive hazard; triggers lane splash on contact. |
| **Hazard** | Reef Outcrop | Indestructible | Environmental rock formations constricting channel navigation. |
| **Mob** | Skeleton Rowers | $5\text{-}7\text{ HP}$ ($2.2\text{-}2.8\text{ m/s}$) | Accelerated forward enemy rowers. |
| **Mob** | Raider Skiffs | $12\text{-}14\text{ HP}$ ($3.4\text{-}3.6\text{ m/s}$) | Aggressive hostile skiffs with increased HP profiles. |
| **Mob** | Kamikaze Rafts | $14\text{-}16\text{ HP}$ ($7.5\text{-}7.8\text{ m/s}$) | Ultra-fast explosive rafts charging down lanes at high speeds. |
| **Gate** | Fleet & Multiplier Gate | Translucent Arch | Fleet Gates ($+1, +2$ Fleet Members) positioned before major enemy waves. |

---

## 3. Timeline Wave Structure

The level features 27 scripted timeline events structured into four high-speed tactical phases across $250\text{m}$:

```
[0m] Start ───► [50m] Fleet Gate (+2) ───► [145m] Barricade Gauntlet ───► [178m] Pre-Boss Fleet Gate (+2) ───► [250m] Boss Battle
```

### Phase Breakdown:
1. **$0\text{m} - 50\text{m}$ (Night Incursion & Initial Ambushes):**
   * Early obstacle clusters paired with faster Skeleton Rowers ($5\text{ HP}, 2.2\text{ m/s}$).
   * Reef Hazard at $22\text{m}$ and Sea Mine at $28\text{m}$ force early lane switching.
   * $+2$ Fleet Gate at $50\text{m}$ mobilizes broadside support early.
2. **$50\text{m} - 140\text{m}$ (Kamikaze Waves & Skiff Attacks):**
   * Raider Skiffs ($12\text{ HP}$) paired with high-speed Kamikaze Rafts ($14\text{ HP}, 7.5\text{ m/s}$) at $74\text{m}$.
   * $+1$ Fleet Gate at $100\text{m}$ provides recovery after dense obstacle & mine encounters.
3. **$140\text{m} - 200\text{m}$ (Barricade Bottleneck & Raider Charge):**
   * At $145\text{m}$, a 4-point **Barricade Wall** ($3\text{ HP}$) blocks the channel with a single lane gap.
   * Followed immediately by Kamikaze Rafts ($16\text{ HP}, 7.8\text{ m/s}$) and dual Raider Skiffs.
   * $+2$ Fleet Gate at $178\text{m}$ maxes out fleet capacity.
4. **$200\text{m} - 250\text{m}$ (Nightmare Flagship Approach):**
   * Heavy fuse obstacles ($6\text{ HP}$), sea mines, and final skeleton rower wave ($7\text{ HP}$).
   * Boss warning banner at $236\text{m}$ ("NIGHTMARE FLAGSHIP APPROACHING!").

---

## 4. Boss Specification: Nightmare Flagship (Captain Ironjaw)

* **Boss Scene:** [`boss_war_barge.tscn`](file:///f:/projects/cove-corsair/src/gameplay/enemies/boss_war_barge.tscn) / [`boss_war_barge.gd`](file:///f:/projects/cove-corsair/src/gameplay/enemies/boss_war_barge.gd)
* **Total Health:** $300\text{ HP}$ (Upgraded from Level 1's $220\text{ HP}$)
* **Boss Archetype:** Heavy Iron-Plated War Barge
* **Attack Behavior & Pacing:**
  * Higher health pool ($300\text{ HP}$) requiring sustained salvo fire.
  * Rapid swivel gun mortar volleys targeting active player lane positions.
  * Boiler core exposure windows reduced, demanding precise timing during overheat phases.
