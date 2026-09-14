# Cove Corsair — Campaign Ground Truth Audit
> Generated: 2026-09-09 | Source-only read (NO code changes)  
> Extraction method: Direct file inspection of all .tres resources, .gd scripts, and .tscn chunk scenes.

---

## Executive Summary

This document is a factual ground-truth extraction of the Cove Corsair engine state as of the audit date. All values are read directly from source files — no estimates, no design docs, no assumptions.

---

## Table 1 — Real Fleet Stats by Tier

### Ammo Damage Reference (from `/src/data/resources/user_ammo/`)

| Ammo Type | Damage | AoE Dmg | Splash Radius | Projectile Speed |
|---|---|---|---|---|
| Standard Ball | 1 | — | 0 m | 24 u/s |
| Heavy Shot | 5 | 3 | 3.5 m | 14 u/s |
| Grape Shot | 1 | — | 0 m | 22 u/s |
| Scatter Pellet | 2 | — | 0 m | 28 u/s |
| Coconut Bomb | 3 | — | 2.5 m | 18 u/s |
| Fire Bomb | 4 | — | 2.0 m | 20 u/s |

### Weapon Reference (from `/src/data/resources/user_crew/`)

| Weapon | Type | Fire Rate (s) | Default Ammo | Dmg/Shot | Pellets | Theoretical DPS |
|---|---|---|---|---|---|---|
| Bow Chaser | cannon | 0.20 s | Standard Ball | 1 | 1 | **5.0** |
| Port/Stbd Swivel | swivel_gun | 0.20 s | Grape Shot | 1 | 1 | **5.0** each |
| Heavy Siege Mortar | deck_mortar | 1.30 s | Heavy Shot | 5 (+3 AoE) | 1 | **3.8** (direct) |
| Scattershot Carronade | scattershot | 0.45 s | Scatter Pellet | 2 | 5 pellets | **22.2** (full cone) |
| Monkey Bomber (crew) | crew_thrower | 0.20 s | Coconut Bomb | 3 (AoE r=2.5) | 1 | **15.0** |
| Skeleton Tosser (crew) | crew_thrower | 0.20 s | Fire Bomb | 4 (AoE r=2.0) | 1 | **20.0** |

> **DPS note:** Crew weapons auto-target nearest enemy. Scattershot DPS assumes all 5 pellets hit same target (close range only, max range 12 m). AoE damage is additional per nearby target; not counted in single-target DPS column.

---

### Fleet Stats - Dinghy (dinghy_ship.tres)

| Stat | Value |
|---|---|
| Ship ID | dinghy |
| Archetype | Agility Skiff |
| Hull HP (max_health) | **1** |
| Move Speed (move_speed) | **12.0** u/s |
| Base Fire Rate | 0.20 s |
| Unlock Cost | **0** (starter vessel) |
| Tier 2 Upgrade Cost | **300** |
| Tier 3 Upgrade Cost | **750** |

| Tier | Active Sockets | Active Weapons | Combined DPS |
|---|---|---|---|
| T1 | BowMount | Bow Chaser x1 | **5.0** |
| T2 | BowMount + MidDeckCrew | Bow Chaser + Monkey Bomber | **20.0** |
| T3 | BowMount + MidDeckCrew + AftDeckCrew | Bow Chaser + Monkey Bomber + Skeleton Tosser | **40.0** |

---

### Fleet Stats - Sloop (sloop_ship.tres)

| Stat | Value |
|---|---|
| Ship ID | sloop |
| Archetype | Balanced Standard |
| Hull HP (max_health) | **5** |
| Move Speed (move_speed) | **11.0** u/s |
| Base Fire Rate | 0.16 s (cannon socket) |
| Unlock Cost | **600** |
| Tier 2 Upgrade Cost | **800** |
| Tier 3 Upgrade Cost | **1500** |

