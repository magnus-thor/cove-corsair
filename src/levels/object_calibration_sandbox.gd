extends Node3D

@onready var object_container: Node3D = $ObjectContainer

@onready var category_option: OptionButton = %category_option
@onready var object_option: OptionButton = %object_option

@onready var slider_pos_y: HSlider = %slider_pos_y
@onready var slider_psize: HSlider = %slider_psize
@onready var slider_scale: HSlider = %slider_scale
@onready var slider_rot_x: HSlider = %slider_rot_x
@onready var slider_rot_y: HSlider = %slider_rot_y

@onready var input_pos_y: LineEdit = %input_pos_y
@onready var input_psize: LineEdit = %input_psize
@onready var input_scale: LineEdit = %input_scale
@onready var input_rot_x: LineEdit = %input_rot_x
@onready var input_rot_y: LineEdit = %input_rot_y

@onready var btn_pos_y_dec: Button = %btn_pos_y_dec
@onready var btn_pos_y_inc: Button = %btn_pos_y_inc
@onready var btn_psize_dec: Button = %btn_psize_dec
@onready var btn_psize_inc: Button = %btn_psize_inc
@onready var btn_scale_dec: Button = %btn_scale_dec
@onready var btn_scale_inc: Button = %btn_scale_inc
@onready var btn_rot_x_dec: Button = %btn_rot_x_dec
@onready var btn_rot_x_inc: Button = %btn_rot_x_inc
@onready var btn_rot_y_dec: Button = %btn_rot_y_dec
@onready var btn_rot_y_inc: Button = %btn_rot_y_inc

@onready var btn_bobbing_toggle: Button = %btn_bobbing_toggle
@onready var btn_print_values: Button = %btn_print_values

@onready var camera_3d: Camera3D = $Camera3D
@onready var btn_cam_lane: Button = %btn_cam_lane
@onready var btn_cam_boss: Button = %btn_cam_boss
@onready var btn_cam_waterline: Button = %btn_cam_waterline
@onready var slider_zoom: HSlider = %slider_zoom
@onready var btn_zoom_in: Button = %btn_zoom_in
@onready var btn_zoom_out: Button = %btn_zoom_out
@onready var btn_zoom_reset: Button = %btn_zoom_reset

enum CamView { LANE, BOSS, WATERLINE }
var current_cam_view: CamView = CamView.LANE
var zoom_factor: float = 1.0

# Object Definitions
var categories: Array[String] = [
	"Enemies & Mobs",
	"Barrels, Hazards & Obstacles",
	"Gates & Collectibles",
	"Ammunition & Projectiles",
	"Vessels / Player Ships"
]

var enemy_items: Array[Dictionary] = [
	{"name": "Skeleton Rower", "res": "res://src/data/resources/enemy_vessels/skeleton_rower.tres"},
	{"name": "Raider Skiff", "res": "res://src/data/resources/enemy_vessels/raider_skiff.tres"},
	{"name": "Turtle Raft", "res": "res://src/data/resources/enemy_vessels/turtle_raft.tres"},
	{"name": "Elite Ironclad", "res": "res://src/data/resources/enemy_vessels/enemy_elite_ironclad.tres"},
	{"name": "Tide Cutter", "scene": "res://src/gameplay/enemies/enemy_tide_cutter.tscn"},
	{"name": "Iron Gunner", "scene": "res://src/gameplay/enemies/enemy_iron_gunner.tscn"},
	{"name": "Grave Skiff", "scene": "res://src/gameplay/enemies/enemy_grave_skiff.tscn"},
	{"name": "Brimstone Raft", "scene": "res://src/gameplay/enemies/enemy_brimstone_raft.tscn"},
	{"name": "Mini-Boss Harvester", "scene": "res://src/gameplay/enemies/enemy_mini_boss_harvester.tscn"},
	{"name": "Mini-Boss Bombard", "scene": "res://src/gameplay/enemies/enemy_mini_boss_bombard.tscn"},
	{"name": "Boss Bone-Beard", "scene": "res://src/gameplay/enemies/boss_bone_beard.tscn"},
	{"name": "Boss War-Barge", "scene": "res://src/gameplay/enemies/boss_war_barge.tscn"},
	{"name": "Boss Phantom Dredge", "scene": "res://src/gameplay/enemies/boss_phantom_dredge.tscn"},
	{"name": "Boss Siege Fortress", "scene": "res://src/gameplay/enemies/boss_siege_fortress.tscn"}
]

