class_name CollectibleDoubloon
extends Area3D

## Value added to the player's doubloon count
@export var value: int = 1

## Rotation / spin speed
@export var rotation_speed: float = 3.5

## Floating bobbing parameters on water
@export var bob_speed: float = 3.5
@export var bob_height: float = 0.02
@export var base_water_y: float = 0.13

## Default river flow downstream speed when floating free
@export var river_flow_speed: float = 14.0

## Speed at which coin flies towards magnet attractor
@export var magnet_pull_speed: float = 22.0

## VFX scene spawned upon pickup
@export var pickup_vfx_scene: PackedScene = preload("res://src/gameplay/vfx/coin_pickup_vfx.tscn")

@onready var visual_container: Node3D = $Visuals

var _time: float = 0.0
var _is_collected: bool = false
var _is_bouncing: bool = false
var _is_attracted: bool = false
var _target_attractor: Node3D = null

func _ready() -> void:
	add_to_group("collectibles")
	add_to_group("doubloons")
	
	# Layer 4 (8), Mask 1 (1)
	collision_layer = 8
	collision_mask = 1
	monitoring = true
	monitorable = true
	
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	
	# Apply water calibration values
	var coin_sprite = get_node_or_null("Visuals/CoinSprite") as Sprite3D
	if coin_sprite:
		coin_sprite.pixel_size = 0.0042
	scale = Vector3(3.00, 3.00, 3.00)
	
	if not _is_bouncing:
		global_position.y = base_water_y

## Called by player magnet area to start magnetic pulling towards player boat
func attract_to(target: Node3D) -> void:
	if _is_collected:
		return
	_is_attracted = true
	_target_attractor = target

## Triggers an initial upward arc and horizontal scatter when dropped from defeated mobs/barrels
func _trigger_spawn_bounce(horizontal_scatter: Vector2 = Vector2.ZERO) -> void:
	_is_bouncing = true
	var start_pos = global_position
	var target_y = base_water_y
	var peak_y = base_water_y + randf_range(0.8, 1.4)
	
	var target_x = start_pos.x + horizontal_scatter.x
	var target_z = start_pos.z + horizontal_scatter.y
	
	var tween = create_tween().set_parallel(false)
	# Arc up
	tween.tween_property(self, "global_position:y", peak_y, 0.20).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	# Land onto water surface
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
		# Magnetic attraction: pull directly towards target attractor
		var target_pos = _target_attractor.global_position
		global_position = global_position.move_toward(target_pos, magnet_pull_speed * delta)
		
		var dist = global_position.distance_to(target_pos)
		if dist < 1.0:
			collect_coin(_target_attractor)
			return
	else:
		# Free floating: move downstream with river current (+Z direction) so coins do not freeze
		var flow = river_flow_speed
		var track_mgr = get_tree().get_first_node_in_group("track_manager")
		if track_mgr and "scroll_speed" in track_mgr:
			flow = track_mgr.scroll_speed
		
		global_position.z += flow * delta
		
		if not _is_bouncing:
			global_position.y = base_water_y
			if visual_container:
				visual_container.position.y = sin(_time * bob_speed) * bob_height

	# Despawn if passed beyond player
	var player = get_tree().get_first_node_in_group("player")
	var player_z = player.global_position.z if player else 0.0
	if global_position.z > (player_z + 12.0):
		queue_free()

func _on_area_entered(area: Area3D) -> void:
	if _is_collected or not GameState.is_game_active:
		return
	if _is_player_node(area):
		collect_coin(area)

func _on_body_entered(body: Node3D) -> void:
	if _is_collected or not GameState.is_game_active:
		return
	if _is_player_node(body):
		collect_coin(body)

func _is_player_node(node: Node) -> bool:
	if not node:
		return false
	if node.is_in_group("player"):
		return true
	var parent = node.get_parent()
	if parent and parent.is_in_group("player"):
		return true
	return false

func collect_coin(player_ref: Node = null) -> void:
	if _is_collected:
		return
	_is_collected = true
	
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	for child in get_children():
		if child is CollisionShape3D:
			child.set_deferred("disabled", true)
			
	GameState.add_doubloons(value)
	
	var player = get_tree().get_first_node_in_group("player")
	if player:
		if player.has_method("add_doubloons"):
			player.add_doubloons(value)
		# NOTE: Doubloons are currency only — they do NOT award XP.
		# XP is awarded solely on enemy/obstacle kills via die().
		
	AudioManager.play_sfx("coin_pickups")
	_spawn_pickup_vfx()
	queue_free()

func _spawn_pickup_vfx() -> void:
	if pickup_vfx_scene:
		var vfx = pickup_vfx_scene.instantiate() as Node3D
		var root = get_tree().current_scene
		var parent = root if root else get_parent()
		if parent:
			parent.add_child(vfx)
			vfx.global_position = global_position
