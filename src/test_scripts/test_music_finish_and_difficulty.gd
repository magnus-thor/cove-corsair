extends Node

## Regression test for music ducking, finish line sail-through, boarding plank drop,
## boss defeat position, and Sloop Tier 4 difficulty balancing.

var _fails: int = 0

func _check(condition: bool, label: String) -> void:
	if condition:
		print("  [PASS] %s" % label)
	else:
		_fails += 1
		push_error("  [FAIL] %s" % label)
		print("  [FAIL] %s" % label)

func _ready() -> void:
	print("==================================================")
	print("  TESTING MUSIC, FINISH LINE, AND SLOOP T4 BALANCE")
	print("==================================================")

	# ── 1. Music Volume & Ducking ──────────────────────────────────────────
	print("\n--- 1. Audio Default Volume & Voiceover Ducking ---")
	print("  GameState.music_volume = %f" % GameState.music_volume)
	_check(is_equal_approx(GameState.music_volume, 0.55), "Default GameState.music_volume is 0.55 (-5.2 dB)")
	var bgm_idx: int = AudioServer.get_bus_index("BGM")
	_check(bgm_idx != -1, "BGM audio bus exists")
	var initial_db: float = AudioServer.get_bus_volume_db(bgm_idx)
	print("  initial BGM db = %f" % initial_db)
	AudioManager.duck_music(true, 0.05)
	await get_tree().create_timer(0.2).timeout
	var ducked_db: float = AudioServer.get_bus_volume_db(bgm_idx)
	print("  ducked BGM db = %f" % ducked_db)
	_check(ducked_db < initial_db - 4.0, "duck_music(true) ducks BGM bus volume by > 4 dB")
	AudioManager.duck_music(false, 0.05)
	await get_tree().create_timer(0.2).timeout
	var restored_db: float = AudioServer.get_bus_volume_db(bgm_idx)
	print("  restored BGM db = %f" % restored_db)
	_check(is_equal_approx(restored_db, initial_db), "duck_music(false) restores BGM bus volume")

	# ── 2. Finish Line Arch & Player Victory Sail ──────────────────────────
	print("\n--- 2. Finish Line Arch & Player Sail-Through ---")
	var finish_scene: PackedScene = load("res://src/gameplay/chunks/chunk_finish_line.tscn") as PackedScene
	var finish_chunk: ChunkFinishLine = finish_scene.instantiate() as ChunkFinishLine
	add_child(finish_chunk)
	await get_tree().process_frame

	var headlands: Node = finish_chunk.find_child("HeadlandsBehindArch", true, false)
	_check(headlands != null, "Headlands behind the arch are generated to prevent empty lane sides")
	_check(headlands != null and headlands.get_child_count() > 0, "Headland rocks and watchtowers populate the harbor channel")

	# Assembler & track manager instances
	var dummy_assembler: ChunkAssembler = ChunkAssembler.new()
	dummy_assembler.add_to_group("chunk_assembler")
	dummy_assembler.scroll_speed = 8.0
	add_child(dummy_assembler)

	var dummy_track: TrackManager = TrackManager.new()
	dummy_track.add_to_group("track_manager")
	dummy_track.scroll_speed = 8.0
	add_child(dummy_track)

	# Dummy player
	var dummy_player: Node3D = Node3D.new()
	dummy_player.add_to_group("player")
	dummy_player.position = Vector3(2.5, 0.0, 0.0)
	add_child(dummy_player)

	finish_chunk._trigger_victory()
	_check(dummy_assembler.get("scroll_speed") == 0.0, "Track scrolling freezes immediately on finish so arch stops sinking down")
	_check(dummy_track.get("scroll_speed") == 0.0, "TrackManager scrolling freezes immediately on finish")

	await get_tree().create_timer(0.4).timeout
	_check(dummy_player.position.z < -2.0, "Player vessel is tweened forward (up the screen) through the arch")
	_check(absf(dummy_player.position.x) < 2.5, "Player vessel centers towards the arch centerline")

	finish_chunk.queue_free()
	dummy_assembler.queue_free()
	dummy_track.queue_free()
	dummy_player.queue_free()
	await get_tree().process_frame

	# ── 3. Boarding Plank Drop Animation ───────────────────────────────────
	print("\n--- 3. Boarding Plank Drop Animation ---")
	var plank_scene: PackedScene = load("res://src/features/boarding/boarding_plank.tscn") as PackedScene
	var plank: BoardingPlank = plank_scene.instantiate() as BoardingPlank
	add_child(plank)
	var origin_p: Vector3 = Vector3(4.0, 1.2, 0.0)
	var target_p: Vector3 = Vector3(0.0, 0.8, 0.0)
	plank.drop_plank(origin_p, target_p, null)
	_check(plank.is_latched == false, "Plank starts unlatched while dropping from enemy vessel")

	await get_tree().create_timer(0.45).timeout
	_check(plank.is_latched == true, "Plank latches onto player deck upon completing drop animation")
	plank.queue_free()
	await get_tree().process_frame

	# ── 4. Sloop Tier 4 Economy & Stats ────────────────────────────────────
	print("\n--- 4. Sloop Tier 4 Economy & Stats ---")
	var sloop_data: ShipData = load("res://src/data/resources/user_vessels/sloop_ship.tres") as ShipData
	_check(sloop_data != null, "sloop_ship.tres loaded successfully")
	var t3_cost: int = sloop_data.upgrade_costs[2]
	var t4_cost: int = sloop_data.upgrade_costs[3]
	_check(t3_cost == 350, "Sloop Tier 3 upgrade cost is 350 doubloons")
	_check(t4_cost == 650, "Sloop Tier 4 upgrade cost is 650 doubloons")
	_check(t3_cost + t4_cost == 1000, "Total cost to reach Tier 4 is 1000 doubloons (~2 endless mode runs)")

	# Sloop Tier 4 stats on Player
	GameState.active_vessel = "sloop"
	var player_scene: PackedScene = load("res://src/gameplay/player/player_boat.tscn") as PackedScene
	var player: PlayerSwerve = player_scene.instantiate() as PlayerSwerve
	add_child(player)
	player.apply_tier(4)
	_check(player.max_health == 6, "Sloop Tier 4 max HP is 6 (reinforced hull to survive Level 6-7)")
	_check(player.tier_fire_rate_multiplier >= 1.25, "Sloop Tier 4 fire rate multiplier is boosted to >= 1.25x")
	player.queue_free()
	await get_tree().process_frame

	# ── 5. Level 6 & 7 Difficulty Jump ─────────────────────────────────────
	print("\n--- 5. Level 6 & 7 Difficulty Jump ---")
	var l6: LevelData = load("res://src/data/resources/levels/level_06.tres") as LevelData
	var l7: LevelData = load("res://src/data/resources/levels/level_07.tres") as LevelData
	_check(l6.base_scroll_speed >= 8.4, "Level 6 base scroll speed is >= 8.4 m/s (difficulty jump from L5's 7.5)")
	_check(l7.base_scroll_speed >= 8.8, "Level 7 base scroll speed is >= 8.8 m/s (rapid hazard pacing)")

	# Mob HP multiplier at level 6+
	GameState.current_level = 6
	var mob_scene: PackedScene = load("res://src/gameplay/enemies/enemy_mob.tscn") as PackedScene
	var mob: EnemyMob = mob_scene.instantiate() as EnemyMob
	add_child(mob)
	await get_tree().process_frame
	_check(mob.max_hp >= 5, "Enemy mob HP on Level 6 is scaled up (got %d HP)" % mob.max_hp)
	mob.queue_free()
	await get_tree().process_frame

	# ── 6. Economy, 2X Bonus, and Skull Outpost Sinking Gate ───────────────
	print("\n--- 6. Economy, 2X Bonus, and Skull Outpost Sinking Gate ---")
	GameState.reset_tutorial()
	_check(GameState.has_used_free_double == false, "Fresh game has_used_free_double starts false")
	_check(GameState.first_loss_occurred == false, "Fresh game first_loss_occurred starts false")

	var hub_scene: PackedScene = load("res://scenes/cove_hub/cove_main_hub.tscn") as PackedScene
	var hub: CoveMainHub = hub_scene.instantiate() as CoveMainHub
	add_child(hub)
	await get_tree().process_frame

	# Level 5 beaten with 0 losses
	GameState.highest_unlocked_level = 6
	_check(hub.is_feature_unlocked("skull_outpost") == false, "Skull Outpost is NOT unlocked after beating Level 5 if player has not lost a vessel")

	# Sinking on Level 6 triggers first loss
	EventBus.player_sunk.emit()
	_check(GameState.first_loss_occurred == true, "EventBus.player_sunk sets GameState.first_loss_occurred = true")
	_check(hub.is_feature_unlocked("skull_outpost") == true, "Skull Outpost is unlocked once first loss occurs at Level 5+")
	hub.queue_free()
	await get_tree().process_frame

	# Endless Mode configuration
	var endless: EndlessMode = EndlessMode.new()
	_check(endless.wager_interval_meters == 350.0, "Endless mode first wager checkpoint interval is 350m (was 1000m)")
	endless.queue_free()

	# Cleanup save if created during test
	if FileAccess.file_exists(GameState.SAVE_PATH):
		DirAccess.remove_absolute(GameState.SAVE_PATH)

	print("\n==================================================")
	if _fails == 0:
		print("ALL MUSIC, FINISH LINE, AND DIFFICULTY TESTS PASSED! ✓")
		get_tree().quit(0)
	else:
		print("FAILED: %d tests failed." % _fails)
		get_tree().quit(1)
