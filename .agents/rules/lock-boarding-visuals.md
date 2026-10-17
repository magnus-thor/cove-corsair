### RULE: STRICT VISUAL NODE & BOARDING SCENE LOCK

All visual scenes, node transforms, markers, cameras, and rigs under the boarding system are AUTHORITATIVE and USER-MANAGED in the Godot Editor. The agent must NEVER edit, rewrite, or overwrite these files or their spatial transforms.

1. Protected Scene Files (DO NOT MODIFY TRANSFORMS, NODES, OR SCENE STRUCTURE):
   - `src/features/boarding/boarding_defense_arena.tscn`
   - `src/features/boarding/rigs/player/*` (e.g. `rig_sloop.tscn`, `rig_dinghy.tscn`, `rig_bombard_skiff.tscn`, `rig_ironclad.tscn`)
   - `src/features/boarding/rigs/enemy/*` (e.g. `rig_war_barge.tscn`, `rig_bone_beard.tscn`, `rig_siege_fortress.tscn`, `rig_phantom_dredge.tscn`)
   - `src/features/boarding/player/deck_player_controller.tscn`
   - `src/features/boarding/crew/boarding_crew_station.tscn`

2. Prohibited Agent Actions:
   - NEVER modify positions, rotations, scales, or node hierarchies in these `.tscn` files.
   - NEVER add code in scripts (`@tool` or runtime) that overwrites, resets, or saves over user-authored transforms on disk.
   - NEVER touch these scenes when working on level design, river chunks, enemy balance, GameState, or UI.

3. Role of the Agent:
   - All visual placement, docking alignment, plank anchors, crew sizing, and camera framing are calibrated manually by the user in the Godot 3D Editor.
   - The agent is only permitted to touch pure gameplay logic (signals, damage, health, wave counts) and must treat all `.tscn` spatial layouts as read-only black boxes.
