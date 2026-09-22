class_name CollectibleXpOrb
extends Area3D

@export var value: float = 15.0
@export var rotation_speed: float = 3.5
@export var bob_speed: float = 3.5
@export var bob_height: float = 0.02
@export var base_water_y: float = 0.46
@export var river_flow_speed: float = 14.0
@export var magnet_pull_speed: float = 24.0

var _time: float = 0.0
var _is_collected: bool = false
var _is_bouncing: bool = false
var _is_attracted: bool = false
var _target_attractor: Node3D = null

func _ready() -> void:
	add_to_group("collectibles")
	add_to_group("xp_orbs")
	
	collision_layer = 8
	collision_mask = 1
	set_deferred("monitoring", true)
	set_deferred("monitorable", true)
	
	# Create CollisionShape3D dynamically
	var col_shape = CollisionShape3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = 0.8
	col_shape.shape = sphere
	add_child(col_shape)
	
	# Create Visuals node dynamically
	var visuals_node = Node3D.new()
	visuals_node.name = "Visuals"
	add_child(visuals_node)
	
	# Create Sprite3D dynamically
	var sprite = Sprite3D.new()
	sprite.name = "XpSprite"
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.texture = preload("res://assets/sprites/ui/coin_icon.svg")
	sprite.modulate = Color(0.2, 1.0, 0.2) # bright green
	sprite.pixel_size = 0.0021
	visuals_node.add_child(sprite)
	
	scale = Vector3(3.0, 3.0, 3.0)
	
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	
	if not _is_bouncing:
		global_position.y = base_water_y

func attract_to(target: Node3D) -> void:
	if _is_collected:
		return
	_is_attracted = true
	_target_attractor = target

func _trigger_spawn_bounce(horizontal_scatter: Vector2 = Vector2.ZERO) -> void:
	_is_bouncing = true
	var start_pos = global_position
	var target_y = base_water_y
	var peak_y = base_water_y + randf_range(0.8, 1.4)
	
	var target_x = start_pos.x + horizontal_scatter.x
	var target_z = start_pos.z + horizontal_scatter.y
	
	var tween = create_tween().set_parallel(false)
	tween.tween_property(self, "global_position:y", peak_y, 0.20).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "global_position:y", target_y, 0.25).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BOUNCE)
	
	if horizontal_scatter != Vector2.ZERO:
		var h_tween = create_tween().set_parallel(true)
		h_tween.tween_property(self, "global_position:x", target_x, 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		h_tween.tween_property(self, "global_position:z", target_z, 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	
	tween.finished.connect(func():
		_is_bouncing = false
		global_position.y = base_water_y
	)

func _physics_process(delta: float) -> void:
	if _is_collected or not GameState.is_game_active:
		return
		
	_time += delta
	
	if _is_attracted and _target_attractor and is_instance_valid(_target_attractor):
		var target_pos = _target_attractor.global_position
		global_position = global_position.move_toward(target_pos, magnet_pull_speed * delta)
		
		var dist = global_position.distance_to(target_pos)
		if dist < 1.0:
			collect_orb(_target_attractor)
			return
	else:
		var flow = river_flow_speed
		var track_mgr = get_tree().get_first_node_in_group("track_manager")
		if track_mgr and "scroll_speed" in track_mgr:
			flow = track_mgr.scroll_speed
		
		global_position.z += flow * delta
		
		if not _is_bouncing:
			global_position.y = base_water_y
			var visuals_node = get_node_or_null("Visuals")
			if visuals_node:
				visuals_node.position.y = sin(_time * bob_speed) * bob_height

	var player = get_tree().get_first_node_in_group("player")
	var player_z = player.global_position.z if player else 0.0
	if global_position.z > (player_z + 12.0):
		queue_free()

func _on_area_entered(area: Area3D) -> void:
	if _is_collected or not GameState.is_game_active:
		return
	if _is_player_node(area):
		collect_orb(area)

func _on_body_entered(body: Node3D) -> void:
	if _is_collected or not GameState.is_game_active:
		return
	if _is_player_node(body):
		collect_orb(body)

func _is_player_node(node: Node) -> bool:
	if not node:
		return false
	if node.is_in_group("player"):
		return true
	var parent = node.get_parent()
	if parent and parent.is_in_group("player"):
		return true
	return false

func collect_orb(_player_ref: Node = null) -> void:
	if _is_collected:
		return
	_is_collected = true
	
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	for child in get_children():
		if child is CollisionShape3D:
			child.set_deferred("disabled", true)
			
	var player = get_tree().get_first_node_in_group("player")
	if player:
		if player.has_method("add_doubloons"):
			player.add_doubloons(int(value))
		if player.has_method("spawn_floating_text_at_position"):
			player.spawn_floating_text_at_position("+" + str(int(value)) + " COINS", Color(1.0, 0.85, 0.2))
	if GameState:
		GameState.add_doubloons(int(value), "xp_orb")

		
	AudioManager.play_sfx("coin_pickups")
	queue_free()
