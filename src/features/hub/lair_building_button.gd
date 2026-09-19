class_name LairBuildingButton
extends Control

## Modular Building Card Component for 2D Town Canvas.
## Displays building title, subtitle, icon, and handles level lock / padlock gating.

signal building_activated(mode_id: String)

@export var mode_id: String = "campaign"
@export var title_text: String = "Chart House"
@export var subtitle_text: String = "Campaign (45 Levels)"
@export var icon_texture: Texture2D = null
@export var required_level: int = 0
@export var action_text: String = "ENTER"

@onready var card_panel: PanelContainer = %CardPanel
@onready var icon_rect: TextureRect = %IconRect
@onready var title_label: Label = %TitleLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var action_button: Button = %ActionButton
@onready var lock_overlay: PanelContainer = %LockOverlay
@onready var lock_label: Label = %LockLabel
@onready var lock_icon: TextureRect = %LockIcon

var _is_locked: bool = false
var _hover_tween: Tween = null
var _base_scale: Vector2 = Vector2.ONE

func _ready() -> void:
	_base_scale = scale
	_apply_content()
	refresh_lock_state()

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)

	if action_button:
		action_button.pressed.connect(trigger_activation)

func _apply_content() -> void:
	if title_label:
		title_label.text = title_text.to_upper()
	if subtitle_label:
		subtitle_label.text = subtitle_text
	if icon_rect and icon_texture != null:
		icon_rect.texture = icon_texture
	if action_button:
		action_button.text = action_text

func refresh_lock_state() -> void:
	var cur_level: int = GameState.highest_unlocked_level if GameState else 1
	_is_locked = (required_level > 0 and cur_level < required_level)

	if lock_overlay:
		lock_overlay.visible = _is_locked
		if _is_locked and lock_label:
			lock_label.text = "UNLOCKS AT LEVEL %d" % required_level

	if action_button:
		action_button.disabled = _is_locked

	mouse_default_cursor_shape = Control.CURSOR_FORBIDDEN if _is_locked else Control.CURSOR_POINTING_HAND

func is_locked() -> bool:
	return _is_locked

func trigger_activation() -> void:
	if _is_locked:
		_play_locked_shake()
		return

	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("gate_passes")

	_play_click_pop()
	building_activated.emit(mode_id)

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
	if _is_locked:
		return
	if _hover_tween and _hover_tween.is_valid():
		_hover_tween.kill()
	_hover_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(self, "scale", _base_scale * 1.025, 0.16)
	if card_panel:
		_hover_tween.tween_property(card_panel, "modulate", Color(1.1, 1.08, 0.95, 1.0), 0.16)

func _on_mouse_exited() -> void:
	if _hover_tween and _hover_tween.is_valid():
		_hover_tween.kill()
	_hover_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(self, "scale", _base_scale, 0.16)
	if card_panel:
		_hover_tween.tween_property(card_panel, "modulate", Color.WHITE, 0.16)

func _play_click_pop() -> void:
	var pop := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(self, "scale", _base_scale * 0.97, 0.08)
	pop.tween_property(self, "scale", _base_scale * 1.02, 0.12)
	pop.tween_property(self, "scale", _base_scale, 0.1)

func _play_locked_shake() -> void:
	if AudioManager and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("barrel_hits", 0.8, 1.0)
	var shake := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var orig_x: float = position.x
	shake.tween_property(self, "position:x", orig_x - 8.0, 0.05)
	shake.tween_property(self, "position:x", orig_x + 8.0, 0.05)
	shake.tween_property(self, "position:x", orig_x - 4.0, 0.04)
	shake.tween_property(self, "position:x", orig_x + 4.0, 0.04)
	shake.tween_property(self, "position:x", orig_x, 0.04)
