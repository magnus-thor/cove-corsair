---
level_id: 25
level_title: "Level 25: Phantom Trench (Boss Threat)"
biome_name: "bayou"
base_scroll_speed: 9.8
completion_doubloon_reward: 684
river_width_world: 12.0
resource_file: "res://src/data/resources/levels/level_25.tres"
---

# Level 25: Phantom Trench - Technical Specification

> **Biome:** Black Tide Bayou (Murky Swamp & Cypress Mangroves)  
> **Course Distance:** 450.0m (9 Chunks @ 50m) | **Base Scroll Speed:** 10.8 m/s  
> **Level Clear Bonus:** 240 🪙 Doubloons | **Base Max Gold:** ~375 🪙 Doubloons (2X: ~750 🪙)

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
* The corresponding Godot resource file [`level_25.tres`](file:///f:/projects/cove-corsair/src/data/resources/levels/level_25.tres) will be immediately updated and reflected in-game!

---

## 1. Level Identity & Environment Configuration

* **Level Resource:** [`level_25.tres`](file:///f:/projects/cove-corsair/src/data/resources/levels/level_25.tres)
* **Biome Identifier:** `bayou` (Black Tide Bayou (Murky Swamp & Cypress Mangroves))
* **Target Course Distance:** 450.0m (9 Track Chunks @ 50.0m each)
* **Base Scroll Speed:** 10.8 m/s
* **River Width (World Units):** 12.0m (X between -6.0 and +6.0)
* **Minimum Viable Vessel:** Sloop T3
* **Recommended Vessel:** Sloop T3 / Bombard T2
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
| **Obstacle** | Barricade Slat Wall | 12 HP | Fortified wooden/iron palisade blocking river lanes. Requires focused firepower or Bombard splash. |
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

### **Boss Identity:** The Phantom Dredge (Spectral Galleon)

* **Boss Scene:** [`boss_phantom_dredge.tscn`](file:///f:/projects/cove-corsair/src/gameplay/enemies/boss_phantom_dredge.tscn)
* **Boss Script:** [`boss_phantom_dredge.gd`](file:///f:/projects/cove-corsair/src/gameplay/enemies/boss_phantom_dredge.gd)
* **Total Health:** **320 HP**
* **Vessel Archetype:** Spectral Bayou Dreadnought / Ghost Paddlewheel
* **Minion Escorts:** Spawns at most 1 Ghost every 14s with strict hard cap to prevent player overwhelm.

### Destructible Sub-Components & Hit Zones:
* **Spectral Paddlewheels (40 HP each):** Propels the ship and kicks up toxic wake waves
* **Ghost Lantern Array (30 HP):** Channels tracking ectoplasm orbs
* **Phantom Hull Shell (Spectral Shield):** Intermittent phase-shifting immunity

### Tactical Strengths:
* **Offensive Coverage:** Ectoplasm Geyser mortar drops green telegraph circles (1.6s warning) across multiple lanes; tracking ghost fireballs that pursue the player until shot down; brief phase invisibility.
* **Defensive Resilience:** Armored hull mitigates unaligned cannon fire.
* **Escort Reinforcements:** Spawns at most 1 Ghost every 14s with strict hard cap to prevent player overwhelm.

### Vulnerabilities & Counter-Tactics:
* **Exploitable Openings:** Telegraphed green circles give 1.6s warning to dodge into safe lanes. Ghost tracking orbs have only 1 HP and can be intercepted by forward fire. Vulnerable to Bombard AoE splash.
* **Weapon Synergy:** Bombard Skiff mortars bypass frontal armor; The Dinghy's responsive turning evades telegraphed mortar circles.

### Boss Attack Phases:
1. **Phase 1: Spectral Torment:** Launches alternating green geyser mortars and single tracking orbs.
2. **Phase 2: Submergence & Ambush:** Dips beneath murky waters, emerging with sudden high-speed paddlewheel wake waves.
3. **Phase 3: Ectoplasm Frenzy:** Fires triple geyser clusters; ghost fire rate increases by 40%.

---

## 5. Maximum Coin Yield & Economy Breakdown

Gold in **Level 25: Phantom Trench** is earned through destructible barrels, enemy sinks, hidden hazard chests, pre-boss totems, and stage clear rewards:

| Reward Source | Yield Range | Drop Mechanics & Exact Breakdown |
| :--- | :--- | :--- |
| **Floating Doubloon Pickups** | ~15-35 coins | Loose channel coins collected along river paths and buffer runway. |
| **Destructible Barrels & Sinks** | ~25-50 coins | Wooden/fuse barrels and sunk enemy mobs (rowers, skiffs, turtle rafts). |
| **Gated Mine & Flank Chests** | ~997 coins | High-value loot chests locked behind sea mine corridors (75 & 100 coins) and barricade flanks (50 coins). |
| **Pre-Boss Totems & Rune Chests** | ~100-200 coins | Destructible rune totems in pre-boss buffer and boss arena dropping 50-doubloon chests. |
| **TOTAL IN-RUN EARNINGS** | **~1147 🪙** | **Maximum gold gathered during course navigation and boss engagement.** |
| **Level Clear Bonus** | **240 🪙** | Guaranteed completion reward awarded on defeating the boss / dock arrival. |
| **BASE MAXIMUM TOTAL** | **~1387 🪙** | **Total doubloons banked without ad multiplier.** |
| **2X AD MULTIPLIER TOTAL** | **~2774 🪙** | **Total doubloons banked when tapping [ ✦ CLAIM 2X BONUS ] on Settlement Screen.** |

> 💡 **Why In-Run Coins Scale on Level 5+:**
> On Levels 1–4, `ChestSpawnMarker` chests remain dormant (`min_level = 5`), yielding ~40–60 in-run coins. From Level 5 onward, full hazard chests unlock (75–100 gold each), scaling in-run earnings to **~1147 coins** per run!

---

## 6. Chunk Progression & Wave Milestones

```
[0m] Warmup ──► [112m] Mine / Barricade ──► [225m] Fleet Gate ──► [400m] Pre-Boss Gauntlet & Runway ──► [450m] The Phantom Dredge
```

* **0m - 112m (Initial Deployment & Calibration):** Warmup channel with open water, initial barrel formations, and light Skeleton Rower encounters.
* **112m - 225m (Tactical Hazard Gate):** Dense mine gauntlet or barricade slat barrier forcing decisive steering, burst fire, and reward chest acquisition.
* **225m - 400m (Fleet Reinforcement & Climax Gauntlet):** Multiplier gates allow expanding follower vessel count to max broadside potential while navigating high-density barricades and charging enemy formations.
* **400m - 450m (Pre-Boss Approach & Buffer Runway):** 50-meter pre-boss approach featuring coin trails, warning skull totems, a final +1 Fleet Multiplier Gate, and a lone scout rower, preparing the player for arena transition.
* **450m (Boss Arena Engagement):** Camera locks to boss focus. Sinking **The Phantom Dredge (Spectral Galleon)** triggers the grand victory fanfare and opens the Settlement Screen.
