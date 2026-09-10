# Campaign Master Balancing & Progression Specification

> Strategic Level Breakdown, Vessel Thresholds, Economy & Boss Mechanics (Levels 1–45)

---

## 1. Executive Balancing Framework

### The Two-Tier Vessel Architecture

* **Class A: Skiffs (Starter Class)**
* **The Dinghy:** Micro-hitbox ($1.6\text{m}$), maximum turn agility, high speed.


* T1: **2 HP**, 5.0 DPS, Cost: Free.


* T2: **3 HP**, 14.0 DPS, Cost: 250 🪙.
* T3: **4 HP**, 28.0 DPS, Cost: 1,000 🪙.


* **The Sloop:** Balanced standard ($1.9\text{m}$), broad coverage, sustained stream fire.


* T1: **4 HP**, 10.0 DPS, Cost: 500 🪙.
* T2: **5 HP**, 20.0 DPS, Cost: 700 🪙.
* T3: **6 HP**, 35.0 DPS, Cost: 1,600 🪙.




* **Class B: Warships (Heavy Specialist Class)**
* **The Bombard Skiff:** Siege mortar, AoE splash ($3.5\text{m}$), barrier/armor destroyer.


* T1: **4 HP**, 12.0 DPS (AoE), Cost: 1,400 🪙.
* T2: **5 HP**, 28.0 DPS, Cost: 1,800 🪙.
* T3: **6 HP**, 48.0 DPS, Cost: 2,800 🪙.


* **The Ironclad:** Armored tank ($2.4\text{m}$), high HP pool, 50% wall impact mitigation.
* T1: **7 HP**, 12.0 DPS, Cost: 1,800 🪙.
* T2: **9 HP**, 26.0 DPS, Cost: 2,400 🪙.
* T3: **11 HP**, 44.0 DPS, Cost: 3,800 🪙.





### Economy & The Opt-In Ad Multiplier

* In-run coins come exclusively from destructible barrels (1–3 coins), enemy sinks (2–4 coins), and gated chests.


* **Opt-In Multiplier ("Ad" Reward):** On the Settlement Screen, players can tap **[ ✦ CLAIM 2X BONUS ]** to double their total run payout (In-Run Drops + Clear Reward).
* Payout columns in this document display:
* **Base Run Total:** Expected in-run drops + level clear bonus.
* **2X Bonus Total:** Doubled reward if the player opts in.



---

## 2. Boss Combat Mechanics & Calibrations

### Fixing The Phantom Dredge (Level 2 Overwhelm Bug)

During testing, Level 2 loaded **The Phantom Dredge** (`chunk_boss_phantom_dredge.tscn`), which is designed as a mid-tier Bayou apparition:

* **The Green Circles:** This is the Dredge's "Spectral Geyser / Ectoplasm Mortar" AoE attack. It drops telegraph markers that erupt after a delay.
* **The Swarm Bug:** The Dredge runs an internal summon loop spawning 2 Ghost Rowers every few seconds while simultaneously firing geysers, pinning a low-DPS Dinghy into undodgeable overlap damage.
* **The Fix:**
1. **Remove Dredge from Level 2:** Level 2 should NOT feature a complex summoning boss. Early levels should use minor skirmish flagships.


2. **Telegraph Windows:** For all geyser/circle attacks, the telegraph delay is increased from $0.8\text{s} \rightarrow 1.6\text{s}$, giving clear reaction time to steer out.
3. **Hard Cap on Summons:** Bosses cannot spawn adds if there are already 2 active hostile ships in the river.



### The 4 Major Boss Archetypes

#### 1. Captain Ironjaw (Cove 1 — Tropical Flagship)

* **Visual & Hull:** Armored pirate cutter with broadside gun ports.
* **Health:** Scales from **40 HP** (L1) to **120 HP** (L10) to **220 HP** (L15).
* **Weaponry:** Alternating port/starboard cannonballs (1 dmg) and targeted frontal grape-shot.
* **Minions / Adds:** None on early levels. Spawns 1 Skeleton Rower every 12s on L10+.

#### 2. The Phantom Dredge (Cove 2 — Bayou Apparition)

