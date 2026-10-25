class_name ChunkFinishLine
extends BaseTrackChunk

@export_enum("tropical", "bayou", "brimstone") var theme_name: String = "tropical"
@export var custom_chunk_id: String = ""
@export var doubloon_scene: PackedScene = preload("res://src/gameplay/collectibles/collectible_doubloon.tscn")
@export var explosion_scene: PackedScene = preload("res://src/vfx/barrel_explosion.tscn")

@onready var finish_trigger: Area3D = get_node_or_null("FinishTrigger") as Area3D

var _is_finished: bool = false
var active_arch_style: String = ""
var active_wave_style: String = ""

const ENEMY_MOB_SCENE: PackedScene = preload("res://src/gameplay/enemies/enemy_mob.tscn")
const BARREL_SCENE: PackedScene = preload("res://src/gameplay/obstacles/destructible_barrel.tscn")
const ROWER_DATA: Resource = preload("res://src/data/resources/enemy_vessels/skeleton_rower.tres")
const RAIDER_DATA: Resource = preload("res://src/data/resources/enemy_vessels/raider_skiff.tres")
const TURTLE_DATA: Resource = preload("res://src/data/resources/enemy_vessels/turtle_raft.tres")
const GHOST_DATA: Resource = preload("res://src/data/resources/enemy_vessels/ghost_sloop.tres")
const ELITE_IRONCLAD_DATA: Resource = preload("res://src/data/resources/enemy_vessels/enemy_elite_ironclad.tres")

const GRAVE_SKIFF_SCENE: PackedScene = preload("res://src/gameplay/enemies/enemy_grave_skiff.tscn")
const TIDE_CUTTER_SCENE: PackedScene = preload("res://src/gameplay/enemies/enemy_tide_cutter.tscn")
const HARVESTER_SCENE: PackedScene = preload("res://src/gameplay/enemies/enemy_mini_boss_harvester.tscn")
const BIOGAS_POD_SCENE: PackedScene = preload("res://src/gameplay/obstacles/hazard_biogas_pod.tscn")

const IRON_GUNNER_SCENE: PackedScene = preload("res://src/gameplay/enemies/enemy_iron_gunner.tscn")
const BRIMSTONE_RAFT_SCENE: PackedScene = preload("res://src/gameplay/enemies/enemy_brimstone_raft.tscn")
const BOMBARD_SCENE: PackedScene = preload("res://src/gameplay/enemies/enemy_mini_boss_bombard.tscn")
const THERMAL_GEYSER_SCENE: PackedScene = preload("res://src/gameplay/obstacles/hazard_thermal_geyser.tscn")

const SHIP_WRECK_MODEL: PackedScene = preload("res://assets/models/ship-wreck.glb")
const ROCKS_MODEL: PackedScene = preload("res://assets/models/rocks-a.glb")
const TOWER_WATCH_MODEL: PackedScene = preload("res://assets/models/tower-watch.glb")
const TOWER_LARGE_MODEL: PackedScene = preload("res://assets/models/tower-complete-large.glb")
const MANGROVE_MODEL: PackedScene = preload("res://assets/models/scenery/Emerald_Mangrove_Grov.glb")
const WILLOW_MODEL: PackedScene = preload("res://assets/models/scenery/The_Withered_Willow.glb")
const TOTEM_MODEL: PackedScene = preload("res://assets/models/scenery/Totem_of_the_Painted.glb")
const ANCHOR_MODEL: PackedScene = preload("res://assets/models/scenery/Rustbound_Anchor.glb")
const SPIRE_MODEL: PackedScene = preload("res://assets/models/scenery/Volcanic_Spire.glb")
const CRYSTAL_MODEL: PackedScene = preload("res://assets/models/scenery/Obsidian_Crystal_Clus.glb")
const CROWN_MODEL: PackedScene = preload("res://assets/models/scenery/Molten_Crown.glb")

static func get_arch_variant(cur_lvl: int) -> int:
	return (cur_lvl + int(cur_lvl / 7)) % 3

static func get_wave_variant(cur_lvl: int) -> int:
	return cur_lvl % 4

func _resolve_active_level() -> int:
	var gs: Node = get_node_or_null("/root/GameState")
	if gs and "current_level" in gs:
		return clampi(int(gs.get("current_level")), 1, 45)
	return 1

func _resolve_active_biome(cur_lvl: int) -> String:
	var b_override: String = biome_id.strip_edges().to_lower()
	if b_override in ["tropical", "bayou", "brimstone"]:
		return b_override
	if theme_name in ["bayou", "brimstone"]:
		return theme_name
	var gs: Node = get_node_or_null("/root/GameState")
	if gs and gs.has_method("get_current_level_resource"):
		var res: LevelData = gs.call("get_current_level_resource") as LevelData
		if res and res.level_id == cur_lvl and not res.biome_name.is_empty():
			return res.biome_name.to_lower()
	if cur_lvl >= 31:
		return "brimstone"
	elif cur_lvl >= 16:
		return "bayou"
	return theme_name.to_lower()

var _finish_setup_done: bool = false
var _l1_coin_mobs_spawned: int = 0

func _ready() -> void:
	var cur_lvl: int = _resolve_active_level()
	var resolved_biome: String = _resolve_active_biome(cur_lvl)
	var is_base_tropical_scene: bool = scene_file_path.ends_with("chunk_finish_line.tscn") and biome_id.is_empty()
	if resolved_biome in ["tropical", "bayou", "brimstone"] and not is_base_tropical_scene:
		theme_name = resolved_biome

	super._ready()
	if _finish_setup_done:
		return
	_finish_setup_done = true
	if not custom_chunk_id.is_empty():
		chunk_id = custom_chunk_id
	elif theme_name == "bayou":
		chunk_id = "finish_line_bayou"
	elif theme_name == "brimstone":
		chunk_id = "finish_line_brimstone"
	else:
		chunk_id = "finish_line"

	if finish_trigger:
		if not finish_trigger.area_entered.is_connected(_on_finish_area_entered):
			finish_trigger.area_entered.connect(_on_finish_area_entered)
		if not finish_trigger.body_entered.is_connected(_on_finish_body_entered):
			finish_trigger.body_entered.connect(_on_finish_body_entered)

	_configure_finish_arch_for_level(cur_lvl, theme_name)
	_spawn_headland_scenery()
	_spawn_finish_wave()

