class_name LairHotspotArea
extends Control

## Interactive illustrated building/landmark hotspot for Smuggler's Cove hub.
## Replaces heavy UI buttons with invisible or subtle hotspot zones directly over the cove artwork.

signal hotspot_activated(mode_id: String)

@export var mode_id: String = "campaign"
@export var display_title: String = "Chart House"
@export var required_level: int = 0

@onready var click_detector: Control = %ClickDetector
@onready var hover_highlight: TextureRect = %HoverHighlight
@onready var lock_badge: Control = %LockBadge
@onready var title_tag: Label = %TitleTag

var is_locked: bool = false
var _shake_tween: Tween = null
var _hover_tween: Tween = null

func _ready() -> void:
	refresh_lock_state()

	if click_detector:
		click_detector.gui_input.connect(_on_gui_input)
		click_detector.mouse_entered.connect(_on_mouse_entered)
		click_detector.mouse_exited.connect(_on_mouse_exited)

	if hover_highlight:
		hover_highlight.visible = false
	if title_tag:
		title_tag.visible = false

func refresh_lock_state() -> void:
	var highest_lvl: int = 1
	if GameState:
		if GameState.has_method("get_highest_level_unlocked"):
			highest_lvl = GameState.get_highest_level_unlocked()
		else:
			highest_lvl = GameState.highest_unlocked_level

	is_locked = (required_level > 0 and highest_lvl < required_level)

	if lock_badge:
		lock_badge.visible = is_locked

	if click_detector:
		click_detector.mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN if is_locked else Control.CURSOR_POINTING_HAND

func is_active_locked() -> bool:
	return is_locked

func trigger_activation() -> void:
	if is_locked:
		_show_locked_feedback()
		return

	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("gate_passes")

	hotspot_activated.emit(mode_id)

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
	if hover_highlight:
		hover_highlight.visible = true
		if _hover_tween and _hover_tween.is_valid():
			_hover_tween.kill()
		_hover_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		hover_highlight.modulate.a = 0.0
		_hover_tween.tween_property(hover_highlight, "modulate:a", 1.0, 0.15)

	if title_tag:
		title_tag.text = display_title if not is_locked else "Locked (Lvl %d)" % required_level
		title_tag.visible = true

func _on_mouse_exited() -> void:
	if hover_highlight:
		if _hover_tween and _hover_tween.is_valid():
			_hover_tween.kill()
		_hover_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_hover_tween.tween_property(hover_highlight, "modulate:a", 0.0, 0.15)
		_hover_tween.tween_callback(func() -> void:
			if hover_highlight:
				hover_highlight.visible = false
		)
	if title_tag:
		title_tag.visible = false

func _show_locked_feedback() -> void:
	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("barrel_hits", 0.8, 1.0)

	if lock_badge:
		if _shake_tween and _shake_tween.is_valid():
			_shake_tween.kill()
		var orig_x: float = lock_badge.position.x
		_shake_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_shake_tween.tween_property(lock_badge, "position:x", orig_x + 6.0, 0.04)
		_shake_tween.tween_property(lock_badge, "position:x", orig_x - 6.0, 0.04)
		_shake_tween.tween_property(lock_badge, "position:x", orig_x + 3.0, 0.04)
		_shake_tween.tween_property(lock_badge, "position:x", orig_x - 3.0, 0.04)
		_shake_tween.tween_property(lock_badge, "position:x", orig_x, 0.04)
