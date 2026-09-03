# Cove Corsair - Level Systems & Biome Architecture

This directory contains technical specifications for all campaign levels in **Cove Corsair**. Each document details the biome design, pacing curve, entity timeline, hazard mechanics, starting vessel loadout, and boss battle specs.

---

## Campaign Level Overview

| Level ID | Level Name | Biome Type | Target Distance | Scroll Speed | Starting Vessel | Boss Encounter | Primary Hazards |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Level 1** | [Smuggler's Run](file:///f:/projects/cove-corsair/documents/levels/level_01_smugglers_run.md) | `smugglers_run` (Coastal Island) | $250\text{m}$ | $10.0\text{ m/s}$ | The Dinghy (1 HP) | **Captain Ironjaw's War-Barge** ($220\text{ HP}$) | Reef Outcrops, Spiked Mines, Barricades |
| **Level 2** | [Black Tide Bayou](file:///f:/projects/cove-corsair/documents/levels/level_02_black_tide_bayou.md) | `black_tide_bayou` (Murky Swamp) | $280\text{m}$ | $10.0\text{ m/s}$ | The Sloop (1 HP) | **The Phantom Dredge** ($750\text{ HP}$) | Biogas Pods, Grave Skiffs, Tide Cutters |
| **Level 3** | [Brimstone Bastion](file:///f:/projects/cove-corsair/documents/levels/level_03_brimstone_bastion.md) | `brimstone_bastion` (Volcanic Fortress) | $320\text{m}$ | $10.0\text{ m/s}$ | The Ironclad (2 HP) | **Brimstone Siege Fortress** ($800\text{ HP}$) | Thermal Geysers, Iron Gunners, Bombarders |

---

## Core Level Architecture

Levels in **Cove Corsair** use a **strictly deterministic timeline engine**. 
- Level data is defined via strongly typed `LevelData` resources (`src/data/level_data.gd`).
- Spawns are scheduled as `SpawnEvent` instances (`src/data/spawn_event.gd`) triggered at specific distance milestones ($Z$ coordinate progression).
- The `LevelController` (`src/gameplay/levels/level_controller.gd`) processes the timeline queue, spawning obstacles, enemy mobs, multiplier gates, hazards, and bosses without random generation.

### Detailed Level Specifications
1. [Level 1: Smuggler's Run Setup Specification](file:///f:/projects/cove-corsair/documents/levels/level_01_smugglers_run.md)
2. [Level 2: Black Tide Bayou Setup Specification](file:///f:/projects/cove-corsair/documents/levels/level_02_black_tide_bayou.md)
3. [Level 3: Brimstone Bastion Setup Specification](file:///f:/projects/cove-corsair/documents/levels/level_03_brimstone_bastion.md)
