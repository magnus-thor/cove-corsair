# Cove Corsair - Progression, Fleet Meta & Future Modes Architecture

This document details the long-term progression loop, sidegrade vessel balancing matrix, campaign level vectors, economy, VFX/audio architecture, and future gameplay modes in **Cove Corsair**.

---

## ⚖️ 1. Horizontal Vessel Balancing: Specialization Over Raw Power

Vessels are balanced as distinct tactical choices (sidegrades) rather than a linear tier ladder. Each vessel possesses specialized speed, durability, and hardpoint configurations tailored to specific level hazards and combat encounters.

### Fleet Roster Matrix

| Vessel | Archetype | Calibrated Pricing (Buy / T2 / T3) | Base Stats (HP / Speed / Fire Rate) | Core Strength | Core Tradeoff | Best Suited Level Profile |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| [**The Dinghy**](file:///f:/projects/cove-corsair/src/data/resources/user_vessels/dinghy_ship.tres) | Agile Skiff | **$0 / 300 / 750$** | $1\text{ HP}$ / $12.0\text{ m/s}$ / $0.20\text{s}$ | High agility, narrow hitbox ($1.6\text{m}$) | Fragility ($1\text{ HP}$) | **Hazard Heavy:** Narrow reef splits, dense minefields, high volume of $1\text{-}2\text{ HP}$ barrels (e.g., L19 "Devil's Slalom"). |
| [**The Sloop**](file:///f:/projects/cove-corsair/src/data/resources/user_vessels/sloop_ship.tres) | Balanced Standard | **$600 / 800 / 1,500$** | $5\text{ HP}$ / $11.0\text{ m/s}$ / $0.16\text{s}$ | Balanced mobility, wide swivel arc coverage | Average hull ($5\text{ HP}$), moderate damage | **Dynamic Flankers:** Strafing Grave Skiffs, multi-lane split gates, and medium mob density. |
| [**The Bombard Skiff**](file:///f:/projects/cove-corsair/src/data/resources/user_vessels/bombard_skiff_ship.tres) | Artillery Mortar | **$1,000 / 1,200 / 2,200$** | $3\text{ HP}$ / $9.0\text{ m/s}$ / $1.30\text{s}$ | Parabolic siege mortar with AoE splash ($2.0\text{m}$), dual scattershot carronades | Slow direct fire rate, light hull ($3\text{ HP}$) | **Dense Formations:** Interlocking barricades, clustered Fuse Barrels, and heavily fortified siege encounters. |
| [**The Ironclad**](file:///f:/projects/cove-corsair/src/data/resources/user_vessels/ironclad_ship.tres) | Armored Brawler | **$1,400 / 1,800 / 3,000$** | $8\text{ HP}$ / $7.5\text{ m/s}$ / $0.15\text{s}$ | Massive durability ($8\text{ HP}$), heavy forward firepower, quad swivel battery | Sluggish swerve ($7.5\text{ m/s}$), huge footprint ($2.4\text{m}$) | **Siege Heavy:** High-HP Turtle Rafts, dense barricade walls, straight-line DPS checks (e.g., L16 "The Iron Wall"). |

---

## 🛠️ 2. Standardized 3-Tier Upgrade Progression

Every vessel in Cove Corsair supports two purchasable upgrades ($3\text{ tiers total}$):

```
[ Tier 1: Stock Hull ] ───► [ Tier 2: Crew Hardpoint ] ───► [ Tier 3: Artillery Battery ]
   Base cannons & HP           Unlocks Monkey / Crew           Unlocks Swivel / Scattershot / Quad Mounts
```

### Detailed Vessel Tier Layouts

#### 🚤 The Dinghy (`dinghy_ship.tres`)
* **Purchase Price:** $0\text{ Doubloons}$ (Starter vessel).
* **Tier 1 (Base):** Bow Chaser Cannon (`BowMount`).
* **Tier 2 ($300\text{ Doubloons}$):** Adds Monkey Bomber Crew (`MidDeckCrew`) hurling explosive bombs.
* **Tier 3 ($750\text{ Doubloons}$):** Adds Skeleton Tosser Crew (`AftDeckCrew`) launching heavy throwing axes.

#### ⛵ The Sloop (`sloop_ship.tres`)
* **Purchase Price:** $600\text{ Doubloons}$.
* **Tier 1 (Base):** Dual Bow Chasers (`BowMount`).
* **Tier 2 ($800\text{ Doubloons}$):** Adds Deck Crew Duo — Monkey Bomber (`MidDeckCrew`) & Skeleton Tosser (`AftDeckCrew`).
* **Tier 3 ($1,500\text{ Doubloons}$):** Adds Port & Starboard Swivel Guns (`PortSwivelMount`, `StarboardSwivelMount`) for wide-angle broadside defense.

#### 💣 The Bombard Skiff (`bombard_skiff_ship.tres`)
* **Purchase Price:** $1,000\text{ Doubloons}$.
* **Tier 1 (Base):** Heavy Siege Mortar (`BowMortarMount`) firing high-arc AoE mortar shells ([`ammo_heavy_shot.tres`](file:///f:/projects/cove-corsair/src/data/resources/user_ammo/ammo_heavy_shot.tres)).
* **Tier 2 ($1,200\text{ Doubloons}$):** Adds Quarterdeck Crew Support (`QuarterdeckCrew` - Monkey Bomber).
* **Tier 3 ($2,200\text{ Doubloons}$):** Adds Dual Side Scattershot Carronades (`PortRailMount`, `StarboardRailMount` firing [`scattershot_pellet.tscn`](file:///f:/projects/cove-corsair/src/gameplay/projectiles/scattershot_pellet.tscn)).

#### 🛡️ The Ironclad (`ironclad_ship.tres`)
* **Purchase Price:** $1,400\text{ Doubloons}$.
* **Tier 1 (Base):** Triple Heavy Bow Battery (`BowMount`).
* **Tier 2 ($1,800\text{ Doubloons}$):** Reinforced Deck Crew — Monkey Bomber (`MonkeyCrew`) & Skeleton Tosser (`SkeletonCrew`).
* **Tier 3 ($3,000\text{ Doubloons}$):** Quad Swivel Gun Battery (`PortSwivelMount1`, `PortSwivelMount2`, `StarboardSwivelMount1`, `StarboardSwivelMount2`).

---

## 🗺️ 3. 45-Level Campaign & Milestone Boss Rotation

The campaign spans **45 sequentially unlocked levels** distributed across 3 distinct environmental biomes, generated via [`generate_campaign_levels.gd`](file:///f:/projects/cove-corsair/src/tools/generate_campaign_levels.gd):

### Biome Breakdown

```
[ Levels 1–15: Tropical Reef ] ──► [ Levels 16–30: Murky Bayou ] ──► [ Levels 31–45: Volcanic Brimstone ]
  Scroll Speed: 8.0 – 9.5 m/s        Scroll Speed: 9.5 – 11.5 m/s       Scroll Speed: 11.5 – 13.0 m/s
  Doubloons: 100 – 450               Doubloons: 500 – 750               Doubloons: 800 – 1,200
  Clear sunny waters, sandy shoals   Atmospheric swamp fog (0.015)      Intense heat fog (0.02), crimson glow
```

1. **Cove 1 — Tropical Reef (Levels 1–15):**
   * Pacing: Gradual onboarding, introductory mine gauntlets, and wooden barricades.
   * Speed Range: $8.0\text{ m/s}$ up to $9.5\text{ m/s}$.
   * Completion Rewards: $100$ to $450\text{ Doubloons}$.
   * **Milestone Encounters:**
     * **Level 5:** [The Phantom Dredge](file:///f:/projects/cove-corsair/src/gameplay/enemies/boss_phantom_dredge.gd)
     * **Level 10:** [Captain Ironjaw](file:///f:/projects/cove-corsair/src/gameplay/enemies/boss_war_barge.gd)
     * **Level 15:** [Captain Bone-Beard's Outpost](file:///f:/projects/cove-corsair/src/gameplay/enemies/boss_bone_beard.gd)

2. **Cove 2 — Murky Bayou (Levels 16–30):**
   * Pacing: Dense obstacle fields, biogas pods, high-speed strafing skiffs, and tactical bottlenecks.
   * Speed Range: $9.5\text{ m/s}$ up to $11.5\text{ m/s}$.
   * Completion Rewards: $500$ to $750\text{ Doubloons}$.
   * **Tactical Bottlenecks:**
     * **Level 16 ("The Iron Wall"):** Heavy sequential barricade clusters demanding high burst DPS or Ironclad/Bombard loadouts.
     * **Level 19 ("Devil's Slalom"):** Dense mine gauntlet testing Dinghy slalom navigation and precision steering.
   * **Milestone Encounters:**
     * **Level 20:** [The Siege Fortress](file:///f:/projects/cove-corsair/src/gameplay/enemies/boss_siege_fortress.gd)
     * **Level 25:** [The Phantom Dredge](file:///f:/projects/cove-corsair/src/gameplay/enemies/boss_phantom_dredge.gd)
     * **Level 30:** [Captain Bone-Beard's Armada](file:///f:/projects/cove-corsair/src/gameplay/enemies/boss_bone_beard.gd)

3. **Cove 3 — Volcanic Brimstone (Levels 31–45):**
   * Pacing: Rapid scroll speeds, lava geysers, exploding brimstone rafts, and fortified siege fortifications.
   * Speed Range: $11.5\text{ m/s}$ up to $13.0\text{ m/s}$.
   * Completion Rewards: $800$ to $1,200\text{ Doubloons}$.
   * **Milestone Encounters:**
     * **Level 35:** [Captain Ironjaw's Crucible](file:///f:/projects/cove-corsair/src/gameplay/enemies/boss_war_barge.gd)
     * **Level 40:** [The Molten Bulwark (Siege Fortress)](file:///f:/projects/cove-corsair/src/gameplay/enemies/boss_siege_fortress.gd)
     * **Level 45:** [Captain Bone-Beard's Final Throne](file:///f:/projects/cove-corsair/src/gameplay/enemies/boss_bone_beard.gd)

### Milestone Boss Rotation
Milestone boss encounters occur **every 5 levels** (Levels 5, 10, 15, 20, 25, 30, 35, 40, 45 — 9 boss milestones total), challenging players to adapt vessel selection and weapon upgrades.

---

## 🚧 4. Dynamic Barricade Health Scaling

To maintain tactical challenge without hard-walling player progression, wooden Barricade Walls ([`barricade_wall.gd`](file:///f:/projects/cove-corsair/src/gameplay/obstacles/barricade_wall.gd)) scale dynamically based on campaign tier:

$$\text{Slat HP}(\text{Level}) = \begin{cases} 2\text{ HP} & \text{Levels } 1\text{ to } 3 \text{ (Starter Dinghy punches through in 2 direct cannon shots)} \\ 6\text{ HP} & \text{Levels } 4\text{ to } 10 \text{ (Demands sustained fire or upgraded vessel volleys)} \\ 12\text{ HP} & \text{Levels } 11\text{ to } 25 \text{ (Mid-campaign fortified barrier)} \\ 20\text{ HP} & \text{Levels } 26+ \text{ (Late-game fortified siege walls)} \end{cases}$$

* Intact barricade slats deal $3\text{ damage}$ on direct collision with the player vessel (instantly destroying The Dinghy with $1\text{ HP}$, while The Ironclad with $8\text{ HP}$ survives with $5\text{ HP}$ remaining).
* Armored barrel rune obstacles within barricade chunks are flagged with `spawns_chest`, yielding 3D treasure chests upon destruction.

---

## 🗺️ 5. River Map Architecture

The campaign map ([`river_map.gd`](file:///f:/projects/cove-corsair/src/ui/river_map.gd)) provides a visual progression interface:

* **15,000px Parchment Canvas:** Continuous vertical canvas ($720 \times 15,000\text{px}$) with biome-tinted wash zones (Tropical Reef $10,000\text{--}15,000\text{px}$, Murky Bayou $5,000\text{--}10,000\text{px}$, Volcanic Brimstone $0\text{--}5,000\text{px}$).
* **Smooth Spline Interpolation:** `Curve2D` with baked 5-layer polylines rendering riverbed depth, sandy riverbanks, shoreline shadows, and sunlight current highlights.
* **45 Milestone Nodes & 9 Boss Badges:** Level nodes feature star mastery ratings, high-score tracking, and skull badges for milestone bosses.
* **ScrollContainer Frame-0 Guard:** Deferment guard (`await get_tree().process_frame`) ensures the 15,000px height is measured before viewport centering.
* **Victory Advancement Sequence:** Upon completing a level, the miniature player vessel smoothly navigates the spline from `last_cleared_level` to `highest_unlocked_level`, rotating tangent to curve geometry with water-cruising SFX.
* **Level Detail Modal:** Interactive popup displaying target distance, biome type, star rating, best score, and "Set Sail" dispatch.

---

## 💰 6. Economy, Settlement Loop & Shipyard Notifications

The game economy balances risk, reward, and persistent progress:

```
[ In-Run Play ] ──► [ Hull Destroyed / Victory ] ──► [ Settlement Screen ] ──► [ Shipyard Upgrade ] ──► [ Next Level / Retry ]
  Collect Coins       Retain 100% In-Run Coins         Animated Doubloon Tally   Pulsing Alert Badge       Instant Auto-Start
```

* **100% In-Run Gold Retention on Defeat:** Failing a run retains all collected doubloons ("HULL BREACHED - TREASURE RETAINED"). Players naturally earn the currency needed for shipyard upgrades within 2–3 attempts without tedious grinding.
* **Unified Settlement Screen:** ([`settlement_screen.gd`](file:///f:/projects/cove-corsair/src/ui/settlement_screen.gd))
  * Smooth modal zoom and backdrop fade with audio stingers.
  * Tally-roll counter interpolating run doubloons, level completion bonus, and banked totals with synced coin pickup SFX.
  * Star rating display based on completion, zero leaks, and untouched hull.
* **Shipyard Upgrade Notification Badges:**
  * When banked doubloons satisfy `can_afford_active_vessel_upgrade()`, the Shipyard button triggers a looping pulsing badge and radiant golden highlight.
  * Opening the shipyard directly from the settlement screen allows immediate upgrading before retrying or advancing.

---

## ✨ 7. 3D Particle Architecture & Combat VFX

Mobile-optimized 3D particle systems are managed globally by [`vfx_manager.gd`](file:///f:/projects/cove-corsair/src/core/vfx_manager.gd):

* **Engine:** Built with `CPUParticles3D` to ensure maximum compatibility with the mobile renderer and avoid compute shader pipeline stalls.
* **World Tree Reparenting:** Particles spawn into a dedicated `VFXContainer` rooted under the active scene rather than the dying entity, guaranteeing that calling `queue_free()` on a destroyed obstacle or enemy skiff does not prematurely prune active debris.
* **Waterline Snapping:** Geyser splashes ([`vfx_mortar_geyser.tscn`](file:///f:/projects/cove-corsair/src/vfx/vfx_mortar_geyser.tscn)) clamp $Y$-coordinates to the water plane ($0.0\text{m} \le Y \le 0.05\text{m}$) to eliminate floating water plumes.
* **Particle Roster:**
  * **Timber Splinters** (`vfx_wood_splinter.tscn`): Angular wooden shrapnel with gravity and tumbling rotation.
  * **Mortar Geyser** (`vfx_mortar_geyser.tscn`): Vertical water column and horizontal expanding shockwave ring.
  * **Mine Explosion** (`vfx_mine_explosion.tscn`): Fiery orange core burst followed by billowing charcoal smoke.
  * **Coin Burst** (`vfx_coin_burst.tscn`): Golden coin eruption triggering upon collecting 3D treasure chests.
* **3D Treasure Chest Pickups:** [`collectible_chest.tscn`](file:///f:/projects/cove-corsair/src/gameplay/collectibles/collectible_chest.tscn) instantiates Kenney 3D chest models (`chest.glb`), supporting high-value rewards ($25\text{--}100\text{ doubloons}$) in hazard pockets via [`chest_spawn_marker.gd`](file:///f:/projects/cove-corsair/src/gameplay/chunks/chest_spawn_marker.gd).

---

## 🔊 8. Audio System & Perlin Noise Camera Trauma

* **Audio Manager:** ([`audio_manager.gd`](file:///f:/projects/cove-corsair/src/core/audio_manager.gd))
  * **Dedicated Audio Buses:** `Master`, `BGM`, and `SFX` with persistent volume and mute state.
  * **Biome Crossfade:** Dual-player crossfading (`MusicPlayer_A` / `MusicPlayer_B`) over $1.0\text{s}$ with a **redundant crossfade guard** preventing track restarts if the target biome theme is already playing.
  * **SFX Voice Pooling:** 24-player pool with category sound cooldowns and randomized pitch variation ($0.93\times\text{--}1.07\times$).
* **Camera Trauma & Perlin Shake:** ([`game_camera.gd`](file:///f:/projects/cove-corsair/src/core/game_camera.gd))
  * Uses `FastNoiseLite` (Perlin noise) with **quadratic falloff** ($\text{intensity} = \text{trauma}^2$) and rapid decay ($1.25/\text{s}$).
  * Trauma events:
    * Hull hit: $+0.55\text{ trauma}$
    * Mortar AoE impact: $+0.45\text{ trauma}$
    * Mortar launch: $+0.25\text{ trauma}$
    * Scattershot volley: $+0.15\text{ trauma}$
    * Standard cannon shot: $+0.08\text{ trauma}$

---

## 🔮 9. Prospective Future Modes

### The Galleon Siege (Stationary Broadside & Boarding Duels)
* **Concept:** Locked side-view camera facing an enemy war galleon. Two-front battle managing deck batteries while repelling enemy boarding crews.
* **Mechanics:** Modular destructible zones (Powder Magazine, Cannon Ports, Masts & Rigging) and rhythm-based deck duels (High Strike, Low Strike, Parry).

### Advanced Weapon Archetypes
* **Greek Fire Siphon:** Continuous short-range thermal cone melting barricades and ignoring physical armor.
* **Harpoon Launcher:** Tethered projectile dragging floating powder barrels into enemy formations.
