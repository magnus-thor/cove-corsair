class_name RiverMap
extends Control

## Animated River Progression Map for Cove Corsair
## Features scrollable curved river spline, milestone nodes (1 to 6+),
## dynamic vessel advancement animation upon victory, and level details popup modal.

signal level_selected(level_num: int)
signal sail_requested(level_num: int)

@onready var scroll_container: ScrollContainer = %ScrollContainer
@onready var map_canvas: Control = %MapCanvas
@onready var river_path_layer: Control = %RiverPathLayer
@onready var terrain_layer: Control = %TerrainLayer
@onready var nodes_layer: Control = %NodesLayer
@onready var mini_vessel: Node2D = %MiniVessel
@onready var mini_vessel_icon: TextureRect = %MiniVesselIcon
@onready var unlock_vfx: Node2D = %UnlockVFX

# Level Detail Popup
@onready var popup_scrim: ColorRect = %PopupScrim
@onready var popup_panel: PanelContainer = %PopupPanel
@onready var popup_title: Label = %PopupTitle
@onready var popup_num: Label = %PopupNum
@onready var popup_biome: Label = %PopupBiome
@onready var popup_score: Label = %PopupScore
@onready var popup_boss_tag: PanelContainer = %PopupBossTag
@onready var popup_boss_label: Label = %PopupBossLabel
@onready var btn_set_sail: Button = %BtnSetSail
@onready var btn_close_popup: Button = %BtnClosePopup

const FONT_CARTER: FontFile = preload("res://assets/fonts/CarterOne.ttf")
const FONT_LILITA: FontFile = preload("res://assets/fonts/LilitaOne-Regular.ttf")
const ICON_PADLOCK: Texture2D = preload("res://assets/sprites/ui/theme/icon_padlock.svg")
const ICON_CHECKMARK: Texture2D = preload("res://assets/sprites/ui/theme/icon_checkmark.svg")
const ICON_SKULL: Texture2D = preload("res://assets/sprites/ui/hud_skull_icon.svg")
const ICON_COIN: Texture2D = preload("res://assets/sprites/ui/coin_icon.svg")
const ICON_BOAT_FALLBACK: Texture2D = preload("res://assets/sprites/ui/hud_boat_icon.svg")

const MILESTONES: Dictionary = {
	1: {
		"name": "SMUGGLER'S RUN",
		"biome": "Tropical Reef",
		"target_dist": 200,
		"pos": Vector2(360, 3800),
		"is_boss": true,
		"boss_name": "Captain Ironjaw"
	},
	2: {
		"name": "BLACK TIDE BAYOU",
		"biome": "Murky Bayou",
		"target_dist": 200,
		"pos": Vector2(520, 3500),
		"is_boss": true,
		"boss_name": "The Phantom Dredge"
	},
	3: {
		"name": "BRIMSTONE BASTION",
		"biome": "Volcanic Bastion",
		"target_dist": 200,
		"pos": Vector2(200, 3200),
		"is_boss": true,
		"boss_name": "The Siege Fortress"
	},
	4: {
		"name": "SMUGGLER'S NIGHTMARE",
		"biome": "Stormy Coast",
		"target_dist": 300,
		"pos": Vector2(520, 2900),
		"is_boss": true,
		"boss_name": "Captain Ironjaw (Enraged)"
	},
	5: {
		"name": "BLACK TIDE ABYSS",
		"biome": "Abyssal Mire",
		"target_dist": 300,
		"pos": Vector2(200, 2600),
		"is_boss": true,
		"boss_name": "The Phantom Dredge"
	},
	6: {
		"name": "BRIMSTONE INFERNO",
		"biome": "Lava Caldera",
		"target_dist": 300,
		"pos": Vector2(360, 2300),
		"is_boss": true,
		"boss_name": "The Siege Fortress"
	},
	7: {
		"name": "CORAL CATACLYSM",
		"biome": "Tropical Atoll",
		"target_dist": 350,
		"pos": Vector2(520, 2000),
		"is_boss": false,
		"boss_name": ""
	},
	8: {
		"name": "SERPENT'S MIRE",
		"biome": "Deep Bayou",
		"target_dist": 350,
		"pos": Vector2(200, 1700),
		"is_boss": false,
		"boss_name": ""
	},
	9: {
		"name": "ASHEN STRAITS",
		"biome": "Volcanic Straits",
		"target_dist": 350,
		"pos": Vector2(520, 1400),
		"is_boss": false,
		"boss_name": ""
	},
	10: {
		"name": "SKULL REEF PASS",
		"biome": "Outer Reefs",
		"target_dist": 400,
		"pos": Vector2(200, 1100),
		"is_boss": false,
		"boss_name": ""
	},
	11: {
		"name": "DREADWATER GORGE",
		"biome": "Dread Bayou",
		"target_dist": 400,
		"pos": Vector2(520, 800),
		"is_boss": false,
		"boss_name": ""
	},
	12: {
		"name": "BONEBEARD'S LAIR",
		"biome": "Infernal Caldera",
		"target_dist": 400,
		"pos": Vector2(360, 500),
		"is_boss": true,
		"boss_name": "Captain Bone-Beard"
	}
}

