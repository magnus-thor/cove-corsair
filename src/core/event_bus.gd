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
signal level_started(level_index: int)

## Fired when the player clears the distance target / reaches the boss gate.
signal level_completed(doubloons: int, targets: int)

## Fired when the full campaign is beaten.
signal campaign_completed(total_doubloons: int, total_targets: int)

## Fired when the player's ship sinks (i.e. 0 HP and no more i-frames).
signal player_sunk()

## Fired when a run ends in failure (timed out, leaked too many mobs, etc.).
signal run_failed(coins_collected: int, distance_reached: float)

## ── Boss Lifecycle ───────────────────────────────────────────────────────────

## Fired when a boss enters the arena. HUD subscribes to show boss HP bar.
signal boss_spawned_event(boss_name: String, max_val: int)

## Fired each time the active boss takes damage. HUD subscribes to update bar.
signal boss_health_changed(current: int, max_val: int)

## ── Progress ────────────────────────────────────────────────────────────────

## Fired when the player's run distance hits the configured level target.
signal distance_target_reached()

## ── Camera ──────────────────────────────────────────────────────────────────

## Request a trauma-based camera shake without any direct camera reference.
## Subscribers (game_camera.gd) call add_trauma(amount).
signal screen_shake_requested(trauma: float)
