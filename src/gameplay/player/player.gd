class_name PlayerSwerve
extends CharacterBody3D

signal health_changed(current: int, max_hp: int)
signal score_changed(new_score: int)
signal doubloons_changed(new_doubloons: int)
signal run_failed(coins_collected: int, distance_reached: float)

@export var ship_data: ShipData:
	set(val):
		if ship_data == val:
			return
		ship_data = val
		if is_node_ready() and ship_data:
			apply_ship_data(ship_data)

@export_group("Ship Data Tier Presets")
@export var dinghy_ship_data: ShipData = preload("res://src/data/resources/user_vessels/dinghy_ship.tres")
@export var sloop_ship_data: ShipData = preload("res://src/data/resources/user_vessels/sloop_ship.tres")
@export var ironclad_ship_data: ShipData = preload("res://src/data/resources/user_vessels/ironclad_ship.tres")
@export var bombard_skiff_ship_data: ShipData = preload("res://src/data/resources/user_vessels/bombard_skiff_ship.tres")

const DEFAULT_SOCKET_WEAPONS: Dictionary = {
	"BowMount": "res://src/data/resources/user_crew/weapon_bow_chaser.tres",
	"BowMortarMount": "res://src/data/resources/user_crew/weapon_bow_mortar.tres",
	"MidDeckCrew": "res://src/data/resources/user_crew/crew_monkey_bomber.tres",
	"MonkeyCrew": "res://src/data/resources/user_crew/crew_monkey_bomber.tres",
	"QuarterdeckCrew": "res://src/data/resources/user_crew/crew_monkey_bomber.tres",
	"AftDeckCrew": "res://src/data/resources/user_crew/crew_skeleton_tosser.tres",
	"SkeletonCrew": "res://src/data/resources/user_crew/crew_skeleton_tosser.tres",
	"PortSwivelMount": "res://src/data/resources/user_crew/weapon_port_swivel.tres",
	"StarboardSwivelMount": "res://src/data/resources/user_crew/weapon_port_swivel.tres",
	"PortSwivelMount1": "res://src/data/resources/user_crew/weapon_port_swivel.tres",
	"PortSwivelMount2": "res://src/data/resources/user_crew/weapon_port_swivel.tres",
	"StarboardSwivelMount1": "res://src/data/resources/user_crew/weapon_port_swivel.tres",
	"StarboardSwivelMount2": "res://src/data/resources/user_crew/weapon_port_swivel.tres",
	"PortRailMount": "res://src/data/resources/user_crew/weapon_scattershot.tres",
	"StarboardRailMount": "res://src/data/resources/user_crew/weapon_scattershot.tres"
}

## Width of the river channel boundaries. The boat can move within [-river_width/2, river_width/2]
@export var river_width: float = 12.0

## Touch/drag input sensitivity scaling factor.
@export var sensitivity: float = 0.015

## Keyboard movement speed in units per second.
@export var keyboard_speed: float = 15.0

## Interpolation speed for the horizontal translation. Higher values make the swerve more immediate.
@export var lerp_speed: float = 12.0

## Configurable floating and bobbing parameters
@export var bob_frequency: float = 2.2
@export var min_hover_height: float = 0.04
@export var max_hover_height: float = 0.08
@export var yaw_lerp_speed: float = 10.0

## The active ship tier
@export var current_tier: int = 1

## Cooldown duration between automatic shots in seconds
@export var shoot_cooldown: float = 0.45

## Multiplier applied to shooting speed
@export var fire_rate_multiplier: float = 1.0

## Damage bonus applied to all projectiles
@export var base_damage_bonus: int = 0

## The cannonball prefab scene to spawn
@export var cannonball_scene: PackedScene = preload("res://src/gameplay/projectiles/cannonball.tscn")

@onready var visuals: Node3D = $BoatVisuals

var dragging: bool = false
var target_x: float = 0.0
var half_width: float = 0.0

var max_health: int = 3
var current_health: int = 3

@export var target_score: int = 50

var equipped_weapons: Dictionary = {}
@export var follower_scene: PackedScene = preload("res://src/gameplay/player/follower_boat.tscn")
var follower_boats: Array[Node3D] = []
var active_reef_overlaps: int = 0
var scraping_timer: float = 0.0
var speed_multiplier: float = 1.0
var active_weapons: Array[Node] = []
var shoot_timer: float = 0.0
var score: int = 0
var doubloons: int = 0
var is_game_over: bool = false
var float_time: float = 0.0
var hit_invulnerability_timer: float = 0.0

@export var is_shooting_enabled: bool = false
@export var end_game_ui_scene: PackedScene = preload("res://src/ui/end_game_ui.tscn")

