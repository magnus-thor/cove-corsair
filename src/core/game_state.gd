extends Node

## Global GameState / ScoreManager Autoload for Cove Corsair
##
## Owns persistent player/run data and economy-tier signals.
## Cross-boundary lifecycle events (level_completed, boss_spawned, player_sunk,
## run_failed, distance_target_reached) have been migrated to EventBus.

# Economy & UI signals — tightly coupled to GameState data, stay here.
signal doubloons_changed(new_amount: int)
signal multiplier_changed(new_multiplier: float, mode: String)
signal progress_changed(current_distance: float, total_distance: float)
signal active_vessel_changed(vessel_id: String)
signal crew_unlocked(crew_id: String, level: int)
signal crew_equipped(ship_id: String, socket_name: String, crew_id: String)
signal outfitting_unlocked(item_id: String)
signal outfitting_equipped(ship_id: String, category: String, item_id: String)
signal fire_frenzy_triggered(duration: float)
signal tutorial_step_changed(new_step: int)

enum TutorialStep {
	NOT_STARTED = 0,         # Before Level 1 start
	LEVEL_1_IN_PROGRESS = 1, # First run on Dinghy
	LEVEL_1_COMPLETED = 2,   # Level 1 victory, 2x claimed
	LEVEL_2_IN_PROGRESS = 3, # Sailing Level 2 on Dinghy
	LEVEL_2_COMPLETED = 4,   # Shipyard unlocked! Guided to buy Sloop
	SLOOP_PURCHASED = 5,     # Sloop bought & equipped, ready for Level 3
	LEVEL_3_IN_PROGRESS = 6, # Sailing Level 3
	LEVEL_3_COMPLETED = 7,   # Level 3 victory -> Guided to recruit Monkey Bomber
	CREW_EQUIPPED = 8,       # Monkey Bomber recruited & equipped, ready for Level 4
	LEVEL_4_IN_PROGRESS = 9, # Sailing Level 4
	LEVEL_4_COMPLETED = 10,  # Level 4 victory -> Guided to upgrade Sloop to Tier 2
	SLOOP_T2_UPGRADED = 11,  # Sloop upgraded to Tier 2, ready for Level 5
	COMPLETED = 12           # Full tutorial complete
}

var tutorial_step: int = TutorialStep.NOT_STARTED

## Cove hub houses ("shipyard", "skull_outpost") that have already been built for the player.
## A house is raised with a build animation the first time the player is directed to it.
var hub_buildings_built: Array[String] = []

func is_hub_building_built(building_id: String) -> bool:
	return hub_buildings_built.has(building_id)

func mark_hub_building_built(building_id: String) -> void:
	if hub_buildings_built.has(building_id):
		return
	hub_buildings_built.append(building_id)
	save_game()

# Legacy cross-boundary lifecycle signals (retained for backward compatibility).
# Canonical cross-boundary events route through EventBus.
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

# Scene Loading & Transition State
var pending_loading_path: String = ""
var pending_loading_title: String = ""
const LOADING_SCREEN_PATH: String = "res://src/ui/loading_screen.tscn"

const LEVEL_TITLES: Dictionary = {
	1: "Smuggler's Run",
	2: "Black Tide Bayou",
	3: "Brimstone Bastion",
	4: "Smuggler's Nightmare",
	5: "Black Tide Abyss",
	6: "Brimstone Inferno"
}

func get_level_display_name(level_num: int) -> String:
	if LEVEL_TITLES.has(level_num):
		return str(LEVEL_TITLES[level_num])
	return "River Level %d" % level_num

func change_scene_with_loading(target_path: String, destination_title: String = "") -> void:
	pending_loading_path = target_path
	pending_loading_title = destination_title
	get_tree().change_scene_to_file(LOADING_SCREEN_PATH)

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
var music_volume: float = 0.55
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
var should_auto_start_endless: bool = false
var is_endless_mode: bool = false
## When true, pirate_lair_hub will auto-open the campaign river map on _ready().
## Reset to false immediately after the hub consumes it.
var should_open_map: bool = false

