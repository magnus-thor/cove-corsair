class_name BoarderEnemy
extends CharacterBody3D

## Enemy crew unit capable of crossing boarding planks, marching down ship deck,
## driving zone infestation, or functioning in standalone/free-roam encounters.
## If they breach past the stern defense line, they trigger an encounter defeat.

signal died(enemy: BoarderEnemy)
signal reached_deck(enemy: BoarderEnemy, zone: BoardingZone)
signal breached_stern(enemy: BoarderEnemy)

enum BoarderState {
	CROSSING,
	ON_DECK,
	FREE_ROAM,
	FALLING,
	DEAD
}

const DEFAULT_ENEMY_MODEL_PATH: String = "res://assets/models/enemy/crew/frontline_pirate_walking.glb"
const FALLBACK_RAIDER_SCENE: String = "res://src/features/boarding/enemies/pirate_raider_visual.tscn"

static var _shared_anim_library: AnimationLibrary = null

static func _get_or_create_shared_anim_library() -> AnimationLibrary:
	if _shared_anim_library != null:
		return _shared_anim_library
		
	_shared_anim_library = AnimationLibrary.new()
	var anim_sources: Dictionary = {
		"Walking": ["res://assets/models/enemy/crew/frontline_pirate_walking.glb", "Walking", Animation.LOOP_LINEAR],
		"Running": ["res://assets/models/enemy/crew/frontline_pirate_running.glb", "Running", Animation.LOOP_LINEAR],
		"Attack": ["res://assets/models/enemy/crew/frontline_pirate_attack.glb", "Attack", Animation.LOOP_NONE],
		"Dead": ["res://assets/models/enemy/crew/frontline_pirate_dead.glb", "Dead", Animation.LOOP_NONE]
	}
	for anim_key: String in anim_sources:
		var src_path: String = anim_sources[anim_key][0] as String
		var src_name: String = anim_sources[anim_key][1] as String
		var loop_mode: Animation.LoopMode = anim_sources[anim_key][2] as Animation.LoopMode
		if ResourceLoader.exists(src_path):
			var scn: PackedScene = load(src_path) as PackedScene
			if scn:
				var inst: Node = scn.instantiate()
				var ap: AnimationPlayer = inst.find_child("*AnimationPlayer*", true, false) as AnimationPlayer
				if ap and ap.has_animation(src_name):
					var a: Animation = ap.get_animation(src_name).duplicate()
					a.loop_mode = loop_mode
					_shared_anim_library.add_animation(anim_key, a)
				inst.free()
	return _shared_anim_library

@export_group("Archetype & Stats")
@export var archetype_name: String = "Raider"
@export var max_hp: float = 25.0
@export var deck_wander_speed: float = 1.15
@export var cross_speed_mult: float = 1.0
@export var infestation_weight: float = 1.0
@export var start_on_deck: bool = false
@export var breach_z: float = 6.2
@export var attack_damage: float = 3.5
@export var attack_interval_sec: float = 1.35
@export var attack_sfx: String = "barrel_hits"

@export_group("Audio Feedback")
@export var impact_sfx: String = "barrel_hits"
@export var death_sfx: String = "barrel_breaks"

@export_group("Visuals")
@export var enemy_model_path: String = DEFAULT_ENEMY_MODEL_PATH
@export var model_scale: Vector3 = Vector3(0.24, 0.24, 0.24)

var current_hp: float = 25.0
var active_plank: BoardingPlank = null
var active_rope: BoardingPlank = null # Backward compatibility alias
var current_zone: BoardingZone = null

var current_state: BoarderState = BoarderState.CROSSING
var is_on_deck: bool = false
var is_falling: bool = false
var has_breached: bool = false

var is_dead: bool:
	get:
		return current_state == BoarderState.DEAD or current_hp <= 0.0 or is_falling

var stagger_timer: float = 0.0
var slow_timer: float = 0.0
var speed_mult: float = 1.0

var rope_progress: float = 0.0:
	set(val):
		rope_progress = val
		plank_progress = val
var plank_progress: float = 0.0

var _deck_wander_timer: float = 0.0
var _wander_dir: Vector3 = Vector3.ZERO
var _attack_timer: float = 0.0

@onready var model_container: Node3D = get_node_or_null("ModelContainer") as Node3D
var anim_player: AnimationPlayer = null

func _ready() -> void:
	add_to_group("boarder")
	add_to_group("enemies")
	current_hp = max_hp
	_load_visual_model()
	
	if start_on_deck:
		current_state = BoarderState.FREE_ROAM
		is_on_deck = true
		is_falling = false
		play_animation("Walking")

