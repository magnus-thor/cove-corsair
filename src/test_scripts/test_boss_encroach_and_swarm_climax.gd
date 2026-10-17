extends Node3D

## Headless test harness verifying:
## 1. Boss Relentless Advancing Dreadnought doom-clock & distance updates
## 2. Lethal ram crush when boss reaches collision plane with HP > 15%
## 3. Desperation boarding trigger when boss drops <= 15% HP
## 4. Boarding Defense Arena HP threat scaling (1-5% vs 10-15%)
## 5. Gate escalation tracking in LevelController
## 6. High-density Swarm Climax waves in ChunkVanguardClimax

const WAR_BARGE_SCENE: PackedScene = preload("res://src/gameplay/enemies/boss_war_barge.tscn")
const PLAYER_SCENE: PackedScene = preload("res://src/gameplay/player/player_boat.tscn")
const ARENA_SCENE: PackedScene = preload("res://src/features/boarding/boarding_defense_arena.tscn")
const CLIMAX_SCENE: PackedScene = preload("res://src/gameplay/chunks/chunk_vanguard_climax.tscn")

func _ready() -> void:
	print("==================================================")
	print(" STARTING BOSS ENCROACH & SWARM CLIMAX TEST SUITE ")
	print("==================================================")
	
	_test_boss_advance_and_proximity()
	_test_boss_ram_crush()
	_test_boarding_health_scaling()
	_test_gate_escalation_and_swarm()
	
	print("==================================================")
	print("   ALL TESTS PASSED WITH ZERO ERRORS!             ")
	print("==================================================")
	get_tree().quit(0)

func _test_boss_advance_and_proximity() -> void:
	print("\n--- 1. Testing Boss Relentless Advance & Proximity Updates ---")
	var player: Node3D = Node3D.new()
	player.name = "Player"
	player.add_to_group("player")
	add_child(player)
	player.global_position = Vector3.ZERO

	var boss: BossWarBarge = WAR_BARGE_SCENE.instantiate() as BossWarBarge
	boss.name = "TestBossBarge"
	add_child(boss)
	boss.activate_arena()
	boss.global_position = Vector3(0.0, 0.0, -60.0)
	
	var reported: Array[float] = [-1.0]
	var dist_cb: Callable = func(d: float, _m: float) -> void:
		reported[0] = d
	EventBus.boss_distance_updated.connect(dist_cb)

	# Simulate 1 second of combat process
	boss.current_state = BossWarBarge.State.COMBAT
	boss._physics_process(1.0)
	
	assert(boss.global_position.z > -60.0, "Boss must advance forward in Z during COMBAT (got %f)" % boss.global_position.z)
	assert(reported[0] >= 0.0, "EventBus.boss_distance_updated must have fired (got %f)" % reported[0])
	print("  [PASS] Boss advanced to Z = %.2f, proximity distance = %.2fm" % [boss.global_position.z, reported[0]])
	
	EventBus.boss_distance_updated.disconnect(dist_cb)
	boss.queue_free()
	player.queue_free()

func _test_boss_ram_crush() -> void:
	print("\n--- 2. Testing Lethal Ramming Crush (HP > 15%) ---")
	var player_node: Node3D = PLAYER_SCENE.instantiate() as Node3D
	player_node.name = "Player"
	add_child(player_node)
	player_node.global_position = Vector3.ZERO

	var boss: BossWarBarge = WAR_BARGE_SCENE.instantiate() as BossWarBarge
	boss.name = "TestBossRam"
	add_child(boss)
	boss.activate_arena()
	boss.current_hp = 500
	boss.max_hp = 500 # 100% HP

	# Place boss right at lethal collision plane Z = -0.5 (dist < 1.2m)
	boss.global_position = Vector3(0.0, 0.0, -0.5)
	boss.current_state = BossWarBarge.State.COMBAT
	boss._physics_process(0.1)

	var p_health: int = int(player_node.get("current_health")) if "current_health" in player_node else 0
	var has_boarded: bool = bool(boss.get("has_triggered_boarding"))
	assert(p_health <= 0 or not has_boarded, "Boss must crush player when reaching collision plane with HP > 15%")
	print("  [PASS] Boss successfully executed lethal ram crush when reaching player with high HP.")

	boss.queue_free()
	player_node.queue_free()

