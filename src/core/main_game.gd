class_name MainGame
extends Node3D

@export var start_screen_scene: PackedScene = preload("res://src/ui/start_screen.tscn")
@export var victory_screen_scene: PackedScene = preload("res://src/ui/victory_screen.tscn")
@export var settlement_screen_scene: PackedScene = preload("res://src/ui/settlement_screen.tscn")

@export var harbor_bay_scene: PackedScene = preload("res://src/levels/harbor_bay.tscn")

var start_screen: StartScreen
var victory_screen: VictoryScreen
var settlement_screen: CanvasLayer
var harbor_bay: Node3D

func _ready() -> void:
	GameState.active_vessel_changed.connect(_on_active_vessel_changed)
	_update_active_player_vessel()
	if GameState.should_auto_start:
		GameState.should_auto_start = false
		_start_game_immediately()
	else:
		GameState.is_game_active = false
		_pause_player_shooting()
		_setup_harbor_mode()
		_setup_start_screen()
	_setup_victory_screen()

func _setup_harbor_mode() -> void:
	GameState.set_performance_mode(false)
	# Hide track segments and river lane during harbor mode
	var track_mgr = get_tree().get_first_node_in_group("track_manager")
	if track_mgr:
		track_mgr.visible = false
		
	# Hide LevelController obstacles/props from displaying in the harbor
	var level_ctrl = get_tree().get_first_node_in_group("level_controller")
	if level_ctrl:
		level_ctrl.visible = false

	# Setup Harbor Bay
	if harbor_bay_scene:
		harbor_bay = harbor_bay_scene.instantiate() as Node3D
		add_child(harbor_bay)
		
	var camera = get_tree().get_first_node_in_group("game_camera")
	if camera and camera.has_method("set_harbor_mode"):
		camera.set_harbor_mode(true)

	var player = get_tree().get_first_node_in_group("player")
	if player:
		var hardpoints = player.get_node_or_null("Hardpoints")
		if hardpoints:
			hardpoints.visible = false

func _start_game_immediately() -> void:
	GameState.is_game_active = true
	GameState.set_performance_mode(true)
	var level_ctrl = get_tree().get_first_node_in_group("level_controller")
	if level_ctrl:
		level_ctrl.visible = true
	var is_modular = level_ctrl and level_ctrl.chunk_assembler and level_ctrl.chunk_assembler.is_assembled
	var track_mgr = get_tree().get_first_node_in_group("track_manager")
	if track_mgr:
		track_mgr.visible = not is_modular
		track_mgr.set_physics_process(not is_modular)
	var camera = get_tree().get_first_node_in_group("game_camera")
	if camera and camera.has_method("set_harbor_mode"):
		camera.set_harbor_mode(false)
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
	GameState.set_performance_mode(true)
	
	# 1. Disable harbor backdrop camera & hide 3D parent node BEFORE chunk instantiation
	if harbor_bay and is_instance_valid(harbor_bay):
		var harbor_cam = harbor_bay.find_child("*Camera*", true, false)
		if harbor_cam and harbor_cam is Camera3D:
			harbor_cam.current = false
		harbor_bay.hide()
		harbor_bay.transition_out(0.8)
		
	# 2. Make runner track and level obstacles visible & instantiated/ready
	var level_ctrl = get_tree().get_first_node_in_group("level_controller")
	if level_ctrl:
		level_ctrl.visible = true

	var is_modular = level_ctrl and level_ctrl.chunk_assembler and level_ctrl.chunk_assembler.is_assembled
	var track_mgr = get_tree().get_first_node_in_group("track_manager")
	if track_mgr:
		track_mgr.visible = not is_modular
		track_mgr.set_physics_process(not is_modular)

	# 3. Transition gameplay camera once runner chunk is ready to render
	var camera = get_tree().get_first_node_in_group("game_camera") as Camera3D
	if camera:
		camera.make_current()
		if camera.has_method("transition_to_gameplay"):
			camera.transition_to_gameplay(0.85)
		
	var player = get_tree().get_first_node_in_group("player")
	if player:
		if "is_shooting_enabled" in player:
			player.is_shooting_enabled = true
		var tween = create_tween()
		var vis = player.get_node_or_null("BoatVisuals")
		if vis:
			tween.tween_property(vis, "rotation_degrees:y", 0.0, 0.6).set_trans(Tween.TRANS_SINE)
		var hardpoints = player.get_node_or_null("Hardpoints")
		if hardpoints:
			hardpoints.visible = true
			tween.tween_property(hardpoints, "rotation_degrees:y", 0.0, 0.6).set_trans(Tween.TRANS_SINE)
		
	var hud = get_tree().get_first_node_in_group("top_hud")
	if hud and hud.has_method("on_game_started"):
		hud.on_game_started()
		
	AudioManager.play_music()

func _setup_victory_screen() -> void:
	if settlement_screen_scene:
		settlement_screen = settlement_screen_scene.instantiate() as CanvasLayer
		settlement_screen.add_to_group("settlement_screen")
		add_child(settlement_screen)
	elif victory_screen_scene:
		victory_screen = victory_screen_scene.instantiate() as VictoryScreen
		add_child(victory_screen)
		
	if GameState.has_signal("level_completed") and not GameState.level_completed.is_connected(_on_level_completed):
		GameState.level_completed.connect(_on_level_completed)

func _on_level_completed(_doubloons: int, _targets: int) -> void:
	GameState.set_performance_mode(false)
	var stars: int = GameState.calculate_stars()
	var level_res = GameState.get_current_level_resource()
	var bonus: int = level_res.completion_doubloon_reward if level_res else 150
	var run_coins = GameState.run_doubloons
	GameState.bank_run_doubloons(bonus)
	
	if settlement_screen:
		settlement_screen.show_victory(run_coins, bonus, GameState.doubloons, stars)
	elif victory_screen:
		victory_screen.show_victory(run_coins + bonus, _targets, stars)

func _on_active_vessel_changed(_vessel_id: String) -> void:
	_update_active_player_vessel()

func _update_active_player_vessel() -> void:
	var ship = GameState.get_active_ship_resource()
	if not ship:
		return
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return

	var target_scene: PackedScene = null
	if "boat_scene" in ship and ship.boat_scene:
		target_scene = ship.boat_scene
	elif ship.ship_id == "bombard_skiff":
		target_scene = preload("res://src/gameplay/player/bombard_skiff_boat.tscn")

	if target_scene and player.scene_file_path != target_scene.resource_path:
		var parent = player.get_parent()
		if parent:
			var old_transform = player.transform
			var old_shooting = player.is_shooting_enabled if "is_shooting_enabled" in player else false
			player.remove_from_group("player")
			parent.remove_child(player)
			player.queue_free()

			var new_boat = target_scene.instantiate()
			new_boat.name = "PlayerBoat"
			new_boat.transform = old_transform
			parent.add_child(new_boat)
			if "is_shooting_enabled" in new_boat:
				new_boat.is_shooting_enabled = old_shooting
			if not GameState.is_game_active:
				var hp = new_boat.get_node_or_null("Hardpoints")
				if hp:
					hp.visible = false
			return

	if player.has_method("apply_ship_data"):
		player.apply_ship_data(ship)

