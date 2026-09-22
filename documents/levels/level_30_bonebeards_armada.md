---
level_id: 30
level_title: "Level 30: Bonebeard's Armada (Boss Threat)"
biome_name: "bayou"
base_scroll_speed: 10.3
completion_doubloon_reward: 796
river_width_world: 12.0
resource_file: "res://src/data/resources/levels/level_30.tres"
---

# Level 30: Bonebeard's Armada - Technical Specification

> **Biome:** Black Tide Bayou (Murky Swamp & Cypress Mangroves)  
> **Course Distance:** 500.0m (10 Chunks @ 50m) | **Base Scroll Speed:** 11.5 m/s  
> **Level Clear Bonus:** 290 🪙 Doubloons | **Base Max Gold:** ~450 🪙 Doubloons (2X: ~900 🪙)

---

## 🛠️ Level Tuning & Modding Guide

This document is bidirectionally linked to the game's runtime resources. You can edit this level's configuration directly in the header block above or via the parameters below.

* **To change maximum coins or clear reward:** Change `completion_doubloon_reward` in the YAML header above.
* **To change level scroll speed:** Change `base_scroll_speed` in the YAML header above.
* **To apply changes directly to the game:** Run the synchronization script:
  ```bash
  python src/tools/sync_level_docs.py
  ```
  *(or double-click `sync_levels.bat` in the project root, or execute `godot --headless --script src/tools/sync_level_docs.gd`)*
