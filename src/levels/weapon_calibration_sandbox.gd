extends Node3D

@export var target_ship: ShipData = preload("res://src/data/resources/user_vessels/dinghy_ship.tres")

@onready var player_boat: CharacterBody3D = $PlayerBoat

# Preloaded Ship Resources for multi-vessel calibration
var dinghy_ship: ShipData = preload("res://src/data/resources/user_vessels/dinghy_ship.tres")
var sloop_ship: ShipData = preload("res://src/data/resources/user_vessels/sloop_ship.tres")
var ironclad_ship: ShipData = preload("res://src/data/resources/user_vessels/ironclad_ship.tres")

# Dynamic Weapon, Crew, and Ammunition options populated per active vessel
var available_assets: Array[Dictionary] = []
var available_ammunition: Array[Dictionary] = []

# UI References
@onready var camera_3d: Camera3D = $Camera3D
@onready var panel_container: PanelContainer = %PanelContainer
@onready var btn_toggle_ui: Button = %btn_toggle_ui

@onready var btn_cam_rear: Button = %btn_cam_rear
@onready var btn_cam_top: Button = %btn_cam_top
@onready var btn_cam_lane: Button = %btn_cam_lane
@onready var btn_cam_side: Button = %btn_cam_side

@onready var slider_zoom: HSlider = %slider_zoom
@onready var btn_zoom_in: Button = %btn_zoom_in
@onready var btn_zoom_out: Button = %btn_zoom_out
@onready var btn_zoom_reset: Button = %btn_zoom_reset

enum CamView { REAR, TOP, LANE, SIDE }
var current_cam_view: CamView = CamView.REAR
var zoom_factor: float = 1.0

var is_orbiting: bool = false
var orbit_yaw: float = 0.0
var orbit_pitch: float = 0.0

@onready var ship_option: OptionButton = %ship_option
@onready var tier_option: OptionButton = %tier_option
@onready var socket_option: OptionButton = %socket_option
@onready var asset_option: OptionButton = %asset_option
@onready var ammo_option: OptionButton = %ammo_option

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
@onready var btn_reset_socket: Button = %btn_reset_socket
@onready var btn_reset_all: Button = %btn_reset_all
@onready var btn_print_dict: Button = %btn_print_dict
@onready var btn_fire_toggle: Button = %btn_fire_toggle
@onready var btn_clear_all: Button = %btn_clear_all

var sockets: Array[String] = []
var active_socket: String = ""
var updating_ui: bool = false
var default_offsets: Dictionary = {}
var default_rotations: Dictionary = {}
var default_scales: Dictionary = {}

func _ready() -> void:
	GameState.is_game_active = true
	
	if player_boat:
		player_boat.is_calibration_mode = true
		player_boat.global_position = Vector3.ZERO
		player_boat.is_shooting_enabled = false
		if target_ship:
			player_boat.apply_ship_data(target_ship)
			
	_setup_ui()
	_update_camera_buttons()
	_apply_camera_view()

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
		asset_option.item_selected.connect(_on_asset_selected)

	if ammo_option:
		ammo_option.item_selected.connect(_on_ammo_selected)

	_refresh_vessel_options()
	
	if btn_cam_rear: btn_cam_rear.pressed.connect(func(): _set_camera_view(CamView.REAR))
	if btn_cam_top: btn_cam_top.pressed.connect(func(): _set_camera_view(CamView.TOP))
	if btn_cam_lane: btn_cam_lane.pressed.connect(func(): _set_camera_view(CamView.LANE))
	if btn_cam_side: btn_cam_side.pressed.connect(func(): _set_camera_view(CamView.SIDE))
	
	if slider_zoom: slider_zoom.value_changed.connect(func(v): _on_zoom_changed(v))
	if btn_zoom_in: btn_zoom_in.pressed.connect(func(): _adjust_zoom(-0.1))
	if btn_zoom_out: btn_zoom_out.pressed.connect(func(): _adjust_zoom(0.1))
	if btn_zoom_reset: btn_zoom_reset.pressed.connect(func(): _reset_zoom())
	
	if btn_toggle_ui: btn_toggle_ui.pressed.connect(_toggle_ui_visibility)
	
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
		
	if btn_reset_socket:
		btn_reset_socket.pressed.connect(_on_btn_reset_socket_pressed)
	if btn_reset_all:
		btn_reset_all.pressed.connect(_on_btn_reset_all_pressed)
		
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

func _refresh_vessel_options() -> void:
	_refresh_ship_sockets_and_tiers()
	_refresh_vessel_assets_and_ammo()

