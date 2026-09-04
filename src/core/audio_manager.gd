extends Node

## Dynamic AudioManager Autoload Singleton for Cove Corsair

static var instance: Node

var sfx_library: Dictionary = {
	"cannon_shots": [],
	"barrel_hits": [],
	"barrel_breaks": [],
	"gate_passes": [],
	"coin_pickups": [],
	"water_splashes": []
}

var sound_cooldowns: Dictionary = {
	"cannon_shots": 0.08,
	"cannon_fire": 0.08,
	"barrel_breaks": 0.12,
	"explosion": 0.12,
	"coin_pickups": 0.06,
	"coin_pickup": 0.06
}

var last_play_times: Dictionary = {}

var base_sfx_path: String = "res://assets/audio/sfx/"
var music_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
const POOL_SIZE: int = 24

var _sfx_pool_index: int = 0

func _init() -> void:
	if instance == null:
		instance = self

func _enter_tree() -> void:
	if instance == null:
		instance = self

func _ready() -> void:
	if instance == null:
		instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	_setup_music_player()
	_setup_sfx_pool()
	_scan_and_load_sfx()

func _setup_buses() -> void:
	if AudioServer.get_bus_index("BGM") == -1:
		AudioServer.add_bus()
		var bgm_idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bgm_idx, "BGM")
		AudioServer.set_bus_send(bgm_idx, "Master")
	if AudioServer.get_bus_index("SFX") == -1:
		AudioServer.add_bus()
		var sfx_idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(sfx_idx, "SFX")
		AudioServer.set_bus_send(sfx_idx, "Master")

func set_bus_volume(bus_name: String, linear_vol: float) -> void:
	var idx = AudioServer.get_bus_index(bus_name)
	if idx != -1:
		var clamped_vol = clamp(linear_vol, 0.0001, 1.0)
		var db_val = linear_to_db(clamped_vol) if linear_vol > 0.0001 else -80.0
		AudioServer.set_bus_volume_db(idx, db_val)

func get_bus_volume(bus_name: String) -> float:
	var idx = AudioServer.get_bus_index(bus_name)
	if idx != -1:
		var db_val = AudioServer.get_bus_volume_db(idx)
		if db_val <= -79.0:
			return 0.0
		return db_to_linear(db_val)
	return 1.0

func set_bus_muted(bus_name: String, muted: bool) -> void:
	var idx = AudioServer.get_bus_index(bus_name)
	if idx != -1:
		AudioServer.set_bus_mute(idx, muted)

func is_bus_muted(bus_name: String) -> bool:
	var idx = AudioServer.get_bus_index(bus_name)
	if idx != -1:
		return AudioServer.is_bus_mute(idx)
	return false

func _setup_music_player() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.name = "MusicPlayer"
	music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	
	var bgm_bus_idx = AudioServer.get_bus_index("BGM")
	music_player.bus = "BGM" if bgm_bus_idx != -1 else "Master"
	
	add_child(music_player)

func _setup_sfx_pool() -> void:
	var sfx_bus_idx = AudioServer.get_bus_index("SFX")
	var sfx_bus_name = "SFX" if sfx_bus_idx != -1 else "Master"
	
	sfx_players.clear()
	for i in range(POOL_SIZE):
		var player = AudioStreamPlayer.new()
		player.name = "SFXPlayer_%02d" % i
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		player.bus = sfx_bus_name
		add_child(player)
		sfx_players.append(player)