func _configure_finish_arch_for_level(cur_lvl: int, biome: String) -> void:
	var entities: Node3D = get_node_or_null("Entities") as Node3D
	if not entities:
		return
	var finish_arch: Node3D = entities.get_node_or_null("FinishArch") as Node3D
	if not finish_arch:
		finish_arch = Node3D.new()
		finish_arch.name = "FinishArch"
		finish_arch.add_to_group("finish_landmark")
		entities.add_child(finish_arch)

	var arch_var: int = get_arch_variant(cur_lvl)

	if biome == "bayou":
		if arch_var == 0:
			# Variant 0 (e.g. Level 21): Withered Willow Canopy Arch & Painted Voodoo Totems
			active_arch_style = "bayou_willow_totem_canopy"
		elif arch_var == 1:
			# Variant 1 (e.g. Level 16, 22, 28): Ghost Shipwreck & Rustbound Anchor Sanctuary
			active_arch_style = "bayou_shipwreck_anchor_gate"
			var w_l: Node3D = finish_arch.get_node_or_null("WillowArch_Left") as Node3D
			var w_r: Node3D = finish_arch.get_node_or_null("WillowArch_Right") as Node3D
			if w_l:
				w_l.position = Vector3(-6.4, 1.5, -51.0)
			if w_r:
				w_r.position = Vector3(6.4, 1.5, -51.0)
			for side: float in [-1.0, 1.0]:
				if SHIP_WRECK_MODEL:
					var wreck: Node3D = SHIP_WRECK_MODEL.instantiate() as Node3D
					if wreck:
						wreck.name = "FinishWreck_%s" % ("L" if side < 0.0 else "R")
						finish_arch.add_child(wreck)
						wreck.position = Vector3(side * 5.6, 0.2, -50.0)
						wreck.rotation_degrees = Vector3(12.0, 35.0 * side, -26.0 * side)
						wreck.scale = Vector3.ONE * 1.35
		else:
			# Variant 2 (e.g. Level 17, 23, 26, 29): Emerald Mangrove & Ritual Totem Pier
			active_arch_style = "bayou_mangrove_ritual_arch"
			for side: float in [-1.0, 1.0]:
				if MANGROVE_MODEL:
					var grove: Node3D = MANGROVE_MODEL.instantiate() as Node3D
					if grove:
						grove.name = "MangroveArch_%s" % ("L" if side < 0.0 else "R")
						finish_arch.add_child(grove)
						grove.position = Vector3(side * 5.5, 1.4, -49.5)
						grove.rotation_degrees = Vector3(0.0, 90.0 * side, -20.0 * side)
						grove.scale = Vector3.ONE * 2.1
				if TOTEM_MODEL:
					var extra_totem: Node3D = TOTEM_MODEL.instantiate() as Node3D
					if extra_totem:
						extra_totem.name = "RitualTotemOuter_%s" % ("L" if side < 0.0 else "R")
						finish_arch.add_child(extra_totem)
						extra_totem.position = Vector3(side * 6.5, 1.2, -45.0)
						extra_totem.scale = Vector3.ONE * 1.65

	elif biome == "brimstone":
		var spire_l: Node3D = finish_arch.get_node_or_null("VolcanicSpire_ArchLeft") as Node3D
		var spire_r: Node3D = finish_arch.get_node_or_null("VolcanicSpire_ArchRight") as Node3D
		var crown_apex: Node3D = finish_arch.get_node_or_null("MoltenCrown_Apex") as Node3D
		var obs_l: Node3D = finish_arch.get_node_or_null("Obsidian_Left") as Node3D
		var obs_r: Node3D = finish_arch.get_node_or_null("Obsidian_Right") as Node3D

		if arch_var == 2:
			# Variant 2 (e.g. Level 34): Towering Volcanic Spire Hellgate & Floating Molten Crown Apex
			active_arch_style = "brimstone_spire_crown_hellgate"
			if spire_l:
				spire_l.position = Vector3(-5.7, 1.9, -50.0)
				spire_l.rotation_degrees = Vector3(0.0, 0.0, -22.0)
				spire_l.scale = Vector3(2.5, 3.1, 2.5)
			if spire_r:
				spire_r.position = Vector3(5.7, 1.9, -50.0)
				spire_r.rotation_degrees = Vector3(0.0, 180.0, 22.0)
				spire_r.scale = Vector3(2.5, 3.1, 2.5)
			if crown_apex:
				crown_apex.position = Vector3(0.0, 5.2, -50.0)
				crown_apex.scale = Vector3.ONE * 2.1
		elif arch_var == 1:
			# Variant 1 (e.g. Level 43): Abyssal Obsidian Crystal Rift Arch (Overarching Crystal Fangs)
			active_arch_style = "brimstone_obsidian_crystal_rift"
			if spire_l:
				spire_l.position = Vector3(-8.2, 1.6, -51.5)
				spire_l.rotation_degrees = Vector3(0.0, 15.0, -8.0)
				spire_l.scale = Vector3(1.8, 2.2, 1.8)
			if spire_r:
				spire_r.position = Vector3(8.2, 1.6, -51.5)
				spire_r.rotation_degrees = Vector3(0.0, -165.0, 8.0)
				spire_r.scale = Vector3(1.8, 2.2, 1.8)
			if obs_l:
				obs_l.position = Vector3(-5.2, 2.2, -50.0)
				obs_l.rotation_degrees = Vector3(0.0, 0.0, -34.0)
				obs_l.scale = Vector3(2.6, 3.0, 2.4)
			if obs_r:
				obs_r.position = Vector3(5.2, 2.2, -50.0)
				obs_r.rotation_degrees = Vector3(0.0, 180.0, 34.0)
				obs_r.scale = Vector3(2.6, 3.0, 2.4)
			if crown_apex:
				crown_apex.visible = false
			# Add overhanging upper crystal bridge clusters forming a jagged crystal cavern maw
			for side: float in [-1.0, 1.0]:
				if CRYSTAL_MODEL:
					var upper_crys: Node3D = CRYSTAL_MODEL.instantiate() as Node3D
					if upper_crys:
						upper_crys.name = "RiftCrystalUpper_%s" % ("L" if side < 0.0 else "R")
						finish_arch.add_child(upper_crys)
						upper_crys.position = Vector3(side * 2.4, 4.8, -50.0)
						upper_crys.rotation_degrees = Vector3(0.0, 0.0, -115.0 * side)
						upper_crys.scale = Vector3(1.9, 2.3, 1.9)
		else:
			# Variant 0 (e.g. Level 33, 36, 39, 42): Dreadflame Iron Bastion & Triple Molten Crown Gate
			active_arch_style = "brimstone_dreadflame_bastion"
			if crown_apex:
				crown_apex.position = Vector3(0.0, 4.8, -50.0)
				crown_apex.scale = Vector3.ONE * 1.75
			for side: float in [-1.0, 1.0]:
				if TOWER_LARGE_MODEL:
					var d_tower: Node3D = TOWER_LARGE_MODEL.instantiate() as Node3D
					if d_tower:
						d_tower.name = "DreadBastionTower_%s" % ("L" if side < 0.0 else "R")
						finish_arch.add_child(d_tower)
						d_tower.position = Vector3(side * 6.4, 0.0, -50.0)
						d_tower.scale = Vector3(1.3, 1.6, 1.3)

	else:
		# Tropical arch variants
		var gate_center: Node3D = finish_arch.get_node_or_null("GateCenter") as Node3D
		if arch_var == 0:
			active_arch_style = "tropical_corsair_fortress_arch"
		elif arch_var == 1:
			active_arch_style = "tropical_watchtower_harbor_pier"
			if gate_center:
				gate_center.scale = Vector3(2.6, 1.85, 1.8)
			for side: float in [-1.0, 1.0]:
				if TOWER_WATCH_MODEL:
					var w_tower: Node3D = TOWER_WATCH_MODEL.instantiate() as Node3D
					if w_tower:
						w_tower.name = "WatchTower_%s" % ("L" if side < 0.0 else "R")
						finish_arch.add_child(w_tower)
						w_tower.position = Vector3(side * 5.8, 0.0, -49.0)
						w_tower.scale = Vector3(1.5, 1.7, 1.5)
		else:
			active_arch_style = "tropical_shipwreck_citadel_gate"
			for side: float in [-1.0, 1.0]:
				if SHIP_WRECK_MODEL:
					var t_wreck: Node3D = SHIP_WRECK_MODEL.instantiate() as Node3D
					if t_wreck:
						t_wreck.name = "HarborWreck_%s" % ("L" if side < 0.0 else "R")
						finish_arch.add_child(t_wreck)
						t_wreck.position = Vector3(side * 6.4, 0.1, -45.0)
						t_wreck.rotation_degrees = Vector3(8.0, -25.0 * side, 18.0 * side)
						t_wreck.scale = Vector3.ONE * 1.25

