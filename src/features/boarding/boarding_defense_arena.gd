@tool
class_name BoardingDefenseArena
extends Node3D

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
		print("[BoardingArena] preview_player_vessel setter: ", value)
		preview_player_vessel = value
		if is_instance_valid(player_ship_container):
			setup_player_vessel(preview_player_vessel)

@export_enum("war_barge", "bone_beard", "siege_fortress", "ghost_sloop") var preview_enemy_vessel: String = "war_barge":
	set(value):
		print("[BoardingArena] preview_enemy_vessel setter: ", value)
		preview_enemy_vessel = value
		if is_instance_valid(enemy_ship_container):
			setup_enemy_vessel(preview_enemy_vessel)

@export_enum("monkey_bomber", "skeleton_tosser", "grease_monkey", "deckhand_sniper", "none") var preview_defender_crew: String = "monkey_bomber":
	set(value):
		preview_defender_crew = value
		if is_inside_tree():
			if Engine.is_editor_hint():
				_update_editor_preview_crew()
			else:
				_setup_crew_from_gamestate()

@export var show_editor_planks: bool = true:
	set(value):
		show_editor_planks = value
		if Engine.is_editor_hint():
			if show_editor_planks:
				_update_editor_preview_planks()
			else:
				_clear_editor_preview_planks()

@export_range(0.2, 3.0, 0.05) var plank_width: float = 0.41:
	set(value):
		plank_width = value
		if is_inside_tree() and Engine.is_editor_hint():
			_update_editor_preview_planks()

@export_range(0.02, 1.0, 0.02) var plank_thickness: float = 0.12:
	set(value):
		plank_thickness = value
		if is_inside_tree() and Engine.is_editor_hint():
			_update_editor_preview_planks()

@export var refresh_preview: bool = false:
	set(_value):
		refresh_preview = false
		if Engine.is_editor_hint() and is_inside_tree():
			_rebuild_editor_preview()

@export var disable_enemies: bool = false:
	set(value):
		disable_enemies = value
		if disable_enemies and is_inside_tree():
			clear_all_boarders()

@export var deploy_test_planks: bool = false:
	set(_value):
		deploy_test_planks = false
		if is_inside_tree():
			launch_plank_to_zone(0, 1, 0.0)
			launch_plank_to_zone(1, 1, 0.0)
			launch_plank_to_zone(2, 1, 0.0)

@export var clear_planks_and_enemies: bool = false:
	set(_value):
		clear_planks_and_enemies = false
		if is_inside_tree():
			clear_all_planks_and_boarders()

@export_group("Layout Overrides")
## When true, BoardingCamera3D snaps to the rig's CameraMount.
## When false (default), BoardingCamera3D keeps the transform authored in BoardingDefenseArena.
@export var use_rig_camera_mount: bool = false:
	set(value):
		use_rig_camera_mount = value
		if Engine.is_editor_hint() and is_inside_tree() and use_rig_camera_mount:
			if is_instance_valid(boarding_camera) and is_instance_valid(player_rig) and is_instance_valid(player_rig.camera_mount):
				boarding_camera.global_transform = player_rig.camera_mount.global_transform

## When true (default), EnemyShipContainer always docks using the vehicle's saved dock_position.
@export var use_rig_dock_position: bool = true:
	set(value):
		use_rig_dock_position = value
		if Engine.is_editor_hint() and is_inside_tree() and use_rig_dock_position:
			if is_instance_valid(enemy_ship_container) and is_instance_valid(enemy_rig):
				target_dock_x = enemy_rig.dock_position.x
				enemy_ship_container.position = enemy_rig.dock_position
				enemy_ship_container.rotation = Vector3.ZERO

## When true, in-game boarding runs will force the selected preview_enemy_vessel for live testing.
@export var debug_force_preview_enemy_vessel: bool = false

@export_group("Vessel Calibration & Persistence")
## Saves current enemy rig transforms (dock_position, MarkerBow, MarkerMid, MarkerStern, wake, model)
## directly into that vessel's authoritative .tscn file on disk (res://src/features/boarding/rigs/enemy/rig_<vessel>.tscn).
@export var save_current_enemy_vessel_data: bool = false:
	set(_value):
		save_current_enemy_vessel_data = false
		if is_inside_tree():
			save_active_enemy_rig_to_disk()