* **Visual & Hull:** Semi-translucent spectral galleon with glowing green lanterns.
* **Health:** Scales from **180 HP** (L20) to **320 HP** (L25).
* **Weaponry:**
* *Spectral Geysers:* 2 telegraphed green circles in player lanes ($1.6\text{s}$ warn before detonation).
* *Ghost Fire:* Slow-moving tracking orbs that can be shot down by player fire.


* **Minions / Adds:** Spawns a maximum of 1 Ghost Rower (HP 4) every 14s. Hard cap of 1 add on screen.

#### 3. The Siege Fortress (Cove 2/3 — Fortified Bastion)

* **Visual & Hull:** Massive stationary/slow river barge with iron shield plating and twin turrets.
* **Health:** Scales from **280 HP** (L20) to **500 HP** (L40).
* **Weaponry:** Heavy bow mortar lobbing high-arc shells, flanked by rotating chainguns.
* **Minions / Adds:** Releases 1 Armored Turtle Raft into the water every 18s.

#### 4. Captain Bone-Beard (Grandmaster Flagship)

* **Visual & Hull:** Three-masted Dreadnought with steam rams and heavy carronades.
* **Health:** Scales from **350 HP** (L12) to **750 HP** (L30) to **1,200 HP** (L45).


* **Weaponry:** Full broadside rolling volleys, frontal ram surges, and burning barrel drop-mines.
* **Minions / Adds:** Summons pairs of Raider Skiffs in flanking lanes.

---

## 3. Campaign Master Matrix: Levels 1–45

### Cove 1: Tropical Lagoon (Levels 1–15)

*Gentle learning curve. Driftwood barricades (2–6 HP). Focus on steering, target acquisition, and building early savings.*

| Lv | Title | Speed | Barricade HP | Boss Encounter & Weapons | Max Boss Adds | In-Run Drops | Clear Bonus | Base Total | 2X Bonus | Min. Viable | Rec. Vessel |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| **1** | Smuggler's Run | $6.5\text{ m/s}$<br> | 2 HP

 | **None** (Level ends on dock crossing) | None | 25 🪙 | 50 🪙 | **75 🪙** | **150 🪙** | Dinghy T1

 | Dinghy T1

 |
| **2** | Palm Shallows | $7.0\text{ m/s}$ | 2 HP

 | **Raider Sloop** (HP 30, slow forward cannon) | None | 35 🪙 | 65 🪙 | **100 🪙** | **200 🪙** | Dinghy T1

 | Dinghy T1

 |
| **3** | Serpent's Reach | $7.2\text{ m/s}$ | 3 HP | **Raider Sloop** (HP 40, forward cannon) | None | 40 🪙 | 75 🪙 | **115 🪙** | **230 🪙** | Dinghy T1 | Dinghy T2 |
| **4** | Sunken Reefs | $7.5\text{ m/s}$ | 3 HP | **None** (Hazard slalom focus) | None | 45 🪙 | 85 🪙 | **130 🪙** | **260 🪙** | Dinghy T1 | Dinghy T2 |
| **5** | Ironjaw's Scout | $7.8\text{ m/s}$ | 4 HP | **Ironjaw Scout** (HP 55, alternating broadside) | 1 Rower | 50 🪙 | 100 🪙 | **150 🪙** | **300 🪙** | Dinghy T2 | Dinghy T2 / Sloop T1 |
| **6** | Corsair's Cut | $8.0\text{ m/s}$ | 4 HP | **None** (Mine gauntlet focus) | None | 50 🪙 | 90 🪙 | **140 🪙** | **280 🪙** | Dinghy T2 | Sloop T1 |
| **7** | Bone Cay | $8.2\text{ m/s}$ | 5 HP | **Raider Brig** (HP 65, twin bow cannons) | None | 55 🪙 | 100 🪙 | **155 🪙** | **310 🪙** | Dinghy T2 | Sloop T1 |
| **8** | Pelican Point | $8.4\text{ m/s}$ | 5 HP | **None** (Barricade siege test) | None | 60 🪙 | 105 🪙 | **165 🪙** | **330 🪙** | Dinghy T2 | Sloop T1 |
| **9** | Sharktooth Shoal | $8.6\text{ m/s}$ | 6 HP | **Twin Skiff Chiefs** (HP 40 each) | 1 Rower | 65 🪙 | 115 🪙 | **180 🪙** | **360 🪙** | Dinghy T2 | Sloop T2 |
| **10** | Captain Ironjaw | $8.8\text{ m/s}$ | 6 HP | **Captain Ironjaw** (HP 120, broadsides + grape) | 1 Rower | 75 🪙 | 145 🪙 | **220 🪙** | **440 🪙** | Sloop T1 | Sloop T2 / Dinghy T3 |
| **11** | Dead Calm Pass | $9.0\text{ m/s}$ | 6 HP | **None** (Precision mine corridors) | None | 70 🪙 | 120 🪙 | **190 🪙** | **380 🪙** | Dinghy T2 | Dinghy T3 |
| **12** | Smuggler's Gate | $9.0\text{ m/s}$ | 8 HP | **Ironclad Escort** (HP 140, heavy ram) | None | 75 🪙 | 125 🪙 | **200 🪙** | **400 🪙** | Sloop T2 | Bombard T1 |
| **13** | Coral Labyrinth | $9.2\text{ m/s}$ | 8 HP | **None** (Switchback steering maze) | None | 80 🪙 | 130 🪙 | **210 🪙** | **420 🪙** | Dinghy T3 | Dinghy T3 |
| **14** | Siren's Shoals | $9.4\text{ m/s}$ | 8 HP | **Raider Flagship** (HP 160, mortar arcs) | 2 Rowers | 85 🪙 | 140 🪙 | **225 🪙** | **450 🪙** | Sloop T2 | Bombard T1 |
| **15** | Bonebeard's Outpost | $9.5\text{ m/s}$<br> | 8 HP | **Ironjaw Elite** (HP 220, rapid fire + mines) | 2 Rowers | 95 🪙 | 175 🪙 | **270 🪙** | **540 🪙** | Sloop T2

 | Bombard T1 / Sloop T3 |

