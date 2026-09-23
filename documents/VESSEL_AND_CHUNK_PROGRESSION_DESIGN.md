# Cove Corsair - Vessel & Chunk Progression Architecture

> **Document Status:** Active Engineering & Design Specification  
> **Target Version:** Cove Corsair v1.2+  
> **Related Files:** [`vessels.md`](file:///f:/projects/cove-corsair/documents/vessels.md), [`level_and_chunk_guide.md`](file:///f:/projects/cove-corsair/documents/level_and_chunk_guide.md), [`BaseTrackChunk.gd`](file:///f:/projects/cove-corsair/src/gameplay/chunks/base_track_chunk.gd), [`ChunkAssembler.gd`](file:///f:/projects/cove-corsair/src/gameplay/world/chunk_assembler.gd)

---

## 🎯 1. Core Design Mandate

> **Every stage and modular chunk in Cove Corsair must be calibrated to the specific flagship capabilities the player possesses at that point in campaign progression.**

In order to create genuine strategic depth and give players a compelling reason to upgrade and switch vessels:
1. **Each vessel must have a distinct tactical superpower** (e.g. speed, mortar arcing over obstacles, heavy armor ramming).
2. **Each vessel must have clear operational weaknesses** (e.g. the Sloop struggles in narrow coral chicanes; the Bombard is slow in open strafing runs).
3. **Levels must present obstacles that naturally highlight these strengths and weaknesses**, creating distinct moments where switching vessels is the obvious, rewarding choice.

---

## ⛵ 2. Player Flagship Archetypes & Performance Profiles

```
┌────────────────────────────────────────────────────────────────────────┐
│                        VESSEL SPECIALIZATION SPECTRUM                  │
├─────────────────┬─────────────────┬──────────────────┬─────────────────┤
│   THE DINGHY    │    THE SLOOP    │ THE BOMBARD SKIFF│  THE IRONCLAD   │
│  (Tight Agility)│(Long-Range Speed│ (Siege Artillery)│(Armored Brawler)│
└─────────────────┴─────────────────┴──────────────────┴─────────────────┘
```

| Metric | [The Dinghy](file:///f:/projects/cove-corsair/src/data/resources/user_vessels/dinghy_ship.tres) | [The Sloop](file:///f:/projects/cove-corsair/src/data/resources/user_vessels/sloop_ship.tres) | [The Bombard Skiff](file:///f:/projects/cove-corsair/src/data/resources/user_vessels/bombard_skiff_ship.tres) | [The Ironclad](file:///f:/projects/cove-corsair/src/data/resources/user_vessels/ironclad_ship.tres) |
| :--- | :--- | :--- | :--- | :--- |
| **Campaign Stage** | Levels 1–3 (Introductory) | Levels 4–10+ (Speed & Range) | Levels 10–20+ (Siege & Barricades) | Levels 18–45 (Armored Frontline) |
| **Purchase Cost** | **$0\text{ 🪙}$** (Starter) | **$500\text{ 🪙}$** | **$1,000\text{ 🪙}$** | **$2,500\text{ 🪙}$** |
| **Base Hull HP** | $2\text{ HP}$ (Fragile) | $4\text{ HP}$ (Light) | $4\text{ HP}$ (Medium) | $8\text{ HP}$ (Heavy Armor) |
| **Lateral Swerve Speed** | $10.5\text{ m/s}$ (Zero Drift) | $11.5\text{ m/s}$ (Fastest) | $6.5\text{ m/s}$ (Slowest) | $8.5\text{ m/s}$ (Balanced) |
| **Armament Profile** | 1 Bow Chaser ($1\text{ dmg}$) | 2 Bow Chasers ($2\times 1\text{ dmg}$) | 1 Heavy Mortar ($4\text{ dir} + 3\text{ AoE}$) | 3 Heavy Batteries ($3\times 2 = 6\text{ dmg}$) |
| **Effective Range** | $38\text{m}$ | $38\text{m}$ (Long Range) | $13\text{m}$ (Short Range Mortar) | $24\text{m}$ (Mid Range Cluster) |
| **Collision Bounding Box** | $(1.6, 1.0, 2.8)$ | $(1.4, 1.0, 2.5)$ | $(1.8, 1.2, 3.0)$ | $(2.4, 1.4, 3.8)$ |
| **Firing Behavior** | Single forward shot | Twin parallel chasers | **Parabolic Arc OVER obstacles** | Frontal 3-cannon cluster volley |

---

## 🗺️ 3. Vessel-to-Chunk Specialization Matrix

### 1. The Dinghy (Narrow Corridors & Precision Weaving)
* **Design Role:** The starter vessel for learning lane swerving. Smallest collision box allows forgiving navigation through tight shallows.
* **Natural Strengths:** Extremely responsive steering; can slip through narrow gaps without clipping terrain.
* **Weaknesses:** Very low damage output ($1\text{ dmg}$); fragile hull.
* **Ideal Chunks:**
  * Open water intro runways ([`chunk_warmup.tscn`](file:///f:/projects/cove-corsair/src/gameplay/chunks/chunk_warmup.tscn)).
  * Wide sea mine corridors with clear evasion lines ([`chunk_mine_gauntlet.tscn`](file:///f:/projects/cove-corsair/src/gameplay/chunks/chunk_mine_gauntlet.tscn)).
  * Shallow canal sections where larger hulls risk grounding.

### 2. The Sloop (Open Broadside Strafing & Long-Range Skirmishes)
* **Design Role:** The premier high-speed runner. Excels at long-range engagement and fast lane shifts.
* **Natural Strengths:** $11.5\text{ m/s}$ lateral speed; twin long-range cannonballs ($38\text{m}$) that eliminate enemies before they get close.
* **Weaknesses:** High forward track velocity makes tight, multi-rock obstacle slaloms extremely punishing to navigate; low point-blank burst damage against obstacles directly in front of the bow.
* **Ideal Chunks:**
  * Open river gunner ambushes ([`chunk_gunner_ambush.tscn`](file:///f:/projects/cove-corsair/src/gameplay/chunks/chunk_gunner_ambush.tscn), [`chunk_opener_ambush.tscn`](file:///f:/projects/cove-corsair/src/gameplay/chunks/chunk_opener_ambush.tscn)).
  * Long multiplier gate runways ([`chunk_vanguard_climax.tscn`](file:///f:/projects/cove-corsair/src/gameplay/chunks/chunk_vanguard_climax.tscn)).
  * High-speed strafing channels with moving raiders.
* **DO NOT USE IN EARLY CAMPAIGN (L4):** Dense coral reef slaloms.

### 3. The Bombard Skiff (Fortified Barricades & Coral Chicanes)
* **Design Role:** Heavy siege artillery. Sacrifices lateral speed for massive explosive damage and indirect fire capability.
* **Natural Strengths:** **Mortar fires in a high arc over terrain**, detonating behind rock barriers and clearing clusters ($3.2\text{m}$ splash radius). Smashes multi-slat barricades in a single shell.
* **Weaknesses:** Slow lateral speed ($6.5\text{ m/s}$); long reload cooldown ($1.3\text{s}$); struggles against fast-moving individual dart skiffs spread across distant lanes.
* **Ideal Chunks:**
  * Heavy wooden barricade walls ([`chunk_barricade_siege.tscn`](file:///f:/projects/cove-corsair/src/gameplay/chunks/chunk_barricade_siege.tscn)).
  * Coral reef labyrinths with enemies hiding between rocks ([`chunk_reef_slalom.tscn`](file:///f:/projects/cove-corsair/src/gameplay/chunks/chunk_reef_slalom.tscn)).
  * Fortified Turtle Raft clusters and armored gunner barricades.

### 4. The Ironclad (Dense Minefields & Armored Fleet Brawls)
* **Design Role:** Unstoppable armored juggernaut. Designed to absorb punishment and smash through frontline defenses.
* **Natural Strengths:** $8\text{ HP}$ base armor; Spiked Ramming Prow absorbs explosive sea mine detonations; Triple Heavy Battery ($6\text{ dmg}$ per volley) shreds armored warcraft point-blank.
* **Weaknesses:** Widest collision profile $(2.4\text{m})$; heavy turn radius; expensive upgrade path.
* **Ideal Chunks:**
  * Dense sea mine grids with no clear bypass lanes (mines must be rammed or blasted).
  * High-density kamikaze raft waves ([`chunk_fodder_swarm.tscn`](file:///f:/projects/cove-corsair/src/gameplay/chunks/chunk_fodder_swarm.tscn)).
  * Multi-lane armored fleet battles with heavy barges.

---

## 🧱 4. Expanding the Chunk Library (From 17 to 24 Chunks)

The existing 17 chunks are heavily concentrated around openers and boss arenas, leaving too few mid-track variations to express vessel specialization across 45 campaign levels.

### Current 17 Chunks Breakdown
* **Standard Gameplay Chunks (6):** `chunk_warmup`, `chunk_mine_gauntlet`, `chunk_barricade_siege`, `chunk_gunner_ambush`, `chunk_fodder_swarm`, `chunk_vanguard_climax`.
* **Reef Chunks (2):** `chunk_reef_slalom`, `chunk_opener_slalom`.
* **Opener Chunks (2):** `chunk_opener_ambush`, `chunk_opener_gauntlet`.
* **Transitions & Finish (2):** `chunk_boss_intro_buffer`, `chunk_finish_line`.
* **Boss Arenas (4):** `chunk_boss_ironjaw`, `chunk_boss_bonebeard`, `chunk_boss_phantom_dredge`, `chunk_boss_siege_fortress`.
* **Special Mode (1):** `chunk_wager_fork`.

### Proposed 7 New Chunks Tailored for Specific Vessels

| New Chunk Scene | Target Flagship | Tactical Obstacle / Layout | Why It Demands This Vessel |
| :--- | :--- | :--- | :--- |
| **`chunk_coral_labyrinth.tscn`** | **Bombard Skiff** | High coral arches dividing the river into isolated pockets. Enemies shelter in blind corners. | Mortar shells arc cleanly over the high coral to eliminate enemies without requiring line-of-sight. |
| **`chunk_bastion_breach.tscn`** | **Bombard Skiff** | 3 consecutive solid barricade walls spanning all 3 lanes with zero navigation openings. | Direct cannons take 6–8 hits per slat; Bombard AoE mortar shatters entire sections in 1 blast. |
| **`chunk_minefield_rampart.tscn`** | **Ironclad** | Checkerboard grid of 8 sea mines blocking all lanes. Avoidance is nearly impossible. | Ironclad Spiked Prow and heavy armor absorb mine blasts with 0 hull damage. |
| **`chunk_iron_broadside.tscn`** | **Ironclad** | Side-by-side armored war barges advancing downchannel with high HP pools ($15\text{--}25\text{ HP}$). | Demands the Ironclad's 6-damage triple cannon cluster to punch through before collision. |
| **`chunk_rapids_sprint.tscn`** | **Sloop** | Accelerated river flow ($10\text{ m/s}$), alternating doubloon gates, distant Gunner perches. | High lateral swerve velocity ($11.5\text{ m/s}$) is required to catch multiplier gates at high speed. |
| **`chunk_flak_corridor.tscn`** | **Sloop** | Fast-moving agile raiders strafing rapidly from bank to bank across the river. | Sloop's high-speed long-range twin chasers snipe agile targets across broad waterways. |
| **`chunk_shallows_channel.tscn`** | **Dinghy** | Extremely narrow 6m canal lined with rocky shallows. | Small Dinghy hull $(1.6\text{m})$ maneuvers safely where wide hulls ($2.4\text{m}$) suffer collisions. |

---

## ⚙️ 5. Dynamic Chunk Population & Level Scaling Architecture

### The Problem with Static Chunks
Hardcoding static entities inside `.tscn` files causes early levels to feel either impossibly hard (if tuned for late game) or late levels to feel trivial (if tuned for early game).

### Proposed Dynamic Spawner System
Chunks will use **Marker3D Spawn Points** evaluated at runtime based on `GameState.current_level`:

```gdscript
# Conceptual Dynamic Chunk Controller
extends BaseTrackChunk

@export var tier_1_spawns: Array[NodePath] # Active on Levels 1-5
@export var tier_2_spawns: Array[NodePath] # Active on Levels 6-15
@export var tier_3_spawns: Array[NodePath] # Active on Levels 16+

func _ready() -> void:
    super._ready()
    _populate_for_level(GameState.current_level)
```

#### Level Scaling Bands:
1. **Band 1 (Levels 1–5 - Cove 1):**
   * Mob Count: 1–2 craft per 50m chunk.
   * Enemy Types: Skeleton Rowers ($2\text{ HP}$), Practice Skiffs ($2\text{ HP}$), light Gunners ($4\text{ HP}$).
   * Obstacle Durability: Barricade slats = $1\text{--}2\text{ HP}$, barrels = $1\text{ HP}$.
2. **Band 2 (Levels 6–15 - Cove 2):**
   * Mob Count: 3–5 craft per chunk.
   * Enemy Types: Tide Cutters ($10\text{ HP}$), Iron Gunners ($10\text{ HP}$), Fuse Kegs.
   * Obstacle Durability: Barricade slats = $6\text{ HP}$.
3. **Band 3 (Levels 16+ - Cove 3 & Endgame):**
   * Mob Count: 5–8 craft per chunk + heavy war barges.
   * Enemy Types: Armored Harvesters, Kamikaze Brimstone Rafts, Minefield Gauntlets.
   * Obstacle Durability: Armored Barricade slats = $12\text{--}20\text{ HP}$.

---

## 🗺️ 6. Campaign Level Recipe Alignment Plan

### Phase A: Realign Early Campaign Levels (Levels 1–5)
Ensure early stages strictly match **The Dinghy** and **The Sloop**:

* **Level 1 (Dinghy T1):** `[chunk_warmup, chunk_barricade_siege (Tier 1 tuning), chunk_finish_line]` (200m).
* **Level 2 (Dinghy T2 + Crew):** `[chunk_warmup, chunk_mine_gauntlet, chunk_finish_line]` (200m).
* **Level 3 (Dinghy T2/T3):** `[chunk_opener_ambush, chunk_gunner_ambush, chunk_barricade_siege, chunk_finish_line]` (250m).
* **Level 4 (Sloop T1/T2 Maiden Voyage):**
  * **CURRENT (BROKEN):** `[opener_gauntlet, barricade, reef_slalom, fodder_swarm, climax, finish]`
  * **PROPOSED (SLOOP-ALIGNED):** `[chunk_opener_ambush, chunk_gunner_ambush, chunk_fodder_swarm, chunk_vanguard_climax, chunk_finish_line]`
  * *Rationale:* Replaces the tight reef slalom with wide-channel gunner skirmishes where Sloop speed and twin long-range chasers excel.
* **Level 5 (Captain Ironjaw Boss):** `[chunk_opener_gauntlet, chunk_gunner_ambush, chunk_mine_gauntlet, chunk_boss_ironjaw]` (250m + Arena).

### Phase B: Introduce Bombard Skiff Chunks (Levels 10–12)
* Introduce `chunk_reef_slalom` and `chunk_bastion_breach` on Levels 10–12.
* Solid multi-slat barricades and coral clusters encourage purchasing the Bombard Skiff.

### Phase C: Introduce Ironclad Chunks (Levels 18–20)
* Introduce `chunk_minefield_rampart` and `chunk_iron_broadside` on Levels 18–20.
* Dense minefields and armored war barges encourage commissioning the Ironclad.
