extends Node3D

func assert_test(condition: bool, message: String) -> void:
	if condition:
		print("  [PASS] %s" % message)
	else:
		push_error("  [FAIL] %s" % message)
		print("  [FAIL] %s" % message)

func _ready() -> void:
	print("\n==========================================================")
	print("  TESTING AUDIO MAPPING, BIOME MUSIC & CAMERA SHAKE")
	print("==========================================================\n")

	_test_audio_manager_sfx_registration()
	_test_music_streams_and_redundant_crossfade_guard()
	_test_level_controller_biome_transitions()
	_test_procedural_camera_shake_matrix()
	_test_weapon_sfx_and_camera_trauma()
	_test_barricade_and_sea_mine_impacts()

	print("\n==========================================================")
	print("  ALL AUDIO & CAMERA SHAKE VERIFICATIONS COMPLETED")
	print("==========================================================\n")
	get_tree().quit()

func _test_audio_manager_sfx_registration() -> void:
	print("--- 1. Audio Asset Mapping (AudioManager.gd) ---")
	assert_test(AudioManager != null, "AudioManager autoload singleton is active")
	
	var expected_sfx = [
		"sfx_mortar_fire",
		"sfx_mortar_impact",
		"sfx_scattershot",
		"sfx_wood_smash",
		"sfx_mine_detonate"
	]
	
	for key in expected_sfx:
		assert_test(AudioManager.sfx_library.has(key), "sfx_library contains key '%s'" % key)
		var streams: Array = AudioManager.sfx_library.get(key, [])
		assert_test(streams.size() > 0, "sfx_library['%s'] loaded %d AudioStreams (>0)" % [key, streams.size()])

func _test_music_streams_and_redundant_crossfade_guard() -> void:
	print("\n--- 2. Music Streams & Redundant Crossfade Guard ---")
	assert_test(AudioManager.music_library.has("music_tropical"), "music_library has 'music_tropical'")
	assert_test(AudioManager.music_library.has("music_bayou"), "music_library has 'music_bayou'")
	assert_test(AudioManager.music_library.has("music_brimstone"), "music_library has 'music_brimstone'")
	
	# Test initial crossfade to tropical
	AudioManager.crossfade_music("music_tropical", 0.1)
	assert_test(AudioManager.current_music_key == "music_tropical", "Current music key set to 'music_tropical'")
	assert_test(AudioManager.current_music_player != null and AudioManager.current_music_player.playing, "Music player is actively playing")
	
	var initial_player = AudioManager.current_music_player
	
	# Test Mandatory Rule 1: Redundant Biome Crossfade Guard
	AudioManager.crossfade_music("music_tropical", 0.1)
	assert_test(AudioManager.current_music_player == initial_player, "Redundant crossfade guard preserved active music player without restarting")
	assert_test(AudioManager.current_music_key == "music_tropical", "Music key remains 'music_tropical'")

func _test_level_controller_biome_transitions() -> void:
	print("\n--- 3. Dynamic Biome Music Transition (Levels 1-45) ---")
	var level_ctrl = LevelController.new()
	add_child(level_ctrl)
	
	# Test Level 1 (Tropical) -> music_tropical
	var l1_res = load("res://src/data/resources/levels/level_01.tres") as LevelData
	if l1_res:
		level_ctrl.load_level_resource(l1_res)
		assert_test(l1_res.biome_name == "tropical", "Level 1 biome is 'tropical'")
		assert_test(AudioManager.current_music_key == "music_tropical", "Level 1 triggered 'music_tropical'")
		
	# Test Level 16 (Bayou) -> music_bayou
	var l16_res = load("res://src/data/resources/levels/level_16.tres") as LevelData
	if l16_res:
		level_ctrl.load_level_resource(l16_res)
		assert_test(l16_res.biome_name == "bayou", "Level 16 biome is 'bayou'")
		assert_test(AudioManager.current_music_key == "music_bayou", "Level 16 crossfaded to 'music_bayou'")
		
	# Test Level 31 (Brimstone) -> music_brimstone
	var l31_res = load("res://src/data/resources/levels/level_31.tres") as LevelData
	if l31_res:
		level_ctrl.load_level_resource(l31_res)
		assert_test(l31_res.biome_name == "brimstone", "Level 31 biome is 'brimstone'")
		assert_test(AudioManager.current_music_key == "music_brimstone", "Level 31 crossfaded to 'music_brimstone'")
		
	level_ctrl.queue_free()

