# Cove Corsair - Lane Objects, Hazards & Gates Architecture

This document provides a technical specification for all **Lane Objects**, **Destructible Obstacles**, **Environmental Hazards**, **Multiplier Gates**, and **Collectibles** in **Cove Corsair**.

---

## 🛢️ 1. Destructible Obstacles

Destructible obstacles drift down-river along channel lanes. Controlled via [`destructible_obstacle.gd`](file:///f:/projects/cove-corsair/src/gameplay/obstacles/destructible_obstacle.gd), obstacles adhere to the [Tiered Color Rarity Framework](file:///f:/projects/cove-corsair/documents/Ahoy%21%20Pirate%20Arcade%20Runner_%20Master%20Game%20Design%20&%20Strategic%20Roadmap.md#3-tiered-color-rarity-system):

| Obstacle Type | HP Profile | Rarity Tier | Reward Drops | Behavior & Destruction Effect |
| :--- | :--- | :--- | :--- | :--- |
| **Wooden Barrel** | $1\text{-}2\text{ HP}$ | Common (White) | $+10\text{ Gold}, +15\text{ XP}$ | Standard target barrel; shatters on impact or destruction. |
| **Fuse Barrel** | $3\text{-}4\text{ HP}$ | Normal (Green) | $+15\text{ Gold}, +20\text{ XP}$ | Red explosive barrel; detonates on destruction to clear adjacent lane obstacles. |
| **Rune Barrel** | $4\text{-}10\text{ HP}$ | Rare (Blue) | $+25\text{ Gold}, +35\text{ XP}$ | Reinforced obstacle requiring concentrated cannon volleys. |
| **Armored Barrel Chest** | $6\text{ HP}$ | Elite (Purple) | $+50\text{ Gold}, +50\text{ XP}$ | Heavy chest obstacle dropping golden reward doubloons upon destruction. |
| **Barricade Wall** | $2\text{ HP}$ per segment | Normal (Green) | $+5\text{ Gold}$ per segment | 5-segment interlocking wooden wall spanning the river ($12\text{m}$). Must shoot 1 segment to break through. |

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
| **Reef Outcrop** | Level 1 | Indestructible | Environmental rock barrier occupying channel center ($X = 0.0, scale_x = 1.5, scale_z = 3.75$). Forces immediate swerving. |
| **Spiked Sea Mine** | Level 1 | $1\text{ HP}$ | Floating mine detonating instantly on contact with player hull or follower skiffs, dealing $1\text{ Hull Damage}$. |
| **Biogas Pod** | Level 2 | $2\text{ HP}$ | Toxic swamp pod; detonates upon destruction into a lingering poison cloud ($3.0\text{m}$ radius). |
| **Thermal Geyser** | Level 3 | Indestructible | Erupts periodically with red floor telegraphing, launching vertical lava plumes dealing instant hull damage. |

### 🖼️ Environmental Hazards Concept Art (Transparent PNG Sprites)

````carousel
![Biogas Pod Hazard](file:///C:/Users/Magnus/.gemini/antigravity-ide/brain/a15dc124-9380-4e4f-82f3-a23d3405db55/hazard_biogas_pod.png)
<!-- slide -->
![Thermal Geyser Hazard](file:///C:/Users/Magnus/.gemini/antigravity-ide/brain/a15dc124-9380-4e4f-82f3-a23d3405db55/hazard_thermal_geyser.png)
````


---


## 🪙 4. Collectibles

* **Doubloons:** ([`collectible_doubloon.tscn`](file:///f:/projects/cove-corsair/src/gameplay/collectibles/collectible_doubloon.tscn)) Floating gold coins arranged in smooth racing arcs along lanes.
* **Magnetic Figurehead Attraction:** Upgrading the Magnetic Figurehead node increases coin attraction radius, pulling doubloons into the player vessel automatically from adjacent lanes.
