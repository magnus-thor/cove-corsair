class_name ChunkFinishLine
extends BaseTrackChunk

@export_enum("tropical", "bayou", "brimstone") var theme_name: String = "tropical"
@export var custom_chunk_id: String = ""
@export var doubloon_scene: PackedScene = preload("res://src/gameplay/collectibles/collectible_doubloon.tscn")
@export var explosion_scene: PackedScene = preload("res://src/vfx/barrel_explosion.tscn")

@onready var finish_trigger: Area3D = get_node_or_null("FinishTrigger")

var _is_finished: bool = false

const ENEMY_MOB_SCENE: PackedScene = preload("res://src/gameplay/enemies/enemy_mob.tscn")
const BARREL_SCENE: PackedScene = preload("res://src/gameplay/obstacles/destructible_barrel.tscn")
const ROWER_DATA: Resource = preload("res://src/data/resources/enemy_vessels/skeleton_rower.tres")

func _ready() -> void:
	super._ready()
	if not custom_chunk_id.is_empty():
		chunk_id = custom_chunk_id
	elif theme_name == "bayou":
		chunk_id = "finish_line_bayou"
	elif theme_name == "brimstone":
		chunk_id = "finish_line_brimstone"
	else:
		chunk_id = "finish_line"

	if finish_trigger:
		if not finish_trigger.area_entered.is_connected(_on_finish_area_entered):
			finish_trigger.area_entered.connect(_on_finish_area_entered)
		if not finish_trigger.body_entered.is_connected(_on_finish_body_entered):
			finish_trigger.body_entered.connect(_on_finish_body_entered)
	_spawn_finish_wave()

func _spawn_finish_wave() -> void:
	var entities: Node = get_node_or_null("Entities")
	if not entities:
		return
	var lanes: Array[float] = [-1.8, -0.6, 0.6, 1.8]
	var guard_hp: int = 2
	var guard_speed: float = 1.2
	if theme_name == "bayou":
		guard_hp = 4
		guard_speed = 1.4
	elif theme_name == "brimstone":
		guard_hp = 5
		guard_speed = 1.5

	for lx: float in lanes:
		var mob: Area3D = ENEMY_MOB_SCENE.instantiate() as Area3D
		entities.add_child(mob)
		mob.position = Vector3(lx, 0.1, -10.0)
		if mob.has_method("apply_enemy_data"):
			mob.call("apply_enemy_data", ROWER_DATA)
		mob.set("max_hp", guard_hp)
		mob.set("current_hp", guard_hp)
		mob.set("forward_speed", guard_speed)
		mob.set("doubloons_drop", 1)

func _on_finish_area_entered(area: Area3D) -> void:
	if _is_finished:
		return
	if area.is_in_group("player") or (area.get_parent() and area.get_parent().is_in_group("player")):
		_trigger_victory()

func _on_finish_body_entered(body: Node3D) -> void:
	if _is_finished:
		return
	if body.is_in_group("player") or (body.get_parent() and body.get_parent().is_in_group("player")):
		_trigger_victory()

func _trigger_victory() -> void:
	if _is_finished:
		return
	_is_finished = true
	
	if AudioManager:
		AudioManager.play_sfx("gate_passes")
		if theme_name == "brimstone":
			AudioManager.play_sfx("sfx_mine_detonate")
		elif theme_name == "bayou":
			AudioManager.play_sfx("water_splashes")
		else:
			AudioManager.play_sfx("barrel_breaks")
		
	_spawn_celebration_effects()
	
	# Smoothly decelerate scrolling as vessel sails into the harbor
	var assembler := get_tree().get_first_node_in_group("chunk_assembler") as ChunkAssembler
	var track_mgr := get_tree().get_first_node_in_group("track_manager") as Node3D
	var tween: Tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if assembler and "scroll_speed" in assembler:
		tween.tween_property(assembler, "scroll_speed", 0.0, 1.2)
	if track_mgr and "scroll_speed" in track_mgr:
		tween.tween_property(track_mgr, "scroll_speed", 0.0, 1.2)
	
	# Small delay for fireworks before victory settlement
	get_tree().create_timer(1.2, true, false, true).timeout.connect(func() -> void:
		EventBus.level_completed.emit(GameState.doubloons, GameState.targets_destroyed)
	)

func _spawn_celebration_effects() -> void:
	var root: Node = get_tree().current_scene
	var spawn_parent: Node = root if root else self
	
	var burst_count: int = 12 if theme_name == "tropical" else (16 if theme_name == "bayou" else 20)
	var coin_count: int = 15 if theme_name == "tropical" else 18
	
	# Spawn coin fountain & firework bursts across the gate arch
	for i in range(burst_count):
		if explosion_scene:
			var vfx := explosion_scene.instantiate() as Node3D
			if vfx:
				spawn_parent.add_child(vfx)
				var spread_y: float = randf_range(2.0, 6.0) if theme_name != "brimstone" else randf_range(2.5, 7.5)
				var offset := Vector3(randf_range(-5.5, 5.5), spread_y, global_position.z - 34.0 + randf_range(-1.5, 1.5))
				vfx.global_position = offset
			
	if doubloon_scene:
		for d_i in range(coin_count):
			var d := doubloon_scene.instantiate() as CollectibleDoubloon
			if d:
				spawn_parent.add_child(d)
				d.global_position = Vector3(randf_range(-4.5, 4.5), 0.2, global_position.z - 34.0)
				d._trigger_spawn_bounce(Vector2(randf_range(-2.5, 2.5), randf_range(-2.5, 2.5)))
