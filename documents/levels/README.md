# Cove Corsair - Campaign Level Systems & Master Specifications

This directory contains technical specifications for all **45 campaign levels** in **Cove Corsair**, organized across three distinct biomes with calibrated difficulty scaling, dynamic barricade progression, milestone boss encounters, and full economic breakdowns.

---

## 🛠️ In-Game Level Tuning & Modding System

Every level in **Cove Corsair** is bidirectionally linked between its Markdown documentation file in this directory and its Godot runtime resource (`.tres`) in [`src/data/resources/levels/`](file:///f:/projects/cove-corsair/src/data/resources/levels/).

### How to Change Maximum Coins or Level Parameters:
1. Open the target level's document (e.g. [`level_01_smugglers_run.md`](file:///f:/projects/cove-corsair/documents/levels/level_01_smugglers_run.md)).
2. In the YAML frontmatter block at the very top, edit the parameter:
   ```yaml
   ---
   level_id: 1
   level_title: "Level 1: Smuggler's Run"
   base_scroll_speed: 6.5
   completion_doubloon_reward: 75    # <-- Change maximum clear reward here
   river_width_world: 12.0
   ---
   ```
3. Run the synchronization tool via your preferred method:
   * **Windows Quick-Run:** Double-click [`sync_levels.bat`](file:///f:/projects/cove-corsair/sync_levels.bat) (or run `.\sync_levels.bat` in terminal).
   * **Python:** Run `python src/tools/sync_level_docs.py` (add `--dry-run` to preview changes).
   * **Godot Headless:** Run `godot --headless --script src/tools/sync_level_docs.gd`.
4. The corresponding `.tres` resource files are updated instantly and your new values take effect immediately upon playing the level.

---

## 💰 Maximum Coin Calculation & Economy Breakdown

Gold in each level is derived from four distinct components:
1. **Floating Doubloons:** Static coins floating in the channel ($1\text{ coin}$ each, magnetized by fleet prows).
2. **Destructible Barrels & Sinks:** Wooden barrels ($1\text{ coin}$), explosive fuse barrels, and sunk enemy vessels ($2\text{-}6\text{ coins}$).
3. **Calibrated Hazard Pockets (Level 5+):** Rare bonus chests ($15\text{-}20\text{ coins}$) tucked into hazardous sea mine corridors and barricade flanks (guarded by single-chest per run limit).
4. **Guaranteed Level Clear Bonus:** Configured via `completion_doubloon_reward` in the level resource.

$$\text{Base Maximum Coins} = \text{In-Run Drops (Pickups + Barrels + Sinks + Hazard Chests)} + \text{Clear Bonus}$$
$$\text{2X Ad Multiplier Total} = 2 \times \text{Base Maximum Coins}$$

> 💡 **Balanced Progression & Vessel Acquisition:**
> Pacing is strictly calibrated to prevent runaway inflation and ensure ship unlocks and tier upgrades feel meaningful and earned. Total base career gold across all 45 levels is ~15,200 🪙 (~30,400 🪙 with 2X), perfectly pacing Dinghy, Sloop, Bombard Skiff, and Ironclad upgrades.

On the **Settlement Screen**, players can tap **[ ✦ CLAIM 2X BONUS DOUBLOONS ]** to double both their in-run earnings and clear bonus.

---

## 🗺️ Master Campaign Index (Levels 1–45)

### Cove 1: Tropical Archipelago (Levels 1–15)
*Sunny shoals, crystal turquoise waters (`0.0` fog), driftwood barricades ($2\text{-}8\text{ HP}$), and Captain Ironjaw's armada.*

| Level | Document | Speed | Barricade HP | Boss Encounter | Clear Bonus | Base Total | 2X Max Gold | Recommended Ship |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **01** | [Level 01: Smuggler's Run](file:///f:/projects/cove-corsair/documents/levels/level_01_smugglers_run.md) | $6.5\text{ m/s}$ | 2 HP | **None** (Level ends on dock crossing) | 50 🪙 | ~75 🪙 | **~150 🪙** | Dinghy T1 |
| **02** | [Level 02: Palm Shallows](file:///f:/projects/cove-corsair/documents/levels/level_02_palm_shallows.md) | $7.0\text{ m/s}$ | 2 HP | **Raider Sloop** (HP 30, slow forward cannon) | 65 🪙 | ~100 🪙 | **~200 🪙** | Dinghy T1 |
| **03** | [Level 03: Serpent's Reach](file:///f:/projects/cove-corsair/documents/levels/level_03_brimstone_bastion.md) | $7.2\text{ m/s}$ | 3 HP | **Raider Sloop** (HP 40, forward cannon) | 75 🪙 | ~115 🪙 | **~230 🪙** | Dinghy T2 |
| **04** | [Level 04: Sunken Reefs](file:///f:/projects/cove-corsair/documents/levels/level_04_smugglers_nightmare.md) | $7.5\text{ m/s}$ | 3 HP | **None** (Hazard slalom focus) | 85 🪙 | ~130 🪙 | **~260 🪙** | Dinghy T2 |
| **05** | [Level 05: Ironjaw's Scout](file:///f:/projects/cove-corsair/documents/levels/level_05_black_tide_abyss.md) | $7.8\text{ m/s}$ | 4 HP | **Ironjaw Scout** (HP 55, alternating broadside) | 100 🪙 | ~150 🪙 | **~300 🪙** | Dinghy T2 / Sloop T1 |
| **06** | [Level 06: Corsair's Cut](file:///f:/projects/cove-corsair/documents/levels/level_06_brimstone_inferno.md) | $8.0\text{ m/s}$ | 4 HP | **None** (Mine gauntlet focus) | 90 🪙 | ~140 🪙 | **~280 🪙** | Sloop T1 |
| **07** | [Level 07: Bone Cay](file:///f:/projects/cove-corsair/documents/levels/level_07_bone_cay.md) | $8.2\text{ m/s}$ | 5 HP | **Raider Brig** (HP 65, twin bow cannons) | 100 🪙 | ~155 🪙 | **~310 🪙** | Sloop T1 |
| **08** | [Level 08: Pelican Point](file:///f:/projects/cove-corsair/documents/levels/level_08_pelican_point.md) | $8.4\text{ m/s}$ | 5 HP | **None** (Barricade siege test) | 105 🪙 | ~165 🪙 | **~330 🪙** | Sloop T1 |
| **09** | [Level 09: Sharktooth Shoal](file:///f:/projects/cove-corsair/documents/levels/level_09_sharktooth_shoal.md) | $8.6\text{ m/s}$ | 6 HP | **Twin Skiff Chiefs** (HP 40 each) | 115 🪙 | ~180 🪙 | **~360 🪙** | Sloop T2 |
| **10** | [Level 10: Captain Ironjaw](file:///f:/projects/cove-corsair/documents/levels/level_10_captain_ironjaw.md) | $8.8\text{ m/s}$ | 6 HP | **Captain Ironjaw** (HP 120, broadsides + grape) | 145 🪙 | ~220 🪙 | **~440 🪙** | Sloop T2 / Dinghy T3 |
| **11** | [Level 11: Dead Calm Pass](file:///f:/projects/cove-corsair/documents/levels/level_11_dead_calm_pass.md) | $9.0\text{ m/s}$ | 6 HP | **None** (Precision mine corridors) | 120 🪙 | ~190 🪙 | **~380 🪙** | Dinghy T3 |
| **12** | [Level 12: Smuggler's Gate](file:///f:/projects/cove-corsair/documents/levels/level_12_smugglers_gate.md) | $9.0\text{ m/s}$ | 8 HP | **Ironclad Escort** (HP 140, heavy ram) | 125 🪙 | ~200 🪙 | **~400 🪙** | Bombard T1 |
| **13** | [Level 13: Coral Labyrinth](file:///f:/projects/cove-corsair/documents/levels/level_13_coral_labyrinth.md) | $9.2\text{ m/s}$ | 8 HP | **None** (Switchback steering maze) | 130 🪙 | ~210 🪙 | **~420 🪙** | Dinghy T3 |
| **14** | [Level 14: Siren's Shoals](file:///f:/projects/cove-corsair/documents/levels/level_14_sirens_shoals.md) | $9.4\text{ m/s}$ | 8 HP | **Raider Flagship** (HP 160, mortar arcs) | 140 🪙 | ~225 🪙 | **~450 🪙** | Bombard T1 |
| **15** | [Level 15: Bonebeard's Outpost](file:///f:/projects/cove-corsair/documents/levels/level_15_bonebeards_outpost.md) | $9.5\text{ m/s}$ | 8 HP | **Ironjaw Elite** (HP 220, rapid fire + mines) | 175 🪙 | ~270 🪙 | **~540 🪙** | Bombard T1 / Sloop T3 |

---

### Cove 2: Black Tide Bayou (Levels 16–30)
*Atmospheric marsh fog (`0.015 - 0.022`), toxic Biogas pods, reinforced oak walls ($10\text{-}14\text{ HP}$), and The Phantom Dredge.*

| Level | Document | Speed | Barricade HP | Boss Encounter | Clear Bonus | Base Total | 2X Max Gold | Recommended Ship |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **16** | [Level 16: The Iron Wall](file:///f:/projects/cove-corsair/documents/levels/level_16_the_iron_wall.md) | $9.5\text{ m/s}$ | 12 HP | **None** (Triple fortified wall bottleneck) | 160 🪙 | ~250 🪙 | **~500 🪙** | Bombard T1 / Ironclad T1 |
| **17** | [Level 17: Murkwater Run](file:///f:/projects/cove-corsair/documents/levels/level_17_murkwater_run.md) | $9.6\text{ m/s}$ | 10 HP | **Ghost Sloop Ambush** (HP 150) | 165 🪙 | ~260 🪙 | **~520 🪙** | Sloop T2 |
| **18** | [Level 18: Witch's Channel](file:///f:/projects/cove-corsair/documents/levels/level_18_witchs_channel.md) | $9.8\text{ m/s}$ | 10 HP | **None** (Submerged hazards & snags) | 170 🪙 | ~270 🪙 | **~540 🪙** | Dinghy T3 |
| **19** | [Level 19: Devil's Slalom](file:///f:/projects/cove-corsair/documents/levels/level_19_devils_slalom.md) | $10.0\text{ m/s}$ | 10 HP | **None** (2.1m ultra-tight mine gauntlet) | 175 🪙 | ~280 🪙 | **~560 🪙** | Dinghy T3 |
| **20** | [Level 20: Citadel of Iron](file:///f:/projects/cove-corsair/documents/levels/level_20_citadel_of_iron.md) | $10.0\text{ m/s}$ | 12 HP | **Siege Fortress** (HP 280, mortar + shields) | 210 🪙 | ~325 🪙 | **~650 🪙** | Bombard T2 / Ironclad T1 |
| **21** | [Level 21: Serpent's Nest](file:///f:/projects/cove-corsair/documents/levels/level_21_serpents_nest.md) | $10.2\text{ m/s}$ | 10 HP | **None** (Flanking shore turrets) | 180 🪙 | ~290 🪙 | **~580 🪙** | Sloop T3 |
| **22** | [Level 22: Gloom Mire](file:///f:/projects/cove-corsair/documents/levels/level_22_gloom_mire.md) | $10.3\text{ m/s}$ | 12 HP | **Bayou Marauder** (HP 180, explosive barrels) | 185 🪙 | ~300 🪙 | **~600 🪙** | Ironclad T2 |
| **23** | [Level 23: Rotwood Reach](file:///f:/projects/cove-corsair/documents/levels/level_23_rotwood_reach.md) | $10.5\text{ m/s}$ | 12 HP | **None** (Barricades paired with sea mines) | 190 🪙 | ~310 🪙 | **~620 🪙** | Sloop T3 |
| **24** | [Level 24: Blackwater Hollow](file:///f:/projects/cove-corsair/documents/levels/level_24_blackwater_hollow.md) | $10.6\text{ m/s}$ | 12 HP | **Heavy Turtle Barge** (HP 220, armored prow) | 195 🪙 | ~320 🪙 | **~640 🪙** | Bombard T2 |
| **25** | [Level 25: Phantom Trench](file:///f:/projects/cove-corsair/documents/levels/level_25_phantom_trench.md) | $10.8\text{ m/s}$ | 12 HP | **Phantom Dredge** (HP 320, geysers + tracking orb) | 240 🪙 | ~375 🪙 | **~750 🪙** | Sloop T3 / Bombard T2 |
| **26** | [Level 26: Stagnant Cut](file:///f:/projects/cove-corsair/documents/levels/level_26_stagnant_cut.md) | $10.9\text{ m/s}$ | 14 HP | **None** (Massive drift log-jams) | 210 🪙 | ~340 🪙 | **~680 🪙** | Ironclad T2 |
| **27** | [Level 27: Banshee Bog](file:///f:/projects/cove-corsair/documents/levels/level_27_banshee_bog.md) | $11.0\text{ m/s}$ | 12 HP | **None** (Current shifts & mine nets) | 215 🪙 | ~350 🪙 | **~700 🪙** | Dinghy T3 |
| **28** | [Level 28: Dead Man's Bayou](file:///f:/projects/cove-corsair/documents/levels/level_28_dead_mans_bayou.md) | $11.2\text{ m/s}$ | 14 HP | **Ghost Armada Chief** (HP 250, twin broadsides) | 220 🪙 | ~360 🪙 | **~720 🪙** | Bombard T3 |
| **29** | [Level 29: Voodoo Crossing](file:///f:/projects/cove-corsair/documents/levels/level_29_voodoo_crossing.md) | $11.3\text{ m/s}$ | 14 HP | **None** (Armored raft formations) | 225 🪙 | ~370 🪙 | **~740 🪙** | Sloop T3 |
| **30** | [Level 30: Bonebeard's Armada](file:///f:/projects/cove-corsair/documents/levels/level_30_bonebeards_armada.md) | $11.5\text{ m/s}$ | 14 HP | **Bonebeard Ironclad** (HP 450, ramming + flak) | 290 🪙 | ~450 🪙 | **~900 🪙** | Bombard T3 / Ironclad T2 |

---

### Cove 3: Volcanic Brimstone (Levels 31–45)
*Boiling lava streams (`0.02 - 0.025` ash haze), thermal geysers, iron palisades ($16\text{-}20\text{ HP}$), and Bone-Beard's Throne.*

| Level | Document | Speed | Barricade HP | Boss Encounter | Clear Bonus | Base Total | 2X Max Gold | Recommended Ship |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **31** | [Level 31: Cinder Rapids](file:///f:/projects/cove-corsair/documents/levels/level_31_cinder_rapids.md) | $11.5\text{ m/s}$ | 16 HP | **None** (Volcanic geysers + narrow chutes) | 240 🪙 | ~390 🪙 | **~780 🪙** | Sloop T3 |
| **32** | [Level 32: Magma Surge](file:///f:/projects/cove-corsair/documents/levels/level_32_magma_surge.md) | $11.6\text{ m/s}$ | 16 HP | **Volcano Sloop** (HP 280, incendiary mortars) | 245 🪙 | ~400 🪙 | **~800 🪙** | Bombard T3 |
| **33** | [Level 33: Ashfall Gorge](file:///f:/projects/cove-corsair/documents/levels/level_33_ashfall_gorge.md) | $11.7\text{ m/s}$ | 16 HP | **None** (Fast switchback rock hazards) | 250 🪙 | ~410 🪙 | **~820 🪙** | Dinghy T3 |
| **34** | [Level 34: Obsidian Strait](file:///f:/projects/cove-corsair/documents/levels/level_34_obsidian_strait.md) | $11.8\text{ m/s}$ | 18 HP | **None** (Reinforced wall gauntlet) | 255 🪙 | ~420 🪙 | **~840 🪙** | Ironclad T3 |
| **35** | [Level 35: Ironjaw's Crucible](file:///f:/projects/cove-corsair/documents/levels/level_35_ironjaws_crucible.md) | $11.9\text{ m/s}$ | 18 HP | **Ironjaw Supreme** (HP 550, flame cannons) | 320 🪙 | ~500 🪙 | **~1,000 🪙** | Bombard T3 / Sloop T3 |
| **36** | [Level 36: Pyroclast Pass](file:///f:/projects/cove-corsair/documents/levels/level_36_pyroclast_pass.md) | $12.0\text{ m/s}$ | 16 HP | **None** (Magma minefield) | 270 🪙 | ~440 🪙 | **~880 🪙** | Dinghy T3 |
| **37** | [Level 37: Hellmouth Trench](file:///f:/projects/cove-corsair/documents/levels/level_37_hellmouth_trench.md) | $12.1\text{ m/s}$ | 18 HP | **Fire-Barge Duo** (HP 220 each, broadside flame) | 275 🪙 | ~450 🪙 | **~900 🪙** | Bombard T3 |
| **38** | [Level 38: Boiling Reach](file:///f:/projects/cove-corsair/documents/levels/level_38_boiling_reach.md) | $12.2\text{ m/s}$ | 18 HP | **None** (Full-lane crossfire turrets) | 280 🪙 | ~460 🪙 | **~920 🪙** | Sloop T3 |
| **39** | [Level 39: Sulfur Chasm](file:///f:/projects/cove-corsair/documents/levels/level_39_sulfur_chasm.md) | $12.3\text{ m/s}$ | 18 HP | **None** (The Needle: 2.0m gaps with contact mines) | 285 🪙 | ~470 🪙 | **~940 🪙** | Dinghy T3 |
| **40** | [Level 40: Molten Bulwark](file:///f:/projects/cove-corsair/documents/levels/level_40_molten_bulwark.md) | $12.4\text{ m/s}$ | 20 HP | **Siege Citadel** (HP 750, 4 towers, regen shields) | 380 🪙 | ~580 🪙 | **~1,160 🪙** | Ironclad T3 / Bombard T3 |
| **41** | [Level 41: Inferno Gate](file:///f:/projects/cove-corsair/documents/levels/level_41_inferno_gate.md) | $12.5\text{ m/s}$ | 20 HP | **None** (Dense armored turtle raft barriers) | 300 🪙 | ~490 🪙 | **~980 🪙** | Bombard T3 |
| **42** | [Level 42: Doomspire Channel](file:///f:/projects/cove-corsair/documents/levels/level_42_doomspire_channel.md) | $12.7\text{ m/s}$ | 18 HP | **None** (High-speed rock slalom) | 305 🪙 | ~500 🪙 | **~1,000 🪙** | Dinghy T3 |
| **43** | [Level 43: Abyssal Rift](file:///f:/projects/cove-corsair/documents/levels/level_43_abyssal_rift.md) | $12.8\text{ m/s}$ | 20 HP | **None** (Heavy barricades every 30m) | 310 🪙 | ~510 🪙 | **~1,020 🪙** | Ironclad T3 |
| **44** | [Level 44: Dreadflame Basin](file:///f:/projects/cove-corsair/documents/levels/level_44_dreadflame_basin.md) | $12.9\text{ m/s}$ | 20 HP | **Armored Fleet Escort** (HP 320, heavy broadside) | 320 🪙 | ~530 🪙 | **~1,060 🪙** | Bombard T3 / Ironclad T3 |
| **45** | [Level 45: Bonebeard's Throne](file:///f:/projects/cove-corsair/documents/levels/level_45_bonebeards_throne.md) | $13.0\text{ m/s}$ | 20 HP | **Bone-Beard Dreadnought** (HP 1,200, rolling volleys, ram, flak) | 550 🪙 | ~800 🪙 | **~1,600 🪙** | Ironclad T3 / Bombard T3 |

---

## ⚡ Technical Validation Commands

To verify that all 45 levels load cleanly and adhere to campaign pacing and schema rules:

```bash
# Execute headless verification suite
"D:\Downloads\Godot_v4.8-dev4_win64.exe\Godot_v4.8-dev4_win64.exe" --headless --scene src/test_campaign_expansion.tscn

# Synchronize all level documents with game resources
python src/tools/sync_level_docs.py
# Or run:
sync_levels.bat
```
