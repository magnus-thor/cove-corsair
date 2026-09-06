# Cove Corsair - Deck Crew & Naval Weapon Mounts Architecture

This document provides a technical reference for all **Deck Crew Members** and **Naval Weapon Mounts** in **Cove Corsair**.

---

## 🐒 1. Autonomous Deck Crew Members (`CrewData`)

Deck Crew members are autonomous units mounted on player flagship hardpoints. Defined via [`src/data/crew_data.gd`](file:///f:/projects/cove-corsair/src/data/crew_data.gd) (which inherits from [`WeaponData`](file:///f:/projects/cove-corsair/src/data/weapon_data.gd)), crew members scan for hostile targets, calculate parabolic projectile trajectories, and throw specialized ordnance.

### Crew Roster & Stats Table

| Crew Member | Resource Path | Role (`crew_role`) | Fire Rate (Cooldown) | Detection Range | Targeting Priority | Primary Ammo | Compatible Ammo |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Monkey Bomber** | [`crew_monkey_bomber.tres`](file:///f:/projects/cove-corsair/src/data/resources/user_crew/crew_monkey_bomber.tres) | `bomber` | $0.20\text{s}$ | $20.0\text{m}$ | `nearest` | Coconut Bomb | Coconut Bomb, Fire Bomb |
| **Skeleton Tosser** | [`crew_skeleton_tosser.tres`](file:///f:/projects/cove-corsair/src/data/resources/user_crew/crew_skeleton_tosser.tres) | `tosser` | $0.20\text{s}$ | $20.0\text{m}$ | `nearest` | Throwing Axe | Throwing Axe, Coconut Bomb |
| **Deckhand Sniper** | [`weapon_deckhand_sniper.tres`](file:///f:/projects/cove-corsair/src/data/resources/user_crew/weapon_deckhand_sniper.tres) | `sniper` | $0.35\text{s}$ | $32.0\text{m}$ | `highest_threat` | Heavy Shot | Standard Ball, Heavy Shot |

---

## 🎯 2. Crew Targeting & Throw Arc Mechanics

1. **Target Acquisition:** Each frame, active crew members scan all entities in the `enemies` and `destructible` groups within `detection_range`.
2. **Priority Filters:**
   * `nearest`: Locks onto the closest active obstacle or enemy mob.
   * `highest_threat`: Prioritizes fast-moving mobs (Kamikaze Rafts) and mini-bosses.
   * `boss_focus`: Automatically locks onto active Boss components during boss encounters.
3. **Parabolic Throw Arc:**
   * Projects a parabolic 3D trajectory from the crew hardpoint position to target coordinates using `throw_arc_height` ($0.5\text{m}$).
   * Projectiles land with AoE splash damage when using explosive ordnance (Coconut/Fire Bombs).

---

## 💣 3. Naval Weapon Mounts (`WeaponData`)

Naval weapon mounts represent fixed vessel artillery installed on bow, side broadside, or aft hardpoint sockets ([`src/data/weapon_data.gd`](file:///f:/projects/cove-corsair/src/data/weapon_data.gd)).

### Weapon Mounts Table

| Weapon Mount | Resource Path | Weapon Type | Fire Rate (Cooldown) | Yaw Rotation | Default Ammo | Compatible Ammo |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Bow Chaser** | [`weapon_bow_chaser.tres`](file:///f:/projects/cove-corsair/src/data/resources/user_crew/weapon_bow_chaser.tres) | `cannon` | $0.20\text{s}$ | $0^\circ$ (Forward) | Standard Ball | Standard Ball, Heavy Shot |
| **Port Swivel Gun** | [`weapon_port_swivel.tres`](file:///f:/projects/cove-corsair/src/data/resources/user_crew/weapon_port_swivel.tres) | `swivel_gun` | $0.18\text{s}$ | $+99^\circ \text{ to } +112^\circ$ (Left) | Standard Ball | Standard Ball, Grape Shot |
| **Starboard Swivel Gun** | [`weapon_starboard_swivel.tres`](file:///f:/projects/cove-corsair/src/data/resources/user_crew/weapon_starboard_swivel.tres) | `swivel_gun` | $0.18\text{s}$ | $+80^\circ \text{ to } +94^\circ$ (Right) | Standard Ball | Standard Ball, Grape Shot |
| **Aft Mortar** | [`weapon_aft_mortar.tres`](file:///f:/projects/cove-corsair/src/data/resources/user_crew/weapon_aft_mortar.tres) | `deck_mortar` | $0.40\text{s}$ | $180^\circ$ (Rear) | Heavy Shot | Heavy Shot, Fire Bomb |

---

## 🛠 4. Flagship Hardpoint Socket Integration

Weapon and crew resources are assigned to flagship hardpoint dictionaries (`hardpoint_offsets`, `hardpoint_rotations`, `hardpoint_scales`) defined in [`ShipData`](file:///f:/projects/cove-corsair/src/data/ship_data.gd):

```gdscript
# Hardpoint assignment example from The Sloop (Tier 2 Upgrade)
tier_sockets = [
    ["BowMount"],
    ["BowMount", "MidDeckCrew", "AftDeckCrew"],
    ["BowMount", "MidDeckCrew", "AftDeckCrew", "PortSwivelMount", "StarboardSwivelMount"]
]
```
