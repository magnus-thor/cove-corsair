class_name CrewData
extends WeaponData

## Crew Member Data Class
## Defines autonomous deck crew members that track targets, animate throws,
## and throw specialized ammo (bombs, coconuts, fire) with compatible ammo types.

@export_group("Crew Specialization")
@export var crew_role: String = "bomber" # "bomber", "sniper", "tosser"
@export var targeting_priority: String = "nearest" # "nearest", "highest_threat", "boss_focus"
@export var detection_range: float = 20.0
@export var max_throw_range: float = 20.0
@export var throw_arc_height: float = 0.5

func is_crew_member() -> bool:
	return true

func get_effective_max_range() -> float:
	if max_throw_range > 0.0:
		return max_throw_range
	return max_range

func get_effective_arc_height() -> float:
	if throw_arc_height > 0.0:
		return throw_arc_height
	return arc_height
