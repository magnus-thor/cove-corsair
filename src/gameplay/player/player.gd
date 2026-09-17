class_name PlayerSwerve
extends CharacterBody3D

signal health_changed(current: int, max_hp: int)
signal score_changed(new_score: int)
signal doubloons_changed(new_doubloons: int)
signal run_failed(coins_collected: int, distance_reached: float)

## Standardised signal aliases (Rule 1 — past-tense, typed payloads).
## These coexist with the legacy signals above so existing UI connections keep working.
signal player_health_changed(current: int, max_val: int)
signal player_sunk()

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
	"PortSwivelMount": "res://src/data/resources/user_crew/weapon_port_swivel.tres",
	"StarboardSwivelMount": "res://src/data/resources/user_crew/weapon_port_swivel.tres",
	"PortSwivelMount1": "res://src/data/resources/user_crew/weapon_port_swivel.tres",
	"PortSwivelMount2": "res://src/data/resources/user_crew/weapon_port_swivel.tres",
	"StarboardSwivelMount1": "res://src/data/resources/user_crew/weapon_port_swivel.tres",
	"StarboardSwivelMount2": "res://src/data/resources/user_crew/weapon_port_swivel.tres",
	"PortRailMount": "res://src/data/resources/user_crew/weapon_scattershot.tres",
	"StarboardRailMount": "res://src/data/resources/user_crew/weapon_scattershot.tres"
}

## Width of the river channel boundaries.
@export var river_width: float = 12.0

## The active ship tier
@export var current_tier: int = 1

## Cooldown duration between automatic shots in seconds
@export var shoot_cooldown: float = 0.45

## Multiplier applied to shooting speed
@export var fire_rate_multiplier: float = 1.0

## Multiplier applied based on vessel tier level (+15% per tier above 1)
@export var tier_fire_rate_multiplier: float = 1.0

## Damage bonus applied to all projectiles
@export var base_damage_bonus: int = 0

## The cannonball prefab scene to spawn
@export var cannonball_scene: PackedScene = preload("res://src/gameplay/projectiles/cannonball.tscn")

@onready var visuals: Node3D = $BoatVisuals

# ── Module references (added as children in _ready) ────────────────────────
var _movement: PlayerMovement = null
var _fleet: FleetFormationController = null

var max_health: int = 3
var current_health: int = 3

@export var target_score: int = 50

var equipped_weapons: Dictionary = {}
@export var follower_scene: PackedScene = preload("res://src/gameplay/player/follower_boat.tscn")
var follower_boats: Array[Node3D]:
	get:
		return _fleet.get_followers() if _fleet else []
var active_reef_overlaps: int = 0
var scraping_timer: float = 0.0
var speed_multiplier: float = 1.0
var active_weapons: Array[Node] = []
var shoot_timer: float = 0.0
var score: int = 0
var doubloons: int = 0
var is_game_over: bool = false
var hit_invulnerability_timer: float = 0.0
var ram_absorb_charges_remaining: int = 1
var fire_frenzy_timer: float = 0.0

# Game Feel & Juice Dynamics (Phase 1) — particles owned here; recoil/shudder delegated to _movement
var _bow_spray_particles: CPUParticles3D = null
var _hull_smoke_particles: CPUParticles3D = null

@export var is_shooting_enabled: bool = false
@export var end_game_ui_scene: PackedScene = preload("res://src/ui/end_game_ui.tscn")

@export_group("Player Ship Orientation")
@export var player_pitch_deg: float = -60.0

@export_group("Calibration Mode")
@export var is_calibration_mode: bool = false