var river_curve: Curve2D = Curve2D.new()
var node_controls: Dictionary = {}
var vessel_bob_tween: Tween
var is_animating_travel: bool = false
var popup_selected_level: int = 1

func _ready() -> void:
	_setup_river_spline()
	_setup_terrain_draw()
	_setup_river_path_draw()
	_build_milestone_nodes()
	_setup_mini_vessel()
	_setup_popup()
	
	# Automatically anchor scroll position to current active level node on launch
	var start_lvl = clamp(GameState.current_selected_level, 1, 12)
	_focus_on_level(start_lvl, false)
	
	call_deferred("_handle_initial_presentation")

func _setup_river_spline() -> void:
	river_curve.clear_points()
	# Define serpentine river control points through all 12 milestone nodes from harbor to peak
	var points: Array[Vector2] = [
		Vector2(360, 4050), # Harbor start
		Vector2(360, 3800), # Node 1 (Smuggler's Run)
		Vector2(460, 3650), # Turn 1
		Vector2(520, 3500), # Node 2 (Black Tide Bayou)
		Vector2(380, 3350), # Turn 2
		Vector2(200, 3200), # Node 3 (Brimstone Bastion)
		Vector2(380, 3050), # Turn 3
		Vector2(520, 2900), # Node 4 (Smuggler's Nightmare)
		Vector2(380, 2750), # Turn 4
		Vector2(200, 2600), # Node 5 (Black Tide Abyss)
		Vector2(280, 2450), # Turn 5
		Vector2(360, 2300), # Node 6 (Brimstone Inferno)
		Vector2(460, 2150), # Turn 6
		Vector2(520, 2000), # Node 7 (Coral Cataclysm)
		Vector2(380, 1850), # Turn 7
		Vector2(200, 1700), # Node 8 (Serpent's Mire)
		Vector2(380, 1550), # Turn 8
		Vector2(520, 1400), # Node 9 (Ashen Straits)
		Vector2(380, 1250), # Turn 9
		Vector2(200, 1100), # Node 10 (Skull Reef Pass)
		Vector2(380, 950),  # Turn 10
		Vector2(520, 800),  # Node 11 (Dreadwater Gorge)
		Vector2(440, 650),  # Turn 11
		Vector2(360, 500),  # Node 12 (Bonebeard's Lair - Final Boss)
		Vector2(360, 200)   # Final anchorage peak
	]
	
	for i in range(points.size()):
		var p = points[i]
		var in_tangent = Vector2.ZERO
		var out_tangent = Vector2.ZERO
		
		if i > 0 and i < points.size() - 1:
			var prev_p = points[i - 1]
			var next_p = points[i + 1]
			var diff = (next_p - prev_p) * 0.28
			in_tangent = -diff
			out_tangent = diff
		elif i == 0:
			out_tangent = Vector2(0, -60)
		elif i == points.size() - 1:
			in_tangent = Vector2(0, 60)
			
		river_curve.add_point(p, in_tangent, out_tangent)
	river_curve.bake_interval = 4.0

func _setup_terrain_draw() -> void:
	if terrain_layer:
		terrain_layer.draw.connect(_on_terrain_draw)

func _setup_river_path_draw() -> void:
	if river_path_layer:
		river_path_layer.draw.connect(_on_river_path_draw)

