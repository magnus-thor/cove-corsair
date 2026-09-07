@tool
extends SceneTree

## Automated Campaign Level Generator for Cove Corsair
## Generates level_13.tres to level_45.tres with calibrated difficulty,
## tactical bottlenecks, biome styling, and milestone boss encounters.

const WARMUP_CHUNK_PATH: String = "res://src/gameplay/chunks/chunk_warmup.tscn"
const MINE_CHUNK_PATH: String = "res://src/gameplay/chunks/chunk_mine_gauntlet.tscn"
const BARRICADE_CHUNK_PATH: String = "res://src/gameplay/chunks/chunk_barricade_siege.tscn"

const BOSS_CHUNKS: Dictionary = {
	"bonebeard": "res://src/gameplay/chunks/chunk_boss_bonebeard.tscn",
	"siege_fortress": "res://src/gameplay/chunks/chunk_boss_siege_fortress.tscn",
	"phantom_dredge": "res://src/gameplay/chunks/chunk_boss_phantom_dredge.tscn",
	"ironjaw": "res://src/gameplay/chunks/chunk_boss_ironjaw.tscn"
}

const HORIZON_PATH: String = "res://assets/textures/horizon_smugglers_run.png"
const OUTPUT_DIR: String = "res://src/data/resources/levels/"

const LEVEL_TITLES: Dictionary = {
	13: "Coral Labyrinth",
	14: "Siren's Shoals",
	15: "Bone-Beard's Outpost",
	16: "The Iron Wall",
	17: "Murkwater Run",
	18: "Witch's Channel",
	19: "Devil's Slalom",
	20: "Citadel of Iron",
	21: "Serpent's Nest",
	22: "Gloom Mire",
	23: "Rotwood Reach",
	24: "Blackwater Hollow",
	25: "Phantom Trench",
	26: "Stagnant Cut",
	27: "Banshee Bog",
	28: "Dead Man's Bayou",
	29: "Voodoo Crossing",
	30: "Bone-Beard's Armada",
	31: "Cinder Rapids",
	32: "Magma Surge",
	33: "Ashfall Gorge",
	34: "Obsidian Strait",
	35: "Ironjaw's Crucible",
	36: "Pyroclast Pass",
	37: "Hellmouth Trench",
	38: "Boiling Reach",
	39: "Sulfur Chasm",
	40: "Molten Bulwark",
	41: "Inferno Gate",
	42: "Doomspire Channel",
	43: "Abyssal Rift",
	44: "Dreadflame Basin",
	45: "Bone-Beard's Throne"
}

func _init() -> void:
	print("==================================================")
	print("   STARTING CAMPAIGN LEVEL GENERATOR (L13-L45)    ")
	print("==================================================")
	
	var success = generate_all_levels()
	if success:
		print("==================================================")
		print("   CAMPAIGN GENERATION COMPLETED SUCCESSFULLY!    ")
		print("==================================================")
		quit(0)
	else:
		printerr("Campaign generation failed!")
		quit(1)