func _ready() -> void:
	_clean_shadow_nodes(self)
	add_to_group("player")

	# Instantiate PlayerMovement module
	_movement = PlayerMovement.new()
	_movement.name = "PlayerMovement"
	add_child(_movement)
	_movement.setup(self, visuals)

	# Instantiate FleetFormationController module
	_fleet = FleetFormationController.new()
	_fleet.name = "FleetFormationController"
	_fleet.follower_scene = follower_scene
	add_child(_fleet)
	_fleet.setup(self)

	if visuals:
		visuals.rotation_degrees.y = 0.0
	var init_hp = get_node_or_null("Hardpoints")
	if init_hp:
		init_hp.rotation_degrees.y = 0.0

	_setup_hydrodynamic_particles()
	_setup_hull_smoke()
	
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
		if not GameState.fire_frenzy_triggered.is_connected(_on_fire_frenzy_triggered):
			GameState.fire_frenzy_triggered.connect(_on_fire_frenzy_triggered)
	
	ram_absorb_charges_remaining = 1
	
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
	if _movement:
		_movement.sync_from_ship_data(data.move_speed, data.move_speed * 1.3)
	
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
	player_health_changed.emit(current_health, max_health)

func apply_tier(tier_level: int) -> void:
	if not ship_data or ship_data.tier_sockets.is_empty():
		return
	current_tier = tier_level
	
	# Hull Tier Decoupling: scale Base Hull HP, Max Speed, and Firepower with Tier
	max_health = ship_data.max_health + (tier_level - 1)
	current_health = max_health
	var tier_speed: float = ship_data.move_speed + (tier_level - 1) * 1.5
	tier_fire_rate_multiplier = 1.0 + (tier_level - 1) * 0.15
	if _movement:
		_movement.sync_from_ship_data(tier_speed, tier_speed * 1.3)
	health_changed.emit(current_health, max_health)
	player_health_changed.emit(current_health, max_health)

	var active_sockets: Array = ship_data.tier_sockets[clampi(tier_level - 1, 0, ship_data.tier_sockets.size() - 1)]

	var weapons_map: Dictionary = DEFAULT_SOCKET_WEAPONS.duplicate()
	if "socket_weapons" in ship_data and not ship_data.socket_weapons.is_empty():
		weapons_map.merge(ship_data.socket_weapons, true)

	# Filter weapons_map directly against active_sockets, decoupling crew throwers
	var filtered_map: Dictionary = {}
	for s in active_sockets:
		var s_lower = str(s).to_lower()
		if "crew" in s_lower:
			# Crew sockets start empty unless equipped by the player in GameState
			var equipped_cid = GameState.get_equipped_crew(ship_data.ship_id, str(s)) if GameState else ""
			if equipped_cid != "" and GameState and GameState.CREW_CATALOG.has(equipped_cid):
				filtered_map[s] = GameState.CREW_CATALOG[equipped_cid]["resource_path"]
		elif weapons_map.has(s):
			filtered_map[s] = weapons_map[s]
	weapons_map = filtered_map

	# Safe Ship Swap Guard: Remove any currently equipped weapons whose sockets are no longer in this tier
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
			var s_lower = str(socket_name).to_lower()
			var c_id = ""
			var c_lvl = 1
			if "crew" in s_lower and GameState:
				c_id = GameState.get_equipped_crew(ship_data.ship_id, str(socket_name))
				c_lvl = GameState.get_crew_level(c_id)
			equip_weapon_to_socket(socket_name, w_data, c_id, c_lvl)

func _unhandled_input(event: InputEvent) -> void:
	if is_game_over:
		return
	if _movement:
		_movement.process_input(event)

