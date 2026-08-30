class_name BossWarBarge
extends Node3D

enum State { APPROACHING, COMBAT, DYING }

@export var max_hp: int = 120 # 80 Boiler + 20 Left Armor + 20 Right Armor
@export var current_hp: int = 120

@export var approach_speed: float = 12.0
@export var combat_z_offset: float = -18.0
@export var weave_speed: float = 1.2
@export var patrol_width: float = 3.2

# Component HP
var hp_left_cannon: int = 5
var hp_right_cannon: int = 5
var hp_left_armor: int = 20
var hp_right_armor: int = 20
var hp_boiler: int = 80
var combat_time: float = 0.0
var enraged_shoot_timer: float = 0.0
var minion_timer: float = 0.0
var keg_timer: float = 0.0
var mortar_timer: float = 0.0

# Prefabs
@export var enemy_cannonball_scene: PackedScene = preload("res://src/gameplay/projectiles/enemy_cannonball.tscn")
@export var powder_keg_scene: PackedScene = preload("res://src/gameplay/obstacles/destructible_barrel.tscn")
@export var sea_mine_scene: PackedScene = preload("res://src/gameplay/obstacles/hazard_sea_mine.tscn")
@export var doubloon_scene: PackedScene = preload("res://src/gameplay/collectibles/collectible_doubloon.tscn")
@export var explosion_scene: PackedScene = preload("res://src/gameplay/vfx/barrel_explosion.tscn")
@export var enemy_mob_scene: PackedScene = preload("res://src/gameplay/enemies/enemy_mob.tscn")

@onready var left_cannon_node: Node3D = $LeftCannon
@onready var right_cannon_node: Node3D = $RightCannon
@onready var left_armor_node: Node3D = $LeftArmor
@onready var right_armor_node: Node3D = $RightArmor
@onready var boiler_node: Node3D = $BoilerCore
@onready var boss_sprite: Sprite3D = $BossSprite

# State variables
var current_state: State = State.APPROACHING
var current_phase: int = 1
var _target_z: float = -18.0
var _weave_time: float = 0.0
var _attack_timer: float = 0.0
var _is_left_turn: bool = true
var _flash_tweens: Dictionary = {}
var _is_defeated: bool = false
var _y_base: float = 0.8

# Phase 2 Steam Venting variables
var is_venting_steam: bool = false
var steam_cycle_timer: float = 0.0
var steam_duration: float = 2.5
var steam_cooldown: float = 4.0

# Phase 3 Ram Charge variables
var ram_timer: float = 0.0
var is_charging: bool = false
var charge_direction: int = 1 # 1 = forward, -1 = retreating
var original_combat_z: float = -18.0

func _ready() -> void:
	_clean_shadow_nodes(self)
	add_to_group("enemies")
	add_to_group("boss")
	
	current_hp = max_hp
	original_combat_z = combat_z_offset
	
	# Initial UI Trigger
	GameState.boss_spawned_event.emit("Captain Ironjaw's War-Barge", max_hp)
	GameState.boss_health_changed.emit(current_hp, max_hp)
	
	# Position cannons relative to ship
	if left_cannon_node: left_cannon_node.position = Vector3(-1.8, 0.4, 0.5)
	if right_cannon_node: right_cannon_node.position = Vector3(1.8, 0.4, 0.5)
	if left_armor_node: left_armor_node.position = Vector3(-0.9, 0.3, -0.6)
	if right_armor_node: right_armor_node.position = Vector3(0.9, 0.3, -0.6)
	if boiler_node: boiler_node.position = Vector3(0.0, 0.5, -0.2)

