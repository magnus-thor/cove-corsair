class_name BossBoneBeard
extends Area3D

enum State { APPROACHING, COMBAT, DYING }

@export var max_hp: int = 100
@export var current_hp: int = 100
@export var boarding_rig: PackedScene = preload("res://src/features/boarding/rigs/enemy/rig_bone_beard.tscn")
@export var approach_speed: float = 14.0
@export var combat_z_offset: float = -18.0
@export var weave_speed: float = 1.8
@export var attack_interval: float = 2.5
@export var spawn_hazard_enabled: bool = true
@export var hazard_telegraph_time: float = 1.8
@export var max_active_adds: int = 2

@export var doubloon_scene: PackedScene = preload("res://src/gameplay/collectibles/collectible_doubloon.tscn")
@export var explosion_scene: PackedScene = preload("res://src/vfx/barrel_explosion.tscn")
@export var powder_keg_scene: PackedScene = preload("res://src/gameplay/obstacles/destructible_barrel.tscn")
@export var twin_salvo_scene: PackedScene = preload("res://src/gameplay/projectiles/boss_projectile_twin_cannon_salvo.tscn")

@onready var boss_sprite: Node3D = get_node_or_null("BossMesh") if get_node_or_null("BossMesh") else get_node_or_null("BossSprite")
@onready var health_bar_viewport: SubViewport = get_node_or_null("HealthBarViewport") as SubViewport
@onready var health_bar_sprite: Sprite3D = get_node_or_null("HealthBarSprite") as Sprite3D
@onready var health_bar_progress: ProgressBar = get_node_or_null("HealthBarViewport/HealthBarControl/VBoxContainer/ProgressBar")
@onready var health_title_label: Label = get_node_or_null("HealthBarViewport/HealthBarControl/VBoxContainer/BossTitleLabel")

var current_state: State = State.APPROACHING
var _flash_tween: Tween
var _base_scale: Vector3 = Vector3(4.48, 4.48, 4.48)
var _attack_timer: float = 0.0
var _attack_count: int = 0
var _weave_time: float = 0.0
var _target_z: float = -18.0
var _current_base_y: float = 0.0
var _is_defeated: bool = false
var is_arena_active: bool = false
var has_triggered_boarding: bool = false

func activate_arena() -> void:
	is_arena_active = true

func take_damage(amount: int) -> void:
	if _is_defeated or current_state == State.DYING or not is_arena_active:
		return
	current_hp = max(0, current_hp - amount)
	EventBus.boss_health_changed.emit(current_hp, max_hp)
	_flash_red()
	_update_health_bar()
	
	var boarding_threshold: int = max(1, int(round(float(max_hp) * 0.20)))
	if current_hp <= boarding_threshold and not has_triggered_boarding:
		if current_hp <= 0:
			current_hp = 1
		_initiate_desperation_boarding()
	elif current_hp <= 0:
		if has_triggered_boarding and not _is_defeated:
			current_hp = 1
		else:
			boss_defeat()

func _initiate_desperation_boarding() -> void:
	if has_triggered_boarding or _is_defeated:
		return
	has_triggered_boarding = true
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	if is_instance_valid(player):
		var adapter: InRunBoardingAdapter = InRunBoardingAdapter.new()
		add_child(adapter)
		adapter.start_in_run_boarding(self, player)

func _ready() -> void:
	_clean_shadow_nodes(self)
	add_to_group("enemies")
	add_to_group("boss")
	add_to_group("destructible")
	
	if health_bar_sprite and health_bar_viewport:
		health_bar_sprite.texture = health_bar_viewport.get_texture()
	
	if has_node("/root/GameState"):
		var gs: Node = get_node("/root/GameState")
		if "current_level" in gs:
			var lvl: int = int(gs.get("current_level"))
			if lvl <= 15:
				max_hp = 1800
			elif lvl <= 20:
				max_hp = 2600
			elif lvl <= 30:
				max_hp = 3800
			else:
				max_hp = 6000
				
	current_hp = max_hp
	_attack_timer = attack_interval * 0.75
	if boss_sprite:
		_current_base_y = 2.00
		boss_sprite.position.y = _current_base_y
		boss_sprite.scale = Vector3(4.48, 4.48, 4.48)
		_base_scale = boss_sprite.scale
		boss_sprite.rotation_degrees = Vector3.ZERO
		if boss_sprite is Sprite3D:
			(boss_sprite as Sprite3D).pixel_size = 0.0021
	_update_health_bar()
	area_entered.connect(_on_area_entered)
	
	GameState.boss_spawned = true
	EventBus.boss_spawned_event.emit("Captain Bone-Beard", max_hp)
	EventBus.boss_health_changed.emit(current_hp, max_hp)
	
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var player_z: float = player.global_position.z if player else 0.0
	_target_z = player_z + combat_z_offset


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
				_attack_timer = 0.5 # First attack shortly after arriving
				
		State.COMBAT:
			global_position.z = lerp(global_position.z, _target_z, 4.0 * delta)
			
			_weave_time += delta * weave_speed
			global_position.x = sin(_weave_time) * 2.5
			
			if boss_sprite:
				boss_sprite.position.y = _current_base_y + sin(_weave_time * 2.0) * 0.05

			_attack_timer += delta
			if _attack_timer >= attack_interval:
				_attack_timer = 0.0
				_perform_attack()

	# Standoff limit guard: ensure the boss never passes the player's standoff threshold
	if is_instance_valid(player):
		var min_standoff: float = player_z - 8.0
		if global_position.z > min_standoff:
			global_position.z = min_standoff

