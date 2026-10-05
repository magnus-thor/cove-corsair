@tool
class_name BoardingDefenseArena
extends Node3D

const PlayerBoardingRig = preload("res://src/features/boarding/rigs/player_boarding_rig.gd")
const EnemyBoardingRig = preload("res://src/features/boarding/rigs/enemy_boarding_rig.gd")

## Coordinates 3-zone deck defense encounters: parallel enemy approach,
## docking sequence, broadside camera framing, wave cadence, gangplank launches,
## swarm spawning, overrun hull penalties, and victory/defeat progression.
##
## Vessel layout and spatial nodes are provided by PlayerBoardingRig and
## EnemyBoardingRig scenes, authored visually per vessel.

signal encounter_won()
signal encounter_lost()
signal zone_status_updated(zone_id: String, pct: float, is_overrun: bool)
signal docking_completed()

const APPROACH_DURATION_SEC: float = 1.8

@export_category("Vessel Preview & Calibration (Editor Tool)")
@export_enum("sloop", "dinghy", "bombard_skiff", "ironclad") var preview_player_vessel: String = "sloop":
	set(value):
		preview_player_vessel = value
		if is_inside_tree():
			setup_player_vessel(preview_player_vessel)

@export_enum("war_barge", "bone_beard", "siege_fortress", "ghost_sloop") var preview_enemy_vessel: String = "war_barge":
	set(value):
		preview_enemy_vessel = value
		if is_inside_tree():
			setup_enemy_vessel(preview_enemy_vessel)

@export var show_editor_planks: bool = true:
	set(value):
		show_editor_planks = value
		if Engine.is_editor_hint():
			if show_editor_planks:
				_update_editor_preview_planks()
			else:
				_clear_editor_preview_planks()

@export var refresh_preview: bool = false:
	set(value):
		refresh_preview = false
		if Engine.is_editor_hint() and is_inside_tree():
			_rebuild_editor_preview()

@export var disable_enemies: bool = false:
	set(value):
		disable_enemies = value
		if disable_enemies and is_inside_tree():
			clear_all_boarders()

@export var deploy_test_planks: bool = false:
	set(value):
		deploy_test_planks = false
		if is_inside_tree():
			launch_plank_to_zone(0, 1, 0.0)
			launch_plank_to_zone(1, 1, 0.0)
			launch_plank_to_zone(2, 1, 0.0)

@export var clear_planks_and_enemies: bool = false:
	set(value):
		clear_planks_and_enemies = false
		if is_inside_tree():
			clear_all_planks_and_boarders()

@export_category("Boarding Rig Defaults")
@export var default_player_rig: PackedScene = preload("res://src/features/boarding/rigs/player/rig_sloop.tscn")
@export var default_enemy_rig: PackedScene = preload("res://src/features/boarding/rigs/enemy/rig_war_barge.tscn")

@export_category("Arena References & Gameplay")
@export var player_ship_container: Node3D = null
@export var enemy_ship_container: Node3D = null
@export var player_controller: DeckPlayerController = null
@export var hud: BoardingHUD = null
@export var boarding_camera: Camera3D = null
@export var targeting_system: DeckTargetingSystem = null

@export var plank_scene: PackedScene = preload("res://src/features/boarding/boarding_plank.tscn")
@export var boarder_scene: PackedScene = preload("res://src/features/boarding/boarder_enemy.tscn")
@export var boarder_raider_scene: PackedScene = preload("res://src/features/boarding/enemies/boarder_raider.tscn")
@export var boarder_brute_scene: PackedScene = preload("res://src/features/boarding/enemies/boarder_brute.tscn")
@export var splash_scene: PackedScene = preload("res://src/vfx/hit_splash.tscn")

@export var overrun_damage_per_sec: float = 5.0
@export var total_waves_to_win: int = 3
@export var wave_interval_sec: float = 8.0
@export var debug_disable_spawns: bool = false
@export var boss_tier: int = 0
@export var single_plank_mode: bool = false

# Active instantiated rigs
var player_rig: PlayerBoardingRig = null
var enemy_rig: EnemyBoardingRig = null

# Dynamic rig-backed getters for backwards compatibility & clean typing
var zone_bow: BoardingZone:
	get:
		return player_rig.zone_bow if is_instance_valid(player_rig) else null

var zone_midship: BoardingZone:
	get:
		return player_rig.zone_midship if is_instance_valid(player_rig) else null

var zone_stern: BoardingZone:
	get:
		return player_rig.zone_stern if is_instance_valid(player_rig) else null

var crew_station_bow: BoardingCrewStation:
	get:
		return player_rig.crew_station_bow if is_instance_valid(player_rig) else null

var crew_station_stern: BoardingCrewStation:
	get:
		return player_rig.crew_station_stern if is_instance_valid(player_rig) else null

var enemy_ship_marker_bow: Marker3D:
	get:
		return enemy_rig.plank_origin_bow if is_instance_valid(enemy_rig) else null

var enemy_ship_marker_mid: Marker3D:
	get:
		return enemy_rig.plank_origin_mid if is_instance_valid(enemy_rig) else null

var enemy_ship_marker_stern: Marker3D:
	get:
		return enemy_rig.plank_origin_stern if is_instance_valid(enemy_rig) else null

var zones: Array[BoardingZone] = []

