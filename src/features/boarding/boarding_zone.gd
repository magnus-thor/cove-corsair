@tool
class_name BoardingZone
extends Area3D

## Sector on the player ship deck that tracks enemy boarder occupancy,
## grapple rope attachments, and infestation accumulation/recovery.

signal zone_overrun(zone_id: String)
signal zone_cleared(zone_id: String)
signal infestation_changed(zone_id: String, current_pct: float)

@export var zone_id: String = "midship" # "bow", "midship", "stern"
@export var grapple_anchor: Marker3D = null
@export var plank_anchor: Marker3D = null
@export var station_marker: Marker3D = null
@export var max_infestation: float = 100.0
@export var infestation_per_enemy_per_sec: float = 4.0
@export var recovery_per_sec: float = 6.0

var current_infestation: float = 0.0
var active_boarders: Array[Node3D] = []
var active_grapples: Array[Node3D] = []
var active_planks: Array[Node3D] = []
var is_overrun: bool = false

func _ready() -> void:
	if not is_instance_valid(plank_anchor) and is_instance_valid(grapple_anchor):
		plank_anchor = grapple_anchor
	if Engine.is_editor_hint():
		return
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_clean_invalid_entries()
	
	var total_infest_weight: float = 0.0
	for b: Node3D in active_boarders:
		if is_instance_valid(b):
			var w_val: Variant = b.get("infestation_weight")
			if w_val != null:
				total_infest_weight += float(w_val)
			else:
				total_infest_weight += 1.0

	if total_infest_weight > 0.0:
		var delta_infest: float = total_infest_weight * infestation_per_enemy_per_sec * delta
		current_infestation = minf(current_infestation + delta_infest, max_infestation)
	elif current_infestation > 0.0:
		current_infestation = maxf(current_infestation - (recovery_per_sec * delta), 0.0)
	
	var pct: float = current_infestation / max_infestation if max_infestation > 0.0 else 0.0
	infestation_changed.emit(zone_id, pct)
	
	if current_infestation >= max_infestation and not is_overrun:
		is_overrun = true
		zone_overrun.emit(zone_id)
	elif current_infestation <= 0.0 and is_overrun:
		is_overrun = false
		zone_cleared.emit(zone_id)

func register_plank(plank: Node3D) -> void:
	if is_instance_valid(plank) and not active_planks.has(plank):
		active_planks.append(plank)
	if is_instance_valid(plank) and not active_grapples.has(plank):
		active_grapples.append(plank)

func unregister_plank(plank: Node3D) -> void:
	if active_planks.has(plank):
		active_planks.erase(plank)
	if active_grapples.has(plank):
		active_grapples.erase(plank)

func register_grapple(rope: Node3D) -> void:
	register_plank(rope)

func unregister_grapple(rope: Node3D) -> void:
	unregister_plank(rope)

func register_boarder(boarder: Node3D) -> void:
	if is_instance_valid(boarder) and not active_boarders.has(boarder):
		active_boarders.append(boarder)

func unregister_boarder(boarder: Node3D) -> void:
	if active_boarders.has(boarder):
		active_boarders.erase(boarder)

func force_set_infestation(val: float) -> void:
	current_infestation = clampf(val, 0.0, max_infestation)
	var pct: float = current_infestation / max_infestation if max_infestation > 0.0 else 0.0
	infestation_changed.emit(zone_id, pct)
	if current_infestation >= max_infestation and not is_overrun:
		is_overrun = true
		zone_overrun.emit(zone_id)
	elif current_infestation <= 0.0 and is_overrun:
		is_overrun = false
		zone_cleared.emit(zone_id)

func _clean_invalid_entries() -> void:
	var valid_boarders: Array[Node3D] = []
	for b: Node3D in active_boarders:
		if is_instance_valid(b) and not b.is_queued_for_deletion():
			valid_boarders.append(b)
	active_boarders = valid_boarders
	
	var valid_grapples: Array[Node3D] = []
	for g: Node3D in active_grapples:
		if is_instance_valid(g) and not g.is_queued_for_deletion():
			valid_grapples.append(g)
	active_grapples = valid_grapples

func _on_body_entered(body: Node3D) -> void:
	if is_instance_valid(body) and body.is_in_group("boarder") and not active_boarders.has(body):
		active_boarders.append(body)

func _on_body_exited(body: Node3D) -> void:
	if active_boarders.has(body):
		active_boarders.erase(body)
