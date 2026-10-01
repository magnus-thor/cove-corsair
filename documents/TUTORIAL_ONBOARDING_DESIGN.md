# Cove Corsair - Tutorial & Onboarding System Design

> **Document Status:** Future Feature Specification (To Be Implemented Later)  
> **Related Systems:** [`ShipyardUI.gd`](file:///f:/projects/cove-corsair/src/ui/shipyard/shipyard_ui.gd), [`settlement_screen.gd`](file:///f:/projects/cove-corsair/src/ui/settlement/settlement_screen.gd), [`GameState.gd`](file:///f:/projects/cove-corsair/src/core/game_state.gd)

---

## 🎯 1. Overview & Objectives

This document specifies the step-by-step onboarding tutorial for new players in **Cove Corsair**. The tutorial introduces core runner mechanics, rewarded currency doubling, ship upgrades in the Shipyard, crew recruitment, and the flagship progression path from **The Dinghy** to **The Sloop**.

---

## 🧭 2. Step-by-Step Onboarding Flow (Levels 1–4)

```
[LEVEL 1] ──► [CLAIM 2X GOLD] ──► [SHIPYARD] ──► [UPGRADE DINGHY T2]
  (Dinghy T1)   (Skip Ad Guaranteed)                  (Patched Planks)
                                                             │
                                                             ▼
[LEVEL 3] ◄── [LEVEL 2] ◄── [AUTO-EQUIP CREW] ◄── [RECRUIT FIRST CREW]
 (Dinghy T2)   (Dinghy+Crew)   (Monkey Bomber)
      │
      ▼
[SHIPYARD: BUY SLOOP] ──► [LEVEL 4: SLOOP MAIDEN RUN] (Wide Broadside Channels)
```

---

### Step 1: Level 1 — First Run & Basic Controls
* **Starting State:**
  * Active Vessel: **The Dinghy (Tier 1)** ($2\text{ HP}$, 1 Single Bow Chaser, $10.5\text{ m/s}$ lateral swerve).
  * Banked Doubloons: $0\text{ 🪙}$.
* **In-Game Prompts:**
  * Floating finger/arrow prompt on track start: *"Drag / Swerve to Steer"*.
  * Barrels line up cleanly with single cannon line: *"Cannons auto-fire on targets ahead!"*
  * +10 Multiplier Gate: *"Pass through gates to recruit follower escorts!"*
* **Victory & Settlement Flow:**
  * Level completes upon reaching the dock at $200\text{m}$.
  * The Settlement Screen displays `VICTORY!` in gold with stars.
  * A pulsating golden highlight focuses on **`[ ✦ CLAIM 2X BONUS DOUBLOONS ]`**.
  * **Tutorial Exemption Rule:** For this first completion, tapping `[ ✦ CLAIM 2X BONUS ]` **strictly skips any rewarded video ad** and immediately doubles the payout (~$120\text{--}140\text{ Doubloons}$ total credited to vault).

---

### Step 2: First Shipyard Visit & Dinghy Tier 2 Upgrade
* **Hub Navigation:**
  * Upon returning to the Pirate Lair / Hub, a highlight pointer directs the player to the **SHIPYARD** button.
  * Quartermaster Dialogue / Modal:
    > *"Welcome to the Cove, Captain! That rowboat won't last long against Black-Beard's fleet. Let's patch her planks before the tide rises!"*
* **Guided Upgrade Action:**
  * The Shipyard opens directly on the **Vessels** tab with **The Dinghy** focused.
  * The **UPGRADE (50 🪙)** button pulses with a pointer hand.
  * Player purchases **Tier 2: Patched Planks**:
    * Hull HP increases from $2\text{ HP} \to 3\text{ HP}$.
    * Unlocks the **Mid-Deck Crew Hardpoint Socket**.
  * Vault remaining: ~$70\text{--}90\text{ Doubloons}$.

---

### Step 3: Crew Recruitment & Auto-Equip (Pre-Level 2)
* **Crew Tab Prompt:**
  * Quartermaster guidance moves to the **Crew** tab:
    > *"A captain is only as good as their crew! Recruit a Monkey Bomber to pitch volatile coconuts at oncoming raiders."*
  * The **Monkey Bomber** card ($50\text{ 🪙}$) is highlighted.
* **Auto-Equip Mandate (Core Quality-of-Life Rule):**
  * When a player purchases any crew member or deck weapon in the Shipyard, the game **MUST automatically equip it** to the first compatible open socket on the active vessel.
  * The player does *not* need to navigate to an equipment menu or manually drag sockets during onboarding.
* **Launch Prompt:**
  * Arrow points to **SET SAIL** ➔ selects **Level 2** on the River Map.

---

### Step 4: Level 2 — Crew Bombardment & Sea Mines
* **Active Vessel:** The Dinghy (Tier 2) + Monkey Bomber equipped on Mid-Deck.
* **In-Game Flow:**
  * Monkey Bomber lobbed coconut explosives actively target rafts and barrels.
  * Introduces wide sea mine gates with obvious open evasion corridors.
  * Demonstrates the value of explosive splash damage alongside direct cannon fire.
* **Settlement:**
  * Standard gold payout banked (~$150\text{--}200\text{ Doubloons}$, bringing total vault to ~$300\text{--}400$).

---

### Step 5: Level 3 & The Sloop Threshold
* **Gameplay:**
  * Introduces long-range Iron Gunner skirmishes and a wooden barricade wall with a clean central opening.
* **Economic Threshold:**
  * Completing Level 3 pushes the player's cumulative savings past **$500\text{ Doubloons}$** (the exact purchase price of **The Sloop**).

---

### Step 6: Purchasing The Sloop & Maiden Voyage (Level 4)
* **Hub Recommendation Prompt:**
  * Settlement / Hub displays an alert badge on Shipyard:
    > *"You've outgrown this humble rowboat, Captain! Commission THE SLOOP at the Shipyard for twin bow chasers and unmatched sea speed!"*
* **Purchase Action:**
  * Player purchases **The Sloop** ($500\text{ 🪙}$).
  * Sloop is automatically set as the active flagship.
* **Level 4 Deployment:**
  * Player enters Level 4 with their newly commissioned Sloop.
  * Level 4 layout must feature broad river channels ($12\text{m}$) and open broadside engagements where the Sloop's speed and twin forward chasers shine.

---

## 📣 3. Adaptive In-Game Coach UI (Defeat Tactical Advice)

When a player fails on key campaign milestones, the Settlement Defeat Screen presents contextual tactical coaching with a direct deep-link button to the Shipyard:

```
┌─────────────────────────────────────────────────────────────┐
│                       SHIP SUNK!                            │
│              HULL BREACHED - TREASURE RETAINED              │
├─────────────────────────────────────────────────────────────┤
│  💡 QUARTERMASTER'S TACTICAL ADVICE:                        │
│                                                             │
│  "Captain! These fortified reefs and barricades are too     │
│   dense for our forward chasers! Commission the             │
│   BOMBARD SKIFF at the Shipyard — its heavy mortar shells   │
│   launch clean OVER obstacles and obliterate clusters!"     │
│                                                             │
│   [ GO TO SHIPYARD ]                 [ RETRY WITH SLOOP ]   │
└─────────────────────────────────────────────────────────────┘
```

### Contextual Defeat Prompts

#### Milestone 5–9: The Sloop Difficulty Spike & Endless Farming Directive
* **Core Design Philosophy:**
  * Levels following the Sloop acquisition intentionally introduce sharp difficulty jumps (aggressive mob densities, narrower channels, fortified barricades).
  * **Critical Rule:** The game MUST NOT nerf these level difficulties or artificially inflate Sloop base stats to make the player breeze through. Progression walls are vital to create an organic, compelling reason to play **Endless Voyage**.
* **Condition:** Player is defeated on Level 5, 6, 7, 8, or 9 while using The Sloop (or fails 2 consecutive runs on any of these levels).
* **Dialogue:**
  > *"Captain! The waters ahead grow treacherous and our Sloop's standard timber won't hold against these swarming gunners! Set sail on an **Endless Voyage** to amass doubloons, then visit the Shipyard to reinforce our hull and tune our twin chasers!"*
* **Action:**
  * Primary Button: `[ 🌊 SAIL ENDLESS VOYAGE ]` (deep-links directly into Endless Mode).
  * Secondary Button: `[ 🛠️ UPGRADE AT SHIPYARD ]` (deep-links to Shipyard Sloop upgrades).
  * Tertiary Button: `[ RETRY LEVEL ]`.

#### Milestone 10–12: Fortified Reefs & Barricades
* **Condition:** Player defeated on Level 10, 11, or 12 while using The Sloop or The Dinghy.
* **Dialogue:**
  > *"Captain! These fortified reefs and barricades are too dense for our forward chasers! Commission the **Bombard Skiff** at the Shipyard — its heavy mortar launches high over coral and shatters fortified clusters with explosive splash!"*
* **Action:** `[ GO TO SHIPYARD ]` button deep-links directly to the Bombard Skiff purchase card.

#### Milestone 18–20: Minefield Ramparts & Armored Fleets
* **Condition:** Player defeated on Level 18, 19, or 20 while using The Sloop or The Bombard Skiff.
* **Dialogue:**
  > *"The enemy's broadsides and explosive minefields are tearing right through our timbers! We need an **Ironclad** to absorb the blast and smash through their frontline with triple heavy cannons!"*
* **Action:** `[ GO TO SHIPYARD ]` button deep-links directly to the Ironclad purchase card.

#### Agile Weave Advice (General)
* **Condition:** Player suffers 3+ collisions with rock/reef terrain using heavy hulls (Ironclad / Bombard).
* **Dialogue:**
  > *"This channel's coral shallows are too narrow for our heavy hull! Switch to the agile **Sloop** or nimble **Dinghy** to weave through the rock shoals."*

---

## 📋 4. Implementation Requirements Checklist (For Future Tutorial Phase)

- [ ] **Tutorial State Tracker:** Add `tutorial_step: int` or `tutorial_flags: Dictionary` to `GameState.gd`.
- [ ] **Level 1 Ad-Skip Guard:** Modify `SettlementScreen` to skip ad check on initial completion and guarantee 2X doubloons.
- [ ] **Auto-Equip System:** Ensure `GameState.buy_crew()` and `GameState.buy_weapon()` automatically bind purchased items to the first available socket.
- [ ] **UI Overlay Pointer:** Create reusable finger/arrow tutorial callout component for Hub and Shipyard.
- [ ] **Contextual Defeat Coach Panel:** Add `TacticalAdvicePanel` to `settlement_screen.tscn` displaying milestone hints and deep-linking to the Shipyard.
- [ ] **Sloop Endless Farming Prompt:** Implement the `[ 🌊 SAIL ENDLESS VOYAGE ]` defeat coach prompt on Levels 5–9 when sailing the Sloop, preserving intentional difficulty spikes.