var pending_player_vessel_id: String = ""
var pending_boss: Node3D = null

var current_wave: int = 0
var wave_timer: float = 3.0
var is_encounter_active: bool = true
var total_planks_launched: int = 0
var active_spawners_count: int = 0
var is_approaching: bool = true
var approach_tween: Tween = null
var target_dock_x: float = 13.323

var current_level_index: int = 1
var is_endless_encounter: bool = false
var endless_encounter_distance: float = 0.0

# Telemetry tracking counters
var encounter_start_time: float = 0.0
var encounter_active_boss_name: String = "Boss"
var encounter_player_vessel: String = "sloop"
var encounter_crew_role: String = ""
var encounter_mobs_spawned: int = 0
var encounter_mobs_killed: int = 0
var encounter_hull_damage_taken: float = 0.0
var encounter_end_reason: String = ""
var encounter_telemetry_started: bool = false
var encounter_telemetry_ended: bool = false

func _get_editor_scene_root() -> Node:
	if not Engine.is_editor_hint():
		return null
	if get_tree() and is_instance_valid(get_tree().edited_scene_root):
		return get_tree().edited_scene_root
	if is_instance_valid(owner):
		return owner
	return self

func _ready() -> void:
	# Check for pre-existing rig instances in scene
	if is_instance_valid(player_ship_container):
		var existing_p: PlayerBoardingRig = player_ship_container.get_node_or_null("PlayerBoardingRig") as PlayerBoardingRig
		if is_instance_valid(existing_p):
			_bind_player_rig(existing_p)

	if is_instance_valid(enemy_ship_container):
		var existing_e: EnemyBoardingRig = enemy_ship_container.get_node_or_null("EnemyBoardingRig") as EnemyBoardingRig
		if is_instance_valid(existing_e):
			_bind_enemy_rig(existing_e)

	if Engine.is_editor_hint():
		_rebuild_editor_preview()
		return

	if not show_editor_planks and not disable_enemies:
		_clear_editor_preview_planks()
	else:
		_update_editor_preview_planks()

	if is_instance_valid(hud):
		zone_status_updated.connect(hud.update_zone)
		encounter_won.connect(hud.show_victory)
		encounter_lost.connect(hud.show_defeat)
		hud.update_wave(1, total_waves_to_win)
		if is_instance_valid(player_controller):
			hud.special_attack_requested.connect(player_controller.fire_special_attack)
			player_controller.special_cooldown_updated.connect(hud.update_special_cooldown)
			player_controller.crew_role_changed.connect(hud.set_special_ability_name)
			hud.set_special_ability_name(player_controller.crew_role, player_controller.special_ability_name)

	if is_instance_valid(player_controller):
		player_controller.player_defeated.connect(_on_crew_defeated)

	if is_instance_valid(targeting_system) and is_instance_valid(boarding_camera):
		targeting_system.camera = boarding_camera

	_setup_camera()

	# Resolve player vessel rig
	# If in an active in-run game, use GameState/adapter. If standalone F6 preview, use preview_player_vessel!
	var p_vessel: String = pending_player_vessel_id
	if p_vessel.is_empty():
		if GameState and GameState.is_game_active and not str(GameState.active_vessel).is_empty():
			p_vessel = str(GameState.active_vessel)
		else:
			p_vessel = preview_player_vessel
	setup_player_vessel(p_vessel)

	# Resolve enemy vessel rig
	if is_instance_valid(pending_boss):
		setup_enemy_vessel(pending_boss)
	else:
		setup_enemy_vessel(preview_enemy_vessel)

	_start_approach_sequence()

func _setup_camera() -> void:
	if is_instance_valid(boarding_camera):
		if boarding_camera.rotation.is_zero_approx():
			boarding_camera.position = Vector3(-6.0, 3.2, 0.0)
			var look_target: Vector3 = Vector3(4.5, 2.0, 0.0)
			if is_instance_valid(player_ship_container):
				boarding_camera.look_at(player_ship_container.to_global(look_target), Vector3.UP)
			else:
				boarding_camera.look_at(global_position + look_target, Vector3.UP)
		boarding_camera.current = true
		boarding_camera.make_current()

func _get_player_rig_scene(v_key: String) -> PackedScene:
	if GameState and GameState.has_method("get_vessel_resource"):
		var ship_data: ShipData = GameState.get_vessel_resource(v_key)
		if is_instance_valid(ship_data) and is_instance_valid(ship_data.boarding_rig):
			return ship_data.boarding_rig

	match v_key:
		"sloop":
			return preload("res://src/features/boarding/rigs/player/rig_sloop.tscn")
		"dinghy":
			return preload("res://src/features/boarding/rigs/player/rig_dinghy.tscn")
		"bombard_skiff":
			return preload("res://src/features/boarding/rigs/player/rig_bombard_skiff.tscn")
		"ironclad":
			return preload("res://src/features/boarding/rigs/player/rig_ironclad.tscn")
		_:
			return default_player_rig

