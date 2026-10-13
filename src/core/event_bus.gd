extends Node

## EventBus — Lean cross-boundary signal broker (ARCHITECTURE.md Blueprint 4).
##
## Reserved strictly for events that cross scene-tree ownership boundaries.
## Signals here describe PAST events (past-tense naming, Rule B).
## Components within the same hierarchy communicate via direct child calls or
## parent-facing signals — only use EventBus for truly global broadcasts.
##
## Signals intentionally NOT here: doubloons_changed, multiplier_changed,
## progress_changed, fire_frenzy_triggered — these are tightly coupled to
## GameState economy data and read in the same frame; they stay in GameState.

## ── Level Lifecycle ─────────────────────────────────────────────────────────

## Fired by the level controller when a gauntlet run begins.
@warning_ignore("unused_signal")
signal level_started(level_index: int)

## Fired when the player clears the distance target / reaches the boss gate.
@warning_ignore("unused_signal")
signal level_completed(doubloons: int, targets: int)

## Fired when the full campaign is beaten.
@warning_ignore("unused_signal")
signal campaign_completed(total_doubloons: int, total_targets: int)

## Fired when the player's ship sinks (i.e. 0 HP and no more i-frames).
@warning_ignore("unused_signal")
signal player_sunk()

## Fired when a run ends in failure (timed out, leaked too many mobs, etc.).
@warning_ignore("unused_signal")
signal run_failed(coins_collected: int, distance_reached: float)

## Fired on initial player steer/swerve input during run.
@warning_ignore("unused_signal")
signal player_swerved()

## ── Boss Lifecycle ───────────────────────────────────────────────────────────

## Fired when a boss enters the arena. HUD subscribes to show boss HP bar.
@warning_ignore("unused_signal")
signal boss_spawned_event(boss_name: String, max_val: int)

## Fired each time the active boss takes damage. HUD subscribes to update bar.
@warning_ignore("unused_signal")
signal boss_health_changed(current: int, max_val: int)

## ── Progress ────────────────────────────────────────────────────────────────

## Fired when the player's run distance hits the configured level target.
@warning_ignore("unused_signal")
signal distance_target_reached()

## ── Camera ──────────────────────────────────────────────────────────────────

## Request a trauma-based camera shake without any direct camera reference.
## Subscribers (game_camera.gd) call add_trauma(amount).
@warning_ignore("unused_signal")
signal screen_shake_requested(trauma: float)

## ── Endless / Extraction Mode ──────────────────────────────────────────────

## Fired when a doubloon or gold award is collected in the river.
@warning_ignore("unused_signal")
signal gold_collected(amount: int)

## Fired when the player successfully banks unbanked plunder and extracts safely.
@warning_ignore("unused_signal")
signal run_extracted(score: int, doubloons: int)

## Fired when the player chooses Corsair's Gamble at a wager fork to increase stakes.
@warning_ignore("unused_signal")
signal wager_pushed(new_multiplier: float, new_speed: float)

## ── Telemetry & Playtest Balancing ──────────────────────────────────────────

## Fired when the player takes damage, with source name and river distance.
@warning_ignore("unused_signal")
signal player_hit_taken(amount: int, current_hp: int, max_hp: int, source_info: String, distance: float)

## Fired when doubloons are awarded, specifying the source (e.g. "coin", "chest", "barrel", "gate_multiplier", "level_bonus").
@warning_ignore("unused_signal")
signal doubloon_awarded(amount: int, source: String, total_run: int)

## Fired when an enemy mob escapes past the bottom of the river screen.
@warning_ignore("unused_signal")
signal mob_escaped(mob_name: String, total_leaked: int)

## Fired when player attempts or views an item in shipyard/upgrade UI.
@warning_ignore("unused_signal")
signal shipyard_item_action(item_id: String, item_type: String, cost: int, player_vault: int, success: bool, reason: String)

## ── Engagement Density & Difficulty Logging ─────────────────────────────────

## Fired when an enemy mob is killed by the player.
## mob_type: the name/type string of the mob (e.g. "GraveSkiff", "IronGunner").
## mob_max_hp: HP the mob had at spawn — helps gauge how "hard" it was.
## dist_to_player: Z-distance between mob and player at time of death (how far the shot reached).
## river_distance: how far along the level the kill happened.
@warning_ignore("unused_signal")
signal mob_killed(mob_type: String, mob_max_hp: int, dist_to_player: float, river_distance: float)

## Fired when a modular track chunk enters the camera range and activates its spawners.
## chunk_id: the chunk's scene/node name identifier.
## river_distance: level distance at which the chunk activated.
@warning_ignore("unused_signal")
signal chunk_activated(chunk_id: String, river_distance: float)

## Fired when a destructible obstacle (barrel, barricade, gate) is destroyed by the player.
## obstacle_type: human-readable label ("wooden_barrel", "barricade", "sea_mine", "gate", etc.).
## shots_taken: how many hits it absorbed before dying — proxy for engagement duration.
## river_distance: level distance at time of destruction.
@warning_ignore("unused_signal")
signal obstacle_destroyed_telemetry(obstacle_type: String, shots_taken: int, river_distance: float)

## Fired when a player projectile hits its max_range limit and splashes out harmlessly.
## weapon_id: weapon/ammo identifier string.
## max_range_m: the configured max_range in metres.
## river_distance: level distance when the shot expired.
@warning_ignore("unused_signal")
signal shot_expired_at_distance(weapon_id: String, max_range_m: float, river_distance: float)

## ── Boarding Defense Telemetry ──────────────────────────────────────────────

## Fired when a boarding defense sequence is initiated.
@warning_ignore("unused_signal")
signal boarding_encounter_started(boss_name: String, tier: int, total_waves: int, player_vessel: String, crew_role: String)

## Fired when a boarding defense sequence completes in victory or defeat.
@warning_ignore("unused_signal")
signal boarding_encounter_ended(boss_name: String, outcome: String, duration_sec: float, waves_cleared: int, total_waves: int, mobs_killed: int, mobs_spawned: int, hull_damage_taken: float, end_reason: String)

