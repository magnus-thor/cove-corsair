# Cove Corsair - Level Systems & Biome Architecture

This directory contains technical specifications for the **45-level campaign** in **Cove Corsair**, organized across three biomes with calibrated difficulty scaling, dynamic barricade progression, and milestone boss battles every 5 levels.

---

## 🗺️ Campaign Architecture (45 Levels Across 3 Biomes)

```
[ Levels 1–15: Tropical Reef ] ──► [ Levels 16–30: Murky Bayou ] ──► [ Levels 31–45: Volcanic Brimstone ]
  Scroll Speed: 8.0 – 9.5 m/s        Scroll Speed: 9.5 – 11.5 m/s       Scroll Speed: 11.5 – 13.0 m/s
  Doubloons: 100 – 450               Doubloons: 500 – 750               Doubloons: 800 – 1,200
  Clear sunny waters, sandy shoals   Atmospheric swamp fog (0.015)      Intense heat fog (0.02), crimson glow
```

---

## 👑 Milestone Boss Rotation (Every 5 Levels)

| Milestone | Level Title | Biome | Boss Encounter | Boss Class / Script | Encounter Mechanics |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Level 5** | Black Tide Abyss | Tropical / Bayou | **The Phantom Dredge** ($500\text{ HP}$) | [`boss_phantom_dredge.gd`](file:///f:/projects/cove-corsair/src/gameplay/enemies/boss_phantom_dredge.gd) | Spectral paddlewheel shockwaves, submergence phases, and frenzy rush. |
| **Level 10** | Skull Reef Pass | Tropical | **Captain Ironjaw** ($220\text{ HP}$) | [`boss_war_barge.gd`](file:///f:/projects/cove-corsair/src/gameplay/enemies/boss_war_barge.gd) | Armored war-barge with swivel turrets and exposed boiler core. |
| **Level 15** | Bone-Beard's Outpost | Tropical | **Captain Bone-Beard** ($500\text{ HP}$) | [`boss_bone_beard.gd`](file:///f:/projects/cove-corsair/src/gameplay/enemies/boss_bone_beard.gd) | Twin frigate catamaran spawning skeleton rowers and cursed skull fire. |
| **Level 20** | Citadel of Iron | Bayou | **The Siege Fortress** ($800\text{ HP}$) | [`boss_siege_fortress.gd`](file:///f:/projects/cove-corsair/src/gameplay/enemies/boss_siege_fortress.gd) | Massive floating fortress with dual mortar turrets and molten core meltdown. |
| **Level 25** | Phantom Trench | Bayou | **The Phantom Dredge** ($650\text{ HP}$) | [`boss_phantom_dredge.gd`](file:///f:/projects/cove-corsair/src/gameplay/enemies/boss_phantom_dredge.gd) | Elevated spectral speed, rapid ghost submersion, and toxic shockwaves. |
| **Level 30** | Bone-Beard's Armada | Bayou | **Captain Bone-Beard** ($750\text{ HP}$) | [`boss_bone_beard.gd`](file:///f:/projects/cove-corsair/src/gameplay/enemies/boss_bone_beard.gd) | High-speed cursed broadside salvos with dense minion wave defense. |
| **Level 35** | Ironjaw's Crucible | Brimstone | **Captain Ironjaw** ($400\text{ HP}$) | [`boss_war_barge.gd`](file:///f:/projects/cove-corsair/src/gameplay/enemies/boss_war_barge.gd) | Fortified volcanic war barge with rapid-fire swivels and lava wave assistance. |
| **Level 40** | Molten Bulwark | Brimstone | **The Siege Fortress** ($1,200\text{ HP}$) | [`boss_siege_fortress.gd`](file:///f:/projects/cove-corsair/src/gameplay/enemies/boss_siege_fortress.gd) | Multi-turret mortar siege fortress with volcanic geysers and lava river surges. |
| **Level 45** | Bone-Beard's Throne | Brimstone | **Captain Bone-Beard (Final)** ($1,000\text{ HP}$) | [`boss_bone_beard.gd`](file:///f:/projects/cove-corsair/src/gameplay/enemies/boss_bone_beard.gd) | Final campaign throne encounter featuring maximum wave pressure and skull salvos. |

---

## ⚡ Tactical Bottlenecks & Level Design Highlights

* **Level 16 ("The Iron Wall"):** Introduces heavy sequential barricade walls testing high burst DPS and Ironclad / Bombard Skiff loadouts.
* **Level 19 ("Devil's Slalom"):** Dense sea mine gauntlet with narrow gaps testing The Dinghy's responsive agility and small collision footprint.
* **Dynamic Barricades:** All barricade walls scale dynamically ($2\text{ HP}$ in L1–3, $6\text{ HP}$ in L4–10, $12\text{ HP}$ in L11–25, $20\text{ HP}$ in L26+).

---

## ⚙️ Automated Campaign Level Pipeline

All levels from Level 13 to Level 45 are generated deterministically using [`src/tools/generate_campaign_levels.gd`](file:///f:/projects/cove-corsair/src/tools/generate_campaign_levels.gd):

```bash
# Execute headless campaign level generation
godot --headless --script src/tools/generate_campaign_levels.gd
```

To run the automated verification suite confirming all 45 levels load correctly and adhere to chunk constraints:

```bash
godot --headless --scene src/test_campaign_expansion.tscn
```
