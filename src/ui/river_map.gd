class_name RiverMap
extends Control

## Animated River Progression Map for Cove Corsair
## Features scrollable curved river spline, milestone nodes (1 to 6+),
## dynamic vessel advancement animation upon victory, and level details popup modal.

signal level_selected(level_num: int)
signal sail_requested(level_num: int)
signal cove_requested

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
const GUIDANCE_SCENE: PackedScene = preload("res://src/ui/tutorial/tutorial_guidance_overlay.tscn")

static var MILESTONES: Dictionary = _build_milestones()

var river_curve: Curve2D = Curve2D.new()
var node_controls: Dictionary = {}
var vessel_bob_tween: Tween
var is_animating_travel: bool = false
var popup_selected_level: int = 1
var _tutorial_overlay: TutorialGuidanceOverlay = null

func _ready() -> void:
	_init_milestones_data()
	_setup_river_spline()
	_setup_terrain_draw()
	_setup_river_path_draw()
	_build_milestone_nodes()
	_setup_mini_vessel()
	_setup_popup()
	
	# ScrollContainer Frame-0 Guard: defer initial presentation so 15,000px height is measured
	call_deferred("_handle_initial_presentation")

static func _build_milestones() -> Dictionary:
	var dict: Dictionary = {}
	for lvl in range(1, 46):
		var t := float(lvl - 1) / 44.0
		var node_y := lerpf(14500.0, 500.0, t)
		var node_x := 360.0
		if lvl == 1 or lvl == 45:
			node_x = 360.0
		else:
			node_x = 360.0 + sin((lvl - 1) * 0.72) * 170.0
		
		var is_boss := (lvl % 5 == 0)
		var boss_type := ""
		var boss_name := ""
		
		if is_boss:
			match lvl:
				5:
					boss_type = "phantom_dredge"
					boss_name = "The Phantom Dredge"
				10:
					boss_type = "ironjaw"
					boss_name = "Captain Ironjaw"
				15:
					boss_type = "bonebeard"
					boss_name = "Captain Bone-Beard"
				20:
					boss_type = "siege_fortress"
					boss_name = "The Siege Fortress"
				25:
					boss_type = "phantom_dredge"
					boss_name = "The Phantom Dredge"
				30:
					boss_type = "bonebeard"
					boss_name = "Captain Bone-Beard"
				35:
					boss_type = "ironjaw"
					boss_name = "Captain Ironjaw"
				40:
					boss_type = "siege_fortress"
					boss_name = "The Siege Fortress"
				45:
					boss_type = "final_boss"
					boss_name = "Captain Bone-Beard"
		
		var lvl_title := "EXPEDITION %02d" % lvl
		var biome_desc := "Tropical Reef" if lvl <= 15 else ("Murky Bayou" if lvl <= 30 else "Volcanic Brimstone")
		var target_dist := 200 + (lvl * 25)
		
		dict[lvl] = {
			"name": lvl_title,
			"biome": biome_desc,
			"target_dist": target_dist,
			"pos": Vector2(node_x, node_y),
			"is_boss": is_boss,
			"boss_type": boss_type,
			"boss_name": boss_name
		}
	return dict

func _init_milestones_data() -> void:
	if MILESTONES.is_empty():
		MILESTONES = _build_milestones()
	for lvl: int in MILESTONES.keys():
		if GameState.LEVEL_TITLES.has(lvl):
			MILESTONES[lvl]["name"] = str(GameState.LEVEL_TITLES[lvl]).to_upper()

func _setup_river_spline() -> void:
	river_curve.clear_points()
	var points: Array[Vector2] = []
	points.append(Vector2(360, 14850)) # Harbor start
	for lvl in range(1, 46):
		if MILESTONES.has(lvl):
			points.append(MILESTONES[lvl]["pos"])
	points.append(Vector2(360, 200)) # Final anchorage peak
	
	for i in range(points.size()):
		var p := points[i]
		var in_tangent := Vector2.ZERO
		var out_tangent := Vector2.ZERO
		
		if i > 0 and i < points.size() - 1:
			var prev_p := points[i - 1]
			var next_p := points[i + 1]
			var diff := (next_p - prev_p) * 0.28
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

## ---- Biome-themed drawing (new) ----

const PALETTES: Array = [
	{ # Tropical Reef
		"bg": Color(0.95, 0.88, 0.68), "bank": Color(0.96, 0.86, 0.58), "shore": Color(0.08, 0.42, 0.52),
		"deep": Color(0.10, 0.60, 0.72), "core": Color(0.28, 0.82, 0.86), "glint": Color(0.92, 1.0, 0.95),
	},
	{ # Murky Bayou
		"bg": Color(0.20, 0.28, 0.18), "bank": Color(0.36, 0.30, 0.16), "shore": Color(0.10, 0.17, 0.12),
		"deep": Color(0.18, 0.31, 0.22), "core": Color(0.32, 0.45, 0.27), "glint": Color(0.72, 0.86, 0.48),
	},
	{ # Volcanic Brimstone
		"bg": Color(0.15, 0.08, 0.08), "bank": Color(0.27, 0.12, 0.09), "shore": Color(0.30, 0.06, 0.03),
		"deep": Color(0.62, 0.16, 0.05), "core": Color(0.96, 0.46, 0.08), "glint": Color(1.0, 0.86, 0.42),
	},
]

var _decor_items: Array[Dictionary] = []

## Returns 0.0 (tropical) .. 1.0 (bayou) .. 2.0 (brimstone), smoothly blended across biome borders.
static func _biome_level(y: float) -> float:
	return smoothstep(10500.0, 9500.0, y) + smoothstep(5500.0, 4500.0, y)

static func _palette_color(key: String, y: float) -> Color:
	var lv: float = _biome_level(y)
	var i: int = clampi(int(floorf(lv)), 0, 1)
	var a: Color = (PALETTES[i] as Dictionary)[key]
	var b: Color = (PALETTES[i + 1] as Dictionary)[key]
	return a.lerp(b, lv - float(i))

