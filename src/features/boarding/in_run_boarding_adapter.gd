class_name InRunBoardingAdapter
extends Node

## Adapts the 3-Zone Deck Defense system to in-run boss fights and endless mode.
## Freezes runner scrolling, pauses LevelController and ChunkAssembler,
## disables player cannons, stages BoardingDefenseArena at an isolated altitude,
## transitions active camera to BoardingCamera3D, and cascades victory to boss defeat.

signal boarding_started(boss_name: String)
signal boarding_completed(boss: Node3D)

const ARENA_SCENE: PackedScene = preload("res://src/features/boarding/boarding_defense_arena.tscn")
const STAGING_POSITION: Vector3 = Vector3(0.0, 400.0, 0.0)

var active_arena: BoardingDefenseArena = null
var active_boss: Node3D = null
var active_player: Node3D = null

var _prev_chunk_scroll: float = 0.0
var _prev_level_ctrl_speed: float = 0.0
var _prev_player_shooting: bool = false
var _chunk_assembler: ChunkAssembler = null
var _track_manager: TrackManager = null
var _level_controller: Node = null
var _player_camera: Camera3D = null

func start_in_run_boarding(boss: Node3D, player: Node3D) -> void:
	if not is_instance_valid(boss) or not is_instance_valid(player):
		return

	active_boss = boss
	active_player = player

	# ── 1. Freeze the runner world (ChunkAssembler, TrackManager, LevelController)
	_pause_runner()

	# ── 2. Disable player cannon and swerve movement ────────────────────────
	_disable_player_controls()

	# ── 3. Lock boss into combat-only state and hide runner model ───────────
	if "current_state" in boss:
		boss.set("current_state", 1)
	if "is_barrage_active" in boss:
		boss.set("is_barrage_active", false)
	boss.hide()

	# ── 4. Instantiate Boarding Defense Arena at isolated staging altitude ─
	active_arena = ARENA_SCENE.instantiate() as BoardingDefenseArena
	active_arena.position = STAGING_POSITION
	
	# Configure encounter difficulty and wave scaling based on campaign level or endless mode
	var cur_lvl: int = GameState.current_level if GameState else 1
	var is_endless: bool = GameState.is_endless_mode if GameState else false
	var endless_dist: float = GameState.distance_traveled if GameState else 0.0
	if active_arena.has_method("setup_encounter_difficulty"):
		active_arena.setup_encounter_difficulty(cur_lvl, is_endless, endless_dist)
	elif cur_lvl <= 15:
		active_arena.boss_tier = 1
		active_arena.single_plank_mode = false
	elif cur_lvl <= 30:
		active_arena.boss_tier = 2
	else:
		active_arena.boss_tier = 3

	var p_vessel: String = "sloop"
	if GameState and "active_vessel" in GameState and not str(GameState.active_vessel).is_empty():
		p_vessel = str(GameState.active_vessel)
	active_arena.pending_player_vessel_id = p_vessel
	active_arena.pending_boss = active_boss

	var root: Node = get_tree().current_scene
	if not root:
		root = active_player.get_parent()
	root.add_child(active_arena)
	active_arena.global_position = STAGING_POSITION

	# Configure matching enemy ship model
	if is_instance_valid(active_arena) and active_arena.has_method("setup_enemy_vessel"):
		active_arena.setup_enemy_vessel(active_boss)

	# Configure matching player ship model
	if is_instance_valid(active_arena) and active_arena.has_method("setup_player_vessel"):
		active_arena.setup_player_vessel(p_vessel)

	# Configure biome visuals
	_apply_biome_to_arena()

	# ── 5. Switch viewport to dedicated BoardingCamera3D on player vessel ──
	_store_and_disable_run_camera()

	# ── 6. Wire up encounter signals ────────────────────────────────────────
	active_arena.encounter_won.connect(_on_arena_won)
	active_arena.encounter_lost.connect(_on_arena_lost)

	boarding_started.emit(String(active_boss.name) if is_instance_valid(active_boss) else "")


