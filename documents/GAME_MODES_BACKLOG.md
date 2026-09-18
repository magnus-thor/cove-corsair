# Cove Corsair: Future Gameplay Modes Backlog

## 1. Corsair Gauntlet (Endless Extraction / High-Seas Push-Your-Luck)
* **Status:** In Development (Primary Next Mode).
* **Core Loop:** Endless procedurally stitched river chunks with escalating speed and hazard density. Mid-run wager checkpoints allow cashing out safely or pushing forward for compounding multipliers with full-loss risk.

---

## 2. Smuggler's Run (Cargo Delivery & Hull Tilt Physics)
* **Concept:** Time-attack delivery mode where navigating safely outweighs aggressive kill streaks.
* **Mechanics:**
  * **Fragile Cargo Stacks:** Ship carries 1–3 heavy contraband crates on deck.
  * **Tilt / Overboard Risk:** Aggressive lane-lerping, hard collisions, or taking broadside fire tilts the vessel, causing cargo health loss or crates tumbling overboard.
  * **Draft Scaling:** Vessel sits lower in the water per crate loaded (slower acceleration, heavier ramming momentum).
  * **Payout:** Gold reward dynamically calculated by intact cargo delivered to the destination port buoy.

---

## 3. Plunder Escort & Merchant Ambush (Relative Velocity Convoy)
* **Concept:** Dual variant mode: escorting an allied treasure barge downriver or hunting a royal bullion convoy before it escapes to open sea.
* **Mechanics:**
  * **Moving Objective:** Escort/target moves down the center channel at a constant speed; player throttles up or down to flank.
  * **Decoupled Damage Model:** Leverages `Hitbox3D`/`Hurtbox3D` on the target barge. Player body-blocks ram skiffs and intercepts torpedoes.
  * **In-Flight Repairs:** Collecting floating repair crates in lateral lanes transfers armor restoration to the target barge.

---

## 4. Duel of Blades (Sid Meier's Pirates! Style Swordplay)
* **Concept:** 1v1 tactical fencing mini-game triggered upon ramming or halting an enemy captain's flagship.
* **Mechanics:**
  * **View:** Low-angle side-profile duel on the quarterdeck.
  * **Rock-Paper-Scissors Combat:**
    * *High Slash* beats *Low Parry*.
    * *Low Thrust* beats *High Parry*.
    * *Dodge / Jump Back* evades heavy unblockable lunges.
  * **Advantage Tug-of-War:** Successful strikes push the opponent backward toward the plank or cabin wall until a duel finisher triggers.

---

## 5. Boarding Action: Crowd Defense & Lane Gates
* **Concept:** Camera shifts to a top-down deck view or top-down land runner upon grappling an enemy vessel.
* **Variant A: Multiplier Crowd Runner ("Fake-Ad" Style Crowd War):**
  * Player controls an advancing pirate crew running forward along a multi-lane boarding ramp or jetty.
  * Passing through positive modifier gates (`+5 Swashbucklers`, `x2 Crew`) multiplies boarding party size.
  * Encountering defensive barricades, gunpowder barrels, or hostile lines trades crew numbers 1:1.
* **Variant B: Targeted Deck Defense (Sector Clicker / Whack-A-Mole Defense):**
  * Enemy raiders grapple onto specific sectors of your deck (Prow, Midship Port, Midship Starboard, Stern).
  * Player taps/clicks sectors to command active crew to repel invaders.
  * **Strength Balancing:**
    * Sectors have an *Infestation Gauge* that ticks up per second a raider remains.
    * Assigned crew members deal tick damage to attackers based on their shipyard mastery level (e.g., Barnaby clears gunpowder swarms quickly; Sirena pins high-threat elites with harpoon nets).
