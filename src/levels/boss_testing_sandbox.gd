class_name BossTestingSandbox
extends Node3D

## Boss & Weapon Inspector & Director Sandbox
## A dedicated testing and showcase arena to inspect enemy bosses,
## trigger and observe all their weapon attacks and animations, inspect projectiles,
## and see what minions and hazards they spawn.

# Boss Prefabs
const BOSS_WAR_BARGE_SCENE = preload("res://src/gameplay/enemies/boss_war_barge.tscn")
const BOSS_BONE_BEARD_SCENE = preload("res://src/gameplay/enemies/boss_bone_beard.tscn")
const BOSS_PHANTOM_DREDGE_SCENE = preload("res://src/gameplay/enemies/boss_phantom_dredge.tscn")
const BOSS_SIEGE_FORTRESS_SCENE = preload("res://src/gameplay/enemies/boss_siege_fortress.tscn")
const MINI_BOSS_BOMBARD_SCENE = preload("res://src/gameplay/enemies/enemy_mini_boss_bombard.tscn")
const MINI_BOSS_HARVESTER_SCENE = preload("res://src/gameplay/enemies/enemy_mini_boss_harvester.tscn")

# Minion Prefabs
const MINION_MOB_SCENE = preload("res://src/gameplay/enemies/enemy_mob.tscn")
const MINION_GRAVE_SKIFF_SCENE = preload("res://src/gameplay/enemies/enemy_grave_skiff.tscn")
const MINION_TIDE_CUTTER_SCENE = preload("res://src/gameplay/enemies/enemy_tide_cutter.tscn")
const MINION_IRON_GUNNER_SCENE = preload("res://src/gameplay/enemies/enemy_iron_gunner.tscn")
const MINION_BRIMSTONE_RAFT_SCENE = preload("res://src/gameplay/enemies/enemy_brimstone_raft.tscn")

# Hazard Prefabs
const HAZARD_POWDER_KEG_SCENE = preload("res://src/gameplay/obstacles/destructible_barrel.tscn")
const HAZARD_SEA_MINE_SCENE = preload("res://src/gameplay/obstacles/hazard_sea_mine.tscn")
const HAZARD_BIOGAS_POD_SCENE = preload("res://src/gameplay/obstacles/hazard_biogas_pod.tscn")
const HAZARD_THERMAL_GEYSER_SCENE = preload("res://src/gameplay/obstacles/hazard_thermal_geyser.tscn")

# Projectile Prefabs
const ENEMY_CANNONBALL_SCENE = preload("res://src/gameplay/projectiles/enemy_cannonball.tscn")
const TWIN_SALVO_SCENE = preload("res://src/gameplay/projectiles/boss_projectile_twin_cannon_salvo.tscn")

# Scene Nodes
@onready var camera_3d: Camera3D = $Camera3D
@onready var boss_container: Node3D = $BossContainer
@onready var spawns_container: Node3D = $SpawnsContainer
@onready var dummy_target: Node3D = $DummyTarget
@onready var target_buoy: MeshInstance3D = $DummyTarget/TargetBuoy
@onready var lane_guides: Node3D = $LaneGuides

# UI References
@onready var main_panel: PanelContainer = %MainPanel
@onready var btn_toggle_ui: Button = %btn_toggle_ui
@onready var boss_name_label: Label = %BossNameLabel
@onready var boss_hp_bar: ProgressBar = %BossHPBar
@onready var boss_hp_label: Label = %BossHPLabel
@onready var telemetry_label: Label = %TelemetryLabel
@onready var boss_option: OptionButton = %boss_option

# Boss State Buttons
@onready var btn_freeze_boss: Button = %btn_freeze_boss
@onready var btn_phase_1: Button = %btn_phase_1
@onready var btn_phase_2: Button = %btn_phase_2
@onready var btn_phase_3: Button = %btn_phase_3
@onready var btn_phase_enrage: Button = %btn_phase_enrage
@onready var btn_defeat_boss: Button = %btn_defeat_boss
@onready var btn_reset_boss: Button = %btn_reset_boss
@onready var btn_dmg_50: Button = %btn_dmg_50
@onready var btn_heal_full: Button = %btn_heal_full

# Weapon & Action Container
@onready var weapons_container: VBoxContainer = %WeaponsContainer
@onready var siege_parts_container: VBoxContainer = %SiegePartsContainer
@onready var btn_dmg_port: Button = %btn_dmg_port
@onready var btn_dmg_starboard: Button = %btn_dmg_starboard
@onready var btn_dmg_ram: Button = %btn_dmg_ram
@onready var btn_dmg_furnace: Button = %btn_dmg_furnace

# Projectile Customizer
@onready var slider_proj_speed: HSlider = %slider_proj_speed
@onready var label_proj_speed: Label = %label_proj_speed
@onready var opt_proj_color: OptionButton = %opt_proj_color
@onready var btn_test_proj_close: Button = %btn_test_proj_close
@onready var btn_test_proj_center: Button = %btn_test_proj_center

