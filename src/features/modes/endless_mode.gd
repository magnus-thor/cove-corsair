class_name EndlessMode
extends Node

## Controller for the "Corsair Gauntlet" Endless Extraction Mode.
## Tracks distance, dynamic speed scaling, unbanked doubloons, and wager checkpoints.

signal speed_changed(new_speed: float)
signal multiplier_changed(new_multiplier: float)
signal wager_checkpoint_reached(checkpoint_distance: float)
signal run_extracted(distance_score: int, doubloons_banked: int)

@export var base_speed: float = 7.0
@export var max_speed: float = 24.0
@export var speed_boost_per_push: float = 2.0
@export var wager_interval_meters: float = 1000.0

var distance_traveled: float = 0.0
var current_speed: float = 7.0
var unbanked_doubloons: int = 0
var multiplier: float = 1.0
var speed_boost: float = 0.0
var is_active: bool = false
var has_cashed_out: bool = false

# Checkpoint tracking
var next_checkpoint_distance: float = 1000.0
var _checkpoint_chunk_spawned_for_distance: float = -1.0
var chunks_spawned_count: int = 0
var furthest_chunk_end_z: float = 0.0

# Chunk scene pools for distance tiers
var tier_1_chunks: Array[PackedScene] = [
	preload("res://src/gameplay/chunks/chunk_fodder_swarm.tscn"),
	preload("res://src/gameplay/chunks/chunk_reef_slalom.tscn"),
	preload("res://src/gameplay/chunks/chunk_barricade_siege.tscn"),
	preload("res://src/gameplay/chunks/chunk_gunner_ambush.tscn"),
	preload("res://src/gameplay/chunks/chunk_mine_gauntlet.tscn")
]

var tier_2_chunks: Array[PackedScene] = [
	preload("res://src/gameplay/chunks/chunk_barricade_siege.tscn"),
	preload("res://src/gameplay/chunks/chunk_mine_gauntlet.tscn"),
	preload("res://src/gameplay/chunks/chunk_gunner_ambush.tscn")
]

var tier_3_chunks: Array[PackedScene] = [
	preload("res://src/gameplay/chunks/chunk_mine_gauntlet.tscn"),
	preload("res://src/gameplay/chunks/chunk_barricade_siege.tscn"),
	preload("res://src/gameplay/chunks/chunk_vanguard_climax.tscn")
]

var tier_4_chunks: Array[PackedScene] = [
	preload("res://src/gameplay/chunks/chunk_vanguard_climax.tscn"),
	preload("res://src/gameplay/chunks/chunk_barricade_siege.tscn"),
	preload("res://src/gameplay/chunks/chunk_gunner_ambush.tscn")
]

var wager_fork_scene: PackedScene = preload("res://src/features/track/chunks/chunk_wager_fork.tscn")
var warmup_chunk_scene: PackedScene = preload("res://src/gameplay/chunks/chunk_warmup.tscn")
var reef_slalom_scene: PackedScene = preload("res://src/gameplay/chunks/chunk_reef_slalom.tscn")

# Continuous lane filler prefabs for dense, active gameplay without empty dead spells
var doubloon_scene: PackedScene = preload("res://src/gameplay/collectibles/collectible_doubloon.tscn")
var barrel_scene: PackedScene = preload("res://src/gameplay/obstacles/destructible_barrel.tscn")
var fodder_scene: PackedScene = preload("res://src/gameplay/enemies/enemy_fodder_skiff.tscn")

var _chunk_assembler: ChunkAssembler = null

func _ready() -> void:
	add_to_group("endless_mode")
	current_speed = base_speed
	
	if EventBus:
		if EventBus.has_signal("gold_collected") and not EventBus.gold_collected.is_connected(_on_gold_collected):
			EventBus.gold_collected.connect(_on_gold_collected)
		if EventBus.has_signal("player_sunk") and not EventBus.player_sunk.is_connected(_on_player_sunk):
			EventBus.player_sunk.connect(_on_player_sunk)

