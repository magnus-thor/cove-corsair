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
signal crew_unlocked(crew_id: String, level: int)
signal crew_equipped(ship_id: String, socket_name: String, crew_id: String)
signal outfitting_unlocked(item_id: String)
signal outfitting_equipped(ship_id: String, category: String, item_id: String)
signal fire_frenzy_triggered(duration: float)
@warning_ignore("unused_signal")
signal run_failed(coins_collected: int, distance_reached: float)

const SAVE_PATH: String = "user://cove_corsair_save.json"

# Persistent Economy & Fleet State
var doubloons: int = 0
var owned_vessels: Array[String] = ["dinghy"]
var vessel_tiers: Dictionary = {
	"dinghy": 1,
	"sloop": 1,
	"ironclad": 1,
	"bombard_skiff": 1
}
var active_vessel: String = "dinghy"
var unlocked_crew: Dictionary = {}
var equipped_crew: Dictionary = {}

# Outfitting State: Tactical Ammo & Hull Platings
var unlocked_outfitting: Dictionary = {
	"standard_iron": true,
	"none": true
}
var equipped_ammo: Dictionary = {
	"dinghy": "standard_iron",
	"sloop": "standard_iron",
	"ironclad": "standard_iron",
	"bombard_skiff": "standard_iron"
}
var equipped_plating: Dictionary = {
	"dinghy": "none",
	"sloop": "none",
	"ironclad": "none",
	"bombard_skiff": "none"
}

# Fodder Streak Tracking
var fodder_kill_timestamps: Array[float] = []

# Persistent Progression & Level Map State
var highest_unlocked_level: int = 1
var current_selected_level: int = 1
var just_cleared_level: bool = false
var last_cleared_level: int = 1
var level_high_scores: Dictionary = {
	1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0
}
var level_stars: Dictionary = {
	1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0
}
var unlocked_levels: int = 1 # Backwards compatibility alias for highest_unlocked_level

# Persistent Audio Preferences
var master_volume: float = 1.0
var music_volume: float = 1.0
var sfx_volume: float = 1.0
var master_muted: bool = false
var music_muted: bool = false
var sfx_muted: bool = false

# In-Run Transient State
var run_doubloons: int = 0
var run_doubloons_banked: bool = false
var targets_destroyed: int = 0
var hits_taken: int = 0
var mobs_leaked: int = 0
var active_multiplier: float = 1.0
var multiplier_mode: String = "x" # "x" for multiply, "+" for add
var current_level: int = 1 # Backwards compatibility alias for current_selected_level
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
		"tier_prices": { 2: 250, 3: 1000 },
		"tier_descriptions": {
			1: "Standard Hull & Bow Chaser",
			2: "Reinforced Hull (3 HP, 1 Weapon + 1 Crew Socket)",
			3: "Masterwork Hull (4 HP, 1 Weapon + 2 Crew Sockets)"
		},
		"base_hp": 2,
		"base_speed": 12.0,
		"fire_rate": 0.20,
		"preview_texture": "res://assets/sprites/user_vessels/The Dinghy.png"
	},
	"sloop": {
		"id": "sloop",
		"name": "The Sloop",
		"archetype": "Balanced Standard",
		"resource_path": "res://src/data/resources/user_vessels/sloop_ship.tres",
		"purchase_price": 500,
		"tier_prices": { 2: 700, 3: 1600 },
		"tier_descriptions": {
			1: "Standard Hull & Bow Chasers",
			2: "Reinforced Oak (5 HP, 1 Weapon + 1 Crew Socket)",
			3: "Fleet Flagship (6 HP, All Sockets Unlocked)"
		},
		"base_hp": 4,
		"base_speed": 11.0,
		"fire_rate": 0.16,
		"preview_texture": "res://assets/sprites/user_vessels/The Sloop.png"
	},
	"ironclad": {
		"id": "ironclad",
		"name": "The Ironclad",
		"archetype": "Armored Brawler",
		"resource_path": "res://src/data/resources/user_vessels/ironclad_ship.tres",
		"purchase_price": 1400,
		"tier_prices": { 2: 1800, 3: 3000 },
		"tier_descriptions": {
			1: "Armored Plating & Heavy Battery",
			2: "Reinforced Iron (9 HP, 1 Weapon + 1 Crew Socket)",
			3: "Dreadnought Hull (10 HP, All Sockets Unlocked)"
		},
		"base_hp": 8,
		"base_speed": 7.5,
		"fire_rate": 0.15,
		"preview_texture": "res://assets/sprites/user_vessels/The Ironclad.png"
	},
	"bombard_skiff": {
		"id": "bombard_skiff",
		"name": "The Bombard Skiff",
		"archetype": "Artillery Mortar",
		"resource_path": "res://src/data/resources/user_vessels/bombard_skiff_ship.tres",
		"purchase_price": 1000,
		"tier_prices": { 2: 1200, 3: 2200 },
		"tier_descriptions": {
			1: "Artillery Skiff (3 HP, 1 Weapon Socket)",
			2: "Reinforced Keel (4 HP, 1 Weapon + 1 Crew Socket)",
			3: "Siege Dreadnought (5 HP, All Sockets Unlocked)"
		},
		"base_hp": 3,
		"base_speed": 9.0,
		"fire_rate": 1.3,
		"preview_texture": "res://assets/sprites/user_vessels/The Bombard Skiff.png"
	}
}