---

### Cove 2: Black Tide Bayou (Levels 16–30)

*Strategic inflection point. Dense fog, reinforced oak barriers (10–14 HP), armored turtle rafts, and spectral hazards. Vessel choice directly affects stage difficulty.*

| Lv | Title | Speed | Barricade HP | Boss Encounter & Weapons | Max Boss Adds | In-Run Drops | Clear Bonus | Base Total | 2X Bonus | Min. Viable | Rec. Vessel |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| **16** | The Iron Wall | $9.5\text{ m/s}$<br> | 12 HP

 | **None** (Triple fortified wall bottleneck) | None | 90 🪙 | 160 🪙 | **250 🪙** | **500 🪙** | Bombard T1 | Bombard T1 / Ironclad T1

 |
| **17** | Murkwater Run | $9.6\text{ m/s}$ | 10 HP | **Ghost Sloop Ambush** (HP 150) | 1 Ghost | 95 🪙 | 165 🪙 | **260 🪙** | **520 🪙** | Sloop T2 | Sloop T2

 |
| **18** | Witch's Channel | $9.8\text{ m/s}$ | 10 HP | **None** (Submerged hazards & snags) | None | 100 🪙 | 170 🪙 | **270 🪙** | **540 🪙** | Dinghy T2 | Dinghy T3 |
| **19** | Devil's Slalom | $10.0\text{ m/s}$ | 10 HP | **None** (2.1m ultra-tight mine gauntlet) | None | 105 🪙 | 175 🪙 | **280 🪙** | **560 🪙** | Dinghy T2 | Dinghy T3 |
| **20** | Citadel of Iron | $10.0\text{ m/s}$ | 12 HP

 | **Siege Fortress** (HP 280, mortar + shields) | 1 Turtle | 115 🪙 | 210 🪙 | **325 🪙** | **650 🪙** | Bombard T2 | Bombard T2 / Ironclad T1 |
| **21** | Serpent's Nest | $10.2\text{ m/s}$<br> | 10 HP | **None** (Flanking shore turrets) | None | 110 🪙 | 180 🪙 | **290 🪙** | **580 🪙** | Sloop T2 | Sloop T3 |
| **22** | Gloom Mire | $10.3\text{ m/s}$ | 12 HP

 | **Bayou Marauder** (HP 180, explosive barrels) | 1 Rower | 115 🪙 | 185 🪙 | **300 🪙** | **600 🪙** | Bombard T2 | Ironclad T2 |
