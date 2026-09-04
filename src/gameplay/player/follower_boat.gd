extends Area3D

var target_offset: Vector3 = Vector3.ZERO
var lerp_speed: float = 14.0
var rotation_lerp_speed: float = 12.0
var weapon_instance: Node3D = null

func _ready() -> void:
	_clean_shadow_nodes(self)
	add_to_group("follower")
	add_to_group("player")
	
	area_entered.connect(_on_area_entered)
	
	# Match visual sprite and collision shape to player's active vessel
	var player = get_tree().get_first_node_in_group("player")
	var sf: float = 1.0
	if player and player.has_method("get_fleet_scale_factor"):
		sf = player.get_fleet_scale_factor(player.follower_boats.size() + 1)
		
	if player and "ship_data" in player and player.ship_data:
		var sprite = get_node_or_null("Sprite3D") as Sprite3D
		if sprite and player.ship_data.sprite_texture:
			sprite.texture = player.ship_data.sprite_texture
			sprite.pixel_size = player.ship_data.pixel_size
			var pitch = player.player_pitch_deg if "player_pitch_deg" in player else -60.0
			var rot = player.ship_data.rotation_degrees if ("rotation_degrees" in player.ship_data and player.ship_data.rotation_degrees != Vector3.ZERO) else Vector3(pitch, 0, 0)
			sprite.rotation_degrees = rot
			sprite.position = Vector3(0, player.ship_data.y_offset if "y_offset" in player.ship_data else 0.485, 0)
			var base_sc = player.ship_data.scale if ("scale" in player.ship_data and player.ship_data.scale != Vector3.ZERO) else Vector3.ONE
			sprite.scale = base_sc * sf
			
		var col = get_node_or_null("CollisionShape3D") as CollisionShape3D
		if col and col.shape is BoxShape3D:
			col.shape.size = player.ship_data.collision_size
			col.position = Vector3(0, player.ship_data.collision_size.y * 0.5, 0)
			col.scale = Vector3.ONE * sf
	else:
		var sprite = get_node_or_null("Sprite3D") as Sprite3D
		if sprite:
			sprite.scale = Vector3.ONE * sf
	
	# Instantiate BowMount weapon
	var attached_weapon_scene = load("res://src/gameplay/player/attached_weapon.tscn")
	if attached_weapon_scene:
		var weapon_data = load("res://src/data/resources/user_crew/weapon_bow_chaser.tres")
		if weapon_data:
			weapon_instance = attached_weapon_scene.instantiate()
			if weapon_instance.has_method("setup_weapon"):
				weapon_instance.setup_weapon(weapon_data)
			else:
				weapon_instance.weapon_data = weapon_data
			$BowMount.add_child(weapon_instance)
			$BowMount.scale = Vector3.ONE * sf

func set_target_offset(offset: Vector3) -> void:
	target_offset = offset

func tween_scale(target_sf: float, duration: float) -> void:
	var sprite = get_node_or_null("Sprite3D") as Sprite3D
	if sprite:
		var t = create_tween().set_parallel(true)
		t.tween_property(sprite, "scale", Vector3.ONE * target_sf, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var col = get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col:
		var t_col = create_tween()
		t_col.tween_property(col, "scale", Vector3.ONE * target_sf, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var bow = get_node_or_null("BowMount")
	if bow:
		var t_bow = create_tween()
		t_bow.tween_property(bow, "scale", Vector3.ONE * target_sf, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _physics_process(delta: float) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player or not is_instance_valid(player):
		return
		
	if player.is_game_over:
		return
		
	# Mirror movement with tight lerp delay
	var target_pos = player.global_position + player.global_transform.basis * target_offset
	target_pos.x = clampf(target_pos.x, -5.0, 5.0)
	global_position = global_position.lerp(target_pos, lerp_speed * delta)
	global_position.x = clampf(global_position.x, -5.0, 5.0)
	
	# Match rotation
	global_transform.basis = global_transform.basis.slerp(player.global_transform.basis, rotation_lerp_speed * delta)
	
	# Auto-fires in sync with the fleet
	if player.is_shooting_enabled and is_instance_valid(weapon_instance) and weapon_instance.has_method("try_fire"):
		weapon_instance.try_fire(delta * player.fire_rate_multiplier)

func _on_area_entered(area: Area3D) -> void:
	if area.is_in_group("collectibles") or area.is_in_group("cannonballs") or area.is_in_group("multiplier_gate") or area.is_in_group("player") or area.is_in_group("follower"):
		return
		
	if area.is_in_group("destructible") or area.is_in_group("enemies") or area.is_in_group("boss"):
		AudioManager.play_sfx("barrel_breaks")
		if area.is_in_group("boss") or (area.get_parent() and area.get_parent().is_in_group("boss")):
			if area.has_method("take_damage"):
				area.take_damage(10)
		elif area.has_method("take_damage"):
			area.take_damage(10)
		elif area.has_method("die"):
			area.die()
		else:
			area.queue_free()
		
		destroy_follower()


func destroy_follower() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("remove_follower"):
		player.remove_follower(self)
	queue_free()

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