var obstacle_items: Array[Dictionary] = [
	{"name": "Wooden Barrel", "type": 0}, # ObstacleType.WOODEN_BARREL
	{"name": "Fuse Barrel", "type": 1},   # FUSE_BARREL
	{"name": "Rune Barrel", "type": 2},   # RUNE_BARREL
	{"name": "Biogas Hazard Pod", "scene": "res://src/gameplay/obstacles/hazard_biogas_pod.tscn"},
	{"name": "Thermal Geyser Hazard", "scene": "res://src/gameplay/obstacles/hazard_thermal_geyser.tscn"},
	{"name": "Hazard Sea Mine", "scene": "res://src/gameplay/obstacles/hazard_sea_mine.tscn"},
	{"name": "Hazard Coral Reef", "scene": "res://src/gameplay/obstacles/hazard_reef.tscn"},
	{"name": "Hazard Whirlpool", "scene": "res://src/gameplay/obstacles/hazard_whirlpool.tscn"},
	{"name": "Barricade Wall", "scene": "res://src/gameplay/obstacles/barricade_wall.tscn"},
	{"name": "Barricade Log Segment", "scene": "res://src/gameplay/obstacles/barricade_segment.tscn"},
	{"name": "Bombard Reticle Decal", "reticle": true}
]



var gate_items: Array[Dictionary] = [
	{"name": "Multiplier Gate Arch", "scene": "res://src/gameplay/obstacles/multiplier_gate.tscn"},
	{"name": "Reinforced Gate", "scene": "res://src/gameplay/obstacles/reinforced_gate.tscn"},
	{"name": "Collectible Doubloon", "scene": "res://src/gameplay/collectibles/collectible_doubloon.tscn"},
	{"name": "Treasure Chest", "scene": "res://src/gameplay/collectibles/collectible_chest.tscn"},
	{"name": "XP Orb", "class": "CollectibleXpOrb"}
]

var ammo_items: Array[Dictionary] = [
	{"name": "Standard Ball", "ammo_res": "res://src/data/resources/user_ammo/ammo_standard_ball.tres"},
	{"name": "Grape Shot", "ammo_res": "res://src/data/resources/user_ammo/ammo_grape_shot.tres"},
	{"name": "Scatter Pellet", "ammo_res": "res://src/data/resources/user_ammo/ammo_scatter_pellet.tres"},
	{"name": "Heavy Shot", "ammo_res": "res://src/data/resources/user_ammo/ammo_heavy_shot.tres"},
	{"name": "Fire Bomb", "ammo_res": "res://src/data/resources/user_ammo/ammo_fire_bomb.tres"},
	{"name": "Coconut Bomb", "ammo_res": "res://src/data/resources/user_ammo/ammo_coconut_bomb.tres"},
	{"name": "Throwing Axe", "ammo_res": "res://src/data/resources/user_ammo/ammo_throwing_axe.tres"},
	{"name": "Enemy Flaming Cannonball", "scene": "res://src/gameplay/projectiles/enemy_cannonball.tscn"},
	{"name": "Boss Twin Salvo", "scene": "res://src/gameplay/projectiles/boss_projectile_twin_cannon_salvo.tscn"}
]

var ship_items: Array[Dictionary] = [
	{"name": "The Dinghy", "res": "res://src/data/resources/user_vessels/dinghy_ship.tres"},
	{"name": "The Sloop", "res": "res://src/data/resources/user_vessels/sloop_ship.tres"},
	{"name": "The Ironclad", "res": "res://src/data/resources/user_vessels/ironclad_ship.tres"},
	{"name": "The Bombard Skiff", "res": "res://src/data/resources/user_vessels/bombard_skiff_ship.tres"}
]

var current_object_node: Node3D = null
var current_sprite: Sprite3D = null
var current_resource: Resource = null
var is_bobbing_enabled: bool = false
var bob_time: float = 0.0
var base_y_position: float = 0.48
var updating_ui: bool = false

