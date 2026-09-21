extends Area3D

var target_offset: Vector3 = Vector3.ZERO
var lerp_speed: float = 14.0
var rotation_lerp_speed: float = 12.0
var weapon_instance: Node3D = null
var equipped_weapons: Dictionary = {}

func _ready() -> void:
	_clean_shadow_nodes(self)
	add_to_group("follower")
	add_to_group("player")
	
	area_entered.connect(_on_area_entered)
	
	# Match visual sprite and collision shape to player's active vessel
	var player: Node3D = null
	for p: Node in get_tree().get_nodes_in_group("player"):
		if p != self and not p.is_in_group("follower") and p is Node3D:
			player = p as Node3D
			break
	var sf: float = 1.0
	if player and player.has_method("get_fleet_scale_factor"):
		var followers_count: int = 1
		if "follower_boats" in player:
			var fb_arr: Variant = player.get("follower_boats")
			if fb_arr is Array:
				followers_count = (fb_arr as Array).size() + 1
		sf = float(player.call("get_fleet_scale_factor", followers_count))
		
	if player and "ship_data" in player and player.get("ship_data"):
		var sprite := get_node_or_null("Sprite3D") as Sprite3D
		var model_mesh := get_node_or_null("BoatMesh") as Node3D
		var s_data: ShipData = player.get("ship_data") as ShipData
		var model_to_load: PackedScene = null
		if "model_scene" in s_data and s_data.model_scene:
			model_to_load = s_data.model_scene
		elif s_data.ship_id == "dinghy":
			var dinghy_glb := "res://assets/models/user/vessels/dinghy.glb"
			if ResourceLoader.exists(dinghy_glb):
				model_to_load = load(dinghy_glb) as PackedScene

		if model_to_load:
			if sprite:
				sprite.visible = false
			if not model_mesh:
				model_mesh = model_to_load.instantiate() as Node3D
				if model_mesh:
					model_mesh.name = "BoatMesh"
					add_child(model_mesh)
					_clean_shadow_nodes(model_mesh)
			if model_mesh:
				model_mesh.visible = true
				var base_sc: Vector3 = s_data.scale if ("scale" in s_data and s_data.scale != Vector3.ZERO) else Vector3.ONE
				model_mesh.scale = base_sc * sf
				model_mesh.position = Vector3(0, s_data.y_offset if "y_offset" in s_data else 0.0, 0)
				model_mesh.rotation_degrees = s_data.rotation_degrees if ("rotation_degrees" in s_data and s_data.rotation_degrees != Vector3.ZERO) else Vector3.ZERO
				if s_data.ship_id == "dinghy" and not model_mesh.has_node("CockpitWaterMask"):
					var mask := MeshInstance3D.new()
					mask.name = "CockpitWaterMask"
					mask.mesh = preload("res://assets/models/user/vessels/dinghy_cockpit_mask.tres")
					model_mesh.add_child(mask)
		elif sprite and s_data.sprite_texture:
			if model_mesh:
				model_mesh.visible = false
			sprite.visible = true
			sprite.texture = s_data.sprite_texture
			sprite.pixel_size = s_data.pixel_size
			var pitch: float = float(player.get("player_pitch_deg")) if "player_pitch_deg" in player else -60.0
			var rot: Vector3 = s_data.rotation_degrees if ("rotation_degrees" in s_data and s_data.rotation_degrees != Vector3.ZERO) else Vector3(pitch, 0, 0)
			sprite.rotation_degrees = rot
			sprite.position = Vector3(0, s_data.y_offset if "y_offset" in s_data else 0.485, 0)
			var base_sc: Vector3 = s_data.scale if ("scale" in s_data and s_data.scale != Vector3.ZERO) else Vector3.ONE
			sprite.scale = base_sc * sf
			
		var col := get_node_or_null("CollisionShape3D") as CollisionShape3D
		if col and col.shape is BoxShape3D:
			var box := col.shape as BoxShape3D
			box.size = s_data.collision_size
			col.position = Vector3(0, s_data.collision_size.y * 0.5, 0)
			col.scale = Vector3.ONE * sf
	else:
		var sprite := get_node_or_null("Sprite3D") as Sprite3D
		if sprite:
			sprite.scale = Vector3.ONE * sf
	
	# Instantiate weapons matching the player's active ship
	setup_weapons_from_player(player, sf)

	# Attach stern hydrodynamic water wake
	var wake_scene := preload("res://src/vfx/boat_wake.tscn") as PackedScene
	if wake_scene:
		var wake := wake_scene.instantiate() as Node3D
		if wake:
			add_child(wake)
			wake.position = Vector3(0, 0.02, 0.8)
			wake.scale = Vector3(0.65, 0.65, 0.65) * sf

