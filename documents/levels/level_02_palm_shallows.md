---
level_id: 2
level_title: "Level 2: Palm Shallows"
biome_name: "tropical"
base_scroll_speed: 6.6
completion_doubloon_reward: 58
river_width_world: 12.0
resource_file: "res://src/data/resources/levels/level_02.tres"
---

# Level 2: Palm Shallows - Technical Specification

> **Biome:** Tropical Lagoon / Archipelago  
> **Course Distance:** 300.0m (6 Chunks @ 50m) | **Base Scroll Speed:** 7.0 m/s  
> **Level Clear Bonus:** 65 🪙 Doubloons | **Base Max Gold:** ~100 🪙 Doubloons (2X: ~200 🪙)

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
* The corresponding Godot resource file [`level_02.tres`](file:///f:/projects/cove-corsair/src/data/resources/levels/level_02.tres) will be immediately updated and reflected in-game!

---

## 1. Level Identity & Environment Configuration

* **Level Resource:** [`level_02.tres`](file:///f:/projects/cove-corsair/src/data/resources/levels/level_02.tres)
* **Biome Identifier:** `tropical` (Tropical Lagoon / Archipelago)
* **Target Course Distance:** 300.0m (6 Track Chunks @ 50.0m each)
* **Base Scroll Speed:** 7.0 m/s
* **River Width (World Units):** 12.0m (X between -6.0 and +6.0)
* **Minimum Viable Vessel:** Dinghy T1
* **Recommended Vessel:** Dinghy T1
* **Environment Palette:**
  * **Water Surface Albedo:** Clear Turquoise Cyan `Color(0.08, 0.58, 0.82, 0.88)`
  * **Atmospheric Fog Color:** Tropical Sky Blue `Color(0.48, 0.76, 0.94, 1.0)`
  * **Atmospheric Fog Density:** `0.0 (Crystal clear open daylight)`

---

## 2. Lane Objects & Tactical Hazards

The river channel is populated with dynamic destructible obstacles, hazard emplacements, multiplier arches, and high-value loot chests:

| Entity Category | Entity Type | HP / Armor | Function, Mechanics & In-Game Yield |
| :--- | :--- | :--- | :--- |
| **Obstacle** | Wooden Barrels | 1 HP | Basic target practice barrel. Yields 1-3 doubloons upon destruction. |
| **Obstacle** | Fuse Barrels | 1-2 HP | Volatile red explosive barrels. Detonates in a 3.5m radius, clearing adjacent obstacles and dealing splash damage. |
| **Obstacle** | Rune Barrels / Chests | 2 HP | Mystical barrel dropping 3 coins (L1-4) or a high-value 50 doubloon chest (L5+). |
| **Obstacle** | Barricade Slat Wall | 2 HP | Fortified wooden/iron palisade blocking river lanes. Requires focused firepower or Bombard splash. |
| **Hazard** | Environmental Hazards | Indestructible | Indestructible Reef Outcrops, Spiked Sea Mines (1 HP, contact detonation), Shallows Sandbars |
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
| **Specialist** | Skeleton Rowers (2 HP | High HP | Variable | Stage-specific combat vessel demanding tactical avoidance or focused burst. |

---

## 4. Boss Encounter & Combat Strengths

### **Boss Identity:** Ironjaw Skirmish Flagship (**Raider Sloop** (HP 30, slow forward cannon))

* **Boss Scene:** [`boss_war_barge.tscn`](file:///f:/projects/cove-corsair/src/gameplay/enemies/boss_war_barge.tscn)
* **Boss Script:** [`boss_war_barge.gd`](file:///f:/projects/cove-corsair/src/gameplay/enemies/boss_war_barge.gd)
* **Total Health:** **40 HP**
* **Vessel Archetype:** Armored Pirate Cutter / Heavy Steam War-Barge
* **Minion Escorts:** No minion summons; focused 1v1 duel.

### Destructible Sub-Components & Hit Zones:
* **Port Swivel Turret (30 HP):** Fires telegraphed mortar volleys into player lanes
* **Starboard Swivel Turret (30 HP):** Fires alternating grape-shot cannonballs
* **Frontal Ramming Prow / Armor Plate (40 HP):** Absorbs forward cannon fire
* **Exposed Boiler Core (Critical Hit Zone):** Takes 2.0x damage during steam vents

### Tactical Strengths:
* **Offensive Coverage:** Heavy hull armor that deflects unaligned fire; synchronized broadside salvos requiring quick lane shifts; high ramming damage if player vessel is pinned.
* **Defensive Resilience:** Armored hull mitigates unaligned cannon fire.
* **Escort Reinforcements:** No minion summons; focused 1v1 duel.

### Vulnerabilities & Counter-Tactics:
* **Exploitable Openings:** Exposed boiler vents periodically release steam after turrets are disabled, exposing critical core for massive double damage. Slow turn rate allows agile Skiffs to flank safely.
* **Weapon Synergy:** Bombard Skiff mortars bypass frontal armor; The Dinghy's responsive turning evades telegraphed mortar circles.

### Boss Attack Phases:
1. **Phase 1: Cruiser Salvo:** Alternates port and starboard cannonballs while deploying forward mines.
2. **Phase 2: Boiler Venting:** Under 50% HP or upon loss of side turrets, vents steam and charges forward.
3. **Phase 3: Desperation Barrage:** Continuous grape-shot spray with increased fire rate until sunk.

---

## 5. Maximum Coin Yield & Economy Breakdown

Gold in **Level 2: Palm Shallows** is earned through destructible barrels, enemy sinks, hidden hazard chests, pre-boss totems, and stage clear rewards:

| Reward Source | Yield Range | Drop Mechanics & Exact Breakdown |
| :--- | :--- | :--- |
| **Floating Doubloon Pickups** | ~15-35 coins | Loose channel coins collected along river paths and buffer runway. |
| **Destructible Barrels & Sinks** | ~25-50 coins | Wooden/fuse barrels and sunk enemy mobs (rowers, skiffs, turtle rafts). |
| **Gated Mine & Flank Chests** | 0 coins (L1-4: Chests locked) | High-value loot chests locked behind sea mine corridors (75 & 100 coins) and barricade flanks (50 coins). |
| **Pre-Boss Totems & Rune Chests** | ~6-12 coins | Destructible rune totems in pre-boss buffer and boss arena dropping 50-doubloon chests. |
| **TOTAL IN-RUN EARNINGS** | **~53 🪙** | **Maximum gold gathered during course navigation and boss engagement.** |
| **Level Clear Bonus** | **65 🪙** | Guaranteed completion reward awarded on defeating the boss / dock arrival. |
| **BASE MAXIMUM TOTAL** | **~118 🪙** | **Total doubloons banked without ad multiplier.** |
| **2X AD MULTIPLIER TOTAL** | **~236 🪙** | **Total doubloons banked when tapping [ ✦ CLAIM 2X BONUS ] on Settlement Screen.** |

> 💡 **Why In-Run Coins Scale on Level 5+:**
> On Levels 1–4, `ChestSpawnMarker` chests remain dormant (`min_level = 5`), yielding ~40–60 in-run coins. From Level 5 onward, full hazard chests unlock (75–100 gold each), scaling in-run earnings to **~53 coins** per run!

---

## 6. Chunk Progression & Wave Milestones

```
[0m] Warmup ──► [75m] Mine / Barricade ──► [150m] Fleet Gate ──► [250m] Pre-Boss Gauntlet & Runway ──► [300m] Ironjaw Skirmish Flagship
```

* **0m - 75m (Initial Deployment & Calibration):** Warmup channel with open water, initial barrel formations, and light Skeleton Rower encounters.
* **75m - 150m (Tactical Hazard Gate):** Dense mine gauntlet or barricade slat barrier forcing decisive steering, burst fire, and reward chest acquisition.
* **150m - 250m (Fleet Reinforcement & Climax Gauntlet):** Multiplier gates allow expanding follower vessel count to max broadside potential while navigating high-density barricades and charging enemy formations.
* **250m - 300m (Pre-Boss Approach & Buffer Runway):** 50-meter pre-boss approach featuring coin trails, warning skull totems, a final +1 Fleet Multiplier Gate, and a lone scout rower, preparing the player for arena transition.
* **300m (Boss Arena Engagement):** Camera locks to boss focus. Sinking **Ironjaw Skirmish Flagship (**Raider Sloop** (HP 30, slow forward cannon))** triggers the grand victory fanfare and opens the Settlement Screen.
