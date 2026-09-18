class_name ChunkWagerFork
extends BaseTrackChunk

## 3-Lane Split Checkpoint Chunk for Corsair Gauntlet Endless Mode.
## Spans 60m along the river corridor.
## - Left Lane (-3.2m): Safe harbor gate (Bank & Retire).
## - Right Lane (+3.2m): Corsair's Gamble (+0.5x Multiplier & Speed Boost).
## - Center Lane (0.0m): Blocked by rock outcroppings forcing a choice.

signal choice_selected(choice_name: String)

@onready var bank_trigger_area: Area3D = get_node_or_null("BankTriggerArea") as Area3D
@onready var push_trigger_area: Area3D = get_node_or_null("PushTriggerArea") as Area3D

var _choice_made: bool = false

func _ready() -> void:
	chunk_id = "wager_fork"
	# Override CHUNK_LENGTH with 60.0m
	super._ready()
	if chunk_end:
		chunk_end.position = Vector3(0.0, 0.0, -60.0)
		
	_setup_triggers()

func _setup_triggers() -> void:
	if bank_trigger_area:
		bank_trigger_area.area_entered.connect(_on_bank_area_entered)
		bank_trigger_area.body_entered.connect(_on_bank_body_entered)
		
	if push_trigger_area:
		push_trigger_area.area_entered.connect(_on_push_area_entered)
		push_trigger_area.body_entered.connect(_on_push_body_entered)

func _is_player(node: Node) -> bool:
	if not node:
		return false
	if node.is_in_group("player"):
		return true
	var parent: Node = node.get_parent()
	if parent and parent.is_in_group("player"):
		return true
	return false

func _on_bank_area_entered(area: Area3D) -> void:
	if _choice_made:
		return
	if _is_player(area):
		_trigger_bank()

func _on_bank_body_entered(body: Node3D) -> void:
	if _choice_made:
		return
	if _is_player(body):
		_trigger_bank()

func _on_push_area_entered(area: Area3D) -> void:
	if _choice_made:
		return
	if _is_player(area):
		_trigger_push()

func _on_push_body_entered(body: Node3D) -> void:
	if _choice_made:
		return
	if _is_player(body):
		_trigger_push()

func _trigger_bank() -> void:
	if _choice_made:
		return
	_choice_made = true
	choice_selected.emit("bank")
	print("[WAGER FORK] Player chose LEFT LANE: Bank & Retire!")
	
	var endless_mode: Node = get_tree().get_first_node_in_group("endless_mode")
	if endless_mode and endless_mode.has_method("bank_and_exit"):
		endless_mode.call("bank_and_exit")
	else:
		var parent_mode: Node = find_parent("EndlessMode")
		if parent_mode and parent_mode.has_method("bank_and_exit"):
			parent_mode.call("bank_and_exit")

func _trigger_push() -> void:
	if _choice_made:
		return
	_choice_made = true
	choice_selected.emit("push")
	print("[WAGER FORK] Player chose RIGHT LANE: Corsair's Gamble (+0.5x Multiplier)!")
	
	var endless_mode: Node = get_tree().get_first_node_in_group("endless_mode")
	if endless_mode and endless_mode.has_method("push_luck"):
		endless_mode.call("push_luck")
	else:
		var parent_mode: Node = find_parent("EndlessMode")
		if parent_mode and parent_mode.has_method("push_luck"):
			parent_mode.call("push_luck")

func get_end_z() -> float:
	if chunk_end:
		return chunk_end.global_position.z
	return global_position.z - 60.0