func _ready() -> void:
	GameState.is_game_active = false
	_setup_ui()
	_on_category_selected(0)

func _setup_ui() -> void:
	if category_option:
		category_option.clear()
		for cat in categories:
			category_option.add_item(cat)
		category_option.selected = 0
		category_option.item_selected.connect(_on_category_selected)
		
	if object_option:
		object_option.item_selected.connect(_on_object_selected)
		
	if slider_pos_y: slider_pos_y.value_changed.connect(_on_slider_changed)
	if slider_psize: slider_psize.value_changed.connect(_on_slider_changed)
	if slider_scale: slider_scale.value_changed.connect(_on_slider_changed)
	if slider_rot_x: slider_rot_x.value_changed.connect(_on_slider_changed)
	if slider_rot_y: slider_rot_y.value_changed.connect(_on_slider_changed)
	
	if input_pos_y:
		input_pos_y.text_submitted.connect(func(t): _on_input_submitted(slider_pos_y, t))
		input_pos_y.focus_exited.connect(func(): _on_input_submitted(slider_pos_y, input_pos_y.text))
	if input_psize:
		input_psize.text_submitted.connect(func(t): _on_input_submitted(slider_psize, t))
		input_psize.focus_exited.connect(func(): _on_input_submitted(slider_psize, input_psize.text))
	if input_scale:
		input_scale.text_submitted.connect(func(t): _on_input_submitted(slider_scale, t))
		input_scale.focus_exited.connect(func(): _on_input_submitted(slider_scale, input_scale.text))
	if input_rot_x:
		input_rot_x.text_submitted.connect(func(t): _on_input_submitted(slider_rot_x, t))
		input_rot_x.focus_exited.connect(func(): _on_input_submitted(slider_rot_x, input_rot_x.text))
	if input_rot_y:
		input_rot_y.text_submitted.connect(func(t): _on_input_submitted(slider_rot_y, t))
		input_rot_y.focus_exited.connect(func(): _on_input_submitted(slider_rot_y, input_rot_y.text))

	if btn_pos_y_dec: btn_pos_y_dec.pressed.connect(func(): _step_slider(slider_pos_y, -0.01))
	if btn_pos_y_inc: btn_pos_y_inc.pressed.connect(func(): _step_slider(slider_pos_y, 0.01))
	if btn_psize_dec: btn_psize_dec.pressed.connect(func(): _step_slider(slider_psize, -0.0001))
	if btn_psize_inc: btn_psize_inc.pressed.connect(func(): _step_slider(slider_psize, 0.0001))
	if btn_scale_dec: btn_scale_dec.pressed.connect(func(): _step_slider(slider_scale, -0.01))
	if btn_scale_inc: btn_scale_inc.pressed.connect(func(): _step_slider(slider_scale, 0.01))
	if btn_rot_x_dec: btn_rot_x_dec.pressed.connect(func(): _step_slider(slider_rot_x, -1.0))
	if btn_rot_x_inc: btn_rot_x_inc.pressed.connect(func(): _step_slider(slider_rot_x, 1.0))
	if btn_rot_y_dec: btn_rot_y_dec.pressed.connect(func(): _step_slider(slider_rot_y, -1.0))
	if btn_rot_y_inc: btn_rot_y_inc.pressed.connect(func(): _step_slider(slider_rot_y, 1.0))

	if btn_bobbing_toggle:
		btn_bobbing_toggle.pressed.connect(_on_btn_bobbing_toggle_pressed)
		_update_bobbing_button()
		
	if btn_cam_lane: btn_cam_lane.pressed.connect(func(): _set_camera_view(CamView.LANE))
	if btn_cam_boss: btn_cam_boss.pressed.connect(func(): _set_camera_view(CamView.BOSS))
	if btn_cam_waterline: btn_cam_waterline.pressed.connect(func(): _set_camera_view(CamView.WATERLINE))
	
	if slider_zoom: slider_zoom.value_changed.connect(func(v): _on_zoom_changed(v))
	if btn_zoom_in: btn_zoom_in.pressed.connect(func(): _adjust_zoom(-0.1))
	if btn_zoom_out: btn_zoom_out.pressed.connect(func(): _adjust_zoom(0.1))
	if btn_zoom_reset: btn_zoom_reset.pressed.connect(func(): _reset_zoom())

	if btn_print_values:
		btn_print_values.pressed.connect(_on_btn_print_values_pressed)