func _physics_process(delta: float) -> void:
	if hit_invulnerability_timer > 0.0:
		hit_invulnerability_timer = maxf(0.0, hit_invulnerability_timer - delta)

	if fire_frenzy_timer > 0.0:
		fire_frenzy_timer = maxf(0.0, fire_frenzy_timer - delta)
		if fire_frenzy_timer <= 0.0:
			fire_rate_multiplier = 1.0

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
			var spray_scene = preload("res://src/vfx/boat_wake.tscn")
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
		# Idle bobbing in harbor — delegated to PlayerMovement
		if _movement:
			var idle_h: float = _movement.tick_idle(delta)
			if visuals:
				visuals.position.y = idle_h
				visuals.rotation_degrees.x = sin(_movement.float_time * 1.5) * 2.0
				visuals.rotation_degrees.y = sin(_movement.float_time * 0.7) * 2.0
				visuals.rotation_degrees.z = sin(_movement.float_time * 1.1) * 1.5

				var hardpoints: Node3D = get_node_or_null("Hardpoints")
				if hardpoints:
					hardpoints.visible = false
					hardpoints.position.y = visuals.position.y
					hardpoints.rotation_degrees.x = visuals.rotation_degrees.x
					hardpoints.rotation_degrees.y = visuals.rotation_degrees.y
					hardpoints.rotation_degrees.z = visuals.rotation_degrees.z
		return

	# Delegate movement + banking + bobbing + recoil + shudder to PlayerMovement
	var hover_height: float = _movement.min_hover_height if _movement else 0.04
	if _movement:
		hover_height = _movement.tick(delta, speed_multiplier)

	if visuals:
		visuals.position.y = hover_height
		if _movement:
			visuals.rotation_degrees.x = (sin(_movement.float_time * 1.5) * 2.0) + _movement.get_recoil_pitch()
			visuals.rotation_degrees.y = 0.0
			visuals.rotation_degrees.z = _movement.get_shudder_roll()

		var hardpoints: Node3D = get_node_or_null("Hardpoints")
		if hardpoints:
			hardpoints.visible = true
			hardpoints.position.x = visuals.position.x
			hardpoints.position.z = visuals.position.z
			hardpoints.position.y = visuals.position.y
			hardpoints.rotation_degrees.x = visuals.rotation_degrees.x
			hardpoints.rotation_degrees.y = 0.0
			hardpoints.rotation_degrees.z = visuals.rotation_degrees.z

	# Dynamic Hydrodynamic Bow Spray scaling with horizontal swerve velocity
	if _bow_spray_particles and _movement:
		var swerve_ratio: float = clampf(abs(_movement.x_velocity) / 3.5, 0.0, 1.0)
		if swerve_ratio > 0.15:
			_bow_spray_particles.emitting = true
			_bow_spray_particles.initial_velocity_min = 1.4 * swerve_ratio
			_bow_spray_particles.initial_velocity_max = 3.2 * swerve_ratio
		else:
			_bow_spray_particles.emitting = false

	# Automatic periodic cannon shooting
	if is_shooting_enabled:
		for weapon in equipped_weapons.values():
			if is_instance_valid(weapon) and weapon.has_method("try_fire"):
				weapon.try_fire(delta * fire_rate_multiplier * tier_fire_rate_multiplier)

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
	var ft_script = load("res://src/vfx/floating_text.gd")
	if ft_script:
		var fct = ft_script.new()
		var root = get_tree().current_scene
		if root:
			root.add_child(fct)
			fct.global_position = global_position + Vector3(randf_range(-0.5, 0.5), 1.5, randf_range(-0.5, 0.5))
			fct.setup(text_val, color_val)



func _on_fire_frenzy_triggered(duration: float) -> void:
	fire_frenzy_timer = duration # Refresh timer without compounding
	fire_rate_multiplier = 1.25 # +25% faster firing rate
	spawn_floating_text_at_position("🔥 FIRE FRENZY! +25% SPEED", Color(1.0, 0.8, 0.2))
	AudioManager.play_sfx("gate_passes", 1.2, 1.4)

func damage_fleet(amount: int = 1, source_info: String = "poison_mortar_geyser") -> void:
	GameState.record_hit()
	if _fleet and _fleet.get_follower_count() > 0:
		leak_threat(null)
	else:
		take_hit(amount, source_info)

