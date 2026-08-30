class_name MultiplierGate
extends Area3D

enum OperationType { ADD, MULTIPLY }

@export var operation: OperationType = OperationType.ADD:
	set(val):
		operation = val
		if is_node_ready():
			update_visuals()

@export var value: int = 3:
	set(val):
		if operation == OperationType.ADD:
			value = clamp(val, 1, 5)
		else:
			value = clamp(val, 2, 3)
		if is_node_ready():
			update_visuals()

@export var is_active: bool = true
@export var cannonball_scene: PackedScene = preload("res://src/gameplay/projectiles/cannonball.tscn")

@export var choice_group: String = ""
@export var custom_text: String = ""
@export var gate_action: String = ""

@onready var visuals: Node3D = $Visuals
@onready var label_3d: Label3D = $Visuals/Label3D

var _processed_cannonballs: Dictionary = {}

func _ready() -> void:
	add_to_group("multiplier_gate")
	area_entered.connect(_on_area_entered)
	# Enforce value clamping on ready
	if operation == OperationType.ADD:
		value = clamp(value, 1, 5)
	else:
		value = clamp(value, 2, 3)
		
	# Apply water calibration offset, pixel size, and scale
	var gate_sprite = get_node_or_null("Visuals/GateSprite") as Sprite3D
	if gate_sprite:
		gate_sprite.pixel_size = 0.0028
	if visuals:
		visuals.position.y = -0.13
	scale = Vector3(1.09, 1.09, 1.09)
		
	_clean_shadow_nodes(self)
	update_visuals()

func update_visuals() -> void:
	var gate_sprite = get_node_or_null("Visuals/GateSprite") as Sprite3D
	if gate_sprite:
		gate_sprite.modulate = Color(0.15, 0.75, 1.0, 0.8) # High-contrast cyan/blue holographic frame
		
	if label_3d:
		var display_value = value
		if not custom_text.is_empty():
			var clean_text = custom_text.replace(" Ships", "").replace(" Ship", "").replace(" ships", "").replace(" ship", "").strip_edges()
			var num = clean_text.to_int()
			if num != 0:
				display_value = abs(num)
			if num > 0 and not clean_text.begins_with("+"):
				clean_text = "+" + str(num)
			label_3d.text = clean_text
		else:
			label_3d.text = "+%d" % display_value
		label_3d.modulate = Color(1.0, 0.85, 0.1) # Bold golden numbers
		label_3d.outline_size = 16
		label_3d.outline_modulate = Color(0.0, 0.0, 0.0, 1.0)
		label_3d.font_size = 85

func _on_area_entered(area: Area3D) -> void:
	if not is_active:
		return
		
	var is_player = area.name == "CollisionArea" or area.is_in_group("player") or (area.get_parent() and area.get_parent().is_in_group("player"))
	if not is_player:
		return
		
	is_active = false
	AudioManager.play_sfx("gate_passes")
	
	# Determine value to add (fallback to custom_text parsing)
	var final_value = value
	if not custom_text.is_empty():
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
		
	if player_node and player_node.has_method("add_follower_ships"):
		player_node.add_follower_ships(final_value)
		
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
		
	tween.chain().tween_callback(queue_free)

func _clean_shadow_nodes(node: Node) -> void:
	if not node:
		return
	var lower_name = node.name.to_lower()
	var is_shadow_node = false
	if "shadow" in lower_name or "decal" in lower_name or "projector" in lower_name or "card" in lower_name or "oblate" in lower_name or "sphere" in lower_name:
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