func _load_visual_model() -> void:
	if not is_instance_valid(model_container):
		return
		
	# Rotate model container 180 degrees so GLTF models face Godot -Z forward instead of backward
	model_container.rotation.y = PI
		
	# If a visual model is already instantiated as a child node, reuse and align it
	if model_container.get_child_count() > 0:
		var existing: Node3D = model_container.get_child(0) as Node3D
		if is_instance_valid(existing):
			existing.scale = model_scale
			_align_feet_to_ground(existing)
			_setup_anim_player(existing)
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
			_setup_anim_player(model)
			return

	# Fallback if glb is missing
	if model_container.get_child_count() == 0 and ResourceLoader.exists(FALLBACK_RAIDER_SCENE):
		var fallback_packed: PackedScene = load(FALLBACK_RAIDER_SCENE) as PackedScene
		if fallback_packed:
			var fallback_inst: Node3D = fallback_packed.instantiate() as Node3D
			model_container.add_child(fallback_inst)

func _setup_anim_player(model: Node3D) -> void:
	anim_player = model.find_child("*AnimationPlayer*", true, false) as AnimationPlayer
	if is_instance_valid(anim_player):
		var lib: AnimationLibrary = _get_or_create_shared_anim_library()
		if anim_player.has_animation_library(""):
			anim_player.remove_animation_library("")
		anim_player.add_animation_library("", lib)

func play_animation(anim_name: String, speed_scale: float = 1.0) -> void:
	if not is_instance_valid(anim_player):
		return
	if anim_player.has_animation(anim_name):
		if anim_player.current_animation != anim_name or not anim_player.is_playing():
			anim_player.play(anim_name, -1.0, speed_scale)

func _align_feet_to_ground(model: Node3D) -> void:
	model.position = Vector3.ZERO
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
	if found_mesh:
		model.position.y = -min_y

func _get_audio_manager() -> Node:
	if Engine.is_editor_hint():
		return null
	if Engine.has_singleton("AudioManager"):
		return Engine.get_singleton("AudioManager")
	var root_w: Window = get_tree().root if is_inside_tree() and get_tree() else null
	if root_w and root_w.has_node("AudioManager"):
		return root_w.get_node("AudioManager")
	return null

func start_crossing(plank: BoardingPlank, zone: BoardingZone) -> void:
	current_state = BoarderState.CROSSING
	active_plank = plank
	active_rope = plank
	current_zone = zone
	rope_progress = 0.0
	is_on_deck = false
	is_falling = false
	has_breached = false
	if is_instance_valid(plank):
		global_position = plank.get_point_along_plank(0.0)
		_orient_along_plank(plank)
	play_animation("Running", 1.0)

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
	has_breached = false
	play_animation("Walking", 1.0)
	if is_instance_valid(zone):
		current_state = BoarderState.ON_DECK
		zone.register_boarder(self)
		reached_deck.emit(self, zone)
	else:
		current_state = BoarderState.FREE_ROAM

func apply_stagger(duration: float = 0.22) -> void:
	stagger_timer = maxf(stagger_timer, duration)
	HitFlashComponent.flash_node(self, 0.08)

func apply_slow(factor: float = 0.25, duration: float = 5.0) -> void:
	speed_mult = factor
	slow_timer = maxf(slow_timer, duration)

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
	play_animation("Running", 1.0)
	
	if rope_progress >= 1.0:
		current_state = BoarderState.ON_DECK
		is_on_deck = true
		velocity = Vector3.ZERO
		play_animation("Walking", 1.0)
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

func _get_crew_target() -> Node3D:
	var crew_nodes: Array[Node] = get_tree().get_nodes_in_group("crew_defender")
	if not crew_nodes.is_empty() and is_instance_valid(crew_nodes[0]):
		return crew_nodes[0] as Node3D
	var player_nodes: Array[Node] = get_tree().get_nodes_in_group("player")
	for p: Node in player_nodes:
		if p is CharacterBody3D and is_instance_valid(p):
			return p as Node3D
	return null