const CREW_CATALOG: Dictionary = {
	"monkey_bomber": {
		"id": "monkey_bomber",
		"name": "Monkey Bomber",
		"role": "BOMBARDIER",
		"resource_path": "res://src/data/resources/user_crew/crew_monkey_bomber.tres",
		"preview_texture": "res://assets/sprites/user_crew/weapon_deckhand_sniper_back.png",
		"unlock_price": 350,
		"upgrade_prices": { 2: 500, 3: 850 },
		"levels": {
			1: { "damage": 3, "cooldown": 1.2, "description": "3 AoE damage, 1.2s cooldown" },
			2: { "damage": 5, "cooldown": 1.0, "description": "5 AoE damage, 1.0s cooldown" },
			3: { "damage": 5, "cooldown": 1.0, "description": "5 AoE damage + secondary mini-cluster bounce" }
		}
	},
	"skeleton_tosser": {
		"id": "skeleton_tosser",
		"name": "Skeleton Tosser",
		"role": "PYROTECHNIC",
		"resource_path": "res://src/data/resources/user_crew/crew_skeleton_tosser.tres",
		"preview_texture": "res://assets/sprites/user_crew/skeleton_crew.png",
		"unlock_price": 550,
		"upgrade_prices": { 2: 750, 3: 1200 },
		"levels": {
			1: { "damage": 4, "cooldown": 1.4, "description": "4 direct damage + short burn" },
			2: { "damage": 6, "cooldown": 1.2, "description": "6 damage, wider fire radius" },
			3: { "damage": 6, "cooldown": 1.2, "description": "Lingering napalm effect on water surface" }
		}
	}
}

const OUTFITTING_CATALOG: Dictionary = {
	"standard_iron": {
		"id": "standard_iron",
		"name": "Standard Iron Shot",
		"category": "ammo",
		"price": 0,
		"description": "Standard forged cannonballs. Balanced velocity and baseline kinetic damage.",
		"resource_path": "res://src/data/resources/user_ammo/ammo_standard_iron.tres",
		"preview_texture": "res://assets/sprites/ammo/ammo_heavy_shot.png"
	},
	"battering_shot": {
		"id": "battering_shot",
		"name": "Battering Shot",
		"category": "ammo",
		"price": 400,
		"description": "+100% damage vs Barricade Walls and heavy timber barriers.",
		"resource_path": "res://src/data/resources/user_ammo/ammo_battering_shot.tres",
		"preview_texture": "res://assets/sprites/ammo/ammo_heavy_shot.png"
	},
	"chain_shot": {
		"id": "chain_shot",
		"name": "Chain Shot",
		"category": "ammo",
		"price": 500,
		"description": "Interlinked chain shot. Sweeps and detonates sea mines in a radius safely.",
		"resource_path": "res://src/data/resources/user_ammo/ammo_chain_shot.tres",
		"preview_texture": "res://assets/sprites/ammo/ammo_throwing_axe.png"
	},
	"spectral_salt": {
		"id": "spectral_salt",
		"name": "Spectral Salt Shot",
		"category": "ammo",
		"price": 650,
		"description": "+50% damage vs Ghost/Spectral craft and interrupts boss casting channels.",
		"resource_path": "res://src/data/resources/user_ammo/ammo_spectral_salt.tres",
		"preview_texture": "res://assets/sprites/ammo/ammo_coconut_bomb.png"
	},
	"none": {
		"id": "none",
		"name": "Standard Wood Hull",
		"category": "plating",
		"price": 0,
		"description": "Unmodified seasoned oak hull with standard naval durability.",
		"preview_texture": "res://assets/sprites/user_vessels/The Dinghy.png"
	},
	"spectral_ward": {
		"id": "spectral_ward",
		"name": "Spectral Ward Plating",
		"category": "plating",
		"price": 600,
		"description": "Reduces damage from spectral geysers/circles by 60% and negates movement slows.",
		"preview_texture": "res://assets/sprites/enemy_vessels/Ghost Sloop.png"
	},
	"brimstone_fireproof": {
		"id": "brimstone_fireproof",
		"name": "Brimstone Fireproof Plating",
		"category": "plating",
		"price": 750,
		"description": "Volcanic slate cladding. Reduces magma and fire hazard damage by 50%.",
		"preview_texture": "res://assets/sprites/ammo/ammo_fire_bomb.png"
	},
	"spiked_iron_prow": {
		"id": "spiked_iron_prow",
		"name": "Spiked Iron Prow",
		"category": "plating",
		"price": 500,
		"description": "Reinforced ramming prow. Completely absorbs 1 obstacle ram impact per level with 0 damage.",
		"preview_texture": "res://assets/sprites/enemy_vessels/Armored Turtle-Raft.png"
	}
}

