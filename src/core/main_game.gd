class_name MainGame
extends Node3D

@export var start_screen_scene: PackedScene = preload("res://src/ui/start_screen.tscn")
@export var victory_screen_scene: PackedScene = preload("res://src/ui/victory_screen.tscn")

var start_screen: StartScreen
var victory_screen: VictoryScreen

func _ready() -> void:
	if GameState.should_auto_start:
		GameState.should_auto_start = false
		_start_game_immediately()
	else:
		GameState.is_game_active = false
		_pause_player_shooting()
		_setup_start_screen()
	_setup_victory_screen()

func _start_game_immediately() -> void:
	GameState.is_game_active = true
	var player = get_tree().get_first_node_in_group("player")
	if player and "is_shooting_enabled" in player:
		player.is_shooting_enabled = true
	var hud = get_tree().get_first_node_in_group("top_hud")
	if hud and hud.has_method("on_game_started"):
		hud.on_game_started()
	AudioManager.play_music()

func _pause_player_shooting() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player and "is_shooting_enabled" in player:
		player.is_shooting_enabled = false

func _setup_start_screen() -> void:
	if start_screen_scene:
		start_screen = start_screen_scene.instantiate() as StartScreen
		add_child(start_screen)
		start_screen.game_started.connect(_on_game_started)

func _on_game_started() -> void:
	GameState.is_game_active = true
	var player = get_tree().get_first_node_in_group("player")
	if player and "is_shooting_enabled" in player:
		player.is_shooting_enabled = true
		
	var hud = get_tree().get_first_node_in_group("top_hud")
	if hud and hud.has_method("on_game_started"):
		hud.on_game_started()
		
	AudioManager.play_music()

func _setup_victory_screen() -> void:
	if victory_screen_scene:
		victory_screen = victory_screen_scene.instantiate() as VictoryScreen
		add_child(victory_screen)
		if GameState.has_signal("level_completed"):
			GameState.level_completed.connect(_on_level_completed)

func _on_level_completed(doubloons: int, targets: int) -> void:
	if victory_screen:
		victory_screen.show_victory(doubloons, targets, 3)