@export_group("Player Ship Orientation")
@export var player_pitch_deg: float = -60.0

@export_group("Calibration Mode")
@export var is_calibration_mode: bool = false

func _ready() -> void:
	_clean_shadow_nodes(self)
	add_to_group("player")
	target_x = global_position.x
	half_width = river_width / 2.0
	if visuals:
		visuals.rotation_degrees.y = 0.0
	var init_hp = get_node_or_null("Hardpoints")
	if init_hp:
		init_hp.rotation_degrees.y = 0.0
	
	# Dynamically construct collision area to detect overlapping Area3D obstacles
	var detection_area = Area3D.new()
	detection_area.name = "CollisionArea"
	add_child(detection_area)
	
	var col_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(1.6, 1.4, 2.8)
	col_shape.shape = box_shape
	detection_area.add_child(col_shape)
	col_shape.position = Vector3(0, 0.6, 0)
	
	detection_area.area_entered.connect(_on_area_entered)
	
	# Dynamically construct MagnetArea to attract Layer 4 Collectibles
	var magnet_area = get_node_or_null("MagnetArea") as Area3D
	if not magnet_area:
		magnet_area = Area3D.new()
		magnet_area.name = "MagnetArea"
		add_child(magnet_area)
		
	magnet_area.collision_layer = 0
	magnet_area.collision_mask = 8 # Layer 4 (Collectibles)
	magnet_area.monitoring = true
	magnet_area.monitorable = false

	var mag_shape = magnet_area.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if not mag_shape:
		mag_shape = CollisionShape3D.new()
		magnet_area.add_child(mag_shape)

	var sphere = SphereShape3D.new()
	sphere.radius = 4.5
	mag_shape.shape = sphere
	mag_shape.position = Vector3(0, 0.5, 0)
	
	magnet_area.area_entered.connect(_on_magnet_area_entered)
	
	if Engine.has_singleton("GameState") or get_node_or_null("/root/GameState"):
		if not GameState.active_vessel_changed.is_connected(_on_active_vessel_changed):
			GameState.active_vessel_changed.connect(_on_active_vessel_changed)
	
	var level_ship = GameState.get_current_ship_resource() if GameState.has_method("get_current_ship_resource") else null
	if level_ship:
		ship_data = level_ship
		
	if ship_data:
		apply_ship_data(ship_data)
	else:
		equip_weapon_to_socket("BowMount", preload("res://src/data/resources/user_crew/weapon_bow_chaser.tres"))
	
	if is_calibration_mode:
		_setup_calibration_mode()

func _on_active_vessel_changed(v_id: String) -> void:
	var ship = GameState.get_vessel_resource(v_id)
	if ship:
		apply_ship_data(ship)

