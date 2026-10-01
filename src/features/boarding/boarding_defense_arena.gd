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
		"transform": Transform3D(-7.234234e-08, 0.0, 1.655, 0.0, 1.655, 0.0, -1.655, 0.0, -7.234234e-08, 0.0, 0.0054335, 0.0),
		"rail_offset_x": 0.0
	},
	"dinghy": {
		"path": "res://assets/models/user/vessels/dinghy.glb",
		"transform": Transform3D(3.8, 0.0, 0.0, 0.0, 3.8, 0.0, 0.0, 0.0, 3.8, -0.35, 0.15, -0.2),
		"rail_offset_x": -0.25
	},
	"bombard_skiff": {
		"path": "res://assets/models/user/vessels/the_bombard_skiff.glb",
		"transform": Transform3D(0.0, 0.0, 2.6, 0.0, 2.6, 0.0, -2.6, 0.0, 0.0, 0.05, 0.05, -0.1),
		"rail_offset_x": 0.25
	},
	"ironclad": {
		"path": "res://assets/models/user/vessels/the_ironclad.glb",
		"transform": Transform3D(0.0, 0.0, 1.85, 0.0, 1.85, 0.0, -1.85, 0.0, 0.0, 0.1, 0.05, 0.0),
		"rail_offset_x": 0.35
	}
}

const ENEMY_VESSEL_CONFIGS: Dictionary = {
	"war_barge": {
		"path": "res://assets/models/enemy/vessels/boss_war_barge.glb",
		"transform": Transform3D(-0.31290805, -0.8244233, 3.407758, 0.0, 3.4213028, 0.8277002, -3.5060644, 0.07357786, -0.30413443, -11.516914, 0.29983392, 0.17183113),
		"marker_bow": Vector3(-13.068624, 1.1870035, -1.8804607),
		"marker_mid": Vector3(-12.614456, 0.26471028, -0.17524332),
		"marker_stern": Vector3(-12.687212, 0.40418908, 0.4926853),
		"dock_x": 13.323
	},
	"bone_beard": {
		"path": "res://assets/models/enemy/vessels/captain_bone-beard’s_twin_frigate.glb",
		"transform": Transform3D(-4.2, 0.0, 0.0, 0.0, 4.2, 0.0, 0.0, 0.0, -4.2, -11.5, 0.25, 0.0),
		"marker_bow": Vector3(-13.1, 0.55, -1.85),
		"marker_mid": Vector3(-13.1, 0.50, -0.05),
		"marker_stern": Vector3(-13.1, 0.55, 0.65),
		"dock_x": 13.32
	},
	"siege_fortress": {
		"path": "res://assets/models/enemy/vessels/boss_siege_fortress.glb",
		"transform": Transform3D(-4.2, 0.0, 0.0, 0.0, 4.2, 0.0, 0.0, 0.0, -4.2, -11.4, 0.20, 0.0),
		"marker_bow": Vector3(-13.2, 0.65, -1.90),
		"marker_mid": Vector3(-13.15, 0.60, -0.05),
		"marker_stern": Vector3(-13.2, 0.65, 0.70),
		"dock_x": 13.5
	},
	"ghost_sloop": {
		"path": "res://assets/models/enemy/vessels/ghost_sloop.glb",
		"transform": Transform3D(-4.8, 0.0, 0.0, 0.0, 4.8, 0.0, 0.0, 0.0, -4.8, -11.5, 0.35, 0.0),
		"marker_bow": Vector3(-12.8, 0.60, -1.80),
		"marker_mid": Vector3(-12.7, 0.55, -0.05),
		"marker_stern": Vector3(-12.8, 0.60, 0.60),
		"dock_x": 13.32
	}
}

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

func _ready() -> void:
	zones = [zone_bow, zone_midship, zone_stern]
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
	var current_vessel: String = "sloop"
	if GameState and "active_vessel" in GameState and not str(GameState.active_vessel).is_empty():
		current_vessel = str(GameState.active_vessel)
	setup_player_vessel(current_vessel)
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

var is_camera_free_mode: bool = false
var _is_mmb_dragging: bool = false
var _last_mouse_pos: Vector2 = Vector2.ZERO
var _camera_debug_label: Label = null

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
		_update_camera_debug_overlay()