func _get_enemy_rig_scene(b_str: String) -> PackedScene:
	match b_str:
		"war_barge", "bosswarbarge":
			return preload("res://src/features/boarding/rigs/enemy/rig_war_barge.tscn")
		"bone_beard", "bossbonebeard":
			return preload("res://src/features/boarding/rigs/enemy/rig_bone_beard.tscn")
		"siege_fortress", "bosssiegefortress":
			return preload("res://src/features/boarding/rigs/enemy/rig_siege_fortress.tscn")
		"ghost_sloop", "phantom_dredge", "bossphantomdredge":
			return preload("res://src/features/boarding/rigs/enemy/rig_phantom_dredge.tscn")
		_:
			if b_str.contains("fortress"):
				return preload("res://src/features/boarding/rigs/enemy/rig_siege_fortress.tscn")
			elif b_str.contains("bone") or b_str.contains("twin"):
				return preload("res://src/features/boarding/rigs/enemy/rig_bone_beard.tscn")
			elif b_str.contains("ghost") or b_str.contains("dredge") or b_str.contains("phantom"):
				return preload("res://src/features/boarding/rigs/enemy/rig_phantom_dredge.tscn")
			return default_enemy_rig

func setup_player_vessel(vessel_id: String = "") -> void:
	var v_key: String = vessel_id.to_lower().strip_edges()
	if v_key.is_empty():
		v_key = preview_player_vessel
	encounter_player_vessel = v_key
	var rig_scene: PackedScene = _get_player_rig_scene(v_key)
	set_player_rig(rig_scene)

func setup_enemy_vessel(boss_or_name: Variant = null) -> void:
	if boss_or_name is Node3D:
		var boss_node: Node3D = boss_or_name as Node3D
		var scene: PackedScene = boss_node.get("boarding_rig") as PackedScene if "boarding_rig" in boss_node else null
		set_enemy_rig(scene if is_instance_valid(scene) else default_enemy_rig, String(boss_node.name))
		return

	var b_str: String = ""
	if boss_or_name != null:
		b_str = str(boss_or_name).to_lower().strip_edges()
	if b_str.is_empty():
		b_str = preview_enemy_vessel.to_lower().strip_edges()
	var scene: PackedScene = _get_enemy_rig_scene(b_str)
	var boss_display_name: String = str(boss_or_name) if (boss_or_name != null and not str(boss_or_name).is_empty()) else preview_enemy_vessel
	set_enemy_rig(scene if is_instance_valid(scene) else default_enemy_rig, boss_display_name)

func set_player_rig(scene: PackedScene) -> void:
	if not is_instance_valid(player_ship_container):
		return
	if not scene:
		scene = default_player_rig
	if not scene:
		return

	if is_instance_valid(player_rig) and player_rig.scene_file_path == scene.resource_path:
		return

	if is_instance_valid(player_rig):
		_unbind_player_rig()
		if Engine.is_editor_hint():
			player_rig.free()
		else:
			player_rig.queue_free()
		player_rig = null

	var inst: Node = scene.instantiate()
	if not (inst is PlayerBoardingRig):
		inst.queue_free()
		return

	player_rig = inst as PlayerBoardingRig
	player_rig.name = "PlayerBoardingRig"
	player_ship_container.add_child(player_rig)
	if Engine.is_editor_hint():
		var er: Node = _get_editor_scene_root()
		if er:
			player_rig.owner = er

	_bind_player_rig(player_rig)

func _bind_player_rig(rig: PlayerBoardingRig) -> void:
	player_rig = rig
	zones = player_rig.get_zones()
	for z: BoardingZone in zones:
		if is_instance_valid(z):
			z.add_to_group("boarding_zone")
			if not z.zone_overrun.is_connected(_on_zone_overrun):
				z.zone_overrun.connect(_on_zone_overrun)
			if not z.zone_cleared.is_connected(_on_zone_cleared):
				z.zone_cleared.connect(_on_zone_cleared)
			if not z.infestation_changed.is_connected(_on_zone_infestation_changed):
				z.infestation_changed.connect(_on_zone_infestation_changed)

	if is_instance_valid(player_controller):
		player_controller.station_markers = {
			"bow": zone_bow.station_marker if is_instance_valid(zone_bow) else null,
			"midship": zone_midship.station_marker if is_instance_valid(zone_midship) else null,
			"stern": zone_stern.station_marker if is_instance_valid(zone_stern) else null
		}
		if is_instance_valid(player_rig.player_spawn):
			player_controller.set_deck_anchor(player_rig.player_spawn.global_transform)

	if is_instance_valid(boarding_camera) and is_instance_valid(player_rig.camera_mount):
		boarding_camera.global_transform = player_rig.camera_mount.global_transform

	if not Engine.is_editor_hint():
		_setup_crew_from_gamestate()

	if show_editor_planks:
		_update_editor_preview_planks()

func _unbind_player_rig() -> void:
	if is_instance_valid(player_rig):
		for z: BoardingZone in zones:
			if is_instance_valid(z):
				if z.zone_overrun.is_connected(_on_zone_overrun):
					z.zone_overrun.disconnect(_on_zone_overrun)
				if z.zone_cleared.is_connected(_on_zone_cleared):
					z.zone_cleared.disconnect(_on_zone_cleared)
				if z.infestation_changed.is_connected(_on_zone_infestation_changed):
					z.infestation_changed.disconnect(_on_zone_infestation_changed)

