# Cove Corsair — 3D Asset & Environmental Catalog

This document is the master inventory and categorization of all 3D models (`.glb`), textures, shaders, materials (`.tres`), and mesh scenes (`.tscn`) in **Cove Corsair**.

---

## 📑 Table of Contents
1. [Overview & Metrics](#-overview--metrics)
2. [Ships & Vessels](#-ships--vessels)
3. [Weapons & Projectiles](#-weapons--projectiles)
4. [Characters & Crew](#-characters--crew)
5. [Natural Environment (Rocks, Terrain, Foliage)](#-natural-environment)
6. [Man-made Props (Docks, Barrels, Palisades, Towers)](#-man-made-props)
7. [Combat VFX & Collectibles](#-combat-vfx--collectibles)
8. [Riverbank Assembly & Kenney Asset Guide](#-riverbank-assembly--kenney-asset-guide)

---

## 📊 Overview & Metrics

- **Total 3D Mesh Files (`.glb`):** **86 models**
  - **72 Kenney Pirate Kit assets** in `res://assets/models/`
  - **5 Custom Enemy & Boss vessels** in `res://assets/models/enemy/vessels/`
  - **4 Custom Player vessels** in `res://assets/models/user/vessels/`
  - **2 Custom Crew character models** in `res://assets/models/user/crew/`
  - **3 Custom Cannon & Weapon models** in `res://assets/models/user/weapons/` & `res://assets/models/weapons/`
- **Material Architecture:**
  - **Kenney Low-Poly Mesh Pipeline:** Uses single palette texture (`res://assets/models/Textures/colormap.png`) with mobile-optimized flat shading (`StandardMaterial3D`, roughness 0.85–0.95, metallic 0.0, runtime shadows disabled via `SHADOW_CASTING_SETTING_OFF`).
  - **Hero Asset Pipeline:** Custom PBR texture sets (Albedo, Normal, Metallic/Roughness) for player ships, boss vessels, crew, and weapons.
  - **Shaders:** Dynamic screen-space water shader (`res://src/shaders/water_stylized.gdshader`) and cockpit interior depth mask (`res://src/shaders/cockpit_depth_mask.gdshader`).

---

## 🚢 Ships & Vessels

### 1. Player Vessels (Custom PBR Models)
Located in `res://assets/models/user/vessels/`:

| Vessel | Model File (`.glb`) | Texture Maps & Masking | Role / Stats Profile |
|---|---|---|---|
| **The Dinghy** | `dinghy.glb` | `dinghy_0.jpg`<br>`dinghy_1.jpg`<br>`dinghy_cockpit_mask.tres` | Starter agile skiff, narrow hitbox, responsive swerve. |
| **The Sloop** | `the_sloop.glb` | `the_sloop_base_color.jpg`<br>`the_sloop_normal.jpg`<br>`the_sloop_metallic_roughness.jpg` | All-rounder corsair sloop, balanced hull and broadside slots. |
| **The Bombard Skiff** | `the_bombard_skiff.glb` | `the_bombard_skiff_base_color.jpg`<br>`the_bombard_skiff_normal.jpg`<br>`the_bombard_skiff_metallic_roughness.jpg` | Heavy artillery vessel with high-angle mortar capabilities. |
| **The Ironclad** | `the_ironclad.glb` | `the_ironclad_base_color.jpg`<br>`the_ironclad_normal.jpg`<br>`the_ironclad_metallic_roughness.jpg` | Armored battleship, high hull HP, quad swivel battery. |

### 2. Enemy & Boss Vessels (Custom PBR Models)
Located in `res://assets/models/enemy/vessels/`:

| Vessel | Model File (`.glb`) | Texture Maps | Encounter / Role |
|---|---|---|---|
| **Skeleton Rower** | `skeleton_rower.glb` | `skeleton_rower_0.jpg`<br>`skeleton_rower_1.jpg` | Standard swarming mob skiff. |
| **Ghost Sloop** | `ghost_sloop.glb` | `ghost_sloop_0.jpg`<br>`ghost_sloop_1.jpg` | Mid-tier spectral ambush raider. |
| **Captain Bone-Beard’s Twin Frigate** | `captain_bone-beard’s_twin_frigate.glb` | `captain_bone-beard’s_twin_frigate_base_color.jpg`<br>`captain_bone-beard’s_twin_frigate_normal.jpg`<br>`captain_bone-beard’s_twin_frigate_metallic_roughness.jpg` | Biome 1 & 3 flagship boss (catamaran twin-hull). |
| **Boss War Barge** | `boss_war_barge.glb` | `boss_war_barge_base_color.jpg`<br>`boss_war_barge_normal.jpg`<br>`boss_war_barge_metallic_roughness.jpg` | Biome 2 siege barge with heavy battering ram. |
| **Boss Siege Fortress** | `boss_siege_fortress.glb` | `boss_siege_fortress_base_color.jpg`<br>`boss_siege_fortress_normal.jpg`<br>`boss_siege_fortress_metallic_roughness.jpg` | Biome 3 floating fortress with multi-turret emplacements. |

### 3. Kenney Pirate Vessels & Wrecks
Located in `res://assets/models/` (uses palette `colormap.png`):

| Filename | Description / Potential Use |
|---|---|
| `boat-row-small.glb` | Small derelict rowboat / river flotsam / starter dinghy fallback. |
| `boat-row-large.glb` | Heavy cargo rowboat / river ferry obstacle. |
| `ship-small.glb` | Compact civilian single-mast merchant cutter. |
| `ship-medium.glb` | Mid-sized two-mast armed brigantine. |
| `ship-large.glb` | Three-mast heavy galleon. |
| `ship-pirate-small.glb` | Light corsair gunboat. |
| `ship-pirate-medium.glb` | Standard corsair frigate. |
| `ship-pirate-large.glb` | Heavy pirate flagship. |
| `ship-ghost.glb` | Spectral phantom hull with tattered sails. |
| `ship-wreck.glb` | Shattered hull ribcage / static riverbank flavor hazard. |

---

## 💥 Weapons & Projectiles

### 1. 3D Weapon Models
| Model File | Location | Textures | Description |
|---|---|---|---|
| `cannon.glb` | `res://assets/models/user/weapons/` | `cannon_base_color.jpg`<br>`cannon_normal.jpg`<br>`cannon_metallic_roughness.jpg` | High-fidelity naval carriage deck cannon. |
| `scattershot_carronade.glb` | `res://assets/models/user/weapons/`<br>`res://assets/models/weapons/` | `scattershot_carronade_base_color.jpg`<br>`scattershot_carronade_normal.jpg`<br>`scattershot_carronade_metallic_roughness.jpg` | Short-barrel heavy carronade for wide-angle buckshot. |
| `cannon.glb` | `res://assets/models/` | `colormap.png` | Kenney naval carriage cannon. |
| `cannon-mobile.glb` | `res://assets/models/` | `colormap.png` | Kenney wheeled field artillery piece. |
| `cannon-ball.glb` | `res://assets/models/` | `colormap.png` | Kenney 3D iron solid shot. |

### 2. Projectile Scenes (`res://src/gameplay/projectiles/`)
| Scene | Target Entity | Mesh / Visual Representation |
|---|---|---|
| `cannonball.tscn` | Enemy vessels & destructibles | 3D sphere mesh with trail VFX. |
| `enemy_cannonball.tscn` | Player fleet | 3D projectile with fiery crimson emissive shader. |
| `scattershot_pellet.tscn` | Swarm mobs & barricades | Multi-pellet scatter projectile with high dispersion cone ($25.0\text{ m/s}$, $12.0\text{m}$ despawn). |

---

## ☠️ Characters & Crew

### 3D Animated Crew Models (`res://assets/models/user/crew/`)
| Model File | Accompanying Textures | Description |
|---|---|---|
| `monkey_crew.glb` | `monkey_crew_base_color.jpg`<br>`monkey_crew_normal.jpg`<br>`monkey_crew_metallic_roughness.jpg` | 3D Pirate Monkey Bomber (hurls coconut & fire bombs). |
| `skeleton_crew.glb` | `skeleton_crew_0.jpg`<br>`skeleton_crew_1.jpg` | 3D Skeleton Deckhand (hurls throwing axes). |

---

## 🌴 Natural Environment

### Foliage, Palms & Plants (`res://assets/models/`)
| Filename | Description / Biome Role |
|---|---|
| `palm-detailed-straight.glb` | Tall upright palm tree for backdrop cliff ridges. |
| `palm-detailed-bend.glb` | Leaning palm curving inward over the riverbank with high vertical clearance ($>4.5\text{m}$). |
| `palm-bend.glb` | Curved palm trunk without undergrowth. |
| `grass-plant.glb` | Small undergrowth tuft for shoreline borders. |
| `grass-patch.glb` | Clustered foliage patch for shoreline transitions. |

### Rocks & Formations (`res://assets/models/`)
| Filename | Description / Biome Role |
|---|---|
| `rocks-sand-a.glb`, `b`, `c` | Sandy shoreline rocks embedded along water edges. |
| `rocks-a.glb`, `b`, `c` | Large cliff boulders and outer canyon walls. |
| `patch-sand.glb`, `patch-sand-foliage.glb` | Low-poly beach sand flats for jagged shorelines. |

---

## 📦 Man-made Props

### Obstacles, Barrels & Structures (`res://assets/models/`)
| Filename | Description / Role |
|---|---|
| `barrel.glb` | Standard wooden obstacle barrel. |
| `chest.glb` | 3D Pirate treasure chest for collectible doubloon rewards. |
| `structure-platform-dock-small.glb` | Ruined wooden dock fragment used for flavor accents. |
| `palisade-spikes.glb` | Defensive timber palisade spike wall. |

---

## ✨ Combat VFX & Collectibles

Managed globally via [`vfx_manager.gd`](file:///f:/projects/cove-corsair/src/core/vfx_manager.gd):

| Scene / Asset | Location | Visual Profile & Lifecycle |
|---|---|---|
| `vfx_wood_splinter.tscn` | `res://src/vfx/` | Burst of angular timber splinters with gravity and tumbling rotation ($0.5\text{s}$). |
| `vfx_mortar_geyser.tscn` | `res://src/vfx/` | Vertical water column geyser and expanding horizontal shockwave ring ($0.6\text{s}$, snaps to waterline $Y \in [0.0, 0.05]$). |
| `vfx_mine_explosion.tscn` | `res://src/vfx/` | Intense orange fiery blast followed by dark expanding smoke cloud ($0.5\text{s}$). |
| `vfx_coin_burst.tscn` | `res://src/vfx/` | Upward fountain of golden doubloon particles upon opening 3D treasure chests ($0.7\text{s}$). |
| `collectible_chest.tscn` | `res://src/gameplay/collectibles/` | 3D treasure chest pickup (`chest.glb`) carrying $25\text{--}100$ doubloon rewards. |

---

## 🏞 Riverbank Assembly & Kenney Asset Guide

The organic riverbank scatter system is governed by [`res://src/gameplay/levels/riverbank_props.gd`](file:///f:/projects/cove-corsair/src/gameplay/levels/riverbank_props.gd), generating 40-meter recycling chunks along both flanks outside the playable corridor ($|X| > 10.0\text{m}$).

### 1. Organic 3-Tier Natural Shoreline Architecture

```
[TIER 3: CLIFF RIDGE]        rocks-a / rocks-b / rocks-c (X ≈ ±6.5m to ±8.5m)
           ▲
[TIER 2: CANOPY OVERHANGS]   palm-detailed-bend / grass-plant (X ≈ ±5.0m, clearance > 4.5m)
           ▲
[TIER 1: JAGGED SHORELINE]   patch-sand / rocks-sand-a/b/c (X ≈ ±4.0m to ±4.5m)
══════════════════════════════════════════════════════════════════════════════════
~~~~~~~~~~~~~~~~~~~~~~~~ RIVER RUNNER PLAYABLE CORRIDOR ~~~~~~~~~~~~~~~~~~~~~~~~~
```

### 2. Active Asset Mapping Table for `riverbank_props.gd`

| Shoreline Layer | Constant in `riverbank_props.gd` | Assigned Kenney Model(s) | Drop-in Replacement Slot (`res://assets/models/environment/`) |
|---|---|---|---|
| **Tier 1: Shoals & Sand** | `SHOAL_SAND_PATHS` | `patch-sand.glb`<br>`patch-sand-foliage.glb` | `shoal_sand.glb` |
| **Tier 1: Shoreline Rocks** | `SHORE_ROCKS_PATHS` | `rocks-sand-a.glb`<br>`rocks-sand-b.glb`<br>`rocks-sand-c.glb` | `shore_rocks.glb` |
| **Tier 2: Canopy Palms** | `PALM_BEND_PATHS` | `palm-detailed-bend.glb`<br>`palm-bend.glb` | `palm_canopy.glb` |
| **Tier 2: Straight Palms** | `PALM_STRAIGHT_PATH` | `palm-detailed-straight.glb` | `palm_straight.glb` |
| **Tier 2: Understory Tufts**| `FOLIAGE_TUFT_PATH` | `grass-plant.glb` | `understory_tuft.glb` |
| **Tier 3: Cliff Formations**| `CLIFF_ROCK_PATHS` | `rocks-a.glb`<br>`rocks-b.glb`<br>`rocks-c.glb` | `cliff_rocks.glb` |
| **Flavor: Shipwrecks** | `FLAVOR_SHIPWRECK` | `ship-wreck.glb` | `flavor_shipwreck.glb` |
| **Flavor: Ruined Docks** | `FLAVOR_DOCK_RUIN` | `structure-platform-dock-small.glb` | `flavor_dock_ruin.glb` |
| **Flavor: Barrels** | `FLAVOR_BARREL` | `barrel.glb` | `flavor_barrel.glb` |
