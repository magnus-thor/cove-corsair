extends Node

## Global GameState / ScoreManager Autoload for Cove Corsair

signal doubloons_changed(new_amount: int)
signal multiplier_changed(new_multiplier: float, mode: String)
signal progress_changed(current_distance: float, total_distance: float)
@warning_ignore("unused_signal")
signal distance_target_reached
@warning_ignore("unused_signal")
signal level_completed(doubloons: int, targets: int)
@warning_ignore("unused_signal")
signal campaign_completed(total_doubloons: int, total_targets: int)
@warning_ignore("unused_signal")
signal boss_spawned_event(boss_name: String, max_val: int)
@warning_ignore("unused_signal")
signal boss_health_changed(current: int, max_val: int)
signal active_vessel_changed(vessel_id: String)

const SAVE_PATH: String = "user://cove_corsair_save.json"

# Persistent Economy & Fleet State
var doubloons: int = 0
var owned_vessels: Array[String] = ["dinghy"]
var vessel_tiers: Dictionary = {
	"dinghy": 1,
	"sloop": 1,
	"ironclad": 1
}
var active_vessel: String = "dinghy"
var unlocked_levels: int = 3

# Persistent Audio Preferences
var master_volume: float = 1.0
var music_volume: float = 1.0
var sfx_volume: float = 1.0
var master_muted: bool = false
var music_muted: bool = false
var sfx_muted: bool = false

# In-Run Transient State
var run_doubloons: int = 0
var targets_destroyed: int = 0
var active_multiplier: float = 1.0
var multiplier_mode: String = "x" # "x" for multiply, "+" for add
var current_level: int = 1
var level_distance_target: float = 250.0 # meters / units to reach boss or finish
var distance_traveled: float = 0.0
var is_game_active: bool = false
var boss_spawned: bool = false
var should_auto_start: bool = false

const VESSEL_CATALOG: Dictionary = {
	"dinghy": {
		"id": "dinghy",
		"name": "The Dinghy",
		"archetype": "Agility Skiff",
		"resource_path": "res://src/data/resources/user_vessels/dinghy_ship.tres",
		"purchase_price": 0,
		"tier_prices": { 2: 75, 3: 200 },
		"tier_descriptions": {
			1: "Bow Chaser Cannon",
			2: "Bow Chaser + Monkey Bomber",
			3: "Bow Chaser + Monkey Bomber + Skeleton Tosser"
		},
		"base_hp": 1,
		"base_speed": 12.0,
		"fire_rate": 0.20,
		"preview_texture": "res://assets/sprites/user_vessels/The Dinghy.png"
	},
	"sloop": {
		"id": "sloop",
		"name": "The Sloop",
		"archetype": "Balanced Standard",
		"resource_path": "res://src/data/resources/user_vessels/sloop_ship.tres",
		"purchase_price": 450,
		"tier_prices": { 2: 600, 3: 900 },
		"tier_descriptions": {
			1: "Bow Chaser Cannon",
			2: "Bow Chaser + Monkey Bomber + Skeleton Tosser",
			3: "Bow Chaser + Monkey Bomber + Skeleton Tosser + Port & Starboard Swivel Guns"
		},
		"base_hp": 5,
		"base_speed": 11.0,
		"fire_rate": 0.16,
		"preview_texture": "res://assets/sprites/user_vessels/The Sloop.png"
	},
	"ironclad": {
		"id": "ironclad",
		"name": "The Ironclad",
		"archetype": "Armored Brawler",
		"resource_path": "res://src/data/resources/user_vessels/ironclad_ship.tres",
		"purchase_price": 1200,
		"tier_prices": { 2: 1500, 3: 2000 },
		"tier_descriptions": {
			1: "Heavy Frontal Cannon Battery",
			2: "Heavy Battery + Monkey Bomber + Skeleton Tosser",
			3: "Heavy Battery + Monkey + Skeleton + Quad Swivel Gun Battery"
		},
		"base_hp": 8,
		"base_speed": 7.5,
		"fire_rate": 0.15,
		"preview_texture": "res://assets/sprites/user_vessels/The Ironclad.png"
	}
}

const LEVEL_RESOURCES: Dictionary = {
	1: "res://src/data/resources/levels/level_01_smugglers_run.tres",
	2: "res://src/data/resources/levels/level_02_black_tide_bayou.tres",
	3: "res://src/data/resources/levels/level_03_brimstone_bastion.tres",
	4: "res://src/data/resources/levels/level_04_smugglers_nightmare.tres",
	5: "res://src/data/resources/levels/level_05_black_tide_abyss.tres",
	6: "res://src/data/resources/levels/level_06_brimstone_inferno.tres"
}