func start_run() -> void:
	is_active = true
	has_cashed_out = false
	distance_traveled = 0.0
	speed_boost = 0.0
	multiplier = 1.0
	unbanked_doubloons = 0
	next_checkpoint_distance = wager_interval_meters
	current_speed = calculate_speed(0.0)
	
	GameState.is_game_active = true
	GameState.run_doubloons = 0
	GameState.run_doubloons_banked = false
	GameState.level_distance_target = 999999.0
	GameState.distance_traveled = 0.0
	GameState.set_multiplier(multiplier, "x")
	
	_chunk_assembler = get_tree().get_first_node_in_group("chunk_assembler") as ChunkAssembler
	if _chunk_assembler:
		_chunk_assembler.scroll_speed = current_speed
		_init_endless_chunks()
	
	speed_changed.emit(current_speed)
	multiplier_changed.emit(multiplier)

func _physics_process(delta: float) -> void:
	if not is_active or has_cashed_out:
		return
		
	# Distance accumulation (can also be synced with ChunkAssembler)
	var move_delta: float = current_speed * delta
	distance_traveled += move_delta
	
	# Speed formula: current_speed = min(max_speed, base_speed + (distance_traveled / 250.0) * 0.5) + speed_boost
	var new_speed: float = calculate_speed(distance_traveled)
	if not is_equal_approx(new_speed, current_speed):
		current_speed = new_speed
		speed_changed.emit(current_speed)
		if _chunk_assembler and is_instance_valid(_chunk_assembler):
			_chunk_assembler.scroll_speed = current_speed
	
	# Synchronize with GameState HUD progress
	GameState.distance_traveled = distance_traveled
	if GameState.has_signal("progress_changed"):
		GameState.progress_changed.emit(distance_traveled, next_checkpoint_distance)
		
	# Approach checkpoint HUD telegraph (within 110m of wager checkpoint)
	var dist_to_chk: float = next_checkpoint_distance - distance_traveled
	var hud: Node = get_tree().get_first_node_in_group("top_hud")
	if hud and "level_title" in hud and hud.get("level_title"):
		var title_label: Label = hud.get("level_title") as Label
		if title_label:
			if dist_to_chk > 0.0 and dist_to_chk <= 110.0:
				title_label.text = "⚖ WAGER FORK: ◄ [GREEN] CASH OUT | [RED] PUSH LUCK ►"
				title_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3, 1.0))
			elif title_label.text.begins_with("⚖"):
				title_label.text = "CORSAIR GAUNTLET"
				title_label.add_theme_color_override("font_color", Color(0.98, 0.95, 0.89, 1.0))
		
	# Stream chunks if running with ChunkAssembler
	if _chunk_assembler and is_instance_valid(_chunk_assembler):
		_check_stream_chunks()

## Formula: current_speed = min(max_speed, base_speed + (distance_traveled / 250.0) * 0.5) + speed_boost
func calculate_speed(dist: float) -> float:
	var scaled: float = base_speed + (dist / 250.0) * 0.5 + speed_boost
	return minf(max_speed, scaled)

func _on_gold_collected(amount: int) -> void:
	if not is_active:
		return
	var gained: int = int(round(float(amount) * multiplier))
	unbanked_doubloons += gained
	GameState.run_doubloons = unbanked_doubloons
	GameState.doubloons_changed.emit(GameState.doubloons + unbanked_doubloons)

