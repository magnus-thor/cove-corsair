class_name BossWarBarge
extends Node3D

enum State { APPROACHING, COMBAT, DYING }

@export var max_hp: int = 220
@export var current_hp: int = 220

@export var approach_speed: float = 12.0
@export var combat_z_offset: float = -18.0
@export var weave_speed: float = 1.3
@export var patrol_width: float = 2.8

# Inspector-exposed Boss Tuning Properties
@export var attack_interval: float = 2.0
@export var spawn_hazard_enabled: bool = true
@export var hazard_telegraph_time: float = 1.8
@export var max_active_adds: int = 2

var combat_time: float = 0.0
var enraged_shoot_timer: float = 0.0
var minion_timer: float = 0.0
var keg_timer: float = 0.0
var mortar_timer: float = 0.0
var is_barrage_active: bool = false

# Prefabs
@export var enemy_cannonball_scene: PackedScene = preload("res://src/gameplay/projectiles/enemy_cannonball.tscn")
@export var powder_keg_scene: PackedScene = preload("res://src/gameplay/obstacles/destructible_barrel.tscn")
@export var sea_mine_scene: PackedScene = preload("res://src/gameplay/obstacles/hazard_sea_mine.tscn")
@export var doubloon_scene: PackedScene = preload("res://src/gameplay/collectibles/collectible_doubloon.tscn")
@export var explosion_scene: PackedScene = preload("res://src/vfx/barrel_explosion.tscn")
@export var enemy_mob_scene: PackedScene = preload("res://src/gameplay/enemies/enemy_mob.tscn")

@onready var left_cannon_node: Node3D = $LeftCannon
@onready var right_cannon_node: Node3D = $RightCannon
@onready var boiler_node: Node3D = $BoilerCore
@onready var boss_sprite: Node3D = get_node_or_null("BossMesh") if get_node_or_null("BossMesh") else get_node_or_null("BossSprite")
@onready var hit_box: Area3D = $HitBox
@onready var bow_foam: GPUParticles3D = get_node_or_null("BowFoamParticles")
@onready var bow_crest: MeshInstance3D = get_node_or_null("BowFoamCrest")

# State variables
var current_state: State = State.APPROACHING
var current_phase: int = 1
var _target_z: float = -18.0
var _weave_time: float = 0.0
var _attack_timer: float = 0.0
var _attack_cooldown: float = 2.0
var _is_left_turn: bool = true
var _flash_tweens: Dictionary = {}
var _is_defeated: bool = false
var _y_base: float = 0.22

# Phase 2 Steam Venting variables
var is_venting_steam: bool = false
var steam_cycle_timer: float = 0.0
var steam_duration: float = 2.5
var steam_cooldown: float = 4.0

# Phase 3 Ram Charge variables
var ram_timer: float = 0.0
var ram_cooldown: float = 6.0
var is_charging: bool = false
var charge_direction: int = 1 # 1 = forward, -1 = retreating
var original_combat_z: float = -18.0
var is_arena_active: bool = false
var _base_mesh_scale: Vector3 = Vector3.ONE

func activate_arena() -> void:
	is_arena_active = true
	print("[BOSS ARENA] Activated Captain Ironjaw: vulnerability enabled | HP: %d/%d" % [current_hp, max_hp])

