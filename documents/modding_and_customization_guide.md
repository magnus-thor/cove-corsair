# Cove Corsair - Master Modding & Customization Guide

Welcome to the comprehensive modding and configuration reference for **Cove Corsair**. Cove Corsair uses a modular, data-driven architecture built on Godot 4 custom resources (`.tres`) and modular scene prefabs (`.tscn`).

---

## 📚 Specialized Guides Index

Detailed step-by-step walkthroughs have been organized into the following specialized documents:

1. 🗺️ **[Level & Track Chunk Modification Guide](file:///f:/projects/cove-corsair/documents/level_and_chunk_guide.md)**
   - Modifying level parameters (scroll speed, biome palette, rewards, title).
   - Adding, removing, and reordering 50m track chunks in `chunk_scenes`.
   - Tuning chunk difficulty (mob stats, obstacle density, barricades, mines, multiplier gates).
   - Creating new custom modular chunks adhering to `BaseTrackChunk`.

2. 👹 **[Boss & Ammo Modification Guide](file:///f:/projects/cove-corsair/documents/boss_and_ammo_guide.md)**
   - Editing boss statistics (health, weave speeds, attack intervals, add counts).
   - Switching boss visual presentations (3D GLB meshes vs. 2D billboard sprites).
   - Customizing boss projectiles and converting enemy ammo to 2D sprites.
   - Creating unique projectile scenes per boss encounter.

3. ⛵ **[Vessel, Crew & Weapon Customization Guide](file:///f:/projects/cove-corsair/documents/vessel_and_crew_guide.md)**
   - Configuring player vessels (`ShipData`) and 3-tier upgrade trees.
   - Adjusting hardpoint sockets, weapon transforms, and tier activations.
   - Tuning autonomous deck crew companions (`CrewData`) and targeting logic.
   - Customizing naval ammunition (`AmmoData`), sprite visuals, and splash radii.

---

## ⚡ Quick Cheat Sheet

| I want to... | Where to go | File / Resource |
| :--- | :--- | :--- |
| **Change a level's speed or biome** | Godot Inspector / Text Editor | `src/data/resources/levels/level_XX.tres` |
| **Add/remove chunks in a level** | Edit `chunk_scenes` array | `src/data/resources/levels/level_XX.tres` |
| **Create a new chunk layout** | Inherit from `BaseTrackChunk` | `src/gameplay/chunks/chunk_<name>.tscn` |
| **Make obstacles or mobs tougher** | Edit child nodes in chunk | `src/gameplay/chunks/chunk_<name>.tscn` |
| **Change a boss's HP or attacks** | Edit root node exported vars | `src/gameplay/enemies/boss_<name>.tscn` |
| **Change boss ammo visual/sprite** | Edit scene or assign new prefab | `src/gameplay/projectiles/enemy_cannonball.tscn` |
| **Edit player ship stats or tiers** | Edit `ShipData` resource | `src/data/resources/user_vessels/<ship>.tres` |
| **Change crew throw range or ammo** | Edit `CrewData` resource | `src/data/resources/user_crew/<crew>.tres` |
| **Assign custom 2D sprite to ammo** | Set `sprite_texture` property | `src/data/resources/user_ammo/<ammo>.tres` |
