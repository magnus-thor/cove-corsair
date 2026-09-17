class_name BossSiegeFortress
extends Node3D

enum State { APPROACHING, COMBAT, RAMMING, DYING }

@export var max_hp: int = 800 # Port: 150, Starboard: 150, Prow Ram: 150, Furnace Core: 350
@export var current_hp: int = 800

@export var approach_speed: float = 12.0
@export var combat_z_offset: float = -19.0
@export var weave_speed: float = 1.1
@export var patrol_width: float = 2.6

# Inspector-exposed Boss Tuning Properties
@export var attack_interval: float = 2.2
@export var spawn_hazard_enabled: bool = true
@export var hazard_telegraph_time: float = 1.8
@export var max_active_adds: int = 2

# Component HP
var hp_port_turret: int = 150
var hp_starboard_turret: int = 150
var hp_prow_ram: int = 150
var hp_furnace_core: int = 350

var current_state: State = State.APPROACHING
var current_phase: int = 1
var combat_time: float = 0.0

var _target_z: float = -19.0
var _weave_time: float = 0.0
var _attack_timer: float = 0.0
var _geyser_timer: float = 0.0
var _ram_timer: float = 0.0
var _minion_timer: float = 0.0
var is_barrage_active: bool = false
var _is_defeated: bool = false
var _charge_dir: int = 1
var _y_base: float = 0.5
var _flash_tweens: Dictionary = {}

# Prefabs
@export var enemy_cannonball_scene: PackedScene = preload("res://src/gameplay/projectiles/enemy_cannonball.tscn")
@export var thermal_geyser_scene: PackedScene = preload("res://src/gameplay/obstacles/hazard_thermal_geyser.tscn")
@export var iron_gunner_scene: PackedScene = preload("res://src/gameplay/enemies/enemy_iron_gunner.tscn")
@export var brimstone_raft_scene: PackedScene = preload("res://src/gameplay/enemies/enemy_brimstone_raft.tscn")
@export var doubloon_scene: PackedScene = preload("res://src/gameplay/collectibles/collectible_doubloon.tscn")
@export var explosion_scene: PackedScene = preload("res://src/vfx/barrel_explosion.tscn")

@onready var boss_sprite: Node3D = get_node_or_null("BossMesh") if get_node_or_null("BossMesh") else get_node_or_null("BossSprite")
@onready var port_turret_node: Node3D = $PortTurret
@onready var starboard_turret_node: Node3D = $StarboardTurret
@onready var prow_ram_node: Node3D = $ProwRam
@onready var furnace_core_node: Node3D = $FurnaceCore

var is_arena_active: bool = false
var _base_mesh_scale: Vector3 = Vector3(4.74, 4.74, 4.74)

func activate_arena() -> void:
	is_arena_active = true
	print("[BOSS ARENA] Activated Siege Fortress: vulnerability enabled | HP: %d/%d" % [current_hp, max_hp])

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("boss")
	current_hp = max_hp

	if boss_sprite:
		boss_sprite.position.y = _y_base
		boss_sprite.scale = Vector3(4.74, 4.74, 4.74)
		boss_sprite.rotation_degrees = Vector3.ZERO
		_base_mesh_scale = boss_sprite.scale
	
	EventBus.boss_spawned_event.emit("The Siege Fortress", max_hp)
	EventBus.boss_health_changed.emit(current_hp, max_hp)

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
				_attack_timer = 0.5
				_minion_timer = 3.5 # First minion wave arrives 1.5s into combat!
				
		State.COMBAT:
			_process_combat(delta)
			
		State.RAMMING:
			_process_ram_overdrive(delta)