# Spawns & Hazards
@onready var btn_spawn_skiff: Button = %btn_spawn_skiff
@onready var btn_spawn_grave_skiff: Button = %btn_spawn_grave_skiff
@onready var btn_spawn_tide_cutter: Button = %btn_spawn_tide_cutter
@onready var btn_spawn_iron_gunner: Button = %btn_spawn_iron_gunner
@onready var btn_spawn_brimstone: Button = %btn_spawn_brimstone
@onready var btn_spawn_swarm: Button = %btn_spawn_swarm
@onready var btn_spawn_keg: Button = %btn_spawn_keg
@onready var btn_spawn_mine: Button = %btn_spawn_mine
@onready var btn_spawn_pod: Button = %btn_spawn_pod
@onready var btn_spawn_geyser: Button = %btn_spawn_geyser
@onready var btn_clear_all: Button = %btn_clear_all

# Camera & Time
@onready var btn_cam_front: Button = %btn_cam_front
@onready var btn_cam_quarter: Button = %btn_cam_quarter
@onready var btn_cam_top: Button = %btn_cam_top
@onready var btn_cam_side: Button = %btn_cam_side
@onready var slider_zoom: HSlider = %slider_zoom
@onready var btn_toggle_buoy: Button = %btn_toggle_buoy
@onready var btn_toggle_guides: Button = %btn_toggle_guides
@onready var btn_speed_pause: Button = %btn_speed_pause
@onready var btn_speed_slow: Button = %btn_speed_slow
@onready var btn_speed_quarter: Button = %btn_speed_quarter
@onready var btn_speed_half: Button = %btn_speed_half
@onready var btn_speed_normal: Button = %btn_speed_normal
@onready var btn_speed_double: Button = %btn_speed_double

# Active State Variables
var active_boss: Node3D = null
var current_boss_index: int = 0
var is_boss_frozen: bool = true # Start stationary so user can immediately inspect the boss model!
var configured_proj_speed: float = 11.0
var selected_proj_color: Color = Color.WHITE

enum CamPreset { FRONT, QUARTER, TOP, SIDE }
var current_cam_preset: CamPreset = CamPreset.FRONT
var zoom_factor: float = 1.0
var is_orbiting: bool = false
var orbit_yaw: float = 0.0
var orbit_pitch: float = 0.0

const BOSS_CATALOG: Array[Dictionary] = [
	{
		"name": "Captain Ironjaw (War-Barge)",
		"subtitle": "Armored steam war-barge with broadsides, steam venting, and mortar barrage.",
		"scene": BOSS_WAR_BARGE_SCENE,
		"default_hp": 220,
		"actions": [
			{"name": "💥 Fire Alternating Salvo", "method": "_fire_ironjaw_salvo"},
			{"name": "🎯 Fire Targeted Mortar", "method": "_fire_ironjaw_mortar"},
			{"name": "💨 Toggle Steam Venting", "method": "_toggle_ironjaw_steam"},
			{"name": "⚡ Trigger Ram Charge", "method": "_fire_ironjaw_ram"},
			{"name": "🔴 Enraged Rapid Salvo", "method": "_fire_ironjaw_enrage"}
		]
	},
	{
		"name": "Captain Bone-Beard",
		"subtitle": "Fast twin-frigate with high weave speed and rolling powder keg drops.",
		"scene": BOSS_BONE_BEARD_SCENE,
		"default_hp": 100,
		"actions": [
			{"name": "💥 Fire Twin Cannon Salvo", "method": "_fire_bonebeard_salvo"},
			{"name": "🛢️ Drop Rolling Powder Kegs", "method": "_fire_bonebeard_kegs"},
			{"name": "🌊 Lateral Speed Surge", "method": "_surge_bonebeard_weave"}
		]
	},
	{
		"name": "The Phantom Dredge",
		"subtitle": "Submerging bayou dredger with dive, surface, and toxic mortar cycles.",
		"scene": BOSS_PHANTOM_DREDGE_SCENE,
		"default_hp": 450,
		"actions": [
			{"name": "👻 Fire Spectral Volley (Cyan)", "method": "_fire_dredge_spectral"},
			{"name": "🧪 Fire Poison Mortar Strike", "method": "_fire_dredge_mortar"},
			{"name": "🌊 Submerge / Surface Toggle", "method": "_toggle_dredge_submerge"},
			{"name": "💫 Emit Water Shockwave", "method": "_fire_dredge_shockwave"},
			{"name": "🚣 Rain Bayou Mob Swarm", "method": "_fire_dredge_swarm"}
		]
	},
	{
		"name": "The Siege Fortress",
		"subtitle": "Heavy volcanic citadel craft with multi-turret crossfire and geyser slams.",
		"scene": BOSS_SIEGE_FORTRESS_SCENE,
		"default_hp": 800,
		"actions": [
			{"name": "🏰 Fire Multi-Turret Salvo", "method": "_fire_fortress_salvo"},
			{"name": "🌋 Trigger Thermal Geyser Slam", "method": "_fire_fortress_geyser"},
			{"name": "🦏 Trigger Ram Overdrive", "method": "_fire_fortress_ram"}
		]
	},
	{
		"name": "Mini-Boss: Bombard Skiff",
		"subtitle": "Heavy artillery skiff launching high-arc explosive mortar shells.",
		"scene": MINI_BOSS_BOMBARD_SCENE,
		"default_hp": 120,
		"actions": [
			{"name": "💣 Launch Heavy Bombard Mortar", "method": "_fire_bombard_mortar"},
			{"name": "💥 Fire Forward Cannon", "method": "_fire_bombard_cannon"}
		]
	},
	{
		"name": "Mini-Boss: Toxic Harvester",
		"subtitle": "Paddle-steamer harvester deploying toxic biogas mortar strikes.",
		"scene": MINI_BOSS_HARVESTER_SCENE,
		"default_hp": 110,
		"actions": [
			{"name": "🧪 Launch Toxic Biogas Mortar", "method": "_fire_harvester_mortar"},
			{"name": "🛢️ Deploy Biogas Pod", "method": "_fire_harvester_pod"}
		]
	}
]