## Reloads the active enemy vessel rig fresh from disk, discarding any unsaved local tweaks.
@export var reload_active_vessel_from_disk: bool = false:
	set(_value):
		reload_active_vessel_from_disk = false
		if is_inside_tree():
			reload_active_enemy_rig()

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
var boss_hp_threat_pct: float = 0.15

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
	if is_instance_valid(owner):
		return owner
	return self

func _get_game_state() -> Node:
	if Engine.is_editor_hint():
		return null
	if is_inside_tree() and get_tree() and get_tree().root:
		return get_tree().root.get_node_or_null("GameState")
	return null

func _get_audio_manager() -> Node:
	if Engine.is_editor_hint():
		return null
	if is_inside_tree() and get_tree() and get_tree().root:
		return get_tree().root.get_node_or_null("AudioManager")
	return null

func _get_event_bus() -> Node:
	if Engine.is_editor_hint():
		return null
	if is_inside_tree() and get_tree() and get_tree().root:
		return get_tree().root.get_node_or_null("EventBus")
	return null

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

	_clear_editor_preview_crew()

	if not show_editor_planks and not disable_enemies:
		_clear_editor_preview_planks()
	else:
		_update_editor_preview_planks()

	if is_instance_valid(hud):
		if not zone_status_updated.is_connected(hud.update_zone):
			zone_status_updated.connect(hud.update_zone)
		if not encounter_won.is_connected(hud.show_victory):
			encounter_won.connect(hud.show_victory)
		if not encounter_lost.is_connected(hud.show_defeat):
			encounter_lost.connect(hud.show_defeat)
		hud.update_wave(1, total_waves_to_win)
		if is_instance_valid(player_controller):
			if not hud.special_attack_requested.is_connected(player_controller.fire_special_attack):
				hud.special_attack_requested.connect(player_controller.fire_special_attack)
			if not player_controller.special_cooldown_updated.is_connected(hud.update_special_cooldown):
				player_controller.special_cooldown_updated.connect(hud.update_special_cooldown)
			if not player_controller.crew_role_changed.is_connected(hud.set_special_ability_name):
				player_controller.crew_role_changed.connect(hud.set_special_ability_name)
			hud.set_special_ability_name(player_controller.crew_role, player_controller.special_ability_name)

	if is_instance_valid(player_controller):
		if not player_controller.player_defeated.is_connected(_on_crew_defeated):
			player_controller.player_defeated.connect(_on_crew_defeated)

	if is_instance_valid(targeting_system) and is_instance_valid(boarding_camera):
		targeting_system.camera = boarding_camera

	_setup_camera()

	# Resolve player vessel rig
	# If in an active in-run game, use GameState/adapter. If standalone F6 preview, use preview_player_vessel!
	var p_vessel: String = pending_player_vessel_id
	if p_vessel.is_empty():
		var gs: Node = _get_game_state()
		if not Engine.is_editor_hint() and gs and gs.get("is_game_active") and not str(gs.get("active_vessel")).is_empty():
			p_vessel = str(gs.get("active_vessel"))
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
		if not Engine.is_editor_hint():
			boarding_camera.current = true
			boarding_camera.make_current()

func _get_player_rig_scene(v_key: String) -> PackedScene:
	if not Engine.is_editor_hint():
		var gs: Node = _get_game_state()
		if gs and gs.has_method("get_vessel_resource"):
			var ship_data: ShipData = gs.call("get_vessel_resource", v_key) as ShipData
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
	if debug_force_preview_enemy_vessel:
		var scene: PackedScene = _get_enemy_rig_scene(preview_enemy_vessel.to_lower().strip_edges())
		set_enemy_rig(scene if is_instance_valid(scene) else default_enemy_rig, preview_enemy_vessel)
		return

	if boss_or_name is Node3D:
		var boss_node: Node3D = boss_or_name as Node3D
		var boss_rig_scene: PackedScene = boss_node.get("boarding_rig") as PackedScene if "boarding_rig" in boss_node else null
		set_enemy_rig(boss_rig_scene if is_instance_valid(boss_rig_scene) else default_enemy_rig, String(boss_node.name))
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

	# Clear any existing PlayerBoardingRig from container
	for child: Node in player_ship_container.get_children():
		if child is PlayerBoardingRig or child.name.begins_with("PlayerBoardingRig"):
			_unbind_player_rig()
			if child.get_parent():
				child.get_parent().remove_child(child)
			child.queue_free()
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
	if not Engine.is_editor_hint():
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

	if use_rig_camera_mount and is_instance_valid(boarding_camera) and is_instance_valid(player_rig.camera_mount):
		boarding_camera.global_transform = player_rig.camera_mount.global_transform

	if not Engine.is_editor_hint():
		_setup_crew_from_gamestate()

	if show_editor_planks:
		_update_editor_preview_planks()