func _process_combat(delta: float) -> void:
	combat_time += delta
	
	# Horizontal patrol weave
	global_position.z = lerp(global_position.z, _target_z, 3.0 * delta)
	_weave_time += delta * weave_speed
	global_position.x = sin(_weave_time) * patrol_width
	
	if boss_sprite:
		boss_sprite.position.y = _y_base + sin(_weave_time * 2.0) * 0.06
		
	# Turret Broadsides
	_attack_timer += delta
	var attack_cd := attack_interval if current_phase == 1 else (attack_interval * 0.75 if current_phase == 2 else attack_interval * 0.5)
	if _attack_timer >= attack_cd:
		_attack_timer = 0.0
		_fire_fortress_salvo()
		
	# Geyser Slams (paused if hazards disabled or barrage active)
	if spawn_hazard_enabled and not is_barrage_active:
		_geyser_timer += delta
		var geyser_cd := 7.0 if current_phase == 1 else (5.0 if current_phase == 2 else 3.5)
		if _geyser_timer >= geyser_cd:
			_geyser_timer = 0.0
			_trigger_geyser_slam()
		
	# Ram Overdrive Trigger (Phase 2 & 3)
	if current_phase >= 2 and hp_prow_ram > 0:
		_ram_timer += delta
		var ram_cd := 10.0 if current_phase == 2 else 7.0
		if _ram_timer >= ram_cd:
			_ram_timer = 0.0
			_start_ram_overdrive()
			return
			
	# Reinforcement Minions
	_minion_timer += delta
	var minion_cd := 5.0 if current_phase == 1 else 4.0
	if _minion_timer >= minion_cd:
		_minion_timer = 0.0
		_spawn_bastion_minions()

func _fire_fortress_salvo() -> void:
	var shoot_points: Array[Node3D] = []
	if hp_port_turret > 0 and is_instance_valid(port_turret_node):
		shoot_points.append(port_turret_node)
	if hp_starboard_turret > 0 and is_instance_valid(starboard_turret_node):
		shoot_points.append(starboard_turret_node)
	if shoot_points.is_empty():
		shoot_points.append(furnace_core_node)
		
	AudioManager.play_sfx("cannon_shots", 0.7, 0.9, 2.0)
	is_barrage_active = true
	get_tree().create_timer(1.2).timeout.connect(func() -> void:
		is_barrage_active = false
	)
	
	for point in shoot_points:
		if not is_instance_valid(point):
			continue
		var ball := enemy_cannonball_scene.instantiate() as Area3D
		var root: Node = get_tree().current_scene
		if root:
			root.add_child(ball)
		else:
			get_parent().add_child(ball)
		ball.global_position = point.global_position + Vector3(0, 0.4, 1.2)
		ball.set_meta("is_fire", true)
		var enemy_ball := ball as EnemyCannonball
		if enemy_ball:
			enemy_ball.set_color(Color(1.0, 0.45, 0.1))
			enemy_ball.attach_fire_trail()
			enemy_ball.speed = 18.0

		var fire_dir := Vector3(0, 0, 1)
		var player := get_tree().get_first_node_in_group("player") as Node3D
		if player and is_instance_valid(player):
			var to_player: Vector3 = (player.global_position - ball.global_position)
			to_player.y = 0.0
			if to_player.length_squared() > 0.01:
				fire_dir = to_player.normalized()
				if fire_dir.z < 0.1:
					fire_dir.z = 0.4
					fire_dir = fire_dir.normalized()
		if enemy_ball:
			enemy_ball.setup(fire_dir, null, null)
			enemy_ball.direction = fire_dir

func _trigger_geyser_slam() -> void:
	if not spawn_hazard_enabled or is_barrage_active:
		return
	AudioManager.play_sfx("barrel_breaks", 0.5, 0.7, 4.0)
	AudioManager.play_sfx("water_splashes", 0.5, 0.7, 3.0)
	
	var camera := get_tree().get_first_node_in_group("game_camera") as GameCamera
	if camera and camera.has_method("shake"):
		camera.shake(0.35, 0.3)
		
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if not player or not is_instance_valid(player):
		return
		
	# Telegraphed lane-based volcanic pillars:
	# Always leaves a clear, readable 3.8m+ lane for the player to maneuver through.
	var px: float = player.global_position.x
	var target_lanes: Array[float] = []
	if px < -1.2:
		# Player is on the left; erupt left & center, leaving right corridor wide open
		target_lanes = [-3.5, 0.0]
	elif px > 1.2:
		# Player is on the right; erupt right & center, leaving left corridor wide open
		target_lanes = [3.5, 0.0]
	else:
		# Player is in center; erupt flanking lanes at +/- 3.6, keeping 4.0m center corridor clear
		target_lanes = [-3.6, 3.6]

	for lx in target_lanes:
		if thermal_geyser_scene:
			var geyser := thermal_geyser_scene.instantiate() as Node3D
			get_tree().current_scene.add_child(geyser)
			# Ensure hazard NEVER spawns within 15 meters of player vessel
			var safe_z := minf(player.global_position.z - 16.0, global_position.z + 3.0)
			geyser.global_position = Vector3(lx, 0.0, safe_z)
			if "forward_speed" in geyser:
				geyser.set("forward_speed", 6.5)
			if "telegraph_duration" in geyser:
				geyser.set("telegraph_duration", maxf(1.6, hazard_telegraph_time))
			if "eruption_duration" in geyser:
				geyser.set("eruption_duration", 1.8)

