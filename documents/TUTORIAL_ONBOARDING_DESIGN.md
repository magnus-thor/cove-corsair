# Cove Corsair - Tutorial & Onboarding System Design

> **Document Status:** Active Implementation  
> **Related Systems:** [`ShipyardUI.gd`](file:///f:/projects/cove-corsair/src/ui/shipyard/shipyard_ui.gd), [`settlement_screen.gd`](file:///f:/projects/cove-corsair/src/ui/settlement/settlement_screen.gd), [`GameState.gd`](file:///f:/projects/cove-corsair/src/core/game_state.gd), [`pirate_lair_hub.gd`](file:///f:/projects/cove-corsair/src/features/hub/pirate_lair_hub.gd)

---

## 🎯 1. Overview & Objectives

This document specifies the step-by-step onboarding tutorial for new players in **Cove Corsair**. The tutorial introduces core runner mechanics, rewarded currency doubling, ship progression from **The Dinghy** to **The Sloop**, vessel upgrading, crew recruitment, and the flagship outfitting loop.

### Core Pillars
1. **The Dinghy as a Throwaway Raft:** The Dinghy serves exclusively as a weak starter vessel for Levels 1 & 2. It has $3\text{ HP}$ (giving newcomers a 2-mistake margin) and a single bow chaser firing at $0.38\text{s}$ (so the Sloop's twin chasers at $0.36\text{s}$ deliver nearly double the firepower and spread).
2. **Permanent Retirement:** Once the Sloop is purchased after Level 2, the Dinghy is permanently hidden from the Shipyard catalog. The Sloop becomes the permanent baseline flagship.
3. **Paced Discovery (Levels 1–5):**
   * **Levels 1–2:** Played on base Dinghy; Shipyard is locked.
   * **After Level 2:** Shipyard unlocks ➔ Buy & Equip **The Sloop** ($400\text{ 🪙}$).
   * **Level 3:** Maiden Sloop run with twin bow chasers.
   * **After Level 3:** Upgrade Sloop to **Tier 2** (unlocks Mid-Deck Crew socket).
   * **Level 4:** Sloop Tier 2 run.
   * **After Level 4:** Recruit & auto-equip **Monkey Bomber** crew.
   * **Level 5+:** Tutorial complete; full game open.
4. **Mid-Deck Standardization:** All vessels in the game unlock their Mid-Deck Crew socket after **1 upgrade (Tier 2)**.
5. **Strict UI Guidance:** Animated arrow/finger pointer + Quartermaster speech banner; non-target buttons are temporarily disabled during tutorial steps to guarantee focus.
6. **Graceful Economy Guards:** Level 1 & 2 payouts guarantee $400+\text{ 🪙}$ for the Sloop. For Tier 2 upgrade and crew purchase, if a player is short on doubloons, the cost is dynamically discounted to their current balance.

---

## 🧭 2. Step-by-Step Onboarding Flow (Levels 1–5)

```
[LEVEL 1: DINGHY T1] ──► [CLAIM 2X GOLD (NO AD)] ──► [LEVEL 2: DINGHY T1]
 (Swerve Hand Prompt)                                (Shipyard Locked)
                                                             │
                                                             ▼
[LEVEL 3: SLOOP T1]  ◄── [SET SAIL: LVL 3]  ◄── [SHIPYARD: BUY SLOOP]
 (Twin Bow Chasers)                             (Dinghy Hidden Forever)
        │
        ▼
[SHIPYARD: MONKEY CREW] ──► [LEVEL 4: SLOOP + MONKEY] ──► [LEVEL 5: PHANTOM DREDGE]
(Auto-Equip to Mid-Deck)   (Explosive Coconut Test)       (Tutorial Complete!)
```

---

### Step 1: Level 1 — First Run & Basic Controls
* **Starting State:**
  * Active Vessel: **The Dinghy (Tier 1)** ($2\text{ HP}$, 1 Single Bow Chaser with $0.45\text{s}$ cooldown, $10.5\text{ m/s}$ lateral swerve).
  * Banked Doubloons: $0\text{ 🪙}$.
  * Shipyard / Drydock State: **LOCKED** (subtitle: `"UNLOCKS AFTER LEVEL 2"`).
* **In-Game Prompts:**
  * Animated floating swipe hand on track start: *"Drag / Swerve to Steer"*. Auto-dismisses upon first player touch/swerve.
  * Barrels line up cleanly with single cannon lane.
  * Multiplier gate introduces follower fleet mechanics.
* **Victory & Settlement Flow:**
  * Level completes upon reaching the dock at $200\text{m}$.
  * Settlement Screen displays `VICTORY!` in gold with stars.
  * Pulsating golden highlight focuses on **`[ ✦ CLAIM 2X BONUS DOUBLOONS ]`**.
  * **Ad-Skip Exemption Rule:** For Level 1 completion, tapping `[ ✦ CLAIM 2X BONUS ]` strictly skips any ad and immediately doubles the payout (~$120\text{--}140\text{ Doubloons}$ banked).
  * `[ SHIPYARD ]` button on Settlement screen is disabled / locked.
  * Primary action leads back to Hub or directly to Level 2.

---

### Step 2: Level 2 — Obstacle Evasion & The Rowboat Ceiling
* **Starting State:**
  * Active Vessel: The Dinghy (Tier 1, unmodified).
  * Shipyard / Drydock remains locked.
* **In-Game Flow:**
  * Sea mines and barricade corridors with clear central openings.
  * Dinghy's slower fire rate makes clearing heavy barricades challenging, encouraging evasive steering.
* **Settlement & Economy:**
  * Payout yields ~$160\text{--}200\text{ Doubloons}$, bringing total vault to **$400+\text{ Doubloons}$**.
  * On victory, returning to Pirate Lair triggers the Shipyard unlock sequence.

---

### Step 3: Post-Level 2 Hub — Shipyard Unlocked & Sloop Commission
* **Hub Sequence:**
  * Upon loading Pirate Lair Hub, the Drydock hotspot sparkles and unlocks.
  * Quartermaster guidance banner:
    > *"Well rowed, Captain! But that rowboat won't survive the open waters ahead. To the Drydock! Commission THE SLOOP!"*
  * Animated finger/arrow pointer points directly to the Drydock hotspot pin. Unrelated pins (Endless, Settings) are blocked.
* **Shipyard UI Guidance (Vessels Tab):**
  * The Shipyard opens directly to the **Vessels** tab.
  * **Dinghy Retirement:** The Dinghy is **completely hidden** from the catalog grid.
  * **The Sloop** card ($400\text{ 🪙}$) is selected and highlighted.
  * Animated pointer pulses over the golden **`[ COMMISSION SLOOP (400 🪙) ]`** button.
  * Once tapped:
    * Sloop is purchased and **automatically set as active vessel**.
    * The action button changes to `EQUIPPED`.
    * Quartermaster prompt directs the player to exit or tap **`[ SET SAIL ]`**.
    * Guidance leads to River Map with **Level 3** selected.

---

### Step 4: Level 3 — Sloop Maiden Voyage
* **Starting State:**
  * Active Vessel: **The Sloop (Tier 1)** ($4\text{ HP}$, Twin Bow Chasers $0.36\text{s}$, $11.5\text{ m/s}$ speed). Sockets: `["BowMount"]`.
* **In-Game Flow:**
  * Twin forward chasers shred through barricades and rafts at double density.
  * Channel width and boat speed showcase the dramatic leap over the Dinghy.
* **Settlement:**
  * Standard gold payout awarded (~$150\text{--}200\text{ 🪙}$).
  * Settlement returns to Hub with guidance to visit the Shipyard.

---

### Step 5: Post-Level 3 — Sloop Tier 2 Upgrade (Socket Unlock)
* **Hub & Shipyard Guidance:**
  * Quartermaster dialogue:
    > *"She cuts the tide like a razor! Now let's reinforce her deck timbers to mount crew battle stations!"*
  * Pointer guides player into Shipyard on Sloop card.
  * Action button pulses on **`[ UPGRADE TO TIER 2 ]`** (Standard cost: $250\text{ 🪙}$; dynamically discounted to current vault balance if player has less).
  * Purchasing Tier 2:
    * Sloop reaches Tier 2 (`Tuned Rigging`: $4\text{ HP}$, $11.8\text{ m/s}$, +5% Firepower, unlocks **`MidDeckCrew`** socket).
* **Launch Prompt:**
  * Guidance directs player to **Level 4** on River Map.

---

### Step 6: Level 4 — Armored Waters
* **Starting State:**
  * Active Vessel: The Sloop (Tier 2).
* **In-Game Flow:**
  * Faster paced enemy rafts, floating powder kegs, and armored river skiffs.
* **Settlement:**
  * Payout awarded (~$150\text{--}200\text{ 🪙}$).
  * Guidance directs player back to the Shipyard to recruit crew.

---

### Step 7: Post-Level 4 — Recruiting & Auto-Equipping Monkey Bomber
* **Shipyard Guidance (Crew Tab):**
  * Quartermaster dialogue:
    > *"Every flagship needs a salty crew! Recruit a Monkey Bomber to pitch explosive coconuts from your new mid-deck station!"*
  * Pointer guides player to the **Crew** tab.
  * Non-target tabs are disabled during this step.
  * **Monkey Bomber** card is focused.
  * Pointer pulses on **`[ RECRUIT CREW (50 🪙) ]`** (discounted if player has less).
  * **Auto-Equip Execution:**
    * When purchased, Monkey Bomber is automatically bound to Sloop's `MidDeckCrew` socket via `GameState.auto_equip_to_first_available_socket()`.
* **Launch Prompt:**
  * Guidance directs player to **Level 5**.

---

### Step 8: Level 5+ — Tutorial Complete!
* **Starting State:**
  * Active Vessel: **The Sloop (Tier 2) + Monkey Bomber equipped**.
* **Transition:**
  * The tutorial state flag `tutorial_step` reaches `TUTORIAL_COMPLETED`.
  * All UI restrictions, locked tabs, and guided overlays are permanently removed.
  * Standard game loop, endless gauntlets, and freeform outfitting are fully active.

---

## 🛠️ 3. Technical Architecture & State Tracking

### State Machine in `GameState.gd`
```gdscript
enum TutorialStep {
    NOT_STARTED = 0,         # Before Level 1 start
    LEVEL_1_IN_PROGRESS = 1, # First run on Dinghy
    LEVEL_1_COMPLETED = 2,   # Level 1 victory, 2x claimed
    LEVEL_2_IN_PROGRESS = 3, # Sailing Level 2 on Dinghy
    LEVEL_2_COMPLETED = 4,   # Shipyard unlocked! Guided to buy Sloop
    SLOOP_PURCHASED = 5,     # Sloop bought & equipped, ready for Level 3
    LEVEL_3_IN_PROGRESS = 6, # Sailing Level 3
    LEVEL_3_COMPLETED = 7,   # Guided to upgrade Sloop to Tier 2
    SLOOP_T2_UPGRADED = 8,   # Sloop upgraded, ready for Level 4
    LEVEL_4_IN_PROGRESS = 9, # Sailing Level 4
    LEVEL_4_COMPLETED = 10,  # Guided to recruit Monkey Bomber
    CREW_EQUIPPED = 11,      # Monkey Bomber auto-equipped, ready for Level 5
    COMPLETED = 12           # Full tutorial complete
}
```

### Save Migration & Legacy Profiles
* When loading save data:
  * If `GameState.highest_unlocked_level > 2` or `GameState.is_vessel_unlocked("sloop")`:
    * `tutorial_step` automatically defaults to `TutorialStep.COMPLETED`.
* In Settings / Harbor Calibration Menu:
  * Add a **`[ 🔄 RESET TUTORIAL ]`** button to set `tutorial_step = 0`, reset active vessel to Dinghy, and allow instant playtesting from scratch.

### Reusable Tutorial Guidance Overlay Component
* `TutorialGuidanceOverlay.tscn` / `.gd`:
  * Pointer hand/arrow with bobbing tween.
  * Glowing golden target highlight ring (`%TargetHighlight`) with breathing animation.
  * Speech banner (`%BannerPanel`) with Quartermaster portrait + typewriter animated text (`visible_ratio` tweened from 0.0 to 1.0).
  * Auto-wrapped compact dialogue box (sized cleanly to fit text).
  * Ambient screen dimming shield (`Color(0, 0, 0, 0.32)`) keeping non-target areas dim without obstructing visibility.
  * Voiceover Audio Player (`%VoicePlayer`) playing clips from `res://assets/audio/voice/tutorial/`.
  * Target node locator: positions pointer and glowing ring dynamically over target controls (`%BtnDrydock`, `%ActionButton`, `%TabCrew`, etc.).
  * Input shield: blocks mouse/touch input on non-target controls while letting target button clicks through.

---

## 🎙️ 4. ElevenLabs Voiceover Audio Manifest & Production Guide

All audio clips are located in:
```
res://assets/audio/voice/tutorial/
```
Supported formats: `.mp3` (recommended), `.ogg`, or `.wav`.  
The game automatically plays the audio in sync with the typewriter text animation. If an audio file is not present, the text still types out smoothly at ~30 characters per second.

### Character Persona: **The Quartermaster**
* **ElevenLabs Recommended Voice:** Grizzled, weathered pirate veteran, warm mentor tone, confident and enthusiastic.
* **Format:** 44.1kHz MP3, standard mono or stereo.

| Audio File Name (`<voice_id>.mp3`) | Action / Trigger | In-Game Target | Dialogue Script |
|---|---|---|---|
| `tut_hub_open_charthouse.mp3` | Fresh Start in Cove Hub | Chart House hotspot | *"Ahoy, Captain! Tap the Chart House to plot yer course and open the river roadmap!"* |
| `tut_hub_open_charthouse_lvl2.mp3` | Post-Lvl 1 in Cove Hub | Chart House hotspot | *"First voyage survived! Chart your course for River Level 2!"* |
| `tut_map_select_level_1.mp3` | Roadmap Opened (Fresh) | Level 1 Milestone Node | *"Select the first river channel to begin yer voyage!"* |
| `tut_map_set_sail_1.mp3` | Level 1 Detail Modal Open | "SET SAIL" Button | *"All hands on deck! Tap SET SAIL to enter the river!"* |
| `tut_settle_claim_2x.mp3` | Level Complete Victory | "CLAIM 2X GOLD" Button | *"A true corsair always doubles their haul! Claim yer bonus gold!"* |
| `tut_settle_continue_1.mp3` | Level 1 Bonus Claimed | "NEXT LEVEL" Button | *"Doubloons banked in the vault! Onward to the next voyage!"* |
| `tut_map_select_level_2.mp3` | Level 1 Cleared on Map | Level 2 Milestone Node | *"Channel Two lies ahead! Prepare to maneuver through treacherous rocks!"* |
| `tut_map_set_sail_2.mp3` | Level 2 Detail Modal Open | "SET SAIL" Button | *"Cast off! Let's conquer the second stretch!"* |
| `tut_settle_return_to_hub.mp3` | Level 2 & 3 Victory Claimed | "RETURN TO COVE" Button | *"We've got the coin! Return to Smuggler's Cove to visit the Drydock!"* |
| `tut_hub_open_drydock.mp3` | Post-Lvl 2 in Cove Hub | Drydock hotspot | *"Well rowed, Captain! But that rowboat won't survive the open waters ahead. To the Drydock! Commission THE SLOOP!"* |
| `tut_shipyard_buy_sloop.mp3` | Shipyard Open (Vessels) | "COMMISSION SLOOP" Button | *"Here she is! Commission THE SLOOP with twin bow chasers and reinforced hull!"* |
| `tut_shipyard_close_after_sloop.mp3` | Sloop Commissioned | Close / Return Button | *"The Sloop is yours and equipped as flagship! Close the Drydock to return to the Cove!"* |
| `tut_hub_open_map_lvl3.mp3` | Sloop Equipped in Hub | Chart House hotspot | *"The Sloop is rigged and ready! Chart a course for River Level 3!"* |
| `tut_map_select_level_3.mp3` | Roadmap after Sloop | Level 3 Milestone Node | *"Select Channel Three! Time to unleash the Sloop's twin cannons!"* |
| `tut_map_set_sail_3.mp3` | Level 3 Detail Modal Open | "SET SAIL" Button | *"Set Sail! Show those scoundrels the might of a true pirate sloop!"* |
| `tut_hub_drydock_for_crew.mp3` | Post-Lvl 3 in Cove Hub | Drydock hotspot | *"Every flagship needs a salty crew! To the Drydock to recruit a Monkey Bomber!"* |
| `tut_shipyard_hire_monkey_bomber.mp3` | Shipyard Crew Tab | "RECRUIT CREW" Button | *"Recruit Monkey Bomber! They auto-equip to your mid-deck!"* |
| `tut_shipyard_close_after_crew.mp3` | Monkey Bomber Hired | Close / Return Button | *"Monkey Bomber equipped! Close the Drydock to set sail!"* |
| `tut_hub_open_map_lvl4.mp3` | Crew Equipped in Hub | Chart House hotspot | *"Crew battle stations manned! Set sail on River Level 4!"* |
| `tut_map_select_level_4.mp3` | Roadmap after Crew | Level 4 Milestone Node | *"Crew stationed! Select Level 4 to test explosive coconuts!"* |
| `tut_map_set_sail_4.mp3` | Level 4 Detail Modal Open | "SET SAIL" Button | *"Cast off! Let's rain coconuts down the river!"* |
| `tut_map_return_to_hub.mp3` | Roadmap Lvl 3/4 Back Button | Return to Cove Button | *"Recruit crew first! Return to Smuggler's Cove to visit the Drydock!"* |
| `tut_map_return_to_hub_upgrade.mp3` | Roadmap Lvl 4 Back Button | Return to Cove Button | *"Upgrade your vessel first! Return to Smuggler's Cove to visit the Drydock!"* |
| `tut_settle_continue_4.mp3` | Level 4 Victory Claimed | "NEXT LEVEL" Button | *"The final showdown awaits! Onward to The Phantom Dredge!"* |
| `tut_settle_return_to_hub_upgrade.mp3` | Level 4 Settle Screen | "RETURN TO COVE" Button | *"The Dreadnought awaits! Return to Smuggler's Cove to upgrade your flagship at the Drydock!"* |
| `tut_hub_drydock_for_upgrade.mp3` | Post-Lvl 4 in Cove Hub | Drydock hotspot | *"The waters ahead are treacherous! Visit the Drydock to upgrade your Sloop to Tier 2!"* |
| `tut_shipyard_upgrade_sloop_t2.mp3` | Shipyard Upgrade Tab | "UPGRADE SLOOP" Button | *"Upgrade Sloop to Tier 2 for reinforced hull timbers and higher speed!"* |
| `tut_shipyard_close_after_upgrade.mp3`| Sloop Upgraded | Close / Return Button | *"Sloop upgraded! Close the Drydock to challenge the Dreadnought!"* |
| `tut_hub_open_map_lvl5.mp3` | Post-Upgrade in Hub | Chart House hotspot | *"Your flagship is reinforced and ready! Chart a course for River Level 5 to challenge the Dreadnought!"* |
| `tut_map_select_level_5.mp3` | Roadmap before Boss | Level 5 Milestone Node | *"Plot your course for Channel 5, Captain! The river belongs to you!"* |
| `tut_map_set_sail_5.mp3` | Level 5 Detail Modal Open | "SET SAIL" Button | *"All hands on deck! Tap SET SAIL to challenge the Dreadnought!"* |
| `tut_settle_continue_5.mp3` | Boss Cleared / Endless | "NEXT LEVEL" Button | *"Victory achieved! Onward to the next voyage!"* |

> [!NOTE]
> All 32 clips above have been generated via ElevenLabs API using voice ID `4Vl3K2x290GidNvuaLm7`, saved to `res://assets/audio/voice/tutorial/`, and imported into Godot Engine.


