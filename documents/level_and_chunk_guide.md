# Cove Corsair - Level & Track Chunk Modification Guide

This guide details how to modify existing runner levels, adjust track speed and biome visuals, add or remove modular track chunks, and calibrate chunk difficulty and obstacle density.

---

## 🗺️ 1. Level Architecture Overview

Levels in Cove Corsair are completely data-driven using Godot 4 [LevelData](file:///f:/projects/cove-corsair/src/data/resources/level_data.gd) resources. 

When a level starts:
1. [GameState](file:///f:/projects/cove-corsair/src/core/game_state.gd) determines the active level number (from `GameState.current_level` or level select).
2. [LevelController](file:///f:/projects/cove-corsair/src/gameplay/levels/level_controller.gd) loads the matching `level_XX.tres` resource.
3. [ChunkAssembler](file:///f:/projects/cove-corsair/src/gameplay/world/chunk_assembler.gd) instantiates the sequence of 50-meter track chunks specified in `chunk_scenes`, aligns them back-to-back along the $-Z$ axis, manages persistent water shaders, and cleans up chunks $+30\text{m}$ behind the camera.

---

## 📁 2. Modifying Existing Levels

All campaign levels reside in:
`src/data/resources/levels/` ([level_01.tres](file:///f:/projects/cove-corsair/src/data/resources/levels/level_01.tres) through [level_45.tres](file:///f:/projects/cove-corsair/src/data/resources/levels/level_45.tres)).

### Level Resource Properties (`LevelData`)

| Property | Type | Default / Example | Purpose |
| :--- | :--- | :--- | :--- |
| `level_id` | `int` | `1` | Numerical index of the level. |
| `level_title` | `String` | `"Level 1: Smuggler's Run"` | Displayed on the HUD and River Map. |
| `biome_name` | `String` | `"tropical"`, `"bayou"`, `"brimstone"` | Controls riverbank colors, water shaders, music, and environment assets. |
| `base_scroll_speed` | `float` | `6.5` to `12.0` | Forward river speed ($m/s$). Increase to heighten player reaction pressure. |
| `completion_doubloon_reward` | `int` | `50` to `500` | Doubloons granted when defeating the boss or completing the track. |
| `chunk_scenes` | `Array[PackedScene]` | Array of chunk scenes | The ordered sequence of 50m track chunks assembled end-to-end. |
| `river_width_world` | `float` | `12.0` | Playable width from $X = -6.0$ to $X = +6.0$. |
| `horizon_texture` | `Texture2D` | `horizon_smugglers_run.png` | Background panoramic texture. |
| `water_albedo` | `Color` | `Color(0.08, 0.58, 0.82, 0.88)` | Surface tint applied to the river water shader. |
| `fog_color` / `fog_density` | `Color` / `float` | Atmospheric haze settings for mood and biome transitions. |

### How to Edit a Level:
1. Open the Godot Editor.
2. In the **FileSystem** dock, navigate to `res://src/data/resources/levels/`.
3. Double-click the level resource (e.g., `level_01.tres`).
4. In the **Inspector**, modify `base_scroll_speed`, `biome_name`, or the `chunk_scenes` list.
5. Save with `Ctrl + S`.

*(You can also edit `.tres` files directly in any text editor, as they are human-readable text).*

---

## 🧱 3. Adding, Removing & Reordering Chunks

Every runner segment is an individual 50-meter modular chunk inheriting from [BaseTrackChunk](file:///f:/projects/cove-corsair/src/gameplay/chunks/base_track_chunk.gd).

### Available Modular Chunks (`src/gameplay/chunks/`)

| Chunk Scene | Type | Typical Role |
| :--- | :--- | :--- |
| [chunk_warmup.tscn](file:///f:/projects/cove-corsair/src/gameplay/chunks/chunk_warmup.tscn) | Standard | Low threat, starter doubloon lines, gentle barrel obstacles, intro gates. |
| [chunk_mine_gauntlet.tscn](file:///f:/projects/cove-corsair/src/gameplay/chunks/chunk_mine_gauntlet.tscn) | Hazard | Sea mine slalom corridors, tight maneuvering lanes, explosive barrels. |
| [chunk_barricade_siege.tscn](file:///f:/projects/cove-corsair/src/gameplay/chunks/chunk_barricade_siege.tscn) | Combat | High-durability wooden barricade walls, enemy rower waves, side docks. |
| [chunk_boss_intro_buffer.tscn](file:///f:/projects/cove-corsair/src/gameplay/chunks/chunk_boss_intro_buffer.tscn) | Buffer | Open water 50m runway to prepare for boss arena transitions. |
| [chunk_boss_ironjaw.tscn](file:///f:/projects/cove-corsair/src/gameplay/chunks/chunk_boss_ironjaw.tscn) | Boss Arena | Spawns Boss War Barge (Ironjaw) with boundary fortresses. |
| [chunk_boss_phantom_dredge.tscn](file:///f:/projects/cove-corsair/src/gameplay/chunks/chunk_boss_phantom_dredge.tscn) | Boss Arena | Spawns Phantom Dredge submarine boss. |
| [chunk_boss_siege_fortress.tscn](file:///f:/projects/cove-corsair/src/gameplay/chunks/chunk_boss_siege_fortress.tscn) | Boss Arena | Spawns Siege Fortress boss with side turrets. |
| [chunk_boss_bonebeard.tscn](file:///f:/projects/cove-corsair/src/gameplay/chunks/chunk_boss_bonebeard.tscn) | Boss Arena | Spawns Captain Bone-Beard's twin-frigate boss. |

### To Add or Remove Chunks from a Level:
In Godot's Inspector for `level_XX.tres`:
- **Add Chunk**: Expand `Chunk Scenes`, click **Add Element**, and drag a chunk `.tscn` into the new slot.
- **Remove Chunk**: Click the drop-down / delete icon next to the chunk element index.
- **Reorder**: Drag the handle next to an element index up or down.
- **Adjust Level Length**: Each non-boss chunk adds 50 meters of distance before the boss encounter. A standard 6-chunk level is ~250m before the boss arena.

---

## ⚔️ 4. Changing Chunk Strength & Difficulty

Chunk difficulty is controlled by the entities and density placed within the chunk scene itself.

### 1. Enemy Formations & Strength
Inside any chunk `.tscn`, expand the `Entities` node:
- **Mob Health & Speed**: Select an [enemy_mob.tscn](file:///f:/projects/cove-corsair/src/gameplay/enemies/enemy_mob.tscn) instance and edit:
  - `max_hp` / `current_hp`: (e.g. standard rower = 2 HP, armored rower = 4 HP).
  - `forward_speed`: Speed moving downriver towards the player.
- **Swapping Enemy Archetypes**: Replace basic rowers with specialized enemy craft:
  - [enemy_iron_gunner.tscn](file:///f:/projects/cove-corsair/src/gameplay/enemies/enemy_iron_gunner.tscn) — Fires long-range cannonballs.
  - [enemy_grave_skiff.tscn](file:///f:/projects/cove-corsair/src/gameplay/enemies/enemy_grave_skiff.tscn) — High agility dart thrower.
  - [enemy_tide_cutter.tscn](file:///f:/projects/cove-corsair/src/gameplay/enemies/enemy_tide_cutter.tscn) — Fast ramming craft.
  - [enemy_brimstone_raft.tscn](file:///f:/projects/cove-corsair/src/gameplay/enemies/enemy_brimstone_raft.tscn) — Explodes on destruction or contact.
  - [enemy_mini_boss_harvester.tscn](file:///f:/projects/cove-corsair/src/gameplay/enemies/enemy_mini_boss_harvester.tscn) / [enemy_mini_boss_bombard.tscn](file:///f:/projects/cove-corsair/src/gameplay/enemies/enemy_mini_boss_bombard.tscn) — Formidable elite threats with high HP pools and broadside attacks.

### 2. Obstacle & Hazard Density
- **Destructible Barrels** ([destructible_barrel.tscn](file:///f:/projects/cove-corsair/src/gameplay/obstacles/destructible_barrel.tscn)):
  - Increase `max_hp` to require more cannon shots to break.
  - Set `obstacle_type = 2` for explosive powder kegs that damage adjacent targets.
- **Sea Mines** ([hazard_sea_mine.tscn](file:///f:/projects/cove-corsair/src/gameplay/obstacles/hazard_sea_mine.tscn)):
  - Instant hull damage if hit. Group them into narrow gates to force precision steering.
- **Barricade Walls** ([barricade_wall.tscn](file:///f:/projects/cove-corsair/src/gameplay/obstacles/barricade_wall.tscn)):
  - Wooden blockades that span 1–3 lanes, requiring concentrated firepower or mortar bombardment to breach.

### 3. Multiplier Gates
Select [multiplier_gate.tscn](file:///f:/projects/cove-corsair/src/gameplay/obstacles/multiplier_gate.tscn) instances to tweak progression payouts:
- `value`: Numerical bonus (e.g. `1`, `2`, `3`).
- `gate_action`: String action applied when passed:
  - `"add_fleet_1"`: Spawns $+1$ follower ship.
  - `"add_fleet_2"`: Spawns $+2$ follower ships.
  - `"multiply_fleet_2"`: Doubles current follower fleet.
- `custom_text`: The billboard label displayed above the gate (e.g. `"+1"`, `"+2"`, `"x2"`).

---

## 🛠️ 5. Creating a Brand New Custom Chunk

1. In Godot, click **Scene > New Inherited Scene...** and choose [base_track_chunk.gd](file:///f:/projects/cove-corsair/src/gameplay/chunks/base_track_chunk.gd).
2. Ensure the node hierarchy matches the standard contract:
   ```text
   CustomChunk (Node3D, script = BaseTrackChunk)
   ├── ChunkStart (Marker3D at 0, 0, 0)
   ├── ChunkEnd (Marker3D at 0, 0, -50)
   ├── Banks (Node3D)
   │   ├── PalmTrees, Rocks, Docks (X <= -7.0 or X >= +7.0)
   └── Entities (Node3D)
       ├── Doubloons, Chests, Barrels, Mines
       ├── Enemies, Multiplier Gates (-5.0 <= X <= +5.0, 0 >= Z >= -50.0)
   ```
3. Set `chunk_id` in the Inspector (e.g. `"serpent_slalom"`).
4. Save the scene into `res://src/gameplay/chunks/chunk_serpent_slalom.tscn`.
5. Open any `level_XX.tres` and insert your new chunk into the `chunk_scenes` array.