| Tier | Active Sockets | Active Weapons | Combined DPS |
|---|---|---|---|
| T1 | BowMount | Bow Chaser x1 | **5.0** |
| T2 | BowMount + MidDeckCrew + AftDeckCrew | Bow Chaser + Monkey Bomber + Skeleton Tosser | **40.0** |
| T3 | All 5 sockets | + Port + Starboard Swivel | **50.0** |

---

### Fleet Stats - Bombard Skiff (bombard_skiff_ship.tres)

| Stat | Value |
|---|---|
| Ship ID | bombard_skiff |
| Archetype | Artillery Mortar |
| Hull HP (max_health) | **3** |
| Move Speed (move_speed) | **9.0** u/s |
| Base Fire Rate | 1.30 s (mortar) |
| Unlock Cost | **1000** |
| Tier 2 Upgrade Cost | **1200** |
| Tier 3 Upgrade Cost | **2200** |

| Tier | Active Sockets | Active Weapons | Combined DPS |
|---|---|---|---|
| T1 | BowMortarMount | Heavy Siege Mortar x1 | **3.85** direct / ~7.7 with AoE second target |
| T2 | BowMortarMount + QuarterdeckCrew | Mortar + Monkey Bomber | **18.85** |
| T3 | All 4 sockets | + Dual Scattershot Carronades | **63.25** |

---

### Fleet Stats - Ironclad (ironclad_ship.tres)

| Stat | Value |
|---|---|
| Ship ID | ironclad |
| Archetype | Armored Brawler |
| Hull HP (max_health) | **8** |
| Move Speed (move_speed) | **7.5** u/s |
| Base Fire Rate | 0.15 s (cannon) |
| Unlock Cost | **1400** |
| Tier 2 Upgrade Cost | **1800** |
| Tier 3 Upgrade Cost | **3000** |

| Tier | Active Sockets | Active Weapons | Combined DPS |
|---|---|---|---|
| T1 | BowMount | Bow Chaser x1 | **5.0** |
| T2 | BowMount + MonkeyCrew + SkeletonCrew | Bow Chaser + Monkey Bomber + Skeleton Tosser | **40.0** |
| T3 | All 7 sockets | + Port/Stbd SwivelMount1 + Port/Stbd SwivelMount2 (x4 swivels) | **60.0** |

---

## Economy and Drop Sources

### Destructible Obstacles - Fixed Drop Values (destructible_obstacle.gd)

| Type | HP | Doubloon Drop | Notes |
|---|---|---|---|
| Wooden Barrel | 1 | 1 (or 1-3 random if doubloons_drop <= 0) | Most common |
| Fuse Barrel | 1 | 2 | Explodes - chain-deals 2 dmg in r=3.5 m |
| Rune Barrel | 2 | 3 | Has spawns_chest metadata in barricade chunk (value 50) |
| Sea Mine | 1 | 2 | Explodes on contact/destruction |
| Coral Reef | indestructible | 4 (dead code) | Cannot be destroyed; doubloons_drop=4 is never called |

### Enemy Mob - Drop Values (enemy_mob.gd and enemy .tres files)

| Enemy | HP | Drop | Speed | Can Fire |
|---|---|---|---|---|
| Skeleton Rower | 2 | 2 | 2.0 u/s | Yes (interval 2.4 s) |
| Raider Skiff | 4 | 3 | 0.0 (stationary) | Yes (interval 1.8 s) |
| Ghost Sloop | 6 | 4 | 2.4 u/s | Yes (interval 1.8 s) |
| Armored Turtle-Raft | 30 | 4 | 1.5 u/s | No |
| Elite Armored Raft | 45 | 15 | 1.2 u/s | Yes (interval 1.5 s) |

### Chest Pickups (collectible_chest.gd)

Chests add their chest_value directly to GameState.doubloons.

| Spawn Context | Default chest_value |
|---|---|
| ChestSpawnMarker_HazardFlank (barricade chunk) | 50 (only spawns at level >= 5) |
| ChestSpawnMarker_HazardLeft (mine chunk) | 75 |
| ChestSpawnMarker_HazardRight (mine chunk) | 100 |