func _set_camera_view(view: CamView) -> void:
	current_cam_view = view
	_apply_camera_view()

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
	if slider_zoom:
		slider_zoom.value = 1.0
	_apply_camera_view()

func _apply_camera_view() -> void:
	if not camera_3d:
		return
		
	var target_obj_z = current_object_node.position.z if current_object_node else 0.0
	var base_cam_pos = Vector3.ZERO
	var look_target = Vector3.ZERO
	var fov_val = 70.0
	
	match current_cam_view:
		CamView.LANE:
			base_cam_pos = Vector3(0.0, 9.851, target_obj_z + 11.32)
			look_target = Vector3(0.0, 0.0, target_obj_z)
			fov_val = 70.0
		CamView.BOSS:
			base_cam_pos = Vector3(0.0, 11.0, target_obj_z + 24.0)
			look_target = Vector3(0.0, 0.3, target_obj_z + 9.0)
			fov_val = 70.0
		CamView.WATERLINE:
			base_cam_pos = Vector3(0.0, 1.4, target_obj_z + 5.0)
			look_target = Vector3(0.0, 0.3, target_obj_z)
			fov_val = 55.0

	var cam_offset = (base_cam_pos - look_target) * zoom_factor
	camera_3d.global_position = look_target + cam_offset
	camera_3d.look_at(look_target, Vector3.UP)
	camera_3d.fov = fov_val

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_adjust_zoom(-0.08)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_adjust_zoom(0.08)

func _on_category_selected(cat_idx: int) -> void:
	if not object_option:
		return
	object_option.clear()
	
	match cat_idx:
		0: # Enemies & Mobs
			for item in enemy_items:
				object_option.add_item(item["name"])
		1: # Barrels, Hazards & Obstacles
			for item in obstacle_items:
				object_option.add_item(item["name"])
		2: # Gates & Collectibles
			for item in gate_items:
				object_option.add_item(item["name"])
		3: # Ammunition & Projectiles
			for item in ammo_items:
				object_option.add_item(item["name"])
		4: # Player Ships
			for item in ship_items:
				object_option.add_item(item["name"])
				
	object_option.selected = 0
	_on_object_selected(0)