func take_hit(amount: int = 1, source_info: String = "") -> void:
	# Plating damage mitigation
	var active_plating = GameState.get_active_plating() if GameState else "none"
	var s_lower = source_info.to_lower()
	if active_plating == "spectral_ward" and ("spectral" in s_lower or "geyser" in s_lower or "mortar" in s_lower or "poison" in s_lower or "ghost" in s_lower):
		amount = max(1, int(round(amount * 0.4))) # -60% geyser/spectral damage
	elif active_plating == "brimstone_fireproof" and ("brimstone" in s_lower or "fire" in s_lower or "magma" in s_lower or "lava" in s_lower or "flame" in s_lower):
		amount = max(1, int(round(amount * 0.5))) # -50% fire hazard damage

	# I-frame guard: prevent stacked damage from overlapping contacts in the same frame
	if hit_invulnerability_timer > 0.0:
		return
	hit_invulnerability_timer = 0.8
	
	if source_info != "leak_threat":
		GameState.record_hit()
	current_health = max(0, current_health - amount)
	var camera = get_tree().get_first_node_in_group("game_camera")
	if camera and camera.has_method("add_trauma"):
		camera.add_trauma(0.55)

	# Sensory Polish: 3D Hit Flash & Kinetic Hull Shudder
	if _movement:
		_movement.apply_shudder()
	if visuals:
		HitFlashComponent.flash_node(visuals, 0.065)
	_update_hull_distress_smoke()
	
	if current_health <= 1 and current_health > 0:
		if AudioManager and AudioManager.has_method("set_low_hp_tension"):
			AudioManager.set_low_hp_tension(true)
	elif current_health <= 0:
		if AudioManager and AudioManager.has_method("set_low_hp_tension"):
			AudioManager.set_low_hp_tension(false)

	print("[PLAYER HIT] Vessel took %d dmg from '%s' | HP: %d/%d | Fleet: %d" % [amount, source_info, current_health, max_health, (_fleet.get_follower_count() if _fleet else 0) + 1])
	if current_health <= 0:
		print("[FATAL DAMAGE] Killed by: %s | Damage: %d | Remaining HP: %d" % [source_info, amount, current_health])
	health_changed.emit(current_health, max_health)
	player_health_changed.emit(current_health, max_health)
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
			if GameState and GameState.get_active_plating() == "spiked_iron_prow" and ram_absorb_charges_remaining > 0:
				ram_absorb_charges_remaining -= 1
				hit_invulnerability_timer = 0.5
				spawn_floating_text_at_position("🛡️ PROW RAM ABSORBED!", Color(0.3, 0.9, 1.0))
				AudioManager.play_sfx("sfx_wood_smash", 0.9, 1.1)
				if area.has_method("take_hit"):
					area.take_hit(20, "spiked_prow_ram")
				elif area.has_method("take_damage"):
					area.take_damage(20)
				elif area.has_method("die"):
					area.die()
				return

			if hit_invulnerability_timer > 0.0:
				# Collision damage already applied this burst; break barricade segment without re-damaging hull
				if area.has_method("die"):
					area.die()
				elif area.has_method("take_hit"):
					area.take_hit(20, "barricade_graze")
				elif area.has_method("take_damage"):
					area.take_damage(20)
				return
			
			hit_invulnerability_timer = 0.5
			AudioManager.play_sfx("sfx_wood_smash")
			var cur_lvl: int = GameState.current_level if GameState else 1
			var barricade_dmg = 1 if cur_lvl <= 3 else 2
			take_hit(barricade_dmg, "Collision with Barricade")
			if area.has_method("die"):
				area.die()
			elif area.has_method("take_hit"):
				area.take_hit(20, "player_vessel_ram")
			elif area.has_method("take_damage"):
				area.take_damage(20)
			return

		var is_sea_mine = area is HazardSeaMine or (area is DestructibleObstacle and area.obstacle_type == DestructibleObstacle.ObstacleType.SEA_MINE) or ("mine" in area.name.to_lower()) or area.is_in_group("sea_mine")
		if is_sea_mine:
			if GameState and GameState.get_active_plating() == "spiked_iron_prow" and ram_absorb_charges_remaining > 0:
				ram_absorb_charges_remaining -= 1
				hit_invulnerability_timer = 0.6 # Nullifies both contact and explosion splash for that single impact
				spawn_floating_text_at_position("🛡️ PROW RAM ABSORBED!", Color(0.3, 0.9, 1.0))
				AudioManager.play_sfx("sfx_mine_detonate", 0.8, 1.0)
				if area.has_method("die"):
					area.die()
				else:
					area.queue_free()
				return

			# Let mine.die() handle its own explosion VFX at the mine's position.
			# take_hit() will check i-frames internally.
			if area.has_method("die"):
				area.die()
			else:
				area.queue_free()
			take_hit(1, "Collision with Sea Mine")
			return

		if GameState and GameState.get_active_plating() == "spiked_iron_prow" and ram_absorb_charges_remaining > 0 and not area.is_in_group("boss"):
			ram_absorb_charges_remaining -= 1
			hit_invulnerability_timer = 0.5
			spawn_floating_text_at_position("🛡️ PROW RAM ABSORBED!", Color(0.3, 0.9, 1.0))
			AudioManager.play_sfx("barrel_breaks", 0.9, 1.1)
			if area.has_method("take_hit"):
				area.take_hit(10, "spiked_prow_ram")
			elif area.has_method("take_damage"):
				area.take_damage(10)
			elif area.has_method("die"):
				area.die()
			else:
				area.queue_free()
			return

		AudioManager.play_sfx("barrel_hits")
		take_hit(1, "Collision with %s (%s)" % [area.name, str(area.get_groups())])
			
		if area.is_in_group("boss") or (area.get_parent() and area.get_parent().is_in_group("boss")):
			if area.has_method("take_hit"):
				area.take_hit(5, "player_vessel_ram")
			elif area.has_method("take_damage"):
				area.take_damage(5)
		elif area.has_method("die"):
			area.die()
		elif area.has_method("take_hit"):
			area.take_hit(5, "player_vessel_ram")
		elif area.has_method("take_damage"):
			area.take_damage(5)
		else:
			area.queue_free()