func set_enemy_rig(scene: PackedScene, display_name: String = "") -> void:
	if not is_instance_valid(enemy_ship_container):
		return
	if not scene:
		scene = default_enemy_rig
	if not scene:
		return

	if is_instance_valid(enemy_rig) and enemy_rig.scene_file_path == scene.resource_path:
		if not display_name.is_empty():
			encounter_active_boss_name = display_name
		return

	if is_instance_valid(enemy_rig):
		if Engine.is_editor_hint():
			enemy_rig.free()
		else:
			enemy_rig.queue_free()
		enemy_rig = null

	var inst: Node = scene.instantiate()
	if not (inst is EnemyBoardingRig):
		inst.queue_free()
		return

	enemy_rig = inst as EnemyBoardingRig
	enemy_rig.name = "EnemyBoardingRig"
	enemy_ship_container.add_child(enemy_rig)
	if Engine.is_editor_hint():
		var er: Node = _get_editor_scene_root()
		if er:
			enemy_rig.owner = er

	_bind_enemy_rig(enemy_rig, display_name)

func _bind_enemy_rig(rig: EnemyBoardingRig, display_name: String = "") -> void:
	enemy_rig = rig
	target_dock_x = enemy_rig.dock_position.x
	enemy_ship_container.position.y = enemy_rig.dock_position.y
	enemy_ship_container.position.z = enemy_rig.dock_position.z

	if not display_name.is_empty():
		encounter_active_boss_name = display_name
	else:
		encounter_active_boss_name = enemy_rig.name

	if Engine.is_editor_hint():
		enemy_ship_container.position.x = target_dock_x
		if show_editor_planks:
			_update_editor_preview_planks()
	elif is_approaching:
		_start_approach_sequence()

func _rebuild_editor_preview() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	setup_player_vessel(preview_player_vessel)
	setup_enemy_vessel(preview_enemy_vessel)
	if show_editor_planks:
		_update_editor_preview_planks()

func _start_approach_sequence() -> void:
	if not is_instance_valid(enemy_ship_container):
		is_approaching = false
		_on_docking_complete()
		return

	if approach_tween and approach_tween.is_valid():
		approach_tween.kill()

	var dock_x: float = target_dock_x
	var start_x: float = maxf(dock_x + 8.0, 14.0)
	is_approaching = true
	enemy_ship_container.position.x = start_x

	var wake: GPUParticles3D = enemy_rig.wake if is_instance_valid(enemy_rig) else null
	if is_instance_valid(wake):
		wake.emitting = true

	approach_tween = create_tween()
	approach_tween.tween_property(enemy_ship_container, "position:x", dock_x, APPROACH_DURATION_SEC) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	approach_tween.tween_callback(_on_docking_complete)

func _on_docking_complete() -> void:
	is_approaching = false
	var wake: GPUParticles3D = enemy_rig.wake if is_instance_valid(enemy_rig) else null
	if is_instance_valid(wake):
		wake.emitting = false

	_trigger_docking_splash()
	docking_completed.emit()

	if show_editor_planks or disable_enemies:
		_update_editor_preview_planks()

	if debug_disable_spawns:
		return

	if is_encounter_active and current_wave == 0:
		_launch_initial_planks()

func _trigger_docking_splash() -> void:
	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("water_splashes", 0.9, 1.1)

	if splash_scene and is_instance_valid(enemy_ship_container):
		var splash_pos: Vector3 = enemy_ship_container.global_position + Vector3(-1.5, -0.42, 0.0)
		var splash: Node3D = splash_scene.instantiate() as Node3D
		add_child(splash)
		splash.global_position = splash_pos
		var p: GPUParticles3D = splash.find_child("SplashParticles", true, false) as GPUParticles3D
		if is_instance_valid(p):
			p.restart()
			p.emitting = true

func _launch_initial_planks() -> void:
	if not show_editor_planks and not disable_enemies:
		_clear_editor_preview_planks()
	current_wave = 1
	_emit_encounter_started()
	_launch_wave(current_wave)
	call_deferred("_select_initial_plank")
	wave_timer = wave_interval_sec

func _select_initial_plank() -> void:
	if is_instance_valid(zone_bow) and not zone_bow.active_planks.is_empty():
		var p: BoardingPlank = zone_bow.active_planks[0] as BoardingPlank
		if is_instance_valid(p) and is_instance_valid(player_controller):
			player_controller.select_plank(p)

func setup_encounter_difficulty(level_index: int, is_endless: bool = false, endless_distance: float = 0.0) -> void:
	current_level_index = level_index
	is_endless_encounter = is_endless
	endless_encounter_distance = endless_distance

	if is_endless:
		if endless_distance < 800.0:
			boss_tier = 1
			total_waves_to_win = 2
			wave_interval_sec = 8.5
			single_plank_mode = false
		elif endless_distance < 1600.0:
			boss_tier = 2
			total_waves_to_win = 3
			wave_interval_sec = 7.5
			single_plank_mode = false
		elif endless_distance < 2500.0:
			boss_tier = 3
			total_waves_to_win = 4
			wave_interval_sec = 6.5
			single_plank_mode = false
		else:
			boss_tier = 4
			total_waves_to_win = 5
			wave_interval_sec = 6.0
			single_plank_mode = false
	else:
		if level_index <= 15:
			boss_tier = 1
			total_waves_to_win = 2
			wave_interval_sec = 9.0
			single_plank_mode = false
		elif level_index <= 30:
			boss_tier = 2
			total_waves_to_win = 3
			wave_interval_sec = 8.0
			single_plank_mode = false
		else:
			boss_tier = 3
			total_waves_to_win = 4
			wave_interval_sec = 7.0
			single_plank_mode = false

	if is_instance_valid(hud):
		hud.update_wave(maxi(1, current_wave), total_waves_to_win)