func _spawn_finish_wave() -> void:
	var entities: Node = get_node_or_null("Entities")
	if not entities:
		return

	var cur_lvl: int = _resolve_active_level()
	var biome: String = _resolve_active_biome(cur_lvl)
	var wave_var: int = get_wave_variant(cur_lvl)

	# Remove static placeholder Guard* ships so each level & biome spawns a distinct ending formation
	for child: Node in entities.get_children():
		if child.name.begins_with("Guard"):
			entities.remove_child(child)
			child.queue_free()

	var finish_barricade: BarricadeWall = entities.get_node_or_null("FinishBarricade") as BarricadeWall

	if biome == "bayou":
		_spawn_bayou_finish_wave(entities, finish_barricade, cur_lvl, wave_var)
	elif biome == "brimstone":
		_spawn_brimstone_finish_wave(entities, finish_barricade, cur_lvl, wave_var)
	else:
		_spawn_tropical_finish_wave(entities, finish_barricade, cur_lvl, wave_var)

func _spawn_tropical_finish_wave(entities: Node, finish_barricade: BarricadeWall, cur_lvl: int, wave_var: int) -> void:
	var base_hp: int = 2 if cur_lvl <= 2 else (3 if cur_lvl <= 6 else (5 if cur_lvl <= 11 else 7))
	var base_spd: float = 1.6 if cur_lvl <= 2 else 2.2
	var hp_cap: int = 4 if cur_lvl <= 3 else 999

	if cur_lvl <= 1:
		active_wave_style = "tropical_intro_rowers"
		# Wave 1 (Z = -4 to -8): Immediate opening vanguard so there is zero empty space
		for lx: float in [-2.4, 0.0, 2.4]:
			_spawn_enemy_mob(entities, ROWER_DATA, Vector3(lx, 0.1, -5.0), 2, 1.6, 1)
		# Wave 2 (Z = -13 to -17): Staggered flanker line
		for lx2: float in [-3.0, -1.0, 1.0, 3.0]:
			_spawn_enemy_mob(entities, ROWER_DATA, Vector3(lx2, 0.1, -14.5), 1, 1.8, 0)
		# Wave 3 (Z = -21 to -25): Barricade vanguard before FinishBarricade at Z = -26
		for lx3: float in [-2.2, 0.0, 2.2]:
			_spawn_enemy_mob(entities, RAIDER_DATA, Vector3(lx3, 0.1, -22.0), 2, 2.0, 0)
		# Wave 4 (Z = -31 to -36): Final arch blockade right in front of FinishTrigger at Z = -38
		for lx4: float in [-2.8, -1.4, 0.0, 1.4, 2.8]:
			_spawn_enemy_mob(entities, ROWER_DATA, Vector3(lx4, 0.1, -33.5), 2, 1.8, 0)
		return

	# Wave 1 (Z = -4.0 to -9.5): Immediate Entry Swarm across all tropical finish variants (zero empty start!)
	var w1_lanes: Array[float] = [-3.0, -1.5, 0.0, 1.5, 3.0]
	if wave_var % 2 != 0:
		w1_lanes = [-3.2, -1.8, -0.6, 0.6, 1.8, 3.2]
	for i: int in range(w1_lanes.size()):
		var w1_z: float = -4.5 - float(i % 3) * 1.6
		var w1_data: Resource = ROWER_DATA if i % 2 == 0 else RAIDER_DATA
		_spawn_enemy_mob(entities, w1_data, Vector3(w1_lanes[i], 0.1, w1_z), mini(base_hp, hp_cap), base_spd + 0.4, 1 if i < 2 else 0)

	match wave_var:
		0:
			# Variant 0 (e.g. L4, L8, L12): Harbor Barricade + 4-Wave Raider & Rower Assault
			active_wave_style = "tropical_barricade_raiders"
			# Wave 2 (Z = -13 to -18): Raider Flank Pincer
			for rx: float in [-2.8, -1.0, 1.0, 2.8]:
				_spawn_enemy_mob(entities, RAIDER_DATA, Vector3(rx, 0.1, -15.0 - (1.5 if absf(rx) > 2.0 else 0.0)), mini(base_hp + 1, hp_cap), base_spd + 0.5, 1)
			# Wave 3 (Z = -21 to -24, in front of FinishBarricade at -26): Heavy Shield Line
			for sx: float in [-2.2, 0.0, 2.2]:
				_spawn_enemy_mob(entities, TURTLE_DATA if cur_lvl >= 6 else RAIDER_DATA, Vector3(sx, 0.1, -22.0), mini(base_hp + 2, hp_cap), base_spd, 1)
			# Wave 4 (Z = -31 to -36.5, behind FinishBarricade right before Arch): Final Arch Swarm
			var w4_x0: Array[float] = [-3.2, -1.6, 0.0, 1.6, 3.2]
			for j: int in range(w4_x0.size()):
				_spawn_enemy_mob(entities, RAIDER_DATA if j % 2 == 0 else ROWER_DATA, Vector3(w4_x0[j], 0.1, -32.0 - float(j % 2) * 2.2), mini(base_hp, hp_cap), base_spd + 0.6, 0)
		1:
			# Variant 1 (e.g. L9, L13): Open-Channel Raider V-Spearhead + Explosive Kegs (No Barricade Wall)
			active_wave_style = "tropical_raider_v_spearhead"
			if finish_barricade:
				entities.remove_child(finish_barricade)
				finish_barricade.queue_free()
			# Wave 2 (Z = -12 to -19): V-Spearhead
			var v_spawns: Array[Vector3] = [
				Vector3(0.0, 0.1, -12.5),
				Vector3(-1.6, 0.1, -15.5),
				Vector3(1.6, 0.1, -15.5),
				Vector3(-3.0, 0.1, -18.5),
				Vector3(3.0, 0.1, -18.5),
			]
			for pos: Vector3 in v_spawns:
				_spawn_enemy_mob(entities, RAIDER_DATA, pos, mini(base_hp, hp_cap), base_spd + 0.5, 1)
			for kx: float in [-1.8, 1.8]:
				_spawn_barrel(entities, Vector3(kx, 0.05, -22.0), DestructibleObstacle.ObstacleType.FUSE_BARREL, 2)
			# Wave 3 (Z = -24 to -29): Tide Cutter & Raider Rush
			for cx1: float in [-2.4, 2.4]:
				var cutter1: Area3D = TIDE_CUTTER_SCENE.instantiate() as Area3D
				if cutter1:
					entities.add_child(cutter1)
					cutter1.position = Vector3(cx1, 0.1, -25.5)
			for mx: float in [-1.0, 0.0, 1.0]:
				_spawn_enemy_mob(entities, RAIDER_DATA, Vector3(mx * 1.4, 0.1, -28.0), mini(base_hp + 1, hp_cap), base_spd + 0.6, 0)
			# Wave 4 (Z = -32 to -36.5): Final Arch Blitz
			for ax: float in [-3.3, -2.2, -1.1, 0.0, 1.1, 2.2, 3.3]:
				_spawn_enemy_mob(entities, RAIDER_DATA, Vector3(ax, 0.1, -33.0 - (2.0 if absf(ax) < 1.5 else 0.0)), mini(base_hp, hp_cap), base_spd + 0.7, 0)
		2:
			# Variant 2 (e.g. L2, L6, L14): Armored Turtle Prow + Fast Tide Cutter Flankers
			active_wave_style = "tropical_turtle_and_cutters"
			if finish_barricade and cur_lvl > 3:
				finish_barricade.x_points = [-0.8, 0.8]
			# Wave 2 (Z = -13 to -19): Armored Prow + Cutter Escorts
			_spawn_enemy_mob(entities, TURTLE_DATA, Vector3(0.0, 0.1, -14.0), mini(base_hp + 2, hp_cap), 1.5, 2)
			for cx: float in [-2.4, 2.4]:
				var cutter: Area3D = TIDE_CUTTER_SCENE.instantiate() as Area3D
				if cutter:
					entities.add_child(cutter)
					cutter.position = Vector3(cx, 0.1, -17.5)
			for rx2: float in [-1.2, 1.2]:
				_spawn_enemy_mob(entities, RAIDER_DATA, Vector3(rx2, 0.1, -21.0), mini(base_hp, hp_cap), base_spd + 0.4, 0)
			# Wave 3 & 4 (Z = -29 to -36.5): Post-barricade swarm in front of Arch
			var w4_x2: Array[float] = [-3.0, -1.8, -0.6, 0.6, 1.8, 3.0]
			for k: int in range(w4_x2.size()):
				var z_k: float = -30.5 - float(k % 3) * 2.2
				_spawn_enemy_mob(entities, RAIDER_DATA if k % 2 == 0 else ROWER_DATA, Vector3(w4_x2[k], 0.1, z_k), mini(base_hp, hp_cap), base_spd + 0.5, 0)
		_:
			# Variant 3 (e.g. L3, L7, L11): Corsair Flagship & Escort Line
			active_wave_style = "tropical_flagship_escort"
			# Wave 2 (Z = -12 to -18): Escort Line + Flagship
			for rx: float in [-2.6, -1.0, 1.0, 2.6]:
				_spawn_enemy_mob(entities, RAIDER_DATA, Vector3(rx, 0.1, -13.0 - (2.0 if absf(rx) < 1.5 else 0.0)), mini(base_hp, hp_cap), base_spd + 0.3, 1)
			_spawn_enemy_mob(entities, ELITE_IRONCLAD_DATA if cur_lvl >= 7 else TURTLE_DATA, Vector3(0.0, 0.1, -20.5), mini(base_hp + 3, hp_cap), 1.5, 2)
			# Wave 3 & 4 (Z = -29 to -36.5): Final Arch Guard Armada
			var w4_x3: Array[float] = [-3.2, -2.0, -0.8, 0.8, 2.0, 3.2]
			for m: int in range(w4_x3.size()):
				var z_m: float = -30.5 - float(m % 2) * 3.5
				_spawn_enemy_mob(entities, RAIDER_DATA, Vector3(w4_x3[m], 0.1, z_m), mini(base_hp, hp_cap), base_spd + 0.5, 0)