func _physics_process(delta: float) -> void:
	if _is_defeated or current_state == State.DYING:
		return
		
	var player = get_tree().get_first_node_in_group("player")
	var player_z = player.global_position.z if player else 0.0
	_target_z = player_z + combat_z_offset
	
	match current_state:
		State.APPROACHING:
			global_position.z = move_toward(global_position.z, _target_z, approach_speed * delta)
			if abs(global_position.z - _target_z) < 0.5:
				current_state = State.COMBAT
				_attack_timer = 0.5
				
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
	else:
		_process_ram_charge(delta)
		
	# Continuous Mob & Hazard pressure
	minion_timer += delta
	if minion_timer >= 3.0:
		minion_timer = 0.0
		_deploy_side_minions()
		
	keg_timer += delta
	if keg_timer >= 4.5:
		keg_timer = 0.0
		_deploy_center_kegs()
		
	mortar_timer += delta
	if mortar_timer >= 6.0:
		mortar_timer = 0.0
		_fire_targeted_mortar()
		
	if combat_time >= 12.0:
		if boss_sprite:
			boss_sprite.modulate = Color(2.5, 0.4, 0.4, 1.0) # Tint red for enrage
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
	_spawn_pressure_skiff(-0.7, 5.0)
	_spawn_pressure_skiff(0.7, 5.0)

func _spawn_pressure_skiff(x_norm: float, speed_val: float) -> void:
	if enemy_mob_scene:
		var skiff = enemy_mob_scene.instantiate() as Area3D
		var skiff_data = preload("res://src/data/resources/raider_skiff.tres")
		var parent = get_tree().get_first_node_in_group("level_controller")
		if not parent:
			parent = get_parent()
		if parent:
			parent.add_child(skiff)
			if skiff.has_method("apply_enemy_data"):
				skiff.apply_enemy_data(skiff_data)
			skiff.max_hp = 3
			skiff.current_hp = 3
			skiff.forward_speed = speed_val
			var river_width = 12.0
			var player = get_tree().get_first_node_in_group("player")
			if player and "river_width" in player:
				river_width = player.river_width
			var x_world = x_norm * (river_width / 2.0)
			skiff.global_position = Vector3(x_world, 0.1, global_position.z + 2.0)

func _deploy_center_kegs() -> void:
	_spawn_pressure_keg(-0.15, 6.0)
	_spawn_pressure_keg(0.15, 6.0)

func _spawn_pressure_keg(x_norm: float, speed_val: float) -> void:
	if powder_keg_scene:
		var keg = powder_keg_scene.instantiate() as Node3D
		var parent = get_tree().get_first_node_in_group("level_controller")
		if not parent:
			parent = get_parent()
		if parent:
			parent.add_child(keg)
			keg.global_position = Vector3(x_norm * 6.0, 0.05, global_position.z + 3.0)
			if "forward_speed" in keg:
				keg.forward_speed = speed_val
			if "obstacle_type" in keg:
				keg.obstacle_type = DestructibleObstacle.ObstacleType.FUSE_BARREL

func _fire_targeted_mortar() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player or not is_instance_valid(player):
		return
	var target_node: Node3D = player
	if "follower_boats" in player and not player.follower_boats.is_empty():
		if randf() < 0.5:
			var active_f = player.follower_boats.filter(func(x): return is_instance_valid(x))
			if not active_f.is_empty():
				target_node = active_f.pick_random()
	var target_pos = target_node.global_position
	var circle = MeshInstance3D.new()
	var disc = CylinderMesh.new()
	disc.top_radius = 2.0
	disc.bottom_radius = 2.0
	disc.height = 0.01
	circle.mesh = disc
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.1, 0.1, 0.35)
	circle.material_override = mat
	get_tree().current_scene.add_child(circle)
	circle.global_position = Vector3(target_pos.x, 0.02, target_pos.z)
	var tween = create_tween()
	for i in range(3):
		tween.tween_property(mat, "albedo_color:a", 0.1, 0.25)
		tween.tween_property(mat, "albedo_color:a", 0.5, 0.25)
	tween.tween_callback(func():
		_explode_mortar_at(circle.global_position)
		circle.queue_free()
	)