const LEVEL_SHIPS: Dictionary = {
	1: "res://src/data/resources/user_vessels/dinghy_ship.tres",
	2: "res://src/data/resources/user_vessels/sloop_ship.tres",
	3: "res://src/data/resources/user_vessels/ironclad_ship.tres",
	4: "res://src/data/resources/user_vessels/dinghy_ship.tres",
	5: "res://src/data/resources/user_vessels/sloop_ship.tres",
	6: "res://src/data/resources/user_vessels/ironclad_ship.tres"
}

func _ready() -> void:
	load_game()
	apply_audio_settings()

func apply_audio_settings() -> void:
	if not AudioManager:
		return
	if AudioManager.has_method("set_bus_volume"):
		AudioManager.set_bus_volume("Master", master_volume)
		AudioManager.set_bus_volume("BGM", music_volume)
		AudioManager.set_bus_volume("SFX", sfx_volume)
	if AudioManager.has_method("set_bus_muted"):
		AudioManager.set_bus_muted("Master", master_muted)
		AudioManager.set_bus_muted("BGM", music_muted)
		AudioManager.set_bus_muted("SFX", sfx_muted)

func get_current_level_resource() -> LevelData:
	var path = LEVEL_RESOURCES.get(current_level, LEVEL_RESOURCES[1])
	if ResourceLoader.exists(path):
		return load(path) as LevelData
	return null

func get_active_ship_resource() -> ShipData:
	if active_vessel in VESSEL_CATALOG:
		var path = VESSEL_CATALOG[active_vessel]["resource_path"]
		if ResourceLoader.exists(path):
			return load(path) as ShipData
	var fallback_path = LEVEL_SHIPS.get(current_level, LEVEL_SHIPS[1])
	if ResourceLoader.exists(fallback_path):
		return load(fallback_path) as ShipData
	return null

func get_current_ship_resource() -> ShipData:
	return get_active_ship_resource()

func get_active_ship_tier() -> int:
	return vessel_tiers.get(active_vessel, 1)

func is_vessel_owned(vessel_id: String) -> bool:
	return vessel_id in owned_vessels

func get_vessel_tier(vessel_id: String) -> int:
	return vessel_tiers.get(vessel_id, 1)

func get_upgrade_cost(vessel_id: String, target_tier: int) -> int:
	if not VESSEL_CATALOG.has(vessel_id):
		return 0
	return VESSEL_CATALOG[vessel_id]["tier_prices"].get(target_tier, 0)

func can_afford(cost: int) -> bool:
	return doubloons >= cost

func buy_vessel(vessel_id: String) -> bool:
	if not VESSEL_CATALOG.has(vessel_id):
		return false
	if is_vessel_owned(vessel_id):
		return false
	var cost = VESSEL_CATALOG[vessel_id]["purchase_price"]
	if doubloons < cost:
		return false
	doubloons -= cost
	owned_vessels.append(vessel_id)
	vessel_tiers[vessel_id] = 1
	active_vessel = vessel_id
	save_game()
	doubloons_changed.emit(doubloons)
	active_vessel_changed.emit(active_vessel)
	return true

func upgrade_vessel_tier(vessel_id: String) -> bool:
	if not is_vessel_owned(vessel_id):
		return false
	var cur_tier = get_vessel_tier(vessel_id)
	if cur_tier >= 3:
		return false
	var next_tier = cur_tier + 1
	var cost = get_upgrade_cost(vessel_id, next_tier)
	if doubloons < cost:
		return false
	doubloons -= cost
	vessel_tiers[vessel_id] = next_tier
	save_game()
	doubloons_changed.emit(doubloons)
	return true

func equip_vessel(vessel_id: String) -> bool:
	if not is_vessel_owned(vessel_id):
		return false
	active_vessel = vessel_id
	save_game()
	active_vessel_changed.emit(active_vessel)
	return true

func add_doubloons(amount: int) -> void:
	doubloons += amount
	run_doubloons += amount
	save_game()
	doubloons_changed.emit(doubloons)

func set_multiplier(value: float, mode: String = "x") -> void:
	multiplier_mode = mode
	if mode == "x":
		active_multiplier = clamp(value, 1.0, 8.0)
	else:
		active_multiplier = clamp(value, 0.0, 12.0)
	multiplier_changed.emit(active_multiplier, multiplier_mode)

