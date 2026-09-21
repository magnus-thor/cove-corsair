class_name FrenzyVignette
extends CanvasLayer

## Fullscreen golden-fiery pulsating edge vignette celebration for Fire Frenzy / Overdrive.

@onready var vignette_rect: TextureRect = $VignetteRect
@onready var banner_container: Control = $BannerContainer
@onready var banner_panel: PanelContainer = %BannerPanel

var _pulse_tween: Tween = null
var _fade_tween: Tween = null
var _banner_tween: Tween = null

func _ready() -> void:
	layer = 12
	if vignette_rect:
		vignette_rect.modulate.a = 0.0
		vignette_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if banner_panel:
		banner_panel.modulate.a = 0.0
		banner_panel.scale = Vector2(0.5, 0.5)
		_init_banner_style()
	
	if Engine.has_singleton("GameState") or get_node_or_null("/root/GameState"):
		if not GameState.fire_frenzy_triggered.is_connected(trigger_frenzy):
			GameState.fire_frenzy_triggered.connect(trigger_frenzy)

func _process(_delta: float) -> void:
	if banner_panel and banner_panel.visible and banner_panel.modulate.a > 0.0:
		_update_banner_position()

func _update_banner_position() -> void:
	if not banner_container:
		return
		
	var cam: Camera3D = get_viewport().get_camera_3d() if get_viewport() else null
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D if get_tree() else null
	if player and is_instance_valid(player) and cam and is_instance_valid(cam) and not cam.is_position_behind(player.global_position):
		var target_pos: Vector3 = player.global_position + Vector3(0.0, 2.2, -0.4)
		var screen_pos: Vector2 = cam.unproject_position(target_pos)
		banner_container.global_position = screen_pos
	else:
		var vp_rect: Rect2 = get_viewport().get_visible_rect() if get_viewport() else Rect2(0, 0, 1280, 720)
		banner_container.position = Vector2(vp_rect.size.x * 0.5, vp_rect.size.y * 0.65)

func _init_banner_style() -> void:
	if not banner_panel:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.06, 0.02, 0.88)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(1.0, 0.82, 0.25, 0.95)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_bottom_left = 12
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	style.shadow_color = Color(1.0, 0.7, 0.1, 0.4)
	style.shadow_size = 10
	banner_panel.add_theme_stylebox_override("panel", style)

func trigger_frenzy(duration: float = 6.0) -> void:
	if not vignette_rect:
		return
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	if _banner_tween and _banner_tween.is_valid():
		_banner_tween.kill()
		
	vignette_rect.visible = true
	
	# Fade in golden glow
	_fade_tween = create_tween()
	_fade_tween.tween_property(vignette_rect, "modulate:a", 0.70, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# Banner celebratory punch-in
	if banner_panel:
		_update_banner_position()
		banner_panel.visible = true
		banner_panel.scale = Vector2(0.6, 0.6)
		banner_panel.modulate.a = 0.0
		_banner_tween = create_tween()
		_banner_tween.tween_property(banner_panel, "modulate:a", 1.0, 0.15)
		_banner_tween.parallel().tween_property(banner_panel, "scale", Vector2(1.1, 1.1), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_banner_tween.tween_property(banner_panel, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_SINE)
		_banner_tween.tween_interval(maxf(1.0, duration - 1.2))
		_banner_tween.tween_property(banner_panel, "modulate:a", 0.0, 0.45)
		_banner_tween.parallel().tween_property(banner_panel, "scale", Vector2(0.9, 0.9), 0.45)

	# Gentle golden breathing during frenzy
	var loops: int = maxi(1, int(duration * 2.0))
	_pulse_tween = create_tween().set_loops(loops)
	_pulse_tween.tween_property(vignette_rect, "modulate:a", 0.35, 0.3).set_trans(Tween.TRANS_SINE)
	_pulse_tween.tween_property(vignette_rect, "modulate:a", 0.65, 0.3).set_trans(Tween.TRANS_SINE)
	
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