func _explode_mortar_at(pos: Vector3) -> void:
	if explosion_scene:
		var vfx = explosion_scene.instantiate() as Node3D
		get_tree().current_scene.add_child(vfx)
		vfx.global_position = pos
		vfx.scale = Vector3(2.0, 2.0, 2.0)
	AudioManager.play_sfx("barrel_breaks")
	AudioManager.play_sfx("water_splashes", 0.9, 1.1)
	var camera = get_tree().get_first_node_in_group("game_camera")
	if camera and camera.has_method("shake"):
		camera.shake(0.2, 0.2)
	var player = get_tree().get_first_node_in_group("player")
	if player and is_instance_valid(player):
		var targets: Array[Node3D] = [player]
		if "follower_boats" in player:
			for f in player.follower_boats:
				if is_instance_valid(f):
					targets.append(f)
		for target in targets:
			var dist = target.global_position.distance_to(pos)
			if dist <= 2.0:
				if target.has_method("destroy_follower"):
					target.destroy_follower()
					if player.has_method("spawn_floating_text_at_position"):
						player.spawn_floating_text_at_position("-1 FLEET", Color(1.0, 0.1, 0.1))
				elif player.has_method("damage_fleet"):
					player.damage_fleet(1)

func _process_enraged_volley(delta: float) -> void:
	enraged_shoot_timer += delta
	if enraged_shoot_timer >= 0.2: # Fire mortar shell every 0.2s
		enraged_shoot_timer = 0.0
		
		var player = get_tree().get_first_node_in_group("player")
		if not player or not is_instance_valid(player):
			return
			
		var target_node = player
		if "follower_boats" in player and not player.follower_boats.is_empty():
			if randf() < 0.6:
				var active_f = player.follower_boats.filter(func(x): return is_instance_valid(x))
				if not active_f.is_empty():
					target_node = active_f.pick_random()
					
		if target_node and is_instance_valid(target_node):
			_fire_enraged_mortar(target_node.global_position)

func _fire_enraged_mortar(target_pos: Vector3) -> void:
	if not enemy_cannonball_scene:
		return
		
	AudioManager.play_sfx("cannon_shots", 0.8, 1.0, 1.0)
	var ball = enemy_cannonball_scene.instantiate() as Area3D
	var root = get_tree().current_scene
	if root:
		root.add_child(ball)
		
	ball.global_position = global_position + Vector3(randf_range(-1.5, 1.5), 1.0, 2.0)
	ball.scale = Vector3(2.5, 2.5, 2.5) # Heavy enrage scale
	if "speed" in ball:
		ball.speed = 32.0
	
	var dir = (target_pos - ball.global_position).normalized()
	dir.y = 0.0
	dir = dir.normalized()
	
	if "direction" in ball:
		ball.direction = dir

func _process_phase_1(delta: float) -> void:
	_attack_timer += delta
	if _attack_timer >= 0.9:
		_attack_timer = 0.0
		_fire_cannon_volley()
		
	# Occasionally drop a keg
	if randf() < 0.003:
		_drop_keg()

func _process_phase_2(delta: float) -> void:
	# Handle steam venting cycle
	steam_cycle_timer += delta
	if not is_venting_steam:
		if steam_cycle_timer >= steam_cooldown:
			_start_steam_venting()
	else:
		if steam_cycle_timer >= steam_duration:
			_stop_steam_venting()
			
	# Cannon fires slower in Phase 2
	_attack_timer += delta
	if _attack_timer >= 1.3:
		_attack_timer = 0.0
		_fire_cannon_volley()

func _process_phase_3(delta: float) -> void:
	# Charge Timer
	ram_timer += delta
	if ram_timer >= 5.0 and not is_charging:
		_start_ram_charge()
		
	# Eject Mines while patrolling/moving
	if not is_charging and randf() < 0.025:
		_eject_mine()

# Actions
func _fire_cannon_volley() -> void:
	var shoot_node: Node3D = null
	if _is_left_turn and hp_left_cannon > 0:
		shoot_node = left_cannon_node
		_is_left_turn = false
	elif not _is_left_turn and hp_right_cannon > 0:
		shoot_node = right_cannon_node
		_is_left_turn = true
	else:
		# Fallback to whatever is alive
		if hp_left_cannon > 0:
			shoot_node = left_cannon_node
		elif hp_right_cannon > 0:
			shoot_node = right_cannon_node
			
	_is_left_turn = !(_is_left_turn) # Alternate anyway
	
	if shoot_node and is_instance_valid(shoot_node) and enemy_cannonball_scene:
		AudioManager.play_sfx("cannon_shots")
		var ball = enemy_cannonball_scene.instantiate() as Area3D
		var root = get_tree().current_scene
		if root:
			root.add_child(ball)
		ball.global_position = shoot_node.global_position
		ball.rotation = rotation

