# Cove Corsair 🏴‍☠️⚓

**Cove Corsair** is a 3D pirate-themed arcade runner built with **Godot 4**. It features an expansive **45-level campaign** across **3 atmospheric biomes**, a **calibrated 4-vessel progression economy**, a **15,000px continuous River Map**, dynamic **multiplier gate ballistics**, **3D particle combat VFX**, **mobile-optimized audio crossfading**, and **Perlin noise camera trauma shake**.

> [!NOTE]
> This codebase is structured to be completely modular, strongly typed, and fully synchronized across all technical documentation and test suites.

---

## 📑 Table of Contents
1. [Tech Stack & System Requirements](#-tech-stack--system-requirements)
2. [Project Directory & File Structure](#-project-directory--file-structure)
3. [Core Systems & System Architecture](#-core-systems--system-architecture)
4. [Vessel Fleet Roster & Calibrated Economy](#-vessel-fleet-roster--calibrated-economy)
5. [Campaign Structure & Biomes Overview](#-campaign-structure--biomes-overview)
6. [Combat Systems, Weapons & 3D VFX](#-combat-systems-weapons--3d-vfx)
7. [Audio System & Camera Trauma](#-audio-system--camera-trauma)
8. [How to Run, Debug, and Execute Tests](#-how-to-run-debug-and-execute-tests)
9. [Documentation Links](#-documentation-links)

---

## 🛠 Tech Stack & System Requirements

* **Game Engine:** [Godot Engine 4.x](https://godotengine.org/) (Mobile / Forward+ 3D Renderer)
* **Scripting Language:** Typed GDScript 2.0
* **Target Platforms:** Android Mobile (Portrait Mode, $1080 \times 1920$ viewport) & PC Desktop
* **Data Interchange:** Strongly-typed Godot Resources (`.tres`) and JSON configurations
* **Particle Pipeline:** Mobile-optimized `CPUParticles3D` with world container reparenting
* **Audio Pipeline:** Multi-bus architecture (`Master`, `BGM`, `SFX`) with dual-player crossfade

---

## 📂 Project Directory & File Structure

```
f:\projects\cove-corsair\
├── README.md                                   # Root project documentation (this file)
├── project.godot                               # Godot 4 project configuration file
├── export_presets.cfg                          # Godot Android & Desktop export presets
├── coveCorsair.apk                             # Android APK package
├── assets/                                     # Audio, textures, 3D meshes, and fonts
│   ├── audio/                                  # Music tracks and SFX pools
│   ├── models/                                 # Kenney Low-Poly assets & PBR vessel models
│   └── sprites/                                # UI icons, badges, and HUD graphics
├── documents/                                  # Design architecture & technical specifications
│   ├── Cove Corsair - Progression...md         # Progression, Fleet Meta & Economy Architecture
│   ├── Ahoy! Pirate Arcade Runner_...md        # Master Game Design Document & Roadmap
│   ├── vessels.md                              # Player & enemy vessels specification
│   ├── lane_objects.md                         # Destructibles, barricades, and hazards
│   ├── ammo.md                                 # Ammunition types & ballistics specs
│   ├── crew.md                                 # Deck crew hardpoints & weapon sockets
│   ├── assets_3d_manifest.md                   # 3D model & texture manifest
│   └── levels/                                 # Level specs & biome indices
└── src/                                        # Core game source code
    ├── core/                                   # Global singletons & engine systems
    │   ├── game_state.gd                       # Global persistent state & economy autoload
    │   ├── audio_manager.gd                    # Audio bus & biome music crossfader
    │   ├── vfx_manager.gd                      # Global 3D particle spawner & lifecycle manager
    │   ├── game_camera.gd                      # FastNoiseLite Perlin noise camera trauma
    │   └── main_game.gd / .tscn                # Main gameplay scene root
    ├── data/                                   # Data models, schemas, and resource definitions
    │   ├── level_data.gd                       # LevelData resource schema
    │   ├── ship_data.gd                        # ShipData resource schema
    │   ├── weapon_data.gd                      # WeaponData resource schema
    │   ├── ammo_data.gd                        # AmmoData resource schema
    │   └── resources/                          # Compiled .tres resources (levels, vessels, crew)
    ├── gameplay/                               # In-run entities and mechanics
    │   ├── chunks/                             # Reusable track chunks (warmup, barricade, mines, bosses)
    │   ├── collectibles/                       # 3D chests, coin pickups, spawn markers
    │   ├── enemies/                            # Hostile mob skiffs & phase bosses
    │   ├── levels/                             # Track controllers & riverbank prop scatter
    │   ├── obstacles/                          # Barricade walls, sea mines, biogas pods
    │   ├── player/                             # Player vessel, follower fleet AI, weapon sockets
    │   └── projectiles/                        # Cannonballs, mortar shells, scattershot pellets
    ├── tools/                                  # Editor scripts & automated campaign generators
    │   ├── generate_campaign_levels.gd         # 45-level automated campaign generator
    │   └── build_chunks.gd                     # Chunk assembler tool
    ├── ui/                                     # UI layout screens and HUD
    │   ├── river_map.gd / .tscn                # 15,000px continuous River Map
    │   ├── settlement_screen.gd / .tscn        # Victory/defeat modal with gold banking
    │   ├── shipyard/                           # Shipyard upgrade interface
    │   └── top_hud.gd / .tscn                  # In-run health, progress, and doubloons HUD
    ├── vfx/                                    # 3D particle scenes (splinters, geyser, explosions)
    └── test_*.gd / .tscn                       # Automated verification test suites
```

---

## ⚡ Core Systems & System Architecture

### 1. Global Game State (`GameState`)
Autoload singleton ([`src/core/game_state.gd`](file:///f:/projects/cove-corsair/src/core/game_state.gd)):
* Manages persistent economy (`doubloons`), vessel ownership, active vessel tiers, star mastery ratings, and high scores.
* Emits global reactive signals: `doubloons_changed`, `multiplier_changed`, `progress_changed`, `active_vessel_changed`, `run_failed`.
* Handles save/load serialization via `user://cove_corsair_save.json`.

### 2. River Map Navigation (`RiverMap`)
Progression interface ([`src/ui/river_map.gd`](file:///f:/projects/cove-corsair/src/ui/river_map.gd)):
* **15,000px Continuous Canvas:** Features a vertical parchment chart spanning 45 level nodes across 3 biomes.
* **Procedural Spline:** Generates a curved river spline with multi-layered polylines rendering riverbed depth, shorelines, and sunlit water currents.
* **Frame-0 Anchor Guard:** Deferment guard ensures the 15,000px canvas height is fully measured before positioning the camera on the active level.
* **Victory Advancement:** The miniature vessel sails smoothly along the spline from `last_cleared_level` to `highest_unlocked_level`, aligning tangent to curves with water cruise SFX.

### 3. Settlement & Economy Loop (`SettlementScreen`)
End-of-run modal ([`src/ui/settlement_screen.gd`](file:///f:/projects/cove-corsair/src/ui/settlement_screen.gd)):
* **100% In-Run Gold Retention on Defeat:** When the player's hull is destroyed, all doubloons gathered during the run are retained and banked ("HULL BREACHED - TREASURE RETAINED").
* **Animated Roll-up Tally:** Numbers count upward with audio ticks for in-run doubloons, level bonuses, and banked wealth.
* **Shipyard Notification Badge:** When banked doubloons satisfy `can_afford_active_vessel_upgrade()`, the Shipyard button displays a pulsing golden badge and radiant glow, allowing immediate upgrades before restarting.

---

## ⛵ Vessel Fleet Roster & Calibrated Economy

Vessels operate as tactical sidegrades rather than linear power upgrades:

| Vessel | Archetype | Purchase Price | Tier 2 Upgrade | Tier 3 Upgrade | Base HP | Speed | Base Cannon | Hardpoint Layout |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| [**The Dinghy**](file:///f:/projects/cove-corsair/src/data/resources/user_vessels/dinghy_ship.tres) | Agile Skiff | **$0$** | **$300$** | **$750$** | $1\text{ HP}$ | $12.0\text{ m/s}$ | Bow Chaser ($0.20\text{s}$) | Bow Chaser + Monkey Bomber + Skeleton Tosser |
| [**The Sloop**](file:///f:/projects/cove-corsair/src/data/resources/user_vessels/sloop_ship.tres) | Tactical Cruiser | **$600$** | **$800$** | **$1,500$** | $5\text{ HP}$ | $11.0\text{ m/s}$ | Dual Chasers ($0.16\text{s}$) | Dual Chasers + Deck Crew Duo + Dual Swivels |
| [**The Bombard Skiff**](file:///f:/projects/cove-corsair/src/data/resources/user_vessels/bombard_skiff_ship.tres) | Artillery Mortar | **$1,000$** | **$1,200$** | **$2,200$** | $3\text{ HP}$ | $9.0\text{ m/s}$ | Heavy Mortar ($1.30\text{s}$) | Siege Mortar (AoE) + Monkey Bomber + Dual Side Scattershots |
| [**The Ironclad**](file:///f:/projects/cove-corsair/src/data/resources/user_vessels/ironclad_ship.tres) | Armored Brawler | **$1,400$** | **$1,800$** | **$3,000$** | $8\text{ HP}$ | $7.5\text{ m/s}$ | Heavy Battery ($0.15\text{s}$) | Heavy Battery + Deck Crew + Quad Swivel Battery |

---

## 🏝 Campaign Structure & Biomes Overview

The campaign spans **45 sequentially unlocked levels** across 3 biomes generated via [`generate_campaign_levels.gd`](file:///f:/projects/cove-corsair/src/tools/generate_campaign_levels.gd):

```
[ Levels 1–15: Tropical Reef ] ──► [ Levels 16–30: Murky Bayou ] ──► [ Levels 31–45: Volcanic Brimstone ]
  Scroll Speed: 8.0 – 9.5 m/s        Scroll Speed: 9.5 – 11.5 m/s       Scroll Speed: 11.5 – 13.0 m/s
  Doubloons: 100 – 450               Doubloons: 500 – 750               Doubloons: 800 – 1,200
  Clear sunny waters, sandy shoals   Atmospheric swamp fog (0.015)      Intense heat fog (0.02), crimson glow
```

### Milestone Boss Encounters (Every 5 Levels)
* **Level 5:** [The Phantom Dredge](file:///f:/projects/cove-corsair/src/gameplay/enemies/boss_phantom_dredge.gd) ($500\text{ HP}$)
* **Level 10:** [Captain Ironjaw](file:///f:/projects/cove-corsair/src/gameplay/enemies/boss_war_barge.gd) ($220\text{ HP}$)
* **Level 15:** [Captain Bone-Beard's Outpost](file:///f:/projects/cove-corsair/src/gameplay/enemies/boss_bone_beard.gd) ($500\text{ HP}$)
* **Level 20:** [The Siege Fortress](file:///f:/projects/cove-corsair/src/gameplay/enemies/boss_siege_fortress.gd) ($800\text{ HP}$)
* **Level 25:** [The Phantom Dredge](file:///f:/projects/cove-corsair/src/gameplay/enemies/boss_phantom_dredge.gd) ($650\text{ HP}$)
* **Level 30:** [Captain Bone-Beard's Armada](file:///f:/projects/cove-corsair/src/gameplay/enemies/boss_bone_beard.gd) ($750\text{ HP}$)
* **Level 35:** [Captain Ironjaw's Crucible](file:///f:/projects/cove-corsair/src/gameplay/enemies/boss_war_barge.gd) ($400\text{ HP}$)
* **Level 40:** [The Molten Bulwark (Siege Fortress)](file:///f:/projects/cove-corsair/src/gameplay/enemies/boss_siege_fortress.gd) ($1,200\text{ HP}$)
* **Level 45:** [Captain Bone-Beard's Final Throne](file:///f:/projects/cove-corsair/src/gameplay/enemies/boss_bone_beard.gd) ($1,000\text{ HP}$)

### Dynamic Barricade Slat HP Scaling
* **Levels 1–3:** $2\text{ HP}$ (Dinghy breaks slat in 2 direct cannon shots).
* **Levels 4–10:** $6\text{ HP}$ (Demands focused fire or upgraded volleys).
* **Levels 11–25:** $12\text{ HP}$ (Mid-campaign fortified barrier).
* **Levels 26+:** $20\text{ HP}$ (Late-game fortified siege walls).

---

## 💣 Combat Systems, Weapons & 3D VFX

### Ballistics & Ordnance
* **Bow Mortar & Heavy Shot:** ([`weapon_bow_mortar.tres`](file:///f:/projects/cove-corsair/src/data/resources/user_crew/weapon_bow_mortar.tres), [`ammo_heavy_shot.tres`](file:///f:/projects/cove-corsair/src/data/resources/user_ammo/ammo_heavy_shot.tres)) High parabolic arc firing explosive shells that detonate with a $2.0\text{m}$ AoE splash radius.
* **Scattershot Carronades:** ([`weapon_scattershot.tres`](file:///f:/projects/cove-corsair/src/data/resources/user_crew/weapon_scattershot.tres), [`scattershot_pellet.tscn`](file:///f:/projects/cove-corsair/src/gameplay/projectiles/scattershot_pellet.tscn)) High-dispersion 5-pellet cone volley traveling at $25.0\text{ m/s}$ ($12.0\text{m}$ despawn range).

### Global 3D Particle VFX (`VFXManager`)
Global spawner ([`src/core/vfx_manager.gd`](file:///f:/projects/cove-corsair/src/core/vfx_manager.gd)) using `CPUParticles3D`:
* **World Tree Reparenting:** Spawns particles under a persistent `VFXContainer` so calling `queue_free()` on destroyed obstacles does not cut off particle lifecycles.
* **Waterline Snapping:** Water splash geysers snap $Y$-coordinates to the water plane ($0.0\text{m} \le Y \le 0.05\text{m}$).
* **Particle Scenes:** Wood debris splinters, mortar geysers, mine explosions, and golden coin bursts upon opening 3D treasure chests.

---

## 🔊 Audio System & Camera Trauma

* **Audio Manager (`AudioManager`):**
  * Multi-bus audio architecture (`Master`, `BGM`, `SFX`) with persistent volume/mute controls.
  * Dual-player background music crossfade with a **redundant crossfade guard** preventing music restarts when switching between levels within the same biome.
  * 24-voice dynamic sound effect pool with randomized pitch modulation ($0.93\times\text{--}1.07\times$).
* **Camera Trauma & Perlin Noise Shake (`GameCamera`):**
  * Driven by `FastNoiseLite` with quadratic falloff ($\text{intensity} = \text{trauma}^2$) and $1.25/\text{s}$ decay.
  * Trauma events: hull collision ($+0.55$), mortar impact ($+0.45$), mortar launch ($+0.25$), scattershot volley ($+0.15$), cannon fire ($+0.08$).

---

## 🚀 How to Run, Debug, and Execute Tests

### 1. Launching the Game
```bash
# Run main game entrypoint
godot --scene src/core/main_game.tscn
```

### 2. Running Automated Verification Test Suites
All major game systems include headless Godot test runners that output structured verification diagnostics:

```bash
# 1. Fleet meta, vessel stats, hardpoint sockets & levels
godot --headless --scene src/test_fleet_meta_and_levels.tscn

# 2. 45-level campaign expansion & milestone boss rotation
godot --headless --scene src/test_campaign_expansion.tscn

# 3. Early campaign rebalance & barricade tier scaling
godot --headless --scene src/test_early_campaign_rebalance.tscn

# 4. Settlement screen, gold retention & economy loop
godot --headless --scene src/test_settlement_and_economy.tscn

# 5. Combat particle VFX, waterline snapping & container reparenting
godot --headless --scene src/test_vfx_systems.tscn

# 6. Audio crossfade, volume buses & Perlin noise camera trauma
godot --headless --scene src/test_audio_camera_biome.tscn

# 7. 3D treasure chests, mine fields & 15,000px River Map
godot --headless --scene src/test_chest_mines_rivermap.tscn

# 8. Enemy firing vectors & projectile trajectories
godot --headless --scene src/test_enemy_firing_vectors.tscn

# 9. Bombard Skiff mortar mechanics & scattershot carronades
godot --headless --scene src/test_bombard_skiff.tscn
```

### 3. Regenerating Campaign Levels
To regenerate `level_13.tres` through `level_45.tres` from the calibrated ruleset:
```bash
godot --headless --script src/tools/generate_campaign_levels.gd
```

### 4. Building & Exporting Android APK
```bash
# Export release Android APK package
godot --headless --export-release "Android" coveCorsair.apk
```

---

## 📚 Documentation Links

* 📑 **Progression, Fleet Meta & Architecture:** [`documents/Cove Corsair - Progression, Fleet Meta & Future Modes Architecture.md`](file:///f:/projects/cove-corsair/documents/Cove%20Corsair%20-%20Progression,%20Fleet%20Meta%20&%20Future%20Modes%20Architecture.md)
* 📑 **Master Game Design & Strategic Roadmap:** [`documents/Ahoy! Pirate Arcade Runner_ Master Game Design & Strategic Roadmap.md`](file:///f:/projects/cove-corsair/documents/Ahoy%21%20Pirate%20Arcade%20Runner_%20Master%20Game%20Design%20&%20Strategic%20Roadmap.md)
* ⛵ **Vessels & Mobs Specification:** [`documents/vessels.md`](file:///f:/projects/cove-corsair/documents/vessels.md)
* 🐒 **Deck Crew & Weapon Sockets:** [`documents/crew.md`](file:///f:/projects/cove-corsair/documents/crew.md)
* 💣 **Ammunition & Projectile Mechanics:** [`documents/ammo.md`](file:///f:/projects/cove-corsair/documents/ammo.md)
* 🛢️ **Lane Objects, Hazards & Gates:** [`documents/lane_objects.md`](file:///f:/projects/cove-corsair/documents/lane_objects.md)
* 🎨 **3D Asset & Environmental Catalog:** [`documents/assets_3d_manifest.md`](file:///f:/projects/cove-corsair/documents/assets_3d_manifest.md)
* 🌴 **Modular Environment Asset Slots:** [`assets/models/environment/README.md`](file:///f:/projects/cove-corsair/assets/models/environment/README.md)
* 🗺️ **Campaign Levels Index:** [`documents/levels/README.md`](file:///f:/projects/cove-corsair/documents/levels/README.md)