func _on_terrain_draw() -> void:
	# Biome gradient ground
	for y in range(0, 15000, 50):
		terrain_layer.draw_rect(Rect2(0, y, 720, 51), _palette_color("bg", float(y) + 25.0), true)

	# Soft bank halo hugging the river
	var baked: PackedVector2Array = river_curve.get_baked_points()
	if baked.size() >= 2:
		var bank_cols := PackedColorArray()
		for p: Vector2 in baked:
			var c: Color = _palette_color("bank", p.y)
			c.a = 0.9
			bank_cols.append(c)
		terrain_layer.draw_polyline_colors(baked, bank_cols, 250.0, true)
		var halo_cols := PackedColorArray()
		for p: Vector2 in baked:
			var c2: Color = _palette_color("bank", p.y).lightened(0.12)
			c2.a = 0.85
			halo_cols.append(c2)
		terrain_layer.draw_polyline_colors(baked, halo_cols, 190.0, true)

	# Vignette edges
	terrain_layer.draw_rect(Rect2(0, 0, 26, 15000), Color(0, 0, 0, 0.28), true)
	terrain_layer.draw_rect(Rect2(694, 0, 26, 15000), Color(0, 0, 0, 0.28), true)

	# Biome-specific scenery
	if _decor_items.is_empty():
		_generate_decor()
	for item: Dictionary in _decor_items:
		_draw_decor_item(item)

	# Biome zone banners at the border lines
	_draw_biome_banner("~ MURKY BAYOU ~", 10000.0)
	_draw_biome_banner("~ VOLCANIC BRIMSTONE ~", 5000.0)

	_draw_cove_landmark()

func _draw_biome_banner(text: String, y: float) -> void:
	var col: Color = _palette_color("glint", y)
	terrain_layer.draw_rect(Rect2(Vector2(60, y), Vector2(120, 3)), col, true)
	terrain_layer.draw_rect(Rect2(Vector2(540, y), Vector2(120, 3)), col, true)
	terrain_layer.draw_string(FONT_LILITA, Vector2(0, y + 8), text, HORIZONTAL_ALIGNMENT_CENTER, 720.0, 22, col)

func _generate_decor() -> void:
	_decor_items.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	var samples := PackedVector2Array()
	var baked: PackedVector2Array = river_curve.get_baked_points()
	for i in range(0, baked.size(), 4):
		samples.append(baked[i])
	var y: float = 70.0
	while y < 14680.0:
		for attempt in range(2):
			var pos := Vector2(rng.randf_range(34.0, 686.0), y + rng.randf_range(-30.0, 30.0))
			if _decor_blocked(pos, samples):
				continue
			var biome: int = clampi(roundi(_biome_level(pos.y)), 0, 2)
			_decor_items.append({
				"pos": pos,
				"biome": biome,
				"variant": rng.randf(),
				"scale": rng.randf_range(0.8, 1.35),
				"flip": -1.0 if rng.randf() < 0.5 else 1.0,
			})
		y += 62.0

func _decor_blocked(pos: Vector2, samples: PackedVector2Array) -> bool:
	for s: Vector2 in samples:
		if absf(s.y - pos.y) < 170.0 and s.distance_squared_to(pos) < 150.0 * 150.0:
			return true
	for lvl: int in MILESTONES.keys():
		var p: Vector2 = MILESTONES[lvl]["pos"]
		if Rect2(p.x - 80.0, p.y - 40.0, 340.0, 220.0).has_point(pos):
			return true
	return false

func _draw_decor_item(item: Dictionary) -> void:
	var pos: Vector2 = item["pos"]
	var sc: float = float(item["scale"]) * float(item["flip"])
	var sy: float = float(item["scale"])
	var variant: float = float(item["variant"])
	terrain_layer.draw_set_transform(pos, 0.0, Vector2(sc, sy))
	match int(item["biome"]):
		0:
			if variant < 0.68:
				_draw_palm()
			else:
				_draw_shrub(Color(0.22, 0.62, 0.30), Color(0.96, 0.45, 0.50))
		1:
			if variant < 0.55:
				_draw_cypress()
			else:
				_draw_reeds()
		_:
			if variant < 0.5:
				_draw_lava_rock()
			else:
				_draw_mini_volcano()
	terrain_layer.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_palm() -> void:
	terrain_layer.draw_circle(Vector2(0, 2), 16.0, Color(0, 0, 0, 0.14))
	var trunk := PackedVector2Array([Vector2(0, 0), Vector2(7, -24), Vector2(5, -48), Vector2(-3, -70)])
	terrain_layer.draw_polyline(trunk, Color(0.45, 0.30, 0.16), 7.0, true)
	terrain_layer.draw_polyline(trunk, Color(0.62, 0.44, 0.24), 3.5, true)
	var top := Vector2(-3, -70)
	var leaf_cols: Array[Color] = [Color(0.16, 0.55, 0.28), Color(0.24, 0.68, 0.34)]
	for i in range(7):
		var ang: float = -PI + (float(i) / 6.0) * PI
		var dir := Vector2.from_angle(ang)
		var tip: Vector2 = top + dir * 40.0 + Vector2(0, 14.0 * absf(cos(ang)))
		var perp := dir.orthogonal() * 7.0
		terrain_layer.draw_colored_polygon(PackedVector2Array([top, top + dir * 20.0 + perp, tip, top + dir * 20.0 - perp]), leaf_cols[i % 2])
	terrain_layer.draw_circle(top + Vector2(-3, 4), 4.0, Color(0.40, 0.25, 0.10))
	terrain_layer.draw_circle(top + Vector2(4, 5), 4.0, Color(0.40, 0.25, 0.10))

