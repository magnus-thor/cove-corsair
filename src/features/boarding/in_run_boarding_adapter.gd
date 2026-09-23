class_name InRunBoardingAdapter
extends Node

## Adapts the 3-Zone Deck Defense system to in-run boss fights and endless mode.
## Pauses runner scrolling, transitions camera, spawns grapple waves,
## and triggers boss defeat upon deck clearance.

signal boarding_started(boss_name: String)
signal boarding_completed(boss: Node3D)

const ARENA_SCENE: PackedScene = preload("res://src/features/boarding/boarding_defense_arena.tscn")

var active_arena: BoardingDefenseArena = null
var active_boss: Node3D = null
var active_player: Node3D = null

func start_in_run_boarding(boss: Node3D, player: Node3D) -> void:
	if not is_instance_valid(boss) or not is_instance_valid(player):
		return
		
	active_boss = boss
	active_player = player
	
	# Disable boss forward attacks while boarding
	if "current_state" in boss:
		boss.set("current_state", 1) # Combat state lock
	if "is_barrage_active" in boss:
		boss.set("is_barrage_active", false)
		
	# Instantiate Boarding Defense Arena
	active_arena = ARENA_SCENE.instantiate() as BoardingDefenseArena
	var root: Node = get_tree().current_scene
	if not root:
		root = player.get_parent()
		
	root.add_child(active_arena)
	active_arena.global_position = player.global_position
	
	# Connect encounter completion
	active_arena.encounter_won.connect(_on_arena_won)
	active_arena.encounter_lost.connect(_on_arena_lost)
	
	boarding_started.emit(boss.name)

func _on_arena_won() -> void:
	var boss: Node3D = active_boss
	if is_instance_valid(active_arena):
		active_arena.queue_free()
		active_arena = null
		
	boarding_completed.emit(boss)
	
	if is_instance_valid(boss) and boss.has_method("boss_defeat"):
		boss.call("boss_defeat")
	elif is_instance_valid(boss) and boss.has_method("die"):
		boss.call("die")
		
	queue_free()

func _on_arena_lost() -> void:
	if is_instance_valid(active_player) and active_player.has_method("game_over"):
		active_player.game_over(false)
	elif EventBus and EventBus.has_signal("player_sunk"):
		EventBus.player_sunk.emit()
		
	if is_instance_valid(active_arena):
		active_arena.queue_free()
		active_arena = null
		
	queue_free()
