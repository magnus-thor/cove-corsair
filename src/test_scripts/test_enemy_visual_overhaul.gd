@tool
# Turn off untyped warnings specifically for test harnesses:
@warning_ignore("untyped_declaration")
@warning_ignore("unsafe_property_access")
@warning_ignore("unsafe_method_access")
@warning_ignore("unsafe_cast")
extends Node3D

func _ready() -> void:
	print("==================================================")
	print("   TESTING ENEMY VISUAL & AMMO OVERHAUL           ")
	print("==================================================")
	
	_test_enemy_cannonball()
	_test_enemy_vessels()
	_test_bombard_reticle()
	
	print("==================================================")
	print("   ALL ENEMY VISUAL OVERHAUL TESTS PASSED         ")
	print("==================================================")
	get_tree().quit(0)

func _test_enemy_cannonball() -> void:
	print("\n--- 1. Testing Enemy Cannonball Visuals ---")
	var ball_scene = load("res://src/gameplay/projectiles/enemy_cannonball.tscn") as PackedScene
	assert(ball_scene != null, "enemy_cannonball.tscn should load")
	
	var ball = ball_scene.instantiate() as EnemyCannonball
	assert(ball != null, "enemy_cannonball should instantiate as EnemyCannonball")
	add_child(ball)
	
	var spr = ball.get_node_or_null("AmmoSprite") as Sprite3D
	assert(spr != null, "AmmoSprite node should exist on enemy_cannonball")
	assert(spr.texture != null, "AmmoSprite should have a valid texture")
	assert("enemy_ammo_flaming_cannonball" in spr.texture.resource_path, "AmmoSprite must use enemy_ammo_flaming_cannonball.png")
	assert(spr.billboard == BaseMaterial3D.BILLBOARD_FIXED_Y or spr.billboard == BaseMaterial3D.BILLBOARD_ENABLED, "AmmoSprite must have billboard enabled")
	
	# Verify 15% asset texture size reduction (from 885x838 to 752x712)
	var tex_size = spr.texture.get_size()
	assert(tex_size.x <= 755.0 and tex_size.y <= 715.0, "enemy_ammo_flaming_cannonball.png asset reduced by 15%% (actual: %s)" % str(tex_size))
	var col = ball.get_node_or_null("CollisionShape3D") as CollisionShape3D
	assert(col != null and col.shape is SphereShape3D, "CollisionShape3D should exist with SphereShape3D")
	var sphere = col.shape as SphereShape3D
	assert(sphere.radius >= 0.35 and sphere.radius <= 0.45, "Collision sphere radius intact (actual: %.3f)" % sphere.radius)
	
	# Verify high projectile velocity (overcoming river scroll)
	assert(ball.speed >= 17.5, "Enemy cannonball speed is rapid >= 17.5 m/s (actual: %f)" % ball.speed)
	
	# Verify placeholder sphere meshes are hidden
	var core = ball.get_node_or_null("FireCore")
	var glow = ball.get_node_or_null("FireGlow")
	assert(core == null or not core.visible, "FireCore primitive sphere mesh should be hidden")
	assert(glow == null or not glow.visible, "FireGlow primitive sphere mesh should be hidden")
	
	# Test aiming directly towards player location
	var mock_player = Node3D.new()
	mock_player.name = "MockPlayer"
	mock_player.add_to_group("player")
	add_child(mock_player)
	mock_player.global_position = Vector3(3.0, 0.0, 20.0)
	
	var aimed_ball = ball_scene.instantiate() as EnemyCannonball
	add_child(aimed_ball)
	aimed_ball.global_position = Vector3(-1.0, 0.4, -5.0)
	aimed_ball.setup() # Auto-aims towards player at spawn location
	
	var expected_dir = (mock_player.global_position - aimed_ball.global_position).normalized()
	assert(aimed_ball.direction.x > 0.0, "Aimed cannonball tracks player in +X")
	assert(aimed_ball.direction.z > 0.0, "Aimed cannonball tracks player downriver in +Z")
	assert(abs(aimed_ball.direction.x - expected_dir.x) < 0.05, "Cannonball direction matches player vector")
	
	# Test physics process movement
	var init_z = aimed_ball.global_position.z
	aimed_ball._physics_process(0.1)
	assert(aimed_ball.global_position.z > init_z + 1.5, "Cannonball moves rapidly downriver toward player")
	print("  [PASS] Enemy Cannonball 15% size reduction, rapid speed & player targeting verified")
	ball.queue_free()
	aimed_ball.queue_free()
	mock_player.queue_free()

