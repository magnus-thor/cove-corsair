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