func _on_terrain_draw() -> void:
	var canvas_rect = Rect2(Vector2.ZERO, Vector2(720, 4200))
	# Lush vintage pirate chart background
	terrain_layer.draw_rect(canvas_rect, Color(0.93, 0.88, 0.77, 1.0), true)
	
	# Decorative map grid & nautical borders
	var line_color = Color(0.82, 0.75, 0.62, 0.45)
	for y in range(100, 4180, 160):
		terrain_layer.draw_line(Vector2(40, y), Vector2(680, y), line_color, 1.5)
	for x in range(120, 680, 120):
		terrain_layer.draw_line(Vector2(x, 60), Vector2(x, 4140), line_color, 1.5)
		
	# Biome background tint zones (bottom to top across 4200px)
	# Bottom (Tropical Reef L1): Cyan parchment wash
	terrain_layer.draw_rect(Rect2(0, 3600, 720, 600), Color(0.2, 0.65, 0.7, 0.10), true)
	# Bayou & Bastion (L2-L3): Mossy wash
	terrain_layer.draw_rect(Rect2(0, 3000, 720, 600), Color(0.3, 0.5, 0.35, 0.08), true)
	# Stormy Coast & Abyss (L4-L5): Ocean slate wash
	terrain_layer.draw_rect(Rect2(0, 2400, 720, 600), Color(0.2, 0.3, 0.45, 0.09), true)
	# Brimstone & Coral (L6-L7): Volcanic ash wash
	terrain_layer.draw_rect(Rect2(0, 1800, 720, 600), Color(0.7, 0.25, 0.15, 0.12), true)
	# Serpent Mire & Ashen Straits (L8-L9): Murky brimstone wash
	terrain_layer.draw_rect(Rect2(0, 1200, 720, 600), Color(0.3, 0.45, 0.3, 0.10), true)
	# Outer Reef & Dreadwater (L10-L11): Deep slate wash
	terrain_layer.draw_rect(Rect2(0, 600, 720, 600), Color(0.2, 0.35, 0.5, 0.10), true)
	# Caldera Peak (L12 Bonebeard): Burning caldera crimson wash
	terrain_layer.draw_rect(Rect2(0, 0, 720, 600), Color(0.75, 0.2, 0.1, 0.14), true)

func _on_river_path_draw() -> void:
	var baked = river_curve.get_baked_points()
	if baked.size() < 2:
		return
		
	# 1. Outer sandy riverbank border
	river_path_layer.draw_polyline(baked, Color(0.74, 0.63, 0.44, 0.95), 116.0, true)
	# 2. Outer shoreline shadow
	river_path_layer.draw_polyline(baked, Color(0.12, 0.38, 0.48, 0.85), 98.0, true)
	# 3. Vibrant tropical deep-river water channel
	river_path_layer.draw_polyline(baked, Color(0.16, 0.52, 0.65, 0.98), 84.0, true)
	# 4. Sunlit water current core
	river_path_layer.draw_polyline(baked, Color(0.24, 0.68, 0.82, 0.90), 52.0, true)
	# 5. Shimmer flow highlight center dash
	river_path_layer.draw_dashed_line(baked[0], baked[baked.size() - 1], Color(0.95, 0.95, 0.80, 0.65), 5.0, 14.0, true)

	# Stepping stone waypoints along the baked curve
	var total_len = river_curve.get_baked_length()
	var step = 45.0
	var cur = step
	while cur < total_len - 30.0:
		var pt = river_curve.sample_baked(cur)
		river_path_layer.draw_circle(pt, 4.0, Color(0.96, 0.88, 0.55, 0.6))
		cur += step

func _build_milestone_nodes() -> void:
	for child in nodes_layer.get_children():
		child.queue_free()
	node_controls.clear()
	
	for lvl in MILESTONES.keys():
		var data = MILESTONES[lvl]
		var node_btn = _create_milestone_button(lvl, data)
		nodes_layer.add_child(node_btn)
		node_controls[lvl] = node_btn
		
	_refresh_all_node_states()