const LEVEL_RESOURCES: Dictionary = {
	1: "res://src/data/resources/levels/level_01.tres",
	2: "res://src/data/resources/levels/level_02.tres",
	3: "res://src/data/resources/levels/level_03.tres",
	4: "res://src/data/resources/levels/level_04.tres",
	5: "res://src/data/resources/levels/level_05.tres",
	6: "res://src/data/resources/levels/level_06.tres",
	7: "res://src/data/resources/levels/level_07.tres",
	8: "res://src/data/resources/levels/level_08.tres",
	9: "res://src/data/resources/levels/level_09.tres",
	10: "res://src/data/resources/levels/level_10.tres",
	11: "res://src/data/resources/levels/level_11.tres",
	12: "res://src/data/resources/levels/level_12.tres",
	13: "res://src/data/resources/levels/level_13.tres",
	14: "res://src/data/resources/levels/level_14.tres",
	15: "res://src/data/resources/levels/level_15.tres",
	16: "res://src/data/resources/levels/level_16.tres",
	17: "res://src/data/resources/levels/level_17.tres",
	18: "res://src/data/resources/levels/level_18.tres",
	19: "res://src/data/resources/levels/level_19.tres",
	20: "res://src/data/resources/levels/level_20.tres",
	21: "res://src/data/resources/levels/level_21.tres",
	22: "res://src/data/resources/levels/level_22.tres",
	23: "res://src/data/resources/levels/level_23.tres",
	24: "res://src/data/resources/levels/level_24.tres",
	25: "res://src/data/resources/levels/level_25.tres",
	26: "res://src/data/resources/levels/level_26.tres",
	27: "res://src/data/resources/levels/level_27.tres",
	28: "res://src/data/resources/levels/level_28.tres",
	29: "res://src/data/resources/levels/level_29.tres",
	30: "res://src/data/resources/levels/level_30.tres",
	31: "res://src/data/resources/levels/level_31.tres",
	32: "res://src/data/resources/levels/level_32.tres",
	33: "res://src/data/resources/levels/level_33.tres",
	34: "res://src/data/resources/levels/level_34.tres",
	35: "res://src/data/resources/levels/level_35.tres",
	36: "res://src/data/resources/levels/level_36.tres",
	37: "res://src/data/resources/levels/level_37.tres",
	38: "res://src/data/resources/levels/level_38.tres",
	39: "res://src/data/resources/levels/level_39.tres",
	40: "res://src/data/resources/levels/level_40.tres",
	41: "res://src/data/resources/levels/level_41.tres",
	42: "res://src/data/resources/levels/level_42.tres",
	43: "res://src/data/resources/levels/level_43.tres",
	44: "res://src/data/resources/levels/level_44.tres",
	45: "res://src/data/resources/levels/level_45.tres"
}