func _ready() -> void:
	_clean_shadow_nodes(self)
	add_to_group("enemies")
	add_to_group("boss")
	
	if has_node("/root/GameState"):
		var gs: Node = get_node("/root/GameState")
		if "current_level" in gs:
			var lvl: int = int(gs.get("current_level"))
			if lvl <= 5:
				max_hp = 380
			elif lvl <= 10:
				max_hp = 550
			elif lvl <= 20:
				max_hp = 850
			elif lvl <= 35:
				max_hp = 1400
			else:
				max_hp = 2000
	
	current_hp = max_hp
	original_combat_z = combat_z_offset
	
	if boss_sprite:
		boss_sprite.position.y = 0.22
		boss_sprite.scale = Vector3(3.39, 3.39, 3.39)
		boss_sprite.rotation_degrees = Vector3(0.0, 91.0, 0.0)
		if boss_sprite is Sprite3D:
			(boss_sprite as Sprite3D).pixel_size = 0.0021
		_base_mesh_scale = boss_sprite.scale
	
	# Initial UI Trigger — emitted on EventBus (cross-boundary, Rule B)
	EventBus.boss_spawned_event.emit("Captain Ironjaw's War-Barge", max_hp)
	EventBus.boss_health_changed.emit(current_hp, max_hp)

	
	if left_cannon_node: left_cannon_node.position = Vector3(-2.0, 0.5, 0.5)
	if right_cannon_node: right_cannon_node.position = Vector3(2.0, 0.5, 0.5)
	if boiler_node: boiler_node.position = Vector3(0.0, 0.6, 0.0)

	_attack_timer = 0.0
	_attack_cooldown = attack_interval

func _physics_process(delta: float) -> void:
	if _is_defeated or current_state == State.DYING:
		return
		
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var player_z: float = player.global_position.z if player else 0.0
	_target_z = player_z + combat_z_offset
	
	match current_state:
		State.APPROACHING:
			global_position.z = move_toward(global_position.z, _target_z, approach_speed * delta)
			if abs(global_position.z - _target_z) < 0.5:
				current_state = State.COMBAT
				_attack_timer = 0.0
				
		State.COMBAT:
			_process_combat(delta)

func _process_combat(delta: float) -> void:
	combat_time += delta
	
	# Horizontal Patrol Weaving (unless charging)
	if not is_charging:
		global_position.z = lerp(global_position.z, _target_z, 3.0 * delta)
		_weave_time += delta * weave_speed
		global_position.x = sin(_weave_time) * patrol_width
		
		# Bobbing
		if boss_sprite:
			boss_sprite.position.y = _y_base + sin(_weave_time * 2.0) * 0.05
		if bow_crest:
			bow_crest.position.y = 0.04 + sin(_weave_time * 2.5) * 0.015
	else:
		_process_ram_charge(delta)
		
	# Targeted mortar pressure (paused if hazard spawning disabled or already in a barrage)
	if spawn_hazard_enabled and not is_barrage_active:
		mortar_timer += delta
		if mortar_timer >= 10.0:
			mortar_timer = 0.0
			_fire_targeted_mortar()

	# Continuous Minion Add Spawns
	minion_timer += delta
	var spawn_interval: float = 6.5 if current_phase == 1 else (4.5 if current_phase == 2 else 3.5)
	if minion_timer >= spawn_interval:
		minion_timer = 0.0
		_deploy_side_minions()
		
	# Rolling Powder Keg Spawns (paused if hazards disabled or barrage active)
	if spawn_hazard_enabled and not is_barrage_active:
		keg_timer += delta
		if keg_timer >= 7.5:
			keg_timer = 0.0
			_deploy_center_kegs()
		
	if combat_time >= 45.0:
		if boss_sprite and "modulate" in boss_sprite:
			boss_sprite.set("modulate", Color(2.5, 0.4, 0.4, 1.0)) # Tint red for enrage
		_process_enraged_volley(delta)
	else:
		# Phase-Specific Behaviors
		match current_phase:
			1:
				_process_phase_1(delta)
			2:
				_process_phase_2(delta)
			3:
				_process_phase_3(delta)

func _deploy_side_minions() -> void:
	if has_node("/root/GameState") and int(get_node("/root/GameState").get("current_level")) <= 2:
		return
	var existing_enemies := get_tree().get_nodes_in_group("enemies").filter(
		func(e: Node) -> bool: return is_instance_valid(e) and not e.is_in_group("boss") and not e.is_queued_for_deletion()
	)
	if existing_enemies.size() >= max_active_adds:
		return
		
	if current_phase == 1:
		_spawn_pressure_skiff(-0.6, 3.5)
		_spawn_pressure_skiff(0.6, 3.5)
	elif current_phase == 2:
		_spawn_pressure_skiff(-0.7, 4.0)
		_spawn_pressure_skiff(0.0, 3.2)
		_spawn_pressure_skiff(0.7, 4.0)
	else:
		_spawn_pressure_skiff(-0.55, 5.0)
		_spawn_pressure_skiff(0.55, 5.0)