func _spawn_bayou_finish_wave(entities: Node, finish_barricade: BarricadeWall, cur_lvl: int, wave_var: int) -> void:
	var ghost_hp: int = 8 + int((cur_lvl - 15) * 0.6)
	var skiff_hp: int = 12 + int((cur_lvl - 15) * 0.8)

	# Wave 1 (Z = -4.0 to -9.5): Immediate Bayou Swarm at chunk start (eliminates empty space!)
	var w1_lanes: Array[float] = [-3.2, -1.6, 0.0, 1.6, 3.2]
	if wave_var % 2 != 0:
		w1_lanes = [-3.0, -1.8, -0.6, 0.6, 1.8, 3.0]
	for i: int in range(w1_lanes.size()):
		var z1: float = -4.5 - float(i % 3) * 1.8
		if i % 2 == 1:
			_spawn_grave_skiff(entities, Vector3(w1_lanes[i], 0.1, z1), skiff_hp, 2.6)
		else:
			_spawn_enemy_mob(entities, GHOST_DATA, Vector3(w1_lanes[i], 0.1, z1), ghost_hp, 2.5, 1)

	match wave_var:
		1:
			# Variant 1 (e.g. Level 21, 17, 29): Serpent's Nest Spectral Ghost Armada & Tide Cutters (No 5-log barricade)
			active_wave_style = "bayou_spectral_ghost_armada"
			if finish_barricade:
				entities.remove_child(finish_barricade)
				finish_barricade.queue_free()
			# Wave 2 (Z = -12.5 to -18.5): Spectral Ghost Armada
			var ghost_positions: Array[Vector3] = [
				Vector3(0.0, 0.1, -12.5),
				Vector3(-2.6, 0.1, -15.5),
				Vector3(2.6, 0.1, -15.5),
				Vector3(-1.3, 0.1, -18.0),
				Vector3(1.3, 0.1, -18.0),
			]
			for g_pos: Vector3 in ghost_positions:
				_spawn_enemy_mob(entities, GHOST_DATA, g_pos, ghost_hp, 2.4, 2)
			for bx: float in [-3.2, 0.0, 3.2]:
				if BIOGAS_POD_SCENE:
					var pod: Node3D = BIOGAS_POD_SCENE.instantiate() as Node3D
					if pod:
						entities.add_child(pod)
						pod.position = Vector3(bx, 0.05, -21.0)
			# Wave 3 (Z = -23.5 to -28.5): Tide Cutters & Grave Skiffs
			for cx: float in [-2.2, 2.2]:
				var cutter: Area3D = TIDE_CUTTER_SCENE.instantiate() as Area3D
				if cutter:
					entities.add_child(cutter)
					cutter.position = Vector3(cx, 0.1, -24.5)
			for gx1: float in [-1.2, 0.0, 1.2]:
				_spawn_grave_skiff(entities, Vector3(gx1 * 1.5, 0.1, -28.0), skiff_hp, 2.6)
			# Wave 4 (Z = -32.0 to -36.5): Final Arch Spectral Wall
			for ax1: float in [-3.3, -2.0, -0.7, 0.7, 2.0, 3.3]:
				_spawn_enemy_mob(entities, GHOST_DATA, Vector3(ax1, 0.1, -33.0 - (2.2 if absf(ax1) < 1.5 else 0.0)), ghost_hp, 2.8, 0)
		2:
			# Variant 2 (e.g. Level 18, 22, 26): Bayou Harvester Dread-Guard & Grave Skiffs
			active_wave_style = "bayou_harvester_dread_guard"
			if finish_barricade:
				entities.remove_child(finish_barricade)
				finish_barricade.queue_free()
			# Wave 2 (Z = -13 to -19): Grave Skiff Escort Screen
			for gx: float in [-3.0, -1.2, 1.2, 3.0]:
				_spawn_grave_skiff(entities, Vector3(gx, 0.1, -14.0 - (2.0 if absf(gx) < 2.0 else 0.0)), skiff_hp, 2.4)
			# Wave 3 (Z = -22 to -27): Harvester Dread-Guard + Ghost Flankers
			if HARVESTER_SCENE:
				var harv: Area3D = HARVESTER_SCENE.instantiate() as Area3D
				if harv:
					entities.add_child(harv)
					harv.position = Vector3(0.0, 0.1, -23.5)
					harv.set("max_hp", 42 + (cur_lvl - 15) * 2)
					harv.set("current_hp", 42 + (cur_lvl - 15) * 2)
			for fx: float in [-2.8, 2.8]:
				_spawn_enemy_mob(entities, GHOST_DATA, Vector3(fx, 0.1, -26.5), ghost_hp, 2.5, 1)
			# Wave 4 (Z = -31.5 to -36.5): Final Arch Swamp Blitz
			for ax2: float in [-3.2, -1.8, -0.6, 0.6, 1.8, 3.2]:
				_spawn_grave_skiff(entities, Vector3(ax2, 0.1, -32.5 - (2.5 if absf(ax2) > 2.0 else 0.0)), skiff_hp, 2.8)
		0:
			# Variant 0 (e.g. Level 16, 24, 28): Split Bayou Barricade + Grave Skiff Dart Battery + Biogas Spores
			active_wave_style = "bayou_grave_skiff_battery"
			# Wave 2 (Z = -13 to -18): Grave Skiff Battery
			for gx: float in [-2.8, -1.0, 1.0, 2.8]:
				_spawn_grave_skiff(entities, Vector3(gx, 0.1, -14.5 - (1.8 if absf(gx) < 1.5 else 0.0)), skiff_hp, 2.3)
			# Wave 3 (Z = -21 to -24, in front of FinishBarricade at -26): Ghost Sloops + Biogas
			for g0: float in [-2.2, 0.0, 2.2]:
				_spawn_enemy_mob(entities, GHOST_DATA, Vector3(g0, 0.1, -21.5), ghost_hp, 2.2, 1)
			for bx: float in [-1.8, 1.8]:
				if BIOGAS_POD_SCENE:
					var pod: Node3D = BIOGAS_POD_SCENE.instantiate() as Node3D
					if pod:
						entities.add_child(pod)
						pod.position = Vector3(bx, 0.05, -29.0)
			# Wave 4 (Z = -31.5 to -36.5, behind FinishBarricade): Final Arch Blockade
			for ax0: float in [-3.0, -1.5, 0.0, 1.5, 3.0]:
				_spawn_grave_skiff(entities, Vector3(ax0, 0.1, -33.0 - (2.0 if absf(ax0) < 1.0 else 0.0)), skiff_hp, 2.6)
		_:
			# Variant 3 (e.g. Level 19, 23, 27): Twin Ghost Sloops & Grave Skiff Pincer
			active_wave_style = "bayou_ghost_and_grave_pincer"
			if finish_barricade:
				entities.remove_child(finish_barricade)
				finish_barricade.queue_free()
			# Wave 2 (Z = -13 to -18): Ghost Sloop Line
			for gx: float in [-2.8, -0.9, 0.9, 2.8]:
				_spawn_enemy_mob(entities, GHOST_DATA, Vector3(gx, 0.1, -14.0 - (2.0 if absf(gx) < 1.5 else 0.0)), ghost_hp, 2.4, 2)
			# Wave 3 (Z = -22 to -27): Grave Skiff Pincer + Cutters
			for sx: float in [-3.2, 0.0, 3.2]:
				_spawn_grave_skiff(entities, Vector3(sx, 0.1, -23.0), skiff_hp, 2.5)
			for cx3: float in [-1.8, 1.8]:
				var cutter3: Area3D = TIDE_CUTTER_SCENE.instantiate() as Area3D
				if cutter3:
					entities.add_child(cutter3)
					cutter3.position = Vector3(cx3, 0.1, -27.0)
			# Wave 4 (Z = -31.5 to -36.5): Final Arch Horde
			for ax3: float in [-3.3, -2.2, -1.1, 0.0, 1.1, 2.2, 3.3]:
				_spawn_enemy_mob(entities, GHOST_DATA, Vector3(ax3, 0.1, -32.5 - (2.5 if absf(ax3) < 1.5 else 0.0)), ghost_hp, 2.7, 0)

