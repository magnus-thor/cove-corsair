@tool
class_name BoardingDefenseArena
extends Node3D

## Coordinates 3-zone deck defense encounters: parallel enemy approach,
## docking sequence, broadside camera framing, wave cadence, grapple launches,
## swarm spawning, overrun hull penalties, and victory/defeat progression.

signal encounter_won()
signal encounter_lost()
signal zone_status_updated(zone_id: String, pct: float, is_overrun: bool)
signal docking_completed()

const DECK_ELEVATION_Y: float = 0.48
const ENEMY_START_OFFSET_X: float = 14.0
const ENEMY_DOCK_OFFSET_X: float = 4.5
const APPROACH_DURATION_SEC: float = 1.8

const PLAYER_VESSEL_CONFIGS: Dictionary = {
	"sloop": {
		"path": "res://assets/models/user/vessels/the_sloop.glb",
		"position": Vector3(0.0, 0.0054335, 0.0),
		"rotation_degrees": Vector3(0.0, 90.0, 0.0),
		"scale": Vector3(1.655, 1.655, 1.655),
		"rail_offset_x": 0.0
	},
	"dinghy": {
		"path": "res://assets/models/user/vessels/dinghy.glb",
		"position": Vector3(-0.35, 0.15, -0.2),
		"rotation_degrees": Vector3(0.0, 0.0, 0.0),
		"scale": Vector3(3.8, 3.8, 3.8),
		"rail_offset_x": -0.25
	},
	"bombard_skiff": {
		"path": "res://assets/models/user/vessels/the_bombard_skiff.glb",
		"position": Vector3(0.05, 0.05, -0.1),
		"rotation_degrees": Vector3(0.0, -90.0, 0.0),
		"scale": Vector3(2.6, 2.6, 2.6),
		"rail_offset_x": 0.25
	},
	"ironclad": {
		"path": "res://assets/models/user/vessels/the_ironclad.glb",
		"position": Vector3(0.1, 0.05, 0.0),
		"rotation_degrees": Vector3(0.0, -90.0, 0.0),
		"scale": Vector3(1.85, 1.85, 1.85),
		"rail_offset_x": 0.35
	}
}

const ENEMY_VESSEL_CONFIGS: Dictionary = {
	"war_barge": {
		"path": "res://assets/models/enemy/vessels/boss_war_barge.glb",
		"position": Vector3(-11.516914, -0.38194555, 0.17183109),
		"rotation_degrees": Vector3(0.0, 95.10, 0.0),
		"scale": Vector3(3.52, 3.52, 3.52),
		"marker_bow": Vector3(-13.068624, 1.1870035, -1.8804607),
		"marker_mid": Vector3(-12.614456, 0.26471028, -0.17524332),
		"marker_stern": Vector3(-12.687212, 0.40418908, 0.4926853),
		"dock_x": 13.323
	},
	"bone_beard": {
		"path": "res://assets/models/enemy/vessels/captain_bone-beard’s_twin_frigate.glb",
		"position": Vector3(-11.5, 0.25, 0.0),
		"rotation_degrees": Vector3(0.0, 180.0, 0.0),
		"scale": Vector3(4.2, 4.2, 4.2),
		"marker_bow": Vector3(-13.1, 0.55, -1.85),
		"marker_mid": Vector3(-13.1, 0.50, -0.05),
		"marker_stern": Vector3(-13.1, 0.55, 0.65),
		"dock_x": 13.32
	},
	"siege_fortress": {
		"path": "res://assets/models/enemy/vessels/boss_siege_fortress.glb",
		"position": Vector3(-11.4, 0.20, 0.0),
		"rotation_degrees": Vector3(0.0, 180.0, 0.0),
		"scale": Vector3(4.2, 4.2, 4.2),
		"marker_bow": Vector3(-13.2, 0.65, -1.90),
		"marker_mid": Vector3(-13.15, 0.60, -0.05),
		"marker_stern": Vector3(-13.2, 0.65, 0.70),
		"dock_x": 13.5
	},
	"ghost_sloop": {
		"path": "res://assets/models/enemy/vessels/ghost_sloop.glb",
		"position": Vector3(-11.5, 0.35, 0.0),
		"rotation_degrees": Vector3(0.0, 180.0, 0.0),
		"scale": Vector3(4.8, 4.8, 4.8),
		"marker_bow": Vector3(-12.8, 0.60, -1.80),
		"marker_mid": Vector3(-12.7, 0.55, -0.05),
		"marker_stern": Vector3(-12.8, 0.60, 0.60),
		"dock_x": 13.32
	}
}