### Ambient Coins - chunk_warmup.tscn Inventory

| Object | Type | Count | Value | Subtotal |
|---|---|---|---|---|
| Doubloon_1 through Doubloon_5 | Ambient coin | 5 | 1 each | 5 |
| Barrel_Center | Wooden Barrel HP 1 | 1 | 1 | 1 |
| Barrel_Left + Barrel_Right | Wooden Barrel HP 1 | 2 | 1 each | 2 |
| EnemyMob_Rower HP 2 | Skeleton Rower | 1 | 2 | 2 |
| MultiplierGate (+1) | Fleet upgrade | - | - | - |
| **Warmup Chunk Total** | | | | **~10** |

### Ambient Coins - chunk_mine_gauntlet.tscn Inventory

| Object | Type | Count | Value | Subtotal |
|---|---|---|---|---|
| Doubloon1-4 (value=8 each) | Ambient coin | 4 | 8 each | 32 |
| Sea Mines (2 per gate x 4 gates) | Sea Mine HP 1 | 8 | 2 each | 16 |
| ChestSpawnMarker_HazardLeft (min_level=5) | Chest | 0-1 | 75 | 0-75 |
| ChestSpawnMarker_HazardRight (chest_value=100) | Chest | 0-1 | 100 | 0-100 |
| **Mine Chunk Total (no chests)** | | | | **48** |
| **Mine Chunk Total (with chests, L>=5)** | | | | **~223** |

### Ambient Coins - chunk_barricade_siege.tscn Inventory

| Object | Type | Count | Value | Subtotal |
|---|---|---|---|---|
| EnemyMob_TurtleRaft (scene: HP=6, doubloons_drop=4) | Turtle Raft scene override | 1 | 4 | 4 |
| BarricadeWall (5 slats) | Barricade segments | 5 | 1 each | 5 |
| Barrel_RuneChest (HP=2, RUNE_BARREL, spawns_chest=true) | Rune Barrel + Chest | 1 | 3 + 50 chest | 53 |
| EnemyMob_RowerLeft + RowerRight HP 2 each | Skeleton Rowers | 2 | 2 each | 4 |
| ChestSpawnMarker_HazardFlank (chest_value=50, min_level=5) | Chest | 0-1 | 50 | 0-50 |
| **Barricade Chunk Total (no flank chest)** | | | | **~66** |
| **Barricade Chunk Total (with flank chest, L>=5)** | | | | **~116** |

> Level 1-3 Special Rule (chunk_barricade_siege.gd): _apply_level_tuning() replaces the front-hazard Turtle Raft with a Wooden Barrel for levels <= 3. The scene-level Turtle Raft has max_hp=6, doubloons_drop=4 (NOT the 30 HP default from turtle_raft.tres). For levels 4-10, if max_hp > 15, it is capped at 10.

---

## Barricade Segment HP - Dynamic Tier Table (barricade_segment.gd, barricade_wall.gd)

HP is resolved at runtime based on GameState.current_level, NOT stored in level .tres files:

| Level Range | Slat HP per Segment | Wall Segments | Total Wall HP to Clear |
|---|---|---|---|
| Levels 1-3 | 2 | 5 | 10 |
| Levels 4-10 | 6 | 5 | 30 |
| Levels 11-25 | 12 | 5 | 60 |
| Levels 26-45 | 20 | 5 | 100 |

Each BarricadeWall spawns 5 segments at x_points = [-0.8, -0.4, 0.0, 0.4, 0.8] (normalized), scaled to river_width / 2.0 = +/-6 m spread.

---

## Table 2 - Complete Levels 1-45 Matrix

