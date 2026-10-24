class_name TutorialGuidanceOverlay
extends CanvasLayer

## Interactive Spotlight & Tutorial Pointer Overlay for Cove Corsair
## Employs 4 directional shield cutouts around the target Control to focus input,
## a glowing animated target highlight ring, bouncing pointer arrow,
## and a dynamically sized Quartermaster dialogue box with typewriter text animation
## and voice audio playback support (ElevenLabs).
## Fully statically typed.

signal guidance_dismissed

@onready var root_control: Control = $RootControl
@onready var shield_top: ColorRect = %ShieldTop
@onready var shield_bottom: ColorRect = %ShieldBottom
@onready var shield_left: ColorRect = %ShieldLeft
@onready var shield_right: ColorRect = %ShieldRight
@onready var target_highlight: Panel = %TargetHighlight

@onready var banner_panel: PanelContainer = %BannerPanel
@onready var banner_title: Label = %BannerTitle
@onready var banner_text: Label = %BannerText
@onready var tap_hint: Label = %TapHint
@onready var pointer_container: Control = %PointerContainer
@onready var pointer_arrow: Label = %PointerArrow
@onready var voice_player: AudioStreamPlayer = %VoicePlayer

var _target_node: Control = null
var _bounce_tween: Tween = null
var _pulse_tween: Tween = null
var _type_tween: Tween = null
var _dismiss_tween: Tween = null
var _point_dir: Vector2 = Vector2.UP
var _base_pointer_pos: Vector2 = Vector2.ZERO
var _is_typing: bool = false
var _full_text: String = ""

const VOICE_BASE_PATH: String = "res://assets/audio/voice/tutorial/"

func _ready() -> void:
	layer = 55
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	if shield_top:
		shield_top.mouse_filter = Control.MOUSE_FILTER_STOP
	if shield_bottom:
		shield_bottom.mouse_filter = Control.MOUSE_FILTER_STOP
	if shield_left:
		shield_left.mouse_filter = Control.MOUSE_FILTER_STOP
	if shield_right:
		shield_right.mouse_filter = Control.MOUSE_FILTER_STOP

	if banner_panel:
		banner_panel.mouse_filter = Control.MOUSE_FILTER_STOP
		banner_panel.gui_input.connect(_on_banner_gui_input)

func _on_banner_gui_input(ev: InputEvent) -> void:
	var pressed: bool = false
	if ev is InputEventMouseButton:
		var mouse_ev: InputEventMouseButton = ev as InputEventMouseButton
		if mouse_ev.button_index == MOUSE_BUTTON_LEFT and mouse_ev.pressed:
			pressed = true
	elif ev is InputEventScreenTouch:
		var touch_ev: InputEventScreenTouch = ev as InputEventScreenTouch
		if touch_ev.pressed:
			pressed = true

	if pressed:
		if _is_typing:
			_skip_typewriter()
		elif not _target_node or not is_instance_valid(_target_node) or not _target_node.is_visible_in_tree():
			# Fail-safe: Tapping banner dismisses overlay if target is hidden or missing
			dismiss()

func _set_shields_blocking(blocking: bool) -> void:
	var filter: Control.MouseFilter = Control.MOUSE_FILTER_STOP if blocking else Control.MOUSE_FILTER_IGNORE
	if shield_top: shield_top.mouse_filter = filter
	if shield_bottom: shield_bottom.mouse_filter = filter
	if shield_left: shield_left.mouse_filter = filter
	if shield_right: shield_right.mouse_filter = filter

func guide_to(
	target: Control,
	text_content: String,
	point_direction: Vector2 = Vector2.UP,
	title_text: String = "QUARTERMASTER",
	voice_id: String = ""
) -> void:
	# Debounce guard: if already showing or actively typing this exact dialogue line,
	# do not cut off the audio/typewriter to restart it from scratch.
	if visible and _full_text == text_content:
		_target_node = target
		_point_dir = point_direction.normalized() if point_direction != Vector2.ZERO else Vector2.UP
		_update_positions()
		return

	if _dismiss_tween and _dismiss_tween.is_valid():
		_dismiss_tween.kill()
		_dismiss_tween = null
	if root_control:
		root_control.modulate.a = 1.0

	_target_node = target
	_point_dir = point_direction.normalized() if point_direction != Vector2.ZERO else Vector2.UP
	_full_text = text_content

	if not target or not is_instance_valid(target) or not target.is_visible_in_tree():
		# Fail-safe: do not trap player if target cannot be seen
		_set_shields_blocking(false)
		if target_highlight: target_highlight.visible = false
		if pointer_container: pointer_container.visible = false

	if banner_title:
		banner_title.text = title_text.to_upper()
	if banner_text:
		banner_text.text = text_content
		banner_text.visible_ratio = 0.0
	if tap_hint:
		tap_hint.text = "(TAP TO SKIP)"

	visible = true
	_update_positions()
	_start_pointer_bob()
	_start_highlight_pulse()
	_start_voice_and_typewriter(voice_id, text_content)
	var audio: Node = get_node_or_null("/root/AudioManager")
	if audio and audio.has_method("duck_music"):
		audio.call("duck_music", true)