func _spawn_pressure_skiff(x_norm: float, speed_val: float) -> void:
	if enemy_mob_scene:
		var skiff := enemy_mob_scene.instantiate() as EnemyMob
		var skiff_data: Resource = preload("res://src/data/resources/enemy_vessels/raider_skiff.tres")
		var parent: Node = get_tree().get_first_node_in_group("level_controller")
		if not parent:
			parent = get_parent()
		if parent and skiff:
			parent.add_child(skiff)
			skiff.apply_enemy_data(skiff_data)
			skiff.max_hp = 5
			skiff.current_hp = 5
			skiff.forward_speed = speed_val
			var river_width: float = 12.0
			var player := get_tree().get_first_node_in_group("player") as Node3D
			if player and "river_width" in player:
				river_width = float(player.get("river_width"))
			var x_world: float = x_norm * (river_width / 2.0)
			var spawn_x: float = clampf(global_position.x + x_world, -4.2, 4.2)
			skiff.global_position = Vector3(spawn_x, 0.1, global_position.z + 2.5)

func _deploy_center_kegs() -> void:
	if not spawn_hazard_enabled or is_barrage_active:
		return
	_spawn_pressure_keg(-0.18, 5.5)
	_spawn_pressure_keg(0.18, 5.5)

func _spawn_pressure_keg(x_norm: float, speed_val: float) -> void:
	if not spawn_hazard_enabled:
		return
	if powder_keg_scene:
		var keg := powder_keg_scene.instantiate() as DestructibleObstacle
		var parent: Node = get_tree().get_first_node_in_group("level_controller")
		if not parent:
			parent = get_parent()
		if parent and keg:
			parent.add_child(keg)
			var player := get_tree().get_first_node_in_group("player") as Node3D
			var player_z: float = player.global_position.z if player and is_instance_valid(player) else 0.0
			var spawn_x: float = clampf(global_position.x + x_norm * 6.0, -5.0, 5.0)
			# Ensure hazard does not spawn within 15 meters of player vessel
			var spawn_z: float = minf(global_position.z + 3.0, player_z - 15.0)
			keg.global_position = Vector3(spawn_x, 0.05, spawn_z)
			keg.forward_speed = speed_val
			keg.obstacle_type = DestructibleObstacle.ObstacleType.FUSE_BARREL

func _fire_targeted_mortar() -> void:
	var player := get_tree().get_first_node_in_group("player") as PlayerSwerve
	if not player or not is_instance_valid(player):
		return
	is_barrage_active = true
	var target_node: Node3D = player
	if not player.follower_boats.is_empty():
		if randf() < 0.5:
			var active_f: Array = player.follower_boats.filter(func(x: Node3D) -> bool: return is_instance_valid(x))
			if not active_f.is_empty():
				target_node = active_f.pick_random() as Node3D
	var target_pos := target_node.global_position
	var target_x := clampf(target_pos.x, -2.8, 2.8)
	var circle := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 1.8
	disc.bottom_radius = 1.8
	disc.height = 0.01
	circle.mesh = disc
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.1, 0.1, 0.35)
	circle.material_override = mat
	get_tree().current_scene.add_child(circle)
	circle.global_position = Vector3(target_x, 0.02, target_pos.z)
	
	# Minimum 1.6s telegraph duration with clear warning indicator
	var tele_duration := maxf(1.6, hazard_telegraph_time)
	var tween := create_tween()
	var steps := 4
	var step_time := tele_duration / float(steps * 2)
	for i in range(steps):
		tween.tween_property(mat, "albedo_color:a", 0.15, step_time)
		tween.tween_property(mat, "albedo_color:a", 0.70, step_time)
	tween.tween_callback(func() -> void:
		_explode_mortar_at(circle.global_position)
		circle.queue_free()
		is_barrage_active = false
	)