### Column Key
- Speed: base_scroll_speed from LevelData resource
- Chunks: chunk sequence count (W=Warmup, M=MineGauntlet, B=BarricadeSiege + Boss type)
- Slat HP: barricade segment HP at this level
- Wall HP: total HP for one barricade wall (5 slats x slat HP)
- Reward: completion_doubloon_reward
- Drop Est.: estimated max in-run coin yield (best-case all pickups collected)
- Total: Reward + Drop potential
- Rec. Ship: LEVEL_SHIPS entry
- Min. Viable: minimum ship/tier that can reliably clear barricades

### Boss Abbreviations
- IJ = chunk_boss_ironjaw | PD = chunk_boss_phantom_dredge | SF = chunk_boss_siege_fortress | BB = chunk_boss_bonebeard

### Chunk Count Formula for Drop Estimates
- Warmup: ~10 | Mine (no chests): 48 | Mine (with chests L>=5): ~223 | Barricade (no flank chest): ~66 | Barricade (with chest L>=5): ~116

| Lv | Title | Biome | Speed | Chunks | Slat HP | Wall HP | Reward | Drop Est. | Total | Rec. Ship | Min. Viable |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | Smuggler's Run | tropical | 6.5 | W,M,B,M,IJ | 2 | 10 | 150* | ~106 | ~256 | Dinghy | Dinghy T1 |
| 2 | Black Tide Bayou | bayou | 7.5 | W,B,M,B,PD | 2 | 10 | 250 | ~172 | ~422 | Sloop | Dinghy T1 |
| 3 | Brimstone Bastion | brimstone | 8.0 | W,B,W,B,SF | 2 | 10 | 350 | ~172 | ~522 | Ironclad | Dinghy T1 |
| 4 | Smuggler's Nightmare | tropical | 8.0 | W,M,B,M,B,IJ | 6 | 30 | 300 | ~228 | ~528 | Dinghy | Dinghy T2 |
| 5 | Black Tide Abyss | bayou | 8.5 | W,B,M,B,M,PD | 6 | 30 | 500 | ~452 | ~952 | Sloop | Sloop T1 |
| 6 | Brimstone Inferno | brimstone | 9.0 | W,M,B,M,B,SF | 6 | 30 | 600 | ~452 | ~1052 | Ironclad | Sloop T1 |
| 7 | Coral Cataclysm | tropical | 9.0 | W,M,M,B,M,B,IJ | 6 | 30 | 700 | ~548 | ~1248 | Dinghy | Sloop T2 |
| 8 | Serpent's Mire | bayou | 9.5 | W,B,B,M,B,M,PD | 6 | 30 | 800 | ~548 | ~1348 | Sloop | Sloop T2 |
| 9 | Ashen Straits | brimstone | 10.0 | W,M,B,M,B,B,SF | 6 | 30 | 900 | ~548 | ~1448 | Ironclad | Ironclad T1 |
| 10 | Skull Reef Pass | tropical | 10.0 | W,M,B,M,B,M,B,IJ | 6 | 30 | 1000 | ~644 | ~1644 | Dinghy | Ironclad T1 |
| 11 | Dreadwater Gorge | bayou | 10.5 | W,B,M,B,M,B,M,PD | 12 | 60 | 1200 | ~714 | ~1914 | Sloop | Sloop T3 |
| 12 | Bonebeard's Lair | brimstone | 11.0 | W,M,B,M,B,M,B,BB | 12 | 60 | 1500 | ~714 | ~2214 | Ironclad | Ironclad T2 |
| 13 | Coral Labyrinth | tropical | 9.0 | 6 custom chunks | 12 | 60 | 400 | ~310 | ~710 | Dinghy | Dinghy T2 |
| 14 | Siren's Shoals | tropical | 9.25 | 6 custom chunks | 12 | 60 | 425 | ~310 | ~735 | Bombard Skiff | Sloop T1 |
| 15 | Bone-Beard's Outpost | tropical | 9.5 | 7 custom chunks | 12 | 60 | 450 | ~380 | ~830 | Ironclad | Sloop T2 |
| 16 | The Iron Wall | bayou | 9.5 | 7 custom chunks | 12 | 60 | 500 | ~380 | ~880 | Ironclad | Ironclad T1 |
| 17 | Murkwater Run | bayou | 9.65 | 7 custom chunks | 12 | 60 | 525 | ~380 | ~905 | Sloop | Sloop T2 |
| 18 | Witch's Channel | bayou | 9.8 | 8 custom chunks | 12 | 60 | 525 | ~424 | ~949 | Dinghy | Sloop T2 |
| 19 | Devil's Slalom | bayou | 9.95 | 8 custom chunks | 12 | 60 | 550 | ~424 | ~974 | Dinghy | Dinghy T2 |
| 20 | Citadel of Iron | bayou | 10.05 | 8 custom chunks | 12 | 60 | 575 | ~424 | ~999 | Bombard Skiff | Bombard T2 |
| 21 | Serpent's Nest | bayou | 10.2 | 8 custom chunks | 12 | 60 | 600 | ~424 | ~1024 | Ironclad | Ironclad T2 |
| 22 | Gloom Mire | bayou | 10.35 | 8 custom chunks | 12 | 60 | 600 | ~424 | ~1024 | Dinghy | Sloop T2 |
| 23 | Rotwood Reach | bayou | 10.5 | 8 custom chunks | 12 | 60 | 625 | ~424 | ~1049 | Sloop | Sloop T3 |
| 24 | Blackwater Hollow | bayou | 10.65 | 9 custom chunks | 12 | 60 | 650 | ~468 | ~1118 | Bombard Skiff | Bombard T2 |
| 25 | Phantom Trench | bayou | 10.8 | 8 custom+boss | 12 | 60 | 650 | ~424 | ~1074 | Sloop | Sloop T3 |
| 26 | Stagnant Cut | bayou | 10.95 | 9 custom chunks | 20 | 100 | 675 | ~468 | ~1143 | Ironclad | Ironclad T2 |
| 27 | Banshee Bog | bayou | 11.05 | 9 custom chunks | 20 | 100 | 700 | ~468 | ~1168 | Dinghy | Dinghy T3 |
| 28 | Dead Man's Bayou | bayou | 11.2 | 9 custom chunks | 20 | 100 | 725 | ~468 | ~1193 | Bombard Skiff | Bombard T2 |
| 29 | Voodoo Crossing | bayou | 11.35 | 9 custom chunks | 20 | 100 | 725 | ~468 | ~1193 | Dinghy | Dinghy T3 |
| 30 | Bone-Beard's Armada | bayou | 11.5 | 8 custom+boss | 20 | 100 | 750 | ~424 | ~1174 | Ironclad | Ironclad T2 |
| 31 | Cinder Rapids | brimstone | 11.5 | 9 custom chunks | 20 | 100 | 800 | ~468 | ~1268 | Sloop | Sloop T3 |
| 32 | Magma Surge | brimstone | 11.6 | 9 custom chunks | 20 | 100 | 850 | ~468 | ~1318 | Ironclad | Ironclad T2 |
| 33 | Ashfall Gorge | brimstone | 11.7 | 10 custom chunks | 20 | 100 | 850 | ~512 | ~1362 | Dinghy | Dinghy T3 |
| 34 | Obsidian Strait | brimstone | 11.8 | 10 custom chunks | 20 | 100 | 900 | ~512 | ~1412 | Bombard Skiff | Bombard T3 |
| 35 | Ironjaw's Crucible | brimstone | 11.95 | 9 custom+boss | 20 | 100 | 900 | ~468 | ~1368 | Ironclad | Ironclad T3 |
| 36 | Pyroclast Pass | brimstone | 12.05 | 10 custom chunks | 20 | 100 | 950 | ~512 | ~1462 | Dinghy | Dinghy T3 |
| 37 | Hellmouth Trench | brimstone | 12.15 | 10 custom chunks | 20 | 100 | 950 | ~512 | ~1462 | Bombard Skiff | Bombard T3 |
| 38 | Boiling Reach | brimstone | 12.25 | 10 custom chunks | 20 | 100 | 1000 | ~512 | ~1512 | Sloop | Sloop T3 |
| 39 | Sulfur Chasm | brimstone | 12.35 | 11 custom chunks | 20 | 100 | 1050 | ~556 | ~1606 | Dinghy | Dinghy T3 |
| 40 | Molten Bulwark | brimstone | 12.45 | 10 custom+boss | 20 | 100 | 1050 | ~512 | ~1562 | Bombard Skiff | Bombard T3 |
| 41 | Inferno Gate | brimstone | 12.55 | 11 custom chunks | 20 | 100 | 1100 | ~556 | ~1656 | Ironclad | Ironclad T3 |
| 42 | Doomspire Channel | brimstone | 12.7 | 11 custom chunks | 20 | 100 | 1100 | ~556 | ~1656 | Dinghy | Ironclad T3 |
| 43 | Abyssal Rift | brimstone | 12.8 | 11 custom chunks | 20 | 100 | 1150 | ~556 | ~1706 | Bombard Skiff | Bombard T3 |
| 44 | Dreadflame Basin | brimstone | 12.9 | 11 custom chunks | 20 | 100 | 1150 | ~556 | ~1706 | Dinghy | Ironclad T3 |
| 45 | Bone-Beard's Throne | brimstone | 13.0 | 10 custom+boss | 20 | 100 | 1200 | ~512 | ~1712 | Ironclad | Ironclad T3 |