func _create_milestone_button(lvl: int, data: Dictionary) -> Control:
	var container = Control.new()
	container.name = "Node_%d" % lvl
	container.position = data["pos"]
	container.custom_minimum_size = Vector2(160, 160)
	container.pivot_offset = Vector2(80, 80)
	container.set_anchors_preset(Control.PRESET_TOP_LEFT)
	
	# Main touch button
	var btn = TextureButton.new()
	btn.name = "TouchButton"
	btn.custom_minimum_size = Vector2(110, 110)
	btn.position = Vector2(25, 25)
	btn.pivot_offset = Vector2(55, 55)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.focus_mode = Control.FOCUS_NONE
	btn.pressed.connect(func(): _on_node_pressed(lvl))
	container.add_child(btn)
	
	# Pulsing active aura (behind button)
	var aura = ColorRect.new()
	aura.name = "ActiveAura"
	aura.custom_minimum_size = Vector2(126, 126)
	aura.position = Vector2(17, 17)
	aura.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aura.color = Color(1.0, 0.82, 0.2, 0.45)
	aura.pivot_offset = Vector2(63, 63)
	aura.visible = false
	container.add_child(aura)
	container.move_child(aura, 0)
	
	# Node Disc Background Panel
	var disc_panel = Panel.new()
	disc_panel.name = "DiscPanel"
	disc_panel.custom_minimum_size = Vector2(96, 96)
	disc_panel.position = Vector2(32, 32)
	disc_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(disc_panel)
	
	# Level Number Label (inside disc)
	var num_label = Label.new()
	num_label.name = "NumLabel"
	num_label.custom_minimum_size = Vector2(96, 96)
	num_label.position = Vector2(32, 32)
	num_label.text = str(lvl)
	num_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	num_label.add_theme_font_override("font", FONT_CARTER)
	num_label.add_theme_font_size_override("font_size", 42)
	num_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(num_label)
	
	# Status Badge (Brass Checkmark for completed, Padlock for locked)
	var status_icon = TextureRect.new()
	status_icon.name = "StatusIcon"
	status_icon.custom_minimum_size = Vector2(44, 44)
	status_icon.position = Vector2(58, 20)
	status_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	status_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	status_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(status_icon)
	
	# Boss Banner Ribbon (for Level 3 & Level 6)
	if data["is_boss"]:
		var boss_banner = PanelContainer.new()
		boss_banner.name = "BossBanner"
		boss_banner.position = Vector2(-20, -18)
		boss_banner.custom_minimum_size = Vector2(200, 36)
		boss_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		var banner_style = StyleBoxFlat.new()
		banner_style.bg_color = Color(0.72, 0.12, 0.12, 0.95)
		banner_style.set_border_width_all(2)
		banner_style.border_color = Color(1.0, 0.85, 0.35, 1.0)
		banner_style.set_corner_radius_all(10)
		banner_style.shadow_size = 4
		banner_style.shadow_offset = Vector2(0, 2)
		boss_banner.add_theme_stylebox_override("panel", banner_style)
		
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 6)
		hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		
		var skull = TextureRect.new()
		skull.custom_minimum_size = Vector2(22, 22)
		skull.texture = ICON_SKULL
		skull.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		skull.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hbox.add_child(skull)
		
		var b_lbl = Label.new()
		b_lbl.text = "BOSS" if lvl == 3 else "FINAL BOSS"
		b_lbl.add_theme_font_override("font", FONT_LILITA)
		b_lbl.add_theme_font_size_override("font_size", 20)
		b_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7, 1.0))
		hbox.add_child(b_lbl)
		
		boss_banner.add_child(hbox)
		container.add_child(boss_banner)
		
	# Expedition Name Label (Parchment title beneath node)
	var title_lbl = Label.new()
	title_lbl.name = "TitleLabel"
	title_lbl.position = Vector2(-40, 126)
	title_lbl.custom_minimum_size = Vector2(240, 28)
	title_lbl.text = data["name"]
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_override("font", FONT_LILITA)
	title_lbl.add_theme_font_size_override("font_size", 20)
	title_lbl.add_theme_color_override("font_color", Color(0.24, 0.14, 0.08, 1.0))
	title_lbl.add_theme_constant_override("outline_size", 4)
	title_lbl.add_theme_color_override("font_outline_color", Color(0.98, 0.94, 0.88, 1.0))
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(title_lbl)
	
	return container