func game_over(victory: bool) -> void:
	if is_game_over:
		return
	is_game_over = true
	is_shooting_enabled = false
	if AudioManager and AudioManager.has_method("set_low_hp_tension"):
		AudioManager.set_low_hp_tension(false)
	if _hull_smoke_particles:
		_hull_smoke_particles.emitting = false
	if _bow_spray_particles:
		_bow_spray_particles.emitting = false
	
	if not victory:
		player_sunk.emit()
		var coins = GameState.run_doubloons
		var dist = GameState.distance_traveled
		GameState.bank_run_doubloons(0)
		run_failed.emit(coins, dist)
		EventBus.run_failed.emit(coins, dist)
		EventBus.player_sunk.emit()
			
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
	if _movement:
		_movement.target_x = 0.0

func clear_all_weapons() -> void:
	clear_weapons()

func equip_weapon_to_socket(socket_name: String, weapon_data: WeaponData, crew_id: String = "", crew_level: int = 1) -> void:
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
			if old_weapon.weapon_data == weapon_data and ("crew_level" in old_weapon and old_weapon.crew_level == crew_level):
				return # Weapon already active and firing seamlessly
			old_weapon.queue_free()
		equipped_weapons.erase(socket_name)
		
	var attached_weapon_scene = load("res://src/gameplay/player/attached_weapon.tscn")
	var weapon_instance = attached_weapon_scene.instantiate() as AttachedWeapon
	if "crew_id" in weapon_instance:
		weapon_instance.crew_id = crew_id
	if "crew_level" in weapon_instance:
		weapon_instance.crew_level = crew_level
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
	if _fleet:
		_fleet.add_follower()

func add_follower_boats(amount: int) -> void:
	if _fleet:
		_fleet.add_followers(amount)

func multiply_follower_boats(multiplier: float) -> void:
	if _fleet:
		_fleet.multiply_followers(multiplier)

func remove_follower(follower: Node3D) -> void:
	if _fleet:
		_fleet.remove_follower(follower)