## Wager Fork: Left Lane Action
## Ends run, banks 100% of unbanked doubloons safely, emits run_extracted.
func bank_and_exit() -> void:
	if has_cashed_out:
		return
	has_cashed_out = true
	is_active = false
	
	print("[ENDLESS MODE] Player CASHOUT & RETREAT: Banking %d Doubloons (Distance: %.1fm)" % [unbanked_doubloons, distance_traveled])
	
	var hud: Node = get_tree().get_first_node_in_group("top_hud")
	if hud and "level_title" in hud and hud.get("level_title"):
		var title_label: Label = hud.get("level_title") as Label
		if title_label:
			title_label.text = "⚓ ENTERING SAFE HARBOR... SECURING 100% LOOT!"
			title_label.add_theme_color_override("font_color", Color(0.20, 0.96, 0.65, 1.0))
	
	# Bank 100% of unbanked doubloons
	var banked: int = unbanked_doubloons
	GameState.doubloons += banked
	GameState.run_doubloons = 0
	GameState.run_doubloons_banked = true
	GameState.save_game()
	GameState.doubloons_changed.emit(GameState.doubloons)
	
	if AudioManager:
		AudioManager.play_sfx("gate_passes")
		if AudioManager.has_method("play_coin_pickup_scaled"):
			AudioManager.play_coin_pickup_scaled()
	
	var final_score: int = int(distance_traveled)
	run_extracted.emit(final_score, banked)
	if EventBus and EventBus.has_signal("run_extracted"):
		EventBus.run_extracted.emit(final_score, banked)
	
	# Smoothly decelerate scrolling
	if _chunk_assembler and is_instance_valid(_chunk_assembler):
		var tween: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(_chunk_assembler, "scroll_speed", 0.0, 1.2)
	
	# Trigger dedicated extraction settlement screen
	var tree: SceneTree = get_tree()
	if tree:
		tree.create_timer(1.2, true, false, true).timeout.connect(func() -> void:
			var current_tree: SceneTree = get_tree()
			if not current_tree:
				return
			var settlement: Node = current_tree.get_first_node_in_group("settlement_screen")
			if settlement and settlement.has_method("show_extraction"):
				settlement.call("show_extraction", final_score, banked, GameState.doubloons, multiplier)
			else:
				EventBus.level_completed.emit(banked, GameState.targets_destroyed)
		)

## Wager Fork: Right Lane Action
## Pushes luck: Multiplier +0.5, speed burst, triggers audio/VFX fanfare.
func push_luck() -> void:
	if not is_active or has_cashed_out:
		return
		
	multiplier += 0.5
	speed_boost += speed_boost_per_push
	current_speed = calculate_speed(distance_traveled)
	next_checkpoint_distance += wager_interval_meters
	
	print("[ENDLESS MODE] CORSAIR'S GAMBLE! Multiplier increased to %.1fx, Speed boosted to %.1f m/s" % [multiplier, current_speed])
	
	var hud: Node = get_tree().get_first_node_in_group("top_hud")
	if hud and "level_title" in hud and hud.get("level_title"):
		var title_label: Label = hud.get("level_title") as Label
		if title_label:
			title_label.text = "☠ CORSAIR'S GAMBLE! MULTIPLIER BOOSTED TO %.1fx!" % multiplier
			title_label.add_theme_color_override("font_color", Color(1.0, 0.40, 0.20, 1.0))
			get_tree().create_timer(3.5, true, false, true).timeout.connect(func() -> void:
				if is_instance_valid(title_label) and is_active:
					title_label.text = "CORSAIR GAUNTLET"
					title_label.add_theme_color_override("font_color", Color(0.98, 0.95, 0.89, 1.0))
			)
	
	GameState.set_multiplier(multiplier, "x")
	multiplier_changed.emit(multiplier)
	speed_changed.emit(current_speed)
	
	if _chunk_assembler and is_instance_valid(_chunk_assembler):
		_chunk_assembler.scroll_speed = current_speed
		
	if AudioManager:
		AudioManager.play_sfx("gate_passes")
		if AudioManager.has_method("play_barrel_break_scaled"):
			AudioManager.play_barrel_break_scaled()
			
	if EventBus and EventBus.has_signal("wager_pushed"):
		EventBus.wager_pushed.emit(multiplier, current_speed)
	if EventBus and EventBus.has_signal("screen_shake_requested"):
		EventBus.screen_shake_requested.emit(0.35)