const LEVEL_SHIPS: Dictionary = {
	1: "res://src/data/resources/user_vessels/dinghy_ship.tres",
	2: "res://src/data/resources/user_vessels/sloop_ship.tres",
	3: "res://src/data/resources/user_vessels/ironclad_ship.tres",
	4: "res://src/data/resources/user_vessels/dinghy_ship.tres",
	5: "res://src/data/resources/user_vessels/sloop_ship.tres",
	6: "res://src/data/resources/user_vessels/ironclad_ship.tres",
	7: "res://src/data/resources/user_vessels/dinghy_ship.tres",
	8: "res://src/data/resources/user_vessels/sloop_ship.tres",
	9: "res://src/data/resources/user_vessels/ironclad_ship.tres",
	10: "res://src/data/resources/user_vessels/dinghy_ship.tres",
	11: "res://src/data/resources/user_vessels/sloop_ship.tres",
	12: "res://src/data/resources/user_vessels/ironclad_ship.tres",
	# Cove 1 Continuation (L13-L15)
	13: "res://src/data/resources/user_vessels/dinghy_ship.tres",
	14: "res://src/data/resources/user_vessels/bombard_skiff_ship.tres",
	15: "res://src/data/resources/user_vessels/ironclad_ship.tres",
	# Cove 2 (L16-L30) Tactical Pairings
	16: "res://src/data/resources/user_vessels/ironclad_ship.tres", # The Iron Wall (Barricade Cluster)
	17: "res://src/data/resources/user_vessels/sloop_ship.tres",
	18: "res://src/data/resources/user_vessels/dinghy_ship.tres",
	19: "res://src/data/resources/user_vessels/dinghy_ship.tres", # Devil's Slalom (Dense Mines)
	20: "res://src/data/resources/user_vessels/bombard_skiff_ship.tres", # Siege Fortress Boss
	21: "res://src/data/resources/user_vessels/ironclad_ship.tres",
	22: "res://src/data/resources/user_vessels/dinghy_ship.tres",
	23: "res://src/data/resources/user_vessels/sloop_ship.tres",
	24: "res://src/data/resources/user_vessels/bombard_skiff_ship.tres",
	25: "res://src/data/resources/user_vessels/sloop_ship.tres", # Phantom Dredge Boss
	26: "res://src/data/resources/user_vessels/ironclad_ship.tres",
	27: "res://src/data/resources/user_vessels/dinghy_ship.tres",
	28: "res://src/data/resources/user_vessels/bombard_skiff_ship.tres",
	29: "res://src/data/resources/user_vessels/dinghy_ship.tres",
	30: "res://src/data/resources/user_vessels/ironclad_ship.tres", # Bone-Beard Armada
	# Cove 3 (L31-L45) Brimstone Tactical Pairings
	31: "res://src/data/resources/user_vessels/sloop_ship.tres",
	32: "res://src/data/resources/user_vessels/ironclad_ship.tres",
	33: "res://src/data/resources/user_vessels/dinghy_ship.tres",
	34: "res://src/data/resources/user_vessels/bombard_skiff_ship.tres",
	35: "res://src/data/resources/user_vessels/ironclad_ship.tres", # Ironjaw Boss
	36: "res://src/data/resources/user_vessels/dinghy_ship.tres",
	37: "res://src/data/resources/user_vessels/bombard_skiff_ship.tres",
	38: "res://src/data/resources/user_vessels/sloop_ship.tres",
	39: "res://src/data/resources/user_vessels/dinghy_ship.tres",
	40: "res://src/data/resources/user_vessels/bombard_skiff_ship.tres", # Siege Fortress Boss
	41: "res://src/data/resources/user_vessels/ironclad_ship.tres",
	42: "res://src/data/resources/user_vessels/dinghy_ship.tres",
	43: "res://src/data/resources/user_vessels/bombard_skiff_ship.tres",
	44: "res://src/data/resources/user_vessels/dinghy_ship.tres",
	45: "res://src/data/resources/user_vessels/ironclad_ship.tres" # Bone-Beard Final Throne
}

func _ready() -> void:
	load_game()
	apply_audio_settings()
	set_performance_mode(false)

func set_performance_mode(is_gameplay: bool) -> void:
	if is_gameplay:
		Engine.max_fps = 60
	else:
		Engine.max_fps = 30

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

func get_vessel_resource(vessel_id: String) -> ShipData:
	if vessel_id in VESSEL_CATALOG:
		var path = VESSEL_CATALOG[vessel_id]["resource_path"]
		if ResourceLoader.exists(path):
			return load(path) as ShipData
	return null