func apply_ship_data(data: ShipData) -> void:
	if not data:
		return
	if ship_data != data:
		ship_data = data
	max_health = data.max_health
	current_health = data.max_health
	if "fire_rate" in data:
		shoot_cooldown = data.fire_rate
	keyboard_speed = data.move_speed
	lerp_speed = data.move_speed * 1.3
	
	if visuals:
		var boat_mesh = visuals.get_node_or_null("BoatMesh")
		var sprite = visuals.get_node_or_null("BoatSprite") as Sprite3D

		# Determine whether this vessel has a 3D model assigned
		var model_to_load: PackedScene = null
		if "model_scene" in data and data.model_scene:
			model_to_load = data.model_scene
		elif data.ship_id == "dinghy":
			var dinghy_glb = "res://assets/models/user/vessels/dinghy.glb"
			if ResourceLoader.exists(dinghy_glb):
				model_to_load = load(dinghy_glb)

		if model_to_load:
			if sprite:
				sprite.visible = false
			var is_same_model = false
			if boat_mesh:
				if boat_mesh.has_meta("model_source") and boat_mesh.get_meta("model_source") == model_to_load:
					is_same_model = true
				elif not boat_mesh.has_meta("model_source") and model_to_load.resource_path.ends_with("dinghy.glb"):
					boat_mesh.set_meta("model_source", model_to_load)
					is_same_model = true

			if boat_mesh and not is_same_model:
				visuals.remove_child(boat_mesh)
				boat_mesh.queue_free()
				boat_mesh = null

			if not boat_mesh:
				boat_mesh = model_to_load.instantiate()
				boat_mesh.name = "BoatMesh"
				boat_mesh.set_meta("model_source", model_to_load)
				visuals.add_child(boat_mesh)

			if boat_mesh:
				boat_mesh.visible = true
				boat_mesh.position = Vector3(0, data.y_offset if "y_offset" in data else 0.0, 0)
				boat_mesh.rotation_degrees = data.rotation_degrees if ("rotation_degrees" in data and data.rotation_degrees != Vector3.ZERO) else Vector3.ZERO
				var sc = data.scale if ("scale" in data and data.scale != Vector3.ZERO) else Vector3.ONE
				boat_mesh.scale = sc
				if data.ship_id == "dinghy" and not boat_mesh.has_node("CockpitWaterMask"):
					var mask = MeshInstance3D.new()
					mask.name = "CockpitWaterMask"
					mask.mesh = preload("res://assets/models/user/vessels/dinghy_cockpit_mask.tres")
					boat_mesh.add_child(mask)
		elif data.sprite_texture:
			if boat_mesh:
				boat_mesh.visible = false
			if not sprite:
				sprite = Sprite3D.new()
				sprite.name = "BoatSprite"
				visuals.add_child(sprite)
			sprite.visible = true
			sprite.texture = data.sprite_texture
			sprite.pixel_size = data.pixel_size
			var rot = data.rotation_degrees if ("rotation_degrees" in data and data.rotation_degrees != Vector3.ZERO) else Vector3(player_pitch_deg, 0, 0)
			sprite.rotation_degrees = rot
			sprite.position = Vector3(0, data.y_offset if "y_offset" in data else 0.485, 0)
			var sc = data.scale if ("scale" in data and data.scale != Vector3.ZERO) else Vector3.ONE
			sprite.scale = sc
			sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
			sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	
	# Update main character collision shape
	var body_col = get_node_or_null("CollisionShape3D") as CollisionShape3D
	if body_col:
		var box = body_col.shape as BoxShape3D
		if not box:
			box = BoxShape3D.new()
			body_col.shape = box
		box.size = data.collision_size
		body_col.position = Vector3(0, data.collision_size.y * 0.5, 0)
		
	# Update detection area collision shape
	var area_col = get_node_or_null("CollisionArea/CollisionShape3D") as CollisionShape3D
	if area_col:
		var area_box = area_col.shape as BoxShape3D
		if not area_box:
			area_box = BoxShape3D.new()
			area_col.shape = area_box
		area_box.size = Vector3(data.collision_size.x, data.collision_size.y + 0.2, data.collision_size.z)
		area_col.position = Vector3(0, (data.collision_size.y + 0.2) * 0.5, 0)
		
	# Update boat wake position based on collision_size
	var wake = get_node_or_null("BoatWake") as Node3D
	if wake and "collision_size" in data:
		var wake_z = data.collision_size.z * 0.5 - 0.1
		wake.position = Vector3(0, 0.02, max(1.2, wake_z))
		
	# Position and rotate all children under $Hardpoints according to data.hardpoint_offsets and data.hardpoint_rotations
	var hardpoints = get_node_or_null("Hardpoints")
	if hardpoints:
		# Prune any sockets that are not defined in the active ship's ship_data resource
		for socket in hardpoints.get_children():
			if not data.hardpoint_offsets.has(socket.name):
				hardpoints.remove_child(socket)
				socket.queue_free()
				
		for s_name in data.hardpoint_offsets.keys():
			var s_node = hardpoints.get_node_or_null(s_name)
			if not s_node:
				s_node = Node3D.new()
				s_node.name = s_name
				hardpoints.add_child(s_node)

		for socket in hardpoints.get_children():
			if socket is Node3D:
				var s_name = socket.name
				if data.hardpoint_offsets.has(s_name):
					socket.position = data.hardpoint_offsets[s_name]
				elif "y_offset" in data:
					socket.position.y = data.y_offset - 0.57735 * socket.position.z
					
				if data.hardpoint_rotations.has(s_name):
					var rot = data.hardpoint_rotations[s_name]
					if rot is Vector3:
						socket.rotation_degrees = rot

				if data.hardpoint_scales.has(s_name):
					var sc = data.hardpoint_scales[s_name]
					if sc is Vector3:
						socket.scale = sc
						
				# Wipe any existing weapons inside sockets
				for child in socket.get_children():
					child.queue_free()
		
		equipped_weapons.clear()

	# Initialize active tier using GameState active vessel tier
	var active_tier: int = GameState.get_active_ship_tier() if ("get_active_ship_tier" in GameState) else 1
	apply_tier(active_tier)
		
	health_changed.emit(current_health, max_health)