func _spawn_brimstone_finish_wave(entities: Node, finish_barricade: BarricadeWall, cur_lvl: int, wave_var: int) -> void:
	var gunner_hp: int = 24 + (cur_lvl - 30) * 2
	var raft_hp: int = 12 + int((cur_lvl - 30) * 0.8)

	# Wave 1 (Z = -4.0 to -9.5): Immediate Brimstone Blitz at chunk start (zero empty space!)
	var w1_lanes: Array[float] = [-3.3, -1.8, -0.5, 0.5, 1.8, 3.3]
	if wave_var % 2 != 0:
		w1_lanes = [-3.2, -1.6, 0.0, 1.6, 3.2]
	for i: int in range(w1_lanes.size()):
		var z1: float = -4.5 - float(i % 3) * 1.8
		if i % 2 == 0:
			_spawn_brimstone_raft(entities, Vector3(w1_lanes[i], 0.1, z1), raft_hp, 4.4)
		else:
			_spawn_iron_gunner(entities, Vector3(w1_lanes[i], 0.1, z1), gunner_hp, 2.4)

	match wave_var:
		2:
			# Variant 2 (e.g. Level 34, 38, 42): Obsidian Strait Bombard Siege & Thermal Geysers
			active_wave_style = "brimstone_bombard_siege_blockade"
			if finish_barricade:
				entities.remove_child(finish_barricade)
				finish_barricade.queue_free()
			# Wave 2 (Z = -13 to -18): Iron Gunner & Raft Screen
			for gx: float in [-2.8, 2.8]:
				_spawn_iron_gunner(entities, Vector3(gx, 0.1, -13.5), gunner_hp, 2.2)
			for rx2: float in [-1.2, 0.0, 1.2]:
				_spawn_brimstone_raft(entities, Vector3(rx2 * 1.3, 0.1, -16.5), raft_hp, 4.5)
			# Wave 3 (Z = -21 to -27): Heavy Bombard Siege + Thermal Geysers
			if BOMBARD_SCENE:
				var bombard: Area3D = BOMBARD_SCENE.instantiate() as Area3D
				if bombard:
					entities.add_child(bombard)
					bombard.position = Vector3(0.0, 0.1, -22.5)
					bombard.set("max_hp", 55 + (cur_lvl - 30) * 3)
					bombard.set("current_hp", 55 + (cur_lvl - 30) * 3)
			for tx: float in [-2.2, 2.2]:
				if THERMAL_GEYSER_SCENE:
					var geyser: Node3D = THERMAL_GEYSER_SCENE.instantiate() as Node3D
					if geyser:
						entities.add_child(geyser)
						geyser.position = Vector3(tx, 0.0, -25.0)
			for gx3: float in [-3.0, 3.0]:
				_spawn_iron_gunner(entities, Vector3(gx3, 0.1, -27.5), gunner_hp, 2.3)
			# Wave 4 (Z = -31.5 to -36.5): Final Arch Kamikaze Wall
			for ax2: float in [-3.3, -2.0, -0.7, 0.7, 2.0, 3.3]:
				_spawn_brimstone_raft(entities, Vector3(ax2, 0.1, -32.5 - (2.5 if absf(ax2) < 1.5 else 0.0)), raft_hp, 4.8)
		3:
			# Variant 3 (e.g. Level 43, 31, 39): Abyssal Rift Brimstone Kamikaze Blitz & Dreadnought Flagship
			active_wave_style = "brimstone_kamikaze_diamond_blitz"
			if finish_barricade:
				entities.remove_child(finish_barricade)
				finish_barricade.queue_free()
			# Wave 2 (Z = -12.5 to -18.5): Kamikaze Diamond Blitz
			var raft_coords: Array[Vector3] = [
				Vector3(-1.3, 0.1, -12.5),
				Vector3(1.3, 0.1, -12.5),
				Vector3(0.0, 0.1, -15.0),
				Vector3(-3.0, 0.1, -17.5),
				Vector3(3.0, 0.1, -17.5),
			]
			for r_pos: Vector3 in raft_coords:
				_spawn_brimstone_raft(entities, r_pos, raft_hp, 4.6)
			# Wave 3 (Z = -21.5 to -27.5): Dreadnought Flagship + Gunner Escorts + Kegs
			_spawn_enemy_mob(entities, ELITE_IRONCLAD_DATA, Vector3(0.0, 0.1, -22.5), 38 + (cur_lvl - 30) * 2, 1.8, 5)
			for gx3: float in [-2.6, 2.6]:
				_spawn_iron_gunner(entities, Vector3(gx3, 0.1, -25.5), gunner_hp, 2.3)
			for kx: float in [-1.8, 1.8]:
				_spawn_barrel(entities, Vector3(kx, 0.05, -28.0), DestructibleObstacle.ObstacleType.FUSE_BARREL, 3)
			# Wave 4 (Z = -31.5 to -36.5): Final Arch Hellgate Swarm
			for ax3: float in [-3.4, -2.3, -1.2, 0.0, 1.2, 2.3, 3.4]:
				_spawn_brimstone_raft(entities, Vector3(ax3, 0.1, -32.5 - (2.2 if absf(ax3) < 1.5 else 0.0)), raft_hp, 4.9)
		0:
			# Variant 0 (e.g. Level 32, 36, 44): Volcanic Barricade + Twin Iron Gunners + Brimstone Outriders
			active_wave_style = "brimstone_gunner_fortress_wall"
			# Wave 2 (Z = -13 to -18): Twin Iron Gunners + Brimstone Outriders
			for gx: float in [-2.6, 2.6]:
				_spawn_iron_gunner(entities, Vector3(gx, 0.1, -14.0), gunner_hp, 2.2)
			for rx0: float in [-1.2, 0.0, 1.2]:
				_spawn_brimstone_raft(entities, Vector3(rx0 * 1.4, 0.1, -17.5), raft_hp, 4.4)
			# Wave 3 (Z = -21 to -24, in front of FinishBarricade at -26): Armored Guard Line
			for gx0: float in [-2.2, 0.0, 2.2]:
				_spawn_enemy_mob(entities, ELITE_IRONCLAD_DATA, Vector3(gx0, 0.1, -22.0), 28 + (cur_lvl - 30) * 2, 2.0, 2)
			# Wave 4 (Z = -31.5 to -36.5, behind FinishBarricade): Final Arch Blockade
			for ax0: float in [-3.2, -1.8, -0.6, 0.6, 1.8, 3.2]:
				_spawn_brimstone_raft(entities, Vector3(ax0, 0.1, -32.5 - (2.2 if absf(ax0) > 1.5 else 0.0)), raft_hp, 4.6)
		_:
			# Variant 1 (e.g. Level 33, 37, 41): Magma Artillery Triangle & Geyser Vent
			active_wave_style = "brimstone_artillery_triangle"
			if finish_barricade:
				entities.remove_child(finish_barricade)
				finish_barricade.queue_free()
			# Wave 2 (Z = -13 to -18.5): Magma Artillery Triangle
			for gx: float in [-2.8, 0.0, 2.8]:
				var z_off: float = -17.5 if absf(gx) < 0.1 else -13.5
				_spawn_iron_gunner(entities, Vector3(gx, 0.1, z_off), gunner_hp, 2.2)
			# Wave 3 (Z = -21.5 to -27.5): Brimstone Outriders + Geyser Vent
			for rx: float in [-2.8, -1.4, 1.4, 2.8]:
				_spawn_brimstone_raft(entities, Vector3(rx, 0.1, -23.0 - (2.0 if absf(rx) > 2.0 else 0.0)), raft_hp, 4.5)
			if THERMAL_GEYSER_SCENE:
				var geyser: Node3D = THERMAL_GEYSER_SCENE.instantiate() as Node3D
				if geyser:
					entities.add_child(geyser)
					geyser.position = Vector3(0.0, 0.0, -25.5)
			# Wave 4 (Z = -31.5 to -36.5): Final Arch Inferno Swarm
			for ax1: float in [-3.2, -1.6, 0.0, 1.6, 3.2]:
				_spawn_iron_gunner(entities, Vector3(ax1, 0.1, -32.5) if absf(ax1) > 2.0 else Vector3(ax1, 0.1, -35.0), gunner_hp, 2.4)
			for rx_end: float in [-2.4, -0.8, 0.8, 2.4]:
				_spawn_brimstone_raft(entities, Vector3(rx_end, 0.1, -36.0), raft_hp, 4.7)

