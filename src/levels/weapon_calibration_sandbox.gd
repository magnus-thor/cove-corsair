extends Node3D

@export var target_ship: ShipData = preload("res://src/data/resources/dinghy_ship.tres")

@onready var player_boat: CharacterBody3D = $PlayerBoat

# Preloaded Ship Resources for multi-vessel calibration
var dinghy_ship: ShipData = preload("res://src/data/resources/dinghy_ship.tres")
var sloop_ship: ShipData = preload("res://src/data/resources/sloop_ship.tres")
var ironclad_ship: ShipData = preload("res://src/data/resources/ironclad_ship.tres")

# Available Weapon & Crew Resources for live asset previewing
var available_assets: Array[Dictionary] = [
	{"name": "[ Default Ship Tier ]", "data": null},
	{"name": "Monkey Bomber (Crew)", "data": preload("res://src/data/resources/crew_monkey_bomber.tres")},
	{"name": "Skeleton Deckhand (Crew)", "data": preload("res://src/data/resources/crew_skeleton_tosser.tres")},
	{"name": "Bow Chaser (Cannon)", "data": preload("res://src/data/resources/weapon_bow_chaser.tres")},
	{"name": "Port Swivel (Gun)", "data": preload("res://src/data/resources/weapon_port_swivel.tres")},
	{"name": "Starboard Swivel (Gun)", "data": preload("res://src/data/resources/weapon_starboard_swivel.tres")},
	{"name": "Deckhand Sniper (Crew)", "data": preload("res://src/data/resources/weapon_deckhand_sniper.tres")},
	{"name": "Aft Mortar (Cannon)", "data": preload("res://src/data/resources/weapon_aft_mortar.tres")}
]

# UI References
@onready var ship_option: OptionButton = %ship_option
@onready var tier_option: OptionButton = %tier_option
@onready var socket_option: OptionButton = %socket_option
@onready var asset_option: OptionButton = %asset_option

@onready var slider_pos_x: HSlider = %slider_pos_x
@onready var slider_pos_y: HSlider = %slider_pos_y
@onready var slider_pos_z: HSlider = %slider_pos_z
@onready var slider_rot_y: HSlider = %slider_rot_y
@onready var slider_scale: HSlider = %slider_scale

@onready var input_pos_x: LineEdit = %input_pos_x
@onready var input_pos_y: LineEdit = %input_pos_y
@onready var input_pos_z: LineEdit = %input_pos_z
@onready var input_rot_y: LineEdit = %input_rot_y
@onready var input_scale: LineEdit = %input_scale

@onready var btn_pos_x_dec: Button = %btn_pos_x_dec
@onready var btn_pos_x_inc: Button = %btn_pos_x_inc
@onready var btn_pos_y_dec: Button = %btn_pos_y_dec
@onready var btn_pos_y_inc: Button = %btn_pos_y_inc
@onready var btn_pos_z_dec: Button = %btn_pos_z_dec
@onready var btn_pos_z_inc: Button = %btn_pos_z_inc
@onready var btn_rot_y_dec: Button = %btn_rot_y_dec
@onready var btn_rot_y_inc: Button = %btn_rot_y_inc
@onready var btn_scale_dec: Button = %btn_scale_dec
@onready var btn_scale_inc: Button = %btn_scale_inc

@onready var btn_tier1: Button = %btn_tier1
@onready var btn_tier2: Button = %btn_tier2
@onready var btn_tier3: Button = %btn_tier3
@onready var btn_print_dict: Button = %btn_print_dict
@onready var btn_fire_toggle: Button = %btn_fire_toggle
@onready var btn_clear_all: Button = %btn_clear_all

var sockets: Array[String] = []
var active_socket: String = ""
var updating_ui: bool = false

func _ready() -> void:
	GameState.is_game_active = true
	
	if player_boat:
		player_boat.is_calibration_mode = true
		player_boat.global_position = Vector3.ZERO
		player_boat.is_shooting_enabled = false
		if target_ship:
			player_boat.apply_ship_data(target_ship)
			
	_setup_ui()