func setup_weapons_from_player(player: Node3D, sf: float = 1.0) -> void:
	var legacy_bow: Node3D = get_node_or_null("BowMount") as Node3D
	if legacy_bow:
		legacy_bow.visible = false
		for c: Node in legacy_bow.get_children():
			c.queue_free()

	var hardpoints: Node3D = get_node_or_null("Hardpoints") as Node3D
	if not hardpoints:
		hardpoints = Node3D.new()
		hardpoints.name = "Hardpoints"
		add_child(hardpoints)
		
	for w: Node in equipped_weapons.values():
		if is_instance_valid(w):
			w.queue_free()
	equipped_weapons.clear()
	for child: Node in hardpoints.get_children():
		child.queue_free()

	if not player or not ("ship_data" in player) or not player.get("ship_data"):
		return
	var s_data: ShipData = player.get("ship_data") as ShipData
	var tier_level: int = int(player.get("current_tier")) if "current_tier" in player else 1
	if GameState and GameState.vessel_tiers.has(s_data.ship_id):
		tier_level = GameState.get_vessel_tier(s_data.ship_id)

	var active_sockets: Array = []
	if s_data.tier_sockets.size() > 0:
		active_sockets = s_data.tier_sockets[clampi(tier_level - 1, 0, s_data.tier_sockets.size() - 1)]

	const DEFAULT_SOCKET_WEAPONS: Dictionary = {
		"BowMount": "res://src/data/resources/user_crew/weapon_bow_chaser.tres",
		"BowMortarMount": "res://src/data/resources/user_crew/weapon_bow_mortar.tres",
		"PortSwivelMount": "res://src/data/resources/user_crew/weapon_port_swivel.tres",
		"StarboardSwivelMount": "res://src/data/resources/user_crew/weapon_port_swivel.tres",
		"PortSwivelMount1": "res://src/data/resources/user_crew/weapon_port_swivel.tres",
		"PortSwivelMount2": "res://src/data/resources/user_crew/weapon_port_swivel.tres",
		"StarboardSwivelMount1": "res://src/data/resources/user_crew/weapon_port_swivel.tres",
		"StarboardSwivelMount2": "res://src/data/resources/user_crew/weapon_port_swivel.tres",
		"PortRailMount": "res://src/data/resources/user_crew/weapon_scattershot.tres",
		"StarboardRailMount": "res://src/data/resources/user_crew/weapon_scattershot.tres"
	}

	var weapons_map: Dictionary = DEFAULT_SOCKET_WEAPONS.duplicate()
	if "socket_weapons" in s_data and not s_data.socket_weapons.is_empty():
		weapons_map.merge(s_data.socket_weapons, true)

	var attached_weapon_scene: PackedScene = preload("res://src/gameplay/player/attached_weapon.tscn")
	if not attached_weapon_scene:
		return

	for socket_name: String in active_sockets:
		var s_lower: String = socket_name.to_lower()
		var w_data: WeaponData = null
		var c_id: String = ""
		var c_lvl: int = 1
		
		# If player has active instance in equipped_weapons, use its data
		if "equipped_weapons" in player and (player.get("equipped_weapons") is Dictionary) and (player.get("equipped_weapons") as Dictionary).has(socket_name):
			var pw: Node = (player.get("equipped_weapons") as Dictionary)[socket_name] as Node
			if pw and "weapon_data" in pw and pw.get("weapon_data"):
				w_data = pw.get("weapon_data") as WeaponData
			if pw and "crew_id" in pw:
				c_id = str(pw.get("crew_id"))
			if pw and "crew_level" in pw:
				c_lvl = int(pw.get("crew_level"))
				
		if not w_data:
			if "crew" in s_lower:
				c_id = GameState.get_equipped_crew(s_data.ship_id, socket_name) if GameState else ""
				if c_id != "" and GameState and GameState.CREW_CATALOG.has(c_id):
					var res_path: String = str(GameState.CREW_CATALOG[c_id].get("resource_path", ""))
					if res_path != "" and ResourceLoader.exists(res_path):
						w_data = load(res_path) as WeaponData
					c_lvl = GameState.get_crew_level(c_id)
			elif weapons_map.has(socket_name):
				var val: Variant = weapons_map[socket_name]
				if val is String and ResourceLoader.exists(val):
					w_data = load(val) as WeaponData
				elif val is WeaponData:
					w_data = val

		if not w_data:
			continue
			
		var socket: Node3D = Node3D.new()
		socket.name = socket_name
		hardpoints.add_child(socket)
		
		if s_data.hardpoint_offsets.has(socket_name):
			socket.position = s_data.hardpoint_offsets[socket_name] * sf
		if s_data.hardpoint_rotations.has(socket_name):
			socket.rotation_degrees = s_data.hardpoint_rotations[socket_name]
		if s_data.hardpoint_scales.has(socket_name):
			socket.scale = s_data.hardpoint_scales[socket_name] * sf
			
		var w_inst: AttachedWeapon = attached_weapon_scene.instantiate() as AttachedWeapon
		w_inst.crew_id = c_id
		w_inst.crew_level = c_lvl
		w_inst.setup_weapon(w_data)
		socket.add_child(w_inst)
		equipped_weapons[socket_name] = w_inst
		
		if "bow" in s_lower or "mortar" in s_lower:
			weapon_instance = w_inst

