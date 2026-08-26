extends CanvasLayer

@onready var health_label: Label = $Control/MarginContainer/PanelContainer/MarginContainer/HBoxContainer/HealthLabel
@onready var doubloons_label: Label = $Control/MarginContainer/PanelContainer/MarginContainer/HBoxContainer/DoubloonsLabel
@onready var score_label: Label = $Control/MarginContainer/PanelContainer/MarginContainer/HBoxContainer/ScoreLabel

func _ready() -> void:
	# Find player node
	var player = get_tree().get_first_node_in_group("player")
	if player:
		_connect_player(player)
	else:
		# Fallback if player is spawned later
		await get_tree().process_frame
		player = get_tree().get_first_node_in_group("player")
		if player:
			_connect_player(player)

func _connect_player(player: Node) -> void:
	if player.has_signal("health_changed"):
		player.health_changed.connect(_on_player_health_changed)
	if player.has_signal("score_changed"):
		player.score_changed.connect(_on_player_score_changed)
	if player.has_signal("doubloons_changed"):
		player.doubloons_changed.connect(_on_player_doubloons_changed)
		
	if "current_health" in player and "max_health" in player:
		_on_player_health_changed(player.current_health, player.max_health)
	if "score" in player:
		_on_player_score_changed(player.score)
	if "doubloons" in player:
		_on_player_doubloons_changed(player.doubloons)

func _on_player_health_changed(current: int, max_health: int) -> void:
	var hearts = ""
	for i in range(max_health):
		if i < current:
			hearts += "❤"
		else:
			hearts += "🖤"
	if health_label:
		health_label.text = "HP: " + hearts

func _on_player_doubloons_changed(doubloons: int) -> void:
	if doubloons_label:
		doubloons_label.text = "🪙 %d" % doubloons

func _on_player_score_changed(score: int) -> void:
	if score_label:
		score_label.text = "Score: %d / 50" % score
