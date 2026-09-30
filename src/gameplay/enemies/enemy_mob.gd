class_name EnemyMob
extends Area3D

@export var enemy_data: EnemyData = preload("res://src/data/resources/enemy_vessels/skeleton_rower.tres"):
	set(val):
		if enemy_data == val:
			return
		enemy_data = val
		if is_node_ready():
			apply_enemy_data(enemy_data)

## Fallback mob type string for backwards compatibility
@export var mob_type: String = "skeleton_rower":
	set(val):
		mob_type = val
		if is_node_ready() and not enemy_data:
			_apply_mob_type_fallback()

@export var max_hp: int = 3
@export var forward_speed: float = 2.0
@export var doubloons_drop: int = 2

@export_group("Combat Behavior")
@export var can_shoot: bool = false
@export var is_gunner_vanguard: bool = false

@export_group("Enemy Sprite Orientation")
@export var enemy_pitch_deg: float = -40.0

## Prefabs
@export var doubloon_scene: PackedScene = preload("res://src/gameplay/collectibles/collectible_doubloon.tscn")
@export var barrel_explosion_scene: PackedScene = preload("res://src/vfx/barrel_explosion.tscn")
@export var enemy_cannonball_scene: PackedScene = preload("res://src/gameplay/projectiles/enemy_cannonball.tscn")

@onready var enemy_sprite: Sprite3D = $EnemySprite
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var health_bar_viewport: SubViewport = get_node_or_null("HealthBarViewport")
@onready var health_bar_progress: ProgressBar = get_node_or_null("HealthBarViewport/HealthBarControl/ProgressBar")
@onready var health_bar_sprite: Sprite3D = get_node_or_null("HealthBarSprite")
@onready var health_component: HealthComponent = get_node_or_null("HealthComponent")

var _time: float = 0.0
var _is_dead: bool = false
var _current_base_y: float = 1.25
var shoot_cooldown_timer: float = 0.0
var _hits_received: int = 0

## Read-only passthrough for legacy current_hp reads (e.g. hazard_sea_mine.gd).
var current_hp: int:
	get:
		return health_component._current_health if health_component else max_hp

func _ready() -> void:
	_clean_shadow_nodes(self)
	add_to_group("enemies")
	add_to_group("destructible")
	
	area_entered.connect(_on_area_entered)
	
	# Wire HealthComponent (Blueprint 1)
	if health_component:
		health_component.died.connect(die)
		health_component.health_changed.connect(_on_health_changed)
	else:
		var hc := HealthComponent.new()
		hc.name = "HealthComponent"
		hc.max_health = max_hp
		add_child(hc)
		health_component = hc
		health_component.died.connect(die)
		health_component.health_changed.connect(_on_health_changed)
	
	if enemy_data:
		apply_enemy_data(enemy_data)
	else:
		_apply_mob_type_fallback()
		
	_update_health_bar()
	_time = randf_range(0.0, TAU)
	
	# Attach stern hydrodynamic water wake
	var wake_scene := preload("res://src/vfx/boat_wake.tscn")
	if wake_scene:
		var wake := wake_scene.instantiate() as Node3D
		if wake:
			add_child(wake)
			wake.position = Vector3(0, 0.02, -0.9)
			wake.rotation_degrees = Vector3(0, 180, 0)
			wake.scale = Vector3(0.7, 0.7, 0.7)

func apply_enemy_data(data: EnemyData) -> void:
	if not data:
		return
		
	var cur_lvl: int = GameState.current_level if GameState else 1
	var hp_mult: float = 1.0
	if cur_lvl > 30:
		hp_mult = 2.4
	elif cur_lvl > 15:
		hp_mult = 1.6
	elif cur_lvl > 6:
		hp_mult = 1.25
	max_hp = int(ceil(float(data.max_hp) * hp_mult))
	forward_speed = data.forward_speed
	doubloons_drop = data.doubloon_drop_count
	_current_base_y = data.y_offset
	
	# Sync HealthComponent with EnemyData values
	if health_component:
		health_component.reset(max_hp)
	
	if enemy_sprite:
		enemy_sprite.texture = data.sprite_texture
		enemy_sprite.pixel_size = data.pixel_size
		enemy_sprite.rotation_degrees = Vector3(enemy_pitch_deg, 0, 0)
		enemy_sprite.position = Vector3(0, data.y_offset, 0)
		enemy_sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		enemy_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		
	if collision_shape:
		var box := collision_shape.shape as BoxShape3D
		if not box:
			box = BoxShape3D.new()
			collision_shape.shape = box
		box.size = data.collision_size
		collision_shape.position = Vector3(0, data.collision_size.y * 0.5, 0)
		
	if health_bar_sprite:
		health_bar_sprite.position = Vector3(0, data.y_offset + 0.85, 0)
		
	_update_health_bar()