func apply_tier(tier_level: int) -> void:
	if not ship_data or ship_data.tier_sockets.is_empty():
		return
	current_tier = tier_level
	var active_sockets: Array = ship_data.tier_sockets[clampi(tier_level - 1, 0, ship_data.tier_sockets.size() - 1)]

	var weapons_map: Dictionary = DEFAULT_SOCKET_WEAPONS.duplicate()
	if "socket_weapons" in ship_data and not ship_data.socket_weapons.is_empty():
		weapons_map.merge(ship_data.socket_weapons, true)

	# Filter weapons_map directly against active_sockets
	var filtered_map: Dictionary = {}
	for s in active_sockets:
		if weapons_map.has(s):
			filtered_map[s] = weapons_map[s]
	weapons_map = filtered_map

	# Remove any currently equipped weapons whose sockets are no longer in this tier
	var sockets_to_remove: Array[String] = []
	for s in equipped_weapons.keys():
		if not weapons_map.has(s):
			sockets_to_remove.append(s)
	for s in sockets_to_remove:
		if is_instance_valid(equipped_weapons[s]):
			equipped_weapons[s].queue_free()
		equipped_weapons.erase(s)

	for socket_name in weapons_map:
		var val = weapons_map[socket_name]
		var w_data: WeaponData = null
		if val is String:
			w_data = load(val) as WeaponData
		elif val is WeaponData:
			w_data = val
		if w_data:
			equip_weapon_to_socket(socket_name, w_data)

func _unhandled_input(event: InputEvent) -> void:
	if is_game_over:
		return
		
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
	elif event is InputEventScreenTouch:
		dragging = event.pressed
	elif event is InputEventMouseMotion and dragging:
		target_x += event.relative.x * sensitivity
		target_x = clamp(target_x, -half_width, half_width)
	elif event is InputEventScreenDrag:
		target_x += event.relative.x * sensitivity
		target_x = clamp(target_x, -half_width, half_width)

func _physics_process(delta: float) -> void:
	if hit_invulnerability_timer > 0.0:
		hit_invulnerability_timer = maxf(0.0, hit_invulnerability_timer - delta)

	if is_game_over:
		return
		
	if is_calibration_mode:
		_process_calibration_controls(delta)
		return
		
	# Manage reef slow, scraping SFX, and wake spray
	if active_reef_overlaps > 0:
		speed_multiplier = 0.5
		scraping_timer += delta
		if scraping_timer >= 0.25:
			scraping_timer = 0.0
			AudioManager.play_sfx("barrel_hits", 1.15, 1.35, -8.0) # Scrape sound
			# Spawn water spray
			var spray_scene = preload("res://src/gameplay/vfx/boat_wake.tscn")
			if spray_scene:
				var spray = spray_scene.instantiate() as GPUParticles3D
				get_parent().add_child(spray)
				spray.global_position = global_position + Vector3(randf_range(-0.5, 0.5), 0.1, randf_range(-0.5, 0.5))
				spray.emitting = true
				var t = create_tween()
				t.tween_interval(1.0)
				t.tween_callback(spray.queue_free)
	else:
		speed_multiplier = 1.0

	# NOTE: distance tracking is owned solely by LevelController._physics_process.
	# Do NOT call GameState.update_distance() here — it causes double-counting.
		
	if not GameState.is_game_active:
		# Floating / Bobbing on water in calm harbor (facing forward upriver towards the horizon)
		float_time += delta * bob_frequency
		var idle_hover_height = lerp(min_hover_height, max_hover_height, (sin(float_time) + 1.0) * 0.5)
		if visuals:
			visuals.position.y = idle_hover_height
			visuals.rotation_degrees.x = sin(float_time * 1.5) * 2.0
			visuals.rotation_degrees.y = sin(float_time * 0.7) * 2.0
			visuals.rotation_degrees.z = sin(float_time * 1.1) * 1.5
			
			var hardpoints = get_node_or_null("Hardpoints")
			if hardpoints:
				hardpoints.visible = false
				hardpoints.position.y = visuals.position.y
				hardpoints.rotation_degrees.x = visuals.rotation_degrees.x
				hardpoints.rotation_degrees.y = visuals.rotation_degrees.y
				hardpoints.rotation_degrees.z = visuals.rotation_degrees.z
		return

	# 2. Keyboard fallback controls
	var input_dir: float = 0.0
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		input_dir -= 1.0
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		input_dir += 1.0
		
	if input_dir != 0.0:
		target_x += input_dir * keyboard_speed * speed_multiplier * delta
		target_x = clamp(target_x, -half_width, half_width)
		
	# 3. Smooth swerve horizontal interpolation
	var previous_x = position.x
	position.x = lerp(position.x, target_x, lerp_speed * speed_multiplier * delta)
	position.x = clamp(position.x, -half_width, half_width)
	var x_velocity = (position.x - previous_x) / delta if delta > 0.0 else 0.0
	
	# 4. Dynamic Roll and Yaw Banking
	var target_roll_deg = -clamp(x_velocity * 0.9, -15.0, 15.0)
	var target_yaw_deg = -clamp(x_velocity * 0.45, -8.0, 8.0)
	rotation_degrees.z = lerp(rotation_degrees.z, target_roll_deg, yaw_lerp_speed * delta)
	rotation_degrees.y = lerp(rotation_degrees.y, target_yaw_deg, yaw_lerp_speed * delta)
	
	# 5. Floating / Bobbing on water
	float_time += delta * bob_frequency
	var hover_height = lerp(min_hover_height, max_hover_height, (sin(float_time) + 1.0) * 0.5)
	if visuals:
		visuals.position.y = hover_height
		visuals.rotation_degrees.x = sin(float_time * 1.5) * 2.0
		visuals.rotation_degrees.y = 0.0
		visuals.rotation_degrees.z = 0.0
		
		var hardpoints = get_node_or_null("Hardpoints")
		if hardpoints:
			hardpoints.visible = true
			hardpoints.position.x = visuals.position.x
			hardpoints.position.z = visuals.position.z
			hardpoints.position.y = visuals.position.y
			hardpoints.rotation_degrees.x = visuals.rotation_degrees.x
			hardpoints.rotation_degrees.y = 0.0
			hardpoints.rotation_degrees.z = 0.0
		
	# 6. Automatic periodic cannon shooting
	if is_shooting_enabled:
		for weapon in equipped_weapons.values():
			if is_instance_valid(weapon) and weapon.has_method("try_fire"):
				weapon.try_fire(delta * fire_rate_multiplier)
			
	move_and_slide()