static func get_config_transform(cfg: Dictionary) -> Transform3D:
	if cfg.has("transform") and cfg["transform"] is Transform3D:
		return cfg["transform"] as Transform3D
	var pos: Vector3 = cfg.get("position", Vector3.ZERO) as Vector3
	var rot_deg: Vector3 = cfg.get("rotation_degrees", Vector3.ZERO) as Vector3
	var sc: Vector3 = cfg.get("scale", Vector3.ONE) as Vector3
	var rot_rad: Vector3 = Vector3(deg_to_rad(rot_deg.x), deg_to_rad(rot_deg.y), deg_to_rad(rot_deg.z))
	var basis: Basis = Basis.from_euler(rot_rad).scaled(sc)
	return Transform3D(basis, pos)

@export_category("Vessel Preview & Calibration (Editor Tool)")
@export_enum("sloop", "dinghy", "bombard_skiff", "ironclad") var preview_player_vessel: String = "sloop":
	set(value):
		preview_player_vessel = value
		if Engine.is_editor_hint() and is_node_ready():
			setup_player_vessel(preview_player_vessel)

@export_enum("war_barge", "bone_beard", "siege_fortress", "ghost_sloop") var preview_enemy_vessel: String = "war_barge":
	set(value):
		preview_enemy_vessel = value
		if Engine.is_editor_hint() and is_node_ready():
			setup_enemy_vessel(preview_enemy_vessel)

@export var sync_editor_preview: bool = false:
	set(value):
		sync_editor_preview = false
		if Engine.is_editor_hint() and is_node_ready():
			var old_p: Node = player_ship_container.find_child("PlayerShipVisual", true, false) if is_instance_valid(player_ship_container) else null
			if is_instance_valid(old_p):
				old_p.free()
			var old_e: Node = enemy_ship_container.find_child("EnemyShipVisual", true, false) if is_instance_valid(enemy_ship_container) else null
			if is_instance_valid(old_e):
				old_e.free()
			setup_player_vessel(preview_player_vessel)
			setup_enemy_vessel(preview_enemy_vessel)
			print("[BoardingArena Tool] Refreshed preview models and markers.")

@export var print_current_transforms: bool = false:
	set(value):
		print_current_transforms = false
		_print_current_vessel_transforms()

@export var apply_transforms_to_in_memory_config: bool = false:
	set(value):
		apply_transforms_to_in_memory_config = false
		_apply_current_transforms_to_config()

@export var show_editor_planks: bool = true:
	set(value):
		show_editor_planks = value
		if Engine.is_editor_hint():
			if show_editor_planks:
				_update_editor_preview_planks()
			else:
				_clear_editor_preview_planks()

@export var disable_enemies: bool = false:
	set(value):
		disable_enemies = value
		if disable_enemies and is_inside_tree():
			clear_all_boarders()

@export var deploy_test_planks: bool = false:
	set(value):
		deploy_test_planks = false
		if is_inside_tree():
			if zones.is_empty():
				zones = [zone_bow, zone_midship, zone_stern]
			launch_plank_to_zone(0, 1, 0.0)
			launch_plank_to_zone(1, 1, 0.0)
			launch_plank_to_zone(2, 1, 0.0)

@export var clear_planks_and_enemies: bool = false:
	set(value):
		clear_planks_and_enemies = false
		if is_inside_tree():
			clear_all_planks_and_boarders()

@export_category("Arena References & Gameplay")


@export var zone_bow: BoardingZone = null
@export var zone_midship: BoardingZone = null
@export var zone_stern: BoardingZone = null

@export var crew_station_bow: BoardingCrewStation = null
@export var crew_station_stern: BoardingCrewStation = null

@export var player_controller: DeckPlayerController = null

@export var enemy_ship_marker_bow: Marker3D = null
@export var enemy_ship_marker_mid: Marker3D = null
@export var enemy_ship_marker_stern: Marker3D = null

