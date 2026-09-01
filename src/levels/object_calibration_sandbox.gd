extends Node3D

@onready var object_container: Node3D = $ObjectContainer

@onready var category_option: OptionButton = %category_option
@onready var object_option: OptionButton = %object_option

@onready var slider_pos_y: HSlider = %slider_pos_y
@onready var slider_psize: HSlider = %slider_psize
@onready var slider_scale: HSlider = %slider_scale
@onready var slider_rot_y: HSlider = %slider_rot_y

@onready var input_pos_y: LineEdit = %input_pos_y
@onready var input_psize: LineEdit = %input_psize
@onready var input_scale: LineEdit = %input_scale
@onready var input_rot_y: LineEdit = %input_rot_y

@onready var btn_pos_y_dec: Button = %btn_pos_y_dec
@onready var btn_pos_y_inc: Button = %btn_pos_y_inc
@onready var btn_psize_dec: Button = %btn_psize_dec
@onready var btn_psize_inc: Button = %btn_psize_inc
@onready var btn_scale_dec: Button = %btn_scale_dec
@onready var btn_scale_inc: Button = %btn_scale_inc
@onready var btn_rot_y_dec: Button = %btn_rot_y_dec
@onready var btn_rot_y_inc: Button = %btn_rot_y_inc

@onready var btn_bobbing_toggle: Button = %btn_bobbing_toggle
@onready var btn_print_values: Button = %btn_print_values

# Object Definitions
var categories: Array[String] = [
	"Enemies & Mobs",
	"Barrels & Obstacles",
	"Gates & Collectibles",
	"Vessels / Player Ships"
]

var enemy_items: Array[Dictionary] = [
	{"name": "Skeleton Rower", "res": "res://src/data/resources/enemy_vessels/skeleton_rower.tres"},
	{"name": "Raider Skiff", "res": "res://src/data/resources/enemy_vessels/raider_skiff.tres"},
	{"name": "Goblin Skiff", "res": "res://src/data/resources/enemy_vessels/goblin_skiff.tres"},
	{"name": "Turtle Raft", "res": "res://src/data/resources/enemy_vessels/turtle_raft.tres"},
	{"name": "Boss Bone-Beard", "res": "res://src/data/resources/enemy_bosses/boss_bone_beard.tres"},
	{"name": "Boss War-Barge", "scene": "res://src/gameplay/enemies/boss_war_barge.tscn"}
]

var obstacle_items: Array[Dictionary] = [
	{"name": "Wooden Barrel", "type": 0}, # ObstacleType.WOODEN_BARREL
	{"name": "Fuse Barrel", "type": 1},   # FUSE_BARREL
	{"name": "Rune Barrel", "type": 2},   # RUNE_BARREL
	{"name": "Spiked Sea Mine", "type": 3}, # SEA_MINE
	{"name": "Coral Reef", "type": 4}     # CORAL_REEF
]

var gate_items: Array[Dictionary] = [
	{"name": "Multiplier Gate Arch", "scene": "res://src/gameplay/obstacles/multiplier_gate.tscn"},
	{"name": "Collectible Doubloon", "scene": "res://src/gameplay/collectibles/collectible_doubloon.tscn"}
]