func _unbind_player_rig() -> void:
	if is_instance_valid(player_rig) and not Engine.is_editor_hint():
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

	# Clear any existing EnemyBoardingRig from container
	for child: Node in enemy_ship_container.get_children():
		if child is EnemyBoardingRig or child.name.begins_with("EnemyBoardingRig"):
			if child.get_parent():
				child.get_parent().remove_child(child)
			child.queue_free()
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
	enemy_ship_container.rotation = Vector3.ZERO

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
	if use_rig_camera_mount and is_instance_valid(boarding_camera) and is_instance_valid(player_rig) and is_instance_valid(player_rig.camera_mount):
		boarding_camera.global_transform = player_rig.camera_mount.global_transform
	if is_instance_valid(enemy_ship_container) and is_instance_valid(enemy_rig):
		enemy_ship_container.position = enemy_rig.dock_position
		enemy_ship_container.rotation = Vector3.ZERO
	if show_editor_planks:
		_update_editor_preview_planks()
	_update_editor_preview_crew()

func _start_approach_sequence() -> void:
	if not is_instance_valid(enemy_ship_container) or not is_instance_valid(enemy_rig):
		is_approaching = false
		_on_docking_complete()
		return

	if approach_tween and approach_tween.is_valid():
		approach_tween.kill()

	var dock_x: float = target_dock_x
	var start_x: float = maxf(dock_x + 8.0, 14.0)
	is_approaching = true
	enemy_ship_container.position.x = start_x
	enemy_ship_container.position.y = enemy_rig.dock_position.y
	enemy_ship_container.position.z = enemy_rig.dock_position.z
	enemy_ship_container.rotation = Vector3.ZERO

	var wake: GPUParticles3D = enemy_rig.wake if is_instance_valid(enemy_rig) else null
	if is_instance_valid(wake):
		wake.emitting = true

	approach_tween = create_tween()
	approach_tween.tween_property(enemy_ship_container, "position:x", dock_x, APPROACH_DURATION_SEC) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	approach_tween.tween_callback(_on_docking_complete)

func _on_docking_complete() -> void:
	is_approaching = false
	if is_instance_valid(enemy_ship_container) and is_instance_valid(enemy_rig):
		enemy_ship_container.position = enemy_rig.dock_position
		enemy_ship_container.rotation = Vector3.ZERO

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

func get_enemy_rig_path(v_key: String) -> String:
	match v_key.to_lower().strip_edges():
		"war_barge", "bosswarbarge":
			return "res://src/features/boarding/rigs/enemy/rig_war_barge.tscn"
		"bone_beard", "bossbonebeard":
			return "res://src/features/boarding/rigs/enemy/rig_bone_beard.tscn"
		"siege_fortress", "bosssiegefortress":
			return "res://src/features/boarding/rigs/enemy/rig_siege_fortress.tscn"
		"ghost_sloop", "phantom_dredge", "bossphantomdredge":
			return "res://src/features/boarding/rigs/enemy/rig_phantom_dredge.tscn"
		_:
			if v_key.contains("fortress"):
				return "res://src/features/boarding/rigs/enemy/rig_siege_fortress.tscn"
			elif v_key.contains("bone") or v_key.contains("twin"):
				return "res://src/features/boarding/rigs/enemy/rig_bone_beard.tscn"
			elif v_key.contains("ghost") or v_key.contains("dredge") or v_key.contains("phantom"):
				return "res://src/features/boarding/rigs/enemy/rig_phantom_dredge.tscn"
			return "res://src/features/boarding/rigs/enemy/rig_war_barge.tscn"