func _setup_ui() -> void:
	if ship_option:
		ship_option.clear()
		ship_option.add_item("The Dinghy")
		ship_option.add_item("The Sloop")
		ship_option.add_item("The Ironclad")
		if target_ship:
			if target_ship.ship_id == "sloop":
				ship_option.selected = 1
			elif target_ship.ship_id == "ironclad":
				ship_option.selected = 2
			else:
				ship_option.selected = 0
		ship_option.item_selected.connect(_on_ship_selected)

	if asset_option:
		asset_option.clear()
		for item in available_assets:
			asset_option.add_item(item["name"])
		asset_option.selected = 0
		asset_option.item_selected.connect(_on_asset_selected)

	_refresh_ship_sockets_and_tiers()
	
	if slider_pos_x: slider_pos_x.value_changed.connect(_on_slider_changed)
	if slider_pos_y: slider_pos_y.value_changed.connect(_on_slider_changed)
	if slider_pos_z: slider_pos_z.value_changed.connect(_on_slider_changed)
	if slider_rot_y: slider_rot_y.value_changed.connect(_on_slider_changed)
	if slider_scale: slider_scale.value_changed.connect(_on_slider_changed)
	
	if input_pos_x:
		input_pos_x.text_submitted.connect(func(t): _on_input_submitted(slider_pos_x, t))
		input_pos_x.focus_exited.connect(func(): _on_input_submitted(slider_pos_x, input_pos_x.text))
	if input_pos_y:
		input_pos_y.text_submitted.connect(func(t): _on_input_submitted(slider_pos_y, t))
		input_pos_y.focus_exited.connect(func(): _on_input_submitted(slider_pos_y, input_pos_y.text))
	if input_pos_z:
		input_pos_z.text_submitted.connect(func(t): _on_input_submitted(slider_pos_z, t))
		input_pos_z.focus_exited.connect(func(): _on_input_submitted(slider_pos_z, input_pos_z.text))
	if input_rot_y:
		input_rot_y.text_submitted.connect(func(t): _on_input_submitted(slider_rot_y, t))
		input_rot_y.focus_exited.connect(func(): _on_input_submitted(slider_rot_y, input_rot_y.text))
	if input_scale:
		input_scale.text_submitted.connect(func(t): _on_input_submitted(slider_scale, t))
		input_scale.focus_exited.connect(func(): _on_input_submitted(slider_scale, input_scale.text))

	if btn_pos_x_dec: btn_pos_x_dec.pressed.connect(func(): _step_slider(slider_pos_x, -0.01))
	if btn_pos_x_inc: btn_pos_x_inc.pressed.connect(func(): _step_slider(slider_pos_x, 0.01))
	if btn_pos_y_dec: btn_pos_y_dec.pressed.connect(func(): _step_slider(slider_pos_y, -0.01))
	if btn_pos_y_inc: btn_pos_y_inc.pressed.connect(func(): _step_slider(slider_pos_y, 0.01))
	if btn_pos_z_dec: btn_pos_z_dec.pressed.connect(func(): _step_slider(slider_pos_z, -0.01))
	if btn_pos_z_inc: btn_pos_z_inc.pressed.connect(func(): _step_slider(slider_pos_z, 0.01))
	if btn_rot_y_dec: btn_rot_y_dec.pressed.connect(func(): _step_slider(slider_rot_y, -1.0))
	if btn_rot_y_inc: btn_rot_y_inc.pressed.connect(func(): _step_slider(slider_rot_y, 1.0))
	if btn_scale_dec: btn_scale_dec.pressed.connect(func(): _step_slider(slider_scale, -0.01))
	if btn_scale_inc: btn_scale_inc.pressed.connect(func(): _step_slider(slider_scale, 0.01))
	
	if btn_tier1:
		btn_tier1.pressed.connect(func(): _on_equip_tier(1))
	if btn_tier2:
		btn_tier2.pressed.connect(func(): _on_equip_tier(2))
	if btn_tier3:
		btn_tier3.pressed.connect(func(): _on_equip_tier(3))
		
	if btn_print_dict:
		btn_print_dict.pressed.connect(_on_btn_print_dict_pressed)
	if btn_fire_toggle:
		btn_fire_toggle.pressed.connect(_on_btn_fire_toggle_pressed)
		_update_fire_toggle_button()
	if btn_clear_all:
		btn_clear_all.pressed.connect(_on_btn_clear_all_pressed)