func generate_all_levels() -> bool:
	var warmup_scene = load(WARMUP_CHUNK_PATH) as PackedScene
	var mine_scene = load(MINE_CHUNK_PATH) as PackedScene
	var barricade_scene = load(BARRICADE_CHUNK_PATH) as PackedScene
	var horizon_tex = load(HORIZON_PATH) as Texture2D
	
	var boss_scenes: Dictionary = {}
	for b_id in BOSS_CHUNKS:
		boss_scenes[b_id] = load(BOSS_CHUNKS[b_id]) as PackedScene
		if not boss_scenes[b_id]:
			printerr("Failed to load boss scene: %s" % BOSS_CHUNKS[b_id])
			return false
	
	for lvl in range(13, 46):
		var data = LevelData.new()
		data.level_id = lvl
		data.horizon_texture = horizon_tex
		data.river_width_world = 12.0
		
		var title_name = LEVEL_TITLES.get(lvl, "Expedition %d" % lvl)
		data.level_title = "Level %d: %s" % [lvl, title_name]
		
		var chunk_count: int = 6
		var boss_key: String = ""
		
		if lvl <= 15:
			# Cove 1 (L13-L15): Tropical, speed 9.0 to 9.5, 6-7 chunks. L15 Boss: Bone-Beard.
			data.biome_name = "tropical"
			var t = float(lvl - 13) / 2.0
			data.base_scroll_speed = snappedf(lerpf(9.0, 9.5, t), 0.05)
			data.completion_doubloon_reward = int(round(lerpf(400.0, 450.0, t) / 25.0) * 25.0)
			data.water_albedo = Color(0.08, 0.58, 0.82, 0.88)
			data.fog_color = Color(0.48, 0.76, 0.94, 1.0)
			data.fog_density = 0.0
			
			chunk_count = 7 if lvl == 15 else 6
			if lvl == 15:
				boss_key = "bonebeard"
				
		elif lvl <= 30:
			# Cove 2 (L16-L30): Bayou, speed 9.5 to 11.5, 7-9 chunks. Completion 500-750.
			data.biome_name = "bayou"
			var t = float(lvl - 16) / 14.0
			data.base_scroll_speed = snappedf(lerpf(9.5, 11.5, t), 0.05)
			data.completion_doubloon_reward = int(round(lerpf(500.0, 750.0, t) / 25.0) * 25.0)
			data.water_albedo = Color(0.12, 0.25, 0.18, 0.92)
			data.fog_color = Color(0.22, 0.35, 0.28, 1.0)
			data.fog_density = 0.015
			
			if lvl in [16, 17]:
				chunk_count = 7
			elif lvl in [18, 19, 20, 21, 22, 23, 25]:
				chunk_count = 8
			else:
				chunk_count = 9
				
			if lvl == 20:
				boss_key = "siege_fortress"
			elif lvl == 25:
				boss_key = "phantom_dredge"
			elif lvl == 30:
				boss_key = "bonebeard"
				
		else:
			# Cove 3 (L31-L45): Brimstone, speed 11.5 to 13.0, 9-11 chunks. Completion 800-1200.
			data.biome_name = "brimstone"
			var t = float(lvl - 31) / 14.0
			data.base_scroll_speed = snappedf(lerpf(11.5, 13.0, t), 0.05)
			data.completion_doubloon_reward = int(round(lerpf(800.0, 1200.0, t) / 50.0) * 50.0)
			data.water_albedo = Color(0.35, 0.1, 0.08, 0.95)
			data.fog_color = Color(0.45, 0.18, 0.12, 1.0)
			data.fog_density = 0.02
			
			if lvl in [31, 32]:
				chunk_count = 9
			elif lvl in [33, 34, 35, 36, 37, 38]:
				chunk_count = 10
			else:
				chunk_count = 11
				
			if lvl == 35:
				boss_key = "ironjaw"
			elif lvl == 40:
				boss_key = "siege_fortress"
			elif lvl == 45:
				boss_key = "bonebeard"
		
		# Build Chunk Sequence
		var chunks: Array[PackedScene] = []
		
		# Chunk 0: Always warmup
		chunks.append(warmup_scene)
		
		var middle_count = chunk_count - 2
		
		if lvl == 16:
			# Tactical Bottleneck L16: "The Iron Wall" (heavy barricade clusters testing Ironclad/Bombard)
			for i in range(middle_count):
				if i == 2:
					chunks.append(mine_scene)
				else:
					chunks.append(barricade_scene)
		elif lvl == 19:
			# Tactical Bottleneck L19: "Devil's Slalom" (dense mine gauntlet testing Dinghy agility)
			for i in range(middle_count):
				if i == 3:
					chunks.append(barricade_scene)
				else:
					chunks.append(mine_scene)
		else:
			# Pacing Ruleset: Weighted alternation between mine gauntlet and barricade siege
			var bias_mines = (lvl % 2 == 1)
			for i in range(middle_count):
				if bias_mines:
					chunks.append(mine_scene if (i % 3 != 1) else barricade_scene)
				else:
					chunks.append(barricade_scene if (i % 3 != 1) else mine_scene)
		
		# Final Chunk: Boss chunk on milestones (every 5 levels), or intense siege chunk
		if boss_key != "":
			chunks.append(boss_scenes[boss_key])
		else:
			chunks.append(barricade_scene)
			
		data.chunk_scenes = chunks
		
		var file_path = OUTPUT_DIR + "level_%02d.tres" % lvl
		var err = ResourceSaver.save(data, file_path)
		if err != OK:
			printerr("Failed to save %s (error %d)" % [file_path, err])
			return false
		print("[SAVED] %s: %s (%s, %d chunks, speed %.2f, %d coins, boss: %s)" % [
			file_path, data.level_title, data.biome_name, data.chunk_scenes.size(),
			data.base_scroll_speed, data.completion_doubloon_reward,
			boss_key if boss_key != "" else "none"
		])
		
	return true