func _spawn_enemy_mob(entities: Node, data: Resource, pos: Vector3, hp_val: int, spd: float, drop_val: int) -> void:
	if not ENEMY_MOB_SCENE:
		return
	var mob: Area3D = ENEMY_MOB_SCENE.instantiate() as Area3D
	if not mob:
		return
	entities.add_child(mob)
	mob.position = pos
	if mob.has_method("apply_enemy_data") and data:
		mob.call("apply_enemy_data", data)
	mob.set("max_hp", hp_val)
	mob.set("current_hp", hp_val)
	mob.set("forward_speed", spd)
	var final_drop: int = drop_val
	if _resolve_active_level() == 1 and final_drop > 0:
		if _l1_coin_mobs_spawned >= 5:
			final_drop = 0
		else:
			_l1_coin_mobs_spawned += 1
	mob.set("doubloons_drop", final_drop)

func _spawn_grave_skiff(entities: Node, pos: Vector3, hp_val: int, spd: float) -> void:
	if not GRAVE_SKIFF_SCENE:
		return
	var skiff: Area3D = GRAVE_SKIFF_SCENE.instantiate() as Area3D
	if not skiff:
		return
	entities.add_child(skiff)
	skiff.position = pos
	skiff.set("max_hp", hp_val)
	skiff.set("current_hp", hp_val)
	skiff.set("forward_speed", spd)