func leak_threat(_threat_node: Node3D) -> void:
	if is_game_over or not GameState.is_game_active:
		return
	if hit_invulnerability_timer > 0.0:
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
	var last_follower: Node3D = _fleet.get_last_follower() if _fleet else null
	if last_follower and is_instance_valid(last_follower):
		var spawn_pos: Vector3 = last_follower.global_position
		
		# Spawn water splashes
		var splash_scene = preload("res://src/vfx/hit_splash.tscn")
		if splash_scene:
			var splash = splash_scene.instantiate() as Node3D
			get_parent().add_child(splash)
			splash.global_position = spawn_pos
			
		# Spawn bold floating label "-1 FLEET" at its position
		var ft_script = load("res://src/vfx/floating_text.gd")
		if ft_script:
			var fct = ft_script.new()
			var root = get_tree().current_scene
			if root:
				root.add_child(fct)
				fct.global_position = spawn_pos + Vector3(0.0, 1.5, 0.0)
				fct.setup("-1 FLEET", Color(1.0, 0.1, 0.1))
		
		last_follower.destroy_follower()
	else:
		# If no followers exist, inflict 1 point of Hull damage to the player.
		# Spawn the floating label first so it's visible even if game_over fires.
		spawn_floating_text_at_position("-HULL", Color(1.0, 0.1, 0.1))
		take_hit(1, "leak_threat")

func add_follower_ships(amount: int) -> void:
	var can_add: int = FleetFormationController.MAX_FOLLOWERS - (_fleet.get_follower_count() if _fleet else 0)
	var to_add: int = min(amount, can_add)
	if to_add > 0:
		if _fleet:
			_fleet.add_followers(to_add)
		spawn_floating_text_at_position("+%d Ships!" % to_add, Color(0.1, 0.9, 1.0))
	elif current_health < max_health:
		current_health = min(max_health, current_health + 1)
		health_changed.emit(current_health, max_health)
		player_health_changed.emit(current_health, max_health)
		_update_hull_distress_smoke()
		if current_health > 1 and AudioManager and AudioManager.has_method("set_low_hp_tension"):
			AudioManager.set_low_hp_tension(false)
		spawn_floating_text_at_position("+HULL REPAIR!", Color(0.2, 1.0, 0.4))

func trigger_armada_overdrive() -> void:
	# 1. Add at most 1 bonus escort if under cap
	if _fleet and _fleet.get_follower_count() < FleetFormationController.MAX_FOLLOWERS:
		_fleet.add_follower()
	# 2. Fully repair hull
	if current_health < max_health:
		current_health = max_health
		health_changed.emit(current_health, max_health)
		player_health_changed.emit(current_health, max_health)
		_update_hull_distress_smoke()
		if AudioManager and AudioManager.has_method("set_low_hp_tension"):
			AudioManager.set_low_hp_tension(false)
	# 3. Temporary Overdrive fire rate boost
	fire_rate_multiplier = 2.0
	var timer = get_tree().create_timer(6.0)
	timer.timeout.connect(func(): fire_rate_multiplier = 1.0)
	# 4. Audiovisual feedback
	AudioManager.play_sfx("coin_pickup", 1.3, 1.5)
	spawn_floating_text_at_position("★ ARMADA OVERDRIVE! ★", Color(1.0, 0.85, 0.1))

## Firing recoil kick applied to the player vessel hull
func apply_firing_recoil(impulse_degrees: float = 1.8, is_mortar: bool = false) -> void:
	if _movement:
		_movement.apply_recoil(impulse_degrees)
	if is_mortar:
		var camera: Node = get_tree().get_first_node_in_group("game_camera")
		if camera and camera.has_method("add_trauma"):
			camera.add_trauma(0.16)

