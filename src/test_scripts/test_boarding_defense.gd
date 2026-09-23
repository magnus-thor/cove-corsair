extends Node3D

## Integration & Unit Test Harness for the 3-Zone Deck Defense Boarding System.
## Validates ropes, catenary curves, boarder climbing, zone infestation,
## player weapons, and automated crew synergies.

func _ready() -> void:
	print("\n========================================================")
	print("  TESTING 3-ZONE DECK DEFENSE BOARDING SYSTEM")
	print("========================================================\n")
	
	_test_boarding_zone()
	_test_grapple_rope()
	_test_boarder_climbing_and_fall()
	_test_player_weapons_and_targeting()
	_test_crew_station_roles()
	_test_defense_arena_orchestration()
	
	print("\n========================================================")
	print("  ALL 3-ZONE BOARDING DEFENSE TESTS PASSED! ")
	print("========================================================\n")
	get_tree().quit(0)

func _test_boarding_zone() -> void:
	print("--- 1. Testing BoardingZone State Machine & Infestation ---")
	var zone: BoardingZone = BoardingZone.new()
	zone.zone_id = "bow"
	zone.max_infestation = 100.0
	zone.infestation_per_enemy_per_sec = 10.0
	zone.recovery_per_sec = 20.0
	add_child(zone)
	
	assert(zone.current_infestation == 0.0, "Zone must start with 0 infestation")
	assert(not zone.is_overrun, "Zone must not be overrun initially")
	
	# Simulate 1 boarder present
	var dummy_boarder: Node3D = Node3D.new()
	add_child(dummy_boarder)
	zone.register_boarder(dummy_boarder)
	assert(zone.active_boarders.size() == 1, "Active boarders count must be 1")
	
	# Tick process by 5 seconds (5 * 10 = +50 infestation)
	zone._process(5.0)
	assert(is_equal_approx(zone.current_infestation, 50.0), "Infestation must reach 50.0 (got %f)" % zone.current_infestation)
	assert(not zone.is_overrun, "Zone must not be overrun at 50%")
	
	# Tick another 6 seconds (50 + 60 = 110 -> clamped to 100)
	var overrun_emitted: Array[bool] = [false]
	zone.zone_overrun.connect(func(_zid: String) -> void: overrun_emitted[0] = true)
	zone._process(6.0)
	assert(is_equal_approx(zone.current_infestation, 100.0), "Infestation must reach 100.0 max")
	assert(zone.is_overrun, "Zone must transition to overrun at 100%")
	assert(overrun_emitted[0], "zone_overrun signal must be emitted")
	
	# Remove boarder and test passive recovery
	zone.unregister_boarder(dummy_boarder)
	assert(zone.active_boarders.is_empty(), "Active boarders must be empty")
	
	# Recover for 2.5 seconds (2.5 * 20 = -50 recovery -> 50 remaining)
	zone._process(2.5)
	assert(is_equal_approx(zone.current_infestation, 50.0), "Infestation must drop to 50.0 (got %f)" % zone.current_infestation)
	
	# Recover for 3 more seconds -> clears to 0 and clears overrun
	var cleared_emitted: Array[bool] = [false]
	zone.zone_cleared.connect(func(_zid: String) -> void: cleared_emitted[0] = true)
	zone._process(3.0)
	assert(is_equal_approx(zone.current_infestation, 0.0), "Infestation must drop to 0.0")
	assert(not zone.is_overrun, "Zone must clear overrun state at 0%")
	assert(cleared_emitted[0], "zone_cleared signal must be emitted")
	
	dummy_boarder.queue_free()
	zone.queue_free()
	print("[PASS] BoardingZone infestation and overrun state machine verified.")