func _apply_biome_to_arena() -> void:
	if not is_instance_valid(active_arena) or not active_arena.has_method("apply_biome_visuals"):
		return
	var b_name: String = ""
	if GameState and GameState.has_method("get_current_level_resource"):
		var lres: Resource = GameState.get_current_level_resource() as Resource
		if is_instance_valid(lres):
			var res_obj: Object = lres as Object
			if "biome_name" in res_obj and not str(res_obj.get("biome_name")).is_empty():
				b_name = str(res_obj.get("biome_name"))
			elif "biome" in res_obj and not str(res_obj.get("biome")).is_empty():
				b_name = str(res_obj.get("biome"))
	if b_name != "":
		active_arena.apply_biome_visuals(b_name)


func _pause_runner() -> void:
	# Pause ChunkAssembler
	var assembler: Node = get_tree().get_first_node_in_group("chunk_assembler")
	if assembler is ChunkAssembler:
		_chunk_assembler = assembler as ChunkAssembler
		_prev_chunk_scroll = _chunk_assembler.scroll_speed
		_chunk_assembler.scroll_speed = 0.0
		_chunk_assembler.is_boss_active = true
		_chunk_assembler.set_physics_process(false)
		_chunk_assembler.set_process(false)

	# Pause legacy TrackManager
	var track_mgr: Node = get_tree().get_first_node_in_group("track_manager")
	if track_mgr is TrackManager:
		_track_manager = track_mgr as TrackManager
		_track_manager.scroll_speed = 0.0
		_track_manager.set_physics_process(false)
		_track_manager.set_process(false)

	# Pause LevelController
	var lvl_ctrl: Node = get_tree().get_first_node_in_group("level_controller")
	if lvl_ctrl and is_instance_valid(lvl_ctrl):
		_level_controller = lvl_ctrl
		_prev_level_ctrl_speed = float(lvl_ctrl.get("base_scroll_speed")) if ("base_scroll_speed" in lvl_ctrl) else 0.0
		lvl_ctrl.set("base_scroll_speed", 0.0)
		lvl_ctrl.set_physics_process(false)
		lvl_ctrl.set_process(false)

	# Pause EndlessMode
	var endless_mode: Node = get_tree().get_first_node_in_group("endless_mode")
	if endless_mode and is_instance_valid(endless_mode):
		endless_mode.set_physics_process(false)
		endless_mode.set_process(false)

	# Freeze lane enemies
	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		if not enemy.is_in_group("boarder") and enemy is Node3D:
			(enemy as Node3D).hide()
			enemy.set_process(false)
			enemy.set_physics_process(false)

	# Freeze hazards
	for hazard: Node in get_tree().get_nodes_in_group("hazards"):
		if hazard is Node3D:
			(hazard as Node3D).hide()
			hazard.set_process(false)
			hazard.set_physics_process(false)


func _disable_player_controls() -> void:
	if not is_instance_valid(active_player):
		return
	if "is_shooting_enabled" in active_player:
		_prev_player_shooting = active_player.get("is_shooting_enabled") as bool
		active_player.set("is_shooting_enabled", false)
	active_player.set_physics_process(false)
	for follower: Node in get_tree().get_nodes_in_group("follower"):
		follower.set_process(false)
		follower.set_physics_process(false)