const VESSEL_CATALOG: Dictionary = {
	"dinghy": {
		"id": "dinghy",
		"name": "The Dinghy",
		"archetype": "Starter Rowboat",
		"resource_path": "res://src/data/resources/user_vessels/dinghy_ship.tres",
		"purchase_price": 0,
		"max_level": 3,
		"tier_prices": { 2: 150, 3: 450 },
		"tier_descriptions": {
			1: "Leaky Skiff (3 HP, 1 Bow Chaser)",
			2: "Patched Planks (4 HP, 11.0 m/s, +Mid Crew Socket)",
			3: "Reinforced Rowboat (5 HP, 11.5 m/s, All Sockets Unlocked)"
		},
		"base_hp": 3,
		"base_speed": 10.5,
		"fire_rate": 0.38,
		"preview_texture": "res://assets/sprites/user_vessels/The Dinghy.png"
	},
	"sloop": {
		"id": "sloop",
		"name": "The Sloop",
		"archetype": "Agile Long-Range Runner",
		"resource_path": "res://src/data/resources/user_vessels/sloop_ship.tres",
		"purchase_price": 400,
		"max_level": 10,
		"tier_prices": { 2: 250, 3: 350, 4: 650, 5: 1800, 6: 3500, 7: 6000, 8: 9500, 9: 14000, 10: 20000 },
		"tier_descriptions": {
			1: "Standard Oak (4 HP, Twin Bow Chasers)",
			2: "Tuned Rigging (4 HP, 11.8 m/s, +Mid Crew Socket)",
			3: "Reinforced Planks (5 HP, 12.2 m/s, +12% Firepower)",
			4: "Heavy Copper Sheathing (6 HP, 12.6 m/s, +25% Firepower, Reinforced Hull)",
			5: "Hardened Gunwales (6 HP, 13.0 m/s, +30% Firepower)",
			6: "Broadside Carronades (7 HP, 13.4 m/s, +Dual Swivel Mounts)",
			7: "Storm Sails (7 HP, 13.7 m/s, +35% Firepower)",
			8: "Reinforced Keel (7 HP, 14.0 m/s, +40% Firepower)",
			9: "Flagship Quarters (8 HP, 14.3 m/s, +Aft Crew Socket)",
			10: "Fleet Flagship (8 HP, 14.5 m/s, All Sockets Maxed)"
		},
		"base_hp": 4,
		"base_speed": 11.5,
		"fire_rate": 0.36,
		"preview_texture": "res://assets/sprites/user_vessels/The Sloop.png"
	},
	"ironclad": {
		"id": "ironclad",
		"name": "The Ironclad",
		"archetype": "Armored Brawler",
		"resource_path": "res://src/data/resources/user_vessels/ironclad_ship.tres",
		"purchase_price": 1500,
		"max_level": 10,
		"tier_prices": { 2: 700, 3: 1500, 4: 2800, 5: 5000, 6: 8500, 7: 14000, 8: 22000, 9: 34000, 10: 48000 },
		"tier_descriptions": {
			1: "Armored Plating (8 HP, Triple Heavy Battery)",
			2: "Tempered Rivets (8 HP, 8.7 m/s, +5% Firepower)",
			3: "Dual Crew Stations (9 HP, 8.9 m/s, +Deck Crew Sockets)",
			4: "Blast Bulkheads (9 HP, 9.1 m/s, +15% Firepower)",
			5: "Steam Injectors (9 HP, 9.3 m/s, +20% Firepower)",
			6: "Flank Gunports (10 HP, 9.5 m/s, +Dual Swivel Mounts)",
			7: "Cast Iron Prow (10 HP, 9.7 m/s, +30% Firepower)",
			8: "Reinforced Boiler (10 HP, 9.9 m/s, +35% Firepower)",
			9: "Full Battery Array (11 HP, 10.1 m/s, +Quad Swivel Mounts)",
			10: "Dreadnought Hull (11 HP, 10.3 m/s, All Mounts Maxed)"
		},
		"base_hp": 8,
		"base_speed": 8.5,
		"fire_rate": 0.22,
		"preview_texture": "res://assets/sprites/user_vessels/The Ironclad.png"
	},
	"bombard_skiff": {
		"id": "bombard_skiff",
		"name": "The Bombard Skiff",
		"archetype": "Heavy Siege Artillery",
		"resource_path": "res://src/data/resources/user_vessels/bombard_skiff_ship.tres",
		"purchase_price": 800,
		"max_level": 10,
		"tier_prices": { 2: 400, 3: 900, 4: 1800, 5: 3400, 6: 5800, 7: 9500, 8: 15000, 9: 23000, 10: 33000 },
		"tier_descriptions": {
			1: "Artillery Skiff (4 HP, Siege Mortar)",
			2: "Flank Gunwales (4 HP, 7.8 m/s, +Dual Rail Mounts)",
			3: "Quarterdeck Station (5 HP, 8.0 m/s, +Quarterdeck Crew Socket)",
			4: "Reinforced Hull (5 HP, 8.2 m/s, +15% Firepower)",
			5: "Quick-Load Hoists (5 HP, 8.5 m/s, +20% Firepower)",
			6: "Twin Heavy Mortars (6 HP, 8.8 m/s, +Heavy Caliber)",
			7: "Heavy Caliber Bore (6 HP, 9.0 m/s, +30% Firepower)",
			8: "Reinforced Transom (6 HP, 9.3 m/s, +35% Firepower)",
			9: "Dreadnought Mortar (7 HP, 9.5 m/s, +Expanded Shell Spread)",
			10: "Siege Dreadnought (7 HP, 9.8 m/s, All Mounts Maxed)"
		},
		"base_hp": 4,
		"base_speed": 7.6,
		"fire_rate": 0.95,
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
		"upgrade_prices": { 2: 500, 3: 1100, 4: 2400, 5: 5000 },
		"levels": {
			1: { "damage": 3, "cooldown": 1.2, "description": "3 AoE damage, 1.2s cooldown" },
			2: { "damage": 5, "cooldown": 1.0, "description": "5 AoE damage, 1.0s cooldown" },
			3: { "damage": 5, "cooldown": 0.9, "description": "5 AoE damage + secondary mini-cluster bounce" },
			4: { "damage": 6, "cooldown": 0.8, "description": "6 AoE damage, wider blast radius" },
			5: { "damage": 7, "cooldown": 0.7, "description": "7 AoE damage + double cluster detonation" }
		}
	},
	"skeleton_tosser": {
		"id": "skeleton_tosser",
		"name": "Skeleton Tosser",
		"role": "PYROTECHNIC",
		"resource_path": "res://src/data/resources/user_crew/crew_skeleton_tosser.tres",
		"preview_texture": "res://assets/sprites/user_crew/skeleton_crew.png",
		"unlock_price": 600,
		"upgrade_prices": { 2: 850, 3: 1800, 4: 3800, 5: 7500 },
		"levels": {
			1: { "damage": 4, "cooldown": 1.4, "description": "4 direct damage + short burn" },
			2: { "damage": 6, "cooldown": 1.2, "description": "6 damage, wider fire radius" },
			3: { "damage": 6, "cooldown": 1.0, "description": "Lingering napalm effect on water surface" },
			4: { "damage": 7, "cooldown": 0.9, "description": "7 damage, persistent blaze" },
			5: { "damage": 8, "cooldown": 0.8, "description": "8 damage, inferno tempest" }
		}
	},
	"grease_monkey": {
		"id": "grease_monkey",
		"name": "Grease Monkey",
		"role": "ARTILLERY MECHANIC",
		"resource_path": "res://src/data/resources/user_crew/crew_grease_monkey.tres",
		"preview_texture": "res://assets/sprites/user_crew/grease_monkey.png",
		"unlock_price": 500,
		"upgrade_prices": { 2: 750, 3: 1600, 4: 3200, 5: 6500 },
		"levels": {
			1: { "damage": 4, "cooldown": 1.2, "description": "Artillery Specialist: +25% Mortar RoF, +20% AoE Blast Radius, 4 DMG explosive support" },
			2: { "damage": 5, "cooldown": 1.1, "description": "+30% Mortar RoF, +25% AoE Blast, +15% Shell Velocity, 5 DMG support" },
			3: { "damage": 6, "cooldown": 1.0, "description": "+35% Mortar RoF, +30% AoE Blast, +25% Shell Velocity, 6 DMG support" },
			4: { "damage": 7, "cooldown": 0.9, "description": "+40% Mortar RoF, +35% AoE Blast, +30% Shell Velocity, 7 DMG support" },
			5: { "damage": 8, "cooldown": 0.8, "description": "+50% Mortar RoF, +50% AoE Blast, +40% Shell Velocity, 8 DMG support" }
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

var _bridging_event: bool = false

func _ready() -> void:
	load_game()
	apply_audio_settings()
	set_performance_mode(false)
	_setup_event_bus_bridges()

func _setup_event_bus_bridges() -> void:
	if not EventBus:
		return
	# EventBus -> GameState (for legacy listeners attached to GameState)
	EventBus.level_completed.connect(func(d: int, t: int) -> void:
		if not _bridging_event:
			_bridging_event = true
			level_completed.emit(d, t)
			_bridging_event = false
	)
	EventBus.campaign_completed.connect(func(d: int, t: int) -> void:
		if not _bridging_event:
			_bridging_event = true
			campaign_completed.emit(d, t)
			_bridging_event = false
	)
	EventBus.boss_spawned_event.connect(func(n: String, m: int) -> void:
		if not _bridging_event:
			_bridging_event = true
			boss_spawned_event.emit(n, m)
			_bridging_event = false
	)
	EventBus.boss_health_changed.connect(func(c: int, m: int) -> void:
		if not _bridging_event:
			_bridging_event = true
			boss_health_changed.emit(c, m)
			_bridging_event = false
	)
	EventBus.distance_target_reached.connect(func() -> void:
		if not _bridging_event:
			_bridging_event = true
			distance_target_reached.emit()
			_bridging_event = false
	)
	EventBus.run_failed.connect(func(c: int, d: float) -> void:
		if not _bridging_event:
			_bridging_event = true
			run_failed.emit(c, d)
			_bridging_event = false
	)
	# GameState -> EventBus (for legacy emitters calling GameState.<signal>.emit)
	level_completed.connect(func(d: int, t: int) -> void:
		if not _bridging_event:
			_bridging_event = true
			EventBus.level_completed.emit(d, t)
			_bridging_event = false
	)
	campaign_completed.connect(func(d: int, t: int) -> void:
		if not _bridging_event:
			_bridging_event = true
			EventBus.campaign_completed.emit(d, t)
			_bridging_event = false
	)
	boss_spawned_event.connect(func(n: String, m: int) -> void:
		if not _bridging_event:
			_bridging_event = true
			EventBus.boss_spawned_event.emit(n, m)
			_bridging_event = false
	)
	boss_health_changed.connect(func(c: int, m: int) -> void:
		if not _bridging_event:
			_bridging_event = true
			EventBus.boss_health_changed.emit(c, m)
			_bridging_event = false
	)
	distance_target_reached.connect(func() -> void:
		if not _bridging_event:
			_bridging_event = true
			EventBus.distance_target_reached.emit()
			_bridging_event = false
	)
	run_failed.connect(func(c: int, d: float) -> void:
		if not _bridging_event:
			_bridging_event = true
			EventBus.run_failed.emit(c, d)
			_bridging_event = false
	)

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
	var path: Variant = LEVEL_RESOURCES.get(current_level, LEVEL_RESOURCES[1])
	if ResourceLoader.exists(path):
		return load(path) as LevelData
	return null

func get_vessel_resource(vessel_id: String) -> ShipData:
	if vessel_id in VESSEL_CATALOG:
		var path: Variant = VESSEL_CATALOG[vessel_id]["resource_path"]
		if ResourceLoader.exists(path):
			return load(path) as ShipData
	return null

func get_active_ship_resource() -> ShipData:
	var res := get_vessel_resource(active_vessel)
	if res:
		return res
	var fallback_path: Variant = LEVEL_SHIPS.get(current_level, LEVEL_SHIPS[1])
	if ResourceLoader.exists(fallback_path):
		return load(fallback_path) as ShipData
	return null

func get_current_ship_resource() -> ShipData:
	return get_active_ship_resource()

func get_equipped_vessel_id() -> String:
	return active_vessel

func get_active_ship_tier() -> int:
	return vessel_tiers.get(active_vessel, 1)

func is_vessel_owned(vessel_id: String) -> bool:
	return vessel_id in owned_vessels

func get_vessel_tier(vessel_id: String) -> int:
	return vessel_tiers.get(vessel_id, 1)

func get_upgrade_cost(vessel_id: String, target_tier: int) -> int:
	var res := get_vessel_resource(vessel_id)
	if res and res.upgrade_costs.size() >= target_tier and target_tier >= 1:
		var base_cost: int = res.upgrade_costs[target_tier - 1]
		if (tutorial_step == TutorialStep.LEVEL_3_COMPLETED or tutorial_step == TutorialStep.LEVEL_4_COMPLETED) and vessel_id == "sloop" and target_tier == 2:
			return mini(base_cost, doubloons)
		return base_cost
	if VESSEL_CATALOG.has(vessel_id):
		var v_dict: Dictionary = VESSEL_CATALOG[vessel_id] as Dictionary
		var prices: Dictionary = v_dict.get("tier_prices", {}) as Dictionary
		var base_cost: int = int(prices.get(target_tier, 0))
		if (tutorial_step == TutorialStep.LEVEL_3_COMPLETED or tutorial_step == TutorialStep.LEVEL_4_COMPLETED) and vessel_id == "sloop" and target_tier == 2:
			return mini(base_cost, doubloons)
		return base_cost
	return 0

func can_afford(cost: int) -> bool:
	return doubloons >= cost

func buy_vessel(vessel_id: String) -> bool:
	if not VESSEL_CATALOG.has(vessel_id):
		return false
	if is_vessel_owned(vessel_id):
		return false
	var cost: int = int(VESSEL_CATALOG[vessel_id]["purchase_price"])
	# Tutorial Discount: Guarantee affordable Sloop purchase during tutorial
	if tutorial_step == TutorialStep.LEVEL_2_COMPLETED and vessel_id == "sloop":
		cost = mini(cost, doubloons)
	if doubloons < cost:
		if EventBus and EventBus.has_signal("shipyard_item_action"):
			EventBus.shipyard_item_action.emit(vessel_id, "vessel", cost, doubloons, false, "insufficient_funds")
		return false
	doubloons -= cost
	owned_vessels.append(vessel_id)
	vessel_tiers[vessel_id] = 1
	active_vessel = vessel_id
	save_game()
	print("[PURCHASE] Bought Vessel: %s | Cost: %d 🪙 | River Level: %d | Vault Remaining: %d 🪙" % [vessel_id, cost, current_level, doubloons])
	if EventBus and EventBus.has_signal("shipyard_item_action"):
		EventBus.shipyard_item_action.emit(vessel_id, "vessel", cost, doubloons + cost, true, "purchased")
	doubloons_changed.emit(doubloons)
	active_vessel_changed.emit(active_vessel)
	if tutorial_step == TutorialStep.LEVEL_2_COMPLETED and vessel_id == "sloop":
		advance_tutorial_to(TutorialStep.SLOOP_PURCHASED)
	return true

func get_max_vessel_tier(vessel_id: String) -> int:
	if VESSEL_CATALOG.has(vessel_id):
		var v_dict: Dictionary = VESSEL_CATALOG[vessel_id] as Dictionary
		if v_dict.has("max_level"):
			return int(v_dict["max_level"])
	var res := get_vessel_resource(vessel_id)
	if res and not res.upgrade_costs.is_empty():
		return res.upgrade_costs.size()
	return 3

func get_max_vessel_level(vessel_id: String) -> int:
	return get_max_vessel_tier(vessel_id)

func get_vessel_level(vessel_id: String) -> int:
	return get_vessel_tier(vessel_id)

func upgrade_vessel_tier(vessel_id: String) -> bool:
	if not is_vessel_owned(vessel_id):
		return false
	var cur_tier := get_vessel_tier(vessel_id)
	var max_tier := get_max_vessel_tier(vessel_id)
	if cur_tier >= max_tier:
		return false
	var next_tier := cur_tier + 1
	var cost := get_upgrade_cost(vessel_id, next_tier)
	# Tutorial Discount: Guarantee affordable Sloop Tier 2 upgrade during tutorial
	if (tutorial_step == TutorialStep.LEVEL_3_COMPLETED or tutorial_step == TutorialStep.LEVEL_4_COMPLETED) and vessel_id == "sloop" and next_tier == 2:
		cost = mini(cost, doubloons)
	if doubloons < cost:
		if EventBus and EventBus.has_signal("shipyard_item_action"):
			EventBus.shipyard_item_action.emit("%s_t%d" % [vessel_id, next_tier], "vessel_upgrade", cost, doubloons, false, "insufficient_funds")
		return false
	doubloons -= cost
	vessel_tiers[vessel_id] = next_tier
	save_game()
	print("[UPGRADE] Upgraded Vessel: %s to Tier %d | Cost: %d 🪙 | River Level: %d | Vault Remaining: %d 🪙" % [vessel_id, next_tier, cost, current_level, doubloons])
	if EventBus and EventBus.has_signal("shipyard_item_action"):
		EventBus.shipyard_item_action.emit("%s_t%d" % [vessel_id, next_tier], "vessel_upgrade", cost, doubloons + cost, true, "upgraded")
	doubloons_changed.emit(doubloons)
	if (tutorial_step == TutorialStep.LEVEL_3_COMPLETED or tutorial_step == TutorialStep.LEVEL_4_COMPLETED) and vessel_id == "sloop" and next_tier == 2:
		advance_tutorial_to(TutorialStep.SLOOP_T2_UPGRADED)
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
	var cur_tier := get_vessel_tier(active_vessel)
	var max_tier := get_max_vessel_tier(active_vessel)
	if cur_tier >= max_tier:
		return false
	var next_tier := cur_tier + 1
	if (tutorial_step == TutorialStep.LEVEL_3_COMPLETED or tutorial_step == TutorialStep.LEVEL_4_COMPLETED) and active_vessel == "sloop" and next_tier == 2:
		return true
	var cost := get_upgrade_cost(active_vessel, next_tier)
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
		var c_dict: Dictionary = CREW_CATALOG[crew_id] as Dictionary
		var prices: Dictionary = c_dict.get("upgrade_prices", {}) as Dictionary
		return int(prices.get(target_level, 0))
	return 0

func buy_crew(crew_id: String) -> bool:
	if not CREW_CATALOG.has(crew_id):
		return false
	if is_crew_unlocked(crew_id):
		return false
	var cost := get_crew_unlock_cost(crew_id)
	# Tutorial Discount: Guarantee affordable crew purchase during tutorial
	if (tutorial_step == TutorialStep.LEVEL_3_COMPLETED or tutorial_step == TutorialStep.LEVEL_4_COMPLETED) and crew_id == "monkey_bomber":
		cost = mini(cost, doubloons)
	if doubloons < cost:
		if EventBus and EventBus.has_signal("shipyard_item_action"):
			EventBus.shipyard_item_action.emit(crew_id, "crew", cost, doubloons, false, "insufficient_funds")
		return false
	doubloons -= cost
	unlocked_crew[crew_id] = 1
	save_game()
	print("[PURCHASE] Hired Crew: %s (Tier 1) | Cost: %d 🪙 | River Level: %d | Vault Remaining: %d 🪙" % [crew_id, cost, current_level, doubloons])
	if EventBus and EventBus.has_signal("shipyard_item_action"):
		EventBus.shipyard_item_action.emit(crew_id, "crew", cost, doubloons + cost, true, "hired")
	doubloons_changed.emit(doubloons)
	crew_unlocked.emit(crew_id, 1)
	auto_equip_crew_to_vessel(active_vessel, crew_id)
	if (tutorial_step == TutorialStep.LEVEL_3_COMPLETED or tutorial_step == TutorialStep.LEVEL_4_COMPLETED) and crew_id == "monkey_bomber":
		advance_tutorial_to(TutorialStep.CREW_EQUIPPED)
	return true


func auto_equip_crew_to_vessel(vessel_id: String, crew_id: String) -> bool:
	if not is_crew_unlocked(crew_id):
		return false
	var cur_tier := get_vessel_tier(vessel_id)
	var available_sockets := get_crew_sockets_for_ship(vessel_id, cur_tier)
	if available_sockets.is_empty():
		return false
	var ship_map: Dictionary = equipped_crew.get(vessel_id, {}) as Dictionary
	var target_socket := ""
	for s: String in available_sockets:
		if not ship_map.has(s) or ship_map[s] == "":
			target_socket = s
			break
	if target_socket == "":
		target_socket = available_sockets[0]
	return equip_crew(vessel_id, target_socket, crew_id)

func upgrade_crew_level(crew_id: String) -> bool:
	if not is_crew_unlocked(crew_id):
		return false
	var cur_lvl := get_crew_level(crew_id)
	var max_lvl: int = 5
	if CREW_CATALOG.has(crew_id):
		var c_dict: Dictionary = CREW_CATALOG[crew_id] as Dictionary
		if c_dict.has("levels"):
			max_lvl = (c_dict["levels"] as Dictionary).size()
	if cur_lvl >= max_lvl:
		return false
	var next_lvl := cur_lvl + 1
	var cost := get_crew_upgrade_cost(crew_id, next_lvl)
	if doubloons < cost:
		if EventBus and EventBus.has_signal("shipyard_item_action"):
			EventBus.shipyard_item_action.emit("%s_lvl%d" % [crew_id, next_lvl], "crew_upgrade", cost, doubloons, false, "insufficient_funds")
		return false
	doubloons -= cost
	unlocked_crew[crew_id] = next_lvl
	save_game()
	print("[UPGRADE] Promoted Crew: %s to Tier %d | Cost: %d 🪙 | River Level: %d | Vault Remaining: %d 🪙" % [crew_id, next_lvl, cost, current_level, doubloons])
	if EventBus and EventBus.has_signal("shipyard_item_action"):
		EventBus.shipyard_item_action.emit("%s_lvl%d" % [crew_id, next_lvl], "crew_upgrade", cost, doubloons + cost, true, "promoted")
	doubloons_changed.emit(doubloons)
	crew_unlocked.emit(crew_id, next_lvl)
	return true


func get_crew_sockets_for_ship(ship_id: String, tier: int = -1) -> Array[String]:
	var ship_res := get_vessel_resource(ship_id)
	if not ship_res:
		return []
	if tier < 1:
		tier = get_vessel_tier(ship_id)
	if ship_res.tier_sockets.is_empty():
		return []
	var s_idx := clampi(tier - 1, 0, ship_res.tier_sockets.size() - 1)
	var active_sockets: Array = ship_res.tier_sockets[s_idx]
	var crew_sockets: Array[String] = []
	for s_name: Variant in active_sockets:
		var s_lower := str(s_name).to_lower()
		if "crew" in s_lower:
			crew_sockets.append(str(s_name))
	return crew_sockets

func get_equipped_crew(ship_id: String, socket_name: String) -> String:
	if not equipped_crew.has(ship_id):
		return ""
	var ship_map: Dictionary = equipped_crew.get(ship_id, {}) as Dictionary
	if ship_map.has(socket_name):
		return str(ship_map[socket_name])
	return ""

func is_crew_equipped_on_ship(ship_id: String, crew_id: String) -> bool:
	if not equipped_crew.has(ship_id):
		return false
	var ship_map: Dictionary = equipped_crew.get(ship_id, {}) as Dictionary
	for s: String in ship_map:
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
	var eq_ship: Dictionary = equipped_crew[ship_id] as Dictionary
	# If this crew is already on another socket on this ship, unequip from old socket
	for s: String in eq_ship.keys():
		if eq_ship[s] == crew_id:
			eq_ship.erase(s)
	eq_ship[socket_name] = crew_id
	save_game()
	crew_equipped.emit(ship_id, socket_name, crew_id)
	return true

func unequip_crew(ship_id: String, socket_name: String) -> bool:
	if not equipped_crew.has(ship_id) or not (equipped_crew[ship_id] is Dictionary):
		return false
	var eq_ship: Dictionary = equipped_crew[ship_id] as Dictionary
	if eq_ship.has(socket_name):
		eq_ship.erase(socket_name)
		save_game()
		crew_equipped.emit(ship_id, socket_name, "")
		return true
	return false

func toggle_equip_crew_active_ship(crew_id: String) -> bool:
	if not is_crew_unlocked(crew_id):
		return false
	if not is_vessel_owned(active_vessel):
		return false
	var cur_tier := get_vessel_tier(active_vessel)
	var available_sockets := get_crew_sockets_for_ship(active_vessel, cur_tier)
	
	# Safe Ship Swap Guard: If vessel has 0 crew sockets (e.g. Tier 1), cannot equip
	if available_sockets.is_empty():
		return false
		
	# If already equipped on active ship, unequip it!
	if is_crew_equipped_on_active_ship(crew_id):
		var eq_map: Dictionary = equipped_crew.get(active_vessel, {}) as Dictionary
		for s: String in eq_map.keys():
			if eq_map[s] == crew_id:
				unequip_crew(active_vessel, s)
				return true
		return false
		
	# Otherwise find first open socket or replace first socket
	var target_socket := ""
	var ship_map: Dictionary = equipped_crew.get(active_vessel, {}) as Dictionary
	for s: String in available_sockets:
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
	var item_dict: Dictionary = OUTFITTING_CATALOG[item_id] as Dictionary
	var price: int = int(item_dict.get("price", 0))
	if doubloons < price:
		if EventBus and EventBus.has_signal("shipyard_item_action"):
			EventBus.shipyard_item_action.emit(item_id, "outfitting", price, doubloons, false, "insufficient_funds")
		return false
	doubloons -= price
	unlocked_outfitting[item_id] = true
	save_game()
	print("[PURCHASE] Bought Outfitting: %s | Cost: %d 🪙 | River Level: %d | Vault Remaining: %d 🪙" % [item_id, price, current_level, doubloons])
	if EventBus and EventBus.has_signal("shipyard_item_action"):
		EventBus.shipyard_item_action.emit(item_id, "outfitting", price, doubloons + price, true, "purchased")
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
	var item_dict: Dictionary = OUTFITTING_CATALOG[item_id] as Dictionary
	var cat: String = str(item_dict.get("category", ""))
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
	var now := Time.get_ticks_msec() / 1000.0
	fodder_kill_timestamps.append(now)
	var cutoff := now - 2.0
	fodder_kill_timestamps = fodder_kill_timestamps.filter(func(t: Variant) -> bool: return t >= cutoff)
	if fodder_kill_timestamps.size() >= 3:
		fodder_kill_timestamps.clear()
		fire_frenzy_triggered.emit(2.5)



func add_doubloons(amount: int, source: String = "general") -> void:
	if is_game_active:
		add_run_doubloons(amount, source)
	else:
		doubloons += amount
		save_game()
		doubloons_changed.emit(doubloons)
		if EventBus and EventBus.has_signal("doubloon_awarded"):
			EventBus.doubloon_awarded.emit(amount, source, doubloons)

func add_run_doubloons(amount: int, source: String = "general") -> void:
	run_doubloons += amount
	doubloons_changed.emit(doubloons + run_doubloons)
	if EventBus and EventBus.has_signal("doubloon_awarded"):
		EventBus.doubloon_awarded.emit(amount, source, run_doubloons)


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
	print("[RIVER LEVEL] Selected Level %d" % current_level)

func get_highest_level_unlocked() -> int:
	return highest_unlocked_level

func unlock_next_level() -> void:
	last_cleared_level = current_level
	if current_level >= highest_unlocked_level:
		highest_unlocked_level = min(45, current_level + 1)
		just_cleared_level = true
	unlocked_levels = highest_unlocked_level
	current_level = min(45, last_cleared_level + 1)
	current_selected_level = current_level
	save_game()
	print("[RIVER LEVEL] Unlocked River Level %d, Next Selected Level is %d" % [highest_unlocked_level, current_level])

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

func record_mob_leaked(mob_name: String = "Enemy Mob") -> void:
	mobs_leaked += 1
	if EventBus and EventBus.has_signal("mob_escaped"):
		EventBus.mob_escaped.emit(mob_name, mobs_leaked)


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
	tutorial_step = TutorialStep.NOT_STARTED
	hub_buildings_built = []
	should_open_map = false
	should_auto_start = false
	should_auto_start_endless = false
	reset_level()
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	save_game()
	doubloons_changed.emit(doubloons)
	active_vessel_changed.emit(active_vessel)
	tutorial_step_changed.emit(tutorial_step)

func init_playtest_fresh_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var backup_path: String = "user://cove_corsair_save.backup.json"
		var r_file := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if r_file:
			var txt: String = r_file.get_as_text()
			r_file.close()
			var w_file := FileAccess.open(backup_path, FileAccess.WRITE)
			if w_file:
				w_file.store_string(txt)
				w_file.close()
				print("💾 [BACKUP] Saved user save backup to %s" % backup_path)
	reset_save_data()
	print("🏴‍☠️ [PLAYTEST] Fresh save initialized: Level 1, 0 🪙, Starter Dinghy T1")


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
		"tutorial_step": tutorial_step,
		"hub_buildings_built": hub_buildings_built,
		"master_volume": master_volume,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"master_muted": master_muted,
		"music_muted": music_muted,
		"sfx_muted": sfx_muted
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		var json_str := JSON.stringify(save_dict, "\t")
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
	music_volume = 0.55
	sfx_volume = 1.0
	master_muted = false
	music_muted = false
	sfx_muted = false
	hub_buildings_built = []

	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return

	var json_str := file.get_as_text()
	file.close()
	var json := JSON.new()
	var err := json.parse(json_str)
	if err == OK and json.data is Dictionary:
		var data: Dictionary = json.data
		doubloons = max(0, int(data.get("doubloons", doubloons)))
		
		if data.has("owned_vessels") and data["owned_vessels"] is Array:
			var loaded_owned: Array[String] = []
			for v: Variant in (data["owned_vessels"] as Array):
				var v_str := str(v)
				if v_str in VESSEL_CATALOG and not loaded_owned.has(v_str):
					loaded_owned.append(v_str)
			if not loaded_owned.has("dinghy"):
				loaded_owned.push_front("dinghy")
			owned_vessels = loaded_owned
			
		if data.has("vessel_tiers") and data["vessel_tiers"] is Dictionary:
			var tiers_dict: Dictionary = data["vessel_tiers"] as Dictionary
			for k: Variant in tiers_dict:
				var v_key := str(k)
				if v_key in VESSEL_CATALOG:
					var max_tier: int = get_max_vessel_tier(v_key)
					vessel_tiers[v_key] = clampi(int(tiers_dict[k]), 1, max_tier)

		# Strict active vessel sanitization: MUST exist in owned_vessels
		if data.has("active_vessel"):
			var loaded_active := str(data["active_vessel"])
			if loaded_active in owned_vessels:
				active_vessel = loaded_active
			else:
				active_vessel = "dinghy"
		else:
			active_vessel = "dinghy"

		if data.has("unlocked_crew") and data["unlocked_crew"] is Dictionary:
			unlocked_crew = {}
			var crew_dict: Dictionary = data["unlocked_crew"] as Dictionary
			for c_id: Variant in crew_dict:
				var cid_str := str(c_id)
				if cid_str in CREW_CATALOG:
					unlocked_crew[cid_str] = clamp(int(crew_dict[c_id]), 1, 3)
		else:
			unlocked_crew = {}

		if data.has("equipped_crew") and data["equipped_crew"] is Dictionary:
			equipped_crew = {}
			var eq_crew_dict: Dictionary = data["equipped_crew"] as Dictionary
			for s_id: Variant in eq_crew_dict:
				var sid_str := str(s_id)
				if eq_crew_dict[s_id] is Dictionary:
					equipped_crew[sid_str] = {}
					var sub_dict: Dictionary = eq_crew_dict[s_id] as Dictionary
					for sock: Variant in sub_dict:
						var c_val := str(sub_dict[sock])
						if c_val in CREW_CATALOG:
							equipped_crew[sid_str][str(sock)] = c_val
		else:
			equipped_crew = {}

		if data.has("unlocked_outfitting") and data["unlocked_outfitting"] is Dictionary:
			unlocked_outfitting = {"standard_iron": true, "none": true}
			var outfit_dict: Dictionary = data["unlocked_outfitting"] as Dictionary
			for o_id: Variant in outfit_dict:
				var oid_str := str(o_id)
				if oid_str in OUTFITTING_CATALOG:
					unlocked_outfitting[oid_str] = (outfit_dict[o_id] == true)
		else:
			unlocked_outfitting = {"standard_iron": true, "none": true}

		if data.has("equipped_ammo") and data["equipped_ammo"] is Dictionary:
			equipped_ammo = {"dinghy": "standard_iron", "sloop": "standard_iron", "ironclad": "standard_iron", "bombard_skiff": "standard_iron"}
			var ammo_dict: Dictionary = data["equipped_ammo"] as Dictionary
			for s_id: Variant in ammo_dict:
				var sid_str := str(s_id)
				var a_val := str(ammo_dict[s_id])
				if a_val in OUTFITTING_CATALOG:
					equipped_ammo[sid_str] = a_val
		else:
			equipped_ammo = {"dinghy": "standard_iron", "sloop": "standard_iron", "ironclad": "standard_iron", "bombard_skiff": "standard_iron"}

		if data.has("equipped_plating") and data["equipped_plating"] is Dictionary:
			equipped_plating = {"dinghy": "none", "sloop": "none", "ironclad": "none", "bombard_skiff": "none"}
			var plating_dict: Dictionary = data["equipped_plating"] as Dictionary
			for s_id: Variant in plating_dict:
				var sid_str := str(s_id)
				var p_val := str(plating_dict[s_id])
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
			just_cleared_level = (data["just_cleared_level"] == true)
		if data.has("last_cleared_level"):
			last_cleared_level = clamp(int(data["last_cleared_level"]), 1, 45)
		if data.has("level_high_scores") and data["level_high_scores"] is Dictionary:
			var scores_dict: Dictionary = data["level_high_scores"] as Dictionary
			for k: Variant in scores_dict:
				var lvl_key := int(k)
				if lvl_key >= 1 and lvl_key <= 45:
					level_high_scores[lvl_key] = max(0, int(scores_dict[k]))

		if data.has("level_stars") and data["level_stars"] is Dictionary:
			var stars_dict: Dictionary = data["level_stars"] as Dictionary
			for k: Variant in stars_dict:
				var lvl_key := int(k)
				if lvl_key >= 1 and lvl_key <= 45:
					level_stars[lvl_key] = clamp(int(stars_dict[k]), 0, 3)

		if data.has("tutorial_step"):
			tutorial_step = int(data["tutorial_step"])
		else:
			# Legacy save migration: auto-complete if level > 2 or Sloop already owned
			if highest_unlocked_level > 2 or is_vessel_owned("sloop"):
				tutorial_step = TutorialStep.COMPLETED
			else:
				tutorial_step = TutorialStep.NOT_STARTED

		if data.has("hub_buildings_built") and data["hub_buildings_built"] is Array:
			for b: Variant in (data["hub_buildings_built"] as Array):
				var b_str: String = str(b)
				if not hub_buildings_built.has(b_str):
					hub_buildings_built.append(b_str)

		# Self-healing / Fast-forward checks on loaded tutorial_step:
		check_and_fast_forward_tutorial()

		if data.has("master_volume"): master_volume = clamp(float(data["master_volume"]), 0.0, 1.0)
		if data.has("music_volume"): music_volume = clamp(float(data["music_volume"]), 0.0, 1.0)
		if data.has("sfx_volume"): sfx_volume = clamp(float(data["sfx_volume"]), 0.0, 1.0)
		if data.has("master_muted"): master_muted = (data["master_muted"] == true)
		if data.has("music_muted"): music_muted = (data["music_muted"] == true)
		if data.has("sfx_muted"): sfx_muted = (data["sfx_muted"] == true)

		doubloons_changed.emit(doubloons)
		tutorial_step_changed.emit(tutorial_step)
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
		tutorial_step = TutorialStep.NOT_STARTED

# --- Tutorial State Management ---

func is_tutorial_completed() -> bool:
	return tutorial_step >= TutorialStep.COMPLETED

func is_tutorial_in_progress() -> bool:
	return tutorial_step < TutorialStep.COMPLETED

func check_and_fast_forward_tutorial() -> void:
	if highest_unlocked_level > 5:
		advance_tutorial_to(TutorialStep.COMPLETED)
		return
	if tutorial_step == TutorialStep.CREW_EQUIPPED and (highest_unlocked_level >= 5 or current_level >= 5):
		if get_vessel_tier("sloop") >= 2:
			advance_tutorial_to(TutorialStep.SLOOP_T2_UPGRADED)
		else:
			advance_tutorial_to(TutorialStep.LEVEL_4_COMPLETED)
		return
	if tutorial_step == TutorialStep.LEVEL_2_COMPLETED and is_vessel_owned("sloop"):
		if active_vessel != "sloop":
			set_active_vessel("sloop")
		advance_tutorial_to(TutorialStep.SLOOP_PURCHASED)
	elif tutorial_step == TutorialStep.LEVEL_3_COMPLETED and is_crew_unlocked("monkey_bomber"):
		if not is_crew_equipped_on_active_ship("monkey_bomber"):
			auto_equip_crew_to_vessel(active_vessel, "monkey_bomber")
		advance_tutorial_to(TutorialStep.CREW_EQUIPPED)
	elif tutorial_step == TutorialStep.LEVEL_4_COMPLETED and get_vessel_tier("sloop") >= 2:
		advance_tutorial_to(TutorialStep.SLOOP_T2_UPGRADED)

func advance_tutorial_to(step: int) -> void:
	if step > tutorial_step:
		tutorial_step = step
		save_game()
		tutorial_step_changed.emit(tutorial_step)
		print("[TUTORIAL] Advanced to step %d (%s)" % [tutorial_step, TutorialStep.keys()[tutorial_step] if tutorial_step < TutorialStep.size() else "UNKNOWN"])

func reset_tutorial() -> void:
	tutorial_step = TutorialStep.NOT_STARTED
	highest_unlocked_level = 1
	current_selected_level = 1
	current_level = 1
	unlocked_levels = 1
	doubloons = 0
	active_vessel = "dinghy"
	owned_vessels = ["dinghy"]
	vessel_tiers["dinghy"] = 1
	if vessel_tiers.has("sloop"):
		vessel_tiers["sloop"] = 1
	unlocked_crew = {}
	equipped_crew = {}
	hub_buildings_built = []
	save_game()
	active_vessel_changed.emit(active_vessel)
	doubloons_changed.emit(doubloons)
	tutorial_step_changed.emit(tutorial_step)
	print("[TUTORIAL] Reset to step 0 (Level 1, Dinghy T1, 0 doubloons)")

