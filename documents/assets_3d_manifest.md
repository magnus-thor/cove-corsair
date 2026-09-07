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
7. [Materials, Shaders & Textures](#-materials-shaders--textures)
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
  - **Kenney Low-Poly Mesh Pipeline:** Uses single palette texture (`res://assets/models/Textures/colormap.png`) with mobile-optimized flat shading (`StandardMaterial3D`, roughness 1.0, metallic 0.0, no shadows at runtime).
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
| **The Ironclad** | `the_ironclad.glb` | `the_ironclad_base_color.jpg`<br>`the_ironclad_normal.jpg`<br>`the_ironclad_metallic_roughness.jpg` | Armored battleship, high hull HP, ramming resistance. |
| **The Bombard Skiff** | `the_bombard_skiff.glb` | `the_bombard_skiff_base_color.jpg`<br>`the_bombard_skiff_normal.jpg`<br>`the_bombard_skiff_metallic_roughness.jpg` | Heavy artillery vessel with high-angle mortar capabilities. |

### 2. Enemy & Boss Vessels (Custom PBR Models)
Located in `res://assets/models/enemy/vessels/`:

| Vessel | Model File (`.glb`) | Texture Maps | Encounter / Role |
|---|---|---|---|
| **Skeleton Rower** | `skeleton_rower.glb` | `skeleton_rower_0.jpg`<br>`skeleton_rower_1.jpg` | Standard swarming mob skiff. |
| **Ghost Sloop** | `ghost_sloop.glb` | `ghost_sloop_0.jpg`<br>`ghost_sloop_1.jpg` | Mid-tier spectral ambush raider. |
| **Captain Bone-Beard’s Twin Frigate** | `captain_bone-beard’s_twin_frigate.glb` | `captain_bone-beard’s_twin_frigate_base_color.jpg`<br>`captain_bone-beard’s_twin_frigate_normal.jpg`<br>`captain_bone-beard’s_twin_frigate_metallic_roughness.jpg` | Biome 1 flagship boss (catamaran twin-hull). |
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
| `ship-wreck.glb` | Shattered hull ribcage / static riverbank hazard. |

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
| `cannonball.tscn` | Enemy vessels & destructibles | 3D sphere mesh / `cannon-ball.glb` with trail VFX. |
| `enemy_cannonball.tscn` | Player fleet | 3D projectile with fiery crimson emissive shader. |
| `scattershot_pellet.tscn` | Swarm mobs & barricades | Multi-pellet scatter projectile with high dispersion cone. |

---

## ☠️ Characters & Crew

### 1. 3D Animated Crew Models (`res://assets/models/user/crew/`)
| Model File | Accompanying Textures | Description |
|---|---|---|
| `monkey_crew.glb` | `monkey_crew_base_color.jpg`<br>`monkey_crew_normal.jpg`<br>`monkey_crew_metallic_roughness.jpg` | 3D Pirate Monkey Bomber (hurls coconut & fire bombs). |
| `skeleton_crew.glb` | `skeleton_crew_0.jpg`<br>`skeleton_crew_1.jpg` | 3D Skeleton Tosser / Deckhand (swivel gunner & boarding crew). |

### 2. 2D Sprite References (`res://assets/sprites/user_crew/`)
- `skeleton_crew.png`
- `weapon_deckhand_sniper.png`
- `weapon_deckhand_sniper_back.png`
- `weapon_port_swivel.png`

---

## 🌴 Natural Environment

All low-poly natural terrain and foliage assets reside in `res://assets/models/` and utilize `res://assets/models/Textures/colormap.png`.

### 1. Rocks, Boulders & Cliffs
| Filename | Visual Profile | Recommended Environment Layer |
|---|---|---|
| `rocks-a.glb` | Tall, jagged angular cliff formation. | Outer boundary cliff walls (Layer 2/3). |
| `rocks-b.glb` | Broad, flat-topped coastal boulder mass. | Mid-distance riverbank shelf. |
| `rocks-c.glb` | Clustered vertical rock stack. | Outer canyon walls / river choke points. |
| `rocks-sand-a.glb` | Coastal boulder with sand accumulation at base. | Inner waterline shoal margin. |
| `rocks-sand-b.glb` | Low beach rock emerging from sand bank. | Shallow sandbar accent. |
| `rocks-sand-c.glb` | Elongated sand-embedded shoreline rock. | Edge lining between water and grass. |

### 2. Ground Terrain & Sand Patches
| Filename | Visual Profile | Recommended Use |
|---|---|---|
| `patch-sand.glb` | Flat modular sand dune patch. | Inner river shoal foundation. |
| `patch-sand-foliage.glb` | Sand patch with small coastal scrubs. | Inner shoal vegetation accent. |
| `patch-grass.glb` | Raised modular grassy riverbank turf. | Raised bank terraces. |
| `patch-grass-foliage.glb` | Grassy turf with dense shrubbery. | Mid/outer bank foliage layer. |
| `hole.glb` | Concave depression / crater terrain tile. | Tidal pool, lagoon, or bomb crater. |

### 3. Foliage & Tropical Palms
| Filename | Visual Profile | Recommended Use |
|---|---|---|
| `palm-straight.glb` | Low-poly upright coconut palm. | Forest canopy on elevated banks. |
| `palm-bend.glb` | Low-poly angled leaning palm. | Overhanging riverbank props. |
| `palm-detailed-straight.glb` | High-definition straight palm with segmented fronds. | Foreground hero bank trees. |
| `palm-detailed-bend.glb` | High-definition curved palm leaning toward river. | Prominent waterline overhangs. |
| `grass.glb` | Low-poly single grass tuft. | Waterline and rock-base accent. |
| `grass-patch.glb` | Low-poly grass cluster. | Ground cover on sand/grass patches. |
| `grass-plant.glb` | Broadleaf tropical coastal plant. | Shrubbery beside boulder clusters. |

---

## 🪵 Man-made Props

### 1. Docks, Wharfs & Walkways
| Filename | Description | Riverbank Role |
|---|---|---|
| `structure-platform-dock.glb` | Full wooden pier / shore platform with piles. | Continuous shore spine barrier tile. |
| `structure-platform-dock-small.glb` | Short / damaged pier section. | Ruined dock prop accent. |
| `platform.glb` | Square flat timber platform. | Outpost base / elevated sentry floor. |
| `platform-planks.glb` | Irregular weathered wooden planks. | Shore walkways / debris bridges. |
| `structure-platform.glb` | High timber stilt platform. | Stilted smuggler shacks over water. |
| `structure-platform-small.glb` | Compact stilt platform. | Mooring posts and small watch posts. |

### 2. Barrels, Crates & Containers
| Filename | Description | Gameplay Role |
|---|---|---|
| `barrel.glb` | Wooden banded barrel. | Destructible river obstacles / loot containers. |
| `crate.glb` | Square wooden shipping crate. | River flotsam / dockside cargo. |
| `crate-bottles.glb` | Crate packed with glass rum bottles. | Smuggler cargo / breakable prop. |
| `chest.glb` | Pirate treasure chest with iron trim. | Doubloon reward chest. |
| `bottle.glb` | Single glass rum/grog bottle. | Micro prop on docks / floating debris. |
| `bottle-large.glb` | Glass demijohn / flagon. | Micro prop on dock platforms. |

### 3. Palisades, Fences & Fortifications
| Filename | Description | Gameplay Role |
|---|---|---|
| `structure-fence.glb` | Sharpened log palisade / fence. | Barricade gate / river defensive wall. |
| `structure-fence-sides.glb` | Palisade section with angled end posts. | Flanking barricade boundaries. |
| `structure.glb` | Timber shanty frame / smuggler hut. | Riverbank outpost / ruined village. |
| `structure-roof.glb` | Weathered wooden roof cap. | Outpost shack roof. |
| `castle-wall.glb` | Stone crenelated bastion wall. | Biome 3 fortress embankments. |
| `castle-gate.glb` | Stone archway with portcullis slot. | River fortress checkpoint arch. |
| `castle-door.glb` | Massive reinforced iron-studded timber door. | Gate barricades. |
| `castle-window.glb` | Stone embrasure with iron bars. | Fortress wall dressing. |

### 4. Watchtowers & Sentry Posts
| Filename | Description | Gameplay Role |
|---|---|---|
| `tower-base.glb` | Stone fortress tower base. | High-ground bastion foundation. |
| `tower-base-door.glb` | Stone tower base with wooden door. | Fortress shore entrance. |
| `tower-middle.glb` | Cylindrical stone tower segment. | Modular tower height extension. |
| `tower-middle-windows.glb` | Stone tower section with arrow loops. | Sentry sniper station. |
| `tower-top.glb` | Stone crenelated battlement ring. | Sniper platform on cliffs. |
| `tower-roof.glb` | Conical tiled tower roof. | Tower roof cap. |
| `tower-watch.glb` | Open wooden crow's nest watch platform. | Pirate shoreline lookout post. |
| `tower-complete-small.glb` | Assembled small sentry tower. | Fast-drop bank defense structure. |
| `tower-complete-large.glb` | Assembled grand fortress bastion tower. | Outer cliff monument / landmark. |

### 5. Nautical Rigging, Flags & Tools
| Filename | Description | Gameplay Role |
|---|---|---|
| `mast.glb` | Bare wooden ship mast with yardarms. | River debris / derelict mast sticking out of water. |
| `mast-ropes.glb` | Ship mast with rigging ratlines & shrouds. | Shipwreck obstacle / bank decoration. |
| `flag.glb` | Plain cloth banner on staff. | Neutral outpost marker. |
| `flag-pennant.glb` | Plain naval streamer pennant. | Wind indicator / dock banner. |
| `flag-high.glb` | High-flying standard banner. | Elevated fort banner. |
| `flag-high-pennant.glb` | High-flying pennant streamer. | Fortress spire accent. |
| `flag-pirate.glb` | Jolly Roger pirate flag. | Corsair outpost marker. |
| `flag-pirate-pennant.glb` | Triangular Jolly Roger streamer. | Corsair riverbank marker. |
| `flag-pirate-high.glb` | High-mast Jolly Roger banner. | Boss territory marker. |
| `flag-pirate-high-pennant.glb` | High-mast triangular Jolly Roger banner. | Boss territory marker. |
| `tool-paddle.glb` | Wooden rowboat oar / canoe paddle. | Flotsam debris. |
| `tool-shovel.glb` | Iron spade / grave digger shovel. | Treasure spot marker on sandbars. |

---

## 🎨 Materials, Shaders & Textures

### 1. Texture Sets
- **Kenney Palette:**
  - Path: `res://assets/models/Textures/colormap.png`
  - Dimensions: $256 \times 256$ color palette texture. All 72 Kenney models sample this map.
- **Hero PBR Texture Sets (Albedo, Normal, Metallic/Roughness):**
  - Player Vessels: `dinghy_0/1.jpg`, `the_sloop_*.jpg`, `the_ironclad_*.jpg`, `the_bombard_skiff_*.jpg`
  - Enemy Vessels: `skeleton_rower_0/1.jpg`, `ghost_sloop_0/1.jpg`, `captain_bone-beard’s_twin_frigate_*.jpg`, `boss_war_barge_*.jpg`, `boss_siege_fortress_*.jpg`
  - Crew: `monkey_crew_*.jpg`, `skeleton_crew_0/1.jpg`
  - Weapons: `cannon_*.jpg`, `scattershot_carronade_*.jpg`

### 2. Shaders & Special Materials
- **Water Shader (`res://src/shaders/water_stylized.gdshader`):**
  - Stylized scrolling dual-normal water with depth-based color gradients, refraction, and foam edges.
- **Cockpit Depth Mask Shader (`res://src/shaders/cockpit_depth_mask.gdshader`):**
  - Stencil/depth-clearing pass ensuring water does not render inside open boat cockpits.
  - Material: `res://assets/models/user/vessels/cockpit_depth_mask_mat.tres`
  - Mesh geometry: `res://assets/models/user/vessels/dinghy_cockpit_mask.tres`

---

## 🏞 Riverbank Assembly & Kenney Asset Guide

The procedural riverbank scatter system is governed by [`res://src/gameplay/levels/riverbank_props.gd`](file:///f:/projects/cove-corsair/src/gameplay/levels/riverbank_props.gd). It builds 40-meter recycling chunks along both flanks outside the playable corridor ($|X| > 10.0$).

### 1. Riverbank Layer Composition Matrix

```
[OUTER CLIFF WALL]   rocks-a / rocks-c / tower-complete-large / castle-wall
         ▲
[MID BANK & CANOPY]  palm-detailed-straight / palm-detailed-bend / structure / structure-roof
         ▲
[INNER SHOAL MARGIN] patch-sand / rocks-sand-a / rocks-sand-c / grass-patch
         ▲
[SHORE SPINE BORDER] structure-platform-dock.glb (Continuous Dock Plank Tile)
═══════════════════════════════════════════════════════════════════════════
~~~~~~~~~~~~~~~~~~~~~~~~ RIVER RUNNER PLAYABLE CORRIDOR ~~~~~~~~~~~~~~~~~~~~
```

### 2. Asset Mapping Table for `riverbank_props.gd`

| Generation Role | Constant in `riverbank_props.gd` | Currently Assigned Model(s) | Drop-in Replacement Slot (`res://assets/models/environment/`) |
|---|---|---|---|
| **Shoreline Spine** | `BANK_SEGMENT_PATH` | `structure-platform-dock.glb` | `bank_segment.glb` |
| **Cliff Clusters** | `PROP_ROCK_CLUSTER_PATHS` | `rocks-a.glb`<br>`rocks-b.glb`<br>`rocks-c.glb` | `prop_rock_cluster.glb` |
| **Shoals & Sandbars**| `PROP_SHOAL_PATHS` | `patch-sand.glb`<br>`rocks-sand-a.glb`<br>`rocks-sand-c.glb` | `prop_shoal_cluster.glb` |
| **Palms & Foliage** | `PROP_PALMS_PATHS` | `palm-detailed-straight.glb`<br>`palm-detailed-bend.glb` | `prop_palms.glb` |
| **Outposts & Ruins**| `PROP_DOCK_RUINS_PATHS` | `structure-platform-dock-small.glb`<br>`structure.glb` | `prop_dock_ruins.glb` |

### 3. Art Pass Drop-in Instructions
When custom environmental models are produced:
1. Export `.glb` meshes with baked vertex colors or flat-shaded palette materials.
2. Place the assets in `res://assets/models/environment/` (see [`README.md`](file:///f:/projects/cove-corsair/assets/models/environment/README.md)).
3. Update the corresponding string path constant at the top of `res://src/gameplay/levels/riverbank_props.gd`. No other gameplay or generator logic needs modification.