func _on_object_selected(obj_idx: int) -> void:
	# Clear previous object
	for child in object_container.get_children():
		child.queue_free()
		
	current_object_node = null
	current_sprite = null
	current_resource = null
	
	var cat_idx = category_option.selected if category_option else 0
	
	match cat_idx:
		0: # Enemies
			if obj_idx < enemy_items.size():
				var item = enemy_items[obj_idx]
				if item.has("res"):
					var res_path = item["res"]
					var e_data = load(res_path) as EnemyData
					current_resource = e_data
					var enemy_scene = load("res://src/gameplay/enemies/enemy_mob.tscn")
					var instance = enemy_scene.instantiate() as Node3D
					object_container.add_child(instance)
					current_object_node = instance
					if instance.has_method("apply_enemy_data"):
						instance.apply_enemy_data(e_data)
					current_sprite = instance.get_node_or_null("EnemySprite") as Sprite3D
					if not current_sprite:
						current_sprite = instance.get_node_or_null("MobSprite") as Sprite3D
				elif item.has("scene"):
					var scene_path = item["scene"]
					var s_res = load(scene_path) as PackedScene
					if s_res:
						var instance = s_res.instantiate() as Node3D
						object_container.add_child(instance)
						current_object_node = instance
						current_sprite = instance.get_node_or_null("BossSprite") as Sprite3D
						if not current_sprite:
							current_sprite = instance.get_node_or_null("EnemySprite") as Sprite3D
						if not current_sprite:
							current_sprite = instance.get_node_or_null("Sprite3D") as Sprite3D
				
		1: # Barrels, Hazards & Obstacles
			if obj_idx < obstacle_items.size():
				var item = obstacle_items[obj_idx]
				if item.has("type"):
					var type_id = item["type"]
					var obs_scene = load("res://src/gameplay/obstacles/destructible_barrel.tscn") as PackedScene
					if obs_scene:
						var instance = obs_scene.instantiate() as Node3D
						object_container.add_child(instance)
						current_object_node = instance
						if "obstacle_type" in instance:
							instance.obstacle_type = type_id
						current_sprite = instance.get_node_or_null("ObstacleSprite") as Sprite3D
				elif item.has("scene"):
					var scene_path = item["scene"]
					var s_res = load(scene_path) as PackedScene
					if s_res:
						var instance = s_res.instantiate() as Node3D
						object_container.add_child(instance)
						current_object_node = instance
						current_sprite = instance.get_node_or_null("ObstacleSprite") as Sprite3D
						if not current_sprite:
							current_sprite = instance.get_node_or_null("PodMesh") as Sprite3D
						if not current_sprite:
							current_sprite = instance.get_node_or_null("Sprite3D") as Sprite3D
				elif item.has("reticle"):
					var reticle = Sprite3D.new()
					reticle.axis = Vector3.AXIS_Y
					reticle.double_sided = true
					reticle.texture = load("res://assets/sprites/ui/bombard_target_reticle.png")
					reticle.pixel_size = 0.0058
					reticle.modulate = Color(1.2, 0.45, 0.1, 0.85)
					object_container.add_child(reticle)
					current_object_node = reticle
					current_sprite = reticle
				
		2: # Gates & Collectibles
			if obj_idx < gate_items.size():
				var item = gate_items[obj_idx]
				if item.has("scene"):
					var scene_path = item["scene"]
					var scene_res = load(scene_path) as PackedScene
					if scene_res:
						var instance = scene_res.instantiate() as Node3D
						object_container.add_child(instance)
						current_object_node = instance
						current_sprite = instance.get_node_or_null("GateSprite") as Sprite3D
						if not current_sprite:
							current_sprite = instance.get_node_or_null("Sprite3D") as Sprite3D
						if not current_sprite:
							var visuals = instance.get_node_or_null("Visuals")
							if visuals:
								current_sprite = visuals.get_node_or_null("ChestSprite") as Sprite3D
				elif item.has("class") and item["class"] == "CollectibleXpOrb":
					var orb_script = load("res://src/gameplay/collectibles/collectible_xp_orb.gd")
					var instance = Area3D.new()
					instance.set_script(orb_script)
					object_container.add_child(instance)
					current_object_node = instance

		3: # Ammunition & Projectiles
			if obj_idx < ammo_items.size():
				var item = ammo_items[obj_idx]
				if item.has("ammo_res"):
					var res_path = item["ammo_res"]
					var ammo_data = load(res_path) as AmmoData
					current_resource = ammo_data
					var cannonball_scene = load("res://src/gameplay/projectiles/cannonball.tscn") as PackedScene
					if cannonball_scene:
						var instance = cannonball_scene.instantiate() as Area3D
						if "ammo_data" in instance:
							instance.ammo_data = ammo_data
						object_container.add_child(instance)
						current_object_node = instance
						current_sprite = instance.get_node_or_null("Sprite3D") as Sprite3D
				elif item.has("scene"):
					var scene_path = item["scene"]
					var s_res = load(scene_path) as PackedScene
					if s_res:
						var instance = s_res.instantiate() as Node3D
						object_container.add_child(instance)
						current_object_node = instance
						current_sprite = instance.get_node_or_null("AmmoSprite") as Sprite3D
						if not current_sprite:
							current_sprite = instance.get_node_or_null("Sprite3D") as Sprite3D
						
		4: # Player Ships
			if obj_idx < ship_items.size():
				var res_path = ship_items[obj_idx]["res"]
				var s_data = load(res_path) as ShipData
				current_resource = s_data
				var boat_scene = load("res://src/gameplay/player/player_boat.tscn")
				var instance = boat_scene.instantiate() as CharacterBody3D
				if instance.has_method("_setup_calibration_mode"):
					instance._setup_calibration_mode()
				instance.is_calibration_mode = true
				object_container.add_child(instance)
				current_object_node = instance
				if instance.has_method("apply_ship_data"):
					instance.apply_ship_data(s_data)
				var visuals = instance.get_node_or_null("BoatVisuals")
				if visuals:
					var spr = visuals.get_node_or_null("BoatSprite") as Sprite3D
					if spr and spr.visible:
						current_sprite = spr
					else:
						current_sprite = null

	if current_object_node:
		# Fallback search for any visible Sprite3D child if not directly found
		var cat_idx_init = category_option.selected if category_option else 0
		if not current_sprite and cat_idx_init != 4:
			for child in current_object_node.find_children("*", "Sprite3D"):
				if child.visible:
					current_sprite = child
					break
				
		# Freeze physics and forward movement so object stays completely stationary
		current_object_node.set_physics_process(false)
		if "forward_speed" in current_object_node:
			current_object_node.forward_speed = 0.0
		if "speed" in current_object_node:
			current_object_node.speed = 0.0
		current_object_node.position = Vector3.ZERO
		
		var item_name = object_option.get_item_text(obj_idx) if object_option else ""
		if "Boss" in item_name:
			current_cam_view = CamView.BOSS
		else:
			current_cam_view = CamView.LANE

	_update_ui_from_current_object()