func _draw_shrub(leaf: Color, flower: Color) -> void:
	terrain_layer.draw_circle(Vector2(0, 2), 18.0, Color(0, 0, 0, 0.14))
	terrain_layer.draw_circle(Vector2(-10, -8), 12.0, leaf.darkened(0.15))
	terrain_layer.draw_circle(Vector2(10, -8), 12.0, leaf.darkened(0.15))
	terrain_layer.draw_circle(Vector2(0, -14), 14.0, leaf)
	terrain_layer.draw_circle(Vector2(-4, -18), 3.0, flower)
	terrain_layer.draw_circle(Vector2(7, -12), 3.0, flower)

func _draw_cypress() -> void:
	terrain_layer.draw_circle(Vector2(0, 2), 18.0, Color(0, 0, 0, 0.22))
	terrain_layer.draw_colored_polygon(PackedVector2Array([Vector2(-13, 0), Vector2(13, 0), Vector2(5, -42), Vector2(-5, -42)]), Color(0.28, 0.20, 0.12))
	var green := Color(0.14, 0.30, 0.18)
	terrain_layer.draw_circle(Vector2(0, -56), 24.0, green)
	terrain_layer.draw_circle(Vector2(-20, -46), 17.0, green.lightened(0.05))
	terrain_layer.draw_circle(Vector2(19, -48), 17.0, green.lightened(0.05))
	var moss := Color(0.62, 0.72, 0.46, 0.7)
	for mx: float in [-24.0, -12.0, 8.0, 22.0]:
		terrain_layer.draw_line(Vector2(mx, -46), Vector2(mx + 2.0, -28), moss, 2.0, true)

func _draw_reeds() -> void:
	terrain_layer.draw_circle(Vector2(0, 2), 16.0, Color(0.05, 0.10, 0.06, 0.35))
	for i in range(5):
		var rx: float = -12.0 + i * 6.0
		var h: float = 34.0 + float((i * 7) % 5) * 5.0
		terrain_layer.draw_line(Vector2(rx, 0), Vector2(rx + float(i - 2) * 2.0, -h), Color(0.50, 0.62, 0.26), 2.5, true)
		if i % 2 == 0:
			terrain_layer.draw_line(Vector2(rx + float(i - 2) * 2.0, -h), Vector2(rx + float(i - 2) * 2.0, -h - 9.0), Color(0.36, 0.20, 0.10), 5.0, true)

func _draw_lava_rock() -> void:
	terrain_layer.draw_circle(Vector2(0, 2), 20.0, Color(0, 0, 0, 0.3))
	var pts := PackedVector2Array([Vector2(-22, 0), Vector2(-16, -22), Vector2(-4, -30), Vector2(10, -20), Vector2(24, -4), Vector2(14, 2)])
	terrain_layer.draw_colored_polygon(pts, Color(0.12, 0.09, 0.09))
	terrain_layer.draw_polyline(PackedVector2Array([Vector2(-16, -22), Vector2(-4, -30), Vector2(10, -20)]), Color(0.85, 0.30, 0.08, 0.9), 2.5, true)
	terrain_layer.draw_line(Vector2(-6, -24), Vector2(-2, -6), Color(1.0, 0.55, 0.12, 0.85), 2.0, true)

func _draw_mini_volcano() -> void:
	terrain_layer.draw_circle(Vector2(0, -22), 46.0, Color(1.0, 0.4, 0.05, 0.10))
	terrain_layer.draw_colored_polygon(PackedVector2Array([Vector2(-44, 0), Vector2(-9, -54), Vector2(9, -54), Vector2(44, 0)]), Color(0.18, 0.11, 0.10))
	terrain_layer.draw_colored_polygon(PackedVector2Array([Vector2(-9, -54), Vector2(9, -54), Vector2(16, -40), Vector2(-16, -40)]), Color(0.26, 0.15, 0.12))
	terrain_layer.draw_rect(Rect2(-9, -58, 18, 6), Color(1.0, 0.55, 0.1), true)
	terrain_layer.draw_line(Vector2(0, -52), Vector2(-8, -20), Color(1.0, 0.5, 0.1, 0.9), 3.0, true)
	terrain_layer.draw_line(Vector2(3, -52), Vector2(14, -14), Color(1.0, 0.45, 0.1, 0.8), 2.5, true)
	terrain_layer.draw_circle(Vector2(-4, -70), 6.0, Color(0.35, 0.25, 0.25, 0.5))
	terrain_layer.draw_circle(Vector2(4, -84), 8.0, Color(0.35, 0.25, 0.25, 0.35))

