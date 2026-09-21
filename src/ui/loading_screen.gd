class_name LoadingScreen
extends CanvasLayer

## Full-screen asynchronous loading screen with river progress bar and animated dinghy monkey.

signal loading_completed(target_scene: PackedScene)

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

var raw_progress: float = 0.0
var visual_progress: float = 0.0
var elapsed_load_time: float = 0.0
var bob_time: float = 0.0

# Minimum dwell time ensures ultra-fast loads don't flash for a single jarring frame
const MINIMUM_LOAD_DURATION: float = 0.9

const FLAVOR_STAGES: Array[Dictionary] = [
	{ "threshold": 0.00, "text": "Untying docklines & hoisting the colors..." },
	{ "threshold": 0.25, "text": "Navigating the rushing river currents..." },
	{ "threshold": 0.50, "text": "Scouting riverbanks for rogue ambushers..." },
	{ "threshold": 0.75, "text": "Sighting the pirate outpost on the horizon..." },
	{ "threshold": 0.98, "text": "Dropping anchor! All hands on deck!" }
]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_update_visual_progress(0.0)
	if fade_overlay:
		fade_overlay.visible = true
		fade_overlay.modulate = Color(1.0, 1.0, 1.0, 1.0)
		var in_tween: Tween = create_tween()
		in_tween.tween_property(fade_overlay, "modulate:a", 0.0, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	if target_scene_path == "" and GameState and "pending_loading_path" in GameState and GameState.pending_loading_path != "":
		target_scene_path = GameState.pending_loading_path
		destination_name = GameState.pending_loading_title
		GameState.pending_loading_path = ""
		GameState.pending_loading_title = ""

	if target_scene_path != "":
		start_loading(target_scene_path, destination_name)

func set_destination(path: String, dest_title: String = "") -> void:
	target_scene_path = path
	destination_name = dest_title
	if is_node_ready():
		start_loading(target_scene_path, destination_name)

func start_loading(path: String, dest_title: String = "") -> void:
	target_scene_path = path
	destination_name = dest_title
	is_loading_active = true
	has_completed_transition = false
	raw_progress = 0.0
	visual_progress = 0.0
	elapsed_load_time = 0.0

	if destination_label:
		if destination_name.strip_edges() != "":
			destination_label.text = "SAILING TO: %s" % destination_name.to_upper()
		else:
			destination_label.text = "SETTING SAIL..."

	if status_caption:
		status_caption.text = FLAVOR_STAGES[0]["text"]

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

		# Factor in minimum duration so progression is smooth and readable
		var time_progress: float = clampf(elapsed_load_time / MINIMUM_LOAD_DURATION, 0.0, 1.0)
		var desired_progress: float = minf(raw_progress, time_progress) if status != ResourceLoader.THREAD_LOAD_LOADED else time_progress

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
		visual_progress = clampf(elapsed_load_time / MINIMUM_LOAD_DURATION, 0.0, 1.0)
		_update_visual_progress(visual_progress)
		if visual_progress >= 1.0:
			has_completed_transition = true
			loading_completed.emit(null)

func _update_visual_progress(progress: float) -> void:
	var percent_int: int = int(round(progress * 100.0))
	if percentage_label:
		percentage_label.text = "%d%%" % percent_int

	# Update flavor text
	if status_caption:
		var current_flavor: String = FLAVOR_STAGES[0]["text"]
		for stage: Dictionary in FLAVOR_STAGES:
			if progress >= float(stage["threshold"]):
				current_flavor = str(stage["text"])
		status_caption.text = current_flavor

	# Update river water fill width
	if river_track and river_water_fill:
		var total_width: float = river_track.size.x
		river_water_fill.offset_right = total_width * progress

	# Update boat horizontal anchor position along the river
	if river_track and boat_anchor:
		var usable_width: float = river_track.size.x - 70.0
		boat_anchor.position.x = usable_width * progress

func _update_boat_float_animation() -> void:
	if not dinghy_sprite:
		return
	# Gentle wave bobbing (Y) and pitch rocking (rotation)
	var bob_offset_y: float = sin(bob_time * 5.5) * 3.5
	var rock_angle_deg: float = sin(bob_time * 3.8) * 2.5
	dinghy_sprite.position.y = bob_offset_y
	dinghy_sprite.rotation_degrees = rock_angle_deg

func _finish_and_change_scene() -> void:
	var packed_scene: PackedScene = ResourceLoader.load_threaded_get(target_scene_path) as PackedScene
	if not packed_scene:
		push_error("LoadingScreen: Failed to retrieve loaded packed scene.")
		get_tree().change_scene_to_file(target_scene_path)
		return

	loading_completed.emit(packed_scene)

	if fade_overlay:
		fade_overlay.visible = true
		var out_tween: Tween = create_tween()
		out_tween.tween_property(fade_overlay, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		await out_tween.finished

	get_tree().change_scene_to_packed(packed_scene)