func _explode_mortar_at(pos: Vector3) -> void:
	if explosion_scene:
		var vfx := explosion_scene.instantiate() as Node3D
		get_tree().current_scene.add_child(vfx)
		vfx.global_position = pos
		vfx.scale = Vector3(2.0, 2.0, 2.0)
	AudioManager.play_sfx("barrel_breaks")
	AudioManager.play_sfx("water_splashes", 0.9, 1.1)
	var camera := get_tree().get_first_node_in_group("game_camera") as GameCamera
	if camera and camera.has_method("shake"):
		camera.shake(0.2, 0.2)
	var player := get_tree().get_first_node_in_group("player") as PlayerSwerve
	if player and is_instance_valid(player):
		var targets: Array[Node3D] = [player]
		for f: Node3D in player.follower_boats:
			if is_instance_valid(f):
				targets.append(f)
		for target in targets:
			var dist: float = target.global_position.distance_to(pos)
			if dist <= 2.0:
				if target.has_method("destroy_follower"):
					target.call("destroy_follower")
					player.spawn_floating_text_at_position("-1 FLEET", Color(1.0, 0.1, 0.1))
				else:
					player.damage_fleet(1)

func _process_enraged_volley(delta: float) -> void:
	enraged_shoot_timer += delta
	if enraged_shoot_timer >= 0.75: # Fire shell every 0.75s during enrage
		enraged_shoot_timer = 0.0
		
		var player := get_tree().get_first_node_in_group("player") as PlayerSwerve
		if not player or not is_instance_valid(player):
			return
			
		var target_node: Node3D = player
		if not player.follower_boats.is_empty():
			if randf() < 0.6:
				var active_f: Array = player.follower_boats.filter(func(x: Node3D) -> bool: return is_instance_valid(x))
				if not active_f.is_empty():
					target_node = active_f.pick_random() as Node3D
					
		if target_node and is_instance_valid(target_node):
			_fire_enraged_mortar(target_node.global_position)

func _fire_enraged_mortar(target_pos: Vector3) -> void:
	if not enemy_cannonball_scene:
		return
		
	AudioManager.play_sfx("cannon_shots", 0.8, 1.0, 1.0)
	var ball := enemy_cannonball_scene.instantiate() as EnemyCannonball
	var root: Node = get_tree().current_scene
	if root and ball:
		root.add_child(ball)
		ball.global_position = global_position + Vector3(randf_range(-1.5, 1.5), 1.0, 2.0)
		ball.scale = Vector3(1.8, 1.8, 1.8)
		ball.set_meta("is_fire", true)
		ball.attach_fire_trail()
		ball.speed = 13.0
		
		var dir: Vector3 = (target_pos - ball.global_position).normalized()
		dir.y = 0.0
		if dir.z <= 0.0:
			dir.z = 1.0
		dir = dir.normalized()
		
		ball.setup(dir, null, null)
		ball.direction = dir

func _process_phase_1(delta: float) -> void:
	_attack_timer += delta
	if _attack_timer >= _attack_cooldown:
		_attack_timer = 0.0
		_attack_cooldown = attack_interval
		_fire_cannon_volley()

func _process_phase_2(delta: float) -> void:
	# Handle steam venting cycle
	steam_cycle_timer += delta
	if not is_venting_steam:
		if steam_cycle_timer >= steam_cooldown:
			_start_steam_venting()
	else:
		if steam_cycle_timer >= steam_duration:
			_stop_steam_venting()
			
	# Regular cannon fire
	_attack_timer += delta
	if _attack_timer >= _attack_cooldown:
		_attack_timer = 0.0
		_attack_cooldown = attack_interval * 0.85 # Slightly faster in Phase 2
		_fire_cannon_volley()