func _drop_keg() -> void:
	if powder_keg_scene:
		var keg = powder_keg_scene.instantiate() as Node3D
		var parent = get_parent()
		if parent:
			parent.add_child(keg)
			keg.global_position = Vector3(global_position.x, 0.4, global_position.z + 3.0)
			if "forward_speed" in keg:
				keg.forward_speed = 8.0

func _eject_mine() -> void:
	if sea_mine_scene:
		var mine = sea_mine_scene.instantiate() as Node3D
		var parent = get_parent()
		if parent:
			parent.add_child(mine)
			# Drop on left, center or right randomly
			var offset_x = randf_range(-2.5, 2.5)
			mine.global_position = Vector3(global_position.x + offset_x, 0.3, global_position.z + 3.0)

# Steam Venting
func _start_steam_venting() -> void:
	is_venting_steam = true
	steam_cycle_timer = 0.0
	AudioManager.play_sfx("water_splashes") # Steam venting hiss
	
	# Glow boiler core red
	var mesh = boiler_node.get_node_or_null("LogMesh") as MeshInstance3D # Reuse log mesh shape or visual representation
	if mesh:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(2.5, 0.5, 0.1) # Bright glowing orange/red
		mat.emission_enabled = true
		mat.emission = Color(1.5, 0.3, 0.0)
		mesh.material_override = mat

func _stop_steam_venting() -> void:
	is_venting_steam = false
	steam_cycle_timer = 0.0
	
	# Reset boiler color
	var mesh = boiler_node.get_node_or_null("LogMesh") as MeshInstance3D
	if mesh:
		mesh.material_override = null

# Ram Charge
func _start_ram_charge() -> void:
	is_charging = true
	charge_direction = 1 # Forward
	ram_timer = 0.0
	AudioManager.play_sfx("cannon_shots") # Warning sound
	
	# Flash red indicators
	if boss_sprite:
		var tween = create_tween()
		tween.tween_property(boss_sprite, "modulate", Color(4.0, 0.2, 0.2, 1.0), 0.15)
		tween.tween_property(boss_sprite, "modulate", Color.WHITE, 0.15)
		tween.tween_property(boss_sprite, "modulate", Color(4.0, 0.2, 0.2, 1.0), 0.15)
		tween.tween_property(boss_sprite, "modulate", Color.WHITE, 0.15)

func _process_ram_charge(delta: float) -> void:
	var player = get_tree().get_first_node_in_group("player")
	var player_z = player.global_position.z if player else 0.0
	
	if charge_direction == 1:
		# Move forward rapidly
		global_position.z = move_toward(global_position.z, player_z - 3.5, 20.0 * delta)
		
		# Check player hit
		if abs(global_position.z - (player_z - 3.5)) < 0.6:
			# Hit! Damage player
			if player and "current_health" in player:
				player.current_health -= 1
				player.health_changed.emit(player.current_health, player.max_health)
				if player.current_health <= 0 and player.has_method("game_over"):
					player.game_over(false)
				AudioManager.play_sfx("barrel_breaks")
			charge_direction = -1 # Retreat
	else:
		# Retreating back
		global_position.z = move_toward(global_position.z, _target_z, 8.0 * delta)
		if abs(global_position.z - _target_z) < 0.5:
			is_charging = false
			ram_timer = 0.0

