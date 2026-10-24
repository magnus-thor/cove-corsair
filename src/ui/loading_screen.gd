class_name LoadingScreen
extends CanvasLayer

## Full-screen asynchronous loading screen with river progress bar and animated dinghy monkey.

signal loading_completed(target_scene: PackedScene)

@onready var root_control: Control = %RootControl
@onready var background_rect: TextureRect = %BackgroundRect
@onready var destination_label: Label = %DestinationLabel
@onready var river_track: Control = %RiverTrack
@onready var river_water_fill: Panel = %RiverWaterFill
@onready var boat_anchor: Control = %BoatAnchor
@onready var dinghy_sprite: TextureRect = %DinghySprite
@onready var percentage_label: Label = %PercentageLabel
@onready var status_caption: Label = %StatusCaption
@onready var fade_overlay: ColorRect = %FadeOverlay

var target_scene_path: String = ""
var destination_name: String = ""
var is_loading_active: bool = false
var has_completed_transition: bool = false
var is_startup_splash: bool = false

var raw_progress: float = 0.0
var visual_progress: float = 0.0
var elapsed_load_time: float = 0.0
var bob_time: float = 0.0
var base_boat_y: float = -40.0

const DEFAULT_STARTUP_SCENE: String = "res://scenes/cove_hub/cove_main_hub.tscn"
const STARTUP_LOAD_DURATION: float = 2.0
const LEVEL_LOAD_DURATION: float = 0.9

var current_load_duration: float = LEVEL_LOAD_DURATION
var current_flavor_stages: Array[Dictionary] = []

const STARTUP_FLAVOR_STAGES: Array[Dictionary] = [
	{ "threshold": 0.00, "text": "Assembling the pirate crew..." },
	{ "threshold": 0.25, "text": "Stocking the hold with powder & rum..." },
	{ "threshold": 0.50, "text": "Chartin' forgotten river channels..." },
	{ "threshold": 0.75, "text": "Catchin' the tide to Smuggler's Cove..." },
	{ "threshold": 0.95, "text": "Welcome to Cove Corsair! Droppin' anchor..." }
]