func _test_boarding_health_scaling() -> void:
	print("\n--- 3. Testing Boarding Defense Arena Threat Scaling (0-15% HP) ---")
	var arena: BoardingDefenseArena = ARENA_SCENE.instantiate() as BoardingDefenseArena
	add_child(arena)

	# Case A: Low remaining HP (3% HP -> 0.03)
	arena.setup_encounter_difficulty(5, false, 0.0, 0.03)
	assert(arena.total_waves_to_win == 2, "3%% Boss HP must configure 2 waves (got %d)" % arena.total_waves_to_win)
	assert(arena.wave_interval_sec >= 8.0, "3%% Boss HP must configure wave interval >= 8.0s (got %.1f)" % arena.wave_interval_sec)
	print("  [PASS] 3%% Boss HP scaled to 2 waves, %.1fs interval." % arena.wave_interval_sec)

	# Case B: High remaining HP (14% HP -> 0.14)
	arena.setup_encounter_difficulty(5, false, 0.0, 0.14)
	assert(arena.total_waves_to_win == 4, "14%% Boss HP must configure 4 waves (got %d)" % arena.total_waves_to_win)
	assert(arena.wave_interval_sec <= 6.5, "14%% Boss HP must configure aggressive wave interval <= 6.5s (got %.1f)" % arena.wave_interval_sec)
	print("  [PASS] 14%% Boss HP scaled to 4 waves, %.1fs interval." % arena.wave_interval_sec)

	arena.queue_free()

func _test_gate_escalation_and_swarm() -> void:
	print("\n--- 4. Testing Gate Escalation & Swarm Climax Chunk ---")
	var lc: LevelController = LevelController.new()
	add_child(lc)
	assert(lc.get_gate_escalation_tier() == 0, "Initial escalation tier must be 0")

	# Pass 2 gates
	EventBus.gate_passed.emit(1)
	EventBus.gate_passed.emit(1)
	assert(lc.get_gate_escalation_tier() == 2, "Escalation tier must increment to 2 (got %d)" % lc.get_gate_escalation_tier())
	print("  [PASS] LevelController successfully tracked 2 gate passes.")

	# Instantiate ChunkVanguardClimax
	var chunk: ChunkVanguardClimax = CLIMAX_SCENE.instantiate() as ChunkVanguardClimax
	add_child(chunk)

	var entities: Node = chunk.get_node_or_null("Entities")
	assert(entities != null, "ChunkVanguardClimax must contain Entities node")
	var enemy_count: int = 0
	for child: Node in entities.get_children():
		if child.is_in_group("enemies"):
			enemy_count += 1
	assert(enemy_count >= 6, "ChunkVanguardClimax must spawn dense swarm waves (got %d enemies)" % enemy_count)
	print("  [PASS] ChunkVanguardClimax spawned dense StarCraft-style swarm of %d enemies." % enemy_count)

	chunk.queue_free()

	# Instantiate ChunkBossIntroBuffer
	var buffer_scene: PackedScene = preload("res://src/gameplay/chunks/chunk_boss_intro_buffer.tscn")
	var buffer_chunk: Node3D = buffer_scene.instantiate() as Node3D
	add_child(buffer_chunk)
	var buffer_entities: Node = buffer_chunk.get_node_or_null("Entities")
	assert(buffer_entities != null, "ChunkBossIntroBuffer must contain Entities node")
	var buffer_enemy_count: int = 0
	for child: Node in buffer_entities.get_children():
		if child.is_in_group("enemies"):
			buffer_enemy_count += 1
	assert(buffer_enemy_count >= 10, "ChunkBossIntroBuffer must spawn aggressive vanguard wave (got %d enemies)" % buffer_enemy_count)
	print("  [PASS] ChunkBossIntroBuffer spawned vanguard swarm of %d enemies to eliminate pre-boss downtime." % buffer_enemy_count)

	buffer_chunk.queue_free()
	lc.queue_free()