# Damage routing
func damage_component(comp_name: String, amount: int, from_bow: bool) -> void:
	if _is_defeated:
		return
		
	match comp_name:
		"left_cannon":
			if hp_left_cannon > 0:
				hp_left_cannon = max(0, hp_left_cannon - amount)
				_flash_node(left_cannon_node)
				if hp_left_cannon <= 0:
					_destroy_subcomponent(left_cannon_node)
					
		"right_cannon":
			if hp_right_cannon > 0:
				hp_right_cannon = max(0, hp_right_cannon - amount)
				_flash_node(right_cannon_node)
				if hp_right_cannon <= 0:
					_destroy_subcomponent(right_cannon_node)
					
		"left_armor":
			if hp_left_armor > 0:
				hp_left_armor = max(0, hp_left_armor - amount)
				_flash_node(left_armor_node)
				current_hp = max(0, current_hp - amount)
				GameState.boss_health_changed.emit(current_hp, max_hp)
				if hp_left_armor <= 0:
					_destroy_subcomponent(left_armor_node)
					_check_phase_transition()
				_flash_boss_main()
					
		"right_armor":
			if hp_right_armor > 0:
				hp_right_armor = max(0, hp_right_armor - amount)
				_flash_node(right_armor_node)
				current_hp = max(0, current_hp - amount)
				GameState.boss_health_changed.emit(current_hp, max_hp)
				if hp_right_armor <= 0:
					_destroy_subcomponent(right_armor_node)
					_check_phase_transition()
				_flash_boss_main()
					
		"boiler_core":
			# Only takes damage if both armors are destroyed
			if hp_left_armor <= 0 and hp_right_armor <= 0:
				var actual_damage = amount
				if is_venting_steam and from_bow:
					actual_damage *= 2 # Crit!
					_show_crit_flash()
					
				hp_boiler = max(0, hp_boiler - actual_damage)
				current_hp = max(0, current_hp - actual_damage)
				GameState.boss_health_changed.emit(current_hp, max_hp)
				_flash_node(boiler_node)
				_flash_boss_main()
				
				if hp_boiler <= 0 or current_hp <= 0:
					boss_defeat()
				else:
					_check_phase_transition()
			else:
				# Invulnerable! Clanking deflect sound
				AudioManager.play_sfx("barrel_hits")

func _flash_node(node: Node3D) -> void:
	if not node: return
	if _flash_tweens.has(node) and _flash_tweens[node].is_valid():
		_flash_tweens[node].kill()
		
	var tween = create_tween()
	_flash_tweens[node] = tween
	
	# Scale punch
	tween.tween_property(node, "scale", node.scale * 1.25, 0.05)
	tween.tween_property(node, "scale", node.scale, 0.08)

func _flash_boss_main() -> void:
	if not boss_sprite: return
	if _flash_tweens.has(boss_sprite) and _flash_tweens[boss_sprite].is_valid():
		_flash_tweens[boss_sprite].kill()
		
	var tween = create_tween()
	_flash_tweens[boss_sprite] = tween
	tween.tween_property(boss_sprite, "modulate", Color(2.5, 0.5, 0.5, 1.0), 0.06)
	tween.tween_property(boss_sprite, "modulate", Color.WHITE, 0.1)

func _show_crit_flash() -> void:
	if not boss_sprite: return
	var tween = create_tween()
	tween.tween_property(boss_sprite, "modulate", Color(1.0, 1.0, 3.0, 1.0), 0.05) # Blue flash for crit
	tween.tween_property(boss_sprite, "modulate", Color.WHITE, 0.15)

func _destroy_subcomponent(node: Node3D) -> void:
	if not node: return
	AudioManager.play_sfx("barrel_breaks")
	if explosion_scene:
		var vfx = explosion_scene.instantiate() as Node3D
		var parent = get_parent() if get_parent() else get_tree().current_scene
		if parent:
			parent.add_child(vfx)
			vfx.global_position = node.global_position
	node.visible = false
	# Disable collisions on the sub-component
	if node is Area3D:
		node.set_deferred("monitoring", false)
		node.set_deferred("monitorable", false)
		for col in node.get_children():
			if col is CollisionShape3D:
				col.set_deferred("disabled", true)

func _check_phase_transition() -> void:
	var hp_ratio = float(current_hp) / float(max_hp)
	if current_phase == 1 and current_hp <= 39: # <65%
		_transition_to_phase_2()
	elif current_phase == 2 and current_hp <= 18: # <30%
		_transition_to_phase_3()

func _transition_to_phase_2() -> void:
	current_phase = 2
	steam_cycle_timer = 0.0
	_start_steam_venting()
	
	# Spawn 2 minion skiffs
	_spawn_minion_skiff(-0.25)
	_spawn_minion_skiff(0.25)

