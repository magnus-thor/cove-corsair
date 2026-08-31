class_name BossBoneBeard
extends Area3D

enum State { APPROACHING, COMBAT, DYING }

@export var max_hp: int = 100
@export var current_hp: int = 100
@export var approach_speed: float = 14.0
@export var combat_z_offset: float = -18.0
@export var weave_speed: float = 1.8
@export var attack_interval: float = 2.5

@export var doubloon_scene: PackedScene = preload("res://src/gameplay/collectibles/collectible_doubloon.tscn")
@export var explosion_scene: PackedScene = preload("res://src/gameplay/vfx/barrel_explosion.tscn")
@export var powder_keg_scene: PackedScene = preload("res://src/gameplay/obstacles/destructible_barrel.tscn")

@onready var boss_sprite: Sprite3D = $BossSprite
@onready var health_bar_progress: ProgressBar = get_node_or_null("HealthBarViewport/HealthBarControl/VBoxContainer/ProgressBar")
@onready var health_title_label: Label = get_node_or_null("HealthBarViewport/HealthBarControl/VBoxContainer/BossTitleLabel")

var current_state: State = State.APPROACHING
var _flash_tween: Tween
var _attack_timer: float = 0.0
var _weave_time: float = 0.0
var _target_z: float = -18.0
var _is_defeated: bool = false
var _current_base_y: float = 2.612

func _ready() -> void:
	_clean_shadow_nodes(self)
	add_to_group("enemies")
	add_to_group("destructible")
	current_hp = max_hp
	_update_health_bar()
	area_entered.connect(_on_area_entered)
	
	var player = get_tree().get_first_node_in_group("player")
	var player_z = player.global_position.z if player else 0.0
	_target_z = player_z + combat_z_offset

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

func _perform_attack() -> void:
	var lanes = [-2.2, 0.0, 2.2]
	lanes.shuffle()
	
	for i in range(2):
		var spawn_x = lanes[i]
		if powder_keg_scene:
			var keg = powder_keg_scene.instantiate() as Node3D
			var root = get_tree().current_scene
			var spawn_parent = root if root else get_parent()
			if spawn_parent:
				spawn_parent.add_child(keg)
				keg.global_position = Vector3(spawn_x, 0.5, global_position.z + 2.5)
				if "forward_speed" in keg:
					keg.forward_speed = 6.0

func take_damage(amount: int) -> void:
	if _is_defeated or current_state == State.DYING:
		return

	current_hp = max(0, current_hp - amount)
	_update_health_bar()
	_flash_red()
	AudioManager.play_sfx("barrel_hits")

	if current_hp <= 0:
		boss_defeat()

func _flash_red() -> void:
	if not boss_sprite:
		return
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()

	_flash_tween = create_tween()
	_flash_tween.tween_property(boss_sprite, "modulate", Color(3.0, 0.2, 0.2, 1.0), 0.07)
	_flash_tween.tween_property(boss_sprite, "modulate", Color.WHITE, 0.12)

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
			
	var tween = create_tween()
	for i in range(7):
		tween.tween_callback(func():
			_spawn_hull_explosion()
			AudioManager.play_sfx("barrel_breaks")
		)
		tween.tween_interval(0.14)
		
	tween.tween_callback(func():
		_spawn_doubloon_fountain()
	)
	tween.tween_interval(1.5)
	tween.tween_callback(func():
		GameState.level_completed.emit(GameState.doubloons, GameState.targets_destroyed)
		queue_free()
	)

func _spawn_hull_explosion() -> void:
	if explosion_scene:
		var vfx = explosion_scene.instantiate() as Node3D
		var root = get_tree().current_scene
		if root:
			root.add_child(vfx)
			var offset = Vector3(randf_range(-2.2, 2.2), randf_range(0.3, 1.8), randf_range(-1.0, 1.0))
			vfx.global_position = global_position + offset

func _spawn_doubloon_fountain() -> void:
	if not doubloon_scene:
		return
	var spawn_parent = get_tree().current_scene
	if not spawn_parent or spawn_parent == self:
		spawn_parent = get_parent()
		if spawn_parent == self or spawn_parent is BossBoneBeard:
			return
		
	var count = randi_range(20, 30)
	for i in range(count):
		var d = doubloon_scene.instantiate() as Area3D
		if d:
			spawn_parent.add_child(d)
			d.global_position = Vector3(global_position.x, 0.05, global_position.z)
			var scatter = Vector2(randf_range(-3.0, 3.0), randf_range(-3.0, 3.0))
			if d.has_method("_trigger_spawn_bounce"):
				d._trigger_spawn_bounce(scatter)

func _on_area_entered(area: Area3D) -> void:
	if _is_defeated or current_state == State.DYING:
		return
	if area.is_in_group("player") or (area.get_parent() and area.get_parent().is_in_group("player")):
		var player = get_tree().get_first_node_in_group("player")
		if player and "current_health" in player:
			player.current_health -= 1
			if player.has_signal("health_changed"):
				player.health_changed.emit(player.current_health, player.max_health)
			if player.current_health <= 0 and player.has_method("game_over"):
				player.game_over(false)

func _clean_shadow_nodes(node: Node) -> void:
	if not node:
		return
	var lower_name = node.name.to_lower()
	var is_shadow_node = false
	if "shadow" in lower_name or "decal" in lower_name or "projector" in lower_name or "card" in lower_name or "oblate" in lower_name or "shadow_sphere" in lower_name or "sphere_shadow" in lower_name:
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
