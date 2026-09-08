# Cove Corsair - Lane Objects, Hazards & Gates Architecture

This document provides a technical specification for all **Lane Objects**, **Destructible Obstacles**, **Environmental Hazards**, **Multiplier Gates**, and **Collectibles** in **Cove Corsair**.

---

## 🛢️ 1. Destructible Obstacles

Destructible obstacles drift down-river along channel lanes. Controlled via [`destructible_obstacle.gd`](file:///f:/projects/cove-corsair/src/gameplay/obstacles/destructible_obstacle.gd) and specialized obstacle scripts, entities adhere to the [Tiered Color Rarity Framework](file:///f:/projects/cove-corsair/documents/Ahoy%21%20Pirate%20Arcade%20Runner_%20Master%20Game%20Design%20&%20Strategic%20Roadmap.md#3-tiered-color-rarity-system):

| Obstacle Type | HP Profile | Rarity Tier | Reward Drops | Behavior & Destruction Effect |
| :--- | :--- | :--- | :--- | :--- |
| **Wooden Barrel** | $1\text{-}2\text{ HP}$ | Common (White) | $+10\text{ Gold}, +15\text{ XP}$ | Standard target barrel; shatters on impact or destruction with wood splinter VFX. |
| **Fuse Barrel** | $3\text{-}4\text{ HP}$ | Normal (Green) | $+15\text{ Gold}, +20\text{ XP}$ | Red explosive barrel; detonates on destruction to clear adjacent lane obstacles. |
| **Rune Barrel** | $4\text{-}10\text{ HP}$ | Rare (Blue) | $+25\text{ Gold}, +35\text{ XP}$ | Reinforced obstacle requiring concentrated cannon volleys. |
| **Armored Barrel Chest** | $2\text{-}6\text{ HP}$ | Elite (Purple) | Drops 3D Treasure Chest | Armored barrel tagged with `spawns_chest = true`; spawns a 3D collectible chest upon destruction. |
| **Barricade Wall** | Dynamic Tier HP ($2\text{--}20\text{ HP}$) | Normal (Green) | $+5\text{ Gold}$ per segment | 5-segment interlocking wooden barrier spanning the river channel ($12\text{m}$). Deals $3\text{ damage}$ on direct collision. |

---

### Dynamic Barricade Slat HP Formula

Barricade slat durability scales dynamically via [`BarricadeWall.get_tier_hp(level)`](file:///f:/projects/cove-corsair/src/gameplay/obstacles/barricade_wall.gd):

$$\text{Slat HP} = \begin{cases} 2\text{ HP} & \text{Levels } 1\text{ to } 3 \text{ (Starter Dinghy breaks a slat in 2 direct cannon shots)} \\ 6\text{ HP} & \text{Levels } 4\text{ to } 10 \text{ (Demands sustained fire or upgraded vessel volleys)} \\ 12\text{ HP} & \text{Levels } 11\text{ to } 25 \text{ (Mid-campaign fortified barrier)} \\ 20\text{ HP} & \text{Levels } 26+ \text{ (Late-game fortified siege walls)} \end{cases}$$

---

## 🚪 2. Multiplier Gates

Floating translucent arches ([`multiplier_gate.gd`](file:///f:/projects/cove-corsair/src/gameplay/obstacles/multiplier_gate.gd)) drift along channel lanes to amplify firepower or expand follower fleets:

| Gate Type | Sub-Type | Visual Color | Gate Effect |
| :--- | :--- | :--- | :--- |
| **Cannonball Add** | `CANNONBALL_ADD` | Glowing Blue | Adds $+2, +3, \text{ or } +5$ parallel cannonballs to volleys passing through. |
| **Cannonball Mult** | `CANNONBALL_MULT` | Fire Orange | Multiplies passing projectile volleys by $\times 2 \text{ or } \times 3$. |
| **Fleet Summon Gate** | `FLEET_SUMMON` | Translucent Cyan | Summons $+1, +2, \text{ or } +4$ follower skiffs when the player vessel passes through. |

---

## ⚠️ 3. Environmental Hazards

Hazards test lateral swerving precision and introduce biome-specific mechanics ([`src/gameplay/obstacles/`](file:///f:/projects/cove-corsair/src/gameplay/obstacles/)):

| Hazard Name | Biome | Durability | Hazard Effect & Mechanics |
| :--- | :--- | :--- | :--- |
| **Reef Outcrop** | Tropical | Indestructible | Environmental rock barrier occupying channel center ($X = 0.0, scale_x = 1.5, scale_z = 3.75$). Forces immediate swerving. |
| **Spiked Sea Mine** | Tropical / Bayou | $1\text{ HP}$ | Floating mine detonating instantly on contact with player hull or follower skiffs ($1\text{ damage}$). Spawns fiery explosion VFX. |
| **Biogas Pod** | Bayou | $2\text{ HP}$ | Toxic swamp pod; detonates upon destruction into a lingering poison cloud ($3.0\text{m}$ radius). |
| **Thermal Geyser** | Brimstone | Indestructible | Erupts periodically with red floor telegraphing, launching vertical lava plumes dealing instant hull damage. |

---

## 🪙 4. Collectibles & 3D Treasure Pickups

### Doubloons
* **Scene:** [`collectible_doubloon.tscn`](file:///f:/projects/cove-corsair/src/gameplay/collectibles/collectible_doubloon.tscn)
* **Mechanics:** Floating gold coins arranged in racing arcs along channel lanes.
* **Magnetic Attraction:** Player vessel attracts coins from adjacent lanes based on magnetic figurehead stats.

### 3D Treasure Chests
* **Scene:** [`collectible_chest.tscn`](file:///f:/projects/cove-corsair/src/gameplay/collectibles/collectible_chest.tscn) & [`chest_pickup.tscn`](file:///f:/projects/cove-corsair/src/gameplay/collectibles/chest_pickup.tscn)
* **3D Asset:** Kenney pirate treasure chest model (`res://assets/models/chest.glb`).
* **Value Profile:** Carries high-yield doubloon rewards ($25$, $50$, $75$, or $100\text{ Doubloons}$).
* **Collection VFX:** Triggers [`vfx_coin_burst.tscn`](file:///f:/projects/cove-corsair/src/vfx/vfx_coin_burst.tscn) golden particle fountain and synchronized coin collection SFX.
* **Hazard Pocket Spawners:** Placed via [`chest_spawn_marker.gd`](file:///f:/projects/cove-corsair/src/gameplay/chunks/chest_spawn_marker.gd) in high-risk track pockets behind mine clusters or barricade flanks, incentivizing daring maneuvers in Levels 6+.
