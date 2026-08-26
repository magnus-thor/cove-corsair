class_name CollectibleDoubloon
extends Area3D

## Value added to the player's doubloon/score count
@export var value: int = 1

## Rotation speed in radians per second
@export var rotation_speed: float = 3.5

## Floating bobbing parameters on water
@export var bob_speed: float = 4.0
@export var bob_height: float = 0.08
@export var base_water_y: float = 0.3

## VFX scene spawned upon pickup
@export var pickup_vfx_scene: PackedScene = preload("res://prefabs/vfx/coin_pickup_vfx.tscn")

@onready var visual_container: Node3D = $Visuals

var _time: float = 0.0
var _is_collected: bool = false
var _is_bouncing: bool = false

func _ready() -> void:
	add_to_group("collectibles")
	add_to_group("doubloons")
	
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	
	_trigger_spawn_bounce()

## Triggers an initial upward arc when dropped from defeated mobs
func _trigger_spawn_bounce(horizontal_scatter: Vector2 = Vector2.ZERO) -> void:
	_is_bouncing = true
	var start_pos = global_position
	var target_y = base_water_y
	var peak_y = start_pos.y + randf_range(1.0, 1.8)
	
	var target_x = start_pos.x + horizontal_scatter.x
	var target_z = start_pos.z + horizontal_scatter.y
	
	var tween = create_tween().set_parallel(false)
	# Arc up
	tween.tween_property(self, "global_position:y", peak_y, 0.22).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	# Land onto water
	tween.tween_property(self, "global_position:y", target_y, 0.28).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BOUNCE)
	
	# Horizontal scatter tween
	if horizontal_scatter != Vector2.ZERO:
		var h_tween = create_tween().set_parallel(true)
		h_tween.tween_property(self, "global_position:x", target_x, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		h_tween.tween_property(self, "global_position:z", target_z, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	
	tween.finished.connect(func(): _is_bouncing = false)

func _physics_process(delta: float) -> void:
	_time += delta
	
	# Rotate continuously
	if visual_container:
		visual_container.rotate_y(rotation_speed * delta)
		
		# Water bobbing when not in the middle of a spawn bounce
		if not _is_bouncing:
			var bob_offset = sin(_time * bob_speed) * bob_height
			visual_container.position.y = bob_offset
			
	# Despawn if passed behind player
	var player = get_tree().get_first_node_in_group("player")
	var player_z = player.global_position.z if player else 0.0
	if global_position.z > (player_z + 12.0):
		queue_free()

func _on_area_entered(area: Area3D) -> void:
	if _is_collected:
		return
	var player = _find_player(area)
	if player:
		_collect(player)

func _on_body_entered(body: Node3D) -> void:
	if _is_collected:
		return
	var player = _find_player(body)
	if player:
		_collect(player)

func _find_player(node: Node) -> PlayerSwerve:
	if node is PlayerSwerve:
		return node
	if node.is_in_group("player"):
		return node as PlayerSwerve
	var parent = node.get_parent()
	if parent is PlayerSwerve:
		return parent
	if parent and parent.is_in_group("player"):
		return parent as PlayerSwerve
	return null

func _collect(player: PlayerSwerve) -> void:
	_is_collected = true
	
	GameState.add_doubloons(value)
	if player and player.has_method("add_doubloons"):
		player.add_doubloons(value)
		
	AudioManager.play_sfx("coin_pickups")
	_spawn_pickup_vfx()
	queue_free()

func _spawn_pickup_vfx() -> void:
	if pickup_vfx_scene:
		var vfx = pickup_vfx_scene.instantiate() as Node3D
		var root = get_tree().current_scene
		if root:
			root.add_child(vfx)
		elif get_parent():
			get_parent().add_child(vfx)
		vfx.global_position = global_position
