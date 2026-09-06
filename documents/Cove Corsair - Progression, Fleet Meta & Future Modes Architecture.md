# **Cove Corsair \- Progression, Fleet Meta & Future Modes Architecture**

This document details the long-term progression loop, sidegrade vessel balancing matrix, campaign level vectors, and prospective future gameplay modes.

## **⚖️ 1\. Horizontal Vessel Balancing: Specialization Over Raw Power**

Vessels are balanced as distinct tactical choices (sidegrades) rather than a linear tier ladder.

### **Fleet Roster Matrix**

| Vessel | Archetype | Core Strength | Core Tradeoff | Best Suited Level Profile |
| :---- | :---- | :---- | :---- | :---- |
| **The Dinghy** | Agile Skiff | High agility ($12.0\\text{ m/s}$), small hitbox ($1.6\\text{m}$)  | Extreme fragility ($1\\text{ HP}$)  | **Hazard Heavy:** Narrow reef splits, dense minefields, high volume of $1\\text{-}2\\text{ HP}$ barrels.  |
| **The Sloop** | Tactical Cruiser | Balanced mobility ($11.0\\text{ m/s}$), wide swivel arc coverage  | Average hull ($5\\text{ HP}$), moderate damage  | **Dynamic Flankers:** Strafing Grave Skiffs, multi-lane split gates, and medium mob density.  |
| **The Ironclad** | Armored Brawler | Massive durability ($8\\text{ HP}$), heavy forward firepower  | Sluggish swerve ($7.5\\text{ m/s}$), huge collision footprint ($2.4\\text{m}$)  | **Siege Heavy:** High-HP Turtle Rafts, unavoidable toxic gas clouds, straight-line DPS checks.  |
| **The Bombard Skiff** *(Proposed)* | Artillery Mortar | Massive AoE splash, clears clustered rows | Low direct fire rate, fragile hull ($3\\text{ HP}$) | **Dense Formations:** Interlocking wooden barricades and tight clusters of explosive Fuse Barrels.  |

## **🛠️ 2\. Standardized 3-Tier Upgrade Progression**

Each vessel supports two purchasable upgrades ($3\\text{ tiers total}$):

\[ Tier 1: Stock Hull \] ───► \[ Tier 2: Crew Hardpoint \] ───► \[ Tier 3: Artillery Battery \]  
   Base cannons & HP           Unlocks Monkey or Skeleton      Unlocks Swivel / Heavy Mounts

* **Tier 1 (Base Purchase):** Stock hull with baseline forward cannons and standard hull health.  
*   
* **Tier 2 (Crew Attachment):** Unlocks autonomous deck sockets for the Monkey Bomber (AoE explosives) or Skeleton Tosser (lobbed axes).  
*   
* **Tier 3 (Artillery Battery):** Mounts broadside swivel guns or heavier chaser cannons to maximize lane fire coverage.  
* 

## **🌊 3\. Level Design Vectors (Validating Player Choice)**

Campaign levels alternate between two design extremes to prevent one vessel from dominating the entire game:

* **Vector A: The Navigational Gauntlet (Favors The Dinghy)**  
* 

  * Dense placement of Sea Mines, narrow rock reefs, and geyser chokepoints.  
  *   
  * Mobs are fast and fragile (Skeleton Rowers, $3\\text{ HP}$).  
  *   
  * *Failure Mode for Heavy Ships:* The Ironclad's wide collision boundary clips mines and reefs that the Dinghy easily slips through.  
  *   
* **Vector B: The Hull & DPS Check (Favors The Ironclad)**  
* 

  * Full-river Barricade Walls, unavoidable Biogas Pod clouds, and heavily armored Turtle Rafts ($30\\text{ HP}$).  
  *   
  * *Failure Mode for Light Ships:* The Dinghy lacks the burst damage to punch through barriers before crashing, resulting in instant destruction.  
  * 

## **📈 4\. Organic Progression & Farming Loop**

* **In-Level Economy Farming:** Players retain all doubloons collected during a run even if their ship is destroyed.  
*   
* **Organic Retry Loop:** Failing a difficult stage 2–3 times naturally provides the doubloon buffer needed to afford the ship's next Tier upgrade in the Shipyard, eliminating the need to grind earlier stages.  
*   
* **Optional Rewarded Ads:** Post-run opt-in multipliers ($2\\times$ or $3\\times$ Doubloons) or single-use second-chance revives offer progression acceleration without halting gameplay flow for non-paying users.  
* 

