class_name BoarderEnemy
extends CharacterBody3D

## Enemy crew unit capable of crossing boarding planks, fighting on deck,
## driving zone infestation, or functioning in standalone/free-roam encounters.

signal died(enemy: BoarderEnemy)
signal reached_deck(enemy: BoarderEnemy, zone: BoardingZone)

enum BoarderState {
	CROSSING,
	ON_DECK,
	FREE_ROAM,
	FALLING,
	DEAD
}

const DEFAULT_ENEMY_MODEL_PATH: String = "res://assets/models/enemy/crew/frontline_pirate.glb"
const FALLBACK_RAIDER_SCENE: String = "res://src/features/boarding/enemies/pirate_raider_visual.tscn"

@export_group("Archetype & Stats")
@export var archetype_name: String = "Raider"
@export var max_hp: float = 25.0
@export var deck_wander_speed: float = 2.5
@export var cross_speed_mult: float = 1.0
@export var infestation_weight: float = 1.0
@export var start_on_deck: bool = false

@export_group("Audio Feedback")
@export var impact_sfx: String = "barrel_hits"
@export var death_sfx: String = "barrel_breaks"

@export_group("Visuals")
@export var enemy_model_path: String = DEFAULT_ENEMY_MODEL_PATH
@export var model_scale: Vector3 = Vector3(0.55, 0.55, 0.55)

var current_hp: float = 25.0
var active_plank: BoardingPlank = null
var active_rope: BoardingPlank = null # Backward compatibility alias
var current_zone: BoardingZone = null

var current_state: BoarderState = BoarderState.CROSSING
var is_on_deck: bool = false
var is_falling: bool = false

var rope_progress: float = 0.0:
	set(val):
		rope_progress = val
		plank_progress = val
var plank_progress: float = 0.0

var _deck_wander_timer: float = 0.0
var _wander_dir: Vector3 = Vector3.ZERO

@onready var model_container: Node3D = $ModelContainer

func _ready() -> void:
	add_to_group("boarder")
	add_to_group("enemies")
	current_hp = max_hp
	_load_visual_model()
	
	if start_on_deck:
		current_state = BoarderState.FREE_ROAM
		is_on_deck = true
		is_falling = false

func _load_visual_model() -> void:
	if not is_instance_valid(model_container):
		return
		
	# If a visual model is already instantiated as a child node (e.g. in an inherited scene or custom prefab),
	# reuse it directly, apply scaling, and align feet without tearing it down.
	if model_container.get_child_count() > 0:
		var existing: Node3D = model_container.get_child(0) as Node3D
		if is_instance_valid(existing):
			existing.scale = model_scale
			_align_feet_to_ground(existing)
			return

	var path_to_load: String = enemy_model_path
	if path_to_load.is_empty() or not ResourceLoader.exists(path_to_load):
		path_to_load = DEFAULT_ENEMY_MODEL_PATH
		
	if ResourceLoader.exists(path_to_load):
		for child: Node in model_container.get_children():
			child.queue_free()
		var scene: PackedScene = load(path_to_load) as PackedScene
		if scene:
			var model: Node3D = scene.instantiate() as Node3D
			model.scale = model_scale
			model_container.add_child(model)
			_align_feet_to_ground(model)
			return

	# Fallback if glb is missing
	if model_container.get_child_count() == 0 and ResourceLoader.exists(FALLBACK_RAIDER_SCENE):
		var fallback_packed: PackedScene = load(FALLBACK_RAIDER_SCENE) as PackedScene
		if fallback_packed:
			var fallback_inst: Node3D = fallback_packed.instantiate() as Node3D
			model_container.add_child(fallback_inst)

func _align_feet_to_ground(model: Node3D) -> void:
	var min_y: float = 0.0
	var found_mesh: bool = false
	var meshes: Array[Node] = model.find_children("*", "MeshInstance3D", true, false)
	for m_node: Node in meshes:
		var mi: MeshInstance3D = m_node as MeshInstance3D
		if is_instance_valid(mi) and mi.mesh:
			var aabb: AABB = mi.mesh.get_aabb()
			var local_min: float = (mi.position.y + aabb.position.y) * model.scale.y
			if not found_mesh or local_min < min_y:
				min_y = local_min
				found_mesh = true
	if found_mesh and min_y < 0.0:
		model.position.y = -min_y

func start_crossing(plank: BoardingPlank, zone: BoardingZone) -> void:
	current_state = BoarderState.CROSSING
	active_plank = plank
	active_rope = plank
	current_zone = zone
	rope_progress = 0.0
	is_on_deck = false
	is_falling = false
	if is_instance_valid(plank):
		global_position = plank.get_point_along_plank(0.0)
		_orient_along_plank(plank)