func _draw_cove_landmark() -> void:
	var c := Vector2(360, 14900)
	terrain_layer.draw_circle(c, 250.0, Color(0.97, 0.88, 0.62, 0.95))
	terrain_layer.draw_circle(c, 214.0, Color(0.98, 0.92, 0.72))
	terrain_layer.draw_circle(c, 168.0, Color(0.08, 0.46, 0.56))
	terrain_layer.draw_circle(c, 152.0, Color(0.20, 0.72, 0.80))
	terrain_layer.draw_circle(c, 100.0, Color(0.38, 0.84, 0.88, 0.7))
	# Wooden dock jutting into the lagoon
	for i in range(8):
		terrain_layer.draw_rect(Rect2(150 + i * 17, 14868, 14, 54), Color(0.52, 0.34, 0.16), true)
		terrain_layer.draw_rect(Rect2(150 + i * 17, 14868, 14, 54), Color(0.28, 0.17, 0.08), false, 1.5)
	for px: int in [150, 252]:
		terrain_layer.draw_circle(Vector2(px, 14866), 5.0, Color(0.30, 0.18, 0.08))
		terrain_layer.draw_circle(Vector2(px, 14924), 5.0, Color(0.30, 0.18, 0.08))
	# Sandy palms flanking the cove
	terrain_layer.draw_set_transform(Vector2(160, 14780), 0.0, Vector2(1.3, 1.3))
	_draw_palm()
	terrain_layer.draw_set_transform(Vector2(570, 14800), 0.0, Vector2(-1.2, 1.2))
	_draw_palm()
	terrain_layer.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _on_river_path_draw() -> void:
	var baked := river_curve.get_baked_points()
	if baked.size() < 2:
		return

	var bank_cols := PackedColorArray()
	var shore_cols := PackedColorArray()
	var deep_cols := PackedColorArray()
	var core_cols := PackedColorArray()
	var glow_cols := PackedColorArray()
	for p: Vector2 in baked:
		var bank: Color = _palette_color("bank", p.y).darkened(0.1)
		bank.a = 0.95
		bank_cols.append(bank)
		shore_cols.append(_palette_color("shore", p.y))
		deep_cols.append(_palette_color("deep", p.y))
		core_cols.append(_palette_color("core", p.y))
		var lava: float = clampf(_biome_level(p.y) - 1.0, 0.0, 1.0)
		glow_cols.append(Color(1.0, 0.45, 0.08, 0.38 * lava))

	# Lava glow aura (only visible in Brimstone)
	river_path_layer.draw_polyline_colors(baked, glow_cols, 150.0, true)
	# 1. Riverbank edge
	river_path_layer.draw_polyline_colors(baked, bank_cols, 116.0, true)
	# 2. Shoreline
	river_path_layer.draw_polyline_colors(baked, shore_cols, 98.0, true)
	# 3. Deep water channel
	river_path_layer.draw_polyline_colors(baked, deep_cols, 84.0, true)
	# 4. Water current core
	river_path_layer.draw_polyline_colors(baked, core_cols, 52.0, true)

	# Flow dashes + stepping-stone waypoints following the curve
	var total_len: float = river_curve.get_baked_length()
	var cur: float = 30.0
	while cur < total_len - 40.0:
		var pt: Vector2 = river_curve.sample_baked(cur)
		var pt2: Vector2 = river_curve.sample_baked(cur + 14.0)
		var glint: Color = _palette_color("glint", pt.y)
		glint.a = 0.55
		river_path_layer.draw_line(pt, pt2, glint, 4.0, true)
		river_path_layer.draw_circle(river_curve.sample_baked(cur + 30.0), 3.5, Color(glint.r, glint.g, glint.b, 0.4))
		cur += 70.0


func _build_milestone_nodes() -> void:
	for child in nodes_layer.get_children():
		child.queue_free()
	node_controls.clear()
	
	for lvl: int in MILESTONES.keys():
		var data: Dictionary = MILESTONES[lvl] as Dictionary
		var node_btn := _create_milestone_button(lvl, data)
		nodes_layer.add_child(node_btn)
		node_controls[lvl] = node_btn
		
	_build_cove_button()
	_refresh_all_node_states()

## "Smuggler's Cove" harbor sign at the river's starting point; returns the player to the hub.
func _build_cove_button() -> void:
	var cove_btn := Button.new()
	cove_btn.name = "CoveButton"
	cove_btn.text = "SMUGGLER'S COVE"
	cove_btn.size = Vector2(280, 64)
	cove_btn.custom_minimum_size = Vector2(280, 64)
	cove_btn.position = Vector2(360.0 - 140.0, 14745.0)
	cove_btn.focus_mode = Control.FOCUS_NONE
	cove_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	cove_btn.add_theme_font_override("font", FONT_CARTER)
	cove_btn.add_theme_font_size_override("font_size", 24)
	cove_btn.add_theme_color_override("font_color", Color(1.0, 0.92, 0.6))
	cove_btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.85))
	cove_btn.add_theme_color_override("font_outline_color", Color(0.18, 0.09, 0.03))
	cove_btn.add_theme_constant_override("outline_size", 6)
	for state: String in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.42, 0.26, 0.12) if state != "hover" else Color(0.52, 0.33, 0.16)
		sb.set_border_width_all(4)
		sb.border_color = Color(0.86, 0.66, 0.26)
		sb.set_corner_radius_all(14)
		sb.shadow_color = Color(0, 0, 0, 0.45)
		sb.shadow_size = 6
		sb.shadow_offset = Vector2(0, 4)
		cove_btn.add_theme_stylebox_override(state, sb)
	cove_btn.pressed.connect(func() -> void:
		AudioManager.play_sfx("gate_passes", 0.9, 1.0)
		cove_requested.emit()
	)
	nodes_layer.add_child(cove_btn)