func _perform_attack() -> void:
	if not spawn_hazard_enabled:
		return
	_attack_count += 1
	if _attack_count % 2 == 1:
		_fire_twin_cannon_salvo()
	else:
		_drop_powder_kegs()

const NO_TARGET_OVERRIDE: float = 999.0

func _fire_twin_cannon_salvo(target_lane_x: float = NO_TARGET_OVERRIDE) -> void:
	if not twin_salvo_scene or _is_defeated or current_state == State.DYING:
		return
	
	AudioManager.play_sfx("cannon_shots", 0.85, 1.1, 1.5)
	
	var root := get_tree().current_scene
	var spawn_parent := root if root else get_parent()
	if not spawn_parent:
		return
		
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var target_x: float = global_position.x
	if not is_nan(target_lane_x) and target_lane_x < 900.0:
		target_x = target_lane_x
	elif player and is_instance_valid(player):
		target_x = player.global_position.x

	var salvo := twin_salvo_scene.instantiate() as EnemyCannonball
	if salvo:
		spawn_parent.add_child(salvo)
		salvo.global_position = Vector3(global_position.x, 0.5, global_position.z + 2.5)
		
		var fire_dir := Vector3(0, 0, 1)
		if player and is_instance_valid(player):
			var to_player := Vector3(target_x - salvo.global_position.x, 0.0, player.global_position.z - salvo.global_position.z)
			if to_player.z > 0.1:
				fire_dir = to_player.normalized()
		
		salvo.setup(fire_dir, null, null)
		salvo.direction = fire_dir
		salvo.speed = 12.0

func _fire_bonebeard_salvo() -> void:
	_fire_twin_cannon_salvo()

func _drop_powder_kegs() -> void:
	var lanes: Array[float] = [-2.2, 0.0, 2.2]
	lanes.shuffle()
	
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var player_z: float = player.global_position.z if player and is_instance_valid(player) else 0.0
	var safe_z := minf(global_position.z + 2.5, player_z - 15.0)
	
	for i in range(2):
		var spawn_x: float = lanes[i]
		if powder_keg_scene:
			var keg := powder_keg_scene.instantiate() as DestructibleObstacle
			var root: Node = get_tree().current_scene
			var spawn_parent: Node = root if root else get_parent()
			if spawn_parent and keg:
				spawn_parent.add_child(keg)
				keg.global_position = Vector3(spawn_x, 0.5, safe_z)
				keg.forward_speed = 6.0

func _flash_red() -> void:
	if not is_instance_valid(boss_sprite):
		return
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
		boss_sprite.scale = _base_scale

	_flash_tween = create_tween()
	if "modulate" in boss_sprite:
		_flash_tween.tween_property(boss_sprite, "modulate", Color(3.0, 0.2, 0.2, 1.0), 0.07)
		_flash_tween.tween_property(boss_sprite, "modulate", Color.WHITE, 0.12)
	else:
		boss_sprite.scale = _base_scale
		_flash_tween.tween_property(boss_sprite, "scale", _base_scale * 1.05, 0.04)
		_flash_tween.tween_property(boss_sprite, "scale", _base_scale, 0.08)

func _update_health_bar() -> void:
	if health_bar_progress:
		health_bar_progress.max_value = max_hp
		health_bar_progress.value = current_hp
	if health_title_label:
		health_title_label.text = "CAPTAIN BONE-BEARD - %d HP" % current_hp

func boss_defeat() -> void:
	if _is_defeated:
		return
	_is_defeated = true
	current_state = State.DYING
	
	GameState.targets_destroyed += 1
	
	# Safe collision disabling using deferred calls
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	for child in get_children():
		if child is CollisionShape3D:
			child.set_deferred("disabled", true)
			
	var tween := create_tween()
	for i in range(7):
		tween.tween_callback(func() -> void:
			_spawn_hull_explosion()
			AudioManager.play_sfx("barrel_breaks")
		)
		tween.tween_interval(0.14)
		
	tween.tween_callback(func() -> void:
		_spawn_doubloon_fountain()
	)
	tween.tween_interval(1.5)
	tween.tween_callback(func() -> void:
		EventBus.level_completed.emit(GameState.doubloons, GameState.targets_destroyed)
		queue_free()
	)

func _spawn_hull_explosion() -> void:
	if explosion_scene:
		var vfx := explosion_scene.instantiate() as Node3D
		var root := get_tree().current_scene
		if root:
			root.add_child(vfx)
			var offset := Vector3(randf_range(-2.2, 2.2), randf_range(0.3, 1.8), randf_range(-1.0, 1.0))
			vfx.global_position = global_position + offset

func _spawn_doubloon_fountain() -> void:
	if not doubloon_scene:
		return
	var spawn_parent := get_tree().current_scene
	if not spawn_parent or spawn_parent == self:
		spawn_parent = get_parent()
		if spawn_parent == self or spawn_parent is BossBoneBeard:
			return
		
	var count := randi_range(20, 30)
	for i in range(count):
		var d := doubloon_scene.instantiate() as CollectibleDoubloon
		if d:
			spawn_parent.add_child(d)
			d.global_position = Vector3(global_position.x, 0.05, global_position.z)
			var scatter := Vector2(randf_range(-3.0, 3.0), randf_range(-3.0, 3.0))
			d._trigger_spawn_bounce(scatter)

func _on_area_entered(area: Area3D) -> void:
	if _is_defeated or current_state == State.DYING:
		return
	if area.is_in_group("player") or (area.get_parent() and area.get_parent().is_in_group("player")):
		var player := get_tree().get_first_node_in_group("player") as PlayerSwerve
		if player:
			player.take_hit(1, "BossBoneBeard hull contact")

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