func _update_ui_from_current_object() -> void:
	if not current_object_node:
		return
		
	updating_ui = true
	var pos_y = current_object_node.position.y
	var psize = 0.0021
	var sc = 1.0
	var rot_x = 0.0
	var rot_y = 0.0
	
	var cat_idx = category_option.selected if category_option else 0
	if cat_idx == 4 and current_resource is ShipData: # Player Ships
		var s_data = current_resource as ShipData
		pos_y = s_data.y_offset
		psize = s_data.pixel_size
		sc = s_data.scale.x if s_data.scale != Vector3.ZERO else 1.0
		rot_x = s_data.rotation_degrees.x
		rot_y = s_data.rotation_degrees.y
	elif cat_idx == 0 or cat_idx == 1 or cat_idx == 3: # Enemies, Obstacles, Ammo
		var boss_mesh = current_object_node.get_node_or_null("BossMesh") if current_object_node.get_node_or_null("BossMesh") else current_object_node.get_node_or_null("VisualContainer")
		if boss_mesh:
			pos_y = boss_mesh.position.y
			sc = boss_mesh.scale.x
			rot_x = boss_mesh.rotation_degrees.x
			rot_y = boss_mesh.rotation_degrees.y
		elif current_sprite:
			pos_y = current_sprite.position.y
			psize = current_sprite.pixel_size
			sc = current_object_node.scale.x
			rot_x = current_sprite.rotation_degrees.x
			rot_y = current_object_node.rotation_degrees.y
		else:
			pos_y = current_object_node.position.y
			sc = current_object_node.scale.x
			rot_x = current_object_node.rotation_degrees.x
			rot_y = current_object_node.rotation_degrees.y
	elif cat_idx == 2: # Gates & Collectibles
		var name_str = object_option.get_item_text(object_option.selected) if object_option else ""
		if "Gate" in name_str:
			var visuals_node = current_object_node.get_node_or_null("Visuals") as Node3D
			if visuals_node:
				pos_y = visuals_node.position.y
		else:
			pos_y = current_object_node.position.y
		if current_sprite:
			psize = current_sprite.pixel_size
			rot_x = current_sprite.rotation_degrees.x
		sc = current_object_node.scale.x
		rot_y = current_object_node.rotation_degrees.y
				
	base_y_position = pos_y
	
	if slider_pos_y: slider_pos_y.value = pos_y
	if slider_psize: slider_psize.value = psize
	if slider_scale: slider_scale.value = sc
	if slider_rot_x: slider_rot_x.value = rot_x
	if slider_rot_y: slider_rot_y.value = rot_y
	
	_update_inputs(pos_y, psize, sc, rot_x, rot_y)
	updating_ui = false
	_apply_camera_view()