func set_target_offset(offset: Vector3) -> void:
	target_offset = offset

func tween_scale(target_sf: float, duration: float) -> void:
	var sprite := get_node_or_null("Sprite3D") as Sprite3D
	var player: Node = get_tree().get_first_node_in_group("player")
	var base_sc := Vector3.ONE
	if player and "ship_data" in player and player.get("ship_data"):
		var s_data := player.get("ship_data") as ShipData
		if s_data and s_data.scale != Vector3.ZERO:
			base_sc = s_data.scale
	if sprite and sprite.visible:
		var t := create_tween().set_parallel(true)
		t.tween_property(sprite, "scale", base_sc * target_sf, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var model_mesh := get_node_or_null("BoatMesh") as Node3D
	if model_mesh and model_mesh.visible:
		var t_m := create_tween()
		t_m.tween_property(model_mesh, "scale", base_sc * target_sf, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var col := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col:
		var t_col := create_tween()
		t_col.tween_property(col, "scale", Vector3.ONE * target_sf, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var bow := get_node_or_null("BowMount") as Node3D
	if bow:
		var t_bow := create_tween()
		t_bow.tween_property(bow, "scale", Vector3.ONE * target_sf, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var hardpoints: Node3D = get_node_or_null("Hardpoints") as Node3D
	if hardpoints and player and "ship_data" in player and player.get("ship_data"):
		var s_data: ShipData = player.get("ship_data") as ShipData
		for socket_name: String in equipped_weapons.keys():
			var socket: Node3D = hardpoints.get_node_or_null(socket_name) as Node3D
			if socket and s_data:
				var base_pos: Vector3 = s_data.hardpoint_offsets.get(socket_name, Vector3.ZERO)
				var base_scale: Vector3 = s_data.hardpoint_scales.get(socket_name, Vector3.ONE)
				var t_sock: Tween = create_tween().set_parallel(true)
				t_sock.tween_property(socket, "position", base_pos * target_sf, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				t_sock.tween_property(socket, "scale", base_scale * target_sf, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _physics_process(delta: float) -> void:
	var player: Node3D = null
	for p: Node in get_tree().get_nodes_in_group("player"):
		if p != self and not p.is_in_group("follower") and ("is_game_over" in p) and p is Node3D:
			player = p as Node3D
			break
	if not player or not is_instance_valid(player):
		return
		
	if "is_game_over" in player and player.get("is_game_over") == true:
		return
		
	# Mirror movement with tight lerp delay
	var target_pos: Vector3 = player.global_position + player.global_transform.basis * target_offset
	target_pos.x = clampf(target_pos.x, -5.0, 5.0)
	global_position = global_position.lerp(target_pos, lerp_speed * delta)
	global_position.x = clampf(global_position.x, -5.0, 5.0)
	
	# Match rotation
	var p_basis: Basis = player.global_transform.basis.orthonormalized()
	var cur_basis := global_transform.basis.orthonormalized()
	global_transform.basis = cur_basis.slerp(p_basis, rotation_lerp_speed * delta).orthonormalized()
	
	# Auto-fires in sync with the fleet
	var shooting_enabled: bool = (player.get("is_shooting_enabled") == true) if ("is_shooting_enabled" in player) else true
	var rate_mult: float = float(player.get("fire_rate_multiplier")) if ("fire_rate_multiplier" in player) else 1.0
	var tier_mult: float = float(player.get("tier_fire_rate_multiplier")) if ("tier_fire_rate_multiplier" in player) else 1.0
	if shooting_enabled:
		for w: Node in equipped_weapons.values():
			if is_instance_valid(w) and w.has_method("try_fire"):
				w.call("try_fire", delta * rate_mult * tier_mult)

func _on_area_entered(area: Area3D) -> void:
	if area.is_in_group("collectibles") or area.is_in_group("cannonballs") or area.is_in_group("multiplier_gate") or area.is_in_group("player") or area.is_in_group("follower"):
		return
		
	if area.is_in_group("destructible") or area.is_in_group("enemies") or area.is_in_group("boss"):
		AudioManager.play_sfx("barrel_breaks")
		if area.is_in_group("boss") or (area.get_parent() and area.get_parent().is_in_group("boss")):
			if area.has_method("take_damage"):
				area.call("take_damage", 10)
		elif area.has_method("take_damage"):
			area.call("take_damage", 10)
		elif area.has_method("die"):
			area.call("die")
		else:
			area.queue_free()
		
		destroy_follower()


func destroy_follower() -> void:
	if VFXManager and VFXManager.has_method("spawn_wood_debris"):
		VFXManager.spawn_wood_debris(global_position)
	var player: Node = get_tree().get_first_node_in_group("player")
	if player and player.has_method("remove_follower"):
		player.call("remove_follower", self)
	queue_free()

func _clean_shadow_nodes(node: Node) -> void:
	if not node:
		return
	var lower_name: String = str(node.name).to_lower()
	var is_shadow_node: bool = false
	if "shadow" in lower_name or "decal" in lower_name or "projector" in lower_name or "card" in lower_name or "oblate" in lower_name or "shadow_sphere" in lower_name or "sphere_shadow" in lower_name:
		is_shadow_node = true
		
	if is_shadow_node:
		if node is Sprite3D or node is MeshInstance3D or node is Decal or node.get_class() == "Decal3D":
			node.queue_free()
			return
			
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if "shadow" in lower_name or "plane" in lower_name or "billboard" in lower_name or "card" in lower_name:
			mesh_node.visible = false
			mesh_node.queue_free()
			return
			
	for child: Node in node.get_children():
		_clean_shadow_nodes(child)