@export var hud: BoardingHUD = null
@export var boarding_camera: Camera3D = null
@export var player_ship_container: Node3D = null
@export var enemy_ship_container: Node3D = null
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
@export var boss_tier: int = 0 # 0 = default/test broadside, 1 = Level 15 (1 plank), 2 = Level 30 (2 planks), 3 = Level 45 (3 planks)
@export var single_plank_mode: bool = false

var zones: Array[BoardingZone] = []
var current_wave: int = 0
var wave_timer: float = 3.0 # Initial grace period
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

func _get_editor_scene_root() -> Node:
	if not Engine.is_editor_hint():
		return null
	if get_tree() and is_instance_valid(get_tree().edited_scene_root):
		return get_tree().edited_scene_root
	if is_instance_valid(owner):
		return owner
	return self

func _editor_sync_vessels() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	setup_player_vessel(preview_player_vessel)
	setup_enemy_vessel(preview_enemy_vessel)
	if show_editor_planks:
		_update_editor_preview_planks()

func _ready() -> void:
	zones = [zone_bow, zone_midship, zone_stern]
	if Engine.is_editor_hint():
		call_deferred("_editor_sync_vessels")
		return
	_clear_editor_preview_planks()
	for zone: BoardingZone in zones:
		if is_instance_valid(zone):
			zone.add_to_group("boarding_zone")
			zone.zone_overrun.connect(_on_zone_overrun)
			zone.zone_cleared.connect(_on_zone_cleared)
			zone.infestation_changed.connect(_on_zone_infestation_changed)
			
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
		player_controller.station_markers = {
			"bow": zone_bow.station_marker if is_instance_valid(zone_bow) else null,
			"midship": zone_midship.station_marker if is_instance_valid(zone_midship) else null,
			"stern": zone_stern.station_marker if is_instance_valid(zone_stern) else null
		}
			
	if is_instance_valid(targeting_system) and is_instance_valid(boarding_camera):
		targeting_system.camera = boarding_camera

	if is_instance_valid(player_ship_container):
		var deck_mesh: MeshInstance3D = player_ship_container.find_child("DeckMesh", true, false) as MeshInstance3D
		if is_instance_valid(deck_mesh):
			deck_mesh.visible = false

	# _setup_deck_elevation()
	_setup_camera()
	_setup_crew_from_gamestate()
	var current_vessel: String = preview_player_vessel
	if GameState and "active_vessel" in GameState and not str(GameState.active_vessel).is_empty():
		current_vessel = str(GameState.active_vessel)
	setup_player_vessel(current_vessel)

	var current_enemy: String = preview_enemy_vessel
	setup_enemy_vessel(current_enemy)

	_start_approach_sequence()

# func _setup_deck_elevation() -> void:
# 	# Ensure explicit baseline offset (Y >= +0.45m) for ships and crew
# 	if is_instance_valid(player_ship_container) and player_ship_container.position.y < DECK_ELEVATION_Y:
# 		player_ship_container.position.y = DECK_ELEVATION_Y
# 	if is_instance_valid(enemy_ship_container) and enemy_ship_container.position.y < DECK_ELEVATION_Y:
# 		enemy_ship_container.position.y = DECK_ELEVATION_Y
		
# 	if is_instance_valid(crew_station_bow):
# 		crew_station_bow.position.y = DECK_ELEVATION_Y
# 	if is_instance_valid(crew_station_stern):
# 		crew_station_stern.position.y = DECK_ELEVATION_Y
# 	if is_instance_valid(player_controller):
# 		player_controller.position.y = DECK_ELEVATION_Y
# 		player_controller.target_station_position.y = DECK_ELEVATION_Y
		
# 	for zone: BoardingZone in zones:
# 		if is_instance_valid(zone):
# 			zone.position.y = DECK_ELEVATION_Y