func _on_player_sunk() -> void:
	if not is_active:
		return
	is_active = false
	
	# Sinking with unbanked wager loses 50% unbanked doubloons
	var retained_doubloons: int = int(floor(float(unbanked_doubloons) * 0.5))
	var lost_doubloons: int = unbanked_doubloons - retained_doubloons
	print("[ENDLESS MODE] Sunk with unbanked wager! Lost 50%% doubloons (%d lost, %d retained)" % [lost_doubloons, retained_doubloons])
	
	unbanked_doubloons = retained_doubloons
	GameState.run_doubloons = retained_doubloons
	GameState.bank_run_doubloons(0)

# --- Procedural Chunk Streaming ---

func _init_endless_chunks() -> void:
	if not _chunk_assembler or not is_instance_valid(_chunk_assembler):
		return
		
	for chunk: BaseTrackChunk in _chunk_assembler.active_chunks:
		if is_instance_valid(chunk):
			chunk.queue_free()
	_chunk_assembler.active_chunks.clear()
	
	chunks_spawned_count = 0
	_checkpoint_chunk_spawned_for_distance = -1.0
	
	# Seed initial 5 continuous runway chunks
	for i: int in range(5):
		_spawn_next_procedural_chunk()
		
	if not _chunk_assembler.active_chunks.is_empty():
		_chunk_assembler.active_chunks[0].activate_spawners()

func _check_stream_chunks() -> void:
	if not _chunk_assembler or not is_instance_valid(_chunk_assembler):
		return
		
	# Check where the furthest active chunk currently ends in real-time
	var furthest_end_z: float = 0.0
	if not _chunk_assembler.active_chunks.is_empty():
		var last_chunk: BaseTrackChunk = _chunk_assembler.active_chunks.back()
		furthest_end_z = last_chunk.position.z - last_chunk.get_chunk_length()
	else:
		furthest_end_z = 0.0
		
	# Keep a continuous buffer of chunks spanning at least 250m ahead of camera (-250.0m)
	while _chunk_assembler.active_chunks.size() < 5 or furthest_end_z > -250.0:
		_spawn_next_procedural_chunk()
		if not _chunk_assembler.active_chunks.is_empty():
			var last_chunk: BaseTrackChunk = _chunk_assembler.active_chunks.back()
			furthest_end_z = last_chunk.position.z - last_chunk.get_chunk_length()
		else:
			break

func _spawn_next_procedural_chunk() -> void:
	if not _chunk_assembler or not is_instance_valid(_chunk_assembler):
		return
		
	# The next chunk MUST attach seamlessly to the end of the last active chunk (ZERO GAPS)
	var spawn_z: float = 0.0
	if not _chunk_assembler.active_chunks.is_empty():
		var last_chunk: BaseTrackChunk = _chunk_assembler.active_chunks.back()
		spawn_z = last_chunk.position.z - last_chunk.get_chunk_length()
	else:
		spawn_z = 0.0
		
	var next_scene: PackedScene = null
	if chunks_spawned_count == 0:
		# FIRST CHUNK GUARANTEE: The level MUST start slow with a gentle warmup runway
		next_scene = warmup_chunk_scene
	elif chunks_spawned_count == 1:
		# Second chunk: gentle transition before heavy swarms
		next_scene = reef_slalom_scene
	else:
		var proj_dist: float = distance_traveled + absf(spawn_z)
		next_scene = _pick_chunk_for_distance(proj_dist)
		
	if not next_scene:
		return
		
	var chunk_instance: BaseTrackChunk = next_scene.instantiate() as BaseTrackChunk
	if not chunk_instance:
		return
		
	# If this is the starting chunk, enforce 40m safe runway clearance from player origin
	if chunks_spawned_count == 0:
		_enforce_start_clearance(chunk_instance, 40.0)
	elif chunk_instance.chunk_id != "wager_fork":
		# Populate active content in empty gaps to completely eradicate dead spells
		_populate_chunk_lane_content(chunk_instance)
		
	_chunk_assembler.add_child(chunk_instance)
	chunk_instance.position = Vector3(0.0, 0.0, spawn_z)
	_chunk_assembler.active_chunks.append(chunk_instance)
	chunks_spawned_count += 1