func _apply_mob_type_fallback() -> void:
	var path_map := {
		"skeleton_rower": "res://src/data/resources/enemy_vessels/skeleton_rower.tres",
		"raider_skiff": "res://src/data/resources/enemy_vessels/raider_skiff.tres",
		"goblin_skiff": "res://src/data/resources/enemy_vessels/raider_skiff.tres",
		"turtle_raft": "res://src/data/resources/enemy_vessels/turtle_raft.tres",
		"ghost_sloop": "res://src/data/resources/enemy_vessels/ghost_sloop.tres",
		"bone_beard": "res://src/data/resources/enemy_bosses/boss_bone_beard.tres"
	}
	if path_map.has(mob_type):
		var res := load(path_map[mob_type]) as EnemyData
		if res:
			apply_enemy_data(res)

func _physics_process(delta: float) -> void:
	if _is_dead or not GameState.is_game_active:
		return
		
	_time += delta
	
	# Constant downward river movement
	global_position.z += forward_speed * delta
	
	# Gentle floating bobbing
	if enemy_sprite:
		enemy_sprite.position.y = _current_base_y + sin(_time * 3.0) * 0.04
		
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var player_z: float = player.global_position.z if player else 0.0
	
	# Active Combatant Homing / Steering
	if has_meta("is_kamikaze") and get_meta("is_kamikaze") and player and is_instance_valid(player):
		global_position.x = move_toward(global_position.x, player.global_position.x, 2.5 * delta)
		global_position.x = clampf(global_position.x, -4.2, 4.2)
		
	# Active Combatant Shooting:
	# Regular lane vessels and boss adds NEVER shoot.
	# Only explicitly designated Gunner Vanguards at the end of non-boss levels shoot.
	var is_boss_active := GameState.boss_spawned or get_tree().get_first_node_in_group("boss") != null
	var can_fire := (can_shoot or is_gunner_vanguard) and not is_boss_active
	if can_fire:
		var dist_to_player: float = absf(global_position.z - player_z)
		# Only shoot if player is at fair distance (14m to 45m); never point-blank
		if dist_to_player >= 14.0 and dist_to_player <= 45.0:
			shoot_cooldown_timer += delta
			var shoot_interval := 2.6
			if shoot_cooldown_timer >= shoot_interval:
				shoot_cooldown_timer = 0.0
				_fire_forward_cannonball()
		
	# Clean up and leak threat if passed behind the player boat
	if global_position.z > (player_z + 3.0):
		GameState.record_mob_leaked()
		if player and player.has_method("leak_threat"):
			player.call("leak_threat", self)
		queue_free()

func _fire_forward_cannonball() -> void:
	if not enemy_cannonball_scene:
		return
		
	var ball := enemy_cannonball_scene.instantiate() as EnemyCannonball
	var root := get_tree().current_scene
	if root and ball:
		root.add_child(ball)
	elif ball:
		get_parent().add_child(ball)
		
	if not ball:
		return
		
	# Spawn slightly ahead in positive Z (downriver facing)
	ball.global_position = global_position + Vector3(0.0, 0.4, 1.2)
	
	# Calibrated dodgeable projectile speed (12.5 m/s) with telegraphed travel time
	var ball_speed: float = 12.5
	var mob_name_lower := ""
	if enemy_data:
		mob_name_lower = enemy_data.mob_name.to_lower()
	elif mob_type:
		mob_name_lower = mob_type.to_lower()
		
	if "elite" in mob_name_lower or "ironclad" in mob_name_lower:
		ball_speed = 21.0
	elif "sloop" in mob_name_lower or "ghost" in mob_name_lower:
		ball_speed = 19.5
	elif "rower" in mob_name_lower or "skeleton" in mob_name_lower:
		ball_speed = 17.5
		
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var fire_dir := Vector3(0, 0, 1) # Default downriver facing
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
	ball.speed = ball_speed
		
	if "ghost" in mob_name_lower or "sloop" in mob_name_lower:
		ball.set_color(Color(0.2, 1.0, 0.75)) # Spectral ghost cyan/green
		
	AudioManager.play_sfx("cannon_shots", 0.9, 1.1, -4.0)

func _on_area_entered(area: Area3D) -> void:
	if _is_dead or not GameState.is_game_active:
		return
	# Colliding with player directly
	if area.is_in_group("player") or (area.get_parent() and area.get_parent().is_in_group("player")):
		var player: Node = get_tree().get_first_node_in_group("player")
		if player and player.has_method("take_hit"):
			player.call("take_hit", 1, "enemy_mob_collision")
		die()

func take_damage(amount: int) -> void:
	if _is_dead:
		return
	if health_component:
		health_component.take_damage(amount, "")
		if not _is_dead:
			_flash_white()
		_spawn_damage_text(amount)