func _scan_and_load_sfx() -> void:
	var actual_base_path = base_sfx_path
	var summary_parts: Array[String] = []

	for category in sfx_library.keys():
		sfx_library[category] = []
		var category_dir_path = actual_base_path.path_join(category)
		
		if not DirAccess.dir_exists_absolute(category_dir_path):
			summary_parts.append("0 %s" % category)
			continue

		var dir = DirAccess.open(category_dir_path)
		if dir:
			dir.list_dir_begin()
			var file_name = dir.get_next()
			var loaded_paths: Dictionary = {}

			while file_name != "":
				if not dir.current_is_dir():
					var clean_name = file_name
					if clean_name.ends_with(".import"):
						clean_name = clean_name.trim_suffix(".import")
					elif clean_name.ends_with(".remap"):
						clean_name = clean_name.trim_suffix(".remap")

					var ext = clean_name.get_extension().to_lower()
					if ext in ["wav", "mp3", "ogg"]:
						var resource_path = category_dir_path.path_join(clean_name)
						if not loaded_paths.has(resource_path):
							loaded_paths[resource_path] = true
							if ResourceLoader.exists(resource_path):
								var stream = ResourceLoader.load(resource_path) as AudioStream
								if stream:
									sfx_library[category].append(stream)
				file_name = dir.get_next()
			dir.list_dir_end()

		summary_parts.append("%d %s" % [sfx_library[category].size(), category])

	print("AudioManager: Loaded " + ", ".join(summary_parts))

## Play a sound effect from the specified category with randomized pitch variation
func play_sfx(category: String, min_pitch: float = 0.93, max_pitch: float = 1.07, volume_db: float = 0.0) -> void:
	# Throttling and cooldown check (handle aliases)
	var check_category = category
	var actual_category = category
	if category == "cannon_fire":
		actual_category = "cannon_shots"
	elif category == "explosion":
		actual_category = "barrel_breaks"
	elif category == "coin_pickup":
		actual_category = "coin_pickups"
		
	var current_time = Time.get_ticks_msec() / 1000.0
	if sound_cooldowns.has(check_category):
		var cooldown = sound_cooldowns[check_category]
		var last_time = last_play_times.get(check_category, 0.0)
		if current_time - last_time < cooldown:
			return
		last_play_times[check_category] = current_time
	elif sound_cooldowns.has(actual_category):
		var cooldown = sound_cooldowns[actual_category]
		var last_time = last_play_times.get(actual_category, 0.0)
		if current_time - last_time < cooldown:
			return
		last_play_times[actual_category] = current_time

	if not sfx_library.has(actual_category):
		push_warning("AudioManager: Category '%s' does not exist in sfx_library." % actual_category)
		return

	var streams: Array = sfx_library[actual_category]
	if streams.is_empty():
		return

	var stream: AudioStream = streams.pick_random()
	if not stream:
		return

	# Lower volume of projectile impact SFX by 4dB
	var final_volume = volume_db
	if actual_category == "barrel_hits":
		final_volume -= 4.0

	var target_player: AudioStreamPlayer = null
	for player in sfx_players:
		if not player.playing:
			target_player = player
			break

	# If all players are active, steal using round-robin
	if target_player == null and not sfx_players.is_empty():
		target_player = sfx_players[_sfx_pool_index]
		_sfx_pool_index = (_sfx_pool_index + 1) % sfx_players.size()

	if target_player:
		target_player.stream = stream
		target_player.pitch_scale = randf_range(min_pitch, max_pitch)
		target_player.volume_db = final_volume
		target_player.play()

## Play background music stream
func play_music(music_path: String = "res://assets/audio/music/gameplay_theme.mp3", volume_db: float = 0.0) -> void:
	if not music_player:
		return

	if ResourceLoader.exists(music_path):
		var stream = ResourceLoader.load(music_path) as AudioStream
		if stream:
			if stream is AudioStreamMP3:
				stream.loop = true
			elif stream is AudioStreamOggVorbis:
				stream.loop = true
			elif stream is AudioStreamWAV:
				stream.loop_mode = AudioStreamWAV.LOOP_FORWARD

			music_player.stream = stream
			music_player.volume_db = volume_db
			music_player.play()
		else:
			push_warning("AudioManager: Failed to load music stream from %s" % music_path)
	else:
		push_warning("AudioManager: Music file not found at %s" % music_path)

## Stop background music
func stop_music() -> void:
	if music_player and music_player.playing:
		music_player.stop()