func _emit_encounter_started() -> void:
	if encounter_telemetry_started:
		return
	encounter_telemetry_started = true
	encounter_start_time = float(Time.get_ticks_msec()) / 1000.0
	if EventBus and EventBus.has_signal("boarding_encounter_started"):
		EventBus.boarding_encounter_started.emit(
			encounter_active_boss_name,
			boss_tier,
			total_waves_to_win,
			encounter_player_vessel,
			encounter_crew_role
		)

func _emit_encounter_ended(outcome: String) -> void:
	if encounter_telemetry_ended:
		return
	encounter_telemetry_ended = true
	if not EventBus or not EventBus.has_signal("boarding_encounter_ended"):
		return
	var duration: float = (float(Time.get_ticks_msec()) / 1000.0) - encounter_start_time
	EventBus.boarding_encounter_ended.emit(
		encounter_active_boss_name,
		outcome,
		snappedf(duration, 0.1),
		current_wave,
		total_waves_to_win,
		encounter_mobs_killed,
		encounter_mobs_spawned,
		snappedf(encounter_hull_damage_taken, 0.1),
		encounter_end_reason
	)

func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if not is_instance_valid(boarding_camera):
		return

	if event is InputEventKey:
		var ke: InputEventKey = event as InputEventKey
		if ke.pressed and not ke.echo:
			if ke.keycode == KEY_H:
				disable_enemies = not disable_enemies
				if disable_enemies:
					clear_all_boarders()
				print("[BoardingArena] Enemies disabled: ", disable_enemies)

func clear_all_boarders() -> void:
	if not is_inside_tree():
		return
	var boarders: Array[Node] = get_tree().get_nodes_in_group("boarder")
	for b: Node in boarders:
		b.queue_free()

func clear_all_planks_and_boarders() -> void:
	var planks: Array[Node] = get_tree().get_nodes_in_group("boarding_plank")
	for p: Node in planks:
		p.queue_free()
	var legacy_ropes: Array[Node] = get_tree().get_nodes_in_group("grapple_rope")
	for r: Node in legacy_ropes:
		r.queue_free()
	clear_all_boarders()

func _update_editor_preview_planks() -> void:
	if not is_inside_tree():
		return

	var container: Node3D = get_node_or_null("EditorPreviewPlanks") as Node3D
	if not is_instance_valid(container):
		container = Node3D.new()
		container.name = "EditorPreviewPlanks"
		add_child(container)

	var active_zones: Array[BoardingZone] = zones
	if active_zones.is_empty():
		var fallback_zones: Array[BoardingZone] = []
		if is_instance_valid(zone_bow):
			fallback_zones.append(zone_bow)
		if is_instance_valid(zone_midship):
			fallback_zones.append(zone_midship)
		if is_instance_valid(zone_stern):
			fallback_zones.append(zone_stern)
		active_zones = fallback_zones

	for i: int in 3:
		var plank_name: String = "PreviewPlank_%d" % i
		var plank_mesh: MeshInstance3D = container.get_node_or_null(plank_name) as MeshInstance3D
		if not is_instance_valid(plank_mesh):
			plank_mesh = MeshInstance3D.new()
			plank_mesh.name = plank_name
			container.add_child(plank_mesh)

		var start_marker: Marker3D = _get_spawn_marker(i)
		var target_zone: BoardingZone = active_zones[i] if i < active_zones.size() else null

		if not is_instance_valid(start_marker) or not is_instance_valid(target_zone):
			plank_mesh.visible = false
			continue

		var target_anchor: Marker3D = target_zone.plank_anchor if is_instance_valid(target_zone.plank_anchor) else target_zone.grapple_anchor
		if not is_instance_valid(target_anchor):
			plank_mesh.visible = false
			continue

		var origin_pos: Vector3 = start_marker.global_position
		var target_pos: Vector3 = target_anchor.global_position
		var length: float = origin_pos.distance_to(target_pos)

		if length < 0.1:
			plank_mesh.visible = false
			continue

		var mid_pos: Vector3 = (origin_pos + target_pos) * 0.5
		plank_mesh.global_position = mid_pos

		var dir: Vector3 = (target_pos - origin_pos).normalized()
		var up: Vector3 = Vector3.UP
		if absf(dir.dot(up)) > 0.99:
			up = Vector3.FORWARD
		plank_mesh.look_at(target_pos, up)

		var box: BoxMesh = plank_mesh.mesh as BoxMesh
		if not is_instance_valid(box):
			box = BoxMesh.new()
			var mat: StandardMaterial3D = StandardMaterial3D.new()
			mat.albedo_color = Color(0.52, 0.35, 0.20, 1.0)
			mat.roughness = 0.85
			box.material = mat
			plank_mesh.mesh = box

		box.size = Vector3(0.41, 0.12, length)
		plank_mesh.visible = true

