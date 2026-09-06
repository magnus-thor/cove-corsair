# Modular Environment Asset Slots

This directory is the designated home for modular low-poly environment meshes used
by the riverbank chunk scatter system (`riverbank_props.gd`).

## Asset Slots & Current Fallbacks

| Slot name (future) | Current fallback (res://assets/models/) | Role |
|---|---|---|
| `bank_segment.glb` | `structure-platform-dock.glb` | Continuous dock-plank shore-edge spine tile |
| `prop_rock_cluster.glb` | `rocks-a.glb`, `rocks-b.glb`, `rocks-c.glb` | Outer cliff / boulder mass |
| `prop_palms.glb` | `palm-detailed-straight.glb`, `palm-detailed-bend.glb` | Tropical foliage on shoal platforms |
| `prop_dock_ruins.glb` | `structure-platform-dock-small.glb`, `structure.glb` | Ruined dock/structure accent props |

## Drop-in Swap Instructions

When low-poly art-pass assets are ready, place each `.glb` in this directory and update
the `BANK_SEGMENT_PATH`, `PROP_ROCK_CLUSTER_PATHS`, `PROP_PALMS_PATHS`, and
`PROP_DOCK_RUINS_PATHS` constants at the top of:

- `res://src/gameplay/levels/riverbank_props.gd`

No other code changes are required.

## Material Requirements

All meshes in this directory must be compatible with:
- `StandardMaterial3D` override (cull_mode = CULL_BACK, roughness = 1.0, metallic_specular = 0.0)
- No normal maps required (mobile-optimised low-poly)
- Shadow casting disabled at runtime (SHADOW_CASTING_SETTING_OFF)
