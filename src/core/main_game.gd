class_name MainGame
extends Node3D

@export var start_screen_scene: PackedScene = preload("res://src/ui/start_screen.tscn")
@export var victory_screen_scene: PackedScene = preload("res://src/ui/victory_screen.tscn")
@export var settlement_screen_scene: PackedScene = preload("res://src/ui/settlement_screen.tscn")

@export var harbor_bay_scene: PackedScene = preload("res://src/levels/harbor_bay.tscn")

var start_screen: StartScreen
var victory_screen: VictoryScreen
var settlement_screen: SettlementScreen
var harbor_bay: HarborBay

func _ready() -> void:
	GameState.active_vessel_changed.connect(_on_active_vessel_changed)
	_update_active_player_vessel()
	if GameState.should_auto_start_endless:
		GameState.should_auto_start_endless = false
		_on_endless_mode_started()
	elif GameState.should_auto_start:
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
	var track_mgr := get_tree().get_first_node_in_group("track_manager") as Node3D
	if track_mgr:
		track_mgr.visible = false
		
	# Hide LevelController obstacles/props from displaying in the harbor
	var level_ctrl := get_tree().get_first_node_in_group("level_controller") as LevelController
	if level_ctrl:
		level_ctrl.visible = false

	# Setup Harbor Bay
	if harbor_bay_scene:
		harbor_bay = harbor_bay_scene.instantiate() as HarborBay
		add_child(harbor_bay)
		
	var camera := get_tree().get_first_node_in_group("game_camera") as GameCamera
	if camera and camera.has_method("set_harbor_mode"):
		camera.set_harbor_mode(true)

	var player := get_tree().get_first_node_in_group("player") as PlayerSwerve
	if player:
		var hardpoints := player.get_node_or_null("Hardpoints") as Node3D
		if hardpoints:
			hardpoints.visible = false

func _start_game_immediately() -> void:
	GameState.is_game_active = true
	GameState.set_performance_mode(true)
	if EventBus and EventBus.has_signal("level_started"):
		EventBus.level_started.emit(GameState.current_level)
	var level_ctrl := get_tree().get_first_node_in_group("level_controller") as LevelController
	if level_ctrl:
		level_ctrl.visible = true
	var is_modular: bool = (level_ctrl != null and level_ctrl.chunk_assembler != null and level_ctrl.chunk_assembler.is_assembled)
	var track_mgr := get_tree().get_first_node_in_group("track_manager") as Node3D
	if track_mgr:
		track_mgr.visible = not is_modular
		track_mgr.set_physics_process(not is_modular)
	var camera := get_tree().get_first_node_in_group("game_camera") as GameCamera
	if camera and camera.has_method("set_harbor_mode"):
		camera.set_harbor_mode(false)
	var player := get_tree().get_first_node_in_group("player") as PlayerSwerve
	if player:
		player.is_shooting_enabled = true
		var vis := player.get_node_or_null("BoatVisuals") as Node3D
		if vis:
			vis.rotation_degrees.y = 0.0
		var hardpoints := player.get_node_or_null("Hardpoints") as Node3D
		if hardpoints:
			hardpoints.visible = true
			hardpoints.rotation_degrees.y = 0.0
	var hud := get_tree().get_first_node_in_group("top_hud") as TopHUD
	if hud and hud.has_method("on_game_started"):
		hud.on_game_started()
	AudioManager.play_music()

func _pause_player_shooting() -> void:
	var player := get_tree().get_first_node_in_group("player") as PlayerSwerve
	if player:
		player.is_shooting_enabled = false

func _setup_start_screen() -> void:
	if start_screen_scene:
		start_screen = start_screen_scene.instantiate() as StartScreen
		add_child(start_screen)
		start_screen.game_started.connect(_on_game_started)
		if start_screen.has_signal("endless_started"):
			start_screen.endless_started.connect(_on_endless_mode_started)

const EndlessModeScript: GDScript = preload("res://src/features/modes/endless_mode.gd")

func _on_endless_mode_started() -> void:
	_on_game_started()
	var endless_mode: Node = EndlessModeScript.new()
	endless_mode.name = "EndlessMode"
	add_child(endless_mode)
	if endless_mode.has_method("start_run"):
		endless_mode.call("start_run")