func _create_milestone_button(lvl: int, data: Dictionary) -> Control:
	var container := Control.new()
	container.name = "Node_%d" % lvl
	container.position = data["pos"]
	container.custom_minimum_size = Vector2(160, 160)
	container.pivot_offset = Vector2(80, 80)
	container.set_anchors_preset(Control.PRESET_TOP_LEFT)
	container.mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Pulsing active circular aura (behind button)
	var aura := Panel.new()
	aura.name = "ActiveAura"
	aura.custom_minimum_size = Vector2(136, 136)
	aura.position = Vector2(12, 12)
	aura.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var aura_style := StyleBoxFlat.new()
	aura_style.set_corner_radius_all(68)
	aura_style.bg_color = Color(1.0, 0.82, 0.2, 0.22)
	aura_style.set_border_width_all(3)
	aura_style.border_color = Color(1.0, 0.92, 0.45, 0.85)
	aura_style.shadow_color = Color(1.0, 0.8, 0.2, 0.4)
	aura_style.shadow_size = 8
	aura.add_theme_stylebox_override("panel", aura_style)
	aura.pivot_offset = Vector2(68, 68)
	aura.visible = false
	container.add_child(aura)
	
	# Node Disc Background Panel
	var disc_panel := Panel.new()
	disc_panel.name = "DiscPanel"
	disc_panel.custom_minimum_size = Vector2(96, 96)
	disc_panel.position = Vector2(32, 32)
	disc_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(disc_panel)
	
	# Level Number Label (inside disc)
	var num_label := Label.new()
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
	var status_icon := TextureRect.new()
	status_icon.name = "StatusIcon"
	status_icon.custom_minimum_size = Vector2(44, 44)
	status_icon.position = Vector2(58, 20)
	status_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	status_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	status_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(status_icon)
	
	# Boss Banner Ribbon for Milestone Bosses (5, 10, 15, 20, 25, 30, 35, 40, 45)
	if data.get("is_boss", false):
		var boss_type: String = str(data.get("boss_type", ""))
		var boss_banner := PanelContainer.new()
		boss_banner.name = "BossBanner"
		boss_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		var banner_w := 220 if boss_type == "final_boss" else 200
		var banner_h := 38 if boss_type == "final_boss" else 34
		boss_banner.position = Vector2(80 - (banner_w * 0.5), -20)
		boss_banner.custom_minimum_size = Vector2(banner_w, banner_h)
		
		var banner_style := StyleBoxFlat.new()
		banner_style.set_corner_radius_all(12)
		banner_style.shadow_size = 6
		banner_style.shadow_offset = Vector2(0, 2)
		
		var label_text := "BOSS"
		var skull_mod := Color.WHITE
		
		match boss_type:
			"phantom_dredge":
				banner_style.bg_color = Color(0.06, 0.28, 0.32, 0.95)
				banner_style.set_border_width_all(2)
				banner_style.border_color = Color(0.35, 0.95, 0.85, 1.0)
				skull_mod = Color(0.4, 1.0, 0.85, 1.0)
				label_text = "PHANTOM DREDGE"
			"ironjaw":
				banner_style.bg_color = Color(0.58, 0.22, 0.08, 0.95)
				banner_style.set_border_width_all(2)
				banner_style.border_color = Color(1.0, 0.72, 0.22, 1.0)
				skull_mod = Color(1.0, 0.8, 0.3, 1.0)
				label_text = "CAPT. IRONJAW"
			"siege_fortress":
				banner_style.bg_color = Color(0.25, 0.18, 0.22, 0.95)
				banner_style.set_border_width_all(2)
				banner_style.border_color = Color(0.95, 0.32, 0.28, 1.0)
				skull_mod = Color(1.0, 0.45, 0.4, 1.0)
				label_text = "SIEGE FORTRESS"
			"bonebeard":
				banner_style.bg_color = Color(0.72, 0.10, 0.10, 0.95)
				banner_style.set_border_width_all(2)
				banner_style.border_color = Color(1.0, 0.86, 0.35, 1.0)
				skull_mod = Color(1.0, 0.92, 0.5, 1.0)
				label_text = "BONE-BEARD"
			"final_boss":
				banner_style.bg_color = Color(0.85, 0.08, 0.08, 0.98)
				banner_style.set_border_width_all(3)
				banner_style.border_color = Color(1.0, 0.95, 0.45, 1.0)
				banner_style.shadow_color = Color(1.0, 0.8, 0.2, 0.6)
				banner_style.shadow_size = 12
				skull_mod = Color(1.0, 0.98, 0.6, 1.0)
				label_text = "★ FINAL BOSS ★"
			_:
				banner_style.bg_color = Color(0.72, 0.12, 0.12, 0.95)
				banner_style.set_border_width_all(2)
				banner_style.border_color = Color(1.0, 0.85, 0.35, 1.0)
				label_text = "BOSS"
				
		boss_banner.add_theme_stylebox_override("panel", banner_style)
		
		var hbox := HBoxContainer.new()
		hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_theme_constant_override("separation", 6)
		hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		
		var skull := TextureRect.new()
		skull.mouse_filter = Control.MOUSE_FILTER_IGNORE
		skull.custom_minimum_size = Vector2(22, 22)
		skull.texture = ICON_SKULL
		skull.modulate = skull_mod
		skull.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		skull.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hbox.add_child(skull)
		
		var b_lbl := Label.new()
		b_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b_lbl.text = label_text
		b_lbl.add_theme_font_override("font", FONT_LILITA)
		b_lbl.add_theme_font_size_override("font_size", 18 if boss_type == "final_boss" else 15)
		b_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.75, 1.0))
		hbox.add_child(b_lbl)
		
		boss_banner.add_child(hbox)
		container.add_child(boss_banner)
		
	# Expedition Name Label (Parchment title beneath node)
	var title_lbl := Label.new()
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

	# Clickable Milestone Button covering the entire 96x96 circle interior
	var btn := Button.new()
	btn.name = "TouchButton"
	btn.position = Vector2(32, 32)
	btn.size = Vector2(96, 96)
	btn.custom_minimum_size = Vector2(96, 96)
	btn.pivot_offset = Vector2(48, 48)
	btn.flat = false
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.focus_mode = Control.FOCUS_NONE

	var hit_style := StyleBoxFlat.new()
	hit_style.bg_color = Color(1.0, 1.0, 1.0, 0.005)
	hit_style.set_corner_radius_all(48)
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(state, hit_style)

	btn.pressed.connect(func() -> void: _on_node_pressed(lvl))
	container.add_child(btn)

	# Safeguard: ensure every non-button child/descendant ignores mouse clicks
	for child: Node in container.get_children():
		if child != btn:
			_set_mouse_filter_recursive(child, Control.MOUSE_FILTER_IGNORE)
	btn.move_to_front()

	return container

static func _set_mouse_filter_recursive(node: Node, filter_mode: Control.MouseFilter) -> void:
	if node is Control:
		var ctrl := node as Control
		ctrl.mouse_filter = filter_mode
	for child: Node in node.get_children():
		_set_mouse_filter_recursive(child, filter_mode)

func _refresh_all_node_states() -> void:
	var unlocked_max := GameState.highest_unlocked_level
	
	for lvl: int in MILESTONES.keys():
		var container := node_controls.get(lvl) as Control
		if not container:
			continue
			
		var disc_panel: Panel = container.get_node("DiscPanel")
		var num_label: Label = container.get_node("NumLabel")
		var status_icon: TextureRect = container.get_node("StatusIcon")
		var active_aura: Control = container.get_node("ActiveAura")
		
		var disc_style := StyleBoxFlat.new()
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