func _ready() -> void:
	GameState.is_game_active = true
	GameState.boss_spawned = true
	
	# Add sandbox to essential groups for boss interactions
	add_to_group("level_controller")
	if camera_3d:
		camera_3d.add_to_group("game_camera")
		
	_setup_dummy_target()
	_setup_ui()
	_spawn_selected_boss(0)
	_set_cam_preset(CamPreset.FRONT)

func _setup_dummy_target() -> void:
	if dummy_target:
		dummy_target.add_to_group("player")
		dummy_target.global_position = Vector3(0.0, 0.0, 0.0)

func _setup_ui() -> void:
	if btn_toggle_ui:
		btn_toggle_ui.pressed.connect(_toggle_ui)
		
	# Boss Dropdown
	if boss_option:
		boss_option.clear()
		for b in BOSS_CATALOG:
			boss_option.add_item(b["name"])
		boss_option.selected = 0
		boss_option.item_selected.connect(_on_boss_selected)
		
	# Boss Lifecycle & State
	if btn_freeze_boss: btn_freeze_boss.pressed.connect(_toggle_freeze_boss)
	if btn_phase_1: btn_phase_1.pressed.connect(func(): set_boss_phase(1))
	if btn_phase_2: btn_phase_2.pressed.connect(func(): set_boss_phase(2))
	if btn_phase_3: btn_phase_3.pressed.connect(func(): set_boss_phase(3))
	if btn_phase_enrage: btn_phase_enrage.pressed.connect(func(): set_boss_phase(4))
	if btn_defeat_boss: btn_defeat_boss.pressed.connect(defeat_current_boss)
	if btn_reset_boss: btn_reset_boss.pressed.connect(respawn_current_boss)
	if btn_dmg_50: btn_dmg_50.pressed.connect(func(): damage_boss(50))
	if btn_heal_full: btn_heal_full.pressed.connect(heal_boss_full)
	
	# Siege Fortress Component Damage
	if btn_dmg_port: btn_dmg_port.pressed.connect(func(): damage_siege_subpart("hp_port_turret", 150))
	if btn_dmg_starboard: btn_dmg_starboard.pressed.connect(func(): damage_siege_subpart("hp_starboard_turret", 150))
	if btn_dmg_ram: btn_dmg_ram.pressed.connect(func(): damage_siege_subpart("hp_prow_ram", 150))
	if btn_dmg_furnace: btn_dmg_furnace.pressed.connect(func(): damage_siege_subpart("hp_furnace_core", 350))

	# Projectile Customizer
	if slider_proj_speed:
		slider_proj_speed.value = configured_proj_speed
		slider_proj_speed.value_changed.connect(func(v):
			configured_proj_speed = v
			if label_proj_speed:
				label_proj_speed.text = "Speed: %.1f m/s" % v
		)
	if label_proj_speed:
		label_proj_speed.text = "Speed: %.1f m/s" % configured_proj_speed
		
	if opt_proj_color:
		opt_proj_color.clear()
		opt_proj_color.add_item("Default Steel")
		opt_proj_color.add_item("Blazing Fire (Orange/Red)")
		opt_proj_color.add_item("Spectral Cursed (Cyan/Green)")
		opt_proj_color.add_item("Void Shadow (Purple/Violet)")
		opt_proj_color.add_item("Toxic Acid (Lime Yellow)")
		opt_proj_color.selected = 0
		opt_proj_color.item_selected.connect(_on_projectile_color_selected)
		
	if btn_test_proj_close: btn_test_proj_close.pressed.connect(func(): _spawn_test_projectile_close())
	if btn_test_proj_center: btn_test_proj_center.pressed.connect(func(): _spawn_test_projectile_lane(0.0))

	# Spawns & Hazards
	if btn_spawn_skiff: btn_spawn_skiff.pressed.connect(func(): spawn_minion("pressure_skiff"))
	if btn_spawn_grave_skiff: btn_spawn_grave_skiff.pressed.connect(func(): spawn_minion("grave_skiff"))
	if btn_spawn_tide_cutter: btn_spawn_tide_cutter.pressed.connect(func(): spawn_minion("tide_cutter"))
	if btn_spawn_iron_gunner: btn_spawn_iron_gunner.pressed.connect(func(): spawn_minion("iron_gunner"))
	if btn_spawn_brimstone: btn_spawn_brimstone.pressed.connect(func(): spawn_minion("brimstone_raft"))
	if btn_spawn_swarm: btn_spawn_swarm.pressed.connect(func(): spawn_minion("bayou_swarm"))
	
	if btn_spawn_keg: btn_spawn_keg.pressed.connect(func(): spawn_hazard("powder_keg"))
	if btn_spawn_mine: btn_spawn_mine.pressed.connect(func(): spawn_hazard("sea_mine"))
	if btn_spawn_pod: btn_spawn_pod.pressed.connect(func(): spawn_hazard("biogas_pod"))
	if btn_spawn_geyser: btn_spawn_geyser.pressed.connect(func(): spawn_hazard("thermal_geyser"))
	if btn_clear_all: btn_clear_all.pressed.connect(clear_all)

	# Camera Presets
	if btn_cam_front: btn_cam_front.pressed.connect(func(): _set_cam_preset(CamPreset.FRONT))
	if btn_cam_quarter: btn_cam_quarter.pressed.connect(func(): _set_cam_preset(CamPreset.QUARTER))
	if btn_cam_top: btn_cam_top.pressed.connect(func(): _set_cam_preset(CamPreset.TOP))
	if btn_cam_side: btn_cam_side.pressed.connect(func(): _set_cam_preset(CamPreset.SIDE))
	if slider_zoom: slider_zoom.value_changed.connect(func(v): _on_zoom_changed(v))
	if btn_toggle_buoy: btn_toggle_buoy.pressed.connect(_toggle_target_buoy)
	if btn_toggle_guides: btn_toggle_guides.pressed.connect(_toggle_lane_guides)
	
	# Time Scale
	if btn_speed_pause: btn_speed_pause.pressed.connect(func(): _set_time_scale(0.0))
	if btn_speed_slow: btn_speed_slow.pressed.connect(func(): _set_time_scale(0.1))
	if btn_speed_quarter: btn_speed_quarter.pressed.connect(func(): _set_time_scale(0.25))
	if btn_speed_half: btn_speed_half.pressed.connect(func(): _set_time_scale(0.5))
	if btn_speed_normal: btn_speed_normal.pressed.connect(func(): _set_time_scale(1.0))
	if btn_speed_double: btn_speed_double.pressed.connect(func(): _set_time_scale(2.0))