## **❓ 5\. Stationary Broadside & Boarding Duels ("The Galleon Siege") *(MAYBE / FUTURE CONCEPT)***

**Status:** Low-priority design exploration for post-launch content or special event encounters.

### **Core Concept**

Instead of scrolling down an infinite river, the camera locks into a stationary cinematic side-view or tight angled perspective alongside an enemy war galleon. The player engages in a two-front battle: managing ship artillery while repelling enemy boarding parties.

\[ Player Flagship \] ◄════ Plank / Grapple Bridge ════► \[ Enemy Galleon \]  
  ├── Deck Cannon Batteries                            ├── Target: Powder Magazine  
  ├── Swivel Sniper Mounts                             ├── Target: Main Mast / Rigging  
  └── Player / Crew Melee Defense                      └── Target: Helm / Captain

### **Potential Mechanics**

* **Targeted Ship Destruction:** The enemy vessel is divided into distinct destructible target zones rather than a single health bar:  
* 

  * **Powder Magazine:** Heavy armor; destroying it deals massive critical damage to the entire ship.  
  *   
  * **Cannon Ports:** Knocking out active broadside cannons reduces incoming fire on the player's hull.  
  *   
  * **Masts & Sails:** Tearing down rigging prevents the enemy ship from maneuvering or breaking away.  
  *   
* **Deck Ingress (Boarding Defense):** Hostile mobs use grappling hooks and gangplanks to board the player's ship. Players direct deck crew or use touch-swipes/point-defense fire to neutralize boarders before hardpoints are disabled.  
*   
* **Retro Melee Duel Mode:**  
* 

  * Inspired by classic duels (*Prince of Persia*, *Sid Meier's Pirates\!*).  
  *   
  * Triggers when boarding the enemy flagship to face the Captain.  
  *   
  * 2-button or 3-direction touch controls: **High Strike**, **Low Strike**, and **Parry/Riposte** for snappy, rhythm-based mobile combat.

\---

## **🎯 6\. Advanced Weapon Archetypes & Tactical Mechanics *(FUTURE EXPANSION)***

To expand combat utility beyond standard projectile arcs, deck hardpoints and vessel sockets may equip specialized ordnance. These ballistics profiles dictate lane-clearing strategies and the architecture of future mob encounters.

### **Weapon Roster Matrix**

| Weapon Type | Firing Profile | Damage & Range | Tactical Specialty | Synergistic Level Hazards |
| :---- | :---- | :---- | :---- | :---- |
| **Standard Cannon** | Linear, single projectile | Moderate DPS, high distance | Versatile forward lane suppression | Basic rowers and isolated blockades |
| **Scattershot Carronade** | Radial 5-slug cone burst | Lethal proximity burst, sharp drop-off | Multi-lane swarm neutralization | Dense skiff clusters, expansive flotsam |
| **Harpoon Launcher** | High-speed tethered strike | Negligible raw damage, instant impact | Environmental manipulation and stuns | Remote Fuse Barrels and armored shields |
| **Greek Fire Siphon** | Persistent thermal spray | Extreme tick damage, $6\\text{m}$ reach | Bypasses shielding, melts infrastructure | Heavy Rafts, vines, and timber walls |

### **Level Design Synergies Enabled by New Weapons**

* **The Siphon Gauntlet (Area Denial & Meltdown):**  
  * Features impenetrable wooden barricades with flammable structural weak points.  
  * Armor-plated mobs that negate physical shot damage are vulnerable to prolonged thermal exposure.  
* **The Harpoon Funnel (Environmental Kinetic Play):**  
  * Encounters requiring players to retrieve explosive ordnance from adjacent lanes to dismantle shielded positions.  
  * Kinetic interaction with hazards becomes the primary DPS vector against fortified targets.  
* **The Carronade Ambush (Reaction-Time Chokepoints):**  
  * Rapids populated by dense, low-HP suicide skiffs emerging from obscured navigable turns.  
  * High mob density penalizes precision fire, rewarding broad-coverage carronade volleys.