func dismiss() -> void:
	if _bounce_tween and _bounce_tween.is_valid():
		_bounce_tween.kill()
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	if _type_tween and _type_tween.is_valid():
		_type_tween.kill()
	if voice_player and voice_player.playing:
		voice_player.stop()

	_target_node = null
	_is_typing = false
	_set_shields_blocking(false)

	if _dismiss_tween and _dismiss_tween.is_valid():
		_dismiss_tween.kill()

	_dismiss_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_dismiss_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if root_control:
		_dismiss_tween.tween_property(root_control, "modulate:a", 0.0, 0.18)
	_dismiss_tween.tween_callback(func() -> void:
		visible = false
		if root_control:
			root_control.modulate.a = 1.0
		var audio: Node = get_node_or_null("/root/AudioManager")
		if audio and audio.has_method("duck_music"):
			audio.call("duck_music", false)
		guidance_dismissed.emit()
	)

func _process(_delta: float) -> void:
	if visible and _target_node and is_instance_valid(_target_node):
		_update_positions()

func _update_positions() -> void:
	if not _target_node or not is_instance_valid(_target_node) or not _target_node.is_visible_in_tree():
		_set_shields_blocking(false)
		if target_highlight: target_highlight.visible = false
		if pointer_container: pointer_container.visible = false
		return

	_set_shields_blocking(true)
	if target_highlight: target_highlight.visible = true
	if pointer_container: pointer_container.visible = true

	var rect: Rect2 = _target_node.get_global_rect()
	var vp_size: Vector2 = get_viewport().get_visible_rect().size

	# 1. Update 4 directional input-blocking shields around target
	if shield_top:
		shield_top.position = Vector2.ZERO
		shield_top.size = Vector2(vp_size.x, maxf(0.0, rect.position.y))
	if shield_bottom:
		shield_bottom.position = Vector2(0.0, rect.end.y)
		shield_bottom.size = Vector2(vp_size.x, maxf(0.0, vp_size.y - rect.end.y))
	if shield_left:
		shield_left.position = Vector2(0.0, rect.position.y)
		shield_left.size = Vector2(maxf(0.0, rect.position.x), rect.size.y)
	if shield_right:
		shield_right.position = Vector2(rect.end.x, rect.position.y)
		shield_right.size = Vector2(maxf(0.0, vp_size.x - rect.end.x), rect.size.y)

	# 2. Update Target Highlight frame
	if target_highlight:
		target_highlight.position = rect.position - Vector2(4.0, 4.0)
		target_highlight.size = rect.size + Vector2(8.0, 8.0)

	# 3. Position pointer relative to target center
	var target_center: Vector2 = rect.get_center()
	var offset_dist: float = 38.0

	if _point_dir == Vector2.UP:
		# Pointer is below target pointing up
		_base_pointer_pos = Vector2(target_center.x - 22.0, rect.end.y + offset_dist)
		if pointer_arrow:
			pointer_arrow.text = "▲"
	elif _point_dir == Vector2.DOWN:
		# Pointer is above target pointing down
		_base_pointer_pos = Vector2(target_center.x - 22.0, rect.position.y - offset_dist - 34.0)
		if pointer_arrow:
			pointer_arrow.text = "▼"
	elif _point_dir == Vector2.LEFT:
		# Pointer is to right of target pointing left
		_base_pointer_pos = Vector2(rect.end.x + offset_dist, target_center.y - 22.0)
		if pointer_arrow:
			pointer_arrow.text = "◀"
	else:
		# Pointer is to left of target pointing right
		_base_pointer_pos = Vector2(rect.position.x - offset_dist - 44.0, target_center.y - 22.0)
		if pointer_arrow:
			pointer_arrow.text = "▶"

	if pointer_container:
		pointer_container.position = _base_pointer_pos

	# 4. Position dialogue banner dynamically: takes ONLY needed area, avoiding target
	if banner_panel:
		var max_panel_w: float = minf(vp_size.x - 36.0, 380.0)

		# Calculate natural text width so the box shrink-wraps cleanly
		var str_w: float = 240.0
		if banner_text:
			var font: Font = banner_text.get_theme_font("font")
			var font_size: int = banner_text.get_theme_font_size("font_size")
			if font:
				str_w = font.get_string_size(_full_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x

		var title_w: float = 140.0
		if banner_title:
			var title_font: Font = banner_title.get_theme_font("font")
			var title_font_size: int = banner_title.get_theme_font_size("font_size")
			if title_font:
				title_w = title_font.get_string_size(banner_title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, title_font_size).x

		var desired_w: float = clampf(maxf(str_w + 40.0, title_w + 60.0), 220.0, max_panel_w)

		banner_panel.custom_minimum_size = Vector2(desired_w, 0.0)
		banner_panel.size = Vector2(desired_w, 0.0)
		banner_panel.reset_size()

		var panel_size: Vector2 = banner_panel.size
		var panel_x: float = clampf((vp_size.x - panel_size.x) * 0.5, 18.0, vp_size.x - panel_size.x - 18.0)

		var panel_y: float = 100.0
		if target_center.y > vp_size.y * 0.5:
			# Target in lower half -> put banner comfortably up top
			panel_y = 100.0
		else:
			# Target in upper half -> put banner down bottom
			panel_y = maxf(100.0, vp_size.y - panel_size.y - 100.0)

		banner_panel.position = Vector2(panel_x, panel_y)


func _start_pointer_bob() -> void:
	if _bounce_tween and _bounce_tween.is_valid():
		_bounce_tween.kill()

	if not pointer_container:
		return

	var bob_offset: Vector2 = _point_dir * -12.0
	_bounce_tween = create_tween().set_loops()
	_bounce_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_bounce_tween.tween_property(pointer_container, "position", _base_pointer_pos + bob_offset, 0.45)
	_bounce_tween.tween_property(pointer_container, "position", _base_pointer_pos, 0.45)

func _start_highlight_pulse() -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()

	if not target_highlight:
		return

	target_highlight.modulate.a = 1.0
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.tween_property(target_highlight, "modulate:a", 0.55, 0.6)
	_pulse_tween.tween_property(target_highlight, "modulate:a", 1.0, 0.6)

func _start_voice_and_typewriter(voice_id: String, text_content: String) -> void:
	if _type_tween and _type_tween.is_valid():
		_type_tween.kill()

	_is_typing = true
	var duration: float = 1.8
	var voice_played: bool = false

	# Attempt to load voice track if voice_id provided
	if not voice_id.is_empty():
		var extensions: Array[String] = [".mp3", ".ogg", ".wav"]
		for ext: String in extensions:
			var candidate_path: String = VOICE_BASE_PATH + voice_id + ext
			if ResourceLoader.exists(candidate_path):
				var stream: AudioStream = load(candidate_path) as AudioStream
				if stream and voice_player:
					voice_player.stream = stream
					voice_player.play()
					var stream_len: float = stream.get_length()
					if stream_len > 0.2:
						duration = stream_len
					voice_played = true
				break

	if not voice_played:
		# Dynamic typewriter timing: ~30 characters per second
		var char_count: int = text_content.length()
		duration = clampf(float(char_count) / 30.0, 1.0, 3.5)

	if banner_text:
		banner_text.visible_ratio = 0.0
		_type_tween = create_tween().set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
		_type_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_type_tween.tween_property(banner_text, "visible_ratio", 1.0, duration)
		_type_tween.tween_callback(func() -> void:
			_is_typing = false
			if tap_hint:
				tap_hint.text = ""
		)

func _skip_typewriter() -> void:
	if _type_tween and _type_tween.is_valid():
		_type_tween.kill()
	if banner_text:
		banner_text.visible_ratio = 1.0
	_is_typing = false
	if tap_hint:
		tap_hint.text = ""
