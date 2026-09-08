# Modular Environment Asset Slots & Natural Shoreline Architecture

This directory is the designated home for modular low-poly environment meshes used by the procedural riverbank scatter system in [`res://src/gameplay/levels/riverbank_props.gd`](file:///f:/projects/cove-corsair/src/gameplay/levels/riverbank_props.gd).

The environment generator employs a **Layer 2 Organic 3-Tier Natural Shoreline System**, replacing obsolete continuous dock piers with natural sandy shoals, leaning palm canopies, towering rock formations, and rare maritime flavor accents.

---

## 🌴 Asset Slots & Active Model Manifest

| Shoreline Layer | Target Slot / Role | Constant in `riverbank_props.gd` | Active Kenney Asset(s) (`res://assets/models/`) | Lateral Offset ($X$) |
|---|---|---|---|---|
| **Tier 1: Beach & Sand Shoals** | Low-poly sand patches & foliage | `SHOAL_SAND_PATHS` | `patch-sand.glb`<br>`patch-sand-foliage.glb` | $\approx \pm 4.0\text{m}$ to $\pm 4.5\text{m}$ |
| **Tier 1: Shoreline Boulders** | Overlapping water-edge rocks | `SHORE_ROCKS_PATHS` | `rocks-sand-a.glb`<br>`rocks-sand-b.glb`<br>`rocks-sand-c.glb` | $\approx \pm 4.0\text{m}$ to $\pm 4.5\text{m}$ |
| **Tier 2: Canopy & Overhangs** | Bent palms leaning toward river | `PALM_BEND_PATHS` | `palm-detailed-bend.glb`<br>`palm-bend.glb` | $\approx \pm 5.0\text{m}$ (Clearance $> 4.5\text{m}$) |
| **Tier 2: Upright Palms** | Tall background palms | `PALM_STRAIGHT_PATH` | `palm-detailed-straight.glb` | $\approx \pm 5.0\text{m}$ |
| **Tier 2: Understory Tufts** | Understory grass & plant tufts | `FOLIAGE_TUFT_PATH` | `grass-plant.glb` | $\approx \pm 4.8\text{m}$ to $\pm 5.2\text{m}$ |
| **Tier 3: Cliff Formations** | Stacked towering cliff ridge | `CLIFF_ROCK_PATHS` | `rocks-a.glb`<br>`rocks-b.glb`<br>`rocks-c.glb` | $\approx \pm 6.5\text{m}$ to $\pm 8.5\text{m}$ |
| **Rare Flavor: Shipwrecks** | Stranded shattered galleon hull | `FLAVOR_SHIPWRECK` | `ship-wreck.glb` | Outer bank |
| **Rare Flavor: Ruined Docks** | Isolated decayed dock section | `FLAVOR_DOCK_RUIN` | `structure-platform-dock-small.glb` | Outer bank |
| **Rare Flavor: Barrels** | Weathered flotsam cargo barrels | `FLAVOR_BARREL` | `barrel.glb` | Outer shoreline |

---

## 🔄 Drop-in Asset Replacement Instructions

When custom stylized environment meshes are ready:
1. Export clean low-poly `.glb` models matching the scale and orientation standards.
2. Place the assets into `res://assets/models/environment/`.
3. Update the corresponding string path constant(s) in `res://src/gameplay/levels/riverbank_props.gd` (`SHOAL_SAND_PATHS`, `SHORE_ROCKS_PATHS`, `PALM_BEND_PATHS`, `CLIFF_ROCK_PATHS`, etc.).
4. No additional gameplay or generator logic needs modification.

---

## ⚙️ Mobile Performance & Shading Guidelines

All environment meshes must adhere to mobile batching standards:
* **Shared Color Palette Texture:** Use `res://assets/models/Textures/colormap.png`.
* **Culling Mode:** `cull_mode = BaseMaterial3D.CULL_BACK` (no redundant backfaces).
* **Lighting & Shadows:** Scenery meshes must have runtime shadows disabled (`SHADOW_CASTING_SETTING_OFF`). Zero realtime point lights.
* **Vertical Clearance:** Bent palms leaning over the river must maintain at least $4.5\text{m}$ vertical clearance above the water plane to prevent clipping with tall ship rigs (such as The Ironclad).