func _on_magnet_area_entered(area: Area3D) -> void:
	if area and area.is_in_group("doubloons") and area.has_method("attract_to"):
		area.attract_to(self)

func upgrade_ship(amount: int = 1) -> void:
	score += amount
	score_changed.emit(score)

func add_doubloons(amount: int) -> void:
	doubloons += amount
	doubloons_changed.emit(doubloons)

func add_evolution_xp(_amount: float) -> void:
	# Deprecated legacy in-run evolution: ship tiers are managed via Shipyard meta-progression.
	pass

func spawn_floating_text_at_position(text_val: String, color_val: Color) -> void:
	var ft_script = load("res://src/gameplay/vfx/floating_text.gd")
	if ft_script:
		var fct = ft_script.new()
		var root = get_tree().current_scene
		if root:
			root.add_child(fct)
			fct.global_position = global_position + Vector3(randf_range(-0.5, 0.5), 1.5, randf_range(-0.5, 0.5))
			fct.setup(text_val, color_val)



func take_hit(amount: int = 1, source_info: String = "") -> void:
	# I-frame guard: prevent stacked damage from overlapping contacts in the same frame
	# (barricade handles its own i-frame; leak_threat is throttled by follower loss)
	if source_info != "leak_threat" and source_info != "Collision with Barricade":
		if hit_invulnerability_timer > 0.0:
			return
		hit_invulnerability_timer = 0.8
	
	if source_info != "leak_threat":
		GameState.record_hit()
	current_health = max(0, current_health - amount)
	var camera = get_tree().get_first_node_in_group("game_camera")
	if camera and camera.has_method("add_trauma"):
		camera.add_trauma(0.55)
	print("[PLAYER HIT] Vessel took %d dmg from '%s' | HP: %d/%d | Fleet: %d" % [amount, source_info, current_health, max_health, follower_boats.size() + 1])
	if current_health <= 0:
		print("[FATAL DAMAGE] Killed by: %s | Damage: %d | Remaining HP: %d" % [source_info, amount, current_health])
	health_changed.emit(current_health, max_health)
	if current_health <= 0:
		game_over(false)