func _populate_chunk_lane_content(chunk: BaseTrackChunk) -> void:
	if not chunk or not is_instance_valid(chunk):
		return
	var entities: Node = chunk.find_child("Entities", true, false)
	if not entities:
		var ent_node := Node3D.new()
		ent_node.name = "Entities"
		chunk.add_child(ent_node)
		entities = ent_node
		
	var lanes: Array[float] = [-3.2, 0.0, 3.2]
	var test_zones: Array[float] = [-8.0, -20.0, -32.0, -42.0]
	
	for zone_z: float in test_zones:
		var has_object_in_zone: bool = false
		for child: Node in entities.get_children():
			if child is Node3D:
				var node_3d: Node3D = child as Node3D
				if absf(node_3d.position.z - zone_z) <= 5.5:
					has_object_in_zone = true
					break
		if not has_object_in_zone:
			var lane_x: float = lanes[randi() % lanes.size()]
			var roll: float = randf()
			if roll < 0.55 and doubloon_scene:
				# Spawn a cluster of 3 floating doubloons in an open lane
				for offset_z: float in [-2.5, 0.0, 2.5]:
					var coin: Node3D = doubloon_scene.instantiate() as Node3D
					if coin:
						entities.add_child(coin)
						coin.position = Vector3(lane_x, 0.1, zone_z + offset_z)
			elif roll < 0.80 and barrel_scene:
				# Spawn a floating destructible barrel
				var barrel: Node3D = barrel_scene.instantiate() as Node3D
				if barrel:
					entities.add_child(barrel)
					barrel.position = Vector3(lane_x, 0.05, zone_z)
			elif fodder_scene:
				# Spawn a fodder patrol skiff
				var skiff: Node3D = fodder_scene.instantiate() as Node3D
				if skiff:
					entities.add_child(skiff)
					skiff.position = Vector3(lane_x, 0.1, zone_z)

func _enforce_start_clearance(chunk: BaseTrackChunk, min_clearance: float = 40.0) -> void:
	if not chunk or not is_instance_valid(chunk):
		return
	var entities: Node = chunk.find_child("Entities", true, false)
	if not entities:
		return
	for child: Node in entities.get_children():
		if not is_instance_valid(child):
			continue
		var is_hazard: bool = child.is_in_group("hazards") or child.name.to_lower().contains("mine") or child.name.to_lower().contains("geyser")
		var is_enemy: bool = child.is_in_group("enemies") or child.name.to_lower().contains("enemy") or child.name.to_lower().contains("fodder") or child.name.to_lower().contains("skiff") or child.name.to_lower().contains("rower")
		if (is_hazard or is_enemy) and child is Node3D:
			var node_3d: Node3D = child as Node3D
			if node_3d.position.z > -min_clearance:
				print("[ENDLESS MODE] Suppressed early hostile '%s' at Z=%.1fm in starting chunk (< %.1fm clearance)" % [child.name, node_3d.position.z, min_clearance])
				if child.get_parent():
					child.get_parent().remove_child(child)
				child.queue_free()

func _pick_chunk_for_distance(proj_dist: float) -> PackedScene:
	# Check if we should spawn Wager Fork checkpoint (EXACTLY ONCE per checkpoint interval)
	if proj_dist >= next_checkpoint_distance and _checkpoint_chunk_spawned_for_distance < next_checkpoint_distance and wager_fork_scene:
		_checkpoint_chunk_spawned_for_distance = next_checkpoint_distance
		print("[ENDLESS MODE] Checkpoint Wager Fork spawned for target %.1fm (proj_dist: %.1fm)" % [next_checkpoint_distance, proj_dist])
		return wager_fork_scene
		
	if proj_dist < 1000.0:
		return _random_from_array(tier_1_chunks)
	elif proj_dist < 2500.0:
		return _random_from_array(tier_2_chunks)
	elif proj_dist < 5000.0:
		return _random_from_array(tier_3_chunks)
	else:
		return _random_from_array(tier_4_chunks)

func _random_from_array(scenes: Array[PackedScene]) -> PackedScene:
	if scenes.is_empty():
		return null
	var idx: int = randi() % scenes.size()
	return scenes[idx]