func _on_slider_changed(_val: float) -> void:
	if updating_ui or not current_object_node:
		return
		
	var new_pos_y = slider_pos_y.value if slider_pos_y else 0.48
	var new_psize = slider_psize.value if slider_psize else 0.0021
	var new_scale = slider_scale.value if slider_scale else 1.0
	var new_rot_x = slider_rot_x.value if slider_rot_x else 0.0
	var new_rot_y = slider_rot_y.value if slider_rot_y else 0.0
	
	base_y_position = new_pos_y
	
	var cat_idx = category_option.selected if category_option else 0
	
	if cat_idx == 4: # Player Ships: update BoatMesh or BoatSprite inside visuals
		current_object_node.position = Vector3.ZERO
		current_object_node.scale = Vector3.ONE
		var visuals = current_object_node.get_node_or_null("BoatVisuals")
		var boat_mesh = visuals.get_node_or_null("BoatMesh") if visuals else null
		if boat_mesh and boat_mesh.visible:
			boat_mesh.scale = Vector3.ONE * new_scale
			boat_mesh.rotation_degrees = Vector3(new_rot_x, new_rot_y, 0.0)
			boat_mesh.position.y = new_pos_y
		elif current_sprite:
			current_sprite.scale = Vector3.ONE * new_scale
			current_sprite.rotation_degrees = Vector3(new_rot_x, new_rot_y, 0.0)
			current_sprite.position.y = new_pos_y
			current_sprite.pixel_size = new_psize
		var hardpoints = current_object_node.get_node_or_null("Hardpoints")
		if hardpoints:
			hardpoints.position.y = new_pos_y
			hardpoints.rotation_degrees = Vector3(new_rot_x, new_rot_y, 0.0)
	elif cat_idx == 2: # Gates & Collectibles
		var name_str = object_option.get_item_text(object_option.selected) if object_option else ""
		if "Gate" in name_str:
			current_object_node.position.y = 0.0
			var visuals_node = current_object_node.get_node_or_null("Visuals") as Node3D
			if visuals_node:
				visuals_node.position.y = new_pos_y
		else:
			current_object_node.position.y = new_pos_y
		current_object_node.scale = Vector3.ONE * new_scale
		current_object_node.rotation_degrees.y = new_rot_y
		if current_sprite:
			current_sprite.rotation_degrees.x = new_rot_x
			current_sprite.pixel_size = new_psize
	elif cat_idx == 3: # Ammo & Projectiles
		current_object_node.position.y = new_pos_y
		if current_sprite:
			current_sprite.position.y = 0.0
			current_sprite.rotation_degrees.x = new_rot_x
			current_sprite.pixel_size = new_psize
		current_object_node.scale = Vector3.ONE * new_scale
		current_object_node.rotation_degrees.y = new_rot_y
	else: # Mobs, Bosses and Obstacles
		var boss_mesh = current_object_node.get_node_or_null("BossMesh") if current_object_node.get_node_or_null("BossMesh") else current_object_node.get_node_or_null("VisualContainer")
		if boss_mesh:
			current_object_node.position = Vector3.ZERO
			boss_mesh.position.y = new_pos_y
			boss_mesh.scale = Vector3.ONE * new_scale
			boss_mesh.rotation_degrees = Vector3(new_rot_x, new_rot_y, 0.0)
			var health_bar = current_object_node.get_node_or_null("HealthBarSprite") as Sprite3D
			if health_bar:
				health_bar.position.y = new_pos_y + (new_scale * 1.2)
		else:
			current_object_node.position.y = 0.0
			if current_sprite:
				current_sprite.position.y = new_pos_y
				current_sprite.rotation_degrees.x = new_rot_x
				current_sprite.pixel_size = new_psize
			else:
				current_object_node.rotation_degrees.x = new_rot_x
			current_object_node.scale = Vector3.ONE * new_scale
			current_object_node.rotation_degrees.y = new_rot_y
			var health_bar = current_object_node.get_node_or_null("HealthBarSprite") as Sprite3D
			if health_bar:
				health_bar.position.y = new_pos_y + 0.85
			
	if current_resource:
		if "y_offset" in current_resource:
			current_resource.y_offset = new_pos_y
		if "pixel_size" in current_resource:
			current_resource.pixel_size = new_psize
		if "scale" in current_resource:
			current_resource.scale = Vector3.ONE * new_scale
		if "rotation_degrees" in current_resource:
			current_resource.rotation_degrees = Vector3(new_rot_x, new_rot_y, 0.0)
			
	_update_inputs(new_pos_y, new_psize, new_scale, new_rot_x, new_rot_y)