| **23** | Rotwood Reach | $10.5\text{ m/s}$<br> | 12 HP

 | **None** (Barricades paired with sea mines) | None | 120 🪙 | 190 🪙 | **310 🪙** | **620 🪙** | Sloop T2 | Sloop T3 |
| **24** | Blackwater Hollow | $10.6\text{ m/s}$ | 12 HP

 | **Heavy Turtle Barge** (HP 220, armored prow) | None | 125 🪙 | 195 🪙 | **320 🪙** | **640 🪙** | Bombard T2

 | Bombard T2

 |
| **25** | Phantom Trench | $10.8\text{ m/s}$<br> | 12 HP

 | **Phantom Dredge** (HP 320, geysers + tracking orb) | 1 Ghost | 135 🪙 | 240 🪙 | **375 🪙** | **750 🪙** | Sloop T3

 | Sloop T3 / Bombard T2

 |
| **26** | Stagnant Cut | $10.9\text{ m/s}$ | 14 HP | **None** (Massive drift log-jams) | None | 130 🪙 | 210 🪙 | **340 🪙** | **680 🪙** | Ironclad T1 | Ironclad T2

 |
| **27** | Banshee Bog | $11.0\text{ m/s}$ | 12 HP | **None** (Current shifts & mine nets) | None | 135 🪙 | 215 🪙 | **350 🪙** | **700 🪙** | Dinghy T3

 | Dinghy T3

 |
| **28** | Dead Man's Bayou | $11.2\text{ m/s}$<br> | 14 HP | **Ghost Armada Chief** (HP 250, twin broadsides) | 2 Ghosts | 140 🪙 | 220 🪙 | **360 🪙** | **720 🪙** | Bombard T2

 | Bombard T3 |
| **29** | Voodoo Crossing | $11.3\text{ m/s}$ | 14 HP | **None** (Armored raft formations) | None | 145 🪙 | 225 🪙 | **370 🪙** | **740 🪙** | Bombard T2 | Sloop T3 |
| **30** | Bonebeard's Armada | $11.5\text{ m/s}$<br> | 14 HP | **Bonebeard Ironclad** (HP 450, ramming + flak) | 2 Rowers | 160 🪙 | 290 🪙 | **450 🪙** | **900 🪙** | Ironclad T2

 | Bombard T3 / Ironclad T2

 |

---

### Cove 3: Brimstone Bastion (Levels 31–45)

*Endgame gauntlet. High velocity, iron palisades (16–20 HP), magma rocks, and relentless crossfire. Demands upgraded Tier 3 hulls.*

| Lv | Title | Speed | Barricade HP | Boss Encounter & Weapons | Max Boss Adds | In-Run Drops | Clear Bonus | Base Total | 2X Bonus | Min. Viable | Rec. Vessel |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| **31** | Cinder Rapids | $11.5\text{ m/s}$<br> | 16 HP | **None** (Volcanic geysers + narrow chutes) | None | 150 🪙 | 240 🪙 | **390 🪙** | **780 🪙** | Sloop T3

 | Sloop T3

 |
| **32** | Magma Surge | $11.6\text{ m/s}$<br> | 16 HP | **Volcano Sloop** (HP 280, incendiary mortars) | 1 Skiff | 155 🪙 | 245 🪙 | **400 🪙** | **800 🪙** | Bombard T2 | Bombard T3 |
| **33** | Ashfall Gorge | $11.7\text{ m/s}$<br> | 16 HP | **None** (Fast switchback rock hazards) | None | 160 🪙 | 250 🪙 | **410 🪙** | **820 🪙** | Dinghy T3

 | Dinghy T3

 |
| **34** | Obsidian Strait | $11.8\text{ m/s}$<br> | 18 HP | **None** (Reinforced wall gauntlet) | None | 165 🪙 | 255 🪙 | **420 🪙** | **840 🪙** | Ironclad T2 | Ironclad T3 |
| **35** | Ironjaw's Crucible | $11.9\text{ m/s}$ | 18 HP | **Ironjaw Supreme** (HP 550, flame cannons) | 2 Skiffs | 180 🪙 | 320 🪙 | **500 🪙** | **1,000 🪙** | Sloop T3

 | Bombard T3 / Sloop T3

 |