func _unhandled_input(event: InputEvent) -> void:
	if not is_instance_valid(boarding_camera):
		return

	if event is InputEventKey:
		var ke: InputEventKey = event as InputEventKey
		if ke.pressed and not ke.echo:
			if ke.keycode == KEY_C:
				is_camera_free_mode = not is_camera_free_mode
				_update_camera_debug_overlay()
			elif ke.keycode == KEY_P:
				_print_camera_transform()
			elif ke.keycode == KEY_H:
				debug_disable_spawns = not debug_disable_spawns
				if debug_disable_spawns:
					clear_all_planks_and_boarders()
				else:
					if current_wave == 0 and not is_approaching:
						_launch_initial_planks()
				_update_camera_debug_overlay()

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			var fwd: Vector3 = -boarding_camera.global_transform.basis.z.normalized()
			boarding_camera.global_position += fwd * 0.8
			_update_camera_debug_overlay()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var back: Vector3 = boarding_camera.global_transform.basis.z.normalized()
			boarding_camera.global_position += back * 0.8
			_update_camera_debug_overlay()
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_is_mmb_dragging = mb.pressed
			_last_mouse_pos = mb.position
		elif is_camera_free_mode and mb.button_index == MOUSE_BUTTON_RIGHT:
			_is_mmb_dragging = mb.pressed
			_last_mouse_pos = mb.position

	elif event is InputEventMouseMotion and _is_mmb_dragging:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		var sensitivity: float = 0.005
		boarding_camera.rotate_y(-mm.relative.x * sensitivity)
		boarding_camera.rotate_object_local(Vector3.RIGHT, -mm.relative.y * sensitivity)
		_update_camera_debug_overlay()

func clear_all_planks_and_boarders() -> void:
	var planks: Array[Node] = get_tree().get_nodes_in_group("boarding_plank")
	for p: Node in planks:
		p.queue_free()
	var legacy_ropes: Array[Node] = get_tree().get_nodes_in_group("grapple_rope")
	for r: Node in legacy_ropes:
		r.queue_free()
	var boarders: Array[Node] = get_tree().get_nodes_in_group("boarder")
	for b: Node in boarders:
		b.queue_free()

func _update_camera_debug_overlay() -> void:
	if not is_instance_valid(_camera_debug_label):
		_camera_debug_label = Label.new()
		_camera_debug_label.name = "CameraDebugOverlay"
		_camera_debug_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		_camera_debug_label.position = Vector2(20.0, -120.0)
		_camera_debug_label.add_theme_font_size_override("font_size", 14)
		_camera_debug_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3, 1.0))
		add_child(_camera_debug_label)

	if is_instance_valid(boarding_camera):
		var p: Vector3 = boarding_camera.position
		var r: Vector3 = boarding_camera.rotation_degrees
		var spawn_status: String = "HIDDEN [Press 'H' to show]" if debug_disable_spawns else "ACTIVE [Press 'H' to hide]"
		if is_camera_free_mode:
			_camera_debug_label.text = "[CAMERA ADJUST: ON ('C' to lock)] | Planks & Mobs: %s\nFly: WASD/QE | Look: Mouse Drag | Zoom: Wheel | Print: 'P'\nPos: Vector3(%.2f, %.2f, %.2f) | Rot: Vector3(%.1f, %.1f, %.1f)" % [spawn_status, p.x, p.y, p.z, r.x, r.y, r.z]
			_camera_debug_label.visible = true
		else:
			_camera_debug_label.text = "Camera: Pos(%.1f, %.1f, %.1f) Rot(%.1f, %.1f) | Planks & Mobs: %s\n['C' adjust view, Wheel zoom, MMB orbit]" % [p.x, p.y, p.z, r.x, r.y, spawn_status]
			_camera_debug_label.visible = true