func _clear_editor_preview_planks() -> void:
	var container: Node = get_node_or_null("EditorPreviewPlanks")
	if is_instance_valid(container):
		if Engine.is_editor_hint():
			container.free()
		else:
			container.queue_free()

func _setup_crew_from_gamestate() -> void:
	var equipped_ids: Array[String] = []
	if GameState:
		var active_ship: String = GameState.active_vessel
		if GameState.equipped_crew.has(active_ship):
			var ship_map: Dictionary = GameState.equipped_crew.get(active_ship, {}) as Dictionary
			for socket_key: Variant in ship_map.keys():
				var cid: String = str(ship_map[socket_key]).strip_edges()
				if not cid.is_empty() and not equipped_ids.has(cid):
					equipped_ids.append(cid)

	if not equipped_ids.is_empty():
		var defender_crew_id: String = equipped_ids[0]
		if is_instance_valid(player_controller):
			player_controller.setup_defender_model(defender_crew_id)
			player_controller.visible = true
			encounter_crew_role = player_controller.crew_role
	else:
		if is_instance_valid(player_controller):
			player_controller.setup_defender_model("")
			encounter_crew_role = ""

	var cs_bow: BoardingCrewStation = crew_station_bow
	var cs_stern: BoardingCrewStation = crew_station_stern

	if is_instance_valid(cs_bow):
		if equipped_ids.size() >= 2:
			cs_bow.setup_crew(equipped_ids[1])
			cs_bow.visible = true
			cs_bow.set_process(true)
		else:
			cs_bow.visible = false
			cs_bow.set_process(false)
			var mc: Node = cs_bow.find_child("ModelContainer", true, false)
			if is_instance_valid(mc):
				for child: Node in mc.get_children():
					child.queue_free()

	if is_instance_valid(cs_stern):
		if equipped_ids.size() >= 3:
			cs_stern.setup_crew(equipped_ids[2])
			cs_stern.visible = true
			cs_stern.set_process(true)
		else:
			cs_stern.visible = false
			cs_stern.set_process(false)
			var mc: Node = cs_stern.find_child("ModelContainer", true, false)
			if is_instance_valid(mc):
				for child: Node in mc.get_children():
					child.queue_free()

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		if show_editor_planks:
			_update_editor_preview_planks()
		return

	if show_editor_planks or disable_enemies:
		_update_editor_preview_planks()

	if not is_encounter_active:
		return

	if is_instance_valid(boarding_camera) and not boarding_camera.is_current():
		boarding_camera.current = true
		boarding_camera.make_current()

	_process_overrun_attrition(delta)
	_process_wave_director(delta)

func apply_biome_visuals(biome_name: String) -> void:
	var b_lower: String = biome_name.to_lower()
	var ocean_node: MeshInstance3D = get_node_or_null("OceanPlane") as MeshInstance3D
	var ocean_mat: StandardMaterial3D = null
	if ocean_node:
		if ocean_node.material_override is StandardMaterial3D:
			ocean_mat = ocean_node.material_override as StandardMaterial3D
		elif ocean_node.mesh and ocean_node.mesh.surface_get_material(0) is StandardMaterial3D:
			ocean_mat = ocean_node.mesh.surface_get_material(0) as StandardMaterial3D

	if b_lower.contains("bayou") or b_lower.contains("black_tide"):
		if ocean_mat:
			ocean_mat.albedo_color = Color(0.12, 0.28, 0.22, 0.9)
	elif b_lower.contains("brimstone") or b_lower.contains("bastion"):
		if ocean_mat:
			ocean_mat.albedo_color = Color(0.18, 0.12, 0.15, 0.9)
	else:
		if ocean_mat:
			ocean_mat.albedo_color = Color(0.08, 0.38, 0.55, 0.85)

func _process_overrun_attrition(delta: float) -> void:
	if disable_enemies:
		return
	for zone: BoardingZone in zones:
		if is_instance_valid(zone) and zone.is_overrun:
			_damage_vessel_hull(overrun_damage_per_sec * delta)

func _process_wave_director(delta: float) -> void:
	if is_approaching or debug_disable_spawns or not is_encounter_active:
		return

	if current_wave < total_waves_to_win:
		wave_timer -= delta
		if wave_timer <= 0.0:
			current_wave += 1
			_launch_wave(current_wave)
			wave_timer = wave_interval_sec
	else:
		_check_victory_condition()

func _check_victory_condition() -> void:
	if not is_encounter_active:
		return
	if current_wave < total_waves_to_win or active_spawners_count > 0:
		return

	var living_boarders: int = 0
	for node: Node in get_tree().get_nodes_in_group("boarder"):
		var enemy: BoarderEnemy = node as BoarderEnemy
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion() and not enemy.is_dead and not enemy.is_falling:
			living_boarders += 1

	if living_boarders == 0:
		_trigger_victory()