func _spawn_iron_gunner(entities: Node, pos: Vector3, hp_val: int, spd: float) -> void:
	if not IRON_GUNNER_SCENE:
		return
	var gunner: Area3D = IRON_GUNNER_SCENE.instantiate() as Area3D
	if not gunner:
		return
	entities.add_child(gunner)
	gunner.position = pos
	gunner.set("max_hp", hp_val)
	gunner.set("current_hp", hp_val)
	gunner.set("forward_speed", spd)

func _spawn_brimstone_raft(entities: Node, pos: Vector3, hp_val: int, spd: float) -> void:
	if not BRIMSTONE_RAFT_SCENE:
		return
	var raft: Area3D = BRIMSTONE_RAFT_SCENE.instantiate() as Area3D
	if not raft:
		return
	entities.add_child(raft)
	raft.position = pos
	raft.set("max_hp", hp_val)
	raft.set("current_hp", hp_val)
	raft.set("forward_speed", spd)

func _spawn_barrel(entities: Node, pos: Vector3, obs_type: int, hp_val: int) -> void:
	if not BARREL_SCENE:
		return
	var barrel: DestructibleObstacle = BARREL_SCENE.instantiate() as DestructibleObstacle
	if not barrel:
		return
	entities.add_child(barrel)
	barrel.position = pos
	barrel.hp = hp_val
	barrel.obstacle_type = obs_type as DestructibleObstacle.ObstacleType