func _pulse_active_aura(aura: Control) -> void:
	if aura.has_meta("pulse_tween"):
		var old_t: Tween = aura.get_meta("pulse_tween")
		if old_t and old_t.is_valid():
			old_t.kill()

	aura.scale = Vector2(0.92, 0.92)
	aura.modulate.a = 0.85
	var t := create_tween().set_loops()
	t.tween_property(aura, "scale", Vector2(1.28, 1.28), 0.85).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(aura, "modulate:a", 0.05, 0.85).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(aura, "scale", Vector2(0.92, 0.92), 0.01)
	t.tween_property(aura, "modulate:a", 0.85, 0.01)
	aura.set_meta("pulse_tween", t)

## Dedicated, pre-cropped river map icons. These are intentionally decoupled from
## the shipyard/gameplay vessel art so editing a vessel elsewhere never alters the map.
const RIVER_VESSEL_ICONS: Dictionary = {
	"dinghy": "res://assets/sprites/ui/river_map_vessels/dinghy.png",
	"sloop": "res://assets/sprites/ui/river_map_vessels/sloop.png",
	"ironclad": "res://assets/sprites/ui/river_map_vessels/ironclad.png",
	"bombard_skiff": "res://assets/sprites/ui/river_map_vessels/bombard_skiff.png",
}

func _setup_mini_vessel() -> void:
	if not mini_vessel or not mini_vessel_icon:
		return
		
	var active_id: String = GameState.active_vessel
	var tex_loaded := false
	if RIVER_VESSEL_ICONS.has(active_id):
		var icon_path: String = str(RIVER_VESSEL_ICONS[active_id])
		if ResourceLoader.exists(icon_path):
			var t := ResourceLoader.load(icon_path) as Texture2D
			if t:
				mini_vessel_icon.texture = t
				tex_loaded = true
				
	if not tex_loaded:
		mini_vessel_icon.texture = ICON_BOAT_FALLBACK
	
	mini_vessel_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
	_start_vessel_idle_bob()