func _launch_wave(wave_num: int) -> void:
	_emit_encounter_started()
	if is_instance_valid(hud):
		hud.update_wave(wave_num, total_waves_to_win)

	if boss_tier == 0:
		launch_plank_to_zone(0, wave_num, 0.0)
		launch_plank_to_zone(1, wave_num, 1.5)
		launch_plank_to_zone(2, wave_num, 3.0)
	elif boss_tier == 1 or single_plank_mode:
		if single_plank_mode:
			launch_plank_to_zone(0, wave_num, 0.0)
		elif wave_num <= 1:
			launch_plank_to_zone(0, wave_num, 0.0)
			launch_plank_to_zone(2, wave_num, 2.5)
		else:
			launch_plank_to_zone(0, wave_num, 0.0)
			launch_plank_to_zone(2, wave_num, 3.2)
	elif boss_tier == 2:
		match wave_num:
			1:
				launch_plank_to_zone(1, wave_num, 0.0)
			2:
				launch_plank_to_zone(0, wave_num, 0.0)
				launch_plank_to_zone(2, wave_num, 2.5)
			_:
				launch_plank_to_zone(0, wave_num, 0.0)
				launch_plank_to_zone(2, wave_num, 2.0)
	elif boss_tier == 3:
		match wave_num:
			1:
				launch_plank_to_zone(0, wave_num, 0.0)
				launch_plank_to_zone(1, wave_num, 1.5)
			2:
				launch_plank_to_zone(1, wave_num, 0.0)
				launch_plank_to_zone(2, wave_num, 1.2)
			3:
				launch_plank_to_zone(0, wave_num, 0.0)
				launch_plank_to_zone(1, wave_num, 1.5)
				launch_plank_to_zone(2, wave_num, 3.0)
			_:
				launch_plank_to_zone(0, wave_num, 0.0)
				launch_plank_to_zone(1, wave_num, 1.0)
				launch_plank_to_zone(2, wave_num, 2.0)
	else:
		match wave_num:
			1:
				launch_plank_to_zone(0, wave_num, 0.0)
				launch_plank_to_zone(2, wave_num, 1.5)
			2:
				launch_plank_to_zone(1, wave_num, 0.0)
				launch_plank_to_zone(2, wave_num, 1.2)
			3:
				launch_plank_to_zone(0, wave_num, 0.0)
				launch_plank_to_zone(1, wave_num, 1.2)
				launch_plank_to_zone(2, wave_num, 2.4)
			4:
				launch_plank_to_zone(0, wave_num, 0.0)
				launch_plank_to_zone(1, wave_num, 0.8)
				launch_plank_to_zone(2, wave_num, 1.6)
			_:
				launch_plank_to_zone(0, wave_num, 0.0)
				launch_plank_to_zone(1, wave_num, 0.5)
				launch_plank_to_zone(2, wave_num, 1.0)

func launch_plank_to_zone(zone_index: int, wave_num: int = 1, spawn_delay_sec: float = 0.0) -> void:
	if debug_disable_spawns:
		return

	if zones.is_empty():
		return

	var idx: int = clampi(zone_index, 0, zones.size() - 1)
	var target_zone: BoardingZone = zones[idx]
	var start_marker: Marker3D = _get_spawn_marker(idx)

	if not is_instance_valid(plank_scene) or not is_instance_valid(start_marker) or not is_instance_valid(target_zone):
		return

	var existing_plank: BoardingPlank = null
	for p: Node3D in target_zone.active_planks:
		if is_instance_valid(p) and p is BoardingPlank and (p as BoardingPlank).is_latched:
			existing_plank = p as BoardingPlank
			break

	var count: int = _get_swarm_count_for_tier(wave_num)
	if is_instance_valid(existing_plank):
		_spawn_plank_swarm(existing_plank, target_zone, count, wave_num, spawn_delay_sec)
		return

	var plank: BoardingPlank = plank_scene.instantiate() as BoardingPlank
	add_child(plank)
	var anchor_pos: Vector3 = target_zone.plank_anchor.global_position if is_instance_valid(target_zone.plank_anchor) else target_zone.grapple_anchor.global_position
	plank.setup_plank(start_marker.global_position, anchor_pos, target_zone)
	total_planks_launched += 1

	_spawn_plank_swarm(plank, target_zone, count, wave_num, spawn_delay_sec)

func _get_swarm_count_for_tier(wave_num: int) -> int:
	if boss_tier <= 1 or single_plank_mode:
		if wave_num <= 1:
			return 1
		return 2
	elif boss_tier == 2:
		if wave_num <= 1:
			return 2
		return 2
	elif boss_tier == 3:
		if wave_num <= 2:
			return 2
		return 3
	else:
		if wave_num <= 2:
			return 2
		return 3