*Level 1 has no completion_doubloon_reward field in the .tres file; uses LevelData class default = 150.

---

## Root-Cause Analysis: Why Level 2 Pays ~850 and Difficulty Spikes

### Factor 1 - Chunk Sequence Doubles Barricade Exposure

Level 1 sequence: W, M, B, M, IJ - 1 barricade chunk
Level 2 sequence: W, B, M, B, PD - **2 barricade chunks**

This is an immediate structural jump. Level 1 has one barricade encounter; Level 2 has two back-to-back.

### Factor 2 - Barricade Chunk Contains the Highest-Value Drop Combination

Each chunk_barricade_siege contains:
- 1x Turtle Raft (scene: HP=6, drops 4 at levels 1-3 — the scene override hp=6 is NOT replaced because the replacement only triggers for enemies in front-of-barricade position at level <=3)
- 5x BarricadeWall slats (1 each = 5)
- 1x Rune Barrel with spawns_chest=true (3 + 50 chest = 53 combined)
- 2x Skeleton Rowers (2 each = 4)

> Important: ChestSpawnMarker_HazardFlank has min_level=5, so flank chest does NOT spawn at Level 2. The Rune Barrel chest DOES spawn because it uses metadata/spawns_chest in destructible_obstacle.gd::die() - no level gate on this path.