func _physics_process(_delta: float) -> void:
	# Pin boss if frozen
	if is_boss_frozen and is_instance_valid(active_boss):
		active_boss.global_position.x = 0.0
		active_boss.global_position.z = -18.0
		if "_weave_time" in active_boss:
			active_boss._weave_time = 0.0
			
	# Silence autonomous timers so user controls what happens
	if is_instance_valid(active_boss):
		if "_attack_timer" in active_boss: active_boss._attack_timer = 0.0
		if "_cannon_timer" in active_boss: active_boss._cannon_timer = 0.0
		if "_mortar_timer" in active_boss: active_boss._mortar_timer = 0.0
		if "_bombard_timer" in active_boss: active_boss._bombard_timer = 0.0
		if "minion_timer" in active_boss: active_boss.minion_timer = 0.0
		if "keg_timer" in active_boss: active_boss.keg_timer = 0.0
		if "mortar_timer" in active_boss: active_boss.mortar_timer = 0.0
		if "_minion_timer" in active_boss: active_boss._minion_timer = 0.0
		if "_geyser_timer" in active_boss: active_boss._geyser_timer = 0.0

	_update_telemetry()

# -------------------------------------------------------------
# Boss Lifecycle Management
# -------------------------------------------------------------
func _on_boss_selected(index: int) -> void:
	current_boss_index = index
	_spawn_selected_boss(index)

func _spawn_selected_boss(index: int) -> void:
	if index < 0 or index >= BOSS_CATALOG.size():
		return
		
	if is_instance_valid(active_boss):
		active_boss.queue_free()
		active_boss = null
		
	var data = BOSS_CATALOG[index]
	var sc: PackedScene = data["scene"]
	if not sc:
		return
		
	active_boss = sc.instantiate() as Node3D
	boss_container.add_child(active_boss)
	
	active_boss.global_position = Vector3(0.0, 0.0, -18.0)
	
	if "current_state" in active_boss:
		active_boss.current_state = 1 # State.COMBAT
	if "_target_z" in active_boss:
		active_boss._target_z = -18.0
		
	if active_boss.has_method("activate_arena"):
		active_boss.activate_arena()
	if "is_arena_active" in active_boss:
		active_boss.is_arena_active = true
	if "spawn_hazard_enabled" in active_boss:
		active_boss.spawn_hazard_enabled = true
		
	# Enforce exact calibrated values for bosses
	match index:
		0: # War-Barge
			var bm = active_boss.get_node_or_null("BossMesh")
			if bm:
				bm.position.y = 0.22
				bm.scale = Vector3(3.39, 3.39, 3.39)
				bm.rotation_degrees = Vector3(0.0, 91.0, 0.0)
		1: # Bone-Beard
			var bm = active_boss.get_node_or_null("BossMesh")
			if bm:
				bm.position.y = 2.00
				bm.scale = Vector3(4.48, 4.48, 4.48)
				bm.rotation_degrees = Vector3(0.0, 0.0, 0.0)
		2: # Phantom Dredge
			var vc = active_boss.get_node_or_null("VisualContainer")
			if vc:
				vc.position.y = 1.45
				vc.scale = Vector3(1.00, 1.00, 1.00)
				vc.rotation_degrees = Vector3(0.0, 178.0, 0.0)
		
	var max_hp = active_boss.max_hp if "max_hp" in active_boss else data["default_hp"]
	var cur_hp = active_boss.current_hp if "current_hp" in active_boss else max_hp
	_update_boss_hp_ui(cur_hp, max_hp, data["name"])
	
	if boss_name_label:
		boss_name_label.text = data["name"]
		
	# Populate dynamic weapon buttons for this boss
	_rebuild_weapon_action_buttons(data["actions"])
	
	# Show/hide Siege Fortress subcomponents panel
	if siege_parts_container:
		siege_parts_container.visible = (index == 3)
		
	_apply_camera_view()

