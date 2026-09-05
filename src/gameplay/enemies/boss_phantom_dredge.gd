class_name BossPhantomDredge
extends Node3D

enum State { APPROACHING, COMBAT, SUBMERGED, DYING }

@export var max_hp: int = 450
@export var current_hp: int = 450

@export var approach_speed: float = 12.0
@export var combat_z_offset: float = -18.0
@export var weave_speed: float = 1.3
@export var patrol_width: float = 3.0

# Phase thresholds
var current_phase: int = 1
var combat_time: float = 0.0
var _target_z: float = -18.0
var _weave_time: float = 0.0
var _attack_timer: float = 0.0
var _submerge_timer: float = 0.0
var _submerge_duration: float = 3.2
var _minion_timer: float = 0.0
var _mortar_timer: float = 0.0
var _is_defeated: bool = false
var current_state: State = State.APPROACHING
var _base_y: float = 1.33
var _flash_tween: Tween

# Prefabs
@export var enemy_cannonball_scene: PackedScene = preload("res://src/gameplay/projectiles/enemy_cannonball.tscn")
@export var grave_skiff_scene: PackedScene = preload("res://src/gameplay/enemies/enemy_grave_skiff.tscn")
@export var tide_cutter_scene: PackedScene = preload("res://src/gameplay/enemies/enemy_tide_cutter.tscn")
@export var biogas_pod_scene: PackedScene = preload("res://src/gameplay/obstacles/hazard_biogas_pod.tscn")
@export var doubloon_scene: PackedScene = preload("res://src/gameplay/collectibles/collectible_doubloon.tscn")
@export var explosion_scene: PackedScene = preload("res://src/gameplay/vfx/barrel_explosion.tscn")

@onready var visual_container: Node3D = get_node_or_null("VisualContainer") if get_node_or_null("VisualContainer") else get_node_or_null("BossSprite")
@onready var hit_box: Area3D = $HitBox

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("boss")
	current_hp = max_hp
	_base_y = 0.0
	if visual_container:
		visual_container.position.y = _base_y
	
	GameState.boss_spawned_event.emit("The Phantom Dredge", max_hp)
	GameState.boss_health_changed.emit(current_hp, max_hp)

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
			
		State.SUBMERGED:
			_process_submerged(delta)

func _process_combat(delta: float) -> void:
	combat_time += delta
	
	# Horizontal patrol weave
	global_position.z = lerp(global_position.z, _target_z, 3.0 * delta)
	_weave_time += delta * weave_speed
	global_position.x = sin(_weave_time) * patrol_width
	
	# Bobbing
	if visual_container:
		visual_container.position.y = _base_y + sin(_weave_time * 2.5) * 0.08
		
	# Poison Mortar
	_mortar_timer += delta
	var mortar_cooldown = 3.5 if current_phase == 1 else (2.5 if current_phase == 2 else 1.6)
	if _mortar_timer >= mortar_cooldown:
		_mortar_timer = 0.0
		_fire_poison_mortars()
		
	# Submerge cycle in Phase 2 & 3
	if current_phase >= 2:
		_submerge_timer += delta
		var submerge_cd = 9.0 if current_phase == 2 else 6.5
		if _submerge_timer >= submerge_cd:
			_submerge_timer = 0.0
			_start_submerge()
			return
			
	# Minion Skiff Spawns
	_minion_timer += delta
	var minion_cd = 3.8 if current_phase == 1 else (2.8 if current_phase == 2 else 2.0)
	if _minion_timer >= minion_cd:
		_minion_timer = 0.0
		_spawn_bayou_adds()

func _fire_poison_mortars() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player or not is_instance_valid(player):
		return
		
	var count = 2 if current_phase == 1 else 3
	for i in range(count):
		get_tree().create_timer(i * 0.25).timeout.connect(func():
			if _is_defeated or not is_instance_valid(self):
				return
			var spread_x = randf_range(-3.0, 3.0)
			var target_pos = player.global_position + Vector3(spread_x, 0, randf_range(-2.0, 2.0))
			_telegraph_and_strike_mortar(target_pos)
		)

func _telegraph_and_strike_mortar(pos: Vector3) -> void:
	var marker = MeshInstance3D.new()
	var disc = CylinderMesh.new()
	disc.top_radius = 1.6
	disc.bottom_radius = 1.6
	disc.height = 0.02
	marker.mesh = disc
	
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.1, 0.9, 0.3, 0.35)
	marker.material_override = mat
	get_tree().current_scene.add_child(marker)
	marker.global_position = Vector3(pos.x, 0.03, pos.z)
	
	AudioManager.play_sfx("cannon_shots", 0.8, 1.0)
	
	var tween = marker.create_tween()
	var vfx_scene = explosion_scene
	var tree = get_tree()
	tween.tween_property(mat, "albedo_color:a", 0.8, 1.1)
	tween.tween_callback(Callable(BossPhantomDredge, "execute_poison_mortar_detonation").bind(marker.global_position, vfx_scene, tree))
	tween.tween_callback(marker.queue_free)