const LEVEL_FLAVOR_STAGES: Array[Dictionary] = [
	{ "threshold": 0.00, "text": "Untying docklines & hoisting the colors..." },
	{ "threshold": 0.25, "text": "Navigating the rushing river currents..." },
	{ "threshold": 0.50, "text": "Scouting riverbanks for rogue ambushers..." },
	{ "threshold": 0.75, "text": "Sighting the pirate outpost on the horizon..." },
	{ "threshold": 0.95, "text": "Dropping anchor! All hands on deck!" }
]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if dinghy_sprite:
		base_boat_y = dinghy_sprite.position.y

	current_flavor_stages = LEVEL_FLAVOR_STAGES
	_update_visual_progress(0.0)

	if fade_overlay:
		fade_overlay.visible = true
		fade_overlay.modulate = Color(1.0, 1.0, 1.0, 1.0)
		var in_tween: Tween = create_tween()
		in_tween.tween_property(fade_overlay, "modulate:a", 0.0, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		in_tween.tween_callback(func() -> void:
			if fade_overlay:
				fade_overlay.visible = false
		)

	var is_boot: bool = false
	if target_scene_path == "":
		if GameState and "pending_loading_path" in GameState and GameState.pending_loading_path != "":
			target_scene_path = GameState.pending_loading_path
			destination_name = GameState.pending_loading_title
			GameState.pending_loading_path = ""
			GameState.pending_loading_title = ""
		else:
			# Game launch boot splash mode
			var is_first_time: bool = false
			if GameState and "tutorial_step" in GameState:
				is_first_time = (int(GameState.tutorial_step) <= int(GameState.TutorialStep.LEVEL_1_IN_PROGRESS))

			if is_first_time:
				# First time startup: directly launch into River Level 1 Tutorial
				GameState.select_level(1)
				GameState.should_auto_start = true
				GameState.should_auto_start_endless = false
				GameState.reset_level()
				GameState.advance_tutorial_to(GameState.TutorialStep.LEVEL_1_IN_PROGRESS)
				target_scene_path = "res://src/core/main_game.tscn"
				destination_name = "Smuggler's Run (Tutorial)"
				is_boot = true
			else:
				target_scene_path = DEFAULT_STARTUP_SCENE
				destination_name = "Smuggler's Cove"
				is_boot = true

	if target_scene_path != "":
		start_loading(target_scene_path, destination_name, is_boot)

func set_destination(path: String, dest_title: String = "") -> void:
	target_scene_path = path
	destination_name = dest_title
	if is_node_ready():
		start_loading(target_scene_path, destination_name, false)

func start_loading(path: String, dest_title: String = "", is_startup: bool = false) -> void:
	target_scene_path = path
	destination_name = dest_title
	is_startup_splash = is_startup
	is_loading_active = true
	has_completed_transition = false
	raw_progress = 0.0
	visual_progress = 0.0
	elapsed_load_time = 0.0

	if is_startup_splash:
		current_flavor_stages = STARTUP_FLAVOR_STAGES
		current_load_duration = STARTUP_LOAD_DURATION
		if destination_label:
			if destination_name != "" and destination_name != "Smuggler's Cove":
				destination_label.text = "SETTING SAIL: %s" % destination_name.to_upper()
			else:
				destination_label.text = "SETTING SAIL FOR SMUGGLER'S COVE"
	else:
		current_flavor_stages = LEVEL_FLAVOR_STAGES
		current_load_duration = LEVEL_LOAD_DURATION
		if destination_label:
			if destination_name.strip_edges() != "":
				destination_label.text = "SAILING TO: %s" % destination_name.to_upper()
			else:
				destination_label.text = "SETTING SAIL..."

	if status_caption and not current_flavor_stages.is_empty():
		status_caption.text = str(current_flavor_stages[0]["text"])

	if target_scene_path != "":
		var error: Error = ResourceLoader.load_threaded_request(target_scene_path, "", true)
		if error != OK:
			push_warning("LoadingScreen: load_threaded_request failed for %s with error %d" % [target_scene_path, error])

func _process(delta: float) -> void:
	bob_time += delta
	_update_boat_float_animation()

	if not is_loading_active or has_completed_transition:
		return

	elapsed_load_time += delta

	# Poll loader progress
	if target_scene_path != "":
		var progress_arr: Array = []
		var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(target_scene_path, progress_arr)

		if not progress_arr.is_empty():
			var p_val: float = float(progress_arr[0])
			raw_progress = maxf(raw_progress, p_val)

		# Progress advances smoothly and proportionally across the entire load duration
		var time_ratio: float = clampf(elapsed_load_time / current_load_duration, 0.0, 1.0)
		var desired_progress: float = time_ratio
		if status != ResourceLoader.THREAD_LOAD_LOADED:
			# If disk reading is somehow still busy, hold at 75% max
			desired_progress = minf(desired_progress, 0.75)

		visual_progress = move_toward(visual_progress, desired_progress, delta * 1.5)
		visual_progress = clampf(visual_progress, 0.0, 1.0)
		_update_visual_progress(visual_progress)

		if status == ResourceLoader.THREAD_LOAD_LOADED and visual_progress >= 0.999:
			has_completed_transition = true
			_finish_and_change_scene()
		elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_error("LoadingScreen: Threaded load failed for: %s" % target_scene_path)
			has_completed_transition = true
			# Fallback direct load attempt
			get_tree().change_scene_to_file(target_scene_path)
	else:
		# Standalone preview / test animation mode
		visual_progress = clampf(elapsed_load_time / current_load_duration, 0.0, 1.0)
		_update_visual_progress(visual_progress)
		if visual_progress >= 1.0:
			has_completed_transition = true
			loading_completed.emit(null)

func _update_visual_progress(progress: float) -> void:
	var percent_int: int = int(round(progress * 100.0))
	if percentage_label:
		percentage_label.text = "%d%%" % percent_int

	# Update flavor text
	if status_caption and not current_flavor_stages.is_empty():
		var current_flavor: String = str(current_flavor_stages[0]["text"])
		for stage: Dictionary in current_flavor_stages:
			if progress >= float(stage["threshold"]):
				current_flavor = str(stage["text"])
		status_caption.text = current_flavor

	# Update river water fill width
	if river_track and river_water_fill:
		var total_width: float = river_track.size.x
		river_water_fill.offset_right = total_width * progress

	# Update boat horizontal anchor position along the river
	if river_track and boat_anchor:
		var usable_width: float = river_track.size.x - 50.0
		boat_anchor.position.x = usable_width * progress

func _update_boat_float_animation() -> void:
	if not dinghy_sprite:
		return
	# Gentle wave bobbing (Y) and pitch rocking (rotation)
	var bob_offset_y: float = sin(bob_time * 5.5) * 3.5
	var rock_angle_deg: float = sin(bob_time * 3.8) * 2.5
	dinghy_sprite.position.y = base_boat_y + bob_offset_y
	dinghy_sprite.rotation_degrees = rock_angle_deg

func _finish_and_change_scene() -> void:
	var packed_scene: PackedScene = ResourceLoader.load_threaded_get(target_scene_path) as PackedScene
	if not packed_scene:
		push_error("LoadingScreen: Failed to retrieve loaded packed scene.")
		get_tree().change_scene_to_file(target_scene_path)
		return

	# Instantiate target scene while LoadingScreen remains fully visible on screen
	var new_scene: Node = packed_scene.instantiate()
	if not new_scene:
		push_error("LoadingScreen: Failed to instantiate packed scene: %s" % target_scene_path)
		get_tree().change_scene_to_file(target_scene_path)
		return

	# Add newly instantiated scene into root tree underneath LoadingScreen (layer 120)
	var root: Window = get_tree().root
	root.add_child(new_scene)
	get_tree().current_scene = new_scene

	_update_visual_progress(1.0)
	loading_completed.emit(packed_scene)

	# Ensure new scene has finished its _ready() and rendered its first frames behind the loading screen
	await get_tree().process_frame
	await get_tree().process_frame

	# Smooth crossfade out of the loading screen to seamlessly reveal the initialized game scene
	if root_control:
		var out_tween: Tween = create_tween()
		out_tween.tween_property(root_control, "modulate:a", 0.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		await out_tween.finished

	# Cleanly remove and free the loading screen
	queue_free()