func _transition_to_phase_3() -> void:
	current_phase = 3
	_stop_steam_venting()
	ram_timer = 0.0

func _spawn_minion_skiff(x_norm: float) -> void:
	if enemy_mob_scene:
		var skiff = enemy_mob_scene.instantiate() as Area3D
		var skiff_data = preload("res://src/data/resources/raider_skiff.tres")
		
		# Add to level controller container if it exists so it scrolls down
		var parent = get_tree().get_first_node_in_group("level_controller")
		if not parent:
			parent = get_parent()
			
		if parent:
			parent.add_child(skiff)
			if skiff.has_method("apply_enemy_data"):
				skiff.apply_enemy_data(skiff_data)
			
			var river_width = 12.0
			var player = get_tree().get_first_node_in_group("player")
			if player and "river_width" in player:
				river_width = player.river_width
				
			var x_world = x_norm * (river_width / 2.0)
			skiff.global_position = Vector3(global_position.x + x_world, 0.1, global_position.z + 4.0)

func boss_defeat() -> void:
	if _is_defeated:
		return
	_is_defeated = true
	current_state = State.DYING
	
	GameState.targets_destroyed += 1
	
	# Deactivate remaining components
	left_cannon_node.visible = false
	right_cannon_node.visible = false
	left_armor_node.visible = false
	right_armor_node.visible = false
	boiler_node.visible = false
	
	# Explode dramatically
	var tween = create_tween()
	for i in range(15):
		tween.tween_callback(func():
			_spawn_hull_explosion()
			AudioManager.play_sfx("barrel_breaks", 0.6, 1.3, 2.0)
			if randf() < 0.3:
				AudioManager.play_sfx("gate_passes", 0.8, 1.2, 0.0)
		)
		tween.tween_interval(0.12)
		
	# Play celebratory fanfare and stop combat music
	tween.tween_callback(func():
		AudioManager.stop_music()
		AudioManager.play_sfx("gate_passes", 0.7, 0.9, 3.0)
		AudioManager.play_sfx("coin_pickups", 0.9, 1.1, 4.0)
		_spawn_doubloon_fountain()
	)
	tween.tween_interval(1.8)
	tween.tween_callback(func():
		GameState.is_game_active = false
		GameState.level_completed.emit(GameState.doubloons, GameState.targets_destroyed)
		queue_free()
	)

func _spawn_hull_explosion() -> void:
	if explosion_scene:
		var vfx = explosion_scene.instantiate() as Node3D
		get_tree().current_scene.add_child(vfx)
		var offset = Vector3(randf_range(-3.0, 3.0), randf_range(0.2, 1.5), randf_range(-2.0, 2.0))
		vfx.global_position = global_position + offset
		vfx.scale = Vector3.ONE * randf_range(1.5, 3.0)

func _spawn_doubloon_fountain() -> void:
	if not doubloon_scene:
		return
	var count = 150
	for i in range(count):
		var d = doubloon_scene.instantiate() as Area3D
		if d:
			get_tree().current_scene.add_child(d)
			d.global_position = Vector3(global_position.x, 0.1, global_position.z)
			var scatter = Vector2(randf_range(-3.5, 3.5), randf_range(-3.5, 3.5))
			if d.has_method("_trigger_spawn_bounce"):
				d._trigger_spawn_bounce(scatter)

func _clean_shadow_nodes(node: Node) -> void:
	if not node:
		return
	var lower_name = node.name.to_lower()
	var is_shadow_node = false
	if "shadow" in lower_name or "decal" in lower_name or "projector" in lower_name or "card" in lower_name or "oblate" in lower_name or "sphere" in lower_name:
		is_shadow_node = true
		
	if is_shadow_node:
		if node is Sprite3D or node is MeshInstance3D or node is Decal or node.get_class() == "Decal3D":
			node.queue_free()
			return
			
	if node is MeshInstance3D:
		if "shadow" in lower_name or "plane" in lower_name or "billboard" in lower_name or "card" in lower_name:
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			node.visible = false
			node.queue_free()
			return
			
	for child in node.get_children():
		_clean_shadow_nodes(child)