func _setup_camera() -> void:
	if is_instance_valid(boarding_camera):
		# If user has not authored camera rotation (i.e. zero), configure default look-at
		if boarding_camera.rotation.is_zero_approx():
			boarding_camera.position = Vector3(-6.0, 3.2, 0.0)
			var look_target: Vector3 = Vector3(4.5, 2.0, 0.0)
			if is_instance_valid(player_ship_container):
				boarding_camera.look_at(player_ship_container.to_global(look_target), Vector3.UP)
			else:
				boarding_camera.look_at(global_position + look_target, Vector3.UP)
		boarding_camera.current = true
		boarding_camera.make_current()

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
	
	var wake: GPUParticles3D = enemy_ship_container.find_child("EnemyBoatWake", true, false) as GPUParticles3D
	if is_instance_valid(wake):
		wake.emitting = true
		
	approach_tween = create_tween()
	approach_tween.tween_property(enemy_ship_container, "position:x", dock_x, APPROACH_DURATION_SEC) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	approach_tween.tween_callback(_on_docking_complete)

func _on_docking_complete() -> void:
	is_approaching = false
	if is_instance_valid(enemy_ship_container):
		var wake: GPUParticles3D = enemy_ship_container.find_child("EnemyBoatWake", true, false) as GPUParticles3D
		if is_instance_valid(wake):
			wake.emitting = false
			
	_trigger_docking_splash()
	docking_completed.emit()
	
	if debug_disable_spawns:
		return
		
	# Only AFTER enemy completes approach, deploy the 3 boarding planks onto player railing
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

func setup_player_vessel(vessel_id: String = "") -> void:
	if not is_instance_valid(player_ship_container):
		return
	var v_key: String = vessel_id.to_lower().strip_edges()
	if v_key.is_empty() or not PLAYER_VESSEL_CONFIGS.has(v_key):
		v_key = "sloop"
	encounter_player_vessel = v_key
		
	var cfg: Dictionary = PLAYER_VESSEL_CONFIGS[v_key] as Dictionary
	var glb_path: String = str(cfg.get("path", "res://assets/models/user/vessels/the_sloop.glb"))
	if not ResourceLoader.exists(glb_path):
		return

	var old_model: Node = player_ship_container.find_child("PlayerShipVisual", true, false)
	var needs_reload: bool = true
	if is_instance_valid(old_model):
		if old_model.scene_file_path == glb_path:
			needs_reload = false
			var old_node3d: Node3D = old_model as Node3D
			if is_instance_valid(old_node3d):
				old_node3d.transform = get_config_transform(cfg)
		else:
			if Engine.is_editor_hint():
				old_model.free()
			else:
				old_model.queue_free()

	if needs_reload:
		var scene: PackedScene = load(glb_path) as PackedScene
		if scene:
			var inst: Node3D = scene.instantiate() as Node3D
			inst.name = "PlayerShipVisual"
			inst.transform = get_config_transform(cfg)
			player_ship_container.add_child(inst)
			var editor_root: Node = _get_editor_scene_root()
			if editor_root:
				inst.owner = editor_root

			if v_key == "dinghy":
				var mask_res: String = "res://assets/models/user/vessels/dinghy_cockpit_mask.tres"
				if ResourceLoader.exists(mask_res):
					var mask: MeshInstance3D = MeshInstance3D.new()
					mask.name = "CockpitWaterMask"
					mask.mesh = load(mask_res) as Mesh
					inst.add_child(mask)
					if editor_root:
						mask.owner = editor_root

	var target_zones: Array[BoardingZone] = zones if not zones.is_empty() else [zone_bow, zone_midship, zone_stern]
	var rail_offset: float = float(cfg.get("rail_offset_x", 0.0))
	for z: BoardingZone in target_zones:
		if is_instance_valid(z) and is_instance_valid(z.plank_anchor):
			z.plank_anchor.position.x = 2.0 + rail_offset