static func execute_poison_mortar_detonation(pos: Vector3, vfx_prefab: PackedScene, tree: SceneTree) -> void:
	if not tree:
		return
	AudioManager.play_sfx("barrel_breaks", 0.7, 0.9, 2.0)
	AudioManager.play_sfx("water_splashes", 0.7, 0.9)
	
	if vfx_prefab:
		var vfx = vfx_prefab.instantiate() as Node3D
		var root = tree.current_scene
		if root:
			root.add_child(vfx)
		vfx.global_position = pos
		vfx.scale = Vector3(2.0, 2.0, 2.0)
		vfx.modulate = Color(0.2, 2.0, 0.6, 1.0)
		
	var camera = tree.get_first_node_in_group("game_camera")
	if camera and camera.has_method("shake"):
		camera.shake(0.20, 0.20)
		
	var player = tree.get_first_node_in_group("player")
	if player and is_instance_valid(player):
		var dist = player.global_position.distance_to(pos)
		if dist <= 1.7 and player.has_method("damage_fleet"):
			player.damage_fleet(1)

func _detonate_poison_mortar(pos: Vector3) -> void:
	execute_poison_mortar_detonation(pos, explosion_scene, get_tree())

func _start_submerge() -> void:
	current_state = State.SUBMERGED
	_submerge_duration = 3.8
	AudioManager.play_sfx("water_splashes", 0.5, 0.7, 2.0)
	
	# Submerge animation: Dive down below the water plane (Y = -3.5)
	if visual_container:
		var tween = create_tween().set_parallel(true)
		tween.tween_property(visual_container, "position:y", -3.5, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		
	# Disable hitbox while underwater
	if hit_box:
		hit_box.set_deferred("monitoring", false)
		hit_box.set_deferred("monitorable", false)
		
	# Emit 3 expanding shockwaves
	for i in range(3):
		get_tree().create_timer(i * 0.9).timeout.connect(func():
			if _is_defeated or not is_instance_valid(self):
				return
			_emit_water_shockwave()
		)
		
	# Rain a wave of minions on the user while submerged
	_rain_submerged_mobs()

func _rain_submerged_mobs() -> void:
	var lanes = [-3.0, 3.0, -1.5, 1.5, 0.0, -2.5, 2.5]
	var count = 6 if current_phase >= 2 else 5
	print("[BOSS SUBMERGED] Raining %d mobs on the player!" % count)
	for i in range(count):
		var delay = 0.35 + (i * 0.45)
		var lane_x = lanes[i % lanes.size()]
		get_tree().create_timer(delay).timeout.connect(func():
			if _is_defeated or not is_instance_valid(self):
				return
			_spawn_bayou_adds(lane_x, i % 2)
		)

func _process_submerged(delta: float) -> void:
	_submerge_duration -= delta
	global_position.x = sin(combat_time * 1.5) * patrol_width
	
	if _submerge_duration <= 0.0:
		_resurface()

func _emit_water_shockwave() -> void:
	AudioManager.play_sfx("water_splashes", 0.8, 1.1)
	var shockwave = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = 1.0
	torus.outer_radius = 1.5
	shockwave.mesh = torus
	
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.1, 0.95, 0.7, 0.6)
	shockwave.material_override = mat
	get_tree().current_scene.add_child(shockwave)
	shockwave.global_position = Vector3(global_position.x, 0.05, global_position.z)
	
	var tween = shockwave.create_tween().set_parallel(true)
	tween.tween_property(shockwave, "scale", Vector3(5.5, 1.0, 5.5), 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(mat, "albedo_color:a", 0.0, 1.2)
	tween.chain().tween_callback(func():
		shockwave.queue_free()
	)
	
	var camera = get_tree().get_first_node_in_group("game_camera")
	if camera and camera.has_method("shake"):
		camera.shake(0.18, 0.16)

func _resurface() -> void:
	current_state = State.COMBAT
	AudioManager.play_sfx("water_splashes", 0.6, 0.8, 3.0)
	
	if visual_container:
		var tween = create_tween().set_parallel(true)
		tween.tween_property(visual_container, "position:y", _base_y, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		
	if hit_box:
		hit_box.set_deferred("monitoring", true)
		hit_box.set_deferred("monitorable", true)
		
	_fire_poison_mortars()

func _spawn_bayou_adds(lane_x_override: float = NAN, type_choice: int = -1) -> void:
	var parent = get_tree().get_first_node_in_group("level_controller")
	if not parent: parent = get_parent()
	if not parent: return
	
	var lx = randf_range(-3.5, 3.5) if is_nan(lane_x_override) else lane_x_override
	lx = clampf(lx, -4.2, 4.2)
	var use_skiff = (randf() < 0.55) if type_choice < 0 else (type_choice == 0)
	
	if use_skiff and grave_skiff_scene:
		var skiff = grave_skiff_scene.instantiate() as Area3D
		parent.add_child(skiff)
		skiff.global_position = Vector3(lx, 0.1, global_position.z + 4.0)
		skiff.max_hp = 12 if current_phase >= 2 else 10
		skiff.current_hp = skiff.max_hp
		skiff.forward_speed = 3.0
	elif tide_cutter_scene:
		var cutter = tide_cutter_scene.instantiate() as Area3D
		parent.add_child(cutter)
		cutter.global_position = Vector3(lx, 0.1, global_position.z + 4.0)
		cutter.max_hp = 16 if current_phase >= 2 else 14
		cutter.current_hp = cutter.max_hp
		cutter.forward_speed = 5.0

func take_damage(amount: int) -> void:
	if _is_defeated or current_state == State.SUBMERGED:
		return
		
	current_hp = max(0, current_hp - amount)
	print("[BOSS HIT] The Phantom Dredge took %d damage | HP: %d/%d" % [amount, current_hp, max_hp])
	GameState.boss_health_changed.emit(current_hp, max_hp)
	_flash_boss()
	
	var ft_script = load("res://src/gameplay/vfx/floating_text.gd")
	if ft_script:
		var fct = ft_script.new()
		var root = get_tree().current_scene
		if root:
			root.add_child(fct)
			fct.global_position = global_position + Vector3(randf_range(-0.8, 0.8), 2.0, randf_range(-0.8, 0.8))
			fct.setup("-" + str(amount), Color(0.2, 1.0, 0.6))
			
	if current_hp <= 0:
		boss_defeat()
	else:
		_check_phase()

func _flash_boss() -> void:
	if not visual_container:
		return
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_property(visual_container, "scale", Vector3(1.06, 1.06, 1.06), 0.05)
	_flash_tween.tween_property(visual_container, "scale", Vector3.ONE, 0.1)

func _check_phase() -> void:
	if current_phase == 1 and current_hp <= int(max_hp * 0.7):
		current_phase = 2
		weave_speed = 1.6
		AudioManager.play_sfx("gate_passes", 0.8, 1.0)
	elif current_phase == 2 and current_hp <= int(max_hp * 0.3):
		current_phase = 3
		weave_speed = 2.0
		AudioManager.play_sfx("gate_passes", 0.7, 0.9)

func boss_defeat() -> void:
	if _is_defeated:
		return
	_is_defeated = true
	current_state = State.DYING
	GameState.targets_destroyed += 1
	
	# Series of massive green and fire explosions
	var tween = create_tween()
	for i in range(16):
		tween.tween_callback(func():
			if explosion_scene:
				var vfx = explosion_scene.instantiate() as Node3D
				get_tree().current_scene.add_child(vfx)
				vfx.global_position = global_position + Vector3(randf_range(-3.5, 3.5), randf_range(0.2, 2.0), randf_range(-2.5, 2.5))
				vfx.scale = Vector3.ONE * randf_range(2.0, 3.5)
				vfx.modulate = Color(0.3, 1.8, 0.5, 1.0) if randf() < 0.6 else Color(2.0, 1.5, 0.4, 1.0)
			AudioManager.play_sfx("barrel_breaks", 0.5, 1.2, 2.0)
		)
		tween.tween_interval(0.11)
		
	tween.tween_callback(func():
		AudioManager.stop_music()
		AudioManager.play_sfx("gate_passes", 0.6, 0.8, 3.0)
		AudioManager.play_sfx("coin_pickups", 0.9, 1.1, 4.0)
		_spawn_doubloon_fountain()
	)
	tween.tween_interval(1.8)
	tween.tween_callback(func():
		GameState.is_game_active = false
		GameState.unlock_next_level()
		GameState.level_completed.emit(GameState.doubloons, GameState.targets_destroyed)
		queue_free()
	)

func _spawn_doubloon_fountain() -> void:
	if not doubloon_scene:
		return
	for i in range(180):
		var d = doubloon_scene.instantiate() as Area3D
		if d:
			get_tree().current_scene.add_child(d)
			d.global_position = Vector3(global_position.x, 0.1, global_position.z)
			if d.has_method("_trigger_spawn_bounce"):
				d._trigger_spawn_bounce(Vector2(randf_range(-4.0, 4.0), randf_range(-4.0, 4.0)))