func _refresh_ship_sockets_and_tiers() -> void:
	sockets.clear()
	default_offsets.clear()
	default_rotations.clear()
	default_scales.clear()
	
	if target_ship and "hardpoint_offsets" in target_ship:
		var raw_sockets: Array[String] = []
		for k in target_ship.hardpoint_offsets.keys():
			raw_sockets.append(String(k))
			default_offsets[String(k)] = target_ship.hardpoint_offsets[k]
		for k in target_ship.hardpoint_rotations.keys():
			default_rotations[String(k)] = target_ship.hardpoint_rotations[k]
		for k in target_ship.hardpoint_scales.keys():
			default_scales[String(k)] = target_ship.hardpoint_scales[k]
			
		var order_rank = func(s: String) -> int:
			var sl = s.to_lower()
			if "bow" in sl: return 0
			if "mid" in sl or "monkey" in sl: return 1
			if "aft" in sl or "skeleton" in sl: return 2
			if "port" in sl: return 3
			if "starboard" in sl: return 4
			return 5
		raw_sockets.sort_custom(func(a, b): return order_rank.call(a) < order_rank.call(b))
		sockets = raw_sockets
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

	var num_tiers = target_ship.tier_sockets.size() if target_ship and "tier_sockets" in target_ship and target_ship.tier_sockets else 2
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

func _refresh_vessel_assets_and_ammo() -> void:
	available_assets.clear()
	available_assets.append({"name": "[ Default Ship Tier ]", "data": null, "path": ""})
	
	var seen_asset_paths: Dictionary = {}
	if target_ship and "tier_sockets" in target_ship and target_ship.tier_sockets:
		for socket_list in target_ship.tier_sockets:
			for socket_name in socket_list:
				var val = target_ship.socket_weapons.get(socket_name, PlayerSwerve.DEFAULT_SOCKET_WEAPONS.get(socket_name, null)) if "socket_weapons" in target_ship else PlayerSwerve.DEFAULT_SOCKET_WEAPONS.get(socket_name, null)
				var res_path: String = ""
				var w_data: WeaponData = null
				if val is String:
					res_path = val
					if ResourceLoader.exists(res_path):
						w_data = load(res_path) as WeaponData
				elif val is WeaponData:
					w_data = val
					res_path = val.resource_path
					
				if w_data and not seen_asset_paths.has(res_path):
					seen_asset_paths[res_path] = true
					var display_name = w_data.weapon_name
					if w_data is CrewData or "crew" in w_data.weapon_type.to_lower():
						display_name += " (Crew)"
					elif "swivel" in w_data.weapon_type.to_lower():
						display_name += " (Swivel)"
					else:
						display_name += " (Cannon)"
					available_assets.append({"name": display_name, "data": w_data, "path": res_path})
					
					if "swivel" in socket_name.to_lower() or "swivel" in w_data.weapon_type.to_lower():
						var stb_path = "res://src/data/resources/user_crew/weapon_starboard_swivel.tres"
						if not seen_asset_paths.has(stb_path) and ResourceLoader.exists(stb_path):
							var stb_data = load(stb_path) as WeaponData
							if stb_data:
								seen_asset_paths[stb_path] = true
								available_assets.append({"name": stb_data.weapon_name + " (Swivel)", "data": stb_data, "path": stb_path})

	if asset_option:
		asset_option.clear()
		for item in available_assets:
			asset_option.add_item(item["name"])
		asset_option.selected = 0
		
	available_ammunition.clear()
	available_ammunition.append({"name": "[ Default Weapon Ammo ]", "data": null, "path": ""})
	
	var seen_ammo_paths: Dictionary = {}
	for asset in available_assets:
		var w_data: WeaponData = asset["data"]
		if not w_data:
			continue
		var ammo_candidates: Array = []
		if "default_ammo" in w_data and w_data.default_ammo:
			ammo_candidates.append(w_data.default_ammo)
		if "compatible_ammo" in w_data and w_data.compatible_ammo:
			for ca in w_data.compatible_ammo:
				if ca:
					ammo_candidates.append(ca)
					
		for a in ammo_candidates:
			var a_data: AmmoData = null
			var a_path: String = ""
			if a is String:
				a_path = a
				if ResourceLoader.exists(a_path):
					a_data = load(a_path) as AmmoData
			elif a is AmmoData:
				a_data = a
				a_path = a.resource_path
				
			if a_data and not seen_ammo_paths.has(a_path):
				seen_ammo_paths[a_path] = true
				var a_name = a_data.ammo_name if ("ammo_name" in a_data and not a_data.ammo_name.is_empty()) else a_path.get_file().get_basename().replace("ammo_", "").capitalize()
				available_ammunition.append({"name": a_name, "data": a_data, "path": a_path})

	if ammo_option:
		ammo_option.clear()
		for item in available_ammunition:
			ammo_option.add_item(item["name"])
		ammo_option.selected = 0

	_update_ui_from_current_socket()