func _process_phase_3(delta: float) -> void:
	# Handle aggressive ram charging
	ram_timer += delta
	if not is_charging and ram_timer >= ram_cooldown:
		_start_ram_charge()
		
	# Constant cannon pressure
	_attack_timer += delta
	if _attack_timer >= _attack_cooldown:
		_attack_timer = 0.0
		_attack_cooldown = attack_interval * 0.70 # Maximum aggression in Phase 3
		_fire_double_cannon_volley()

func _process_steam_venting(delta: float) -> void:
	# Keep patrolling during steam venting, but vulnerability is elevated
	_weave_time += delta * (weave_speed * 0.7) # Slower weave while venting
	global_position.x = sin(_weave_time) * (patrol_width * 0.8)
	global_position.z = lerp(global_position.z, _target_z, 2.0 * delta)

func _fire_double_cannon_volley() -> void:
	var shoot_node: Node3D = left_cannon_node if randf() < 0.5 else right_cannon_node
	var spawn_pos := shoot_node.global_position if shoot_node and is_instance_valid(shoot_node) else (global_position + Vector3(0.0, 0.5, 1.5))
	
	if enemy_cannonball_scene:
		AudioManager.play_sfx("cannon_shots", 0.9, 1.1)
		var ball := enemy_cannonball_scene.instantiate() as EnemyCannonball
		var root: Node = get_tree().current_scene
		if root and ball:
			root.add_child(ball)
			ball.global_position = spawn_pos
			ball.rotation = rotation
			
			var player := get_tree().get_first_node_in_group("player") as Node3D
			var fire_dir := Vector3(0, 0, 1)
			if player and is_instance_valid(player):
				var to_player: Vector3 = (player.global_position - ball.global_position)
				to_player.y = 0.0
				if to_player.length_squared() > 0.01:
					fire_dir = to_player.normalized()
					if fire_dir.z < 0.1:
						fire_dir.z = 0.4
						fire_dir = fire_dir.normalized()
			ball.setup(fire_dir, null, null)
			ball.direction = fire_dir
			ball.speed = 18.0

# Actions
func _fire_warning_shot() -> void:
	if _is_defeated or not is_inside_tree():
		return
	var shoot_node: Node3D = left_cannon_node if randf() < 0.5 else right_cannon_node
	var spawn_pos := shoot_node.global_position if shoot_node and is_instance_valid(shoot_node) else (global_position + Vector3(0.0, 0.5, 1.5))
	
	if enemy_cannonball_scene:
		AudioManager.play_sfx("cannon_shots", 0.9, 1.1)
		var ball := enemy_cannonball_scene.instantiate() as EnemyCannonball
		var root: Node = get_tree().current_scene
		if root and ball:
			root.add_child(ball)
			ball.global_position = spawn_pos
			ball.rotation = rotation
			
			var player := get_tree().get_first_node_in_group("player") as Node3D
			var fire_dir := Vector3(0, 0, 1)
			if player and is_instance_valid(player):
				var to_player: Vector3 = (player.global_position - ball.global_position)
				to_player.y = 0.0
				if to_player.length_squared() > 0.01:
					fire_dir = to_player.normalized()
					if fire_dir.z < 0.1:
						fire_dir.z = 0.4
						fire_dir = fire_dir.normalized()
			ball.setup(fire_dir, null, null)
			ball.direction = fire_dir
			ball.speed = 18.0

func _fire_cannon_volley() -> void:
	var shoot_node: Node3D = left_cannon_node if _is_left_turn else right_cannon_node
	_is_left_turn = !(_is_left_turn) # Alternate sides
	
	if shoot_node and is_instance_valid(shoot_node) and enemy_cannonball_scene:
		AudioManager.play_sfx("cannon_shots")
		var ball := enemy_cannonball_scene.instantiate() as EnemyCannonball
		var root: Node = get_tree().current_scene
		if root and ball:
			root.add_child(ball)
			ball.global_position = shoot_node.global_position
			ball.rotation = rotation
			
			var player := get_tree().get_first_node_in_group("player") as Node3D
			var fire_dir := Vector3(0, 0, 1) # Default downriver facing toward player
			if player and is_instance_valid(player):
				var to_player: Vector3 = (player.global_position - ball.global_position)
				to_player.y = 0.0
				if to_player.length_squared() > 0.01:
					fire_dir = to_player.normalized()
					if fire_dir.z < 0.1:
						fire_dir.z = 0.4
						fire_dir = fire_dir.normalized()
			ball.setup(fire_dir, null, null)
			ball.direction = fire_dir
			ball.speed = 18.0

