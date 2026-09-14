---
level_id: 45
level_title: "Level 45: Bonebeard's Throne (Boss Threat)"
biome_name: "brimstone_bastion"
base_scroll_speed: 12.0
completion_doubloon_reward: 1134
river_width_world: 12.0
resource_file: "res://src/data/resources/levels/level_45.tres"
---

# Level 45: Bonebeard's Throne - Technical Specification

> **Biome:** Volcanic Brimstone Bastion (Caldera Lava Channels)  
> **Course Distance:** 600.0m (12 Chunks @ 50m) | **Base Scroll Speed:** 13.0 m/s  
> **Level Clear Bonus:** 550 🪙 Doubloons | **Base Max Gold:** ~800 🪙 Doubloons (2X: ~1600 🪙)

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
* The corresponding Godot resource file [`level_45.tres`](file:///f:/projects/cove-corsair/src/data/resources/levels/level_45.tres) will be immediately updated and reflected in-game!

---

## 1. Level Identity & Environment Configuration

* **Level Resource:** [`level_45.tres`](file:///f:/projects/cove-corsair/src/data/resources/levels/level_45.tres)
* **Biome Identifier:** `brimstone` (Volcanic Brimstone Bastion (Caldera Lava Channels))
* **Target Course Distance:** 600.0m (12 Track Chunks @ 50.0m each)
* **Base Scroll Speed:** 13.0 m/s
* **River Width (World Units):** 12.0m (X between -6.0 and +6.0)
* **Minimum Viable Vessel:** Any T3
* **Recommended Vessel:** Ironclad T3 / Bombard T3
* **Environment Palette:**
  * **Water Surface Albedo:** Boiling Molten Magma `Color(0.35, 0.10, 0.08, 0.95)`
  * **Atmospheric Fog Color:** Smoky Ash & Crimson Ember `Color(0.45, 0.18, 0.12, 1.0)`
  * **Atmospheric Fog Density:** `0.02 - 0.025 (Volcanic ash fall and oppressive heat distortion)`

---

## 2. Lane Objects & Tactical Hazards

The river channel is populated with dynamic destructible obstacles, hazard emplacements, multiplier arches, and high-value loot chests:

| Entity Category | Entity Type | HP / Armor | Function, Mechanics & In-Game Yield |
| :--- | :--- | :--- | :--- |
| **Obstacle** | Wooden Barrels | 1 HP | Basic target practice barrel. Yields 1-3 doubloons upon destruction. |
| **Obstacle** | Fuse Barrels | 1-2 HP | Volatile red explosive barrels. Detonates in a 3.5m radius, clearing adjacent obstacles and dealing splash damage. |
| **Obstacle** | Rune Barrels / Chests | 2 HP | Mystical barrel dropping 3 coins (L1-4) or a high-value 50 doubloon chest (L5+). |
| **Obstacle** | Barricade Slat Wall | 20 HP | Fortified wooden/iron palisade blocking river lanes. Requires focused firepower or Bombard splash. |
| **Hazard** | Environmental Hazards | Indestructible | Thermal Geysers (Indestructible, periodic eruptive magma columns), Molten Whirlpools, Magma Sea Mines |
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
| **Specialist** | Iron Gunners (14-22 HP | High HP | Variable | Stage-specific combat vessel demanding tactical avoidance or focused burst. |

---

## 4. Boss Encounter & Combat Strengths

### **Boss Identity:** Captain Bone-Beard's Dreadnought

* **Boss Scene:** [`boss_bonebeard.tscn`](file:///f:/projects/cove-corsair/src/gameplay/enemies/boss_bonebeard.tscn)
* **Boss Script:** [`boss_bone_beard.gd`](file:///f:/projects/cove-corsair/src/gameplay/enemies/boss_bone_beard.gd)
* **Total Health:** **1200 HP**
* **Vessel Archetype:** Grandmaster Triple-Masted Steam Dreadnought Catamaran
* **Minion Escorts:** Summons 2 Skiffs in flanking lanes every 15s.

### Destructible Sub-Components & Hit Zones:
* **Twin Catamaran Hulls (150 HP each):** Reinforced with iron ram prows
* **Port & Starboard Heavy Carronades (80 HP each):** Fires rolling broadside volleys
* **Cursed Skull Fire Cannon (100 HP):** Fires homing flaming skulls
* **Steam Ram Engines:** Grants periodic burst charges forward

### Tactical Strengths:
* **Offensive Coverage:** Full-river broadside sweeps; devastating steam ram charges; rolling volleys combined with burning barrel drops; high resilience against all weapon types.
* **Defensive Resilience:** Armored hull mitigates unaligned cannon fire.
* **Escort Reinforcements:** Summons 2 Skiffs in flanking lanes every 15s.

### Vulnerabilities & Counter-Tactics:
* **Exploitable Openings:** Twin hull construction allows piercing cannonballs and Bombard mortars to hit both hulls simultaneously. Long reload pause after a full broadside volley creates critical DPS windows.
* **Weapon Synergy:** Bombard Skiff mortars bypass frontal armor; The Dinghy's responsive turning evades telegraphed mortar circles.

### Boss Attack Phases:
1. **Phase 1: Broadside Rolling Volley:** Fires sequenced cannon volleys across all 3 lanes, forcing precision slalom.
2. **Phase 2: Steam Ram Surges:** Telegraphed steam whistle followed by rapid ramming surge down center lane.
3. **Phase 3: Cursed Throne Barrage:** Rapid skull salvos and flaming barrel mine-drops; summons flanking skiffs.

---

## 5. Maximum Coin Yield & Economy Breakdown

Gold in **Level 45: Bonebeard's Throne** is earned through destructible barrels, enemy sinks, hidden hazard chests, pre-boss totems, and stage clear rewards:

| Reward Source | Yield Range | Drop Mechanics & Exact Breakdown |
| :--- | :--- | :--- |
| **Floating Doubloon Pickups** | ~15-35 coins | Loose channel coins collected along river paths and buffer runway. |
| **Destructible Barrels & Sinks** | ~25-50 coins | Wooden/fuse barrels and sunk enemy mobs (rowers, skiffs, turtle rafts). |
| **Gated Mine & Flank Chests** | ~1463 coins | High-value loot chests locked behind sea mine corridors (75 & 100 coins) and barricade flanks (50 coins). |
| **Pre-Boss Totems & Rune Chests** | ~100-200 coins | Destructible rune totems in pre-boss buffer and boss arena dropping 50-doubloon chests. |
| **TOTAL IN-RUN EARNINGS** | **~1613 🪙** | **Maximum gold gathered during course navigation and boss engagement.** |
| **Level Clear Bonus** | **550 🪙** | Guaranteed completion reward awarded on defeating the boss / dock arrival. |
| **BASE MAXIMUM TOTAL** | **~2163 🪙** | **Total doubloons banked without ad multiplier.** |
| **2X AD MULTIPLIER TOTAL** | **~4326 🪙** | **Total doubloons banked when tapping [ ✦ CLAIM 2X BONUS ] on Settlement Screen.** |

> 💡 **Why In-Run Coins Scale on Level 5+:**
> On Levels 1–4, `ChestSpawnMarker` chests remain dormant (`min_level = 5`), yielding ~40–60 in-run coins. From Level 5 onward, full hazard chests unlock (75–100 gold each), scaling in-run earnings to **~1613 coins** per run!

---

## 6. Chunk Progression & Wave Milestones

```
[0m] Warmup ──► [150m] Mine / Barricade ──► [300m] Fleet Gate ──► [550m] Pre-Boss Gauntlet & Runway ──► [600m] Captain Bone-Beard's Dreadnought
```

* **0m - 150m (Initial Deployment & Calibration):** Warmup channel with open water, initial barrel formations, and light Skeleton Rower encounters.
* **150m - 300m (Tactical Hazard Gate):** Dense mine gauntlet or barricade slat barrier forcing decisive steering, burst fire, and reward chest acquisition.
* **300m - 550m (Fleet Reinforcement & Climax Gauntlet):** Multiplier gates allow expanding follower vessel count to max broadside potential while navigating high-density barricades and charging enemy formations.
* **550m - 600m (Pre-Boss Approach & Buffer Runway):** 50-meter pre-boss approach featuring coin trails, warning skull totems, a final +1 Fleet Multiplier Gate, and a lone scout rower, preparing the player for arena transition.
* **600m (Boss Arena Engagement):** Camera locks to boss focus. Sinking **Captain Bone-Beard's Dreadnought** triggers the grand victory fanfare and opens the Settlement Screen.