func _refresh_all_node_states() -> void:
	var unlocked_max = GameState.highest_unlocked_level
	var selected = GameState.current_selected_level
	
	for lvl in MILESTONES.keys():
		var container = node_controls.get(lvl)
		if not container:
			continue
			
		var disc_panel: Panel = container.get_node("DiscPanel")
		var num_label: Label = container.get_node("NumLabel")
		var status_icon: TextureRect = container.get_node("StatusIcon")
		var active_aura: ColorRect = container.get_node("ActiveAura")
		
		var disc_style = StyleBoxFlat.new()
		disc_style.set_corner_radius_all(48)
		disc_style.shadow_size = 6
		disc_style.shadow_offset = Vector2(0, 4)
		
		if lvl < unlocked_max:
			# STATE: COMPLETED (Brass checkmark)
			disc_style.bg_color = Color(0.18, 0.46, 0.28, 1.0)
			disc_style.set_border_width_all(5)
			disc_style.border_color = Color(0.92, 0.78, 0.32, 1.0)
			
			num_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.82, 0.9))
			status_icon.texture = ICON_CHECKMARK
			status_icon.visible = true
			status_icon.modulate = Color.WHITE
			active_aura.visible = false
			
		elif lvl == unlocked_max:
			# STATE: ACTIVE / CURRENT (Glowing Crest)
			disc_style.bg_color = Color(0.92, 0.68, 0.14, 1.0)
			disc_style.set_border_width_all(6)
			disc_style.border_color = Color(1.0, 0.95, 0.65, 1.0)
			disc_style.shadow_color = Color(1.0, 0.8, 0.2, 0.7)
			disc_style.shadow_size = 12
			
			num_label.add_theme_color_override("font_color", Color(0.25, 0.12, 0.04, 1.0))
			status_icon.visible = false
			active_aura.visible = true
			_pulse_active_aura(active_aura)
			
		else:
			# STATE: LOCKED (Chained Padlocks)
			disc_style.bg_color = Color(0.32, 0.32, 0.36, 0.95)
			disc_style.set_border_width_all(4)
			disc_style.border_color = Color(0.20, 0.20, 0.22, 1.0)
			
			num_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6, 0.6))
			status_icon.texture = ICON_PADLOCK
			status_icon.visible = true
			status_icon.modulate = Color(0.9, 0.9, 0.95, 0.9)
			active_aura.visible = false
			
		disc_panel.add_theme_stylebox_override("panel", disc_style)

