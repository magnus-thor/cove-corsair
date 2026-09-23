class_name BoardingDefenseArena
extends Node3D

## Coordinates 3-zone deck defense encounters: wave cadence, grapple launches,
## swarm spawning, overrun hull penalties, and victory/defeat progression.

signal encounter_won()
signal encounter_lost()
signal zone_status_updated(zone_id: String, pct: float, is_overrun: bool)

@export var zone_bow: BoardingZone = null
@export var zone_midship: BoardingZone = null
@export var zone_stern: BoardingZone = null

@export var crew_station_bow: BoardingCrewStation = null
@export var crew_station_stern: BoardingCrewStation = null

@export var player_controller: DeckPlayerController = null

@export var enemy_ship_marker_bow: Marker3D = null
@export var enemy_ship_marker_mid: Marker3D = null
@export var enemy_ship_marker_stern: Marker3D = null

@export var hud: BoardingHUD = null

@export var rope_scene: PackedScene = preload("res://src/features/boarding/boarding_grapple_rope.tscn")
@export var boarder_scene: PackedScene = preload("res://src/features/boarding/boarder_enemy.tscn")

@export var overrun_damage_per_sec: float = 5.0
@export var total_waves_to_win: int = 3
@export var wave_interval_sec: float = 8.0

var zones: Array[BoardingZone] = []
var current_wave: int = 0
var wave_timer: float = 3.0 # Initial grace period
var is_encounter_active: bool = true
var total_ropes_launched: int = 0

func _ready() -> void:
	zones = [zone_bow, zone_midship, zone_stern]
	for zone: BoardingZone in zones:
		if is_instance_valid(zone):
			zone.add_to_group("boarding_zone")
			zone.zone_overrun.connect(_on_zone_overrun)
			zone.zone_cleared.connect(_on_zone_cleared)
			zone.infestation_changed.connect(_on_zone_infestation_changed)
			
	if is_instance_valid(hud):
		zone_status_updated.connect(hud.update_zone)
		encounter_won.connect(hud.show_victory)
		encounter_lost.connect(hud.show_defeat)
		hud.update_wave(1, total_waves_to_win)
			
	if is_instance_valid(player_controller):
		player_controller.station_markers = {
			"bow": zone_bow.station_marker if is_instance_valid(zone_bow) else null,
			"midship": zone_midship.station_marker if is_instance_valid(zone_midship) else null,
			"stern": zone_stern.station_marker if is_instance_valid(zone_stern) else null
		}
			
	_setup_crew_from_gamestate()

func _setup_crew_from_gamestate() -> void:
	var bow_crew_id: String = ""
	var aft_crew_id: String = ""
	
	if GameState:
		var active_ship: String = GameState.active_vessel
		bow_crew_id = GameState.get_equipped_crew(active_ship, "BowMount")
		if bow_crew_id.is_empty():
			bow_crew_id = GameState.get_equipped_crew(active_ship, "MidDeckCrew")
		aft_crew_id = GameState.get_equipped_crew(active_ship, "AftDeckCrew")
		
		if bow_crew_id.is_empty() and not GameState.unlocked_crew.is_empty():
			bow_crew_id = GameState.unlocked_crew.keys()[0] as String
		if aft_crew_id.is_empty() and not GameState.unlocked_crew.is_empty():
			var keys: Array = GameState.unlocked_crew.keys()
			aft_crew_id = keys[keys.size() - 1] as String
	
	# Default crew for standalone editor play
	if bow_crew_id.is_empty():
		bow_crew_id = "monkey_bomber"
	if aft_crew_id.is_empty():
		aft_crew_id = "skeleton_tosser"
	
	if is_instance_valid(crew_station_bow):
		crew_station_bow.setup_crew(bow_crew_id)
		
	if is_instance_valid(crew_station_stern):
		crew_station_stern.setup_crew(aft_crew_id)

func _process(delta: float) -> void:
	if not is_encounter_active:
		return
		
	_process_overrun_attrition(delta)
	_process_wave_director(delta)

