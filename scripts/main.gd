class_name Main
extends Node3D

@export var victory_screen_scene: PackedScene = preload("res://scenes/ui/victory_screen.tscn")

var victory_screen: VictoryScreen

func _ready() -> void:
	AudioManager.play_music()
	_setup_victory_screen()

func _setup_victory_screen() -> void:
	if victory_screen_scene:
		victory_screen = victory_screen_scene.instantiate() as VictoryScreen
		add_child(victory_screen)
		if GameState.has_signal("level_completed"):
			GameState.level_completed.connect(_on_level_completed)

func _on_level_completed(doubloons: int, targets: int) -> void:
	if victory_screen:
		victory_screen.show_victory(doubloons, targets, 3)

