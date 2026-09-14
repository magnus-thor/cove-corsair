class_name ChunkFinishLine
extends BaseTrackChunk

@export var doubloon_scene: PackedScene = preload("res://src/gameplay/collectibles/collectible_doubloon.tscn")
@export var explosion_scene: PackedScene = preload("res://src/gameplay/vfx/barrel_explosion.tscn")

@onready var finish_trigger: Area3D = get_node_or_null("FinishTrigger")

var _is_finished: bool = false

func _ready() -> void:
	super._ready()
	chunk_id = "finish_line"
	if finish_trigger:
		finish_trigger.area_entered.connect(_on_finish_area_entered)
		finish_trigger.body_entered.connect(_on_finish_body_entered)

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
	print("[FINISH LINE] Player crossed the Harbor Victory Gate! Level Complete!")
	
	if AudioManager:
		AudioManager.play_sfx("gate_passes")
		AudioManager.play_sfx("barrel_breaks")
		
	_spawn_celebration_effects()
	
	# Smoothly decelerate scrolling as vessel sails into the harbor
	var assembler = get_tree().get_first_node_in_group("chunk_assembler")
	var track_mgr = get_tree().get_first_node_in_group("track_manager")
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if assembler and "scroll_speed" in assembler:
		tween.tween_property(assembler, "scroll_speed", 0.0, 1.2)
	if track_mgr and "scroll_speed" in track_mgr:
		tween.tween_property(track_mgr, "scroll_speed", 0.0, 1.2)
	
	# Small delay for fireworks before victory settlement
	get_tree().create_timer(1.2, true, false, true).timeout.connect(func():
		GameState.level_completed.emit(GameState.doubloons, GameState.targets_destroyed)
	)

func _spawn_celebration_effects() -> void:
	var root = get_tree().current_scene
	var spawn_parent = root if root else self
	
	# Spawn coin fountain & firework bursts across the gate arch
	for i in range(12):
		if explosion_scene:
			var vfx = explosion_scene.instantiate() as Node3D
			spawn_parent.add_child(vfx)
			var offset = Vector3(randf_range(-5.0, 5.0), randf_range(2.0, 5.5), global_position.z - 34.0 + randf_range(-1.0, 1.0))
			vfx.global_position = offset
			
	if doubloon_scene:
		for d_i in range(15):
			var d = doubloon_scene.instantiate() as Area3D
			if d:
				spawn_parent.add_child(d)
				d.global_position = Vector3(randf_range(-4.0, 4.0), 0.2, global_position.z - 34.0)
				if d.has_method("_trigger_spawn_bounce"):
					d._trigger_spawn_bounce(Vector2(randf_range(-2.0, 2.0), randf_range(-2.0, 2.0)))
