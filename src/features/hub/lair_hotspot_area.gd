class_name LairHotspotArea
extends Control

## Interactive illustrated building/landmark hotspot pin for Smuggler's Cove hub.
## Combines a full-building clickable detector zone with a stylish pirate pin badge.

signal hotspot_activated(mode_id: String)

@export var mode_id: String = "campaign"
@export var display_title: String = "Chart House"
@export var display_subtitle: String = "Campaign"
@export var required_level: int = 0
@export var theme_accent_color: Color = Color(0.96, 0.62, 0.04) # Default warm amber
@export var icon_texture: Texture2D = null
@export var idle_bob_phase: float = 0.0
@export var pin_offset: Vector2 = Vector2.ZERO

@onready var click_detector: Control = %ClickDetector as Control
@onready var pin_container: Control = %PinContainer as Control
@onready var glow_ring: TextureRect = %GlowRing as TextureRect
@onready var badge_panel: PanelContainer = %BadgePanel as PanelContainer
@onready var icon_texture_rect: TextureRect = %IconTexture as TextureRect
@onready var lock_icon_rect: TextureRect = %LockIcon as TextureRect
@onready var lock_badge: Control = %LockIcon as Control
@onready var title_label: Label = %TitleLabel as Label
@onready var subtitle_label: Label = %SubtitleLabel as Label

var is_locked: bool = false
var _shake_tween: Tween = null
var _bob_tween: Tween = null
var _hover_tween: Tween = null

func _ready() -> void:
	_apply_styling()
	refresh_lock_state()
	_setup_events()
	_start_idle_bob()

func _apply_styling() -> void:
	if pin_container and pin_offset != Vector2.ZERO:
		pin_container.position += pin_offset

	if glow_ring:
		glow_ring.modulate = Color(theme_accent_color.r, theme_accent_color.g, theme_accent_color.b, 0.4)

	if badge_panel:
		var style := badge_panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		if style:
			style.border_color = theme_accent_color
			badge_panel.add_theme_stylebox_override("panel", style)

	if icon_texture_rect and icon_texture:
		icon_texture_rect.texture = icon_texture
		icon_texture_rect.modulate = theme_accent_color

	if title_label:
		title_label.text = display_title.to_upper()

	if subtitle_label:
		subtitle_label.text = display_subtitle.to_upper()

func refresh_lock_state() -> void:
	var highest_lvl: int = 1
	if GameState:
		if GameState.has_method("get_highest_level_unlocked"):
			highest_lvl = GameState.get_highest_level_unlocked()
		elif "highest_unlocked_level" in GameState:
			highest_lvl = int(GameState.highest_unlocked_level)

	is_locked = (required_level > 0 and highest_lvl < required_level)

	if lock_icon_rect and icon_texture_rect:
		lock_icon_rect.visible = is_locked
		icon_texture_rect.visible = not is_locked

	if subtitle_label:
		if is_locked:
			subtitle_label.text = "UNLOCKS AT LVL %d" % required_level
			subtitle_label.modulate = Color(0.9, 0.4, 0.4, 1.0)
		else:
			subtitle_label.text = display_subtitle.to_upper()
			subtitle_label.modulate = Color(0.75, 0.85, 0.95, 0.9)

	if click_detector:
		click_detector.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN if is_locked else Control.CURSOR_POINTING_HAND

func is_active_locked() -> bool:
	return is_locked

func trigger_activation() -> void:
	if is_locked:
		_show_locked_feedback()
		return

	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("gate_passes", 1.0, 1.0)

	_play_press_punch()
	hotspot_activated.emit(mode_id)

func _setup_events() -> void:
	if click_detector:
		click_detector.gui_input.connect(_on_gui_input)
		click_detector.mouse_entered.connect(_on_mouse_entered)
		click_detector.mouse_exited.connect(_on_mouse_exited)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_ev := event as InputEventMouseButton
		if mouse_ev.button_index == MOUSE_BUTTON_LEFT and mouse_ev.pressed:
			trigger_activation()
	elif event is InputEventScreenTouch:
		var touch_ev := event as InputEventScreenTouch
		if touch_ev.pressed:
			trigger_activation()

func _on_mouse_entered() -> void:
	if _hover_tween and _hover_tween.is_valid():
		_hover_tween.kill()

	_hover_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if badge_panel:
		_hover_tween.tween_property(badge_panel, "scale", Vector2(1.06, 1.06), 0.15)
	if glow_ring:
		_hover_tween.tween_property(glow_ring, "modulate:a", 0.75, 0.15)

func _on_mouse_exited() -> void:
	if _hover_tween and _hover_tween.is_valid():
		_hover_tween.kill()

	_hover_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if badge_panel:
		_hover_tween.tween_property(badge_panel, "scale", Vector2(1.0, 1.0), 0.15)
	if glow_ring:
		_hover_tween.tween_property(glow_ring, "modulate:a", 0.4, 0.15)

func _start_idle_bob() -> void:
	if not pin_container:
		return

	var start_y: float = pin_container.position.y
	_bob_tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if idle_bob_phase > 0.0:
		_bob_tween.tween_interval(idle_bob_phase)
	_bob_tween.tween_property(pin_container, "position:y", start_y - 4.0, 1.8)
	_bob_tween.tween_property(pin_container, "position:y", start_y + 4.0, 1.8)
	_bob_tween.tween_property(pin_container, "position:y", start_y, 1.8)

func _play_press_punch() -> void:
	if not badge_panel:
		return
	var punch_tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	punch_tween.tween_property(badge_panel, "scale", Vector2(1.14, 1.14), 0.08)
	punch_tween.tween_property(badge_panel, "scale", Vector2(1.0, 1.0), 0.16)

func _show_locked_feedback() -> void:
	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("barrel_hits", 0.8, 1.0)

	if badge_panel:
		if _shake_tween and _shake_tween.is_valid():
			_shake_tween.kill()
		var orig_pos: Vector2 = badge_panel.position
		_shake_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_shake_tween.tween_property(badge_panel, "position:x", orig_pos.x + 8.0, 0.04)
		_shake_tween.tween_property(badge_panel, "position:x", orig_pos.x - 8.0, 0.04)
		_shake_tween.tween_property(badge_panel, "position:x", orig_pos.x + 4.0, 0.04)
		_shake_tween.tween_property(badge_panel, "position:x", orig_pos.x - 4.0, 0.04)
		_shake_tween.tween_property(badge_panel, "position:x", orig_pos.x, 0.04)