func _drop_keg() -> void:
	if powder_keg_scene:
		var keg := powder_keg_scene.instantiate() as DestructibleObstacle
		var parent: Node = get_parent()
		if parent and keg:
			parent.add_child(keg)
			keg.global_position = Vector3(global_position.x, 0.4, global_position.z + 3.0)
			keg.forward_speed = 5.0
			print("[BOSS SPAWN] Powder Keg launched at %s | Speed: 5.0" % keg.global_position)

func _eject_mine() -> void:
	if not spawn_hazard_enabled or is_barrage_active:
		return
	if sea_mine_scene:
		var mine := sea_mine_scene.instantiate() as Node3D
		var parent: Node = get_parent()
		if parent and mine:
			parent.add_child(mine)
			var player := get_tree().get_first_node_in_group("player") as Node3D
			var player_z: float = player.global_position.z if player and is_instance_valid(player) else 0.0
			var offset_x: float = randf_range(-2.5, 2.5)
			var spawn_x: float = clampf(global_position.x + offset_x, -5.0, 5.0)
			# Ensure at least 15m away from player's vessel
			var spawn_z: float = minf(global_position.z + 3.0, player_z - 15.0)
			mine.global_position = Vector3(spawn_x, 0.3, spawn_z)
			if "forward_speed" in mine:
				mine.set("forward_speed", 4.0)
			print("[BOSS SPAWN] Spiked Sea Mine ejected at %s (safe >=15m) | Speed: 4.0" % mine.global_position)

# Steam Venting
func _start_steam_venting() -> void:
	is_venting_steam = true
	steam_cycle_timer = 0.0
	AudioManager.play_sfx("water_splashes") # Steam venting hiss
	
	# Glow boiler core red
	if is_instance_valid(boiler_node):
		var mesh := boiler_node.get_node_or_null("LogMesh") as MeshInstance3D
		if mesh and is_instance_valid(mesh):
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(2.5, 0.5, 0.1) # Bright glowing orange/red
			mat.emission_enabled = true
			mat.emission = Color(1.5, 0.3, 0.0)
			mesh.material_override = mat

func _stop_steam_venting() -> void:
	is_venting_steam = false
	steam_cycle_timer = 0.0
	
	# Reset boiler color
	if is_instance_valid(boiler_node):
		var mesh := boiler_node.get_node_or_null("LogMesh") as MeshInstance3D
		if mesh and is_instance_valid(mesh):
			mesh.material_override = null

# Ram Charge
func _start_ram_charge() -> void:
	is_charging = true
	charge_direction = 1 # Forward
	ram_timer = 0.0
	AudioManager.play_sfx("cannon_shots") # Warning sound
	
	if is_instance_valid(boss_sprite):
		var cur_tw := _flash_tweens.get(boss_sprite) as Tween
		if cur_tw and cur_tw.is_valid():
			cur_tw.kill()
			boss_sprite.scale = _base_mesh_scale
		var tween := create_tween()
		_flash_tweens[boss_sprite] = tween
		if "modulate" in boss_sprite:
			tween.tween_property(boss_sprite, "modulate", Color(3.0, 0.3, 0.3, 1.0), 0.1)
			tween.tween_property(boss_sprite, "modulate", Color.WHITE, 0.15)
		else:
			tween.tween_property(boss_sprite, "scale", _base_mesh_scale * 1.1, 0.1)
			tween.tween_property(boss_sprite, "scale", _base_mesh_scale, 0.15)