func _on_area_entered(area: Area3D) -> void:
	if is_game_over or not GameState.is_game_active:
		return
		
	# Ignore collectibles, cannonballs, and gates
	if area.is_in_group("collectibles") or area.is_in_group("cannonballs") or area.is_in_group("multiplier_gate") or area.is_in_group("player") or area.is_in_group("follower"):
		return
		
	if area.is_in_group("destructible") or area.is_in_group("enemies") or area.is_in_group("boss"):
		var is_barricade = area is BarricadeSegment or area.is_in_group("barricade") or (area.get_parent() and area.get_parent().is_in_group("barricade"))
		
		if is_barricade:
			if hit_invulnerability_timer > 0.0:
				# Collision damage already applied this burst; damage barricade segment without re-damaging hull
				if area.has_method("take_damage"):
					area.take_damage(5)
				return
			
			hit_invulnerability_timer = 0.5
			AudioManager.play_sfx("sfx_wood_smash")
			take_hit(3, "Collision with Barricade")
			if area.has_method("take_damage"):
				area.take_damage(5)
			elif area.has_method("die"):
				area.die()
			return

		var is_sea_mine = area is HazardSeaMine or (area is DestructibleObstacle and area.obstacle_type == DestructibleObstacle.ObstacleType.SEA_MINE)
		if is_sea_mine:
			# Let mine.die() handle its own explosion VFX at the mine's position.
			# take_hit() will check i-frames internally.
			if area.has_method("die"):
				area.die()
			else:
				var mine_pos = area.global_position
				if VFXManager:
					VFXManager.spawn_mine_explosion(mine_pos)
				area.queue_free()
			take_hit(1, "Collision with Sea Mine")
			return

		AudioManager.play_sfx("barrel_hits")
		take_hit(1, "Collision with %s (%s)" % [area.name, str(area.get_groups())])
			
		if area.is_in_group("boss") or (area.get_parent() and area.get_parent().is_in_group("boss")):
			if area.has_method("take_damage"):
				area.take_damage(5)
		elif area.has_method("die"):
			area.die()
		elif area.has_method("take_damage"):
			area.take_damage(5)
		else:
			area.queue_free()


func game_over(victory: bool) -> void:
	if is_game_over:
		return
	is_game_over = true
	is_shooting_enabled = false
	
	if not victory:
		var coins = GameState.run_doubloons
		var dist = GameState.distance_traveled
		GameState.bank_run_doubloons(0)
		run_failed.emit(coins, dist)
		if GameState.has_signal("run_failed"):
			GameState.run_failed.emit(coins, dist)
			
		var level_ctrl = get_tree().get_first_node_in_group("level_controller")
		if level_ctrl and level_ctrl.has_method("handle_player_defeat"):
			level_ctrl.handle_player_defeat(coins, dist)
			return

		get_tree().paused = true
		var settlement_scene = preload("res://src/ui/settlement_screen.tscn")
		if settlement_scene:
			var ui = settlement_scene.instantiate()
			get_parent().add_child(ui)
			if ui.has_method("show_defeat"):
				ui.show_defeat(coins, dist, GameState.doubloons)
				return
				
	get_tree().paused = true
	if end_game_ui_scene:
		var ui = end_game_ui_scene.instantiate()
		get_parent().add_child(ui)
		if ui.has_method("set_result"):
			ui.set_result(victory, score)

func _process_calibration_controls(delta: float) -> void:
	if is_shooting_enabled:
		for weapon in equipped_weapons.values():
			if is_instance_valid(weapon) and weapon.has_method("try_fire"):
				weapon.try_fire(delta)

func _setup_calibration_mode() -> void:
	position = Vector3.ZERO
	target_x = 0.0

func clear_all_weapons() -> void:
	clear_weapons()