func setup_enemy_vessel(boss_name: String = "") -> void:
	if not is_instance_valid(enemy_ship_container):
		return
	var b_lower: String = boss_name.to_lower().strip_edges()
	var boss_key: String = "war_barge"
	if ENEMY_VESSEL_CONFIGS.has(b_lower):
		boss_key = b_lower
	elif b_lower.contains("fortress"):
		boss_key = "siege_fortress"
	elif b_lower.contains("phantom") or b_lower.contains("dredge") or b_lower.contains("ghost"):
		boss_key = "ghost_sloop"
	elif b_lower.contains("bone") or b_lower.contains("twin"):
		boss_key = "bone_beard"

	encounter_active_boss_name = boss_name if not boss_name.is_empty() else boss_key

	var cfg: Dictionary = ENEMY_VESSEL_CONFIGS.get(boss_key, ENEMY_VESSEL_CONFIGS["war_barge"]) as Dictionary
	var glb_path: String = str(cfg.get("path", ""))
	
	if ResourceLoader.exists(glb_path):
		var old_model: Node = enemy_ship_container.find_child("EnemyShipVisual", true, false)
		var needs_reload: bool = true
		if is_instance_valid(old_model):
			if old_model.scene_file_path == glb_path:
				needs_reload = false
				var old_node3d: Node3D = old_model as Node3D
				if is_instance_valid(old_node3d):
					old_node3d.transform = get_config_transform(cfg)
			else:
				if Engine.is_editor_hint():
					old_model.free()
				else:
					old_model.queue_free()

		if needs_reload:
			var scene: PackedScene = load(glb_path) as PackedScene
			if scene:
				var inst: Node3D = scene.instantiate() as Node3D
				inst.name = "EnemyShipVisual"
				inst.transform = get_config_transform(cfg)
				enemy_ship_container.add_child(inst)
				var editor_root: Node = _get_editor_scene_root()
				if editor_root:
					inst.owner = editor_root

	if is_instance_valid(enemy_ship_marker_bow) and cfg.has("marker_bow"):
		enemy_ship_marker_bow.position = cfg.get("marker_bow") as Vector3
	if is_instance_valid(enemy_ship_marker_mid) and cfg.has("marker_mid"):
		enemy_ship_marker_mid.position = cfg.get("marker_mid") as Vector3
	if is_instance_valid(enemy_ship_marker_stern) and cfg.has("marker_stern"):
		enemy_ship_marker_stern.position = cfg.get("marker_stern") as Vector3

	if cfg.has("dock_x"):
		target_dock_x = float(cfg.get("dock_x", 13.323))
		if Engine.is_editor_hint():
			enemy_ship_container.position.x = target_dock_x
		elif is_approaching:
			_start_approach_sequence()

func _print_current_vessel_transforms() -> void:
	print("\n================================================================================")
	print("  CURRENT BOARDING ARENA VESSEL CONFIGURATION")
	print("================================================================================")
	
	if is_instance_valid(player_ship_container):
		var p_vis: Node3D = player_ship_container.find_child("PlayerShipVisual", true, false) as Node3D
		if is_instance_valid(p_vis):
			var pos: Vector3 = p_vis.position
			var rot: Vector3 = p_vis.rotation_degrees
			var sc: Vector3 = p_vis.scale
			var rail_off: float = 0.0
			if is_instance_valid(zone_bow) and is_instance_valid(zone_bow.plank_anchor):
				rail_off = zone_bow.plank_anchor.position.x - 2.0
			var p_path: String = ""
			if PLAYER_VESSEL_CONFIGS.has(preview_player_vessel):
				var p_dict: Dictionary = PLAYER_VESSEL_CONFIGS[preview_player_vessel] as Dictionary
				p_path = str(p_dict.get("path", ""))
			
			print("--- PLAYER VESSEL ('%s') ---" % preview_player_vessel)
			print("\t\"%s\": {" % preview_player_vessel)
			print("\t\t\"path\": \"%s\"," % p_path)
			print("\t\t\"position\": Vector3(%.4f, %.4f, %.4f)," % [pos.x, pos.y, pos.z])
			print("\t\t\"rotation_degrees\": Vector3(%.2f, %.2f, %.2f)," % [rot.x, rot.y, rot.z])
			print("\t\t\"scale\": Vector3(%.4f, %.4f, %.4f)," % [sc.x, sc.y, sc.z])
			print("\t\t\"rail_offset_x\": %.2f" % rail_off)
			print("\t},")
	
	if is_instance_valid(enemy_ship_container):
		var e_vis: Node3D = enemy_ship_container.find_child("EnemyShipVisual", true, false) as Node3D
		if is_instance_valid(e_vis):
			var pos: Vector3 = e_vis.position
			var rot: Vector3 = e_vis.rotation_degrees
			var sc: Vector3 = e_vis.scale
			var m_bow: Vector3 = enemy_ship_marker_bow.position if is_instance_valid(enemy_ship_marker_bow) else Vector3.ZERO
			var m_mid: Vector3 = enemy_ship_marker_mid.position if is_instance_valid(enemy_ship_marker_mid) else Vector3.ZERO
			var m_stern: Vector3 = enemy_ship_marker_stern.position if is_instance_valid(enemy_ship_marker_stern) else Vector3.ZERO
			var dock: float = target_dock_x
			var e_path: String = ""
			if ENEMY_VESSEL_CONFIGS.has(preview_enemy_vessel):
				var e_dict: Dictionary = ENEMY_VESSEL_CONFIGS[preview_enemy_vessel] as Dictionary
				e_path = str(e_dict.get("path", ""))
			
			print("\n--- ENEMY VESSEL ('%s') ---" % preview_enemy_vessel)
			print("\t\"%s\": {" % preview_enemy_vessel)
			print("\t\t\"path\": \"%s\"," % e_path)
			print("\t\t\"position\": Vector3(%.4f, %.4f, %.4f)," % [pos.x, pos.y, pos.z])
			print("\t\t\"rotation_degrees\": Vector3(%.2f, %.2f, %.2f)," % [rot.x, rot.y, rot.z])
			print("\t\t\"scale\": Vector3(%.4f, %.4f, %.4f)," % [sc.x, sc.y, sc.z])
			print("\t\t\"marker_bow\": Vector3(%.4f, %.4f, %.4f)," % [m_bow.x, m_bow.y, m_bow.z])
			print("\t\t\"marker_mid\": Vector3(%.4f, %.4f, %.4f)," % [m_mid.x, m_mid.y, m_mid.z])
			print("\t\t\"marker_stern\": Vector3(%.4f, %.4f, %.4f)," % [m_stern.x, m_stern.y, m_stern.z])
			print("\t\t\"dock_x\": %.3f" % dock)
			print("\t}")
	print("================================================================================\n")