func _test_grapple_rope() -> void:
	print("--- 2. Testing BoardingGrappleRope Catenary & Severing ---")
	var rope_scene: PackedScene = load("res://src/features/boarding/boarding_grapple_rope.tscn") as PackedScene
	assert(rope_scene != null, "boarding_grapple_rope.tscn must exist")
	var rope: BoardingGrappleRope = rope_scene.instantiate() as BoardingGrappleRope
	add_child(rope)
	
	var zone: BoardingZone = BoardingZone.new()
	add_child(zone)
	
	var p_start: Vector3 = Vector3(6.0, 2.0, 0.0)
	var p_end: Vector3 = Vector3(0.0, 1.0, 0.0)
	rope.setup_grapple(p_start, p_end, zone)
	
	assert(rope.is_latched, "Rope must be latched after setup")
	assert(zone.active_grapples.has(rope), "Zone must register latched rope")
	
	# Test Catenary Sag at midpoint (t = 0.5)
	var mid_point: Vector3 = rope.get_point_along_rope(0.5)
	var linear_mid_y: float = lerpf(p_start.y, p_end.y, 0.5)
	assert(mid_point.y < linear_mid_y, "Midpoint must sag below linear interpolation (sag: %f vs linear: %f)" % [mid_point.y, linear_mid_y])
	
	# Test damage and severing
	var severed_emitted: Array[bool] = [false]
	rope.rope_severed.connect(func(_r: BoardingGrappleRope) -> void: severed_emitted[0] = true)
	
	rope.take_damage(10.0)
	assert(rope.current_health == 20.0, "Rope health should be 20 after 10 damage")
	assert(rope.is_latched, "Rope must remain latched while HP > 0")
	
	rope.take_damage(25.0) # Lethal damage
	assert(severed_emitted[0], "rope_severed signal must be emitted upon destruction")
	assert(not zone.active_grapples.has(rope), "Zone must unregister severed rope")
	
	zone.queue_free()
	print("[PASS] Grapple rope catenary sag and sever mechanics verified.")

func _test_boarder_climbing_and_fall() -> void:
	print("--- 3. Testing Boarder Climber Progression & Overboard Fall ---")
	var rope_scene: PackedScene = load("res://src/features/boarding/boarding_grapple_rope.tscn") as PackedScene
	var rope: BoardingGrappleRope = rope_scene.instantiate() as BoardingGrappleRope
	add_child(rope)
	
	var zone: BoardingZone = BoardingZone.new()
	add_child(zone)
	rope.setup_grapple(Vector3(6.0, 2.0, 0.0), Vector3(0.0, 1.0, 0.0), zone)
	
	var enemy_scene: PackedScene = load("res://src/features/boarding/boarder_enemy.tscn") as PackedScene
	assert(enemy_scene != null, "boarder_enemy.tscn must exist")
	
	# Case A: Normal climb to deck
	var enemy_a: BoarderEnemy = enemy_scene.instantiate() as BoarderEnemy
	add_child(enemy_a)
	enemy_a.start_climbing(rope, zone)
	
	assert(enemy_a.is_in_group("boarder"), "Enemy must belong to 'boarder' group")
	assert(not enemy_a.is_on_deck, "Enemy must not be on deck at start of climb")
	
	# Advance climbing by 4 seconds (rope climb duration is 3.5s)
	enemy_a._process_climbing(4.0)
	assert(enemy_a.is_on_deck, "Enemy must reach deck after climb duration completes")
	assert(zone.active_boarders.has(enemy_a), "Zone must register enemy when landed on deck")
	
	# Case B: Cut rope mid-climb -> triggers overboard tumble
	var enemy_b: BoarderEnemy = enemy_scene.instantiate() as BoarderEnemy
	add_child(enemy_b)
	enemy_b.start_climbing(rope, zone)
	enemy_b._process_climbing(1.0) # Halfway up
	assert(enemy_b.rope_progress > 0.0 and enemy_b.rope_progress < 1.0, "Enemy must be mid-climb")
	
	# Sever rope
	rope.sever()
	enemy_b._process_climbing(0.1) # Ticks fall
	assert(enemy_b.is_falling, "Enemy must transition to is_falling when rope is severed")
	
	enemy_a.queue_free()
	zone.queue_free()
	print("[PASS] Boarder climbing progression and mid-climb fall verified.")