func equip_weapon_to_socket(socket_name: String, weapon_data: WeaponData) -> void:
	if ship_data and not ship_data.hardpoint_offsets.has(socket_name):
		return # strictly forbid sockets not defined in ship_data
		
	var hardpoints = get_node_or_null("Hardpoints")
	if not hardpoints:
		return
	var socket = hardpoints.get_node_or_null(socket_name)
	if not socket:
		socket = Node3D.new()
		socket.name = socket_name
		hardpoints.add_child(socket)
		if ship_data and ship_data.hardpoint_offsets.has(socket_name):
			socket.position = ship_data.hardpoint_offsets[socket_name]
		if ship_data and ship_data.hardpoint_rotations.has(socket_name):
			var rot = ship_data.hardpoint_rotations[socket_name]
			if rot is Vector3:
				socket.rotation_degrees = rot
		if ship_data and ship_data.hardpoint_scales.has(socket_name):
			var sc = ship_data.hardpoint_scales[socket_name]
			if sc is Vector3:
				socket.scale = sc
		
	if equipped_weapons.has(socket_name):
		var old_weapon = equipped_weapons[socket_name]
		if is_instance_valid(old_weapon):
			if old_weapon.weapon_data == weapon_data:
				return # Weapon already active and firing seamlessly
			old_weapon.queue_free()
		equipped_weapons.erase(socket_name)
		
	var attached_weapon_scene = load("res://src/gameplay/player/attached_weapon.tscn")
	var weapon_instance = attached_weapon_scene.instantiate() as AttachedWeapon
	if weapon_instance.has_method("setup_weapon"):
		weapon_instance.setup_weapon(weapon_data)
	else:
		weapon_instance.weapon_data = weapon_data
	socket.add_child(weapon_instance)
	equipped_weapons[socket_name] = weapon_instance
	
	var sprite = weapon_instance.get_node_or_null("Sprite3D") as Sprite3D
	if sprite:
		sprite.scale = Vector3.ZERO
		var tween = create_tween()
		tween.tween_property(sprite, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

func clear_weapons() -> void:
	for weapon in equipped_weapons.values():
		if is_instance_valid(weapon):
			weapon.queue_free()
	equipped_weapons.clear()
	
	var hardpoints = get_node_or_null("Hardpoints")
	if hardpoints:
		for socket in hardpoints.get_children():
			for child in socket.get_children():
				child.queue_free()

func upgrade_crew() -> void:
	if ship_data and ship_data.hardpoint_offsets.has("MidDeckCrew") and (not equipped_weapons.has("MidDeckCrew") or not is_instance_valid(equipped_weapons["MidDeckCrew"])):
		var monkey_res = load("res://src/data/resources/user_crew/crew_monkey_bomber.tres")
		equip_weapon_to_socket("MidDeckCrew", monkey_res)
		spawn_floating_text_at_position("MONKEY BOMBER JOINED!", Color(0.2, 1.0, 0.4))
	elif ship_data and ship_data.hardpoint_offsets.has("AftDeckCrew") and (not equipped_weapons.has("AftDeckCrew") or not is_instance_valid(equipped_weapons["AftDeckCrew"])):
		var skeleton_res = load("res://src/data/resources/user_crew/crew_skeleton_tosser.tres")
		equip_weapon_to_socket("AftDeckCrew", skeleton_res)
		spawn_floating_text_at_position("SKELETON JOINED!", Color(0.2, 1.0, 0.4))
	else:
		fire_rate_multiplier += 0.25
		spawn_floating_text_at_position("CREW FIRE RATE +25%!", Color(0.2, 1.0, 0.4))

func add_follower_boat() -> void:
	if follower_boats.size() >= 4:
		return # strictly cap fleet size at 5 ships (1 player + 4 followers)
	if not follower_scene:
		return
	var follower = follower_scene.instantiate() as Node3D
	var parent = get_parent()
	if parent:
		parent.add_child(follower)
		follower.global_position = global_position
		follower.global_transform.basis = global_transform.basis
		follower_boats.append(follower)
		_update_follower_positions()

func add_follower_boats(amount: int) -> void:
	var can_add = 4 - follower_boats.size()
	var to_add = min(amount, can_add)
	for i in range(to_add):
		add_follower_boat()

func multiply_follower_boats(multiplier: float) -> void:
	var current_total = follower_boats.size() + 1
	var new_total = int(round(current_total * multiplier))
	new_total = min(new_total, 5)
	var extra_needed = new_total - current_total
	if extra_needed > 0:
		add_follower_boats(extra_needed)

func remove_follower(follower: Node3D) -> void:
	if follower in follower_boats:
		follower_boats.erase(follower)
		_update_follower_positions()

func leak_threat(_threat_node: Node3D) -> void:
	if is_game_over or not GameState.is_game_active:
		return
		
	# 1. Trigger a 0.2s red screen-edge flash (Vignette alert)
	var hud = get_tree().get_first_node_in_group("top_hud")
	if hud and hud.has_method("trigger_red_flash"):
		hud.trigger_red_flash()
		
	# 2. Apply camera punch shake (intensity = 0.25)
	var camera = get_tree().get_first_node_in_group("game_camera")
	if camera and camera.has_method("shake"):
		camera.shake(0.2, 0.25)
		
	# 3. Play loud wood crunch SFX
	AudioManager.play_sfx("barrel_hits")
	
	# 4. Explode the outermost follower boat or damage player
	if not follower_boats.is_empty():
		var follower = follower_boats.back() # Outermost follower boat
		if is_instance_valid(follower):
			var spawn_pos = follower.global_position
			
			# Spawn water splashes
			var splash_scene = preload("res://src/gameplay/vfx/hit_splash.tscn")
			if splash_scene:
				var splash = splash_scene.instantiate() as Node3D
				get_parent().add_child(splash)
				splash.global_position = spawn_pos
				
			# Spawn bold floating label "-1 FLEET" at its position
			var ft_script = load("res://src/gameplay/vfx/floating_text.gd")
			if ft_script:
				var fct = ft_script.new()
				var root = get_tree().current_scene
				if root:
					root.add_child(fct)
					fct.global_position = spawn_pos + Vector3(0.0, 1.5, 0.0)
					fct.setup("-1 FLEET", Color(1.0, 0.1, 0.1))
			
			follower.destroy_follower()
	else:
		# If no followers exist, inflict 1 point of Hull damage to the player.
		# Spawn the floating label first so it's visible even if game_over fires.
		spawn_floating_text_at_position("-HULL", Color(1.0, 0.1, 0.1))
		take_hit(1, "leak_threat")

func damage_fleet(_amount: int = 1) -> void:
	GameState.record_hit()
	leak_threat(null)

func add_follower_ships(amount: int) -> void:
	var can_add = 4 - follower_boats.size()
	var to_add = min(amount, can_add)
	if to_add > 0:
		add_follower_boats(to_add)
		if has_method("spawn_floating_text_at_position"):
			spawn_floating_text_at_position("+%d Ships!" % to_add, Color(0.1, 0.9, 1.0))

func get_fleet_offsets(size: int) -> Array[Vector3]:
	match size:
		1:
			return [Vector3(0.0, 0.0, 0.0)]
		2:
			return [Vector3(-0.55, 0.0, 0.2), Vector3(0.55, 0.0, 0.2)]
		3:
			return [Vector3(0.0, 0.0, -0.35), Vector3(-0.65, 0.0, 0.35), Vector3(0.65, 0.0, 0.35)]
		4:
			return [Vector3(0.0, 0.0, -0.45), Vector3(-0.75, 0.0, 0.0), Vector3(0.75, 0.0, 0.0), Vector3(0.0, 0.0, 0.45)]
		5:
			return [Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.0, -0.55), Vector3(-0.75, 0.0, 0.0), Vector3(0.75, 0.0, 0.0), Vector3(0.0, 0.0, 0.55)]
		_:
			return [Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.0, -0.55), Vector3(-0.75, 0.0, 0.0), Vector3(0.75, 0.0, 0.0), Vector3(0.0, 0.0, 0.55)]