func get_active_ship_resource() -> ShipData:
	var res = get_vessel_resource(active_vessel)
	if res:
		return res
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
	var res = get_vessel_resource(vessel_id)
	if res and res.upgrade_costs.size() >= target_tier and target_tier >= 1:
		return res.upgrade_costs[target_tier - 1]
	if VESSEL_CATALOG.has(vessel_id):
		return VESSEL_CATALOG[vessel_id]["tier_prices"].get(target_tier, 0)
	return 0

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

func set_active_vessel(vessel_id: String) -> bool:
	return equip_vessel(vessel_id)

func can_afford_active_vessel_upgrade() -> bool:
	var cur_tier = get_vessel_tier(active_vessel)
	if cur_tier >= 3:
		return false
	var next_tier = cur_tier + 1
	var cost = get_upgrade_cost(active_vessel, next_tier)
	return cost > 0 and doubloons >= cost

# --- Crew Meta & Outfitting ---
func is_crew_unlocked(crew_id: String) -> bool:
	return unlocked_crew.has(crew_id) and int(unlocked_crew[crew_id]) >= 1

func get_crew_level(crew_id: String) -> int:
	return int(unlocked_crew.get(crew_id, 0))

func get_crew_unlock_cost(crew_id: String) -> int:
	if CREW_CATALOG.has(crew_id):
		return CREW_CATALOG[crew_id]["unlock_price"]
	return 0

func get_crew_upgrade_cost(crew_id: String, target_level: int) -> int:
	if CREW_CATALOG.has(crew_id):
		return CREW_CATALOG[crew_id]["upgrade_prices"].get(target_level, 0)
	return 0

func buy_crew(crew_id: String) -> bool:
	if not CREW_CATALOG.has(crew_id):
		return false
	if is_crew_unlocked(crew_id):
		return false
	var cost = get_crew_unlock_cost(crew_id)
	if doubloons < cost:
		return false
	doubloons -= cost
	unlocked_crew[crew_id] = 1
	save_game()
	doubloons_changed.emit(doubloons)
	crew_unlocked.emit(crew_id, 1)
	return true

func upgrade_crew_level(crew_id: String) -> bool:
	if not is_crew_unlocked(crew_id):
		return false
	var cur_lvl = get_crew_level(crew_id)
	if cur_lvl >= 3:
		return false
	var next_lvl = cur_lvl + 1
	var cost = get_crew_upgrade_cost(crew_id, next_lvl)
	if doubloons < cost:
		return false
	doubloons -= cost
	unlocked_crew[crew_id] = next_lvl
	save_game()
	doubloons_changed.emit(doubloons)
	crew_unlocked.emit(crew_id, next_lvl)
	return true

func get_crew_sockets_for_ship(ship_id: String, tier: int = -1) -> Array[String]:
	var ship_res = get_vessel_resource(ship_id)
	if not ship_res:
		return []
	if tier < 1:
		tier = get_vessel_tier(ship_id)
	if ship_res.tier_sockets.is_empty():
		return []
	var s_idx = clampi(tier - 1, 0, ship_res.tier_sockets.size() - 1)
	var active_sockets: Array = ship_res.tier_sockets[s_idx]
	var crew_sockets: Array[String] = []
	for s_name in active_sockets:
		var s_lower = str(s_name).to_lower()
		if "crew" in s_lower:
			crew_sockets.append(str(s_name))
	return crew_sockets

func get_equipped_crew(ship_id: String, socket_name: String) -> String:
	if not equipped_crew.has(ship_id):
		return ""
	var ship_map = equipped_crew[ship_id]
	if ship_map is Dictionary and ship_map.has(socket_name):
		return str(ship_map[socket_name])
	return ""

func is_crew_equipped_on_ship(ship_id: String, crew_id: String) -> bool:
	if not equipped_crew.has(ship_id):
		return false
	var ship_map = equipped_crew[ship_id]
	if ship_map is Dictionary:
		for s in ship_map:
			if ship_map[s] == crew_id:
				return true
	return false

func is_crew_equipped_on_active_ship(crew_id: String) -> bool:
	return is_crew_equipped_on_ship(active_vessel, crew_id)

func equip_crew(ship_id: String, socket_name: String, crew_id: String) -> bool:
	if not is_crew_unlocked(crew_id):
		return false
	if not equipped_crew.has(ship_id) or not (equipped_crew[ship_id] is Dictionary):
		equipped_crew[ship_id] = {}
	# If this crew is already on another socket on this ship, unequip from old socket
	for s in equipped_crew[ship_id].keys():
		if equipped_crew[ship_id][s] == crew_id:
			equipped_crew[ship_id].erase(s)
	equipped_crew[ship_id][socket_name] = crew_id
	save_game()
	crew_equipped.emit(ship_id, socket_name, crew_id)
	return true

