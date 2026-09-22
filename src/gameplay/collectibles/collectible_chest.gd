class_name CollectibleChest
extends Area3D

## 3D Treasure Chest Pickup
## Features 3D chest model, gentle floating waterline bobbing & spin,
## upward coin burst VFX, rising billboard gold Label3D popup, and economy reward.

@export var chest_value: int = 25
@export var rotation_speed: float = 1.5
@export var bob_speed: float = 2.5
@export var bob_height: float = 0.04
@export var base_water_y: float = 0.05
@export var magnet_pull_speed: float = 22.0

var _time: float = 0.0
var _is_collected: bool = false
var _is_attracted: bool = false
var _target_attractor: Node3D = null

func _ready() -> void:
	add_to_group("collectibles")
	collision_layer = 8
	collision_mask = 1
	set_deferred("monitoring", true)
	set_deferred("monitorable", true)
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	global_position.y = base_water_y

func attract_to(target: Node3D) -> void:
	if _is_collected:
		return
	_is_attracted = true
	_target_attractor = target

func _physics_process(delta: float) -> void:
	if _is_collected or not GameState.is_game_active:
		return
		
	_time += delta
	
	# Gentle floating spin
	rotation.y += rotation_speed * delta
	
	if _is_attracted and _target_attractor and is_instance_valid(_target_attractor):
		var target_pos = _target_attractor.global_position
		global_position = global_position.move_toward(target_pos, magnet_pull_speed * delta)
		if global_position.distance_to(target_pos) < 1.0:
			collect_chest()
	else:
		var flow = 12.0
		var track_mgr = get_tree().get_first_node_in_group("track_manager")
		if track_mgr and "scroll_speed" in track_mgr:
			flow = track_mgr.scroll_speed
		global_position.z += flow * delta
		
		global_position.y = base_water_y + sin(_time * bob_speed) * bob_height

	var player = get_tree().get_first_node_in_group("player")
	var player_z = player.global_position.z if player else 0.0
	if global_position.z > (player_z + 12.0):
		queue_free()

func _on_area_entered(area: Area3D) -> void:
	if _is_player_node(area):
		collect_chest()

func _on_body_entered(body: Node3D) -> void:
	if _is_player_node(body):
		collect_chest()

func _is_player_node(node: Node) -> bool:
	if not node:
		return false
	if node.is_in_group("player") or (node.get_parent() and node.get_parent().is_in_group("player")):
		return true
	return false

func collect_chest() -> void:
	if _is_collected:
		return
	_is_collected = true
	
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	for child in get_children():
		if child is CollisionShape3D:
			child.set_deferred("disabled", true)
			
	var visual_node = get_node_or_null("Visuals")
	if visual_node:
		visual_node.visible = false
		
	var spawn_pos = global_position
	
	# 1. Golden coin burst erupting upward
	if VFXManager and VFXManager.has_method("spawn_coin_burst"):
		VFXManager.spawn_coin_burst(spawn_pos)
		
	# 2. Floating Label3D billboard score text (+XX GOLD)
	_spawn_floating_score_label(spawn_pos, chest_value)
	
	# 3. Audio SFX (pitch 1.25)
	AudioManager.play_sfx("coin_pickups", 1.25, 1.25)
	
	# 4. Economy reward
	if GameState:
		GameState.add_doubloons(chest_value, "chest")
	var player := get_tree().get_first_node_in_group("player") as Node
	if player and player.has_method("add_doubloons"):
		player.call("add_doubloons", chest_value)

		
	# Give short window for tween/sounds then queue_free
	await get_tree().create_timer(0.75, false).timeout
	queue_free()

func _spawn_floating_score_label(pos: Vector3, amount: int) -> void:
	var label = Label3D.new()
	var font_file = load("res://assets/fonts/CarterOne.ttf")
	if font_file:
		label.font = font_file
	label.text = "+%d GOLD" % amount
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 48
	# Radiant Gold (#F5D061)
	label.modulate = Color("f5d061")
	label.outline_render_priority = 1
	label.outline_size = 12
	label.outline_modulate = Color(0.12, 0.08, 0.04, 1.0)
		
	var root = get_tree().current_scene
	if not root:
		root = get_tree().root
	root.add_child(label)
	
	var start_pos = pos + Vector3(0, 0.5, 0)
	label.global_position = start_pos
	label.scale = Vector3(0.7, 0.7, 0.7)
	
	var tween = label.create_tween().set_parallel(true)
	tween.tween_property(label, "global_position:y", start_pos.y + 1.8, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector3(1.35, 1.35, 1.35), 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(label.queue_free)