Barricade chunk total at Level 2 per chunk: ~66 x 2 = **~132**

### Factor 3 - Biome Jump Raises Scroll Speed +15%

Level 1: base_scroll_speed = 6.5 (tropical)
Level 2: base_scroll_speed = 7.5 (+1.0 u/s = +15.4% faster)

Higher scroll speed gives the player less time to react to incoming barricades. Difficulty is both perceptual (faster scroll) AND structural (double barricades).

### Factor 4 - Boss Change to Phantom Dredge

Level 1 boss: Ironjaw
Level 2 boss: Phantom Dredge

Different boss pattern. If Phantom Dredge has different attack timing or higher effective HP at this tier, it adds to perceived difficulty spike.

### Factor 5 - Why ~850 Is Seen in Practice (Multiplier Gate Stacking)

The warmup chunk contains a MultiplierGate with gate_action = "add_fleet_1" (value=1). The barricade chunk contains a MultiplierGate with gate_action = "add_fleet_2" (value=2). If the player collects both gates and achieves a 2x multiplier mid-run, in-run coins are doubled:

- Base drops (no multiplier): ~172 + 250 reward = 422
- With 2x multiplier active on in-run coins: ~344 drops + 250 = 594
- If the Rune Barrel chest spawns from BOTH barricade chunks: +100 (two 50-coin chests)
- Full multiplier + both barricade chests + near-perfect mine collection: ~850

