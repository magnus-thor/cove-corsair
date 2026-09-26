class_name BoarderEnemy
extends CharacterBody3D

## Swarmer enemy unit that traverses a grappling rope, lands in a ship zone,
## drives zone infestation, and falls overboard if their rope is cut.

signal died(enemy: BoarderEnemy)
signal reached_deck(enemy: BoarderEnemy, zone: BoardingZone)

@export var max_hp: float = 25.0
@export var deck_wander_speed: float = 2.5

var current_hp: float = 25.0
var active_plank: BoardingPlank = null
var active_rope: BoardingPlank = null # Backward compatibility alias
var current_zone: BoardingZone = null
var rope_progress: float = 0.0:
	set(val):
		rope_progress = val
		plank_progress = val
var plank_progress: float = 0.0
var is_on_deck: bool = false
var is_falling: bool = false

var _deck_wander_timer: float = 0.0
var _wander_dir: Vector3 = Vector3.ZERO

@onready var model_container: Node3D = $ModelContainer
@onready var placeholder_mesh: MeshInstance3D = $MeshInstance3D

const ENEMY_MODEL_PATH: String = "res://assets/models/user/crew/skeleton_crew.glb"

func _ready() -> void:
	add_to_group("boarder")
	add_to_group("enemies")
	current_hp = max_hp
	_load_visual_model()

func _load_visual_model() -> void:
	if ResourceLoader.exists(ENEMY_MODEL_PATH):
		var scene: PackedScene = load(ENEMY_MODEL_PATH) as PackedScene
		if scene and is_instance_valid(model_container):
			var model: Node3D = scene.instantiate() as Node3D
			model.scale = Vector3(0.5, 0.5, 0.5)
			model_container.add_child(model)
			if is_instance_valid(placeholder_mesh):
				placeholder_mesh.visible = false

func start_crossing(plank: BoardingPlank, zone: BoardingZone) -> void:
	active_plank = plank
	active_rope = plank
	current_zone = zone
	rope_progress = 0.0
	is_on_deck = false
	is_falling = false
	if is_instance_valid(plank):
		global_position = plank.get_point_along_plank(0.0)

func start_climbing(rope: BoardingPlank, zone: BoardingZone) -> void:
	start_crossing(rope, zone)

func _physics_process(delta: float) -> void:
	if is_falling:
		return
		
	if not is_on_deck:
		_process_climbing(delta)
	else:
		_process_deck_combat(delta)

func _process_crossing(delta: float) -> void:
	_process_climbing(delta)

func _process_climbing(delta: float) -> void:
	var plank: BoardingPlank = active_plank if is_instance_valid(active_plank) else active_rope
	if not is_instance_valid(plank) or not plank.is_latched:
		_fall_overboard()
		return
		
	var duration: float = maxf(plank.cross_duration_sec, 0.1)
	rope_progress += delta / duration
	global_position = plank.get_point_along_plank(rope_progress)
	
	if rope_progress >= 1.0:
		is_on_deck = true
		velocity = Vector3.ZERO
		if is_instance_valid(current_zone):
			current_zone.register_boarder(self)
			reached_deck.emit(self, current_zone)

func _process_deck_combat(delta: float) -> void:
	_deck_wander_timer -= delta
	if _deck_wander_timer <= 0.0:
		_deck_wander_timer = randf_range(1.0, 2.5)
		var angle: float = randf_range(0.0, TAU)
		_wander_dir = Vector3(cos(angle), 0.0, sin(angle)).normalized()
	
	# Stay anchored around zone area
	if is_instance_valid(current_zone) and is_instance_valid(current_zone.station_marker):
		var to_zone: Vector3 = current_zone.station_marker.global_position - global_position
		if to_zone.length() > 3.0:
			_wander_dir = to_zone.normalized()
			
	velocity = _wander_dir * deck_wander_speed
	move_and_slide()
	
	var flat_vel: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	if flat_vel.length_squared() > 0.05:
		var look_pt: Vector3 = global_position + flat_vel
		if not global_position.is_equal_approx(look_pt):
			look_at(look_pt, Vector3.UP)

func take_damage(amount: float) -> void:
	if is_falling or current_hp <= 0.0:
		return
	current_hp -= amount
	
	# Visual & Audio hit feedback
	HitFlashComponent.flash_node(self, 0.08)
	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("barrel_hits", 1.0, 1.25)
	_spawn_damage_text(int(round(amount)))
	
	if current_hp <= 0.0:
		die()

func die() -> void:
	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("barrel_breaks", 1.0, 1.2)
	if is_instance_valid(current_zone):
		current_zone.unregister_boarder(self)
	died.emit(self)
	queue_free()

func _fall_overboard() -> void:
	if is_falling:
		return
	is_falling = true
	set_physics_process(false)
	
	if is_instance_valid(current_zone):
		current_zone.unregister_boarder(self)
		
	var fall_tween: Tween = create_tween()
	var target_y: float = global_position.y - 4.5
	fall_tween.tween_property(self, "global_position:y", target_y, 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall_tween.parallel().tween_property(self, "rotation:z", 1.8, 0.65)
	fall_tween.tween_callback(func() -> void:
		if AudioManager and AudioManager.has_method("play_sfx"):
			AudioManager.play_sfx("water_splashes", 0.9, 1.1)
		queue_free()
	)

func _spawn_damage_text(dmg: int) -> void:
	var ft_script: GDScript = load("res://src/vfx/floating_text.gd") as GDScript
	if ft_script:
		var fct: Node3D = ft_script.new() as Node3D
		var root: Node = get_tree().current_scene
		if root and fct:
			root.add_child(fct)
			fct.global_position = global_position + Vector3(randf_range(-0.3, 0.3), 1.2, randf_range(-0.3, 0.3))
			if fct.has_method("setup"):
				fct.call("setup", "-%d" % dmg, Color(1.0, 0.3, 0.2))