func unequip_crew(ship_id: String, socket_name: String) -> bool:
	if not equipped_crew.has(ship_id) or not (equipped_crew[ship_id] is Dictionary):
		return false
	if equipped_crew[ship_id].has(socket_name):
		equipped_crew[ship_id].erase(socket_name)
		save_game()
		crew_equipped.emit(ship_id, socket_name, "")
		return true
	return false

func toggle_equip_crew_active_ship(crew_id: String) -> bool:
	if not is_crew_unlocked(crew_id):
		return false
	if not is_vessel_owned(active_vessel):
		return false
	var cur_tier = get_vessel_tier(active_vessel)
	var available_sockets = get_crew_sockets_for_ship(active_vessel, cur_tier)
	
	# Safe Ship Swap Guard: If vessel has 0 crew sockets (e.g. Tier 1), cannot equip
	if available_sockets.is_empty():
		return false
		
	# If already equipped on active ship, unequip it!
	if is_crew_equipped_on_active_ship(crew_id):
		var ship_map = equipped_crew.get(active_vessel, {})
		for s in ship_map.keys():
			if ship_map[s] == crew_id:
				unequip_crew(active_vessel, s)
				return true
		return false
		
	# Otherwise find first open socket or replace first socket
	var target_socket = ""
	var ship_map = equipped_crew.get(active_vessel, {})
	for s in available_sockets:
		if not ship_map.has(s) or ship_map[s] == "":
			target_socket = s
			break
	if target_socket == "":
		target_socket = available_sockets[0]
		
	return equip_crew(active_vessel, target_socket, crew_id)

# --- Outfitting Management (Tactical Ammo & Hull Platings) ---

func is_outfitting_unlocked(item_id: String) -> bool:
	if item_id == "standard_iron" or item_id == "none" or item_id == "":
		return true
	return unlocked_outfitting.get(item_id, false)

func get_equipped_ammo(ship_id: String) -> String:
	return equipped_ammo.get(ship_id, "standard_iron")

func get_equipped_plating(ship_id: String) -> String:
	return equipped_plating.get(ship_id, "none")

func get_active_ammo() -> String:
	return get_equipped_ammo(active_vessel)

func get_active_plating() -> String:
	return get_equipped_plating(active_vessel)

func buy_outfitting(item_id: String) -> bool:
	if not OUTFITTING_CATALOG.has(item_id):
		return false
	if is_outfitting_unlocked(item_id):
		return true
	var price = OUTFITTING_CATALOG[item_id].get("price", 0)
	if doubloons < price:
		return false
	doubloons -= price
	unlocked_outfitting[item_id] = true
	save_game()
	doubloons_changed.emit(doubloons)
	outfitting_unlocked.emit(item_id)
	return true

func equip_ammo(ship_id: String, ammo_id: String) -> bool:
	if not is_outfitting_unlocked(ammo_id):
		return false
	equipped_ammo[ship_id] = ammo_id
	save_game()
	outfitting_equipped.emit(ship_id, "ammo", ammo_id)
	return true

func equip_plating(ship_id: String, plating_id: String) -> bool:
	if not is_outfitting_unlocked(plating_id):
		return false
	equipped_plating[ship_id] = plating_id
	save_game()
	outfitting_equipped.emit(ship_id, "plating", plating_id)
	return true

func toggle_equip_outfitting_active_ship(item_id: String) -> bool:
	if not OUTFITTING_CATALOG.has(item_id):
		return false
	if not is_outfitting_unlocked(item_id):
		return false
	var cat = OUTFITTING_CATALOG[item_id].get("category", "")
	if cat == "ammo":
		if get_active_ammo() == item_id and item_id != "standard_iron":
			return equip_ammo(active_vessel, "standard_iron")
		return equip_ammo(active_vessel, item_id)
	elif cat == "plating":
		if get_active_plating() == item_id and item_id != "none":
			return equip_plating(active_vessel, "none")
		return equip_plating(active_vessel, item_id)
	return false

func record_fodder_kill() -> void:
	var now = Time.get_ticks_msec() / 1000.0
	fodder_kill_timestamps.append(now)
	var cutoff = now - 2.0
	fodder_kill_timestamps = fodder_kill_timestamps.filter(func(t): return t >= cutoff)
	if fodder_kill_timestamps.size() >= 3:
		fodder_kill_timestamps.clear()
		fire_frenzy_triggered.emit(2.5)



