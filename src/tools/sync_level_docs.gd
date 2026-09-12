@tool
extends SceneTree

## Headless GDScript tool for synchronizing level markdown documents
## with Godot .tres resource files.
##
## Usage:
##   godot --headless --script src/tools/sync_level_docs.gd

const DOCS_DIR: String = "res://documents/levels/"
const RESOURCES_DIR: String = "res://src/data/resources/levels/"

const ALIAS_MAP: Dictionary = {
	1: "level_01_smugglers_run.tres",
	2: "level_02_black_tide_bayou.tres",
	3: "level_03_brimstone_bastion.tres",
	4: "level_04_smugglers_nightmare.tres",
	5: "level_05_black_tide_abyss.tres",
	6: "level_06_brimstone_inferno.tres",
}

func _init() -> void:
	print("==================================================")
	print("  GDSCRIPT LEVEL DOCUMENT SYNCHRONIZER           ")
	print("==================================================")
	var count: int = sync_all()
	print("==================================================")
	print("  SYNCHRONIZATION COMPLETED (%d LEVELS CHECKED)  " % count)
	print("==================================================")
	quit(0)

func sync_all() -> int:
	var dir = DirAccess.open(DOCS_DIR)
	if not dir:
		printerr("Cannot open directory: %s" % DOCS_DIR)
		return 0

	var files: Array[String] = []
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.begins_with("level_") and file_name.ends_with(".md"):
			files.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	files.sort()

	var processed := 0
	for fn in files:
		var full_path = DOCS_DIR + fn
		var frontmatter = parse_frontmatter(full_path)
		if not frontmatter.has("level_id"):
			continue

		var lvl_id: int = int(frontmatter["level_id"])
		var main_tres = RESOURCES_DIR + "level_%02d.tres" % lvl_id
		apply_params_to_tres(main_tres, frontmatter)

		if ALIAS_MAP.has(lvl_id):
			var alias_tres = RESOURCES_DIR + ALIAS_MAP[lvl_id]
			if FileAccess.file_exists(alias_tres):
				apply_params_to_tres(alias_tres, frontmatter)

		processed += 1

	return processed

func parse_frontmatter(md_path: String) -> Dictionary:
	var f = FileAccess.open(md_path, FileAccess.READ)
	if not f:
		return {}

	var text = f.get_as_text()
	f.close()

	var reg = RegEx.new()
	reg.compile("^---\\s*\\n([\\s\\S]*?)\\n---\\s*\\n")
	var result = reg.search(text)
	if not result:
		return {}

	var block = result.get_string(1)
	var data := {}
	var lines = block.split("\n")
	for line in lines:
		var trimmed = line.strip_edges()
		if trimmed == "" or trimmed.begins_with("#"):
			continue
		var idx = trimmed.find(":")
		if idx != -1:
			var key = trimmed.substr(0, idx).strip_edges()
			var val = trimmed.substr(idx + 1).strip_edges().trim_prefix('"').trim_suffix('"').trim_prefix("'").trim_suffix("'")
			if val.is_valid_int():
				data[key] = int(val)
			elif val.is_valid_float():
				data[key] = float(val)
			else:
				data[key] = val

	return data

func apply_params_to_tres(tres_path: String, params: Dictionary) -> void:
	if not FileAccess.file_exists(tres_path):
		return

	var res = ResourceLoader.load(tres_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if not res or not (res is LevelData):
		return

	var ldata = res as LevelData
	var modified := false

	if params.has("level_title") and ldata.level_title != str(params["level_title"]):
		ldata.level_title = str(params["level_title"])
		modified = true
	if params.has("biome_name") and ldata.biome_name != str(params["biome_name"]):
		ldata.biome_name = str(params["biome_name"])
		modified = true
	if params.has("base_scroll_speed") and not is_equal_approx(ldata.base_scroll_speed, float(params["base_scroll_speed"])):
		ldata.base_scroll_speed = float(params["base_scroll_speed"])
		modified = true
	if params.has("completion_doubloon_reward") and ldata.completion_doubloon_reward != int(params["completion_doubloon_reward"]):
		ldata.completion_doubloon_reward = int(params["completion_doubloon_reward"])
		modified = true
	if params.has("river_width_world") and not is_equal_approx(ldata.river_width_world, float(params["river_width_world"])):
		ldata.river_width_world = float(params["river_width_world"])
		modified = true

	if modified:
		ResourceSaver.save(ldata, tres_path)
		print("  [UPDATED] %s (reward: %d, speed: %.2f)" % [tres_path, ldata.completion_doubloon_reward, ldata.base_scroll_speed])