func _on_finish_area_entered(area: Area3D) -> void:
	if _is_finished:
		return
	if area.is_in_group("player") or (area.get_parent() and area.get_parent().is_in_group("player")):
		_trigger_victory()

func _on_finish_body_entered(body: Node3D) -> void:
	if _is_finished:
		return
	if body.is_in_group("player") or (body.get_parent() and body.get_parent().is_in_group("player")):
		_trigger_victory()

func _spawn_headland_scenery() -> void:
	var entities: Node3D = get_node_or_null("Entities") as Node3D
	if not entities:
		return

	var headlands: Node3D = Node3D.new()
	headlands.name = "HeadlandsBehindArch"
	headlands.add_to_group("finish_landmark")
	entities.add_child(headlands)

	# Flank channel behind the arch with coastal rock headlands and watchtowers (Z from -54 to -82)
	var z_slots: Array[float] = [-54.0, -62.0, -70.0, -78.0]
	for z_pos: float in z_slots:
		for side: float in [-1.0, 1.0]:
			if ROCKS_MODEL:
				var rock: Node3D = ROCKS_MODEL.instantiate() as Node3D
				if rock:
					headlands.add_child(rock)
					rock.position = Vector3(side * 10.0, 0.0, z_pos)
					rock.rotation_degrees = Vector3(0.0, randf_range(0.0, 360.0), 0.0)
					rock.scale = Vector3.ONE * 2.0
			if TOWER_WATCH_MODEL and absf(z_pos - (-62.0)) < 1.0:
				var tower: Node3D = TOWER_WATCH_MODEL.instantiate() as Node3D
				if tower:
					headlands.add_child(tower)
					tower.position = Vector3(side * 12.0, 0.0, z_pos)
					tower.scale = Vector3.ONE * 1.25

func _trigger_victory() -> void:
	if _is_finished:
		return
	_is_finished = true
	
	if AudioManager:
		AudioManager.play_sfx("gate_passes")
		if theme_name == "brimstone":
			AudioManager.play_sfx("sfx_mine_detonate")
		elif theme_name == "bayou":
			AudioManager.play_sfx("water_splashes")
		else:
			AudioManager.play_sfx("barrel_breaks")
		
	_spawn_celebration_effects()
	
	# Stop track scrolling immediately so the arch stops sinking down towards the player
	var assembler: Node = get_tree().get_first_node_in_group("chunk_assembler")
	var track_mgr: Node = get_tree().get_first_node_in_group("track_manager")
	if assembler and "scroll_speed" in assembler:
		assembler.set("scroll_speed", 0.0)
	if track_mgr and "scroll_speed" in track_mgr:
		track_mgr.set("scroll_speed", 0.0)

	# Animate the player vessel sailing FORWARD (up the screen) through the arch
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	if is_instance_valid(player):
		if "is_shooting_enabled" in player:
			player.set("is_shooting_enabled", false)
		var move_comp: Node = player.get_node_or_null("PlayerMovement")
		if move_comp and "process_mode" in move_comp:
			move_comp.process_mode = Node.PROCESS_MODE_DISABLED

		var sail_tween: Tween = player.create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		sail_tween.tween_property(player, "position:x", 0.0, 1.2)
		var arch_z: float = global_position.z - 50.0
		var target_z: float = arch_z - 8.0
		sail_tween.tween_property(player, "global_position:z", target_z, 1.5)
	
	# Delay for fireworks & celebratory sail before victory settlement
	get_tree().create_timer(1.5, true, false, true).timeout.connect(func() -> void:
		EventBus.level_completed.emit(GameState.doubloons, GameState.targets_destroyed)
	)

func _spawn_celebration_effects() -> void:
	var root: Node = get_tree().current_scene
	var spawn_parent: Node = root if root else self
	
	var burst_count: int = 12 if theme_name == "tropical" else (16 if theme_name == "bayou" else 20)
	var coin_count: int = 15 if theme_name == "tropical" else 18
	
	# Spawn coin fountain & firework bursts across the gate arch
	for i: int in range(burst_count):
		if explosion_scene:
			var vfx := explosion_scene.instantiate() as Node3D
			if vfx:
				spawn_parent.add_child(vfx)
				var spread_y: float = randf_range(2.0, 6.0) if theme_name != "brimstone" else randf_range(2.5, 7.5)
				var offset := Vector3(randf_range(-5.5, 5.5), spread_y, global_position.z - 50.0 + randf_range(-1.5, 1.5))
				vfx.global_position = offset
			
	if doubloon_scene:
		for d_i: int in range(coin_count):
			var d := doubloon_scene.instantiate() as CollectibleDoubloon
			if d:
				spawn_parent.add_child(d)
				d.global_position = Vector3(randf_range(-4.5, 4.5), 0.2, global_position.z - 50.0)
				d._trigger_spawn_bounce(Vector2(randf_range(-2.5, 2.5), randf_range(-2.5, 2.5)))