func _process(delta: float) -> void:
	if not current_object_node:
		return
		
	var cat_idx = category_option.selected if category_option else 0
	var offset_y = base_y_position
	if is_bobbing_enabled:
		bob_time += delta * 2.2
		offset_y += sin(bob_time) * 0.04
		
	if cat_idx == 4: # Vessels
		var visuals = current_object_node.get_node_or_null("BoatVisuals")
		var boat_mesh = visuals.get_node_or_null("BoatMesh") if visuals else null
		if boat_mesh and boat_mesh.visible:
			boat_mesh.position.y = offset_y
		elif current_sprite:
			current_sprite.position.y = offset_y
		var hardpoints = current_object_node.get_node_or_null("Hardpoints")
		if hardpoints:
			hardpoints.position.y = offset_y
	elif cat_idx == 3: # Ammo
		current_object_node.position = Vector3(0.0, offset_y, 0.0)
	elif cat_idx == 2: # Gates & Collectibles
		var name_str = object_option.get_item_text(object_option.selected) if object_option else ""
		if "Gate" in name_str:
			current_object_node.position = Vector3.ZERO
			var visuals_node = current_object_node.get_node_or_null("Visuals") as Node3D
			if visuals_node:
				visuals_node.position.y = offset_y
		else:
			current_object_node.position = Vector3(0.0, offset_y, 0.0)
	else: # Enemies and Obstacles
		current_object_node.position = Vector3.ZERO
		if current_sprite:
			current_sprite.position.y = offset_y

func _on_input_submitted(slider: HSlider, text: String) -> void:
	if not slider:
		return
	var val = text.to_float()
	slider.value = clamp(val, slider.min_value, slider.max_value)

func _step_slider(slider: HSlider, delta: float) -> void:
	if slider:
		slider.value = clamp(slider.value + delta, slider.min_value, slider.max_value)

func _update_inputs(pos_y: float, psize: float, sc: float, rot_x: float, rot_y: float) -> void:
	if input_pos_y and not input_pos_y.has_focus(): input_pos_y.text = "%.2f" % pos_y
	if input_psize and not input_psize.has_focus(): input_psize.text = "%.4f" % psize
	if input_scale and not input_scale.has_focus(): input_scale.text = "%.2f" % sc
	if input_rot_x and not input_rot_x.has_focus(): input_rot_x.text = "%.1f" % rot_x
	if input_rot_y and not input_rot_y.has_focus(): input_rot_y.text = "%.1f" % rot_y

func _on_btn_bobbing_toggle_pressed() -> void:
	is_bobbing_enabled = not is_bobbing_enabled
	_update_bobbing_button()

func _update_bobbing_button() -> void:
	if btn_bobbing_toggle:
		var status = "ON" if is_bobbing_enabled else "OFF"
		btn_bobbing_toggle.text = "Water Floating Bobbing: " + status

func _on_btn_print_values_pressed() -> void:
	if not current_object_node:
		return
		
	var obj_name = "Object"
	if object_option and object_option.selected >= 0:
		obj_name = object_option.get_item_text(object_option.selected)
		
	var pos_y = slider_pos_y.value if slider_pos_y else current_object_node.position.y
	var psize = slider_psize.value if slider_psize else 0.0021
	var sc = slider_scale.value if slider_scale else 1.0
	var rot_x = slider_rot_x.value if slider_rot_x else 0.0
	var rot_y = slider_rot_y.value if slider_rot_y else 0.0
	
	print("\n==========================================")
	print("COPY & PASTE CALIBRATION FOR: %s" % obj_name)
	print("==========================================")
	print("y_offset = %.2f" % pos_y)
	print("pixel_size = %.4f" % psize)
	print("scale = Vector3(%.2f, %.2f, %.2f)" % [sc, sc, sc])
	print("rotation_degrees = Vector3(%.1f, %.1f, 0.0)" % [rot_x, rot_y])
	print("==========================================\n")