func _test_player_weapons_and_targeting() -> void:
	print("--- 4. Testing Deck Player Weapons & Targeting ---")
	var player_scene: PackedScene = load("res://src/features/boarding/player/deck_player_controller.tscn") as PackedScene
	assert(player_scene != null, "deck_player_controller.tscn must exist")
	var player: DeckPlayerController = player_scene.instantiate() as DeckPlayerController
	add_child(player)
	
	var enemy_scene: PackedScene = load("res://src/features/boarding/boarder_enemy.tscn") as PackedScene
	var target_enemy: BoarderEnemy = enemy_scene.instantiate() as BoarderEnemy
	add_child(target_enemy)
	# Position in front of player
	target_enemy.global_position = player.global_position + Vector3(0.0, 0.0, -3.0)
	
	# Test Blunderbuss cone damage
	var initial_hp: float = target_enemy.current_hp
	player.fire_blunderbuss()
	assert(target_enemy.current_hp < initial_hp, "Blunderbuss must damage enemy within forward cone")
	
	# Test Heavy Breaker Axe on Grapple Rope
	var rope_scene: PackedScene = load("res://src/features/boarding/boarding_grapple_rope.tscn") as PackedScene
	var rope: BoardingGrappleRope = rope_scene.instantiate() as BoardingGrappleRope
	add_child(rope)
	var dummy_zone: BoardingZone = BoardingZone.new()
	add_child(dummy_zone)
	rope.setup_grapple(Vector3(5, 1, 0), Vector3(0, 1, 0), dummy_zone)
	
	player.current_target_node = rope
	var rope_hp_before: float = rope.current_health
	player.fire_heavy_breaker()
	assert(rope.current_health <= 0.0 or rope.is_queued_for_deletion(), "Heavy Breaker must deal lethal 35 damage to 30 HP rope")
	
	target_enemy.queue_free()
	dummy_zone.queue_free()
	player.queue_free()
	print("[PASS] Blunderbuss conical cleave and Heavy Breaker axe mechanics verified.")

func _test_crew_station_roles() -> void:
	print("--- 5. Testing Automated Crew Station Roles ---")
	var station_scene: PackedScene = load("res://src/features/boarding/crew/boarding_crew_station.tscn") as PackedScene
	assert(station_scene != null, "boarding_crew_station.tscn must exist")
	var station: BoardingCrewStation = station_scene.instantiate() as BoardingCrewStation
	add_child(station)
	
	# Test role assignment
	station.setup_crew("monkey_bomber")
	assert(station.crew_role == "bomber", "monkey_bomber must map to 'bomber' role")
	
	station.setup_crew("deckhand_sniper")
	assert(station.crew_role == "sniper", "deckhand_sniper must map to 'sniper' role")
	
	station.setup_crew("skeleton_tosser")
	assert(station.crew_role == "tosser", "skeleton_tosser must map to 'tosser' role")
	
	station.setup_crew("grease_monkey")
	assert(station.crew_role == "mechanic", "grease_monkey must map to 'mechanic' role")
	
	# Test Mechanic Damage Control execution
	var test_zone: BoardingZone = BoardingZone.new()
	add_child(test_zone)
	test_zone.force_set_infestation(50.0)
	station.assigned_zone = test_zone
	
	station._execute_mechanic()
	assert(test_zone.current_infestation < 50.0, "Mechanic must actively reduce zone infestation (got %f)" % test_zone.current_infestation)
	
	test_zone.queue_free()
	station.queue_free()
	print("[PASS] Crew station role mapping and automated behavior verified.")

func _test_defense_arena_orchestration() -> void:
	print("--- 6. Testing BoardingDefenseArena Orchestration ---")
	var arena_scene: PackedScene = load("res://src/features/boarding/boarding_defense_arena.tscn") as PackedScene
	assert(arena_scene != null, "boarding_defense_arena.tscn must exist")
	var arena: BoardingDefenseArena = arena_scene.instantiate() as BoardingDefenseArena
	add_child(arena)
	
	assert(arena.zones.size() == 3, "Arena must coordinate 3 zones")
	assert(is_instance_valid(arena.zone_bow), "Bow zone must be valid")
	assert(is_instance_valid(arena.zone_midship), "Midship zone must be valid")
	assert(is_instance_valid(arena.zone_stern), "Stern zone must be valid")
	
	# Test grapple wave launch
	arena.launch_grapple_to_zone(1) # Midship
	assert(arena.total_ropes_launched == 1, "Rope launch counter must increment to 1")
	
	arena.queue_free()
	print("[PASS] BoardingDefenseArena setup and wave launch verified.")