func _on_input_submitted(slider: HSlider, text: String) -> void:
	if not slider:
		return
	var val = text.to_float()
	slider.value = clamp(val, slider.min_value, slider.max_value)

func _refresh_ship_sockets_and_tiers() -> void:
	sockets.clear()
	if target_ship and "hardpoint_offsets" in target_ship:
		for k in target_ship.hardpoint_offsets.keys():
			sockets.append(String(k))
	else:
		sockets = ["BowMount", "MidDeckCrew"]

	if socket_option:
		socket_option.clear()
		for s in sockets:
			socket_option.add_item(s)
		socket_option.selected = 0
		if socket_option.item_selected.is_connected(_on_socket_selected):
			socket_option.item_selected.disconnect(_on_socket_selected)
		socket_option.item_selected.connect(_on_socket_selected)

	if sockets.size() > 0:
		active_socket = sockets[0]
	else:
		active_socket = ""

	var num_tiers = target_ship.tier_upgrades.size() if target_ship and target_ship.tier_upgrades else 2
	if tier_option:
		tier_option.clear()
		for i in range(num_tiers):
			tier_option.add_item("Tier %d" % (i + 1))
		tier_option.selected = 0
		if tier_option.item_selected.is_connected(_on_tier_selected):
			tier_option.item_selected.disconnect(_on_tier_selected)
		tier_option.item_selected.connect(_on_tier_selected)

	if btn_tier1: btn_tier1.visible = (num_tiers >= 1)
	if btn_tier2: btn_tier2.visible = (num_tiers >= 2)
	if btn_tier3: btn_tier3.visible = (num_tiers >= 3)

	_update_ui_from_current_socket()

func _on_equip_tier(tier: int) -> void:
	if player_boat:
		player_boat.apply_tier(tier)
		if tier_option and tier - 1 < tier_option.item_count:
			tier_option.selected = tier - 1
		if asset_option:
			asset_option.selected = 0
		_update_ui_from_current_socket()

func _on_asset_selected(idx: int) -> void:
	if not player_boat or active_socket.is_empty():
		return
	if idx > 0 and idx < available_assets.size():
		var w_data: WeaponData = available_assets[idx]["data"]
		if w_data and player_boat.has_method("equip_weapon_to_socket"):
			player_boat.equip_weapon_to_socket(active_socket, w_data)
	else:
		# Reset to default ship tier
		var selected_tier = tier_option.selected + 1 if tier_option else 1
		player_boat.apply_tier(selected_tier)
	_update_ui_from_current_socket()

func _on_ship_selected(idx: int) -> void:
	match idx:
		0: target_ship = dinghy_ship
		1: target_ship = sloop_ship
		2: target_ship = ironclad_ship
	if player_boat and target_ship:
		player_boat.apply_ship_data(target_ship)
		_refresh_ship_sockets_and_tiers()
		var selected_tier = tier_option.selected + 1 if tier_option else 1
		player_boat.apply_tier(selected_tier)
	_update_ui_from_current_socket()

func _on_tier_selected(idx: int) -> void:
	_on_equip_tier(idx + 1)

func _on_socket_selected(idx: int) -> void:
	if idx >= 0 and idx < sockets.size():
		active_socket = sockets[idx]
		_update_ui_from_current_socket()

func _update_ui_from_current_socket() -> void:
	if not player_boat or active_socket.is_empty():
		return
	var hardpoints = player_boat.get_node_or_null("Hardpoints")
	if not hardpoints:
		return
	var socket_node = hardpoints.get_node_or_null(active_socket)
	if not socket_node:
		return
		
	updating_ui = true
	var pos = socket_node.position
	var rot_y = socket_node.rotation_degrees.y
	var sc = socket_node.scale.x
	
	if slider_pos_x: slider_pos_x.value = pos.x
	if slider_pos_y: slider_pos_y.value = pos.y
	if slider_pos_z: slider_pos_z.value = pos.z
	if slider_rot_y: slider_rot_y.value = rot_y
	if slider_scale: slider_scale.value = sc
	
	_update_inputs(pos, rot_y, sc)
	updating_ui = false