func start_climbing(rope: BoardingPlank, zone: BoardingZone) -> void:
	start_crossing(rope, zone)

func spawn_on_deck(deck_pos: Vector3, zone: BoardingZone = null) -> void:
	global_position = deck_pos
	active_plank = null
	active_rope = null
	rope_progress = 1.0
	current_zone = zone
	is_falling = false
	is_on_deck = true
	if is_instance_valid(zone):
		current_state = BoarderState.ON_DECK
		zone.register_boarder(self)
		reached_deck.emit(self, zone)
	else:
		current_state = BoarderState.FREE_ROAM

func _physics_process(delta: float) -> void:
	match current_state:
		BoarderState.FALLING, BoarderState.DEAD:
			return
		BoarderState.CROSSING:
			_process_climbing(delta)
		BoarderState.ON_DECK:
			_process_deck_combat(delta)
		BoarderState.FREE_ROAM:
			_process_free_roam(delta)

func _process_crossing(delta: float) -> void:
	_process_climbing(delta)

func _process_climbing(delta: float) -> void:
	var plank: BoardingPlank = active_plank if is_instance_valid(active_plank) else active_rope
	if not is_instance_valid(plank) or not plank.is_latched:
		_fall_overboard()
		return
		
	var base_dur: float = plank.cross_duration_sec
	var duration: float = maxf(base_dur / maxf(cross_speed_mult, 0.1), 0.1)
	rope_progress += delta / duration
	global_position = plank.get_point_along_plank(rope_progress)
	_orient_along_plank(plank)

	# Dynamic running stride bobbing while crossing
	if is_instance_valid(model_container):
		model_container.position.y = absf(sin(rope_progress * PI * 14.0)) * 0.04
	
	if rope_progress >= 1.0:
		current_state = BoarderState.ON_DECK
		is_on_deck = true
		velocity = Vector3.ZERO
		if is_instance_valid(model_container):
			model_container.position.y = 0.0
		if is_instance_valid(current_zone):
			current_zone.register_boarder(self)
			reached_deck.emit(self, current_zone)

func _orient_along_plank(plank: BoardingPlank) -> void:
	if not is_instance_valid(plank):
		return
	var forward_dir: Vector3 = plank.target_pos - plank.origin_pos
	forward_dir.y = 0.0
	if forward_dir.length_squared() > 0.001:
		var look_target: Vector3 = global_position + forward_dir.normalized()
		if not global_position.is_equal_approx(look_target):
			look_at(look_target, Vector3.UP)

func _process_deck_combat(delta: float) -> void:
	_deck_wander_timer -= delta
	if _deck_wander_timer <= 0.0:
		_deck_wander_timer = randf_range(1.0, 2.5)
		var angle: float = randf_range(0.0, TAU)
		_wander_dir = Vector3(cos(angle), 0.0, sin(angle)).normalized()
	
	# Stay anchored around zone area if assigned
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

func _process_free_roam(delta: float) -> void:
	_deck_wander_timer -= delta
	if _deck_wander_timer <= 0.0:
		_deck_wander_timer = randf_range(1.5, 3.5)
		var angle: float = randf_range(0.0, TAU)
		_wander_dir = Vector3(cos(angle), 0.0, sin(angle)).normalized()

	velocity = _wander_dir * deck_wander_speed
	move_and_slide()

	var flat_vel: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	if flat_vel.length_squared() > 0.05:
		var look_pt: Vector3 = global_position + flat_vel
		if not global_position.is_equal_approx(look_pt):
			look_at(look_pt, Vector3.UP)

func take_damage(amount: float) -> void:
	if current_state == BoarderState.FALLING or current_state == BoarderState.DEAD or current_hp <= 0.0:
		return
	current_hp -= amount
	
	# Visual & Audio hit feedback
	HitFlashComponent.flash_node(self, 0.08)
	if AudioManager and AudioManager.has_method("play_sfx") and not impact_sfx.is_empty():
		AudioManager.play_sfx(impact_sfx, 1.0, 1.25)
	_spawn_damage_text(int(round(amount)))
	
	if current_hp <= 0.0:
		die()

func die() -> void:
	if current_state == BoarderState.DEAD:
		return
	current_state = BoarderState.DEAD
	if AudioManager and AudioManager.has_method("play_sfx") and not death_sfx.is_empty():
		AudioManager.play_sfx(death_sfx, 1.0, 1.2)
	if is_instance_valid(current_zone):
		current_zone.unregister_boarder(self)
	died.emit(self)
	queue_free()

func _fall_overboard() -> void:
	if current_state == BoarderState.FALLING or current_state == BoarderState.DEAD:
		return
	current_state = BoarderState.FALLING
	is_falling = true
	is_on_deck = false
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