func respawn_current_boss() -> void:
	clear_all()
	_spawn_selected_boss(current_boss_index)

func defeat_current_boss() -> void:
	if not is_instance_valid(active_boss):
		return
	if active_boss.has_method("boss_defeat"):
		active_boss.boss_defeat()
	elif active_boss.has_method("take_damage"):
		active_boss.take_damage(99999)
	elif "current_hp" in active_boss:
		active_boss.current_hp = 0

func _toggle_freeze_boss() -> void:
	is_boss_frozen = not is_boss_frozen
	if btn_freeze_boss:
		btn_freeze_boss.text = "Movement: Stationary" if is_boss_frozen else "Movement: Weaving"

func set_boss_phase(phase: int) -> void:
	if not is_instance_valid(active_boss):
		return
	if "current_phase" in active_boss:
		active_boss.current_phase = clamp(phase, 1, 3)
	if phase == 4: # Enraged
		if "combat_time" in active_boss:
			active_boss.combat_time = 46.0
		if "current_phase" in active_boss:
			active_boss.current_phase = 3
	print("[BOSS INSPECTOR] %s switched to Phase %d" % [active_boss.name, phase])

func damage_boss(amount: int) -> void:
	if not is_instance_valid(active_boss):
		return
	if active_boss.has_method("take_damage"):
		active_boss.take_damage(amount)
	elif "current_hp" in active_boss:
		active_boss.current_hp = max(0, active_boss.current_hp - amount)
		_update_boss_hp_ui(active_boss.current_hp, active_boss.max_hp, active_boss.name)

func heal_boss_full() -> void:
	if not is_instance_valid(active_boss):
		return
	if "max_hp" in active_boss:
		active_boss.current_hp = active_boss.max_hp
		_update_boss_hp_ui(active_boss.current_hp, active_boss.max_hp, active_boss.name)

func damage_siege_subpart(component_var: String, amount: int) -> void:
	if not is_instance_valid(active_boss):
		return
	if component_var in active_boss:
		var current_val = active_boss.get(component_var)
		var new_val = max(0, current_val - amount)
		active_boss.set(component_var, new_val)
		print("[BOSS INSPECTOR] Siege Fortress %s HP reduced to %d" % [component_var, new_val])
		damage_boss(amount)

# -------------------------------------------------------------
# Dynamic Weapon Action Trigger Buttons
# -------------------------------------------------------------
func _rebuild_weapon_action_buttons(actions: Array) -> void:
	if not weapons_container:
		return
		
	# Clear old buttons
	for child in weapons_container.get_children():
		child.queue_free()
		
	for act in actions:
		var btn = Button.new()
		btn.text = act["name"]
		btn.custom_minimum_size = Vector2(0, 36)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var method_name = act["method"]
		btn.pressed.connect(Callable(self, method_name))
		weapons_container.add_child(btn)

# Specific Weapon Trigger Handlers
func _fire_ironjaw_salvo() -> void:
	if not is_instance_valid(active_boss): return
	if active_boss.has_method("_fire_cannon_volley"):
		active_boss._fire_cannon_volley()
	elif active_boss.has_method("_fire_warning_shot"):
		active_boss._fire_warning_shot()

func _fire_ironjaw_mortar() -> void:
	if not is_instance_valid(active_boss): return
	if active_boss.has_method("_fire_targeted_mortar"):
		active_boss._fire_targeted_mortar()

func _toggle_ironjaw_steam() -> void:
	if not is_instance_valid(active_boss): return
	if "is_venting_steam" in active_boss:
		if not active_boss.is_venting_steam:
			if active_boss.has_method("_start_steam_venting"): active_boss._start_steam_venting()
		else:
			if active_boss.has_method("_stop_steam_venting"): active_boss._stop_steam_venting()

func _fire_ironjaw_ram() -> void:
	if not is_instance_valid(active_boss): return
	if active_boss.has_method("_start_ram_charge"):
		active_boss._start_ram_charge()