func add_doubloons(amount: int) -> void:
	if is_game_active:
		add_run_doubloons(amount)
	else:
		doubloons += amount
		save_game()
		doubloons_changed.emit(doubloons)

func add_run_doubloons(amount: int) -> void:
	run_doubloons += amount
	doubloons_changed.emit(doubloons + run_doubloons)

func bank_run_doubloons(completion_bonus: int = 0) -> int:
	if run_doubloons_banked:
		return 0
	run_doubloons_banked = true
	var total_earned: int = run_doubloons + completion_bonus
	doubloons += total_earned
	save_game()
	doubloons_changed.emit(doubloons)
	return total_earned

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

func select_level(lvl: int) -> void:
	current_selected_level = clamp(lvl, 1, 45)
	current_level = current_selected_level
	save_game()

func unlock_next_level() -> void:
	last_cleared_level = current_level
	if current_level >= highest_unlocked_level:
		highest_unlocked_level = min(45, current_level + 1)
		just_cleared_level = true
		current_selected_level = highest_unlocked_level
	unlocked_levels = highest_unlocked_level
	current_level = current_selected_level
	save_game()

func record_level_score(level_num: int, score: int) -> void:
	var cur_best: int = int(level_high_scores.get(level_num, 0))
	if score > cur_best:
		level_high_scores[level_num] = score
		save_game()

func record_level_stars(level_num: int, stars: int) -> void:
	var cur_stars: int = int(level_stars.get(level_num, 0))
	if stars > cur_stars:
		level_stars[level_num] = clamp(stars, 0, 3)
		save_game()

func record_hit() -> void:
	hits_taken += 1

func record_mob_leaked() -> void:
	mobs_leaked += 1

func calculate_stars() -> int:
	var stars: int = 1 # Star 1: Cove Cleared / Boss Defeated
	if mobs_leaked == 0:
		stars += 1 # Star 2: Zero Leaks (No enemy mobs breached past the player)
	if hits_taken == 0:
		stars += 1 # Star 3: Untouched Hull (Zero hits taken from hazards, attacks, or collisions)
	return stars

func is_campaign_complete() -> bool:
	return current_level >= 45