func save_active_enemy_rig_to_disk() -> void:
	if not is_instance_valid(enemy_rig):
		push_error("[BoardingArena] Cannot save vessel data: enemy_rig is null or invalid.")
		return

	var v_key: String = preview_enemy_vessel.to_lower().strip_edges()
	var rig_path: String = get_enemy_rig_path(v_key)
	if not FileAccess.file_exists(rig_path):
		push_error("[BoardingArena] Target rig file not found: %s" % rig_path)
		return

	var read_file: FileAccess = FileAccess.open(rig_path, FileAccess.READ)
	if not read_file:
		push_error("[BoardingArena] Failed to open %s for reading." % rig_path)
		return
	var content: String = read_file.get_as_text()
	read_file.close()

	var dock_pos: Vector3 = enemy_rig.dock_position
	var bow_t: Transform3D = enemy_rig.plank_origin_bow.transform if is_instance_valid(enemy_rig.plank_origin_bow) else Transform3D.IDENTITY
	var mid_t: Transform3D = enemy_rig.plank_origin_mid.transform if is_instance_valid(enemy_rig.plank_origin_mid) else Transform3D.IDENTITY
	var stern_t: Transform3D = enemy_rig.plank_origin_stern.transform if is_instance_valid(enemy_rig.plank_origin_stern) else Transform3D.IDENTITY
	var wake_t: Transform3D = enemy_rig.wake.transform if is_instance_valid(enemy_rig.wake) else Transform3D.IDENTITY
	var model_node: Node3D = enemy_rig.get_node_or_null("Model") as Node3D
	var model_t: Transform3D = model_node.transform if is_instance_valid(model_node) else Transform3D.IDENTITY

	var updated_text: String = _update_rig_tscn_text(content, dock_pos, bow_t, mid_t, stern_t, wake_t, model_t)

	var write_file: FileAccess = FileAccess.open(rig_path, FileAccess.WRITE)
	if not write_file:
		push_error("[BoardingArena] Failed to open %s for writing." % rig_path)
		return
	write_file.store_string(updated_text)
	write_file.close()

	print("[BoardingArena] SUCCESS: Calibrated numbers saved to '%s' for '%s':" % [rig_path, v_key])
	print("  dock_position = %s" % [var_to_str(dock_pos)])
	print("  MarkerBow     = %s" % [var_to_str(bow_t.origin)])
	print("  MarkerMid     = %s" % [var_to_str(mid_t.origin)])
	print("  MarkerStern   = %s" % [var_to_str(stern_t.origin)])
	print("  Model         = %s" % [var_to_str(model_t.origin)])

func reload_active_enemy_rig() -> void:
	if not is_instance_valid(enemy_ship_container):
		return
	for child: Node in enemy_ship_container.get_children():
		if child is EnemyBoardingRig or child.name.begins_with("EnemyBoardingRig"):
			enemy_ship_container.remove_child(child)
			child.queue_free()
	enemy_rig = null
	setup_enemy_vessel(preview_enemy_vessel)
	print("[BoardingArena] Reloaded '%s' rig cleanly from disk." % preview_enemy_vessel)

func _update_rig_tscn_text(
	text: String,
	dock_pos: Vector3,
	bow_t: Transform3D,
	mid_t: Transform3D,
	stern_t: Transform3D,
	wake_t: Transform3D,
	model_t: Transform3D
) -> String:
	var lines: PackedStringArray = text.split("\n")
	var result: PackedStringArray = []
	var current_node: String = ""

	for line: String in lines:
		var trimmed: String = line.strip_edges()
		if trimmed.begins_with("[node name=\""):
			var start_idx: int = trimmed.find("\"") + 1
			var end_idx: int = trimmed.find("\"", start_idx)
			current_node = trimmed.substr(start_idx, end_idx - start_idx)
			result.append(line)
			continue
		elif trimmed.begins_with("["):
			current_node = ""
			result.append(line)
			continue

		var replaced: bool = false
		match current_node:
			"EnemyBoardingRig":
				if trimmed.begins_with("dock_position ="):
					result.append("dock_position = " + var_to_str(dock_pos))
					replaced = true
			"MarkerBow":
				if trimmed.begins_with("transform ="):
					result.append("transform = " + var_to_str(bow_t))
					replaced = true
			"MarkerMid":
				if trimmed.begins_with("transform ="):
					result.append("transform = " + var_to_str(mid_t))
					replaced = true
			"MarkerStern":
				if trimmed.begins_with("transform ="):
					result.append("transform = " + var_to_str(stern_t))
					replaced = true
			"EnemyBoatWake":
				if trimmed.begins_with("transform ="):
					result.append("transform = " + var_to_str(wake_t))
					replaced = true
			"Model":
				if trimmed.begins_with("transform ="):
					result.append("transform = " + var_to_str(model_t))
					replaced = true

		if not replaced:
			result.append(line)

	return "\n".join(result)

func _trigger_docking_splash() -> void:
	var audio: Node = _get_audio_manager()
	if audio and audio.has_method("play_sfx"):
		audio.call("play_sfx", "water_splashes", 0.9, 1.1)

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