func _spawn_plank_swarm(plank: BoardingPlank, zone: BoardingZone, count: int, wave_num: int = 1, initial_delay_sec: float = 0.0) -> void:
	if disable_enemies or debug_disable_spawns:
		return
	active_spawners_count += 1
	if initial_delay_sec > 0.0:
		await get_tree().create_timer(initial_delay_sec).timeout

	var breach_z_val: float = player_rig.get_breach_z(6.2) if is_instance_valid(player_rig) else 6.2

	for i: int in count:
		if i > 0:
			await get_tree().create_timer(1.35).timeout
		if not is_instance_valid(plank) or not plank.is_latched or not is_encounter_active:
			break
		var chosen_scene: PackedScene = _get_enemy_scene_for_swarm(wave_num, i)
		if not is_instance_valid(chosen_scene):
			chosen_scene = boarder_scene
		if not is_instance_valid(chosen_scene):
			break
		encounter_mobs_spawned += 1
		var enemy: BoarderEnemy = chosen_scene.instantiate() as BoarderEnemy
		add_child(enemy)
		if boss_tier <= 1 or single_plank_mode:
			enemy.max_hp = 18.0
			enemy.current_hp = 18.0
			enemy.attack_damage = 3.5
			enemy.cross_speed_mult = 0.85
			enemy.deck_wander_speed = 0.85
			enemy.breach_z = breach_z_val
		elif boss_tier == 2:
			enemy.max_hp = 26.0
			enemy.current_hp = 26.0
			enemy.attack_damage = 4.5
			enemy.cross_speed_mult = 0.95
			enemy.deck_wander_speed = 0.95
			enemy.breach_z = breach_z_val
		elif boss_tier == 3:
			enemy.max_hp = 34.0
			enemy.current_hp = 34.0
			enemy.attack_damage = 6.0
			enemy.cross_speed_mult = 1.05
			enemy.deck_wander_speed = 1.05
			enemy.breach_z = breach_z_val
		else:
			enemy.max_hp = 42.0
			enemy.current_hp = 42.0
			enemy.attack_damage = 7.5
			enemy.cross_speed_mult = 1.15
			enemy.deck_wander_speed = 1.15
			enemy.breach_z = breach_z_val
		enemy.breached_stern.connect(_on_enemy_breached_stern)
		enemy.tree_exited.connect(_on_enemy_removed)
		if enemy.has_signal("died"):
			enemy.died.connect(_on_enemy_died)
		enemy.start_crossing(plank, zone)

	active_spawners_count = maxi(0, active_spawners_count - 1)
	_check_victory_condition()

func _on_enemy_died(_enemy: BoarderEnemy = null) -> void:
	encounter_mobs_killed += 1
	call_deferred("_check_victory_condition")

func _on_enemy_removed() -> void:
	call_deferred("_check_victory_condition")

func _on_enemy_breached_stern(_enemy: BoarderEnemy) -> void:
	if not is_encounter_active:
		return
	is_encounter_active = false
	encounter_end_reason = "stern_breached"
	_emit_encounter_ended("DEFEAT")
	if is_instance_valid(hud):
		hud.show_defeat("STERN BREACHED! GAME OVER")
	encounter_lost.emit()
	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("barrel_breaks", 0.9, 1.1)

func _on_crew_defeated() -> void:
	if not is_encounter_active:
		return
	is_encounter_active = false
	encounter_end_reason = "crew_defeated"
	_emit_encounter_ended("DEFEAT")
	if is_instance_valid(hud):
		hud.show_defeat("CREW MEMBER DEFEATED!")
	encounter_lost.emit()
	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("barrel_breaks", 0.9, 1.1)

func _get_enemy_scene_for_swarm(wave_num: int, swarm_index: int) -> PackedScene:
	var raider_scn: PackedScene = boarder_raider_scene if is_instance_valid(boarder_raider_scene) else boarder_scene
	var brute_scn: PackedScene = boarder_brute_scene if is_instance_valid(boarder_brute_scene) else boarder_scene

	if boss_tier <= 1:
		return raider_scn

	if boss_tier == 2:
		match wave_num:
			1:
				return raider_scn
			2:
				if swarm_index >= 1:
					return brute_scn
				return raider_scn
			_:
				if swarm_index >= 1:
					return brute_scn
				return raider_scn

	match wave_num:
		1:
			return raider_scn
		2:
			if swarm_index >= 1:
				return brute_scn
			return raider_scn
		_:
			if swarm_index % 2 == 1:
				return brute_scn
			return raider_scn

func _damage_vessel_hull(amount: float) -> void:
	encounter_hull_damage_taken += amount
	var player: PlayerSwerve = get_tree().get_first_node_in_group("player") as PlayerSwerve
	if is_instance_valid(player):
		player.take_hit(maxi(1, int(round(amount))), "boarding_overrun")
	elif GameState:
		GameState.record_hit()
		if EventBus and EventBus.has_signal("player_hit_taken"):
			EventBus.player_hit_taken.emit(maxi(1, int(round(amount))), 1, 4, "boarding_overrun", 0.0)

func _get_spawn_marker(zone_index: int) -> Marker3D:
	if is_instance_valid(enemy_rig):
		return enemy_rig.get_plank_origin(zone_index)
	return null

func _on_zone_overrun(zone_id: String) -> void:
	zone_status_updated.emit(zone_id, 1.0, true)

func _on_zone_cleared(zone_id: String) -> void:
	zone_status_updated.emit(zone_id, 0.0, false)

func _on_zone_infestation_changed(zone_id: String, pct: float) -> void:
	zone_status_updated.emit(zone_id, pct, pct >= 1.0)

func _trigger_victory() -> void:
	if not is_encounter_active:
		return
	is_encounter_active = false
	encounter_end_reason = "cleared"
	_emit_encounter_ended("VICTORY")
	if is_instance_valid(hud):
		hud.show_victory()
	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("gate_passes", 1.0, 1.2)
	var tw: Tween = create_tween()
	tw.tween_interval(1.8)
	tw.tween_callback(func() -> void:
		encounter_won.emit()
	)

func _trigger_defeat() -> void:
	if not is_encounter_active:
		return
	is_encounter_active = false
	if encounter_end_reason.is_empty():
		encounter_end_reason = "defeated"
	_emit_encounter_ended("DEFEAT")
	encounter_lost.emit()
