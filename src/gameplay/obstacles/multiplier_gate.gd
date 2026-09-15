class_name MultiplierGate
extends Area3D

enum OperationType { ADD, MULTIPLY }

@export var operation: OperationType = OperationType.ADD:
	set(val):
		operation = val
		if is_node_ready():
			update_visuals()

@export var value: int = 10:
	set(val):
		value = clamp(val, 1, 100)
		if is_node_ready():
			update_visuals()

@export var is_active: bool = true
@export var cannonball_scene: PackedScene = preload("res://src/gameplay/projectiles/cannonball.tscn")

@export var choice_group: String = ""
@export var custom_text: String = ""
@export var gate_action: String = ""

@onready var visuals: Node3D = $Visuals
@onready var label_3d: Label3D = $Visuals/Label3D
@onready var tag_label_3d: Label3D = get_node_or_null("Visuals/TagLabel3D") as Label3D

var _processed_cannonballs: Dictionary = {}

func _ready() -> void:
	add_to_group("multiplier_gate")
	area_entered.connect(_on_area_entered)
	value = clamp(value, 1, 100)
		
	# Apply water calibration offset, pixel size, and scale
	var gate_sprite = get_node_or_null("Visuals/GateSprite") as Sprite3D
	if gate_sprite:
		gate_sprite.pixel_size = 0.0028
	if visuals:
		visuals.position.y = -0.13
	scale = Vector3(1.09, 1.09, 1.09)
		
	_clean_shadow_nodes(self)
	update_visuals()