func setup_encounter_difficulty(level_index: int, is_endless: bool = false, endless_distance: float = 0.0, boss_hp_pct: float = -1.0) -> void:
	current_level_index = level_index
	is_endless_encounter = is_endless
	endless_encounter_distance = endless_distance
	if boss_hp_pct >= 0.0:
		boss_hp_threat_pct = clampf(boss_hp_pct, 0.01, 0.15)
	else:
		boss_hp_threat_pct = 0.05

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

		# If explicit HP % provided from in-run boss:
		if boss_hp_pct >= 0.0:
			if boss_hp_threat_pct <= 0.05:
				total_waves_to_win = 2
				wave_interval_sec = 8.5
			elif boss_hp_threat_pct <= 0.09:
				total_waves_to_win = 3
				wave_interval_sec = 7.5
			else:
				total_waves_to_win = 4
				wave_interval_sec = 6.0

	if is_instance_valid(hud):
		hud.update_wave(maxi(1, current_wave), total_waves_to_win)

func _emit_encounter_started() -> void:
	if encounter_telemetry_started:
		return
	encounter_telemetry_started = true
	encounter_start_time = float(Time.get_ticks_msec()) / 1000.0
	var eb: Node = _get_event_bus()
	if eb and eb.has_signal("boarding_encounter_started"):
		eb.emit_signal("boarding_encounter_started",
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
	var eb: Node = _get_event_bus()
	if not eb or not eb.has_signal("boarding_encounter_ended"):
		return
	var duration: float = (float(Time.get_ticks_msec()) / 1000.0) - encounter_start_time
	eb.emit_signal("boarding_encounter_ended",
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

		if not plank_mesh.is_inside_tree():
			continue

		var start_marker: Marker3D = _get_spawn_marker(i)
		var target_zone: BoardingZone = active_zones[i] if i < active_zones.size() else null

		if not is_instance_valid(start_marker) or not is_instance_valid(target_zone):
			plank_mesh.visible = false
			continue

		var target_anchor: Marker3D = target_zone.plank_anchor if is_instance_valid(target_zone.plank_anchor) else target_zone.grapple_anchor
		if not is_instance_valid(target_anchor):
			plank_mesh.visible = false
			continue

		if not start_marker.is_inside_tree() or not target_anchor.is_inside_tree():
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

		box.size = Vector3(plank_width, plank_thickness, length)
		plank_mesh.visible = true

func _clear_editor_preview_planks() -> void:
	var container: Node = get_node_or_null("EditorPreviewPlanks")
	if is_instance_valid(container):
		if Engine.is_editor_hint():
			container.free()
		else:
			container.queue_free()
const CREW_SCALE_MULTIPLIERS: Dictionary = {
	"monkey_bomber": 1.0,
	"skeleton_tosser": 1.90,
	"grease_monkey": 1.13,
	"deckhand_sniper": 1.0
}
const CREW_OFFSETS: Dictionary = {
	"monkey_bomber": Vector3.ZERO,
	"skeleton_tosser": Vector3.ZERO,
	"grease_monkey": Vector3.ZERO,
	"deckhand_sniper": Vector3.ZERO
}
@export var custom_crew_offsets: Dictionary = {}

func _update_editor_preview_crew() -> void:
	if not is_inside_tree() or not Engine.is_editor_hint():
		return

	var container: Node3D = get_node_or_null("EditorPreviewCrew") as Node3D
	if preview_defender_crew.is_empty() or preview_defender_crew == "none":
		if is_instance_valid(container):
			container.free()
		return

	if not is_instance_valid(container):
		container = Node3D.new()
		container.name = "EditorPreviewCrew"
		add_child(container)

	var glb_path: String = _get_crew_model_path(preview_defender_crew)
	if glb_path.is_empty() or not ResourceLoader.exists(glb_path):
		return

	var defender_node: Node3D = container.get_node_or_null("PreviewDefender") as Node3D
	var current_path: String = String(defender_node.get_meta("glb_path", "")) if is_instance_valid(defender_node) else ""
	if not is_instance_valid(defender_node) or current_path != glb_path:
		if is_instance_valid(defender_node):
			defender_node.free()
		var scene: PackedScene = load(glb_path) as PackedScene
		if scene:
			defender_node = scene.instantiate() as Node3D
			defender_node.name = "PreviewDefender"
			defender_node.set_meta("glb_path", glb_path)
			container.add_child(defender_node)

	if is_instance_valid(defender_node):
		var target_scale: Vector3 = Vector3(0.15, 0.15, 0.15)
		if is_instance_valid(player_controller):
			target_scale = player_controller.crew_scale
			if not player_controller.scale.is_zero_approx():
				target_scale = Vector3(target_scale.x * player_controller.scale.x, target_scale.y * player_controller.scale.y, target_scale.z * player_controller.scale.z)

		var mult: float = float(CREW_SCALE_MULTIPLIERS.get(preview_defender_crew, 1.0))
		target_scale *= mult

		var target_pos: Vector3 = Vector3.ZERO
		var target_rot_y: float = PI
		if is_instance_valid(player_rig) and is_instance_valid(player_rig.player_spawn):
			target_pos = player_rig.player_spawn.global_position
			target_rot_y = player_rig.player_spawn.global_rotation.y
		elif is_instance_valid(player_ship_container):
			target_pos = player_ship_container.global_position + Vector3(0.15, 0.28, -0.02)

		var offset: Vector3 = CREW_OFFSETS.get(preview_defender_crew, Vector3.ZERO) as Vector3
		if custom_crew_offsets != null and custom_crew_offsets.has(preview_defender_crew):
			offset += custom_crew_offsets[preview_defender_crew] as Vector3

		defender_node.scale = target_scale
		var foot_drop: float = -(0.238 - 0.952251 * defender_node.scale.y)
		defender_node.global_position = target_pos + offset + Vector3(0.0, foot_drop, 0.0)
		defender_node.rotation.y = target_rot_y

func _get_crew_model_path(cid: String) -> String:
	match cid:
		"monkey_bomber":
			return "res://assets/models/user/crew/monkey_crew.glb"
		"skeleton_tosser":
			return "res://assets/models/user/crew/skeleton_crew.glb"
		"grease_monkey":
			return "res://assets/models/user/crew/artillery_grease__monkey.glb"
		"deckhand_sniper":
			return "res://assets/models/user/crew/weapon_deckhand_sniper.glb"
		_:
			return "res://assets/models/user/crew/monkey_crew.glb"

func _clear_editor_preview_crew() -> void:
	var container: Node = get_node_or_null("EditorPreviewCrew")
	if is_instance_valid(container):
		if Engine.is_editor_hint():
			container.free()
		else:
			container.queue_free()

func _setup_crew_from_gamestate() -> void:
	if Engine.is_editor_hint():
		return
	var equipped_ids: Array[String] = []
	var gs: Node = _get_game_state()
	if gs:
		var active_ship: String = str(gs.get("active_vessel"))
		var eq_crew: Variant = gs.get("equipped_crew")
		if eq_crew is Dictionary and (eq_crew as Dictionary).has(active_ship):
			var ship_map: Dictionary = (eq_crew as Dictionary).get(active_ship, {}) as Dictionary
			for socket_key: Variant in ship_map.keys():
				var cid: String = str(ship_map[socket_key]).strip_edges()
				if not cid.is_empty() and not equipped_ids.has(cid):
					equipped_ids.append(cid)

	# Fallback to preview_defender_crew for standalone testing or cinematic preview
	if equipped_ids.is_empty() and not preview_defender_crew.is_empty() and preview_defender_crew != "none":
		equipped_ids.append(preview_defender_crew)

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
		_update_editor_preview_crew()
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
	plank.plank_width = plank_width
	plank.plank_thickness = plank_thickness
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
	var audio: Node = _get_audio_manager()
	if audio and audio.has_method("play_sfx"):
		audio.call("play_sfx", "barrel_breaks", 0.9, 1.1)

func _on_crew_defeated() -> void:
	if not is_encounter_active:
		return
	is_encounter_active = false
	encounter_end_reason = "crew_defeated"
	_emit_encounter_ended("DEFEAT")
	if is_instance_valid(hud):
		hud.show_defeat("CREW MEMBER DEFEATED!")
	encounter_lost.emit()
	var audio: Node = _get_audio_manager()
	if audio and audio.has_method("play_sfx"):
		audio.call("play_sfx", "barrel_breaks", 0.9, 1.1)

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
	elif not Engine.is_editor_hint():
		var gs: Node = _get_game_state()
		if gs and gs.has_method("record_hit"):
			gs.call("record_hit")
		var eb: Node = _get_event_bus()
		if eb and eb.has_signal("player_hit_taken"):
			eb.emit_signal("player_hit_taken", maxi(1, int(round(amount))), 1, 4, "boarding_overrun", 0.0)

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
	var audio: Node = _get_audio_manager()
	if audio and audio.has_method("play_sfx"):
		audio.call("play_sfx", "gate_passes", 1.0, 1.2)
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