func reset_level() -> void:
	run_doubloons = 0
	run_doubloons_banked = false
	targets_destroyed = 0
	hits_taken = 0
	mobs_leaked = 0
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
		"ironclad": 1,
		"bombard_skiff": 1
	}
	active_vessel = "dinghy"
	unlocked_crew = {}
	equipped_crew = {}
	unlocked_outfitting = {"standard_iron": true, "none": true}
	equipped_ammo = {"dinghy": "standard_iron", "sloop": "standard_iron", "ironclad": "standard_iron", "bombard_skiff": "standard_iron"}
	equipped_plating = {"dinghy": "none", "sloop": "none", "ironclad": "none", "bombard_skiff": "none"}
	highest_unlocked_level = 1
	current_selected_level = 1
	unlocked_levels = 1
	current_level = 1
	just_cleared_level = false
	last_cleared_level = 1
	level_high_scores = {}
	level_stars = {}
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
		"unlocked_crew": unlocked_crew,
		"equipped_crew": equipped_crew,
		"unlocked_outfitting": unlocked_outfitting,
		"equipped_ammo": equipped_ammo,
		"equipped_plating": equipped_plating,
		"highest_unlocked_level": highest_unlocked_level,
		"current_selected_level": current_selected_level,
		"just_cleared_level": just_cleared_level,
		"last_cleared_level": last_cleared_level,
		"level_high_scores": level_high_scores,
		"level_stars": level_stars,
		"unlocked_levels": highest_unlocked_level,
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
	vessel_tiers = {"dinghy": 1, "sloop": 1, "ironclad": 1, "bombard_skiff": 1}
	active_vessel = "dinghy"
	unlocked_crew = {}
	equipped_crew = {}
	highest_unlocked_level = 1
	current_selected_level = 1
	unlocked_levels = 1
	current_level = 1
	just_cleared_level = false
	last_cleared_level = 1
	level_high_scores = {}
	level_stars = {}
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

		if data.has("unlocked_crew") and data["unlocked_crew"] is Dictionary:
			unlocked_crew = {}
			for c_id in data["unlocked_crew"]:
				var cid_str = str(c_id)
				if cid_str in CREW_CATALOG:
					unlocked_crew[cid_str] = clamp(int(data["unlocked_crew"][c_id]), 1, 3)
		else:
			unlocked_crew = {}

		if data.has("equipped_crew") and data["equipped_crew"] is Dictionary:
			equipped_crew = {}
			for s_id in data["equipped_crew"]:
				var sid_str = str(s_id)
				if data["equipped_crew"][s_id] is Dictionary:
					equipped_crew[sid_str] = {}
					for sock in data["equipped_crew"][s_id]:
						var c_val = str(data["equipped_crew"][s_id][sock])
						if c_val in CREW_CATALOG:
							equipped_crew[sid_str][str(sock)] = c_val
		else:
			equipped_crew = {}

		if data.has("unlocked_outfitting") and data["unlocked_outfitting"] is Dictionary:
			unlocked_outfitting = {"standard_iron": true, "none": true}
			for o_id in data["unlocked_outfitting"]:
				var oid_str = str(o_id)
				if oid_str in OUTFITTING_CATALOG:
					unlocked_outfitting[oid_str] = bool(data["unlocked_outfitting"][o_id])
		else:
			unlocked_outfitting = {"standard_iron": true, "none": true}

		if data.has("equipped_ammo") and data["equipped_ammo"] is Dictionary:
			equipped_ammo = {"dinghy": "standard_iron", "sloop": "standard_iron", "ironclad": "standard_iron", "bombard_skiff": "standard_iron"}
			for s_id in data["equipped_ammo"]:
				var sid_str = str(s_id)
				var a_val = str(data["equipped_ammo"][s_id])
				if a_val in OUTFITTING_CATALOG:
					equipped_ammo[sid_str] = a_val
		else:
			equipped_ammo = {"dinghy": "standard_iron", "sloop": "standard_iron", "ironclad": "standard_iron", "bombard_skiff": "standard_iron"}

		if data.has("equipped_plating") and data["equipped_plating"] is Dictionary:
			equipped_plating = {"dinghy": "none", "sloop": "none", "ironclad": "none", "bombard_skiff": "none"}
			for s_id in data["equipped_plating"]:
				var sid_str = str(s_id)
				var p_val = str(data["equipped_plating"][s_id])
				if p_val in OUTFITTING_CATALOG:
					equipped_plating[sid_str] = p_val
		else:
			equipped_plating = {"dinghy": "none", "sloop": "none", "ironclad": "none", "bombard_skiff": "none"}

		if data.has("highest_unlocked_level"):
			highest_unlocked_level = clamp(int(data["highest_unlocked_level"]), 1, 45)
		elif data.has("unlocked_levels"):
			highest_unlocked_level = clamp(int(data["unlocked_levels"]), 1, 45)
		unlocked_levels = highest_unlocked_level

		if data.has("current_selected_level"):
			current_selected_level = clamp(int(data["current_selected_level"]), 1, 45)
		else:
			current_selected_level = highest_unlocked_level
		current_level = current_selected_level

		if data.has("just_cleared_level"):
			just_cleared_level = bool(data["just_cleared_level"])
		if data.has("last_cleared_level"):
			last_cleared_level = clamp(int(data["last_cleared_level"]), 1, 45)
		if data.has("level_high_scores") and data["level_high_scores"] is Dictionary:
			for k in data["level_high_scores"]:
				var lvl_key = int(k)
				if lvl_key >= 1 and lvl_key <= 45:
					level_high_scores[lvl_key] = max(0, int(data["level_high_scores"][k]))

		if data.has("level_stars") and data["level_stars"] is Dictionary:
			for k in data["level_stars"]:
				var lvl_key = int(k)
				if lvl_key >= 1 and lvl_key <= 45:
					level_stars[lvl_key] = clamp(int(data["level_stars"][k]), 0, 3)

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
		unlocked_crew = {}
		equipped_crew = {}
		unlocked_outfitting = {"standard_iron": true, "none": true}
		equipped_ammo = {"dinghy": "standard_iron", "sloop": "standard_iron", "ironclad": "standard_iron", "bombard_skiff": "standard_iron"}
		equipped_plating = {"dinghy": "none", "sloop": "none", "ironclad": "none", "bombard_skiff": "none"}
		highest_unlocked_level = 1
		current_selected_level = 1
		unlocked_levels = 1
		current_level = 1