func _start_ram_overdrive() -> void:
	current_state = State.RAMMING
	_charge_dir = 1
	AudioManager.play_sfx("gate_passes", 0.6, 0.8, 4.0)
	
	if boss_sprite:
		var tween := create_tween()
		if "modulate" in boss_sprite:
			tween.tween_property(boss_sprite, "modulate", Color(3.0, 1.0, 0.2, 1.0), 0.2)
			tween.tween_property(boss_sprite, "modulate", Color(1.4, 0.6, 0.3, 1.0), 0.3)
		else:
			var sc := boss_sprite.scale
			tween.tween_property(boss_sprite, "scale", sc * 1.12, 0.2)
			tween.tween_property(boss_sprite, "scale", sc, 0.3)

func _process_ram_overdrive(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var player_z: float = player.global_position.z if player else 0.0
	_minion_timer += delta * 0.5
	
	if _charge_dir == 1:
		# Rapid forward thrust
		global_position.z = move_toward(global_position.z, player_z - 3.0, 22.0 * delta)
		
		# Check hit
		if abs(global_position.z - (player_z - 3.0)) < 0.8:
			var player_swerve := player as PlayerSwerve
			if player_swerve:
				player_swerve.take_hit(1, "BossSiegeFortress ram")
				AudioManager.play_sfx("barrel_breaks", 0.6, 0.8, 3.0)
			_charge_dir = -1 # Retreat
	else:
		# Retreat back
		global_position.z = move_toward(global_position.z, _target_z, 9.0 * delta)
		if abs(global_position.z - _target_z) < 0.5:
			current_state = State.COMBAT

func _spawn_bastion_minions() -> void:
	var existing_enemies := get_tree().get_nodes_in_group("enemies").filter(
		func(e: Node) -> bool: return is_instance_valid(e) and not e.is_in_group("boss") and not e.is_queued_for_deletion()
	)
	if existing_enemies.size() >= max_active_adds:
		return
		
	var root: Node = get_tree().current_scene
	if not root: root = get_tree().get_first_node_in_group("level_controller")
	if not root: root = get_parent()
	if not root: return
	
	AudioManager.play_sfx("gate_passes", 1.2, 1.4, 0.0)
	
	# Structure escort waves based on phase
	var spawns: Array[Dictionary] = []
	if current_phase == 1:
		# Phase 1: 1 Iron Gunner escort + 1 Brimstone Raft
		var side := -1.0 if randf() < 0.5 else 1.0
		spawns.append({"type": "gunner", "pos": Vector3(-2.2 * side, 0.1, global_position.z + 3.5)})
		spawns.append({"type": "raft", "pos": Vector3(2.2 * side, 0.1, global_position.z + 4.5)})
	elif current_phase == 2:
		# Phase 2: Dual Brimstone Rafts charging ahead
		spawns.append({"type": "raft", "pos": Vector3(-2.6, 0.1, global_position.z + 3.5)})
		spawns.append({"type": "raft", "pos": Vector3(2.6, 0.1, global_position.z + 3.5)})
	else:
		# Phase 3: 1 Iron Gunner center + dual flanking Brimstone Rafts
		spawns.append({"type": "gunner", "pos": Vector3(0.0, 0.1, global_position.z + 4.0)})
		spawns.append({"type": "raft", "pos": Vector3(-3.0, 0.1, global_position.z + 3.2)})
		spawns.append({"type": "raft", "pos": Vector3(3.0, 0.1, global_position.z + 3.2)})

	# Cap spawns according to max_active_adds
	var available_slots := max_active_adds - existing_enemies.size()
	if available_slots <= 0:
		return
	if spawns.size() > available_slots:
		spawns = spawns.slice(0, available_slots)

	for s in spawns:
		var mob: EnemyMob = null
		if s["type"] == "gunner" and iron_gunner_scene:
			mob = iron_gunner_scene.instantiate() as EnemyMob
		elif s["type"] == "raft" and brimstone_raft_scene:
			mob = brimstone_raft_scene.instantiate() as EnemyMob
			
		if mob:
			root.add_child(mob)
			var pos_clamped: Vector3 = s["pos"]
			pos_clamped.x = clampf(pos_clamped.x, -4.2, 4.2)
			mob.global_position = pos_clamped
			if GameState.boss_spawned:
				print("[BOSS MINION] Spawning %s at pos: %s | HP: %d" % [mob.name, mob.global_position, mob.current_hp])

# Damage Routing
func take_damage(amount: int) -> void:
	damage_component("furnace_core", amount, false)

func damage_component(comp_name: String, amount: int, _from_bow: bool = false) -> void:
	if _is_defeated or not is_arena_active:
		return

		
	if GameState.boss_spawned:
		print("[BOSS HIT] The Siege Fortress [%s] took %d dmg | HP: %d/%d" % [comp_name, amount, current_hp, max_hp])
		
	match comp_name:
		"port_turret":
			if hp_port_turret > 0:
				hp_port_turret = max(0, hp_port_turret - amount)
				current_hp = max(0, current_hp - amount)
				EventBus.boss_health_changed.emit(current_hp, max_hp)
				_flash_node(port_turret_node)
				if hp_port_turret <= 0:
					_destroy_subpart(port_turret_node)
			else:
				damage_component("furnace_core", amount, _from_bow)
					
		"starboard_turret":
			if hp_starboard_turret > 0:
				hp_starboard_turret = max(0, hp_starboard_turret - amount)
				current_hp = max(0, current_hp - amount)
				EventBus.boss_health_changed.emit(current_hp, max_hp)
				_flash_node(starboard_turret_node)
				if hp_starboard_turret <= 0:
					_destroy_subpart(starboard_turret_node)
			else:
				damage_component("furnace_core", amount, _from_bow)
					
		"prow_ram":
			if hp_prow_ram > 0:
				hp_prow_ram = max(0, hp_prow_ram - amount)
				current_hp = max(0, current_hp - amount)
				EventBus.boss_health_changed.emit(current_hp, max_hp)
				_flash_node(prow_ram_node)
				if hp_prow_ram <= 0:
					_destroy_subpart(prow_ram_node)
			else:
				damage_component("furnace_core", amount, _from_bow)
					
		"furnace_core":
			# Takes full damage always, but takes double if turrets are down
			var mult := 1.5 if (hp_port_turret <= 0 and hp_starboard_turret <= 0) else 1.0
			var actual_dmg := int(amount * mult)
			hp_furnace_core = max(0, hp_furnace_core - actual_dmg)
			current_hp = max(0, current_hp - actual_dmg)
			EventBus.boss_health_changed.emit(current_hp, max_hp)
			_flash_node(furnace_core_node)
			_flash_boss_main()
			
	if current_hp <= 0:
		boss_defeat()
	else:
		_check_phase()

func _flash_node(_node: Variant) -> void:
	_flash_boss_main()

func _flash_boss_main() -> void:
	if not boss_sprite:
		return
	if _flash_tweens.has("boss_main") and is_instance_valid(_flash_tweens["boss_main"]):
		var cur_tw := _flash_tweens["boss_main"] as Tween
		if cur_tw and cur_tw.is_valid():
			cur_tw.kill()
		boss_sprite.scale = _base_mesh_scale
	var tween := create_tween()
	_flash_tweens["boss_main"] = tween
	if "modulate" in boss_sprite:
		boss_sprite.set("modulate", Color(2.5, 0.8, 0.4, 1.0))
		tween.tween_property(boss_sprite, "modulate", Color(1.4, 0.6, 0.3, 1.0), 0.1)
	else:
		tween.tween_property(boss_sprite, "scale", _base_mesh_scale * 1.06, 0.04)
		tween.tween_property(boss_sprite, "scale", _base_mesh_scale, 0.08)

func _destroy_subpart(node: Variant) -> void:
	if not is_instance_valid(node):
		return
	AudioManager.play_sfx("barrel_breaks")
	if explosion_scene and (node is Node3D):
		var vfx := explosion_scene.instantiate() as Node3D
		var root: Node = get_tree().current_scene
		if root and vfx:
			root.add_child(vfx)
			vfx.global_position = (node as Node3D).global_position
	if is_instance_valid(node):
		if "visible" in node:
			node.visible = false
		if node is Node:
			var n := node as Node
			n.remove_from_group("boss")
			n.remove_from_group("destructible")
			n.remove_from_group("enemies")
		if node is Area3D:
			var a := node as Area3D
			a.set_deferred("monitoring", false)
			a.set_deferred("monitorable", false)
		if node is CollisionObject3D:
			for child: Node in (node as Node).get_children():
				if child is CollisionShape3D:
					(child as CollisionShape3D).set_deferred("disabled", true)

func _check_phase() -> void:
	if current_phase == 1 and current_hp <= int(max_hp * 0.65):
		current_phase = 2
		weave_speed = 1.4
		AudioManager.play_sfx("gate_passes", 0.8, 1.0)
	elif current_phase == 2 and current_hp <= int(max_hp * 0.35):
		current_phase = 3
		weave_speed = 1.8
		if boss_sprite and "modulate" in boss_sprite:
			boss_sprite.set("modulate", Color(2.5, 0.4, 0.1, 1.0))
		AudioManager.play_sfx("gate_passes", 0.7, 0.9)

func boss_defeat() -> void:
	if _is_defeated:
		return
	_is_defeated = true
	current_state = State.DYING
	GameState.targets_destroyed += 1
	
	# Grand fortress meltdown explosion sequence
	var tween := create_tween()
	for i in range(24):
		tween.tween_callback(func() -> void:
			if explosion_scene:
				var vfx := explosion_scene.instantiate() as Node3D
				if vfx:
					get_tree().current_scene.add_child(vfx)
					vfx.global_position = global_position + Vector3(randf_range(-4.0, 4.0), randf_range(0.2, 2.5), randf_range(-3.0, 3.0))
					vfx.scale = Vector3.ONE * randf_range(2.5, 4.5)
					if "modulate" in vfx:
						vfx.set("modulate", Color(3.0, 1.0, 0.2, 1.0) if randf() < 0.7 else Color(2.5, 2.0, 0.5, 1.0))
			AudioManager.play_sfx("barrel_breaks", 0.4, 1.0, 3.0)
		)
		tween.tween_interval(0.09)
		
	tween.tween_callback(func() -> void:
		AudioManager.stop_music()
		AudioManager.play_sfx("gate_passes", 0.5, 0.7, 4.0)
		AudioManager.play_sfx("coin_pickups", 0.9, 1.1, 5.0)
		_spawn_doubloon_fountain()
	)
	tween.tween_interval(2.2)
	tween.tween_callback(func() -> void:
		GameState.is_game_active = false
		GameState.unlock_next_level()
		# Emit campaign completion and level complete on EventBus (cross-boundary, Rule B).
		EventBus.campaign_completed.emit(GameState.doubloons, GameState.targets_destroyed)
		EventBus.level_completed.emit(GameState.doubloons, GameState.targets_destroyed)
		queue_free()
	)

func _spawn_doubloon_fountain() -> void:
	if not doubloon_scene:
		return
	for i in range(250):
		var d := doubloon_scene.instantiate() as CollectibleDoubloon
		if d:
			get_tree().current_scene.add_child(d)
			d.global_position = Vector3(global_position.x, 0.1, global_position.z)
			d._trigger_spawn_bounce(Vector2(randf_range(-5.0, 5.0), randf_range(-5.0, 5.0)))