func _print_camera_transform() -> void:
	if is_instance_valid(boarding_camera):
		var p: Vector3 = boarding_camera.position
		var r: Vector3 = boarding_camera.rotation_degrees
		print("[BOARDING CAMERA TRANSFORM] position = Vector3(%.2f, %.2f, %.2f), rotation_degrees = Vector3(%.2f, %.2f, %.2f)" % [p.x, p.y, p.z, r.x, r.y, r.z])

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
	if is_instance_valid(hud):
		hud.update_wave(current_wave, total_waves_to_win)
	if boss_tier == 1 or single_plank_mode:
		# 2 planks from the start (Bow and Stern), with staggered swarm spawn
		launch_plank_to_zone(0, current_wave, 0.0)
		launch_plank_to_zone(2, current_wave, 3.2)
	elif boss_tier == 2:
		launch_plank_to_zone(0, current_wave, 0.0)
		launch_plank_to_zone(2, current_wave, 3.2)
	else:
		launch_plank_to_zone(0, current_wave, 0.0)
		launch_plank_to_zone(1, current_wave, 2.5)
		launch_plank_to_zone(2, current_wave, 5.0)
		
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
		
	var cfg: Dictionary = PLAYER_VESSEL_CONFIGS[v_key] as Dictionary
	var glb_path: String = str(cfg.get("path", "res://assets/models/user/vessels/the_sloop.glb"))
	if not ResourceLoader.exists(glb_path):
		return

	var old_model: Node = player_ship_container.find_child("PlayerShipVisual", true, false)
	if is_instance_valid(old_model):
		old_model.queue_free()

	var scene: PackedScene = load(glb_path) as PackedScene
	if scene:
		var inst: Node3D = scene.instantiate() as Node3D
		inst.name = "PlayerShipVisual"
		inst.transform = cfg.get("transform", Transform3D.IDENTITY) as Transform3D
		player_ship_container.add_child(inst)

		if v_key == "dinghy":
			var mask_res: String = "res://assets/models/user/vessels/dinghy_cockpit_mask.tres"
			if ResourceLoader.exists(mask_res):
				var mask: MeshInstance3D = MeshInstance3D.new()
				mask.name = "CockpitWaterMask"
				mask.mesh = load(mask_res) as Mesh
				inst.add_child(mask)

	var target_zones: Array[BoardingZone] = zones if not zones.is_empty() else [zone_bow, zone_midship, zone_stern]
	var rail_offset: float = float(cfg.get("rail_offset_x", 0.0))
	for z: BoardingZone in target_zones:
		if is_instance_valid(z) and is_instance_valid(z.plank_anchor):
			z.plank_anchor.position.x = 2.0 + rail_offset

func setup_enemy_vessel(boss_name: String = "") -> void:
	if not is_instance_valid(enemy_ship_container):
		return
	var b_lower: String = boss_name.to_lower()
	var boss_key: String = "war_barge"
	if b_lower.contains("fortress"):
		boss_key = "siege_fortress"
	elif b_lower.contains("phantom") or b_lower.contains("dredge") or b_lower.contains("ghost"):
		boss_key = "ghost_sloop"
	elif b_lower.contains("bone") or b_lower.contains("frigate"):
		boss_key = "bone_beard"

	var cfg: Dictionary = ENEMY_VESSEL_CONFIGS.get(boss_key, ENEMY_VESSEL_CONFIGS["war_barge"]) as Dictionary
	var glb_path: String = str(cfg.get("path", ""))
	
	if ResourceLoader.exists(glb_path):
		var old_model: Node = enemy_ship_container.find_child("EnemyShipVisual", true, false)
		if is_instance_valid(old_model):
			old_model.queue_free()
		var scene: PackedScene = load(glb_path) as PackedScene
		if scene:
			var inst: Node3D = scene.instantiate() as Node3D
			inst.name = "EnemyShipVisual"
			inst.transform = cfg.get("transform", Transform3D.IDENTITY) as Transform3D
			enemy_ship_container.add_child(inst)

	if is_instance_valid(enemy_ship_marker_bow) and cfg.has("marker_bow"):
		enemy_ship_marker_bow.position = cfg.get("marker_bow") as Vector3
	if is_instance_valid(enemy_ship_marker_mid) and cfg.has("marker_mid"):
		enemy_ship_marker_mid.position = cfg.get("marker_mid") as Vector3
	if is_instance_valid(enemy_ship_marker_stern) and cfg.has("marker_stern"):
		enemy_ship_marker_stern.position = cfg.get("marker_stern") as Vector3

	if cfg.has("dock_x"):
		target_dock_x = float(cfg.get("dock_x", 13.323))
		if is_approaching:
			_start_approach_sequence()

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
	else:
		if is_instance_valid(player_controller):
			player_controller.setup_defender_model("")

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
	if not is_encounter_active:
		return
		
	if is_instance_valid(boarding_camera) and not boarding_camera.is_current():
		boarding_camera.current = true
		boarding_camera.make_current()

	if is_camera_free_mode and is_instance_valid(boarding_camera):
		var fly_speed: float = 8.0 * delta
		var cam_basis: Basis = boarding_camera.global_transform.basis
		var move_dir: Vector3 = Vector3.ZERO
		if Input.is_key_pressed(KEY_W):
			move_dir -= cam_basis.z
		if Input.is_key_pressed(KEY_S):
			move_dir += cam_basis.z
		if Input.is_key_pressed(KEY_A):
			move_dir -= cam_basis.x
		if Input.is_key_pressed(KEY_D):
			move_dir += cam_basis.x
		if Input.is_key_pressed(KEY_E) or Input.is_key_pressed(KEY_SPACE):
			move_dir += Vector3.UP
		if Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_CTRL):
			move_dir += Vector3.DOWN
		if move_dir.length_squared() > 0.001:
			boarding_camera.global_position += move_dir.normalized() * fly_speed
			_update_camera_debug_overlay()
		
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
	if is_instance_valid(hud):
		hud.update_wave(wave_num, total_waves_to_win)
	if boss_tier == 1 or single_plank_mode:
		if wave_num % 2 == 1:
			launch_plank_to_zone(0, wave_num, 0.0)
			launch_plank_to_zone(2, wave_num, 3.2)
		else:
			launch_plank_to_zone(2, wave_num, 0.0)
			launch_plank_to_zone(0, wave_num, 3.2)
	elif boss_tier == 2:
		if wave_num % 2 == 1:
			launch_plank_to_zone(0, wave_num, 0.0)
			launch_plank_to_zone(2, wave_num, 3.2)
		else:
			launch_plank_to_zone(2, wave_num, 0.0)
			launch_plank_to_zone(0, wave_num, 3.2)
	else:
		match wave_num:
			1:
				launch_plank_to_zone(1, wave_num, 0.0)
			2:
				launch_plank_to_zone(0, wave_num, 0.0)
				launch_plank_to_zone(2, wave_num, 3.0)
			3:
				launch_plank_to_zone(0, wave_num, 0.0)
				launch_plank_to_zone(1, wave_num, 2.5)
				launch_plank_to_zone(2, wave_num, 5.0)

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
		# Early levels: 1 enemy per plank for waves 1-2, 2 for final wave
		if wave_num <= 2:
			return 1
		return 2
	elif boss_tier == 2:
		return 2
	else:
		return 3