func _fire_ironjaw_enrage() -> void:
	if not is_instance_valid(active_boss): return
	if active_boss.has_method("_fire_enraged_mortar"):
		active_boss._fire_enraged_mortar(Vector3(0, 0, 0))

func _fire_bonebeard_salvo() -> void:
	if is_instance_valid(active_boss) and active_boss.has_method("_fire_twin_cannon_salvo"):
		active_boss._fire_twin_cannon_salvo()
	elif is_instance_valid(active_boss) and active_boss.has_method("_fire_bonebeard_salvo"):
		active_boss._fire_bonebeard_salvo()
	else:
		_spawn_test_twin_salvo(0.0)

func _spawn_test_twin_salvo(lane_x: float = 0.0) -> void:
	if not TWIN_SALVO_SCENE: return
	var salvo = TWIN_SALVO_SCENE.instantiate() as Area3D
	spawns_container.add_child(salvo)
	var spawn_z = active_boss.global_position.z + 1.5 if is_instance_valid(active_boss) else -16.5
	salvo.global_position = Vector3(lane_x, 0.5, spawn_z)
	if "speed" in salvo: salvo.speed = configured_proj_speed
	if salvo.has_method("set_color") and selected_proj_color != Color.WHITE:
		salvo.set_color(selected_proj_color)
	if salvo.has_method("setup"):
		salvo.setup(Vector3(0, 0, 1), null, null)
	if "direction" in salvo: salvo.direction = Vector3(0, 0, 1)

func _fire_bonebeard_kegs() -> void:
	if not is_instance_valid(active_boss): return
	if active_boss.has_method("_perform_attack"):
		active_boss._perform_attack()

func _surge_bonebeard_weave() -> void:
	if is_instance_valid(active_boss):
		var tween = create_tween()
		tween.tween_property(active_boss, "global_position:x", 3.0, 0.6).set_trans(Tween.TRANS_SINE)
		tween.tween_property(active_boss, "global_position:x", -3.0, 1.2).set_trans(Tween.TRANS_SINE)
		tween.tween_property(active_boss, "global_position:x", 0.0, 0.6).set_trans(Tween.TRANS_SINE)

func _fire_dredge_spectral() -> void:
	if not is_instance_valid(active_boss): return
	if active_boss.has_method("_fire_spectral_cannon_volley"):
		active_boss._fire_spectral_cannon_volley()

func _fire_dredge_mortar() -> void:
	if not is_instance_valid(active_boss): return
	if active_boss.has_method("_fire_poison_mortars"):
		active_boss._fire_poison_mortars()

func _toggle_dredge_submerge() -> void:
	if not is_instance_valid(active_boss): return
	if "current_state" in active_boss:
		if active_boss.current_state != 2: # State.SUBMERGED
			if active_boss.has_method("_start_submerge"): active_boss._start_submerge()
		else:
			if active_boss.has_method("_resurface"): active_boss._resurface()

func _fire_dredge_shockwave() -> void:
	if not is_instance_valid(active_boss): return
	if active_boss.has_method("_emit_water_shockwave"):
		active_boss._emit_water_shockwave()

func _fire_dredge_swarm() -> void:
	if not is_instance_valid(active_boss): return
	if active_boss.has_method("_rain_submerged_mobs"):
		active_boss._rain_submerged_mobs()

func _fire_fortress_salvo() -> void:
	if not is_instance_valid(active_boss): return
	if active_boss.has_method("_fire_fortress_salvo"):
		active_boss._fire_fortress_salvo()

func _fire_fortress_geyser() -> void:
	if not is_instance_valid(active_boss): return
	if active_boss.has_method("_trigger_geyser_slam"):
		active_boss._trigger_geyser_slam()

func _fire_fortress_ram() -> void:
	if not is_instance_valid(active_boss): return
	if active_boss.has_method("_start_ram_overdrive"):
		active_boss._start_ram_overdrive()

func _fire_bombard_mortar() -> void:
	if not is_instance_valid(active_boss): return
	if active_boss.has_method("_launch_heavy_bombard"):
		active_boss._launch_heavy_bombard()

func _fire_bombard_cannon() -> void:
	_spawn_test_projectile_lane(0.0)

func _fire_harvester_mortar() -> void:
	if not is_instance_valid(active_boss): return
	if active_boss.has_method("_launch_toxic_mortar"):
		active_boss._launch_toxic_mortar()

func _fire_harvester_pod() -> void:
	spawn_hazard("biogas_pod")

# -------------------------------------------------------------
# Ammo & Projectile Visuals Inspector
# -------------------------------------------------------------
func _on_projectile_color_selected(index: int) -> void:
	match index:
		0: selected_proj_color = Color.WHITE
		1: selected_proj_color = Color(1.0, 0.35, 0.05) # Fire Orange
		2: selected_proj_color = Color(0.2, 1.0, 0.75) # Spectral Cyan
		3: selected_proj_color = Color(0.75, 0.25, 1.0) # Void Purple
		4: selected_proj_color = Color(0.8, 1.0, 0.1) # Toxic Acid