func _process_overrun_attrition(delta: float) -> void:
	for zone: BoardingZone in zones:
		if is_instance_valid(zone) and zone.is_overrun:
			_damage_vessel_hull(overrun_damage_per_sec * delta)

func _process_wave_director(delta: float) -> void:
	wave_timer -= delta
	if wave_timer <= 0.0:
		if current_wave < total_waves_to_win:
			current_wave += 1
			_launch_wave(current_wave)
			wave_timer = wave_interval_sec
		else:
			# Check victory: all waves launched, no active ropes, no active boarders
			var ropes: Array[Node] = get_tree().get_nodes_in_group("grapple_rope")
			var boarders: Array[Node] = get_tree().get_nodes_in_group("boarder")
			if ropes.is_empty() and boarders.is_empty():
				_trigger_victory()

func _launch_wave(wave_num: int) -> void:
	if is_instance_valid(hud):
		hud.update_wave(wave_num, total_waves_to_win)
	match wave_num:
		1:
			launch_grapple_to_zone(1) # Midship
		2:
			launch_grapple_to_zone(0) # Bow
			launch_grapple_to_zone(2) # Stern
		3:
			launch_grapple_to_zone(0) # Bow
			launch_grapple_to_zone(1) # Midship
			launch_grapple_to_zone(2) # Stern

func launch_grapple_to_zone(zone_index: int) -> void:
	var idx: int = clampi(zone_index, 0, zones.size() - 1)
	var target_zone: BoardingZone = zones[idx]
	var start_marker: Marker3D = _get_spawn_marker(idx)
	
	if not is_instance_valid(rope_scene) or not is_instance_valid(start_marker) or not is_instance_valid(target_zone):
		return
		
	var rope: BoardingGrappleRope = rope_scene.instantiate() as BoardingGrappleRope
	add_child(rope)
	rope.setup_grapple(start_marker.global_position, target_zone.grapple_anchor.global_position, target_zone)
	total_ropes_launched += 1
	
	_spawn_rope_swarm(rope, target_zone, 3)

func _spawn_rope_swarm(rope: BoardingGrappleRope, zone: BoardingZone, count: int) -> void:
	for i: int in count:
		await get_tree().create_timer(i * 1.05).timeout
		if not is_instance_valid(rope) or not rope.is_latched:
			break
		if not is_instance_valid(boarder_scene):
			break
		var enemy: BoarderEnemy = boarder_scene.instantiate() as BoarderEnemy
		add_child(enemy)
		enemy.start_climbing(rope, zone)

func _damage_vessel_hull(amount: float) -> void:
	var player: PlayerSwerve = get_tree().get_first_node_in_group("player") as PlayerSwerve
	if is_instance_valid(player):
		player.take_hit(maxi(1, int(round(amount))), "boarding_overrun")
	elif GameState:
		GameState.record_hit()
		if EventBus and EventBus.has_signal("player_hit_taken"):
			EventBus.player_hit_taken.emit(maxi(1, int(round(amount))), 1, 4, "boarding_overrun", 0.0)

func _get_spawn_marker(zone_index: int) -> Marker3D:
	match zone_index:
		0: return enemy_ship_marker_bow
		1: return enemy_ship_marker_mid
		2: return enemy_ship_marker_stern
		_: return enemy_ship_marker_mid

func _on_zone_overrun(zone_id: String) -> void:
	zone_status_updated.emit(zone_id, 1.0, true)

func _on_zone_cleared(zone_id: String) -> void:
	zone_status_updated.emit(zone_id, 0.0, false)

func _on_zone_infestation_changed(zone_id: String, pct: float) -> void:
	zone_status_updated.emit(zone_id, pct, pct >= 1.0)

func _trigger_victory() -> void:
	is_encounter_active = false
	encounter_won.emit()

func _trigger_defeat() -> void:
	is_encounter_active = false
	encounter_lost.emit()