func _process_deck_combat(delta: float) -> void:
	if has_breached:
		return
		
	# Stagger pauses march and attack
	if stagger_timer > 0.0:
		stagger_timer = maxf(stagger_timer - delta, 0.0)
		velocity = Vector3.ZERO
		move_and_slide()
		return
		
	# Slow recovery
	if slow_timer > 0.0:
		slow_timer = maxf(slow_timer - delta, 0.0)
		if slow_timer <= 0.0:
			speed_mult = 1.0
			
	var move_spd: float = deck_wander_speed * speed_mult
	var crew_target: Node3D = _get_crew_target()
	
	if is_instance_valid(crew_target):
		# Target and charge the crew member defending the vessel
		var to_crew: Vector3 = crew_target.global_position - global_position
		to_crew.y = 0.0
		var dist: float = to_crew.length()
		const ATTACK_RANGE: float = 1.35
		
		if dist > ATTACK_RANGE:
			var move_dir: Vector3 = to_crew.normalized()
			velocity = move_dir * move_spd
			move_and_slide()
			play_animation("Walking", 1.0)
			
			var look_target: Vector3 = global_position + move_dir
			if not global_position.is_equal_approx(look_target):
				look_at(look_target, Vector3.UP)
		else:
			# Melee range: stop and attack the crew defender!
			velocity = Vector3.ZERO
			var flat_crew: Vector3 = Vector3(crew_target.global_position.x, global_position.y, crew_target.global_position.z)
			if not global_position.is_equal_approx(flat_crew):
				look_at(flat_crew, Vector3.UP)
			play_animation("Attack", 1.2)
			
			_attack_timer -= delta
			if _attack_timer <= 0.0:
				_attack_timer = attack_interval_sec
				if crew_target.has_method("take_damage"):
					crew_target.call("take_damage", attack_damage)
				var audio: Node = _get_audio_manager()
				if audio and audio.has_method("play_sfx") and not attack_sfx.is_empty():
					audio.call("play_sfx", attack_sfx, 0.95, 1.15)
	else:
		# Fallback if no crew defender found: march toward Stern (+Z)
		var march_dir: Vector3 = Vector3(0.0, 0.0, 1.0)
		if is_instance_valid(current_zone) and is_instance_valid(current_zone.station_marker):
			var target_x: float = current_zone.station_marker.global_position.x
			var diff_x: float = target_x - global_position.x
			march_dir.x = clampf(diff_x * 0.4, -0.3, 0.3)
			march_dir = march_dir.normalized()
			
		velocity = march_dir * move_spd
		move_and_slide()
		play_animation("Walking", 1.0)
		
		var look_target: Vector3 = global_position + Vector3(march_dir.x * 0.25, 0.0, 1.0)
		if not global_position.is_equal_approx(look_target):
			look_at(look_target, Vector3.UP)
		
	# Check stern breach threshold (game over condition)
	if global_position.z >= breach_z:
		has_breached = true
		play_animation("Attack", 1.2)
		breached_stern.emit(self)

func _process_free_roam(delta: float) -> void:
	if stagger_timer > 0.0:
		stagger_timer = maxf(stagger_timer - delta, 0.0)
		velocity = Vector3.ZERO
		move_and_slide()
		return

	_deck_wander_timer -= delta
	if _deck_wander_timer <= 0.0:
		_deck_wander_timer = randf_range(1.5, 3.5)
		var angle: float = randf_range(0.0, TAU)
		_wander_dir = Vector3(cos(angle), 0.0, sin(angle)).normalized()

	velocity = _wander_dir * (deck_wander_speed * speed_mult)
	move_and_slide()
	play_animation("Walking", 1.0)

	var flat_vel: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	if flat_vel.length_squared() > 0.05:
		var look_pt: Vector3 = global_position + flat_vel
		if not global_position.is_equal_approx(look_pt):
			look_at(look_pt, Vector3.UP)

func take_damage(amount: float) -> void:
	if current_state == BoarderState.FALLING or current_state == BoarderState.DEAD or current_hp <= 0.0:
		return
	current_hp -= amount
	
	# Visual & Audio hit feedback + brief stagger
	apply_stagger(0.20)
	var audio_hit: Node = _get_audio_manager()
	if audio_hit and audio_hit.has_method("play_sfx") and not impact_sfx.is_empty():
		audio_hit.call("play_sfx", impact_sfx, 1.0, 1.25)
	_spawn_damage_text(int(round(amount)))
	
	if current_hp <= 0.0:
		die()

func die() -> void:
	if current_state == BoarderState.DEAD:
		return
	current_state = BoarderState.DEAD
	var audio_death: Node = _get_audio_manager()
	if audio_death and audio_death.has_method("play_sfx") and not death_sfx.is_empty():
		audio_death.call("play_sfx", death_sfx, 1.0, 1.2)
	if is_instance_valid(current_zone):
		current_zone.unregister_boarder(self)
	died.emit(self)
	
	if is_instance_valid(anim_player) and anim_player.has_animation("Dead") and not is_falling:
		velocity = Vector3.ZERO
		var col: CollisionShape3D = get_node_or_null("CollisionShape3D") as CollisionShape3D
		if is_instance_valid(col):
			col.set_deferred("disabled", true)
		play_animation("Dead", 1.2)
		var death_tw: Tween = create_tween()
		death_tw.tween_interval(1.4)
		if is_instance_valid(model_container):
			death_tw.tween_property(model_container, "scale", Vector3.ZERO, 0.3)
		else:
			death_tw.tween_property(self, "scale", Vector3(0.001, 0.001, 0.001), 0.3)
		death_tw.tween_callback(queue_free)
	else:
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
		var audio: Node = _get_audio_manager()
		if audio and audio.has_method("play_sfx"):
			audio.call("play_sfx", "water_splashes", 0.9, 1.1)
		queue_free()
	)

func _spawn_damage_text(dmg: int) -> void:
	var ft_script: GDScript = load("res://src/vfx/floating_text.gd") as GDScript
	if ft_script:
		var fct: Node3D = ft_script.new() as Node3D
		var root: Node = get_tree().current_scene
		if root and fct:
			root.add_child(fct)
			fct.global_position = global_position + Vector3(randf_range(-0.3, 0.3), 1.0, randf_range(-0.3, 0.3))
			if fct.has_method("setup"):
				fct.call("setup", "-%d" % dmg, Color(1.0, 0.3, 0.2))