func _pulse_active_aura(aura: ColorRect) -> void:
	if aura.has_meta("pulse_tween"):
		var old_t: Tween = aura.get_meta("pulse_tween")
		if old_t and old_t.is_valid():
			old_t.kill()
			
	var t = create_tween().set_loops()
	t.tween_property(aura, "scale", Vector2(1.18, 1.18), 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(aura, "modulate:a", 0.3, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(aura, "scale", Vector2(0.96, 0.96), 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(aura, "modulate:a", 0.7, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	aura.set_meta("pulse_tween", t)

func _setup_mini_vessel() -> void:
	if not mini_vessel or not mini_vessel_icon:
		return
		
	var active_id = GameState.active_vessel
	var tex_loaded = false
	if active_id in GameState.VESSEL_CATALOG:
		var p_tex = GameState.VESSEL_CATALOG[active_id].get("preview_texture", "")
		if ResourceLoader.exists(p_tex):
			var t = ResourceLoader.load(p_tex) as Texture2D
			if t:
				mini_vessel_icon.texture = t
				tex_loaded = true
				
	if not tex_loaded:
		mini_vessel_icon.texture = ICON_BOAT_FALLBACK
		
	_start_vessel_idle_bob()

func _start_vessel_idle_bob() -> void:
	if vessel_bob_tween and vessel_bob_tween.is_valid():
		vessel_bob_tween.kill()
		
	vessel_bob_tween = create_tween().set_loops()
	vessel_bob_tween.tween_property(mini_vessel_icon, "position:y", -6.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	vessel_bob_tween.tween_property(mini_vessel_icon, "position:y", 2.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _handle_initial_presentation() -> void:
	if GameState.just_cleared_level:
		_play_advancement_sequence()
	else:
		_focus_on_level(GameState.current_selected_level, false)
		var target_pos = _get_node_dock_pos(GameState.current_selected_level)
		mini_vessel.position = target_pos

func _get_node_dock_pos(lvl: int) -> Vector2:
	if MILESTONES.has(lvl):
		# Position miniature vessel slightly offset near the milestone node
		return MILESTONES[lvl]["pos"] + Vector2(75, 45)
	return Vector2(360, 3800)

func _focus_on_level(lvl: int, animate: bool = true, duration: float = 0.8) -> void:
	if not scroll_container or not MILESTONES.has(lvl):
		return
		
	var node_y = MILESTONES[lvl]["pos"].y
	var viewport_h = scroll_container.size.y
	if viewport_h <= 0:
		viewport_h = 1000.0
	var canvas_h = map_canvas.custom_minimum_size.y if map_canvas else 4200.0
	var target_scroll = clamp(int(node_y - viewport_h * 0.5), 0, int(canvas_h - viewport_h))
	
	if animate:
		var st = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		st.tween_property(scroll_container, "scroll_vertical", target_scroll, duration)
	else:
		scroll_container.scroll_vertical = target_scroll

func _play_advancement_sequence() -> void:
	is_animating_travel = true
	var from_lvl = clamp(GameState.last_cleared_level, 1, 12)
	var to_lvl = clamp(GameState.highest_unlocked_level, 1, 12)
	
	if from_lvl == to_lvl and to_lvl > 1:
		from_lvl = to_lvl - 1
		
	# 1. Place camera and vessel at the just-cleared node
	_focus_on_level(from_lvl, false)
	var start_pos = _get_node_dock_pos(from_lvl)
	var end_pos = _get_node_dock_pos(to_lvl)
	mini_vessel.position = start_pos
	
	# 2. Wait 0.35s before beginning the voyage
	await get_tree().create_timer(0.35, true, false, true).timeout
	
	# Sample offsets along spline
	var from_offset = river_curve.get_closest_offset(start_pos)
	var to_offset = river_curve.get_closest_offset(end_pos)
	
	# Play water cruise SFX
	AudioManager.play_sfx("water_splashes", 0.95, 1.05)
	
	# 3. Tween camera scroll and vessel along river spline over 1.2 seconds
	var travel_duration = 1.2
	_focus_on_level(to_lvl, true, travel_duration)
	
	var travel_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	travel_tween.tween_method(func(offset: float):
		var pt = river_curve.sample_baked(offset)
		var next_pt = river_curve.sample_baked(offset + 6.0)
		var dir = (next_pt - pt).normalized()
		mini_vessel.position = pt
		if dir.length_squared() > 0.01:
			mini_vessel.rotation = lerp_angle(mini_vessel.rotation, dir.angle() + PI/2, 0.25)
	, from_offset, to_offset, travel_duration)
	
	await travel_tween.finished
	
	# 4. Arrival on the newly unlocked node
	mini_vessel.position = end_pos
	mini_vessel.rotation = 0.0
	
	# Emit celebratory sound
	AudioManager.play_sfx("coin_pickups", 1.2, 1.4, 2.5)
	AudioManager.play_sfx("gate_passes", 1.05, 1.15)
	
	# Trigger unlock burst
	_trigger_unlock_burst(to_lvl)
	
	# Clear victory trigger and save progression
	GameState.just_cleared_level = false
	GameState.current_selected_level = to_lvl
	GameState.save_game()
	
	_refresh_all_node_states()
	is_animating_travel = false
	
	# Open level detail popup for the newly unlocked level
	await get_tree().create_timer(0.3, true, false, true).timeout
	_show_level_popup(to_lvl)

func _trigger_unlock_burst(lvl: int) -> void:
	if not unlock_vfx or not MILESTONES.has(lvl):
		return
		
	var pos = MILESTONES[lvl]["pos"] + Vector2(80, 80)
	unlock_vfx.position = pos
	unlock_vfx.visible = true
	unlock_vfx.scale = Vector2(0.2, 0.2)
	unlock_vfx.modulate.a = 1.0
	
	# Shockwave punch animation
	var vt = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	vt.tween_property(unlock_vfx, "scale", Vector2(1.8, 1.8), 0.6)
	vt.tween_property(unlock_vfx, "modulate:a", 0.0, 0.7)
	
	# Scale punch on target node
	var container = node_controls.get(lvl)
	if container:
		var node_t = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		container.scale = Vector2(1.35, 1.35)
		node_t.tween_property(container, "scale", Vector2.ONE, 0.45)

func _on_node_pressed(lvl: int) -> void:
	if is_animating_travel:
		return
		
	var unlocked_max = GameState.highest_unlocked_level
	if lvl <= unlocked_max:
		AudioManager.play_sfx("gate_passes", 1.0, 1.1)
		GameState.current_selected_level = lvl
		GameState.current_level = lvl
		level_selected.emit(lvl)
		
		# Move miniature vessel to selected node
		var target_pos = _get_node_dock_pos(lvl)
		var mt = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		mt.tween_property(mini_vessel, "position", target_pos, 0.4)
		
		_refresh_all_node_states()
		_show_level_popup(lvl)
	else:
		# Locked node: shake padlock with rattle sound
		AudioManager.play_sfx("barrel_hits", 1.2, 1.4)
		var container = node_controls.get(lvl)
		if container:
			var shake_t = create_tween()
			var orig_x = container.position.x
			shake_t.tween_property(container, "position:x", orig_x - 8.0, 0.06)
			shake_t.tween_property(container, "position:x", orig_x + 8.0, 0.06)
			shake_t.tween_property(container, "position:x", orig_x - 4.0, 0.06)
			shake_t.tween_property(container, "position:x", orig_x, 0.06)

# ==============================================================================
# LEVEL DETAIL POPUP MODAL
# ==============================================================================

func _setup_popup() -> void:
	if popup_scrim:
		popup_scrim.visible = false
		popup_scrim.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed:
				_close_level_popup()
		)
		
	if btn_close_popup:
		btn_close_popup.pressed.connect(_close_level_popup)
		
	if btn_set_sail:
		btn_set_sail.pressed.connect(_on_set_sail_pressed)

func _show_level_popup(lvl: int) -> void:
	if not MILESTONES.has(lvl):
		return
		
	popup_selected_level = lvl
	var data = MILESTONES[lvl]
	
	if popup_num:
		popup_num.text = "EXPEDITION %02d" % lvl
	if popup_title:
		popup_title.text = data["name"]
	if popup_biome:
		popup_biome.text = "%s  •  Target: %dm" % [data["biome"], data["target_dist"]]
		
	if popup_score:
		var best = GameState.level_high_scores.get(lvl, 0)
		var stars = GameState.level_stars.get(lvl, 0)
		var stars_str = ""
		for i in range(3):
			stars_str += "★" if i < stars else "☆"
		if best > 0:
			popup_score.text = "%s  •  HIGH SCORE: %s DOUBLOONS" % [stars_str, _format_number(best)]
		else:
			popup_score.text = "%s  •  HIGH SCORE: UNCHARTED" % stars_str
			
	if popup_boss_tag:
		if data["is_boss"]:
			popup_boss_tag.visible = true
			if popup_boss_label:
				popup_boss_label.text = "☠ %s" % data["boss_name"].to_upper()
		else:
			popup_boss_tag.visible = false
			
	popup_scrim.visible = true
	popup_panel.scale = Vector2(0.8, 0.8)
	popup_panel.modulate.a = 0.0
	
	var pt = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pt.tween_property(popup_panel, "scale", Vector2.ONE, 0.35)
	pt.tween_property(popup_panel, "modulate:a", 1.0, 0.25)

func _close_level_popup() -> void:
	if not popup_scrim or not popup_scrim.visible:
		return
		
	AudioManager.play_sfx("gate_passes", 0.9, 1.0)
	var pt = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	pt.tween_property(popup_panel, "scale", Vector2(0.85, 0.85), 0.2)
	pt.tween_property(popup_panel, "modulate:a", 0.0, 0.2)
	
	await pt.finished
	popup_scrim.visible = false

func _on_set_sail_pressed() -> void:
	AudioManager.play_sfx("gate_passes")
	GameState.select_level(popup_selected_level)
	sail_requested.emit(popup_selected_level)

func _format_number(val: int) -> String:
	var s = str(abs(val))
	var res = ""
	var count = 0
	for i in range(s.length() - 1, -1, -1):
		res = s[i] + res
		count += 1
		if count % 3 == 0 and i > 0:
			res = "," + res
	return res