func _on_equip_tier(tier: int) -> void:
	if player_boat:
		player_boat.apply_tier(tier)
		if tier_option and tier - 1 < tier_option.item_count:
			tier_option.selected = tier - 1
		if asset_option:
			asset_option.selected = 0
		_reapply_selected_ammo()
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
	_reapply_selected_ammo()
	_update_ui_from_current_socket()

func _on_ammo_selected(idx: int) -> void:
	if not player_boat:
		return
	var target_ammo: AmmoData = null
	if idx > 0 and idx < available_ammunition.size():
		target_ammo = available_ammunition[idx]["data"]
	_apply_ammo_override(target_ammo)

func _reapply_selected_ammo() -> void:
	if ammo_option and ammo_option.selected > 0 and ammo_option.selected < available_ammunition.size():
		var ammo_data: AmmoData = available_ammunition[ammo_option.selected]["data"]
		_apply_ammo_override(ammo_data)

func _apply_ammo_override(ammo_data: AmmoData) -> void:
	if not player_boat or not "equipped_weapons" in player_boat:
		return
	for socket_name in player_boat.equipped_weapons.keys():
		var weapon_node = player_boat.equipped_weapons[socket_name]
		if is_instance_valid(weapon_node) and "weapon_data" in weapon_node and weapon_node.weapon_data:
			if ammo_data != null:
				weapon_node.weapon_data.default_ammo = ammo_data

func _on_ship_selected(idx: int) -> void:
	match idx:
		0: target_ship = dinghy_ship
		1: target_ship = sloop_ship
		2: target_ship = ironclad_ship
	if player_boat and target_ship:
		player_boat.apply_ship_data(target_ship)
		_refresh_vessel_options()
		var selected_tier = tier_option.selected + 1 if tier_option else 1
		player_boat.apply_tier(selected_tier)
		_reapply_selected_ammo()
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
	
	# Update asset_option to reflect what weapon is currently in active_socket
	if asset_option and player_boat and "equipped_weapons" in player_boat:
		var equipped_w = player_boat.equipped_weapons.get(active_socket, null)
		var current_w_data = equipped_w.weapon_data if (equipped_w and is_instance_valid(equipped_w) and "weapon_data" in equipped_w) else null
		var found_asset_idx = 0
		if current_w_data:
			for i in range(1, available_assets.size()):
				if available_assets[i]["data"] == current_w_data or available_assets[i]["path"] == current_w_data.resource_path:
					found_asset_idx = i
					break
		asset_option.selected = found_asset_idx

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
		_update_ui_from_current_socket()

func _on_btn_reset_socket_pressed() -> void:
	if not player_boat or active_socket.is_empty():
		return
	var hardpoints = player_boat.get_node_or_null("Hardpoints")
	if not hardpoints:
		return
	var socket_node = hardpoints.get_node_or_null(active_socket)
	if not socket_node:
		return
		
	var orig_pos = default_offsets.get(active_socket, Vector3.ZERO)
	var orig_rot = default_rotations.get(active_socket, Vector3.ZERO)
	var orig_scale = default_scales.get(active_socket, Vector3.ONE)
	
	socket_node.position = orig_pos
	socket_node.rotation_degrees = orig_rot
	socket_node.scale = orig_scale
	
	if target_ship:
		target_ship.hardpoint_offsets[active_socket] = orig_pos
		target_ship.hardpoint_rotations[active_socket] = orig_rot
		target_ship.hardpoint_scales[active_socket] = orig_scale
		
	_update_ui_from_current_socket()

func _on_btn_reset_all_pressed() -> void:
	if not player_boat:
		return
	var hardpoints = player_boat.get_node_or_null("Hardpoints")
	if not hardpoints:
		return
		
	for s_name in sockets:
		var s_node = hardpoints.get_node_or_null(s_name)
		if s_node:
			var orig_pos = default_offsets.get(s_name, Vector3.ZERO)
			var orig_rot = default_rotations.get(s_name, Vector3.ZERO)
			var orig_scale = default_scales.get(s_name, Vector3.ONE)
			
			s_node.position = orig_pos
			s_node.rotation_degrees = orig_rot
			s_node.scale = orig_scale
			
			if target_ship:
				target_ship.hardpoint_offsets[s_name] = orig_pos
				target_ship.hardpoint_rotations[s_name] = orig_rot
				target_ship.hardpoint_scales[s_name] = orig_scale
				
	_update_ui_from_current_socket()