func _on_slider_changed(_val: float) -> void:
	if updating_ui or not player_boat or active_socket.is_empty():
		return
	var hardpoints = player_boat.get_node_or_null("Hardpoints")
	if not hardpoints:
		return
	var socket_node = hardpoints.get_node_or_null(active_socket)
	if not socket_node:
		return
		
	var new_pos = Vector3(slider_pos_x.value, slider_pos_y.value, slider_pos_z.value)
	var new_rot_y = slider_rot_y.value
	var new_scale = slider_scale.value if slider_scale else 1.0
	
	socket_node.position = new_pos
	socket_node.rotation_degrees.y = new_rot_y
	socket_node.scale = Vector3.ONE * new_scale
	
	if target_ship:
		target_ship.hardpoint_offsets[active_socket] = new_pos
		target_ship.hardpoint_rotations[active_socket] = socket_node.rotation_degrees
		target_ship.hardpoint_scales[active_socket] = socket_node.scale
		
	_update_inputs(new_pos, new_rot_y, new_scale)

func _step_slider(slider: HSlider, delta: float) -> void:
	if slider:
		slider.value = clamp(slider.value + delta, slider.min_value, slider.max_value)

func _update_inputs(pos: Vector3, rot_y: float, sc: float = 1.0) -> void:
	if input_pos_x and not input_pos_x.has_focus(): input_pos_x.text = "%.2f" % pos.x
	if input_pos_y and not input_pos_y.has_focus(): input_pos_y.text = "%.2f" % pos.y
	if input_pos_z and not input_pos_z.has_focus(): input_pos_z.text = "%.2f" % pos.z
	if input_rot_y and not input_rot_y.has_focus(): input_rot_y.text = "%.1f" % rot_y
	if input_scale and not input_scale.has_focus(): input_scale.text = "%.2f" % sc

func _on_btn_print_dict_pressed() -> void:
	if not player_boat or not target_ship:
		return
	var hardpoints = player_boat.get_node_or_null("Hardpoints")
	if not hardpoints:
		return
		
	var active_sockets: Array[String] = []
	for k in target_ship.hardpoint_offsets.keys():
		active_sockets.append(String(k))
			
	var ship_name_str = target_ship.ship_name if target_ship else "Active Vessel"
	print("\n==========================================")
	print("COPY & PASTE DICTIONARY FOR: %s" % ship_name_str)
	print("==========================================")
	print("hardpoint_offsets = {")
	for i in range(active_sockets.size()):
		var k = active_sockets[i]
		var socket_node = hardpoints.get_node_or_null(k)
		var p = socket_node.position if socket_node else target_ship.hardpoint_offsets.get(k, Vector3.ZERO)
		var comma = "," if i < active_sockets.size() - 1 else ""
		print('"%s": Vector3(%.2f, %.2f, %.2f)%s' % [k, p.x, p.y, p.z, comma])
	print("}")
	print("hardpoint_rotations = {")
	for i in range(active_sockets.size()):
		var k = active_sockets[i]
		var socket_node = hardpoints.get_node_or_null(k)
		var r = socket_node.rotation_degrees if socket_node else Vector3.ZERO
		var comma = "," if i < active_sockets.size() - 1 else ""
		print('"%s": Vector3(%.1f, %.1f, %.1f)%s' % [k, r.x, r.y, r.z, comma])
	print("}")
	print("hardpoint_scales = {")
	for i in range(active_sockets.size()):
		var k = active_sockets[i]
		var socket_node = hardpoints.get_node_or_null(k)
		var sc = socket_node.scale if socket_node else Vector3.ONE
		var comma = "," if i < active_sockets.size() - 1 else ""
		print('"%s": Vector3(%.2f, %.2f, %.2f)%s' % [k, sc.x, sc.y, sc.z, comma])
	print("}")
	print("==========================================\n")

func _on_btn_fire_toggle_pressed() -> void:
	if player_boat:
		player_boat.is_shooting_enabled = not player_boat.is_shooting_enabled
		_update_fire_toggle_button()

func _on_btn_clear_all_pressed() -> void:
	if player_boat:
		player_boat.clear_all_weapons()

func _update_fire_toggle_button() -> void:
	if btn_fire_toggle and player_boat:
		var status = "ON" if player_boat.is_shooting_enabled else "OFF"
		btn_fire_toggle.text = "Auto-Fire: " + status