func _on_game_started() -> void:
	GameState.is_game_active = true
	GameState.set_performance_mode(true)
	if EventBus and EventBus.has_signal("level_started"):
		EventBus.level_started.emit(GameState.current_level)
	print("[RIVER RUN STARTED] River Level %d | Active Vessel: %s (Tier %d) | Vault: %d 🪙" % [
		GameState.current_level,
		GameState.active_vessel,
		GameState.get_active_ship_tier(),
		GameState.doubloons
	])
	
	# 1. Disable harbor backdrop camera & hide 3D parent node BEFORE chunk instantiation
	if harbor_bay and is_instance_valid(harbor_bay):
		var harbor_cam := harbor_bay.find_child("*Camera*", true, false) as Camera3D
		if harbor_cam:
			harbor_cam.current = false
		harbor_bay.hide()
		harbor_bay.transition_out(0.8)
		
	# 2. Make runner track and level obstacles visible & instantiated/ready
	var level_ctrl := get_tree().get_first_node_in_group("level_controller") as LevelController
	if level_ctrl:
		level_ctrl.visible = true

	var is_modular: bool = (level_ctrl != null and level_ctrl.chunk_assembler != null and level_ctrl.chunk_assembler.is_assembled)
	var track_mgr := get_tree().get_first_node_in_group("track_manager") as Node3D
	if track_mgr:
		track_mgr.visible = not is_modular
		track_mgr.set_physics_process(not is_modular)

	# 3. Transition gameplay camera once runner chunk is ready to render
	var camera := get_tree().get_first_node_in_group("game_camera") as GameCamera
	if camera:
		camera.make_current()
		if camera.has_method("transition_to_gameplay"):
			camera.transition_to_gameplay(0.85)
		
	var player := get_tree().get_first_node_in_group("player") as PlayerSwerve
	if player:
		player.is_shooting_enabled = true
		var vis := player.get_node_or_null("BoatVisuals") as Node3D
		if vis:
			vis.rotation_degrees.y = 0.0
		var hardpoints := player.get_node_or_null("Hardpoints") as Node3D
		if hardpoints:
			hardpoints.visible = true
			hardpoints.rotation_degrees.y = 0.0
		
	var hud := get_tree().get_first_node_in_group("top_hud") as TopHUD
	if hud and hud.has_method("on_game_started"):
		hud.on_game_started()
		
	AudioManager.play_music()

func _setup_victory_screen() -> void:
	if settlement_screen_scene:
		settlement_screen = settlement_screen_scene.instantiate() as SettlementScreen
		settlement_screen.add_to_group("settlement_screen")
		add_child(settlement_screen)
	elif victory_screen_scene:
		victory_screen = victory_screen_scene.instantiate() as VictoryScreen
		add_child(victory_screen)
		
	if EventBus and not EventBus.level_completed.is_connected(_on_level_completed):
		EventBus.level_completed.connect(_on_level_completed)
	elif GameState.has_signal("level_completed") and not GameState.level_completed.is_connected(_on_level_completed):
		GameState.level_completed.connect(_on_level_completed)

func _on_level_completed(_doubloons: int, _targets: int) -> void:
	if get_node_or_null("EndlessMode") != null:
		return # In Endless Mode, defeating a boss awards rewards without halting the run!
	GameState.set_performance_mode(false)
	var stars: int = GameState.calculate_stars()
	var level_res := GameState.get_current_level_resource()
	var bonus: int = level_res.completion_doubloon_reward if level_res else 150
	var run_coins := GameState.run_doubloons
	GameState.bank_run_doubloons(bonus)
	
	if settlement_screen:
		settlement_screen.show_victory(run_coins, bonus, GameState.doubloons, stars)
	elif victory_screen:
		victory_screen.show_victory(run_coins + bonus, _targets, stars)

func _exit_tree() -> void:
	if GameState and GameState.active_vessel_changed.is_connected(_on_active_vessel_changed):
		GameState.active_vessel_changed.disconnect(_on_active_vessel_changed)

func _on_active_vessel_changed(_vessel_id: String) -> void:
	if not is_inside_tree():
		return
	_update_active_player_vessel()

func _update_active_player_vessel() -> void:
	var ship := GameState.get_active_ship_resource()
	if not ship:
		return
	var player := get_tree().get_first_node_in_group("player") as PlayerSwerve
	if not player:
		return

	var target_scene: PackedScene = null
	if "boat_scene" in ship and ship.boat_scene:
		target_scene = ship.boat_scene
	elif ship.ship_id == "bombard_skiff":
		target_scene = preload("res://src/gameplay/player/bombard_skiff_boat.tscn")

	if target_scene and player.scene_file_path != target_scene.resource_path:
		var parent: Node = player.get_parent()
		if parent:
			var old_transform: Transform3D = player.transform
			var old_shooting: bool = player.is_shooting_enabled
			player.remove_from_group("player")
			parent.remove_child(player)
			player.queue_free()

			var new_boat := target_scene.instantiate() as PlayerSwerve
			if new_boat:
				new_boat.name = "PlayerBoat"
				new_boat.transform = old_transform
				parent.add_child(new_boat)
				new_boat.is_shooting_enabled = old_shooting
				if not GameState.is_game_active:
					var hp := new_boat.get_node_or_null("Hardpoints") as Node3D
					if hp:
						hp.visible = false
			return

	if player.has_method("apply_ship_data"):
		player.apply_ship_data(ship)

func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if not (event is InputEventKey) or not event.is_pressed() or event.is_echo():
		return
	var key := (event as InputEventKey).keycode
	match key:
		KEY_BRACKETLEFT:
			if GameState.current_level > 1:
				GameState.current_level -= 1
				GameState.current_selected_level = GameState.current_level
				print("[RIVER LEVEL] Stepped back to River Level %d" % GameState.current_level)
				GameState.should_auto_start = true
				get_tree().reload_current_scene()
		KEY_BRACKETRIGHT:
			if GameState.current_level < 45:
				GameState.current_level += 1
				GameState.current_selected_level = GameState.current_level
				print("[RIVER LEVEL] Advanced to River Level %d" % GameState.current_level)
				GameState.should_auto_start = true
				get_tree().reload_current_scene()
		KEY_B:
			var ctrl := get_tree().get_first_node_in_group("level_controller") as LevelController
			if ctrl and ctrl.has_method("jump_to_boss"):
				ctrl.jump_to_boss()
		KEY_R:
			GameState.should_auto_start = true
			get_tree().reload_current_scene()

