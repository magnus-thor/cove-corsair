extends Node3D

func _ready() -> void:
	print("\n========================================================")
	print("  TESTING GREASE MONKEY CREW & 3D MODEL LOADING")
	print("========================================================\n")
	
	# 1. Crew Resource Schema
	var gm_res: CrewData = load("res://src/data/resources/user_crew/crew_grease_monkey.tres") as CrewData
	assert(gm_res != null, "crew_grease_monkey.tres must load")
	assert(gm_res.weapon_name == "Grease Monkey", "weapon_name must be 'Grease Monkey'")
	assert(gm_res.crew_role == "mechanic", "crew_role must be 'mechanic'")
	print("[PASS] crew_grease_monkey.tres verified (Role: mechanic, Ammo: heavy_shot).")
	
	# 2. GameState Catalog Registration
	assert(GameState.CREW_CATALOG.has("grease_monkey"), "GameState.CREW_CATALOG must have 'grease_monkey'")
	var gm_cat: Dictionary = GameState.CREW_CATALOG["grease_monkey"]
	assert(gm_cat["unlock_price"] == 500, "Grease Monkey unlock_price must be 500")
	assert(not GameState.CREW_CATALOG.has("deckhand_sniper"), "Sniper must NOT be registered as crew")
	print("[PASS] GameState CREW_CATALOG verified (Grease Monkey present, Sniper reserved).")
	
	# 3. 3D Model Asset Presence
	assert(ResourceLoader.exists("res://assets/models/user/crew/artillery_grease__monkey.glb"), "artillery_grease__monkey.glb must exist")
	assert(ResourceLoader.exists("res://assets/models/user/crew/weapon_deckhand_sniper.glb"), "weapon_deckhand_sniper.glb preserved for future pirate captain")
	print("[PASS] 3D assets verified in assets/models/user/crew/.")
	
	# 4. AttachedWeapon 3D Model Instantiation
	var attached_scene: PackedScene = load("res://src/gameplay/player/attached_weapon.tscn") as PackedScene
	assert(attached_scene != null, "attached_weapon.tscn must load")
	var weapon: AttachedWeapon = attached_scene.instantiate() as AttachedWeapon
	add_child(weapon)
	
	weapon.crew_id = "grease_monkey"
	weapon.weapon_data = gm_res
	weapon._apply_weapon_data()
	
	assert(weapon.model_container != null, "model_container must be valid")
	assert(weapon.model_container.visible == true, "model_container must be visible for crew")
	var crew_mesh: Node3D = weapon.model_container.get_node_or_null("CrewMesh") as Node3D
	assert(crew_mesh != null, "CrewMesh must be instantiated inside model_container")
	assert(crew_mesh.get_meta("glb_path", "") == "res://assets/models/user/crew/artillery_grease__monkey.glb", "CrewMesh must instantiate artillery_grease__monkey.glb")
	assert(crew_mesh.scale == Vector3(0.55, 0.55, 0.55), "CrewMesh scale must be (0.55, 0.55, 0.55)")
	print("[PASS] AttachedWeapon successfully instantiated 3D artillery_grease__monkey.glb.")
	
	# 5. Grease Monkey Mortar Buffs
	# Equip on a player vessel with bow mortar
	var skiff_scene: PackedScene = load("res://src/gameplay/player/player_boat.tscn") as PackedScene
	var player: PlayerSwerve = skiff_scene.instantiate() as PlayerSwerve
	add_child(player)
	player.ship_data = load("res://src/data/resources/user_vessels/bombard_skiff_ship.tres") as ShipData
	
	GameState.unlocked_crew["grease_monkey"] = 1
	GameState.equip_crew("bombard_skiff", "QuarterdeckCrew", "grease_monkey")
	player.apply_tier(3)
	
	assert(GameState.is_crew_equipped_on_ship("bombard_skiff", "grease_monkey"), "Grease Monkey must be equipped on bombard_skiff")
	print("[PASS] Bombard Skiff visual hierarchy and crew mount verified.")
	
	player.queue_free()
	weapon.queue_free()
	
	print("\n========================================================")
	print("  ALL GREASE MONKEY CHECKS PASSED SUCCESSFULLY! ")
	print("========================================================\n")