* The corresponding Godot resource file [`level_30.tres`](file:///f:/projects/cove-corsair/src/data/resources/levels/level_30.tres) will be immediately updated and reflected in-game!

---

## 1. Level Identity & Environment Configuration

* **Level Resource:** [`level_30.tres`](file:///f:/projects/cove-corsair/src/data/resources/levels/level_30.tres)
* **Biome Identifier:** `bayou` (Black Tide Bayou (Murky Swamp & Cypress Mangroves))
* **Target Course Distance:** 500.0m (10 Track Chunks @ 50.0m each)
* **Base Scroll Speed:** 11.5 m/s
* **River Width (World Units):** 12.0m (X between -6.0 and +6.0)
* **Minimum Viable Vessel:** Ironclad T2
* **Recommended Vessel:** Bombard T3 / Ironclad T2
* **Environment Palette:**
  * **Water Surface Albedo:** Murky Swamp Green `Color(0.12, 0.25, 0.18, 0.92)`
  * **Atmospheric Fog Color:** Deep Marsh Moss `Color(0.22, 0.35, 0.28, 1.0)`
  * **Atmospheric Fog Density:** `0.015 - 0.022 (Dense swamp haze reducing long-range visibility)`

---

## 2. Lane Objects & Tactical Hazards

The river channel is populated with dynamic destructible obstacles, hazard emplacements, multiplier arches, and high-value loot chests:

| Entity Category | Entity Type | HP / Armor | Function, Mechanics & In-Game Yield |
| :--- | :--- | :--- | :--- |
| **Obstacle** | Wooden Barrels | 1 HP | Basic target practice barrel. Yields 1-3 doubloons upon destruction. |
| **Obstacle** | Fuse Barrels | 1-2 HP | Volatile red explosive barrels. Detonates in a 3.5m radius, clearing adjacent obstacles and dealing splash damage. |
| **Obstacle** | Rune Barrels / Chests | 2 HP | Mystical barrel dropping 3 coins (L1-4) or a high-value 50 doubloon chest (L5+). |
| **Obstacle** | Barricade Slat Wall | 14 HP | Fortified wooden/iron palisade blocking river lanes. Requires focused firepower or Bombard splash. |
| **Hazard** | Environmental Hazards | Indestructible | Biogas Pods (2 HP, toxic spore detonation & lingering smog clouds), Cypress Stumps, Submerged Sea Mines |
| **Multiplier Gate** | Fleet Gate | Translucent Arch | Passes vessel through to add +1 or +2 follower skiffs, expanding fleet broadside firepower. |
| **Multiplier Gate** | Cannonball Multiplier | Glowing Portal | Multiplies shot count (+2, x2, x3) to shred oncoming high-HP barricade clusters. |
| **Collectible** | Floating Doubloons | Pick-up | Gold coins floating in river channels (1 coin each). Magnetized by active fleet prows. |
| **Collectible** | Gated Hazard Chests | Pick-up | High-value chests spawned in mine gauntlets (75 & 100 coins) and barricade flanks (50 coins). |

---

## 3. Enemy Vessels & Combat Mechanics

Hostile craft deployed throughout this stage's chunks:

| Vessel Class | Type Name | HP / Profile | Speed | Behavior, Attack Patterns & Yield |
| :--- | :--- | :--- | :--- | :--- |
| **Light Craft** | Skeleton Rowers | 2 HP | 1.5 m/s | Slow forward advance; perfect calibration target. Drops 2 doubloons upon sinking. |
| **Raider Skiff** | Hostile Skiff / Grave Skiff | 4-12 HP | 2.5-3.5 m/s | Agile raider craft with lateral strafing patterns to disrupt firing lanes. Drops 2-4 doubloons. |
| **Heavy Craft** | Turtle Raft / Tide Cutter | 6-18 HP | 1.5-2.5 m/s | Armor-plated barge capable of ramming. Demands sustained stream DPS. Drops 4-6 doubloons. |
| **Fast Striker** | Kamikaze / Brimstone Raft | 5-30 HP | 6.0-6.5 m/s | High-speed ramming craft charging directly down river. Detonates on impact. Drops 3-5 doubloons. |
| **Specialist** | Grave Skiffs (6-12 HP | High HP | Variable | Stage-specific combat vessel demanding tactical avoidance or focused burst. |

---

## 4. Boss Encounter & Combat Strengths

### **Boss Identity:** Captain Bone-Beard's Dreadnought

* **Boss Scene:** [`boss_bonebeard.tscn`](file:///f:/projects/cove-corsair/src/gameplay/enemies/boss_bonebeard.tscn)
* **Boss Script:** [`boss_bone_beard.gd`](file:///f:/projects/cove-corsair/src/gameplay/enemies/boss_bone_beard.gd)
* **Total Health:** **750 HP**
* **Vessel Archetype:** Grandmaster Triple-Masted Steam Dreadnought Catamaran
* **Minion Escorts:** Summons 2 Rowers in flanking lanes every 15s.

### Destructible Sub-Components & Hit Zones:
* **Twin Catamaran Hulls (150 HP each):** Reinforced with iron ram prows
* **Port & Starboard Heavy Carronades (80 HP each):** Fires rolling broadside volleys
* **Cursed Skull Fire Cannon (100 HP):** Fires homing flaming skulls
* **Steam Ram Engines:** Grants periodic burst charges forward

### Tactical Strengths:
* **Offensive Coverage:** Full-river broadside sweeps; devastating steam ram charges; rolling volleys combined with burning barrel drops; high resilience against all weapon types.
* **Defensive Resilience:** Armored hull mitigates unaligned cannon fire.
* **Escort Reinforcements:** Summons 2 Rowers in flanking lanes every 15s.

### Vulnerabilities & Counter-Tactics:
* **Exploitable Openings:** Twin hull construction allows piercing cannonballs and Bombard mortars to hit both hulls simultaneously. Long reload pause after a full broadside volley creates critical DPS windows.
* **Weapon Synergy:** Bombard Skiff mortars bypass frontal armor; The Dinghy's responsive turning evades telegraphed mortar circles.

### Boss Attack Phases:
1. **Phase 1: Broadside Rolling Volley:** Fires sequenced cannon volleys across all 3 lanes, forcing precision slalom.
2. **Phase 2: Steam Ram Surges:** Telegraphed steam whistle followed by rapid ramming surge down center lane.
3. **Phase 3: Cursed Throne Barrage:** Rapid skull salvos and flaming barrel mine-drops; summons flanking skiffs.

---

## 5. Maximum Coin Yield & Economy Breakdown

Gold in **Level 30: Bonebeard's Armada** is earned through destructible barrels, enemy sinks, hidden hazard chests, pre-boss totems, and stage clear rewards:

| Reward Source | Yield Range | Drop Mechanics & Exact Breakdown |
| :--- | :--- | :--- |
| **Floating Doubloon Pickups** | ~15-35 coins | Loose channel coins collected along river paths and buffer runway. |
| **Destructible Barrels & Sinks** | ~25-50 coins | Wooden/fuse barrels and sunk enemy mobs (rowers, skiffs, turtle rafts). |
| **Gated Mine & Flank Chests** | ~963 coins | High-value loot chests locked behind sea mine corridors (75 & 100 coins) and barricade flanks (50 coins). |
| **Pre-Boss Totems & Rune Chests** | ~100-200 coins | Destructible rune totems in pre-boss buffer and boss arena dropping 50-doubloon chests. |
| **TOTAL IN-RUN EARNINGS** | **~1113 🪙** | **Maximum gold gathered during course navigation and boss engagement.** |
| **Level Clear Bonus** | **290 🪙** | Guaranteed completion reward awarded on defeating the boss / dock arrival. |
| **BASE MAXIMUM TOTAL** | **~1403 🪙** | **Total doubloons banked without ad multiplier.** |
| **2X AD MULTIPLIER TOTAL** | **~2806 🪙** | **Total doubloons banked when tapping [ ✦ CLAIM 2X BONUS ] on Settlement Screen.** |

> 💡 **Why In-Run Coins Scale on Level 5+:**
> On Levels 1–4, `ChestSpawnMarker` chests remain dormant (`min_level = 5`), yielding ~40–60 in-run coins. From Level 5 onward, full hazard chests unlock (75–100 gold each), scaling in-run earnings to **~1113 coins** per run!

---

## 6. Chunk Progression & Wave Milestones

```
[0m] Warmup ──► [125m] Mine / Barricade ──► [250m] Fleet Gate ──► [450m] Pre-Boss Gauntlet & Runway ──► [500m] Captain Bone-Beard's Dreadnought
```

* **0m - 125m (Initial Deployment & Calibration):** Warmup channel with open water, initial barrel formations, and light Skeleton Rower encounters.
* **125m - 250m (Tactical Hazard Gate):** Dense mine gauntlet or barricade slat barrier forcing decisive steering, burst fire, and reward chest acquisition.
* **250m - 450m (Fleet Reinforcement & Climax Gauntlet):** Multiplier gates allow expanding follower vessel count to max broadside potential while navigating high-density barricades and charging enemy formations.
* **450m - 500m (Pre-Boss Approach & Buffer Runway):** 50-meter pre-boss approach featuring coin trails, warning skull totems, a final +1 Fleet Multiplier Gate, and a lone scout rower, preparing the player for arena transition.
* **500m (Boss Arena Engagement):** Camera locks to boss focus. Sinking **Captain Bone-Beard's Dreadnought** triggers the grand victory fanfare and opens the Settlement Screen.