func _apply_current_transforms_to_config() -> void:
	if is_instance_valid(player_ship_container):
		var p_vis: Node3D = player_ship_container.find_child("PlayerShipVisual", true, false) as Node3D
		if is_instance_valid(p_vis) and PLAYER_VESSEL_CONFIGS.has(preview_player_vessel):
			var p_cfg: Dictionary = PLAYER_VESSEL_CONFIGS[preview_player_vessel] as Dictionary
			p_cfg["position"] = p_vis.position
			p_cfg["rotation_degrees"] = p_vis.rotation_degrees
			p_cfg["scale"] = p_vis.scale
			if is_instance_valid(zone_bow) and is_instance_valid(zone_bow.plank_anchor):
				p_cfg["rail_offset_x"] = zone_bow.plank_anchor.position.x - 2.0
			print("[BoardingArena Tool] Updated in-memory config for player vessel: '%s'" % preview_player_vessel)
			
	if is_instance_valid(enemy_ship_container):
		var e_vis: Node3D = enemy_ship_container.find_child("EnemyShipVisual", true, false) as Node3D
		if is_instance_valid(e_vis) and ENEMY_VESSEL_CONFIGS.has(preview_enemy_vessel):
			var e_cfg: Dictionary = ENEMY_VESSEL_CONFIGS[preview_enemy_vessel] as Dictionary
			e_cfg["position"] = e_vis.position
			e_cfg["rotation_degrees"] = e_vis.rotation_degrees
			e_cfg["scale"] = e_vis.scale
			if is_instance_valid(enemy_ship_marker_bow):
				e_cfg["marker_bow"] = enemy_ship_marker_bow.position
			if is_instance_valid(enemy_ship_marker_mid):
				e_cfg["marker_mid"] = enemy_ship_marker_mid.position
			if is_instance_valid(enemy_ship_marker_stern):
				e_cfg["marker_stern"] = enemy_ship_marker_stern.position
			print("[BoardingArena Tool] Updated in-memory config for enemy vessel: '%s'" % preview_enemy_vessel)

