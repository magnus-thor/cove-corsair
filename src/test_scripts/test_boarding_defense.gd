extends Node3D

@warning_ignore("untyped_declaration")
@warning_ignore("unsafe_property_access")
@warning_ignore("unsafe_method_access")
@warning_ignore("unsafe_cast")
@warning_ignore("unused_variable")

## Integration & Unit Test Harness for the 3-Zone Deck Defense Boarding System.
## Validates ropes, catenary curves, boarder climbing, zone infestation,
## player weapons, and automated crew synergies.

func _ready() -> void:
	print("\n========================================================")
	print("  TESTING 3-ZONE DECK DEFENSE BOARDING SYSTEM")
	print("========================================================\n")
	
	_test_boarding_zone()
	_test_boarding_plank()
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

func _test_boarding_plank() -> void:
	print("--- 2. Testing BoardingPlank Geometry & Severing ---")
	var plank_scene: PackedScene = load("res://src/features/boarding/boarding_plank.tscn") as PackedScene
	assert(plank_scene != null, "boarding_plank.tscn must exist")
	var plank: BoardingPlank = plank_scene.instantiate() as BoardingPlank
	add_child(plank)
	
	var zone: BoardingZone = BoardingZone.new()
	add_child(zone)
	
	var p_start: Vector3 = Vector3(6.0, 2.0, 0.0)
	var p_end: Vector3 = Vector3(0.0, 1.0, 0.0)
	plank.setup_plank(p_start, p_end, zone)
	
	assert(plank.is_latched, "Plank must be latched after setup")
	assert(zone.active_planks.has(plank), "Zone must register latched plank")
	
	# Test Walking surface height at midpoint (t = 0.5)
	var mid_point: Vector3 = plank.get_point_along_plank(0.5)
	var linear_mid_y: float = lerpf(p_start.y, p_end.y, 0.5)
	assert(mid_point.y >= linear_mid_y, "Plank walking point must be atop the plank surface")
	
	# Test damage and severing
	var severed_emitted: Array[bool] = [false]
	plank.plank_severed.connect(func(_p: BoardingPlank) -> void: severed_emitted[0] = true)
	
	plank.take_damage(10.0)
	assert(plank.current_health == 20.0, "Plank health should be 20 after 10 damage")
	assert(plank.is_latched, "Plank must remain latched while HP > 0")
	
	plank.take_damage(25.0) # Lethal damage
	assert(severed_emitted[0], "plank_severed signal must be emitted upon destruction")
	assert(not zone.active_planks.has(plank), "Zone must unregister severed plank")
	
	zone.queue_free()
	print("[PASS] Boarding plank geometry and sever mechanics verified.")