func update_distance(delta_distance: float) -> void:
	if not is_game_active or boss_spawned:
		return
	distance_traveled = min(level_distance_target, distance_traveled + delta_distance)
	progress_changed.emit(distance_traveled, level_distance_target)

func unlock_next_level() -> void:
	unlocked_levels = min(6, max(unlocked_levels, current_level + 1))
	save_game()

func is_campaign_complete() -> bool:
	return current_level >= 6

func reset_level() -> void:
	run_doubloons = 0
	targets_destroyed = 0
	distance_traveled = 0.0
	is_game_active = false
	boss_spawned = false
	active_multiplier = 1.0
	multiplier_mode = "x"
	doubloons_changed.emit(doubloons)
	progress_changed.emit(distance_traveled, level_distance_target)
	multiplier_changed.emit(active_multiplier, multiplier_mode)

func reset_save_data() -> void:
	doubloons = 0
	owned_vessels = ["dinghy"]
	vessel_tiers = {
		"dinghy": 1,
		"sloop": 1,
		"ironclad": 1
	}
	active_vessel = "dinghy"
	unlocked_levels = 1
	current_level = 1
	reset_level()
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	save_game()
	doubloons_changed.emit(doubloons)
	active_vessel_changed.emit(active_vessel)

func save_game() -> void:
	var save_dict: Dictionary = {
		"doubloons": doubloons,
		"owned_vessels": owned_vessels,
		"vessel_tiers": vessel_tiers,
		"active_vessel": active_vessel,
		"unlocked_levels": unlocked_levels,
		"master_volume": master_volume,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"master_muted": master_muted,
		"music_muted": music_muted,
		"sfx_muted": sfx_muted
	}
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		var json_str = JSON.stringify(save_dict, "\t")
		file.store_string(json_str)
		file.close()

func load_game() -> void:
	# Sensible default fallback state
	owned_vessels = ["dinghy"]
	vessel_tiers = {"dinghy": 1, "sloop": 1, "ironclad": 1}
	active_vessel = "dinghy"
	unlocked_levels = 1
	master_volume = 1.0
	music_volume = 1.0
	sfx_volume = 1.0
	master_muted = false
	music_muted = false
	sfx_muted = false

	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return

	var json_str = file.get_as_text()
	file.close()
	var json = JSON.new()
	var err = json.parse(json_str)
	if err == OK and json.data is Dictionary:
		var data: Dictionary = json.data
		doubloons = max(0, int(data.get("doubloons", doubloons)))
		
		if data.has("owned_vessels") and data["owned_vessels"] is Array:
			var loaded_owned: Array[String] = []
			for v in data["owned_vessels"]:
				var v_str = str(v)
				if v_str in VESSEL_CATALOG and not loaded_owned.has(v_str):
					loaded_owned.append(v_str)
			if not loaded_owned.has("dinghy"):
				loaded_owned.push_front("dinghy")
			owned_vessels = loaded_owned
			
		if data.has("vessel_tiers") and data["vessel_tiers"] is Dictionary:
			for k in data["vessel_tiers"]:
				var v_key = str(k)
				if v_key in VESSEL_CATALOG:
					vessel_tiers[v_key] = clamp(int(data["vessel_tiers"][k]), 1, 3)

		# Strict active vessel sanitization: MUST exist in owned_vessels
		if data.has("active_vessel"):
			var loaded_active = str(data["active_vessel"])
			if loaded_active in owned_vessels:
				active_vessel = loaded_active
			else:
				active_vessel = "dinghy"
		else:
			active_vessel = "dinghy"

		if data.has("unlocked_levels"):
			unlocked_levels = clamp(int(data["unlocked_levels"]), 1, 6)

		if data.has("master_volume"): master_volume = clamp(float(data["master_volume"]), 0.0, 1.0)
		if data.has("music_volume"): music_volume = clamp(float(data["music_volume"]), 0.0, 1.0)
		if data.has("sfx_volume"): sfx_volume = clamp(float(data["sfx_volume"]), 0.0, 1.0)
		if data.has("master_muted"): master_muted = bool(data["master_muted"])
		if data.has("music_muted"): music_muted = bool(data["music_muted"])
		if data.has("sfx_muted"): sfx_muted = bool(data["sfx_muted"])

		doubloons_changed.emit(doubloons)
	else:
		# Corrupted save file fallback
		active_vessel = "dinghy"
		owned_vessels = ["dinghy"]
		vessel_tiers["dinghy"] = 1