func _test_procedural_camera_shake_matrix() -> void:
	print("\n--- 4. Camera Shake Matrix (game_camera.gd) ---")
	var camera = GameCamera.new()
	add_child(camera)
	camera.set_harbor_mode(false)
	
	assert_test(camera.trauma == 0.0, "Initial trauma is 0.0")
	
	# Test add_trauma
	camera.add_trauma(0.25)
	assert_test(is_equal_approx(camera.trauma, 0.25), "add_trauma(0.25) sets trauma to 0.25")
	
	# Test trauma clamping
	camera.add_trauma(0.9)
	assert_test(is_equal_approx(camera.trauma, 1.0), "Trauma clamped to max 1.0")
	
	# Test process decay
	camera._process(0.2)
	assert_test(camera.trauma < 1.0 and camera.trauma > 0.0, "Trauma decays quadratically/linearly during process (actual: %.2f)" % camera.trauma)
	
	camera.remove_from_group("game_camera")
	camera.queue_free()

func _test_weapon_sfx_and_camera_trauma() -> void:
	print("\n--- 5. Weapon Systems & Mandatory Scattershot Audio Limiting ---")
	for old_cam in get_tree().get_nodes_in_group("game_camera"):
		old_cam.queue_free()
	
	var camera = GameCamera.new()
	add_child(camera)
	camera._ready()
	camera.set_harbor_mode(false)
	
	var weapon_scene = load("res://src/gameplay/player/attached_weapon.tscn") as PackedScene
	var weapon_mount = weapon_scene.instantiate() as AttachedWeapon
	var socket = Node3D.new()
	socket.name = "BowMortarMount"
	socket.add_child(weapon_mount)
	add_child(socket)
	
	var weapon_res = load("res://src/data/resources/user_crew/weapon_bow_mortar.tres") as WeaponData
	weapon_mount.setup_weapon(weapon_res)
	
	var world_node = Node3D.new()
	add_child(world_node)
	
	# Firing BowMortarMount
	camera.trauma = 0.0
	weapon_mount.try_fire(weapon_mount.projectile_scene, world_node)
	assert_test(is_equal_approx(camera.trauma, 0.25), "Mortar launch added 0.25 trauma")
	
	# Mortar AoE explosion
	var spawned_balls = []
	for c in world_node.get_children():
		if c is Cannonball:
			spawned_balls.append(c)
	assert_test(spawned_balls.size() > 0, "Mortar cannonball spawned")
	if spawned_balls.size() > 0:
		var ball: Cannonball = spawned_balls[0]
		assert_test(ball.has_meta("is_mortar") or (ball.weapon_data and "mortar" in ball.weapon_data.weapon_type), "Mortar ball retains mortar identity")
		camera.trauma = 0.0
		ball._apply_splash_damage()
		assert_test(is_equal_approx(camera.trauma, 0.45), "Mortar AoE explosion nearby added 0.45 trauma")
		
	# Test Scattershot (Mandatory Rule 2)
	var scatter_weapon = weapon_scene.instantiate() as AttachedWeapon
	var scatter_res = load("res://src/data/resources/user_crew/weapon_scattershot.tres") as WeaponData
	scatter_weapon.setup_weapon(scatter_res)
	add_child(scatter_weapon)
	
	camera.trauma = 0.0
	scatter_weapon.fire_scattershot(Vector3(0, 0, -1), world_node)
	assert_test(is_equal_approx(camera.trauma, 0.15), "Scattershot volley added 0.15 trauma (lateral jitter)")
	
	socket.queue_free()
	world_node.queue_free()
	scatter_weapon.queue_free()
	camera.remove_from_group("game_camera")
	camera.queue_free()

func _test_barricade_and_sea_mine_impacts() -> void:
	print("\n--- 6. Barricade Ramming & Sea Mine Detonation SFX ---")
	var camera = GameCamera.new()
	add_child(camera)
	camera.set_harbor_mode(false)
	
	var seg_scene = load("res://src/gameplay/obstacles/barricade_segment.tscn") as PackedScene
	var seg = seg_scene.instantiate() as BarricadeSegment
	add_child(seg)
	assert_test(seg.is_in_group("barricade"), "BarricadeSegment added to 'barricade' group")
	
	# Test Barricade destruction
	seg.die()
	assert_test(seg._is_destroyed, "BarricadeSegment marked as destroyed")
	
	# Test Sea Mine detonation
	var mine_scene = load("res://src/gameplay/obstacles/hazard_sea_mine.tscn") as PackedScene
	var mine = mine_scene.instantiate() as HazardSeaMine
	add_child(mine)
	mine.die()
	assert_test(mine._is_destroyed, "Sea Mine marked as destroyed")
	
	camera.queue_free()