var ship_items: Array[Dictionary] = [
	{"name": "The Dinghy", "res": "res://src/data/resources/user_vessels/dinghy_ship.tres"},
	{"name": "The Sloop", "res": "res://src/data/resources/user_vessels/sloop_ship.tres"},
	{"name": "The Ironclad", "res": "res://src/data/resources/user_vessels/ironclad_ship.tres"}
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
	if input_rot_y:
		input_rot_y.text_submitted.connect(func(t): _on_input_submitted(slider_rot_y, t))
		input_rot_y.focus_exited.connect(func(): _on_input_submitted(slider_rot_y, input_rot_y.text))

	if btn_pos_y_dec: btn_pos_y_dec.pressed.connect(func(): _step_slider(slider_pos_y, -0.01))
	if btn_pos_y_inc: btn_pos_y_inc.pressed.connect(func(): _step_slider(slider_pos_y, 0.01))
	if btn_psize_dec: btn_psize_dec.pressed.connect(func(): _step_slider(slider_psize, -0.0001))
	if btn_psize_inc: btn_psize_inc.pressed.connect(func(): _step_slider(slider_psize, 0.0001))
	if btn_scale_dec: btn_scale_dec.pressed.connect(func(): _step_slider(slider_scale, -0.01))
	if btn_scale_inc: btn_scale_inc.pressed.connect(func(): _step_slider(slider_scale, 0.01))
	if btn_rot_y_dec: btn_rot_y_dec.pressed.connect(func(): _step_slider(slider_rot_y, -1.0))
	if btn_rot_y_inc: btn_rot_y_inc.pressed.connect(func(): _step_slider(slider_rot_y, 1.0))

	if btn_bobbing_toggle:
		btn_bobbing_toggle.pressed.connect(_on_btn_bobbing_toggle_pressed)
		_update_bobbing_button()
		
	if btn_print_values:
		btn_print_values.pressed.connect(_on_btn_print_values_pressed)

func _on_category_selected(cat_idx: int) -> void:
	if not object_option:
		return
	object_option.clear()
	
	match cat_idx:
		0: # Enemies
			for item in enemy_items:
				object_option.add_item(item["name"])
		1: # Barrels & Obstacles
			for item in obstacle_items:
				object_option.add_item(item["name"])
		2: # Gates & Collectibles
			for item in gate_items:
				object_option.add_item(item["name"])
		3: # Player Ships
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
				
		1: # Barrels & Obstacles
			if obj_idx < obstacle_items.size():
				var type_id = obstacle_items[obj_idx]["type"]
				var obs_scene = load("res://src/gameplay/obstacles/destructible_barrel.tscn") as PackedScene
				if obs_scene:
					var instance = obs_scene.instantiate() as Node3D
					object_container.add_child(instance)
					current_object_node = instance
					if "obstacle_type" in instance:
						instance.obstacle_type = type_id
					current_sprite = instance.get_node_or_null("ObstacleSprite") as Sprite3D
				
		2: # Gates & Collectibles
			if obj_idx < gate_items.size():
				var scene_path = gate_items[obj_idx]["scene"]
				var scene_res = load(scene_path) as PackedScene
				if scene_res:
					var instance = scene_res.instantiate() as Node3D
					object_container.add_child(instance)
					current_object_node = instance
					current_sprite = instance.get_node_or_null("GateSprite") as Sprite3D
					if not current_sprite:
						current_sprite = instance.get_node_or_null("Sprite3D") as Sprite3D
						
		3: # Player Ships
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
					current_sprite = visuals.get_node_or_null("BoatSprite") as Sprite3D

	if current_object_node:
		# Fallback search for any Sprite3D child if not directly found
		if not current_sprite:
			for child in current_object_node.find_children("*", "Sprite3D"):
				current_sprite = child
				break
				
		# Freeze physics and forward movement so object stays completely stationary
		current_object_node.set_physics_process(false)
		if "forward_speed" in current_object_node:
			current_object_node.forward_speed = 0.0
		if "speed" in current_object_node:
			current_object_node.speed = 0.0
		current_object_node.position = Vector3.ZERO

	_update_ui_from_current_object()

func _update_ui_from_current_object() -> void:
	if not current_object_node:
		return
		
	updating_ui = true
	var pos_y = current_object_node.position.y
	
	var cat_idx = category_option.selected if category_option else 0
	if cat_idx == 0 or cat_idx == 1: # Enemies & Obstacles: height is visual sprite position
		if current_sprite:
			pos_y = current_sprite.position.y
	elif cat_idx == 2: # Gates & Collectibles
		var name_str = object_option.get_item_text(object_option.selected) if object_option else ""
		if "Gate" in name_str:
			var visuals_node = current_object_node.get_node_or_null("Visuals") as Node3D
			if visuals_node:
				pos_y = visuals_node.position.y
				
	base_y_position = pos_y
	
	var psize = current_sprite.pixel_size if current_sprite else 0.0021
	var sc = current_object_node.scale.x
	var rot_y = current_object_node.rotation_degrees.y
	
	if slider_pos_y: slider_pos_y.value = pos_y
	if slider_psize: slider_psize.value = psize
	if slider_scale: slider_scale.value = sc
	if slider_rot_y: slider_rot_y.value = rot_y
	
	_update_inputs(pos_y, psize, sc, rot_y)
	updating_ui = false

func _on_slider_changed(_val: float) -> void:
	if updating_ui or not current_object_node:
		return
		
	var new_pos_y = slider_pos_y.value if slider_pos_y else 0.48
	var new_psize = slider_psize.value if slider_psize else 0.0021
	var new_scale = slider_scale.value if slider_scale else 1.0
	var new_rot_y = slider_rot_y.value if slider_rot_y else 0.0
	
	base_y_position = new_pos_y
	
	var cat_idx = category_option.selected if category_option else 0
	
	if cat_idx == 3: # Vessels: root Y position is the y_offset
		current_object_node.position.y = new_pos_y
		if current_sprite:
			current_sprite.position.y = 0.0
	elif cat_idx == 2: # Gates & Collectibles
		var name_str = object_option.get_item_text(object_option.selected) if object_option else ""
		if "Gate" in name_str:
			current_object_node.position.y = 0.0
			var visuals_node = current_object_node.get_node_or_null("Visuals") as Node3D
			if visuals_node:
				visuals_node.position.y = new_pos_y
		else: # Doubloon
			current_object_node.position.y = new_pos_y
	else: # Mobs and Obstacles: root stays at Y=0, sprite moves to Y=new_pos_y
		current_object_node.position.y = 0.0
		if current_sprite:
			current_sprite.position.y = new_pos_y
		var health_bar = current_object_node.get_node_or_null("HealthBarSprite") as Sprite3D
		if health_bar:
			health_bar.position.y = new_pos_y + 0.85
			
	current_object_node.scale = Vector3.ONE * new_scale
	current_object_node.rotation_degrees.y = new_rot_y
	
	if current_sprite:
		current_sprite.pixel_size = new_psize
			
	if current_resource:
		if "y_offset" in current_resource:
			current_resource.y_offset = new_pos_y
		if "pixel_size" in current_resource:
			current_resource.pixel_size = new_psize
			
	_update_inputs(new_pos_y, new_psize, new_scale, new_rot_y)

func _process(delta: float) -> void:
	if not current_object_node:
		return
		
	var cat_idx = category_option.selected if category_option else 0
	var offset_y = base_y_position
	if is_bobbing_enabled:
		bob_time += delta * 2.2
		offset_y += sin(bob_time) * 0.04
		
	if cat_idx == 3: # Vessels
		current_object_node.position = Vector3(0.0, offset_y, 0.0)
	elif cat_idx == 2: # Gates & Collectibles
		var name_str = object_option.get_item_text(object_option.selected) if object_option else ""
		if "Gate" in name_str:
			current_object_node.position = Vector3.ZERO
			var visuals_node = current_object_node.get_node_or_null("Visuals") as Node3D
			if visuals_node:
				visuals_node.position.y = offset_y
		else: # Doubloon
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

func _update_inputs(pos_y: float, psize: float, sc: float, rot_y: float) -> void:
	if input_pos_y and not input_pos_y.has_focus(): input_pos_y.text = "%.2f" % pos_y
	if input_psize and not input_psize.has_focus(): input_psize.text = "%.4f" % psize
	if input_scale and not input_scale.has_focus(): input_scale.text = "%.2f" % sc
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
	var rot_y = slider_rot_y.value if slider_rot_y else 0.0
	
	print("\n==========================================")
	print("COPY & PASTE CALIBRATION FOR: %s" % obj_name)
	print("==========================================")
	print("y_offset = %.2f" % pos_y)
	print("pixel_size = %.4f" % psize)
	print("scale = Vector3(%.2f, %.2f, %.2f)" % [sc, sc, sc])
	print("rotation_degrees = Vector3(0.0, %.1f, 0.0)" % rot_y)
	print("==========================================\n")