func _spawn_test_projectile_close() -> void:
	if not ENEMY_CANNONBALL_SCENE: return
	var ball = ENEMY_CANNONBALL_SCENE.instantiate() as Area3D
	spawns_container.add_child(ball)
	ball.global_position = Vector3(1.0, 1.0, -14.0)
	if "speed" in ball: ball.speed = configured_proj_speed
	if ball.has_method("set_color") and selected_proj_color != Color.WHITE:
		ball.set_color(selected_proj_color)
	if ball.has_method("setup"):
		ball.setup(Vector3(0, 0, 1), null, null)
	if "direction" in ball: ball.direction = Vector3(0, 0, 1)

func _spawn_test_projectile_lane(lane_x: float) -> void:
	if not ENEMY_CANNONBALL_SCENE: return
	var ball = ENEMY_CANNONBALL_SCENE.instantiate() as Area3D
	spawns_container.add_child(ball)
	var spawn_z = active_boss.global_position.z + 1.5 if is_instance_valid(active_boss) else -16.5
	ball.global_position = Vector3(lane_x, 0.5, spawn_z)
	if "speed" in ball: ball.speed = configured_proj_speed
	if ball.has_method("set_color") and selected_proj_color != Color.WHITE:
		ball.set_color(selected_proj_color)
	var dir = Vector3(0, 0, 1)
	if ball.has_method("setup"): ball.setup(dir, null, null)
	if "direction" in ball: ball.direction = dir

# -------------------------------------------------------------
# Spawns & Hazards Inspection
# -------------------------------------------------------------
func spawn_minion(minion_type: String) -> void:
	var sc: PackedScene = null
	var speed_val = 3.2
	match minion_type:
		"pressure_skiff": sc = MINION_MOB_SCENE
		"grave_skiff": sc = MINION_GRAVE_SKIFF_SCENE
		"tide_cutter": sc = MINION_TIDE_CUTTER_SCENE
		"iron_gunner": sc = MINION_IRON_GUNNER_SCENE
		"brimstone_raft": sc = MINION_BRIMSTONE_RAFT_SCENE
		"bayou_swarm":
			_spawn_bayou_swarm()
			return

	if not sc: return
	var minion = sc.instantiate() as Area3D
	spawns_container.add_child(minion)
	var lanes = [-3.0, 0.0, 3.0]
	minion.global_position = Vector3(lanes.pick_random(), 0.1, -14.0)
	if "forward_speed" in minion: minion.forward_speed = speed_val
	if "max_hp" in minion:
		minion.max_hp = 6
		minion.current_hp = 6

func _spawn_bayou_swarm() -> void:
	var lanes = [-3.0, 3.0, -1.5, 1.5, 0.0]
	for i in range(5):
		get_tree().create_timer(i * 0.25).timeout.connect(func():
			var sc = MINION_GRAVE_SKIFF_SCENE if (i % 2 == 0) else MINION_TIDE_CUTTER_SCENE
			var minion = sc.instantiate() as Area3D
			spawns_container.add_child(minion)
			minion.global_position = Vector3(lanes[i % lanes.size()], 0.1, -14.0)
		)

func spawn_hazard(hazard_type: String) -> void:
	var sc: PackedScene = null
	match hazard_type:
		"powder_keg": sc = HAZARD_POWDER_KEG_SCENE
		"sea_mine": sc = HAZARD_SEA_MINE_SCENE
		"biogas_pod": sc = HAZARD_BIOGAS_POD_SCENE
		"thermal_geyser": sc = HAZARD_THERMAL_GEYSER_SCENE
		
	if not sc: return
	var hazard = sc.instantiate() as Node3D
	spawns_container.add_child(hazard)
	var lanes = [-3.0, 0.0, 3.0]
	hazard.global_position = Vector3(lanes.pick_random(), 0.2, -12.0)
	if "forward_speed" in hazard: hazard.forward_speed = 4.5

func clear_all() -> void:
	for child in spawns_container.get_children():
		child.queue_free()
	for node in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(node) and not node.is_in_group("boss") and node != active_boss:
			node.queue_free()
	for proj in get_tree().get_nodes_in_group("enemy_projectiles"):
		if is_instance_valid(proj): proj.queue_free()

# -------------------------------------------------------------
# Camera Showcase & Controls
# -------------------------------------------------------------
func _set_cam_preset(preset: CamPreset) -> void:
	current_cam_preset = preset
	orbit_yaw = 0.0
	orbit_pitch = 0.0
	_update_cam_buttons()
	_apply_camera_view()

func _update_cam_buttons() -> void:
	if btn_cam_front: btn_cam_front.text = "[ Front Framing ]" if current_cam_preset == CamPreset.FRONT else "Front Framing"
	if btn_cam_quarter: btn_cam_quarter.text = "[ 3/4 Quarter ]" if current_cam_preset == CamPreset.QUARTER else "3/4 Quarter"
	if btn_cam_top: btn_cam_top.text = "[ Top-Down ]" if current_cam_preset == CamPreset.TOP else "Top-Down"
	if btn_cam_side: btn_cam_side.text = "[ Waterline ]" if current_cam_preset == CamPreset.SIDE else "Waterline"

