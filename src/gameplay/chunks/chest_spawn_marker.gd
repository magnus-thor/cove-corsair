class_name ChestSpawnMarker
extends Marker3D

## Alternative spawn marker placing reward chests in tight hazard pockets
## for mid/late campaign chunks (e.g. behind outer mine gates or barricade flanks).

@export var chest_scene: PackedScene = preload("res://src/gameplay/collectibles/collectible_chest.tscn")
@export var chest_value: int = 15
@export var min_level: int = 5
@export var spawn_chance: float = 1.0

static var _last_run_level: int = -1
static var _run_chests_spawned: int = 0

var _has_spawned: bool = false

func _ready() -> void:
	add_to_group("chest_spawn_markers")

func activate() -> void:
	spawn()

func spawn() -> void:
	if _has_spawned:
		return
		
	var cur_lvl = 1
	if GameState and "current_level" in GameState:
		cur_lvl = GameState.current_level
		
	if _last_run_level != cur_lvl:
		_last_run_level = cur_lvl
		_run_chests_spawned = 0
		
	# In Early Levels (1-5), chests stay in the open center lane after barricades
	# In Mid/Late Levels (>= min_level), tight hazard pocket chests activate
	if cur_lvl < min_level:
		return
		
	# Economy guard: Cap hazard pocket chests at 1 per level run to prevent loot runaway
	if _run_chests_spawned >= 1:
		return
		
	if spawn_chance < 1.0 and randf() > spawn_chance:
		return
		
	if not chest_scene:
		return
		
	_has_spawned = true
	_run_chests_spawned += 1
	var chest = chest_scene.instantiate() as Area3D
	if not chest:
		return
		
	if "chest_value" in chest:
		chest.chest_value = chest_value
		
	var parent = get_parent()
	if parent:
		parent.add_child(chest)
		chest.position = position
	else:
		get_tree().current_scene.add_child(chest)
		chest.global_position = global_position
		
	process_mode = Node.PROCESS_MODE_DISABLED
