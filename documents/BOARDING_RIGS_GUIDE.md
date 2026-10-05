# Cove Corsair - Boarding Rigs Reference Guide

This document details the architecture, node hierarchy, and spatial coordinate conventions for all **Player Rigs** and **Enemy Boss Rigs** used in the Boarding Defense Arena.

---

## 1. Architecture Overview

During a boarding encounter, two distinct rigs are dynamically loaded into [`boarding_defense_arena.tscn`](file:///f:/projects/cove-corsair/src/features/boarding/boarding_defense_arena.tscn):
1. **Player Vessel Rig ([`PlayerBoardingRig`](file:///f:/projects/cove-corsair/src/features/boarding/rigs/player_boarding_rig.gd))**: Defines the player ship's physical deck floor, defendable zones, crew stations, player spawn, camera mount, and stern breach threshold.
2. **Enemy Vessel Rig ([`EnemyBoardingRig`](file:///f:/projects/cove-corsair/src/features/boarding/rigs/enemy_boarding_rig.gd))**: Defines the boss vessel's docking position, wake emitter, and plank launch points (origins) along the ship's gunwale.

```
       [ ENEMY VESSEL RIG ]                             [ PLAYER VESSEL RIG ]
   ┌──────────────────────────┐                    ┌──────────────────────────────┐
   │                          │                    │  [Bow Crew Station]          │
   │  Plank Origin (Bow)   •──┼───[Gangplank 0]───►│• ZoneBow (GrappleAnchor)    │
   │                          │                    │                              │
   │  Plank Origin (Mid)   •──┼───[Gangplank 1]───►│• ZoneMidship (GrappleAnchor) │
   │                          │                    │  [Player Spawn Point]        │
   │  Plank Origin (Stern) •──┼───[Gangplank 2]───►│• ZoneStern (GrappleAnchor)   │
   │                          │                    │  [Stern Crew Station]        │
   │  [Dock Position & Wake]  │                    │                              │
   └──────────────────────────┘                    │═══════[ BreachLine ]═════════│
                                                   └──────────────────────────────┘
```

---

## 2. What is the `GrappleAnchor`?

Inside each [`BoardingZone`](file:///f:/projects/cove-corsair/src/features/boarding/boarding_zone.gd), the **`GrappleAnchor`** (also aliased as `plank_anchor`) is a `Marker3D` positioned along the **player ship's starboard railing / gunwale** facing the enemy vessel.

### Key Roles:
1. **Gangplank Landing Target:** When the arena spawns gangplanks, each plank starts at the enemy's `PlankOrigin` and casts directly toward the player's corresponding `GrappleAnchor`. The plank angles and extends automatically to bridge the gap.
2. **Boarder Disembark Point:** Enemies run down the plank and step onto the player's deck at the `GrappleAnchor`'s world position before acquiring and charging the crew defender or marching down the deck.
3. **Targeting Reference:** When the player or crew aims at a boarding lane, the system checks `zone.grapple_anchor.global_position` to determine the aim vector toward the incoming assault.

---

## 3. Player Vessel Rig Anatomy

**Script:** [`PlayerBoardingRig`](file:///f:/projects/cove-corsair/src/features/boarding/rigs/player_boarding_rig.gd)  
**Scenes:** [`rig_sloop.tscn`](file:///f:/projects/cove-corsair/src/features/boarding/rigs/player/rig_sloop.tscn), [`rig_dinghy.tscn`](file:///f:/projects/cove-corsair/src/features/boarding/rigs/player/rig_dinghy.tscn), [`rig_bombard_skiff.tscn`](file:///f:/projects/cove-corsair/src/features/boarding/rigs/player/rig_bombard_skiff.tscn), [`rig_ironclad.tscn`](file:///f:/projects/cove-corsair/src/features/boarding/rigs/player/rig_ironclad.tscn)

```
PlayerBoardingRig (Node3D, script: player_boarding_rig.gd)
├── DeckFloor (StaticBody3D)
│   └── CollisionShape3D (BoxShape3D)
├── DeckZones (Node3D)
│   ├── ZoneBow (BoardingZone, Area3D)
│   │   ├── CollisionShape3D (BoxShape3D)
│   │   ├── GrappleAnchor (Marker3D)
│   │   └── StationMarker (Marker3D)
│   ├── ZoneMidship (BoardingZone, Area3D)
│   │   ├── CollisionShape3D (BoxShape3D)
│   │   ├── GrappleAnchor (Marker3D)
│   │   └── StationMarker (Marker3D)
│   └── ZoneStern (BoardingZone, Area3D)
│       ├── CollisionShape3D (BoxShape3D)
│       ├── GrappleAnchor (Marker3D)
│       └── StationMarker (Marker3D)
├── CrewStations (Node3D)
│   ├── CrewStationBow (BoardingCrewStation)
│   └── CrewStationStern (BoardingCrewStation)
├── PlayerSpawn (Marker3D)
├── CameraMount (Marker3D)
├── BreachLine (Marker3D)
└── Model (PackedScene instance of player ship .glb)
```

### Node Explanations:

| Node Name | Type | Purpose & Function |
| :--- | :--- | :--- |
| **`DeckFloor`** | `StaticBody3D` | Invisible solid collision box beneath the deck planks. Prevents the player, crew defenders, and enemy boarders from falling through the ship into the water. |
| **`DeckZones`** | `Node3D` | Container holding the 3 distinct defense sectors: `ZoneBow`, `ZoneMidship`, and `ZoneStern`. |
| ↳ **`ZoneBow`** | `BoardingZone` (`Area3D`) | Forward sector (Prow / Front). Tracks enemy infestation buildup when enemies stand on this part of the deck. |
| ↳ **`ZoneMidship`** | `BoardingZone` (`Area3D`) | Center sector (Main Deck). Usually where the player character stands and where middle planks land. |
| ↳ **`ZoneStern`** | `BoardingZone` (`Area3D`) | Rear sector (Aft / Stern). Closest to the `BreachLine`. |
| ↳ **`GrappleAnchor`** | `Marker3D` | Railing landing coordinate where incoming gangplanks / grapple ropes anchor onto the deck. |
| ↳ **`StationMarker`** | `Marker3D` | Center coordinate within the zone used by pathfinding enemies when moving through the sector. |
| **`CrewStations`** | `Node3D` | Container for automated crew defender placement. |
| ↳ **`CrewStationBow`** | `BoardingCrewStation` | Where the bow defender crew member stands. Assigned to defend `ZoneBow`. |
| ↳ **`CrewStationStern`** | `BoardingCrewStation` | Where the stern defender crew member stands. Assigned to defend `ZoneStern`. |
| **`PlayerSpawn`** | `Marker3D` | Starting position and deck anchor for the frontline pirate character controlled by the user. |
| **`CameraMount`** | `Marker3D` | Pre-calibrated 3D camera position and rotation tailored specifically for this ship's deck elevation and size. |
| **`BreachLine`** | `Marker3D` | **Fail condition tripwire** at the stern railing (`+Z`). If any boarder reaches or passes this Z position (`global_position.z >= breach_z`), the encounter immediately triggers defeat (**"STERN BREACHED! GAME OVER"**). |
| **`Model`** | `.glb` Scene | Visual 3D model of the player vessel. |

---

## 4. Enemy Vessel Rig Anatomy

**Script:** [`EnemyBoardingRig`](file:///f:/projects/cove-corsair/src/features/boarding/rigs/enemy_boarding_rig.gd)  
**Scenes:** [`rig_war_barge.tscn`](file:///f:/projects/cove-corsair/src/features/boarding/rigs/enemy/rig_war_barge.tscn), [`rig_bone_beard.tscn`](file:///f:/projects/cove-corsair/src/features/boarding/rigs/enemy/rig_bone_beard.tscn), [`rig_siege_fortress.tscn`](file:///f:/projects/cove-corsair/src/features/boarding/rigs/enemy/rig_siege_fortress.tscn), [`rig_phantom_dredge.tscn`](file:///f:/projects/cove-corsair/src/features/boarding/rigs/enemy/rig_phantom_dredge.tscn)

```
EnemyBoardingRig (Node3D, script: enemy_boarding_rig.gd)
├── PlankOrigins (Node3D)
│   ├── MarkerBow (Marker3D)
│   ├── MarkerMid (Marker3D)
│   └── MarkerStern (Marker3D)
├── EnemyBoatWake (GPUParticles3D)
└── Model (PackedScene instance of boss ship .glb)
```

### Node Explanations:

| Node Name | Type | Purpose & Function |
| :--- | :--- | :--- |
| **`EnemyBoardingRig`** | `Node3D` | Root node holding exported references to the plank origin markers, wake emitter, and the `dock_position` property. |
| **`dock_position`** | `Vector3` property | The exact world coordinate where this specific boss ship comes to a halt after completing its lateral approach animation. |
| **`PlankOrigins`** | `Node3D` | Container holding launch points for the boarding gangplanks. |
| ↳ **`MarkerBow`** | `Marker3D` | Origin point on the boss ship's gunwale where Plank 0 (Bow) extends from. |
| ↳ **`MarkerMid`** | `Marker3D` | Origin point on the boss ship's gunwale where Plank 1 (Midship) extends from. |
| ↳ **`MarkerStern`** | `Marker3D` | Origin point on the boss ship's gunwale where Plank 2 (Stern) extends from. |
| **`EnemyBoatWake`** | `GPUParticles3D` | Water spray and foam emitted beneath the hull during the ship's approach sequence. Automatically stops emitting once docked. |
| **`Model`** | `.glb` Scene | Visual 3D model of the boss vessel, oriented toward the player ship (either side-by-side or head-on for unique vessels like Captain Bone-Beard). |

---

## 5. Spatial Coordinate Conventions

In the boarding arena, the coordinate system is oriented as follows:

* **Z Axis (Ship Length):**
  * **Negative Z (`-Z`)**: Forward towards the **Bow (Front)**.
  * **Positive Z (`+Z`)**: Backward towards the **Stern (Rear)**.
  * **`BreachLine`** is placed at the highest `+Z` deck position (at the rear railing).
* **X Axis (Ship Width / Gap between ships):**
  * **Negative X (`-X`)**: Port side of the player's ship (where the camera looks from).
  * **Center (`X ≈ 0.0`)**: Centerline of the player's deck.
  * **Positive X (`+X`)**: Starboard side where planks attach, extending toward the enemy ship docked at `X ≈ 13.0` to `15.0`.
* **Y Axis (Deck Height):**
  * **`Y = 0.0`**: Waterline level.
  * **`Y ≈ 0.2` to `0.8`**: Player deck level.

---

## 6. How To Author or Tune a New Rig

### When Creating a New Player Rig:
1. Instance your ship's `.glb` model as `Model`.
2. Adjust `DeckFloor`'s collision box to span the walk-able surface of the deck.
3. Position `ZoneBow`, `ZoneMidship`, and `ZoneStern` along the deck from `-Z` to `+Z`.
4. Position each zone's `GrappleAnchor` right along the edge of the starboard railing facing `+X`.
5. Place `CrewStationBow` in the forward area and `CrewStationStern` in the aft area.
6. Set `BreachLine` at the rear stern railing (`+Z`), leaving 1.5 to 2.0 units of buffer room behind `ZoneStern`.
7. Position `CameraMount` overlooking the deck from the port side (`-X`) slightly elevated (`+Y`).

### When Creating a New Enemy Rig:
1. Instance the boss ship's `.glb` model as `Model`.
2. Orient the model (most ships dock port-to-starboard facing parallel; unique ships can face perpendicular).
3. Place `MarkerBow`, `MarkerMid`, and `MarkerStern` along the railing facing `-X` towards the player's ship.
4. Position `EnemyBoatWake` at the waterline beneath the hull.
5. Calibrate `dock_position` in the inspector so the gap between vessels matches standard plank lengths (approx. 10 to 14 units on X).