| **36** | Pyroclast Pass | $12.0\text{ m/s}$ | 16 HP | **None** (Magma minefield) | None | 170 🪙 | 270 🪙 | **440 🪙** | **880 🪙** | Dinghy T3

 | Dinghy T3

 |
| **37** | Hellmouth Trench | $12.1\text{ m/s}$ | 18 HP | **Fire-Barge Duo** (HP 220 each, broadside flame) | None | 175 🪙 | 275 🪙 | **450 🪙** | **900 🪙** | Bombard T3

 | Bombard T3

 |
| **38** | Boiling Reach | $12.2\text{ m/s}$ | 18 HP | **None** (Full-lane crossfire turrets) | None | 180 🪙 | 280 🪙 | **460 🪙** | **920 🪙** | Sloop T3

 | Sloop T3

 |
| **39** | Sulfur Chasm | $12.3\text{ m/s}$ | 18 HP | **None** (The Needle: 2.0m gaps with contact mines) | None | 185 🪙 | 285 🪙 | **470 🪙** | **940 🪙** | Dinghy T3

 | Dinghy T3

 |
| **40** | Molten Bulwark | $12.4\text{ m/s}$ | 20 HP

 | **Siege Citadel** (HP 750, 4 towers, regen shields) | 2 Turtles | 200 🪙 | 380 🪙 | **580 🪙** | **1,160 🪙** | Ironclad T3 | Ironclad T3 / Bombard T3 |
| **41** | Inferno Gate | $12.5\text{ m/s}$ | 20 HP

 | **None** (Dense armored turtle raft barriers) | None | 190 🪙 | 300 🪙 | **490 🪙** | **980 🪙** | Bombard T3 | Bombard T3 |
| **42** | Doomspire Channel | $12.7\text{ m/s}$<br> | 18 HP | **None** (High-speed rock slalom) | None | 195 🪙 | 305 🪙 | **500 🪙** | **1,000 🪙** | Dinghy T3

 | Dinghy T3

 |
| **43** | Abyssal Rift | $12.8\text{ m/s}$<br> | 20 HP

 | **None** (Heavy barricades every 30m) | None | 200 🪙 | 310 🪙 | **510 🪙** | **1,020 🪙** | Ironclad T3 | Ironclad T3 |
| **44** | Dreadflame Basin | $12.9\text{ m/s}$<br> | 20 HP

 | **Armored Fleet Escort** (HP 320, heavy broadside) | 2 Skiffs | 210 🪙 | 320 🪙 | **530 🪙** | **1,060 🪙** | Sloop T3

 | Bombard T3 / Ironclad T3 |
| **45** | Bonebeard's Throne | $13.0\text{ m/s}$<br> | 20 HP

 | **Bone-Beard Dreadnought** (HP 1,200, rolling volleys, ram, flak) | 2 Skiffs | 250 🪙 | 550 🪙 | **800 🪙** | **1,600 🪙** | Any T3

 | Ironclad T3 / Bombard T3 |

---

## 4. Economic Validation (With and Without 2X Multiplier)

* **Level 1 Clear:** Yields **75 🪙** (or **150 🪙** with 2X bonus).
* **Dinghy Tier 2 Upgrade (250 🪙):**
* *Standard Player:* Reached after clearing Level 1 + Level 2 (Total: $75 + 100 = 175\text{ 🪙}$) plus a couple of scrap attempts.
* *2X Ad Player:* Reached immediately upon clearing Level 1 and Level 2 with the bonus activated ($150 + 200 = 350\text{ 🪙}$).


* **Sloop Unlock (500 🪙):**
* *Standard Player:* Naturally unlocked around Level 4 or 5.
* *2X Ad Player:* Unlocked by Level 3.


* **Warship Unlocks (Bombard: 1,400 🪙 / Ironclad: 1,800 🪙):**
* Accumulation safely positions the player to purchase their first heavy Warship around Level 12–15, right before the Level 16 "The Iron Wall" bottleneck.




* **Full Fleet Max (All 4 Ships to Tier 3):**
* Cumulative cost to buy and max all vessels = **16,650 🪙**.
* Total career gold across all 45 base clears = $\approx 15,200\text{ 🪙}$.
* With failed run scrap and occasional 2X opt-in bonuses, players comfortably finish maxing their fleet right as they defeat Bone-Beard on Level 45.