func _start_vessel_idle_bob() -> void:
	if vessel_bob_tween and vessel_bob_tween.is_valid():
		vessel_bob_tween.kill()
		
	var base_y: float = mini_vessel_icon.position.y
	vessel_bob_tween = create_tween().set_loops()
	vessel_bob_tween.tween_property(mini_vessel_icon, "position:y", base_y - 6.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	vessel_bob_tween.tween_property(mini_vessel_icon, "position:y", base_y + 4.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _handle_initial_presentation() -> void:
	# ScrollContainer Frame-0 Guard: wait for 15,000px content height to be fully measured
	await get_tree().process_frame
	
	var active_lvl: int = clampi(GameState.current_selected_level, 1, 45)
	if GameState.just_cleared_level:
		_play_advancement_sequence()
	else:
		_focus_on_level(active_lvl, false)
		var target_pos := _get_node_dock_pos(active_lvl)
		mini_vessel.position = target_pos
		mini_vessel.rotation = _get_node_water_rotation(active_lvl)
		var parent_canvas: CanvasLayer = get_parent() as CanvasLayer
		if is_visible_in_tree() and (not parent_canvas or parent_canvas.visible):
			_check_tutorial_guidance()

func _get_node_dock_pos(lvl: int) -> Vector2:
	if MILESTONES.has(lvl):
		# Position vessel on the river water at the milestone waypoint
		return MILESTONES[lvl]["pos"]
	return Vector2(360, 14500)

func _get_node_water_rotation(lvl: int) -> float:
	if river_curve and MILESTONES.has(lvl):
		var pos: Vector2 = MILESTONES[lvl]["pos"]
		var offset := river_curve.get_closest_offset(pos)
		var pt1 := river_curve.sample_baked(offset)
		var pt2 := river_curve.sample_baked(minf(offset + 6.0, river_curve.get_baked_length()))
		var dir := (pt2 - pt1).normalized()
		if dir.length_squared() > 0.01:
			return dir.angle() + PI/2
	return 0.0

func _focus_on_level(lvl: int, animate: bool = true, duration: float = 0.8) -> void:
	if not scroll_container or not MILESTONES.has(lvl):
		return
		
	var node_y: float = MILESTONES[lvl]["pos"].y
	var viewport_h := scroll_container.size.y
	if viewport_h <= 0:
		viewport_h = 1000.0
	var canvas_h := map_canvas.custom_minimum_size.y if map_canvas else 15000.0
	var target_scroll: int = clampi(int(node_y - viewport_h * 0.5), 0, int(canvas_h - viewport_h))
	
	if animate:
		var st := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		st.tween_property(scroll_container, "scroll_vertical", target_scroll, duration)
	else:
		scroll_container.scroll_vertical = target_scroll

func _play_advancement_sequence() -> void:
	is_animating_travel = true
	var from_lvl: int = clampi(GameState.last_cleared_level, 1, 45)
	var to_lvl: int = clampi(GameState.highest_unlocked_level, 1, 45)
	
	if from_lvl == to_lvl and to_lvl > 1:
		from_lvl = to_lvl - 1
		
	# 1. Place camera and vessel at the just-cleared node
	_focus_on_level(from_lvl, false)
	var start_pos := _get_node_dock_pos(from_lvl)
	var end_pos := _get_node_dock_pos(to_lvl)
	mini_vessel.position = start_pos
	mini_vessel.rotation = _get_node_water_rotation(from_lvl)
	if vessel_bob_tween and vessel_bob_tween.is_valid():
		vessel_bob_tween.kill()
	mini_vessel_icon.position.y = -57.0
	
	# 2. Wait 0.35s before beginning the voyage
	await get_tree().create_timer(0.35, true, false, true).timeout
	
	# Sample offsets along spline
	var from_offset := river_curve.get_closest_offset(start_pos)
	var to_offset := river_curve.get_closest_offset(end_pos)
	
	# Play water cruise SFX
	AudioManager.play_sfx("water_splashes", 0.95, 1.05)
	
	# 3. Tween camera scroll and vessel along river spline over 1.2 seconds
	var travel_duration := 1.2
	_focus_on_level(to_lvl, true, travel_duration)
	
	var travel_tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	travel_tween.tween_method(func(offset: float) -> void:
		var pt := river_curve.sample_baked(offset)
		var next_pt := river_curve.sample_baked(offset + 6.0)
		var dir := (next_pt - pt).normalized()
		mini_vessel.position = pt
		if dir.length_squared() > 0.01:
			mini_vessel.rotation = lerp_angle(mini_vessel.rotation, dir.angle() + PI/2, 0.25)
	, from_offset, to_offset, travel_duration)
	
	await travel_tween.finished
	
	# 4. Arrival on the newly unlocked node
	mini_vessel.position = end_pos
	mini_vessel.rotation = _get_node_water_rotation(to_lvl)
	mini_vessel_icon.position.y = -57.0
	_start_vessel_idle_bob()
	
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
	
	# During tutorial, guide the player to click the milestone node first rather than auto-opening popup
	if not GameState.is_tutorial_in_progress():
		await get_tree().create_timer(0.3, true, false, true).timeout
		_show_level_popup(to_lvl)
	else:
		_check_tutorial_guidance()


func _trigger_unlock_burst(lvl: int) -> void:
	if not unlock_vfx or not MILESTONES.has(lvl):
		return
		
	var pos: Vector2 = MILESTONES[lvl]["pos"] + Vector2(80, 80)
	unlock_vfx.position = pos
	unlock_vfx.visible = true
	unlock_vfx.scale = Vector2(0.2, 0.2)
	unlock_vfx.modulate.a = 1.0
	
	# Shockwave punch animation
	var vt := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	vt.tween_property(unlock_vfx, "scale", Vector2(1.8, 1.8), 0.6)
	vt.tween_property(unlock_vfx, "modulate:a", 0.0, 0.7)
	
	# Scale punch on target node
	var container := node_controls.get(lvl) as Control
	if container:
		var node_t := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		container.scale = Vector2(1.35, 1.35)
		node_t.tween_property(container, "scale", Vector2.ONE, 0.45)

func _on_node_pressed(lvl: int) -> void:
	if is_animating_travel:
		return

	if GameState.is_tutorial_in_progress():
		var allowed_lvl: int = -1
		match GameState.tutorial_step:
			GameState.TutorialStep.NOT_STARTED:
				allowed_lvl = 1
			GameState.TutorialStep.LEVEL_1_COMPLETED:
				allowed_lvl = 2
			GameState.TutorialStep.SLOOP_PURCHASED:
				allowed_lvl = 3
			GameState.TutorialStep.CREW_EQUIPPED:
				allowed_lvl = 4
			GameState.TutorialStep.SLOOP_T2_UPGRADED:
				allowed_lvl = 5
		if lvl != allowed_lvl:
			AudioManager.play_sfx("barrel_hits", 1.2, 1.4)
			var cont := node_controls.get(lvl) as Control
			if cont:
				var shake_t := create_tween()
				var orig_x: float = cont.position.x
				shake_t.tween_property(cont, "position:x", orig_x - 8.0, 0.06)
				shake_t.tween_property(cont, "position:x", orig_x + 8.0, 0.06)
				shake_t.tween_property(cont, "position:x", orig_x - 4.0, 0.06)
				shake_t.tween_property(cont, "position:x", orig_x, 0.06)
			return

	var unlocked_max := GameState.highest_unlocked_level
	if lvl <= unlocked_max:
		AudioManager.play_sfx("gate_passes", 1.0, 1.1)
		GameState.current_selected_level = lvl
		GameState.current_level = lvl
		level_selected.emit(lvl)
		
		# Move miniature vessel to selected node on the water
		var target_pos := _get_node_dock_pos(lvl)
		var target_rot := _get_node_water_rotation(lvl)
		var mt := create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		mt.tween_property(mini_vessel, "position", target_pos, 0.4)
		mt.tween_property(mini_vessel, "rotation", target_rot, 0.4)
		
		_refresh_all_node_states()
		_show_level_popup(lvl)
	else:
		# Locked node: shake padlock with rattle sound
		AudioManager.play_sfx("barrel_hits", 1.2, 1.4)
		var container := node_controls.get(lvl) as Control
		if container:
			var shake_t := create_tween()
			var orig_x: float = container.position.x
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
		popup_scrim.gui_input.connect(func(event: InputEvent) -> void:
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
	var data: Dictionary = MILESTONES[lvl] as Dictionary

	if GameState.LEVEL_RESOURCES.has(lvl):
		var res_path: String = str(GameState.LEVEL_RESOURCES[lvl])
		if ResourceLoader.exists(res_path):
			var res := load(res_path) as LevelData
			if res:
				data["name"] = res.level_title.replace("Level %d: " % lvl, "").to_upper()
				data["target_dist"] = (res.chunk_scenes.size() - 1) * 50
				if res.biome_name == "tropical":
					data["biome"] = "Tropical Reef"
				elif res.biome_name == "bayou":
					data["biome"] = "Murky Bayou"
				elif res.biome_name == "brimstone":
					data["biome"] = "Volcanic Brimstone"
	
	if popup_num:
		popup_num.text = "EXPEDITION %02d" % lvl
	if popup_title:
		popup_title.text = data["name"]
	if popup_biome:
		popup_biome.text = "%s  •  Target: %dm" % [data["biome"], data["target_dist"]]
		
	if popup_score:
		var best: int = int(GameState.level_high_scores.get(lvl, 0))
		var stars: int = int(GameState.level_stars.get(lvl, 0))
		var stars_str := ""
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
				popup_boss_label.text = "☠ %s" % str(data["boss_name"]).to_upper()
		else:
			popup_boss_tag.visible = false
			
	popup_scrim.visible = true
	popup_panel.scale = Vector2(0.8, 0.8)
	popup_panel.modulate.a = 0.0
	
	var pt := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pt.tween_property(popup_panel, "scale", Vector2.ONE, 0.35)
	pt.tween_property(popup_panel, "modulate:a", 1.0, 0.25)
	_check_tutorial_guidance()

func _close_level_popup() -> void:
	if not popup_scrim or not popup_scrim.visible:
		return
		
	AudioManager.play_sfx("gate_passes", 0.9, 1.0)
	var pt := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	pt.tween_property(popup_panel, "scale", Vector2(0.85, 0.85), 0.2)
	pt.tween_property(popup_panel, "modulate:a", 0.0, 0.2)
	
	await pt.finished
	popup_scrim.visible = false
	_check_tutorial_guidance()

func _on_set_sail_pressed() -> void:
	if _tutorial_overlay and is_instance_valid(_tutorial_overlay):
		_tutorial_overlay.dismiss()
	AudioManager.play_sfx("gate_passes")
	GameState.select_level(popup_selected_level)
	sail_requested.emit(popup_selected_level)

func dismiss_tutorial_guidance() -> void:
	if _tutorial_overlay and is_instance_valid(_tutorial_overlay):
		_tutorial_overlay.dismiss()

func _check_tutorial_guidance() -> void:
	if not GameState.is_tutorial_in_progress():
		dismiss_tutorial_guidance()
		return

	# Only show guidance if river map itself is currently visible and active in the scene tree
	if not is_visible_in_tree() or not is_inside_tree():
		dismiss_tutorial_guidance()
		return

	var parent_canvas: CanvasLayer = get_parent() as CanvasLayer
	if parent_canvas and not parent_canvas.visible:
		dismiss_tutorial_guidance()
		return

	if not _tutorial_overlay or not is_instance_valid(_tutorial_overlay):
		_tutorial_overlay = GUIDANCE_SCENE.instantiate() as TutorialGuidanceOverlay
		add_child(_tutorial_overlay)

	# If level popup modal is open, guide directly to "SET SAIL" button
	if popup_scrim and popup_scrim.visible and btn_set_sail and is_instance_valid(btn_set_sail):
		var target_lvl: int = popup_selected_level
		var sail_text: String = "All hands on deck! Tap SET SAIL to enter the river!"
		match target_lvl:
			1: sail_text = "All hands on deck! Tap SET SAIL to enter the river!"
			2: sail_text = "Cast off! Let's conquer the second stretch!"
			3: sail_text = "Set Sail! Show those scoundrels the might of a true pirate sloop!"
			4: sail_text = "Cast off! Let's rain coconuts down the river!"
			5: sail_text = "All hands on deck! Tap SET SAIL to challenge the Dreadnought!"
		_tutorial_overlay.guide_to(
			btn_set_sail,
			sail_text,
			Vector2.UP,
			"QUARTERMASTER",
			"tut_map_set_sail_%d" % target_lvl
		)
		return

	# Otherwise, guide to the appropriate level milestone node on the river
	match GameState.tutorial_step:
		GameState.TutorialStep.NOT_STARTED:
			_guide_to_milestone_node(1, "Select the first river channel to begin yer voyage!", "tut_map_select_level_1")
		GameState.TutorialStep.LEVEL_1_COMPLETED:
			_guide_to_milestone_node(2, "Channel Two lies ahead! Prepare to maneuver through treacherous rocks!", "tut_map_select_level_2")
		GameState.TutorialStep.SLOOP_PURCHASED:
			_guide_to_milestone_node(3, "Select Channel Three! Time to unleash the Sloop's twin cannons!", "tut_map_select_level_3")
		GameState.TutorialStep.LEVEL_3_COMPLETED:
			var parent_hub: Node = get_parent()
			if parent_hub:
				var back_btn: BaseButton = parent_hub.find_child("BtnCloseRiverMap", true, false) as BaseButton
				if back_btn:
					_tutorial_overlay.guide_to(back_btn, "Recruit crew first! Return to Smuggler's Cove to visit the Drydock!", Vector2.UP, "QUARTERMASTER", "tut_map_return_to_hub")
		GameState.TutorialStep.CREW_EQUIPPED:
			_guide_to_milestone_node(4, "Crew stationed! Select Level 4 to test explosive coconuts!", "tut_map_select_level_4")
		GameState.TutorialStep.LEVEL_4_COMPLETED:
			var parent_hub: Node = get_parent()
			if parent_hub:
				var back_btn: BaseButton = parent_hub.find_child("BtnCloseRiverMap", true, false) as BaseButton
				if back_btn:
					_tutorial_overlay.guide_to(back_btn, "Upgrade your vessel first! Return to Smuggler's Cove to visit the Drydock!", Vector2.UP, "QUARTERMASTER", "tut_map_return_to_hub_upgrade")
		GameState.TutorialStep.SLOOP_T2_UPGRADED:
			_guide_to_milestone_node(5, "Plot your course for Channel 5, Captain! The river belongs to you!", "tut_map_select_level_5")
		_:
			if _tutorial_overlay and is_instance_valid(_tutorial_overlay):
				_tutorial_overlay.dismiss()


func _guide_to_milestone_node(lvl: int, text_content: String, voice_id: String) -> void:
	var container: Control = node_controls.get(lvl, null) as Control
	if not container:
		return
	_focus_on_level(lvl, false)
	var btn: Control = container.get_node_or_null("TouchButton") as Control
	var target_ctrl: Control = btn if btn else container
	if _tutorial_overlay:
		_tutorial_overlay.guide_to(target_ctrl, text_content, Vector2.UP, "QUARTERMASTER", voice_id)

func _format_number(val: int) -> String:
	var s := str(abs(val))
	var res := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		res = s[i] + res
		count += 1
		if count % 3 == 0 and i > 0:
			res = "," + res
	return res
