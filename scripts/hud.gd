extends CanvasLayer

@onready var health_label: Label = $Control/MarginContainer/PanelContainer/MarginContainer/HBoxContainer/HealthLabel
@onready var score_label: Label = $Control/MarginContainer/PanelContainer/MarginContainer/HBoxContainer/ScoreLabel

func _ready() -> void:
	# Find player node
	var player = get_tree().get_first_node_in_group("player")
	if player:
		# Connect to signals
		player.health_changed.connect(_on_player_health_changed)
		player.score_changed.connect(_on_player_score_changed)
		
		# Set initial values
		_on_player_health_changed(player.current_health, player.max_health)
		_on_player_score_changed(player.score)
	else:
		# Fallback if player is spawned later
		await get_tree().process_frame
		player = get_tree().get_first_node_in_group("player")
		if player:
			player.health_changed.connect(_on_player_health_changed)
			player.score_changed.connect(_on_player_score_changed)
			_on_player_health_changed(player.current_health, player.max_health)
			_on_player_score_changed(player.score)

func _on_player_health_changed(current: int, max_health: int) -> void:
	var hearts = ""
	for i in range(max_health):
		if i < current:
			hearts += "❤"
		else:
			hearts += "🖤"
	health_label.text = "HP: " + hearts

func _on_player_score_changed(score: int) -> void:
	score_label.text = "Barrels: %d / 50" % score