func get_fleet_scale_factor(size: int) -> float:
	match size:
		1: return 1.0
		2: return 0.80
		3: return 0.68
		4: return 0.58
		5: return 0.50
		_: return 0.50

func _update_follower_positions() -> void:
	var size = follower_boats.size() + 1
	var offsets = get_fleet_offsets(size)
	var target_sf = get_fleet_scale_factor(size)
	
	var tween = create_tween().set_parallel(true)
	
	if visuals:
		tween.tween_property(visuals, "position:x", offsets[0].x, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(visuals, "position:z", offsets[0].z, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		
		var sprite = visuals.get_node_or_null("BoatSprite") as Sprite3D
		if sprite:
			tween.tween_property(sprite, "scale", Vector3.ONE * target_sf, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			
	var hardpoints = get_node_or_null("Hardpoints")
	if hardpoints:
		tween.tween_property(hardpoints, "position:x", offsets[0].x, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(hardpoints, "position:z", offsets[0].z, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(hardpoints, "scale", Vector3.ONE * target_sf, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		
	var body_col = get_node_or_null("CollisionShape3D") as CollisionShape3D
	if body_col:
		tween.tween_property(body_col, "scale", Vector3.ONE * target_sf, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		
	var area_col = get_node_or_null("CollisionArea/CollisionShape3D") as CollisionShape3D
	if area_col:
		tween.tween_property(area_col, "scale", Vector3.ONE * target_sf, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			
	for i in range(follower_boats.size()):
		var follower = follower_boats[i]
		if is_instance_valid(follower):
			var f_offset = offsets[i + 1]
			if follower.has_method("set_target_offset"):
				follower.set_target_offset(f_offset)
			if follower.has_method("tween_scale"):
				follower.tween_scale(target_sf, 0.4)

func _clean_shadow_nodes(node: Node) -> void:
	if not node:
		return
	var lower_name = node.name.to_lower()
	var is_shadow_node = false
	if "shadow" in lower_name or "decal" in lower_name or "projector" in lower_name or "card" in lower_name or "oblate" in lower_name or "shadow_sphere" in lower_name or "sphere_shadow" in lower_name:
		is_shadow_node = true
		
	if is_shadow_node:
		if node is Sprite3D or node is MeshInstance3D or node is Decal or node.get_class() == "Decal3D":
			node.queue_free()
			return
			
	if node is MeshInstance3D:
		if "shadow" in lower_name or "plane" in lower_name or "billboard" in lower_name or "card" in lower_name:
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			node.visible = false
			node.queue_free()
			return
			
	for child in node.get_children():
		_clean_shadow_nodes(child)