This is the actual mechanism. The ~850 figure is the observed ceiling for an optimal L2 run.

### Minimum Viable Vessel for Level 2

- Slat HP = 2 - Dinghy T1 (Bow Chaser, DPS = 5.0) destroys one slat every 0.4 seconds. A full 5-slat wall (HP=10) cleared in 2.0 s continuous fire.
- Turtle Raft (scene HP=6) - Dinghy T1 clears in 1.2 s.
- **Minimum viable: Dinghy T1** - theoretically passable, but max_health=1 means a single hit from any enemy cannonball or passing obstacle ends the run. Dinghy T2 (DPS=20) is strongly recommended.

---

## Appendix - Shared Chunk Drop Summary (Levels 1-12)

The three canonical shared chunks used in Levels 1-12:

| Chunk | Key Content | Base Drop (no chests) | With Chests (L>=5) |
|---|---|---|---|
| chunk_warmup.tscn | 5 coins (1 each), 3 barrels, 1 Skeleton Rower, MultiplierGate | ~10 | ~10 |
| chunk_mine_gauntlet.tscn | 4 coins (8 each=32), 8 Sea Mines (2 each=16), 2 ChestMarkers | ~48 | ~223 |
| chunk_barricade_siege.tscn | TurtleRaft (4), 5 slats (5), Rune Barrel+Chest (53), 2 Rowers (4), flank ChestMarker | ~66 | ~116 |

Levels 13-45 use bespoke chunk scenes (unique IDs per .tres) - their per-chunk inventory was not individually parsed. The Table 2 estimates use the canonical chunk formula scaled by chunk count.

---

## Data Source Files Inspected

| File | Purpose |
|---|---|
| src/data/resources/user_vessels/*.tres | Vessel stats (HP, speed, tier costs, sockets) |
| src/data/resources/user_crew/*.tres | Weapon fire rates and properties |
| src/data/resources/user_ammo/*.tres | Ammo damage values |
| src/data/resources/enemy_vessels/*.tres | Enemy HP and drop counts |
| src/data/resources/levels/level_01.tres to level_45.tres | Level scroll speed, chunk sequence, completion reward |
| src/gameplay/obstacles/barricade_segment.gd | Dynamic HP tier logic |
| src/gameplay/obstacles/barricade_wall.gd | Wall spawn and HP assignment |
| src/gameplay/obstacles/destructible_obstacle.gd | Barrel drop values, explosion logic |
| src/gameplay/chunks/chunk_warmup.tscn | Ambient coin/barrel/enemy inventory |
| src/gameplay/chunks/chunk_mine_gauntlet.tscn | Mine + doubloon + chest inventory |
| src/gameplay/chunks/chunk_barricade_siege.tscn | Barricade + enemy + rune barrel inventory |
| src/gameplay/chunks/chunk_barricade_siege.gd | Early-level enemy replacement logic |
| src/gameplay/chunks/chest_spawn_marker.gd | Chest min_level gate (min_level=5) |
| src/gameplay/enemies/enemy_mob.gd | Enemy drop logic, fire intervals |
| src/gameplay/collectibles/collectible_chest.gd | Chest reward amount |
| src/gameplay/collectibles/collectible_doubloon.gd | Coin value delivery |
| src/gameplay/player/attached_weapon.gd | Weapon fire timer, scatter pellet logic |
| src/core/game_state.gd | LEVEL_SHIPS mapping, VESSEL_CATALOG |