func _store_and_disable_run_camera() -> void:
	# 1. Disable all cameras in game_camera group
	var cameras: Array[Node] = get_tree().get_nodes_in_group("game_camera")
	for cam_node: Node in cameras:
		if cam_node is Camera3D:
			var cam: Camera3D = cam_node as Camera3D
			_player_camera = cam
			cam.set_process(false)
			cam.set_physics_process(false)
			cam.current = false
			cam.clear_current(true)

	# Check fallback on player subtree
	if is_instance_valid(active_player):
		var cam_child: Node = active_player.find_child("*Camera*", true, false)
		if cam_child is Camera3D:
			_player_camera = cam_child as Camera3D
			(cam_child as Camera3D).set_process(false)
			(cam_child as Camera3D).set_physics_process(false)
			(cam_child as Camera3D).current = false
			(cam_child as Camera3D).clear_current(true)

	# Check active viewport camera
	var vp: Viewport = get_viewport()
	if vp:
		var cur_cam: Camera3D = vp.get_camera_3d()
		if is_instance_valid(cur_cam) and (not is_instance_valid(active_arena) or cur_cam != active_arena.boarding_camera):
			_player_camera = cur_cam
			cur_cam.set_process(false)
			cur_cam.set_physics_process(false)
			cur_cam.current = false
			cur_cam.clear_current(true)

	# 2. Make BoardingCamera3D current
	if is_instance_valid(active_arena) and is_instance_valid(active_arena.boarding_camera):
		active_arena.boarding_camera.current = true
		active_arena.boarding_camera.make_current()


func _restore_runner() -> void:
	# Re-enable ChunkAssembler
	if is_instance_valid(_chunk_assembler):
		_chunk_assembler.scroll_speed = _prev_chunk_scroll
		_chunk_assembler.is_boss_active = false
		_chunk_assembler.set_physics_process(true)
		_chunk_assembler.set_process(true)

	# Re-enable TrackManager
	if is_instance_valid(_track_manager):
		_track_manager.scroll_speed = _prev_chunk_scroll
		_track_manager.set_physics_process(true)
		_track_manager.set_process(true)

	# Re-enable LevelController
	if is_instance_valid(_level_controller):
		_level_controller.set("base_scroll_speed", _prev_level_ctrl_speed)
		_level_controller.set_physics_process(true)
		_level_controller.set_process(true)
	_level_controller = null

	# Re-enable EndlessMode
	var endless_mode: Node = get_tree().get_first_node_in_group("endless_mode")
	if endless_mode and is_instance_valid(endless_mode):
		endless_mode.set_physics_process(true)
		endless_mode.set_process(true)

	# Restore run camera
	if is_instance_valid(_player_camera):
		_player_camera.set_process(true)
		_player_camera.set_physics_process(true)
		_player_camera.current = true
		_player_camera.make_current()
	_player_camera = null

	# Restore player controls
	if is_instance_valid(active_player):
		active_player.set("is_shooting_enabled", _prev_player_shooting)
		active_player.set_physics_process(true)

	# Restore followers
	for follower: Node in get_tree().get_nodes_in_group("follower"):
		follower.set_process(true)
		follower.set_physics_process(true)

	# Restore enemies and hazards
	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		if not enemy.is_in_group("boarder") and enemy is Node3D:
			(enemy as Node3D).show()
			enemy.set_process(true)
			enemy.set_physics_process(true)
	for hazard: Node in get_tree().get_nodes_in_group("hazards"):
		if hazard is Node3D:
			(hazard as Node3D).show()
			hazard.set_process(true)
			hazard.set_physics_process(true)

	# Restore runner boss visibility
	if is_instance_valid(active_boss):
		active_boss.show()


func _on_arena_won() -> void:
	var boss: Node3D = active_boss
	if is_instance_valid(active_arena):
		active_arena.queue_free()
		active_arena = null

	_restore_runner()
	boarding_completed.emit(boss)

	if is_instance_valid(boss) and boss.has_method("boss_defeat"):
		boss.call("boss_defeat")
	elif is_instance_valid(boss) and boss.has_method("die"):
		boss.call("die")

	queue_free()


func _on_arena_lost() -> void:
	if is_instance_valid(active_player):
		if active_player is PlayerSwerve:
			(active_player as PlayerSwerve).game_over(false)
		elif active_player.has_method("game_over"):
			active_player.call("game_over", false)
	elif EventBus and EventBus.has_signal("player_sunk"):
		EventBus.player_sunk.emit()

	if is_instance_valid(active_arena):
		active_arena.queue_free()
		active_arena = null

	queue_free()