func _test_enemy_vessels() -> void:
	print("\n--- 2. Testing Enemy Vessel Sprite Differentiation ---")
	
	# Harvester Mini-Boss
	var harvester_scene = load("res://src/gameplay/enemies/enemy_mini_boss_harvester.tscn") as PackedScene
	assert(harvester_scene != null, "enemy_mini_boss_harvester.tscn should load")
	var harvester = harvester_scene.instantiate()
	var h_spr = harvester.get_node_or_null("Sprite3D") as Sprite3D
	assert(h_spr != null and h_spr.texture != null, "Harvester has Sprite3D with texture")
	assert("enemy_harvester_steamer" in h_spr.texture.resource_path, "Harvester uses enemy_harvester_steamer.png")
	assert(not ("Armored Turtle-Raft" in h_spr.texture.resource_path), "Harvester no longer uses Turtle-Raft")
	print("  [PASS] Harvester Mini-Boss uses dedicated enemy_harvester_steamer.png")
	harvester.queue_free()
	
	# Bombard Mini-Boss
	var bombard_scene = load("res://src/gameplay/enemies/enemy_mini_boss_bombard.tscn") as PackedScene
	assert(bombard_scene != null, "enemy_mini_boss_bombard.tscn should load")
	var bombard = bombard_scene.instantiate()
	var b_spr = bombard.get_node_or_null("Sprite3D") as Sprite3D
	assert(b_spr != null and b_spr.texture != null, "Bombard has Sprite3D with texture")
	assert("enemy_bombard_skiff" in b_spr.texture.resource_path, "Bombard uses enemy_bombard_skiff.png")
	assert(not ("Armored Turtle-Raft" in b_spr.texture.resource_path), "Bombard no longer uses Turtle-Raft")
	print("  [PASS] Bombard Mini-Boss uses dedicated enemy_bombard_skiff.png")
	bombard.queue_free()
	
	# Iron Gunner
	var gunner_scene = load("res://src/gameplay/enemies/enemy_iron_gunner.tscn") as PackedScene
	assert(gunner_scene != null, "enemy_iron_gunner.tscn should load")
	var gunner = gunner_scene.instantiate()
	var g_spr = gunner.get_node_or_null("Sprite3D") as Sprite3D
	assert(g_spr != null and g_spr.texture != null, "Iron Gunner has Sprite3D with texture")
	assert("enemy_iron_gunner" in g_spr.texture.resource_path, "Iron Gunner uses enemy_iron_gunner.png")
	assert(not ("Armored Turtle-Raft" in g_spr.texture.resource_path), "Iron Gunner no longer uses Turtle-Raft")
	print("  [PASS] Iron Gunner uses dedicated enemy_iron_gunner.png")
	gunner.queue_free()
	
	# Elite Ironclad
	var ironclad_data = load("res://src/data/resources/enemy_vessels/enemy_elite_ironclad.tres") as EnemyData
	assert(ironclad_data != null, "enemy_elite_ironclad.tres should load")
	assert("enemy_elite_ironclad" in ironclad_data.sprite_texture.resource_path, "Elite Ironclad data uses enemy_elite_ironclad.png")
	
	var ironclad_scene = load("res://src/gameplay/enemies/enemy_elite_ironclad.tscn") as PackedScene
	var ironclad = ironclad_scene.instantiate()
	var ic_spr = ironclad.get_node_or_null("EnemySprite") as Sprite3D
	assert(ic_spr != null and ic_spr.texture != null, "Elite Ironclad scene has EnemySprite with texture")
	assert("enemy_elite_ironclad" in ic_spr.texture.resource_path, "Elite Ironclad scene uses enemy_elite_ironclad.png")
	print("  [PASS] Elite Ironclad uses dedicated enemy_elite_ironclad.png")
	ironclad.queue_free()
	
	# Turtle Raft (retains original texture)
	var turtle_data = load("res://src/data/resources/enemy_vessels/turtle_raft.tres") as EnemyData
	assert(turtle_data != null, "turtle_raft.tres should load")
	assert("Armored Turtle-Raft" in turtle_data.sprite_texture.resource_path, "Turtle-Raft retains Armored Turtle-Raft.png")
	print("  [PASS] Turtle-Raft uniquely retains authentic Armored Turtle-Raft.png")

func _test_bombard_reticle() -> void:
	print("\n--- 3. Testing Bombard Target Reticle Visuals ---")
	var reticle_tex = load("res://assets/sprites/ui/bombard_target_reticle.png") as Texture2D
	assert(reticle_tex != null, "bombard_target_reticle.png should load successfully")
	print("  [PASS] bombard_target_reticle.png loaded with size %s" % str(reticle_tex.get_size()))