func _on_zoom_changed(v: float) -> void:
	zoom_factor = v
	_apply_camera_view()

func _toggle_target_buoy() -> void:
	if target_buoy:
		target_buoy.visible = not target_buoy.visible
		if btn_toggle_buoy:
			btn_toggle_buoy.text = "Target Buoy: ON" if target_buoy.visible else "Target Buoy: OFF"

func _toggle_lane_guides() -> void:
	if lane_guides:
		lane_guides.visible = not lane_guides.visible
		if btn_toggle_guides:
			btn_toggle_guides.text = "Lane Guides: ON" if lane_guides.visible else "Lane Guides: OFF"

func _set_time_scale(ts: float) -> void:
	Engine.time_scale = ts
	print("[BOSS INSPECTOR] Simulation speed: %.2fx" % ts)

func _apply_camera_view() -> void:
	if not camera_3d: return
	
	var base_cam_pos = Vector3.ZERO
	var look_target = Vector3(0.0, 0.8, -18.0) # Look straight at boss
	var fov_val = 52.0
	
	match current_cam_preset:
		CamPreset.FRONT:
			# Direct front inspection view, framing the boss in upper half
			base_cam_pos = Vector3(0.0, 2.2, -10.0)
			look_target = Vector3(0.0, 0.6, -18.0)
			fov_val = 48.0
		CamPreset.QUARTER:
			# Dynamic 3/4 isometric perspective
			base_cam_pos = Vector3(7.0, 3.8, -10.5)
			look_target = Vector3(0.0, 0.6, -18.0)
			fov_val = 50.0
		CamPreset.TOP:
			# High-angle tactical view
			base_cam_pos = Vector3(0.0, 22.0, -14.0)
			look_target = Vector3(0.0, 0.0, -14.0)
			fov_val = 56.0
		CamPreset.SIDE:
			# Level profile across water
			base_cam_pos = Vector3(15.0, 1.8, -18.0)
			look_target = Vector3(0.0, 0.6, -18.0)
			fov_val = 45.0

	var cam_offset = (base_cam_pos - look_target) * zoom_factor
	if orbit_yaw != 0.0 or orbit_pitch != 0.0:
		var rot_basis = Basis(Vector3.UP, deg_to_rad(orbit_yaw))
		var right_axis = rot_basis.x
		rot_basis = Basis(right_axis, deg_to_rad(orbit_pitch)) * rot_basis
		cam_offset = rot_basis * cam_offset

	camera_3d.global_position = look_target + cam_offset
	camera_3d.look_at(look_target, Vector3.UP)
	camera_3d.fov = fov_val
	
	# Elevate framing so boss sits comfortably in the upper half above the bottom controls!
	if main_panel and main_panel.visible:
		camera_3d.v_offset = -0.72
	else:
		camera_3d.v_offset = 0.0

func _toggle_ui() -> void:
	if main_panel:
		main_panel.visible = not main_panel.visible
		if btn_toggle_ui:
			btn_toggle_ui.text = "Show Controls (H)" if not main_panel.visible else "Hide Controls (H)"
		_apply_camera_view()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_H:
			_toggle_ui()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			zoom_factor = clampf(zoom_factor - 0.08, 0.3, 3.0)
			if slider_zoom: slider_zoom.value = zoom_factor
			_apply_camera_view()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			zoom_factor = clampf(zoom_factor + 0.08, 0.3, 3.0)
			if slider_zoom: slider_zoom.value = zoom_factor
			_apply_camera_view()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			is_orbiting = event.pressed
	elif event is InputEventMouseMotion and is_orbiting:
		orbit_yaw += -event.relative.x * 0.4
		orbit_pitch = clampf(orbit_pitch - event.relative.y * 0.4, -80.0, 80.0)
		_apply_camera_view()

# -------------------------------------------------------------
# Telemetry
# -------------------------------------------------------------
func _update_boss_hp_ui(cur_hp: int, max_hp: int, boss_name: String = "") -> void:
	if boss_hp_bar:
		boss_hp_bar.max_value = max_hp
		boss_hp_bar.value = cur_hp
	if boss_hp_label:
		var name_str = boss_name if not boss_name.is_empty() else (active_boss.name if is_instance_valid(active_boss) else "Boss")
		var pct = (float(cur_hp) / float(max_hp) * 100.0) if max_hp > 0 else 0.0
		boss_hp_label.text = "%s: %d / %d HP (%.0f%%)" % [name_str, cur_hp, max_hp, pct]

func _update_telemetry() -> void:
	if not telemetry_label: return
	var minion_count = get_tree().get_nodes_in_group("enemies").filter(func(x): return is_instance_valid(x) and not x.is_in_group("boss") and x != active_boss).size()
	var projectile_count = get_tree().get_nodes_in_group("enemy_projectiles").size()
	var hazard_count = spawns_container.get_child_count()
	
	telemetry_label.text = "Minions: %d | Projectiles: %d | Hazards: %d | Speed: %.2fx | Orbit: RMB Drag" % [
		minion_count, projectile_count, hazard_count, Engine.time_scale
	]