func _spawn_plank_swarm(plank: BoardingPlank, zone: BoardingZone, count: int, wave_num: int = 1, initial_delay_sec: float = 0.0) -> void:
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
		var enemy: BoarderEnemy = chosen_scene.instantiate() as BoarderEnemy
		add_child(enemy)
		if boss_tier <= 1 or single_plank_mode:
			enemy.max_hp = 18.0
			enemy.current_hp = 18.0
			enemy.attack_damage = 3.5
			enemy.cross_speed_mult = 0.85
			enemy.deck_wander_speed = 0.85
			enemy.breach_z = 6.2
		enemy.breached_stern.connect(_on_enemy_breached_stern)
		enemy.tree_exited.connect(_on_enemy_removed)
		if enemy.has_signal("died"):
			enemy.connect("died", _on_enemy_died)
		enemy.start_crossing(plank, zone)
		
	active_spawners_count = maxi(0, active_spawners_count - 1)
	_check_victory_condition()

func _on_enemy_died() -> void:
	call_deferred("_check_victory_condition")

func _on_enemy_removed() -> void:
	call_deferred("_check_victory_condition")

func _on_enemy_breached_stern(_enemy: BoarderEnemy) -> void:
	if not is_encounter_active:
		return
	is_encounter_active = false
	if is_instance_valid(hud):
		hud.show_defeat("STERN BREACHED! GAME OVER")
	encounter_lost.emit()
	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("barrel_breaks", 0.9, 1.1)

func _on_crew_defeated() -> void:
	if not is_encounter_active:
		return
	is_encounter_active = false
	if is_instance_valid(hud):
		hud.show_defeat("CREW MEMBER DEFEATED!")
	encounter_lost.emit()
	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("barrel_breaks", 0.9, 1.1)

func _get_enemy_scene_for_swarm(wave_num: int, swarm_index: int) -> PackedScene:
	var raider_scn: PackedScene = boarder_raider_scene if is_instance_valid(boarder_raider_scene) else boarder_scene
	var brute_scn: PackedScene = boarder_brute_scene if is_instance_valid(boarder_brute_scene) else boarder_scene

	# Boss 1 only uses the frontline pirate raider!
	if boss_tier <= 1:
		return raider_scn

	match wave_num:
		1:
			return raider_scn
		2:
			if swarm_index == 2:
				return brute_scn
			return raider_scn
		_:
			if swarm_index % 2 == 1:
				return brute_scn
			return raider_scn

func _damage_vessel_hull(amount: float) -> void:
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
	encounter_lost.emit()