## take_hit is the canonical entry point (SSOT Rule C).
func take_hit(amount: int, source_info: String = "") -> void:
	if _is_dead:
		return
	_hits_received += 1
	if health_component:
		health_component.take_damage(amount, source_info)
		if not _is_dead:
			_flash_white()
		_spawn_damage_text(amount)

func _spawn_damage_text(amount: int) -> void:
	var ft_script := load("res://src/vfx/floating_text.gd") as GDScript
	if ft_script:
		var fct: Node3D = ft_script.new() as Node3D
		var root := get_tree().current_scene
		if root and fct:
			root.add_child(fct)
			fct.global_position = global_position + Vector3(randf_range(-0.5, 0.5), 1.2, randf_range(-0.5, 0.5))
			if fct.has_method("setup"):
				fct.call("setup", "-" + str(amount), Color(1.0, 0.3, 0.3))

func _on_health_changed(_current: int, _max_val: int) -> void:
	_update_health_bar()

func _flash_white() -> void:
	HitFlashComponent.flash_node(self, 0.065)

func _update_health_bar() -> void:
	var cur := health_component._current_health if health_component else max_hp
	var mx := health_component.max_health if health_component else max_hp
	if health_bar_progress:
		health_bar_progress.max_value = mx
		health_bar_progress.value = cur
		
		# Color lerp: Green -> Yellow -> Red
		var ratio := float(cur) / float(mx) if mx > 0 else 0.0
		if ratio > 0.5:
			health_bar_progress.modulate = Color(0.2, 0.9, 0.3).lerp(Color(1.0, 0.85, 0.1), (1.0 - ratio) * 2.0)
		else:
			health_bar_progress.modulate = Color(1.0, 0.85, 0.1).lerp(Color(0.95, 0.2, 0.2), (0.5 - ratio) * 2.0)

func die() -> void:
	if _is_dead:
		return
	_is_dead = true

	# Trigger arcade hit stop on heavy/elite vessels
	if max_hp >= 4 and VFXManager and VFXManager.has_method("hit_stop"):
		VFXManager.hit_stop(0.045)
	
	if mob_type == "turtle_raft" or (enemy_data and "turtle" in enemy_data.resource_path.to_lower()):
		if VFXManager:
			VFXManager.spawn_wood_debris(global_position)
	
	GameState.targets_destroyed += 1
	AudioManager.play_sfx("barrel_breaks")
	_spawn_explosion()
	_spawn_doubloons()
	
	# Trigger camera shake on death!
	var camera := get_tree().get_first_node_in_group("game_camera") as GameCamera
	if camera:
		camera.shake(0.18, 0.16)

	# ── Engagement telemetry ─────────────────────────────────────────────────
	if EventBus and EventBus.has_signal("mob_killed"):
		var player_node: Node3D = get_tree().get_first_node_in_group("player") as Node3D
		var dist_to_player: float = 0.0
		if is_instance_valid(player_node):
			dist_to_player = absf(global_position.z - player_node.global_position.z)
		var river_dist: float = GameState.distance_traveled if GameState else 0.0
		var mob_label: String = enemy_data.mob_name if (enemy_data and not enemy_data.mob_name.is_empty()) else mob_type
		EventBus.mob_killed.emit(mob_label, max_hp, dist_to_player, river_dist)

	var player: Node = get_tree().get_first_node_in_group("player")
	if player and player.has_method("upgrade_ship"):
		player.call("upgrade_ship", 1)
		
	queue_free()

func _spawn_explosion() -> void:
	if barrel_explosion_scene:
		var vfx := barrel_explosion_scene.instantiate() as Node3D
		var root := get_tree().current_scene
		if root and vfx:
			root.add_child(vfx)
		elif get_parent() and vfx:
			get_parent().add_child(vfx)
		if vfx:
			vfx.global_position = global_position

func _spawn_doubloons() -> void:
	if not doubloon_scene or doubloons_drop <= 0:
		return
		
	var spawn_parent: Node = get_tree().current_scene
	if not spawn_parent or spawn_parent == self:
		spawn_parent = get_parent()
		if spawn_parent == self or spawn_parent is EnemyMob:
			return
			
	for i in range(doubloons_drop):
		var doubloon := doubloon_scene.instantiate() as CollectibleDoubloon
		if doubloon:
			spawn_parent.add_child(doubloon)
			doubloon.global_position = Vector3(global_position.x, 0.05, global_position.z)
			var scatter := Vector2(randf_range(-0.8, 0.8), randf_range(-0.8, 0.8))
			doubloon._trigger_spawn_bounce(scatter)

func _clean_shadow_nodes(node: Node) -> void:
	if not node:
		return
	var lower_name: String = str(node.name).to_lower()
	var is_shadow_node: bool = false
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
