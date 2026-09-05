class_name CollectibleChest
extends Area3D

@export var rotation_speed: float = 2.5
@export var bob_speed: float = 2.5
@export var bob_height: float = 0.05
@export var base_water_y: float = 0.17
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
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	global_position.y = base_water_y
	
	scale = Vector3(0.96, 0.96, 0.96)

func attract_to(target: Node3D) -> void:
	if _is_collected:
		return
	_is_attracted = true
	_target_attractor = target

func _physics_process(delta: float) -> void:
	if _is_collected or not GameState.is_game_active:
		return
		
	_time += delta
	
	# Spin
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
	if not node: return false
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
			
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("add_doubloons"):
		player.add_doubloons(25)
	if GameState:
		GameState.add_doubloons(25)
		
	AudioManager.play_sfx("coin_pickups")
	queue_free()