func on_shot_hit(_cannonball: Node = null) -> void:
	if not is_active:
		return
		
	var cur_val = value
	if not custom_text.is_empty() and custom_text != "★ 100 MAX ★":
		var clean_text = custom_text.replace(" Ships", "").replace(" Ship", "").replace(" ships", "").replace(" ship", "").replace("★", "").replace("MAX", "").strip_edges()
		var num = clean_text.to_int()
		if num != 0:
			cur_val = abs(num)
			
	var max_cap = 100
	if cur_val < max_cap:
		var increment = 5
		if _cannonball and _cannonball.get("damage") and _cannonball.damage > 1:
			increment = 10
		cur_val = min(cur_val + increment, max_cap)
		value = cur_val
		if cur_val >= max_cap:
			custom_text = "★ 100 MAX ★"
		else:
			custom_text = "+%d" % cur_val
		update_visuals()
		
		var pitch_scale = lerpf(1.1, 1.75, float(cur_val) / float(max_cap))
		AudioManager.play_sfx("gate_passes", pitch_scale, pitch_scale + 0.15)
		
		if cur_val >= max_cap:
			AudioManager.play_sfx("coin_pickup", 1.4, 1.6)
		
		if visuals:
			var tween = create_tween().set_parallel(true)
			var target_punch = Vector3(1.35, 1.35, 1.35) if cur_val < max_cap else Vector3(1.5, 1.5, 1.5)
			visuals.scale = target_punch
			tween.tween_property(visuals, "scale", Vector3(1.09, 1.09, 1.09), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			if label_3d:
				var flash_col = Color(1.0, 1.0, 0.7) if cur_val < max_cap else Color(1.0, 1.0, 1.0)
				label_3d.modulate = flash_col
				var end_col = _get_value_color(cur_val)
				tween.tween_property(label_3d, "modulate", end_col, 0.22)

func _get_value_color(val: int) -> Color:
	if val >= 100:
		return Color(1.0, 0.9, 0.2)  # Radiant Gold
	elif val >= 75:
		return Color(1.0, 0.6, 0.15) # Fiery Amber
	elif val >= 50:
		return Color(0.85, 0.35, 1.0) # Royal Violet
	elif val >= 25:
		return Color(0.3, 1.0, 0.5)   # Vibrant Emerald
	else:
		return Color(0.25, 0.85, 1.0) # Cyan Hologram

func update_visuals() -> void:
	var cur_val = value
	var gate_sprite = get_node_or_null("Visuals/GateSprite") as Sprite3D
	var val_color = _get_value_color(cur_val)
	
	if gate_sprite:
		if cur_val >= 100:
			gate_sprite.modulate = Color(1.0, 0.85, 0.2, 1.0)
		elif cur_val >= 75:
			gate_sprite.modulate = Color(1.0, 0.55, 0.1, 0.95)
		elif cur_val >= 50:
			gate_sprite.modulate = Color(0.75, 0.25, 1.0, 0.95)
		elif cur_val >= 25:
			gate_sprite.modulate = Color(0.2, 0.95, 0.4, 0.9)
		else:
			gate_sprite.modulate = Color(0.15, 0.75, 1.0, 0.85)
		
	if label_3d:
		if cur_val >= 100:
			label_3d.text = "★ 100 MAX ★"
		elif not custom_text.is_empty():
			var clean_text = custom_text.replace(" Ships", "").replace(" Ship", "").replace(" ships", "").replace(" ship", "").strip_edges()
			var num = clean_text.to_int()
			if num != 0:
				cur_val = abs(num)
			if num > 0 and not clean_text.begins_with("+"):
				clean_text = "+" + str(num)
			label_3d.text = clean_text
		else:
			label_3d.text = "+%d" % cur_val
			
		label_3d.modulate = val_color
		label_3d.outline_size = 16
		label_3d.outline_modulate = Color(0.0, 0.0, 0.0, 1.0)
		label_3d.font_size = 85 if cur_val < 100 else 72

	if not tag_label_3d:
		tag_label_3d = get_node_or_null("Visuals/TagLabel3D") as Label3D
	if tag_label_3d:
		if cur_val >= 100:
			tag_label_3d.text = "★ ARMADA OVERDRIVE READY! ★"
			tag_label_3d.modulate = Color(1.0, 0.95, 0.3)
		elif cur_val >= 75:
			tag_label_3d.text = "ALMOST MAXED! KEEP FIRING!"
			tag_label_3d.modulate = Color(1.0, 0.7, 0.2)
		elif cur_val >= 40:
			tag_label_3d.text = "PUMP THE ARMADA!"
			tag_label_3d.modulate = Color(0.85, 0.4, 1.0)
		else:
			tag_label_3d.text = "SHOOT FOR FLEET & GOLD"
			tag_label_3d.modulate = Color(0.3, 0.9, 1.0)

func _on_area_entered(area: Area3D) -> void:
	if not is_active:
		return

	# Handle cannonball shooting gate to increment multiplier
	if area.is_in_group("cannonballs") and not area.is_in_group("enemy_projectiles"):
		on_shot_hit(area)
		return
		
	var is_player = area.name == "CollisionArea" or area.is_in_group("player") or (area.get_parent() and area.get_parent().is_in_group("player"))
	if not is_player:
		return
		
	is_active = false
	AudioManager.play_sfx("gate_passes")
	
	# Determine value to add (fallback to custom_text parsing)
	var final_value = value
	if not custom_text.is_empty() and custom_text != "★ 100 MAX ★":
		var clean_text = custom_text.replace(" Ships", "").replace(" Ship", "").replace(" ships", "").replace(" ship", "").strip_edges()
		var num = clean_text.to_int()
		if num != 0:
			final_value = abs(num)
			
	# Handle choice group deactivation
	if not choice_group.is_empty():
		var gates = get_tree().get_nodes_in_group("multiplier_gate")
		for gate in gates:
			if gate is MultiplierGate and gate.choice_group == choice_group and gate != self:
				gate.is_active = false
				var t = gate.create_tween().set_parallel(true)
				t.tween_property(gate, "modulate:a", 0.0, 0.25)
				t.chain().tween_callback(gate.queue_free)
				
	# Find the player node
	var player_node = null
	if area.is_in_group("player") and not area.name == "CollisionArea":
		player_node = area
	elif area.get_parent() and area.get_parent().is_in_group("player"):
		player_node = area.get_parent()
	else:
		player_node = get_tree().get_first_node_in_group("player")
		
	# Calculate rewards based on 1-100 progression
	var ships_to_add = clamp(int(ceil(float(final_value) / 25.0)), 1, 4)
	var doubloons_to_add = 250 if final_value >= 100 else (final_value * 2)
	
	GameState.doubloons += doubloons_to_add
	if player_node:
		if "doubloons" in player_node:
			player_node.doubloons += doubloons_to_add
		if player_node.has_signal("doubloons_changed"):
			player_node.doubloons_changed.emit(GameState.doubloons)
		if player_node.has_method("add_follower_ships"):
			player_node.add_follower_ships(ships_to_add)
		if final_value >= 100 and player_node.has_method("trigger_armada_overdrive"):
			player_node.trigger_armada_overdrive()
		if player_node.has_method("spawn_floating_text_at_position"):
			var msg = "+%d Gold! +%d Fleet!" % [doubloons_to_add, ships_to_add] if final_value < 100 else "★ 100 MAX! +%d Gold! ★" % doubloons_to_add
			player_node.spawn_floating_text_at_position(msg, Color(1.0, 0.85, 0.1))
		
	_play_disappear_animation()

func _play_disappear_animation() -> void:
	# Disable collision immediately
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	for child in get_children():
		if child is CollisionShape3D:
			child.set_deferred("disabled", true)
			
	if not visuals:
		queue_free()
		return
		
	var tween = create_tween().set_parallel(true)
	tween.tween_property(visuals, "scale", Vector3(1.35, 1.35, 1.35), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(visuals, "position:y", visuals.position.y + 0.8, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	var gate_sprite = get_node_or_null("Visuals/GateSprite") as Sprite3D
	if gate_sprite:
		tween.tween_property(gate_sprite, "modulate:a", 0.0, 0.22)
	if label_3d:
		tween.tween_property(label_3d, "modulate:a", 0.0, 0.22)
	if tag_label_3d:
		tween.tween_property(tag_label_3d, "modulate:a", 0.0, 0.22)
		
	tween.chain().tween_callback(queue_free)

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
