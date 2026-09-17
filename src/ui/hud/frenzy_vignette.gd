class_name FrenzyVignette
extends CanvasLayer

## Fullscreen golden-fiery pulsating edge vignette celebration for Fire Frenzy / Overdrive.

@onready var vignette_rect: TextureRect = $VignetteRect

var _pulse_tween: Tween = null
var _fade_tween: Tween = null

func _ready() -> void:
	layer = 12
	if vignette_rect:
		vignette_rect.modulate.a = 0.0
		vignette_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	if Engine.has_singleton("GameState") or get_node_or_null("/root/GameState"):
		if not GameState.fire_frenzy_triggered.is_connected(trigger_frenzy):
			GameState.fire_frenzy_triggered.connect(trigger_frenzy)

func trigger_frenzy(duration: float = 6.0) -> void:
	if not vignette_rect:
		return
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
		
	vignette_rect.visible = true
	
	# Fade in golden glow
	_fade_tween = create_tween()
	_fade_tween.tween_property(vignette_rect, "modulate:a", 0.75, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# Gentle pulsing during frenzy
	var loops: int = maxi(1, int(duration * 2.0))
	_pulse_tween = create_tween().set_loops(loops)
	_pulse_tween.tween_property(vignette_rect, "modulate:a", 0.42, 0.25).set_trans(Tween.TRANS_SINE)
	_pulse_tween.tween_property(vignette_rect, "modulate:a", 0.78, 0.25).set_trans(Tween.TRANS_SINE)
	
	# Fade out cleanly upon expiration
	var fade_time: float = maxf(0.1, duration - 0.45)
	var timer := get_tree().create_timer(fade_time)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(vignette_rect):
			if _pulse_tween and _pulse_tween.is_valid():
				_pulse_tween.kill()
			var out_tween := create_tween()
			out_tween.tween_property(vignette_rect, "modulate:a", 0.0, 0.45)
	)