func _update_fire_toggle_button() -> void:
	if btn_fire_toggle and player_boat:
		var status = "ON" if player_boat.is_shooting_enabled else "OFF"
		btn_fire_toggle.text = "Auto-Fire: " + status

func _set_camera_view(view: CamView) -> void:
	current_cam_view = view
	orbit_yaw = 0.0
	orbit_pitch = 0.0
	_update_camera_buttons()
	_apply_camera_view()

func _update_camera_buttons() -> void:
	if btn_cam_rear: btn_cam_rear.text = "[ Behind ]" if current_cam_view == CamView.REAR else "Behind"
	if btn_cam_top: btn_cam_top.text = "[ Top ]" if current_cam_view == CamView.TOP else "Top"
	if btn_cam_lane: btn_cam_lane.text = "[ Lane ]" if current_cam_view == CamView.LANE else "Lane"
	if btn_cam_side: btn_cam_side.text = "[ Side ]" if current_cam_view == CamView.SIDE else "Side"

func _on_zoom_changed(v: float) -> void:
	zoom_factor = v
	_apply_camera_view()

func _adjust_zoom(delta: float) -> void:
	zoom_factor = clampf(zoom_factor + delta, 0.25, 2.5)
	if slider_zoom:
		slider_zoom.value = zoom_factor
	_apply_camera_view()

func _reset_zoom() -> void:
	zoom_factor = 1.0
	orbit_yaw = 0.0
	orbit_pitch = 0.0
	if slider_zoom:
		slider_zoom.value = 1.0
	_apply_camera_view()

func _toggle_ui_visibility() -> void:
	if panel_container:
		panel_container.visible = not panel_container.visible
		if btn_toggle_ui:
			btn_toggle_ui.text = "Show UI (H)" if not panel_container.visible else "Hide UI (H)"
		_apply_camera_view()

func _apply_camera_view() -> void:
	if not camera_3d:
		return
		
	var base_cam_pos = Vector3.ZERO
	var look_target = Vector3.ZERO
	var fov_val = 60.0
	
	match current_cam_view:
		CamView.REAR:
			# Directly behind the stern, looking forward down the deck along -Z
			base_cam_pos = Vector3(0.0, 1.45, 3.4)
			look_target = Vector3(0.0, 0.35, -0.15)
			fov_val = 60.0
		CamView.TOP:
			# High-angle top-down view looking down at the deck and forward
			base_cam_pos = Vector3(0.0, 8.5, 3.0)
			look_target = Vector3(0.0, 0.0, -0.5)
			fov_val = 65.0
		CamView.LANE:
			# In-game lane camera view matching object calibration sandbox
			base_cam_pos = Vector3(0.0, 9.851, 11.32)
			look_target = Vector3(0.0, 0.0, 0.0)
			fov_val = 70.0
		CamView.SIDE:
			# Starboard side profile view to check elevation / deck height
			base_cam_pos = Vector3(3.8, 0.95, 0.0)
			look_target = Vector3(0.0, 0.35, 0.0)
			fov_val = 55.0

	var cam_offset = (base_cam_pos - look_target) * zoom_factor
	if orbit_yaw != 0.0 or orbit_pitch != 0.0:
		var rot_basis = Basis(Vector3.UP, deg_to_rad(orbit_yaw))
		var right_axis = rot_basis.x
		rot_basis = Basis(right_axis, deg_to_rad(orbit_pitch)) * rot_basis
		cam_offset = rot_basis * cam_offset

	camera_3d.global_position = look_target + cam_offset
	camera_3d.look_at(look_target, Vector3.UP)
	camera_3d.fov = fov_val
	# Elevate framing into the open upper viewport when the bottom UI is open
	camera_3d.v_offset = -0.26 if (panel_container and panel_container.visible) else 0.0

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_H:
			_toggle_ui_visibility()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_adjust_zoom(-0.08)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_adjust_zoom(0.08)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			is_orbiting = event.pressed
	elif event is InputEventMouseMotion and is_orbiting:
		orbit_yaw += -event.relative.x * 0.4
		orbit_pitch = clampf(orbit_pitch - event.relative.y * 0.4, -80.0, 80.0)
		_apply_camera_view()
