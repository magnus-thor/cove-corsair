class_name BossComponentDelegate
extends Area3D

@export var boss_node: Node3D
@export var component_name: String = ""

# Keep track of projectile information for weak-point logic
var last_hit_from_bow: bool = false

func _ready() -> void:
	add_to_group("destructible")
	area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area3D) -> void:
	if area.is_in_group("cannonballs"):
		last_hit_from_bow = area.has_meta("from_bow")

func take_damage(amount: int) -> void:
	if boss_node and boss_node.has_method("damage_component"):
		boss_node.damage_component(component_name, amount, last_hit_from_bow)