func _process_ram_charge(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var player_z: float = player.global_position.z if player else 0.0
	
	if charge_direction == 1:
		# Surge forward to 9.5m in front of player
		global_position.z = move_toward(global_position.z, player_z - 9.5, 16.0 * delta)
		if global_position.z >= player_z - 9.8:
			charge_direction = -1 # Retreat
			AudioManager.play_sfx("barrel_breaks")
			if player and abs(player.global_position.x - global_position.x) < 2.5:
				var player_swerve := player as PlayerSwerve
				if player_swerve:
					player_swerve.leak_threat(self)
	else:
		# Retreat back to combat offset
		global_position.z = move_toward(global_position.z, _target_z, 10.0 * delta)
		if abs(global_position.z - _target_z) < 0.5:
			is_charging = false
			ram_timer = 0.0

func take_damage(amount: int) -> void:
	if _is_defeated or not is_arena_active:
		return
		
	var actual_damage: int = amount

	if is_venting_steam:
		actual_damage *= 2 # Critical hit during steam venting!
		_show_crit_flash()
		
	current_hp = max(0, current_hp - actual_damage)
	print("[BOSS HIT] Captain Ironjaw's War-Barge took %d damage | HP: %d/%d" % [actual_damage, current_hp, max_hp])
	EventBus.boss_health_changed.emit(current_hp, max_hp)
	_flash_boss_main()
	
	if current_hp <= 0:
		boss_defeat()
	else:
		_check_phase_transition()

func damage_component(_comp_name: String, amount: int, _from_bow: bool) -> void:
	take_damage(amount)

func _flash_boss_main() -> void:
	if not is_instance_valid(boss_sprite):
		return
	var cur_tw := _flash_tweens.get(boss_sprite) as Tween
	if cur_tw and cur_tw.is_valid():
		cur_tw.kill()
		boss_sprite.scale = _base_mesh_scale
		
	var tween := create_tween()
	_flash_tweens[boss_sprite] = tween
	if "modulate" in boss_sprite:
		tween.tween_property(boss_sprite, "modulate", Color(2.5, 0.5, 0.5, 1.0), 0.06)
		tween.tween_property(boss_sprite, "modulate", Color.WHITE, 0.1)
	else:
		tween.tween_property(boss_sprite, "scale", _base_mesh_scale * 1.06, 0.04)
		tween.tween_property(boss_sprite, "scale", _base_mesh_scale, 0.08)

func _show_crit_flash() -> void:
	if not is_instance_valid(boss_sprite):
		return
	var cur_tw := _flash_tweens.get(boss_sprite) as Tween
	if cur_tw and cur_tw.is_valid():
		cur_tw.kill()
		boss_sprite.scale = _base_mesh_scale
	var tween := create_tween()
	_flash_tweens[boss_sprite] = tween
	if "modulate" in boss_sprite:
		tween.tween_property(boss_sprite, "modulate", Color(1.0, 1.0, 3.0, 1.0), 0.05) # Blue flash for crit
		tween.tween_property(boss_sprite, "modulate", Color.WHITE, 0.15)
	else:
		tween.tween_property(boss_sprite, "scale", _base_mesh_scale * 1.12, 0.05)
		tween.tween_property(boss_sprite, "scale", _base_mesh_scale, 0.12)

func _check_phase_transition() -> void:
	if current_phase == 1 and current_hp <= int(max_hp * 0.68):
		_transition_to_phase_2()
	elif current_phase == 2 and current_hp <= int(max_hp * 0.32):
		_transition_to_phase_3()

func _transition_to_phase_2() -> void:
	current_phase = 2
	steam_cycle_timer = 0.0
	_start_steam_venting()
	_deploy_side_minions()

func _transition_to_phase_3() -> void:
	current_phase = 3
	_stop_steam_venting()
	ram_timer = 0.0
	_deploy_side_minions()

func boss_defeat() -> void:
	if _is_defeated:
		return
	_is_defeated = true
	current_state = State.DYING
	
	GameState.targets_destroyed += 1
	
	if is_instance_valid(hit_box):
		hit_box.set_deferred("monitoring", false)
		hit_box.set_deferred("monitorable", false)
	
	if is_instance_valid(bow_foam):
		bow_foam.emitting = false
	if is_instance_valid(bow_crest):
		bow_crest.visible = false
	
	# Explode dramatically
	var tween := create_tween()
	for i in range(15):
		tween.tween_callback(func() -> void:
			_spawn_hull_explosion()
			AudioManager.play_sfx("barrel_breaks", 0.6, 1.3, 2.0)
			if randf() < 0.3:
				AudioManager.play_sfx("gate_passes", 0.8, 1.2, 0.0)
		)
		tween.tween_interval(0.12)
		
	# Play celebratory fanfare and stop combat music
	tween.tween_callback(func() -> void:
		AudioManager.stop_music()
		AudioManager.play_sfx("gate_passes", 0.7, 0.9, 3.0)
		AudioManager.play_sfx("coin_pickups", 0.9, 1.1, 4.0)
		_spawn_doubloon_fountain()
	)
	tween.tween_interval(1.8)
	tween.tween_callback(func() -> void:
		GameState.is_game_active = false
		EventBus.level_completed.emit(GameState.doubloons, GameState.targets_destroyed)
		queue_free()
	)

func _spawn_hull_explosion() -> void:
	if explosion_scene:
		var vfx := explosion_scene.instantiate() as Node3D
		var root: Node = get_tree().current_scene
		if root and vfx:
			root.add_child(vfx)
			var offset := Vector3(randf_range(-3.0, 3.0), randf_range(0.2, 1.5), randf_range(-2.0, 2.0))
			vfx.global_position = global_position + offset
			vfx.scale = Vector3.ONE * randf_range(1.5, 3.0)

func _spawn_doubloon_fountain() -> void:
	var cur_lvl: int = 1
	if has_node("/root/GameState"):
		var gs: Node = get_node("/root/GameState")
		if "current_level" in gs:
			cur_lvl = int(gs.get("current_level"))
			
	var vfx_mgr: Node = get_tree().get_first_node_in_group("vfx_manager")
	if vfx_mgr and vfx_mgr.has_method("spawn_coin_burst"):
		vfx_mgr.call("spawn_coin_burst", global_position)
	elif VFXManager and VFXManager.has_method("spawn_coin_burst"):
		VFXManager.spawn_coin_burst(global_position)
		
	if not doubloon_scene:
		return
	var count: int = 0 if cur_lvl <= 1 else (5 if cur_lvl == 2 else (15 if cur_lvl <= 5 else 30))
	for i in range(count):
		var d := doubloon_scene.instantiate() as CollectibleDoubloon
		if d:
			get_tree().current_scene.add_child(d)
			d.global_position = Vector3(global_position.x, 0.1, global_position.z)
			var scatter := Vector2(randf_range(-3.5, 3.5), randf_range(-3.5, 3.5))
			d._trigger_spawn_bounce(scatter)

func _clean_shadow_nodes(node: Node) -> void:
	if not node:
		return
	var lower_name: String = str(node.name).to_lower()
	var is_shadow_node := false
	if "shadow" in lower_name or "decal" in lower_name or "projector" in lower_name or "card" in lower_name or "oblate" in lower_name or "shadow_sphere" in lower_name or "sphere_shadow" in lower_name:
		is_shadow_node = true
		
	if is_shadow_node:
		if node is Sprite3D or node is MeshInstance3D or node is Decal or node.get_class() == "Decal3D":
			node.queue_free()
			return
			
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		if "shadow" in lower_name or "plane" in lower_name or "billboard" in lower_name or "card" in lower_name:
			mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mesh_node.visible = false
			mesh_node.queue_free()
			return
			
	for child: Node in node.get_children():
		_clean_shadow_nodes(child)
