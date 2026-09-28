class_name BoardingCrewStation
extends Node3D

## Automated crew station that mounts an unlocked/equipped Shipyard crew member
## and runs their tactical behavior (Swarm bombs, rope sabotage, flame traps, or repair).

signal crew_action_triggered(crew_id: String, action_name: String, target_pos: Vector3)

@export var station_id: String = "bow" # "bow", "midship", "stern"
@export var assigned_zone: BoardingZone = null
@export var action_interval_sec: float = 3.5
@export var crew_scale: Vector3 = Vector3(0.55, 0.55, 0.55)

var crew_id: String = ""
var crew_role: String = "deckhand" # "bomber", "sniper", "tosser", "mechanic", "deckhand"
var action_timer: float = 0.0

@onready var deck_marker: Marker3D = (get_node_or_null("DeckMarker") as Marker3D)
@onready var model_container: Node3D = ($DeckMarker/ModelContainer if has_node("DeckMarker/ModelContainer") else get_node_or_null("ModelContainer")) as Node3D

const CREW_MODELS: Dictionary = {
	"monkey_bomber": "res://assets/models/user/crew/monkey_crew.glb",
	"skeleton_tosser": "res://assets/models/user/crew/skeleton_crew.glb",
	"grease_monkey": "res://assets/models/user/crew/artillery_grease__monkey.glb",
	"deckhand_sniper": "res://assets/models/user/crew/weapon_deckhand_sniper.glb"
}

func _ready() -> void:
	action_timer = randf_range(1.0, 2.5) # Stagger initial actions
	set_process(false) # Inactive until assigned equipped crew in setup_crew

func setup_crew(new_crew_id: String) -> void:
	crew_id = new_crew_id
	_resolve_crew_role()
	_load_crew_model()

func _resolve_crew_role() -> void:
	match crew_id:
		"monkey_bomber":
			crew_role = "bomber"
			action_interval_sec = 2.8
		"skeleton_tosser":
			crew_role = "tosser"
			action_interval_sec = 2.2
		"grease_monkey":
			crew_role = "mechanic"
			action_interval_sec = 3.0
		"deckhand_sniper":
			crew_role = "sniper"
			action_interval_sec = 3.5
		_:
			crew_role = "deckhand"
			action_interval_sec = 2.5

func _load_crew_model() -> void:
	if not is_instance_valid(model_container):
		return
		
	for child: Node in model_container.get_children():
		child.queue_free()
		
	if CREW_MODELS.has(crew_id):
		var glb_path: String = CREW_MODELS[crew_id] as String
		if ResourceLoader.exists(glb_path):
			var scene: PackedScene = load(glb_path) as PackedScene
			if scene:
				var inst: Node3D = scene.instantiate() as Node3D
				inst.scale = crew_scale
				model_container.add_child(inst)

func _process(delta: float) -> void:
	action_timer -= delta
	if action_timer <= 0.0:
		_execute_crew_behavior()
		action_timer = action_interval_sec

func _execute_crew_behavior() -> void:
	match crew_role:
		"bomber":
			_execute_bomber()
		"sniper":
			_execute_sniper()
		"tosser":
			_execute_tosser()
		"mechanic":
			_execute_mechanic()
		_:
			_execute_deckhand()

func _execute_bomber() -> void:
	# Lobs AoE bomb into any zone with infestation > 35% or active boarders
	var target_zone: BoardingZone = assigned_zone
	var zones: Array[Node] = get_tree().get_nodes_in_group("boarding_zone")
	var highest_infest: float = 0.0
	
	for z_node: Node in zones:
		var z: BoardingZone = z_node as BoardingZone
		if is_instance_valid(z) and z.current_infestation > highest_infest:
			highest_infest = z.current_infestation
			target_zone = z
			
	if is_instance_valid(target_zone) and (target_zone.current_infestation >= 35.0 or not target_zone.active_boarders.is_empty()):
		var blast_pos: Vector3 = target_zone.global_position
		for b: Node3D in target_zone.active_boarders:
			if is_instance_valid(b) and b is BoarderEnemy:
				(b as BoarderEnemy).take_damage(25.0) # High AoE damage
		crew_action_triggered.emit(crew_id, "cluster_bomb", blast_pos)

func _execute_sniper() -> void:
	# Snipe priority: highest health active enemy boarder on deck or plank
	var enemies: Array[Node] = get_tree().get_nodes_in_group("boarder")
	var target_enemy: BoarderEnemy = null
	var highest_hp: float = 0.0
	
	for e_node: Node in enemies:
		var enemy: BoarderEnemy = e_node as BoarderEnemy
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion() and not enemy.is_falling:
			if enemy.current_hp > highest_hp:
				highest_hp = enemy.current_hp
				target_enemy = enemy
				
	if is_instance_valid(target_enemy):
		target_enemy.take_damage(28.0)
		target_enemy.apply_stagger(0.35)
		crew_action_triggered.emit(crew_id, "sniper_shot", target_enemy.global_position)

func _execute_tosser() -> void:
	# Area denial: burns active boarders in assigned zone
	if is_instance_valid(assigned_zone) and not assigned_zone.active_boarders.is_empty():
		for b: Node3D in assigned_zone.active_boarders:
			if is_instance_valid(b) and b is BoarderEnemy:
				(b as BoarderEnemy).take_damage(15.0)
		crew_action_triggered.emit(crew_id, "fire_toss", assigned_zone.global_position)

func _execute_mechanic() -> void:
	# Rapid infestation clear and damage control
	if is_instance_valid(assigned_zone) and assigned_zone.current_infestation > 0.0:
		assigned_zone.force_set_infestation(assigned_zone.current_infestation - 20.0)
		crew_action_triggered.emit(crew_id, "repair_deck", assigned_zone.global_position)

func _execute_deckhand() -> void:
	# Standard single-target potshot at boarder
	if is_instance_valid(assigned_zone) and not assigned_zone.active_boarders.is_empty():
		var target: Node3D = assigned_zone.active_boarders[0]
		if is_instance_valid(target) and target is BoarderEnemy:
			(target as BoarderEnemy).take_damage(12.0)
			crew_action_triggered.emit("deckhand", "musket_shot", target.global_position)