func _test_boarder_climbing_and_fall() -> void:
	print("--- 3. Testing Boarder Climber Progression & Overboard Fall ---")
	var plank_scene: PackedScene = load("res://src/features/boarding/boarding_plank.tscn") as PackedScene
	var plank: BoardingPlank = plank_scene.instantiate() as BoardingPlank
	add_child(plank)
	
	var zone: BoardingZone = BoardingZone.new()
	add_child(zone)
	plank.setup_plank(Vector3(6.0, 2.0, 0.0), Vector3(0.0, 1.0, 0.0), zone)
	
	var enemy_scene: PackedScene = load("res://src/features/boarding/boarder_enemy.tscn") as PackedScene
	assert(enemy_scene != null, "boarder_enemy.tscn must exist")
	
	# Case A: Normal climb to deck
	var enemy_a: BoarderEnemy = enemy_scene.instantiate() as BoarderEnemy
	add_child(enemy_a)
	enemy_a.start_crossing(plank, zone)
	
	assert(enemy_a.is_in_group("boarder"), "Enemy must belong to 'boarder' group")
	assert(not enemy_a.is_on_deck, "Enemy must not be on deck at start of climb")
	assert(enemy_a.anim_player != null, "BoarderEnemy must have AnimationPlayer configured")
	assert(enemy_a.anim_player.has_animation("Walking"), "AnimationPlayer must contain 'Walking'")
	assert(enemy_a.anim_player.has_animation("Running"), "AnimationPlayer must contain 'Running'")
	assert(enemy_a.anim_player.has_animation("Attack"), "AnimationPlayer must contain 'Attack'")
	assert(enemy_a.anim_player.has_animation("Dead"), "AnimationPlayer must contain 'Dead'")
	
	# Advance climbing by 6.0 seconds (cross duration is 4.2s with cross speed)
	enemy_a._process_climbing(6.0)
	assert(enemy_a.is_on_deck, "Enemy must reach deck after climb duration completes")
	assert(zone.active_boarders.has(enemy_a), "Zone must register enemy when landed on deck")
	
	# Case B: Cut plank mid-crossing -> triggers overboard tumble
	var enemy_b: BoarderEnemy = enemy_scene.instantiate() as BoarderEnemy
	add_child(enemy_b)
	enemy_b.start_crossing(plank, zone)
	enemy_b._process_crossing(1.0) # Halfway across
	assert(enemy_b.plank_progress > 0.0 and enemy_b.plank_progress < 1.0, "Enemy must be mid-crossing")
	
	# Sever plank
	plank.sever()
	enemy_b._process_crossing(0.1) # Ticks fall
	assert(enemy_b.is_falling, "Enemy must transition to is_falling when plank is severed")
	
	# Case C: Standalone deck placement without plank (e.g. Free Roam / Event)
	var enemy_c: BoarderEnemy = enemy_scene.instantiate() as BoarderEnemy
	add_child(enemy_c)
	@warning_ignore("unsafe_method_access")
	enemy_c.spawn_on_deck(Vector3(0.0, 1.0, 0.0), null)
	assert(enemy_c.is_on_deck, "Enemy spawned on deck must be immediately on deck")
	assert(not enemy_c.is_falling, "Enemy spawned on deck must not fall")
	enemy_c._physics_process(0.1) # Ticks free roam movement
	assert(not enemy_c.is_falling, "Standalone enemy without plank must not fall overboard")
	
	# Case D: Archetype scene variants (Raider vs Brute)
	var raider_scene: PackedScene = load("res://src/features/boarding/enemies/boarder_raider.tscn") as PackedScene
	assert(raider_scene != null, "boarder_raider.tscn must exist")
	var raider: BoarderEnemy = raider_scene.instantiate() as BoarderEnemy
	add_child(raider)
	assert(raider.archetype_name == "Raider", "Raider archetype name must be Raider")
	assert(raider.max_hp == 18.0, "Raider HP must be 18.0")
	assert(raider.infestation_weight == 1.0, "Raider infestation weight must be 1.0")

	var brute_scene: PackedScene = load("res://src/features/boarding/enemies/boarder_brute.tscn") as PackedScene
	assert(brute_scene != null, "boarder_brute.tscn must exist")
	var brute: BoarderEnemy = brute_scene.instantiate() as BoarderEnemy
	add_child(brute)
	assert(brute.archetype_name == "Brute", "Brute archetype name must be Brute")
	assert(brute.max_hp == 70.0, "Brute HP must be 70.0")
	assert(brute.infestation_weight == 2.5, "Brute infestation weight must be 2.5")
	assert(brute.cross_speed_mult < 1.0, "Brute cross speed must be slower than standard")

	# Test Brute heavier infestation weight in zone
	var test_zone_brute: BoardingZone = BoardingZone.new()
	test_zone_brute.max_infestation = 100.0
	test_zone_brute.infestation_per_enemy_per_sec = 10.0
	add_child(test_zone_brute)
	test_zone_brute.register_boarder(brute)
	test_zone_brute._process(1.0) # 1 sec * 10 rate * 2.5 weight = 25.0
	assert(is_equal_approx(test_zone_brute.current_infestation, 25.0), "Brute must cause 25 infestation in 1s with weight 2.5 (got %f)" % test_zone_brute.current_infestation)

	enemy_c.queue_free()
	raider.queue_free()
	brute.queue_free()
	test_zone_brute.queue_free()
	enemy_a.queue_free()
	zone.queue_free()
	print("[PASS] Boarder climbing progression, standalone placement, and archetype variants verified.")

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
	
	# Test Heavy Breaker Axe on Boarding Plank
	var plank_scene: PackedScene = load("res://src/features/boarding/boarding_plank.tscn") as PackedScene
	var plank: BoardingPlank = plank_scene.instantiate() as BoardingPlank
	add_child(plank)
	var dummy_zone: BoardingZone = BoardingZone.new()
	add_child(dummy_zone)
	plank.setup_plank(Vector3(5, 1, 0), Vector3(0, 1, 0), dummy_zone)
	
	player.current_target_node = plank
	player.fire_heavy_breaker()
	assert(plank.current_health <= 0.0 or plank.is_queued_for_deletion(), "Heavy Breaker must deal lethal 35 damage to 30 HP plank")
	
	# Test Clicking Plank positions crew at deck connection point without damaging plank
	var plank2: BoardingPlank = plank_scene.instantiate() as BoardingPlank
	add_child(plank2)
	var deck_zone: BoardingZone = BoardingZone.new()
	var station_mark: Marker3D = Marker3D.new()
	station_mark.position = Vector3(1.2, 0.0, 0.5)
	deck_zone.add_child(station_mark)
	deck_zone.station_marker = station_mark
	add_child(deck_zone)
	plank2.setup_plank(Vector3(6.0, 1.0, 0.5), Vector3(1.8, 1.0, 0.5), deck_zone)
	
	var hp_plank2_before: float = plank2.current_health
	player._on_target_acquired(plank2, Vector3(4.0, 1.0, 0.5))
	assert(plank2.current_health == hp_plank2_before, "Clicking plank must NOT damage or sever plank")
	assert(player.selected_plank == plank2, "Clicking plank must set selected_plank on crew defender")
	assert(is_equal_approx(player.global_position.x, player.initial_deck_position.x), "Crew member must stay in the same place always")
	
	plank2.queue_free()
	deck_zone.queue_free()
	target_enemy.queue_free()
	player.select_plank(null)

	# Test Crew turns towards targeted spot while staying in place always
	var initial_crew_pos: Vector3 = player.global_position
	player._on_target_acquired(null, Vector3(1.5, 0.0, -1.0))
	player._physics_process(0.1)
	assert(player.global_position.is_equal_approx(initial_crew_pos), "Crew member must remain in the same place always")
	assert(player.aim_target_point.is_equal_approx(Vector3(1.5, 0.0, -1.0)), "Crew member must face targeted spot")
	
	# Test Auto-Attack on Nearest Boarder
	var auto_target: BoarderEnemy = enemy_scene.instantiate() as BoarderEnemy
	add_child(auto_target)
	auto_target.spawn_on_deck(player.global_position + Vector3(0.0, 0.0, 2.0), null)
	var hp_before_auto: float = auto_target.current_hp
	player.auto_attack_timer = 0.0
	player._process_auto_attack(0.1)
	assert(auto_target.current_hp < hp_before_auto, "Crew auto-attack must automatically damage nearest boarder within range")
	
	# Test Crew Special Attacks (Bomber AoE, Sniper Pierce, Swordsman Cleave, Mechanic Tar)
	player.setup_defender_model("monkey_bomber")
	assert(player.crew_role == "bomber", "Crew role must be bomber")
	player.special_timer = 0.0
	player.fire_special_attack()
	assert(player.special_timer > 0.0, "Bomber special attack must trigger cooldown")
	
	player.setup_defender_model("deckhand_sniper")
	assert(player.crew_role == "sniper", "Crew role must be sniper")
	player.special_timer = 0.0
	player.fire_special_attack()
	assert(player.special_timer > 0.0, "Sniper special attack must trigger cooldown")
	
	# Test Boarder approaching and attacking crew member
	var attacker: BoarderEnemy = enemy_scene.instantiate() as BoarderEnemy
	add_child(attacker)
	attacker.spawn_on_deck(player.global_position + Vector3(0.0, 0.0, 1.0), null) # Within 1.35m attack range
	attacker._attack_timer = 0.0
	var player_hp_before: float = player.current_health
	attacker._process_deck_combat(0.1)
	assert(player.current_health < player_hp_before, "Boarder must damage crew defender in melee range")
	attacker.queue_free()
	
	auto_target.queue_free()
	dummy_zone.queue_free()
	player.queue_free()
	print("[PASS] Blunderbuss, Heavy Breaker, Tap-to-Move, Auto-Attack, and Crew Special Attacks verified.")

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
	
	# 1. Verify Vessel Containers & Crew Node Structure
	assert(is_instance_valid(arena.player_ship_container), "player_ship_container must be valid")
	assert(is_instance_valid(arena.enemy_ship_container), "enemy_ship_container must be valid")
	assert(arena.player_controller.has_node("DeckMarker"), "Player controller must have explicit DeckMarker node")
	assert(arena.crew_station_bow.has_node("DeckMarker"), "Bow crew station must have explicit DeckMarker node")
	assert(arena.crew_station_stern.has_node("DeckMarker"), "Stern crew station must have explicit DeckMarker node")
	
	# 2. Verify Dedicated BoardingCamera3D
	assert(is_instance_valid(arena.boarding_camera), "BoardingCamera3D must be assigned")
	assert(arena.boarding_camera.current, "BoardingCamera3D must be active/current")
	
	# 3. Verify Enemy Approach & Docking Sequence
	assert(arena.is_approaching, "Enemy ship must be approaching on scene start")
	assert(arena.enemy_ship_container.position.x >= 14.0, "Enemy ship must start at >= 14.0m lateral offset (got %f)" % arena.enemy_ship_container.position.x)
	
	# Enable spawns for test simulation of approach tween
	arena.debug_disable_spawns = false
	arena._on_docking_complete()
	assert(not arena.is_approaching, "Approach must be complete after docking")
	assert(arena.total_planks_launched == 3, "Docking sequence must launch 3 boarding planks into Bow, Midship, Stern (got %d)" % arena.total_planks_launched)
	
	# 4. Verify Boss Tier 1 2-Plank Mode
	var arena_tier1: BoardingDefenseArena = arena_scene.instantiate() as BoardingDefenseArena
	add_child(arena_tier1)
	arena_tier1.boss_tier = 1
	arena_tier1.debug_disable_spawns = false
	arena_tier1._on_docking_complete()
	assert(arena_tier1.total_planks_launched == 2, "Boss Tier 1 must launch exactly 2 planks from the start (got %d)" % arena_tier1.total_planks_launched)
	
	# 5. Verify Stern Breach triggers Encounter Lost
	var test_enemy: BoarderEnemy = BoarderEnemy.new()
	arena_tier1.add_child(test_enemy)
	var lost_emitted: Array[bool] = [false]
	arena_tier1.encounter_lost.connect(func() -> void: lost_emitted[0] = true)
	arena_tier1._on_enemy_breached_stern(test_enemy)
	assert(lost_emitted[0], "Stern breach must immediately trigger encounter_lost")
	
	test_enemy.queue_free()
	arena_tier1.queue_free()
	arena.queue_free()
	print("[PASS] BoardingDefenseArena deck elevation, camera, single-plank scaling, and stern breach verified.")