func _setup_hydrodynamic_particles() -> void:
	if _bow_spray_particles == null:
		_bow_spray_particles = CPUParticles3D.new()
		_bow_spray_particles.name = "BowSprayVFX"
		_bow_spray_particles.amount = 14
		_bow_spray_particles.lifetime = 0.35
		_bow_spray_particles.explosiveness = 0.0
		_bow_spray_particles.randomness = 0.4
		_bow_spray_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		_bow_spray_particles.emission_box_extents = Vector3(0.6, 0.05, 0.2)
		_bow_spray_particles.direction = Vector3(0, 0.7, -0.7)
		_bow_spray_particles.spread = 45.0
		_bow_spray_particles.gravity = Vector3(0, -9.8, 0)
		_bow_spray_particles.initial_velocity_min = 1.5
		_bow_spray_particles.initial_velocity_max = 3.2
		var spray_mat = StandardMaterial3D.new()
		spray_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		spray_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		spray_mat.albedo_color = Color(0.92, 0.97, 1.0, 0.6)
		var qm = QuadMesh.new()
		qm.size = Vector2(0.2, 0.2)
		qm.material = spray_mat
		_bow_spray_particles.mesh = qm
		add_child(_bow_spray_particles)
		_bow_spray_particles.position = Vector3(0, 0.04, -1.25)
		_bow_spray_particles.emitting = false

func _setup_hull_smoke() -> void:
	if _hull_smoke_particles == null:
		_hull_smoke_particles = CPUParticles3D.new()
		_hull_smoke_particles.name = "HullDistressSmoke"
		_hull_smoke_particles.amount = 20
		_hull_smoke_particles.lifetime = 0.75
		_hull_smoke_particles.randomness = 0.3
		_hull_smoke_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		_hull_smoke_particles.emission_box_extents = Vector3(0.25, 0.1, 0.4)
		_hull_smoke_particles.direction = Vector3(0, 1.0, 0.4)
		_hull_smoke_particles.spread = 35.0
		_hull_smoke_particles.gravity = Vector3(0, 0.9, 0)
		_hull_smoke_particles.initial_velocity_min = 0.6
		_hull_smoke_particles.initial_velocity_max = 1.4
		var smoke_mat = StandardMaterial3D.new()
		smoke_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		smoke_mat.albedo_color = Color(0.25, 0.25, 0.25, 0.4)
		var qm = QuadMesh.new()
		qm.size = Vector2(0.32, 0.32)
		qm.material = smoke_mat
		_hull_smoke_particles.mesh = qm
		if visuals:
			visuals.add_child(_hull_smoke_particles)
		else:
			add_child(_hull_smoke_particles)
		_hull_smoke_particles.position = Vector3(0, 0.45, 0.35)
		_hull_smoke_particles.emitting = false

func _update_hull_distress_smoke() -> void:
	if not _hull_smoke_particles:
		_setup_hull_smoke()
	if not _hull_smoke_particles:
		return
	if is_game_over:
		_hull_smoke_particles.emitting = false
		return
	var hp_ratio = float(current_health) / float(max(1, max_health))
	if hp_ratio > 0.67:
		_hull_smoke_particles.emitting = false
	elif hp_ratio > 0.34:
		_hull_smoke_particles.emitting = true
		_hull_smoke_particles.amount = 8
		if _hull_smoke_particles.mesh and _hull_smoke_particles.mesh.material:
			(_hull_smoke_particles.mesh.material as StandardMaterial3D).albedo_color = Color(0.6, 0.6, 0.6, 0.35)
	else:
		_hull_smoke_particles.emitting = true
		_hull_smoke_particles.amount = 22
		if _hull_smoke_particles.mesh and _hull_smoke_particles.mesh.material:
			(_hull_smoke_particles.mesh.material as StandardMaterial3D).albedo_color = Color(0.12, 0.12, 0.12, 0.8)

func get_fleet_offsets(size: int) -> Array[Vector3]:
	return _fleet.get_fleet_offsets(size) if _fleet else []

func get_fleet_scale_factor(size: int) -> float:
	return _fleet.get_fleet_scale_factor(size) if _fleet else 1.0

func _update_follower_positions() -> void:
	if _fleet:
		_fleet.update_formation()

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