func _update_editor_preview_planks() -> void:
	if not is_inside_tree():
		return
	
	var container: Node3D = get_node_or_null("EditorPreviewPlanks") as Node3D
	if not is_instance_valid(container):
		container = Node3D.new()
		container.name = "EditorPreviewPlanks"
		add_child(container)
	
	var active_zones: Array[BoardingZone] = zones if not zones.is_empty() else [zone_bow, zone_midship, zone_stern]
	
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
			mat.albedo_color = Color(0.52, 0.35, 0.20, 1.0) # Weathered oak plank
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

	# 1. Primary defender is the equipped crew member
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

	# 2. Automated crew stations: ONLY active if additional equipped crew exist!
	# Unequipped crew members are never spawned.
	if is_instance_valid(crew_station_bow):
		if equipped_ids.size() >= 2:
			crew_station_bow.setup_crew(equipped_ids[1])
			crew_station_bow.visible = true
			crew_station_bow.set_process(true)
		else:
			crew_station_bow.visible = false
			crew_station_bow.set_process(false)
			var mc: Node = crew_station_bow.find_child("ModelContainer", true, false)
			if is_instance_valid(mc):
				for child: Node in mc.get_children():
					child.queue_free()

	if is_instance_valid(crew_station_stern):
		if equipped_ids.size() >= 3:
			crew_station_stern.setup_crew(equipped_ids[2])
			crew_station_stern.visible = true
			crew_station_stern.set_process(true)
		else:
			crew_station_stern.visible = false
			crew_station_stern.set_process(false)
			var mc: Node = crew_station_stern.find_child("ModelContainer", true, false)
			if is_instance_valid(mc):
				for child: Node in mc.get_children():
					child.queue_free()

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		if show_editor_planks:
			_update_editor_preview_planks()
		return
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
		# Default / Test Broadside: launch 3 planks into Bow, Midship, Stern
		launch_plank_to_zone(0, wave_num, 0.0)
		launch_plank_to_zone(1, wave_num, 1.5)
		launch_plank_to_zone(2, wave_num, 3.0)
	elif boss_tier == 1 or single_plank_mode:
		# Tier 1 (War Barge / L1-15): 2 waves
		if single_plank_mode:
			launch_plank_to_zone(0, wave_num, 0.0)
		elif wave_num <= 1:
			launch_plank_to_zone(0, wave_num, 0.0)
			launch_plank_to_zone(2, wave_num, 2.5)
		else:
			launch_plank_to_zone(0, wave_num, 0.0)
			launch_plank_to_zone(2, wave_num, 3.2)
	elif boss_tier == 2:
		# Tier 2 (Captain Bone-Beard / L16-30): 3 waves
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
		# Tier 3 (Siege Fortress / Phantom Dredge / L31-45): 4 waves
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
		# Tier 4 (Endless Nightmare / 5 waves)
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

	var idx: int = clampi(zone_index, 0, zones.size() - 1)
	var target_zone: BoardingZone = zones[idx]
	var start_marker: Marker3D = _get_spawn_marker(idx)
	
	if not is_instance_valid(plank_scene) or not is_instance_valid(start_marker) or not is_instance_valid(target_zone):
		return
		
	# If zone already has an active latched plank, reuse it for the new swarm instead of duplicating
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
			enemy.breach_z = 6.2
		elif boss_tier == 2:
			enemy.max_hp = 26.0
			enemy.current_hp = 26.0
			enemy.attack_damage = 4.5
			enemy.cross_speed_mult = 0.95
			enemy.deck_wander_speed = 0.95
			enemy.breach_z = 6.2
		elif boss_tier == 3:
			enemy.max_hp = 34.0
			enemy.current_hp = 34.0
			enemy.attack_damage = 6.0
			enemy.cross_speed_mult = 1.05
			enemy.deck_wander_speed = 1.05
			enemy.breach_z = 6.2
		else:
			enemy.max_hp = 42.0
			enemy.current_hp = 42.0
			enemy.attack_damage = 7.5
			enemy.cross_speed_mult = 1.15
			enemy.deck_wander_speed = 1.15
			enemy.breach_z = 6.2
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

	# Boss Tier 1 only uses the frontline pirate raider!
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

	# Tier 3 and 4:
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
	match zone_index:
		0: return enemy_ship_marker_bow
		1: return enemy_ship_marker_mid
		2: return enemy_ship_marker_stern
		_: return enemy_ship_marker_mid

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
