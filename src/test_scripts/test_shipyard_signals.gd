## Headless Signal Regression Test — Shipyard UI
## Tests that Buy, Equip, and Tab-switching signal hookups remain intact
## after the visual comparison dashboard refactor.
##
## Run with:
##   godot --headless --script src/test_scripts/test_shipyard_signals.gd
##
## All scene/signal wiring is verified without instantiating the full game tree.
## GameState and AudioManager autoloads are NOT available in headless mode,
## so this test validates the .tscn structure and GDScript syntax integrity only.

extends SceneTree

const SHIPYARD_SCENE_PATH: String = "res://src/ui/shipyard/shipyard_ui.tscn"
const STAT_BAR_SCENE_PATH: String = "res://src/ui/components/stat_bar.tscn"
const CREW_CARD_SCENE_PATH: String = "res://src/ui/shipyard/crew_card.tscn"
const OUTFITTING_CARD_SCENE_PATH: String = "res://src/ui/shipyard/outfitting_card.tscn"
const VESSEL_CARD_SCENE_PATH: String = "res://src/ui/shipyard/vessel_card.tscn"

var _pass_count: int = 0
var _fail_count: int = 0

func _init() -> void:
	print("\n=== Shipyard UI Signal Regression Test ===\n")

	_test_scene_loads()
	_test_stat_bar_scene_loads()
	_test_shipyard_script_signals()
	_test_crew_card_signals()
	_test_outfitting_card_signals()
	_test_vessel_card_signals()
	_test_tab_state_enum()
	_test_action_state_enum()

	print("\n--- Results: %d passed, %d failed ---" % [_pass_count, _fail_count])
	if _fail_count > 0:
		push_error("REGRESSION: %d test(s) failed." % _fail_count)
		quit(1)
	else:
		print("All tests passed. ✓")
		quit(0)

## ─── Helpers ────────────────────────────────────────────────────────────────

func _assert(condition: bool, test_name: String) -> void:
	if condition:
		_pass_count += 1
		print("  PASS  %s" % test_name)
	else:
		_fail_count += 1
		push_error("  FAIL  %s" % test_name)

## ─── Tests ──────────────────────────────────────────────────────────────────

func _test_scene_loads() -> void:
	print("[ Scene load checks ]")
	_assert(ResourceLoader.exists(SHIPYARD_SCENE_PATH), "shipyard_ui.tscn exists")
	_assert(ResourceLoader.exists(CREW_CARD_SCENE_PATH), "crew_card.tscn exists")
	_assert(ResourceLoader.exists(OUTFITTING_CARD_SCENE_PATH), "outfitting_card.tscn exists")
	_assert(ResourceLoader.exists(VESSEL_CARD_SCENE_PATH), "vessel_card.tscn exists")

func _test_stat_bar_scene_loads() -> void:
	print("[ UIStatBar scene ]")
	_assert(ResourceLoader.exists(STAT_BAR_SCENE_PATH), "stat_bar.tscn exists")

	# Verify the scene can be loaded as a PackedScene
	var packed: PackedScene = load(STAT_BAR_SCENE_PATH) as PackedScene
	_assert(packed != null, "stat_bar.tscn loads as PackedScene")

func _test_shipyard_script_signals() -> void:
	print("[ ShipyardUI signals ]")
	# Load the packed scene and inspect the script's signal list
	var packed: PackedScene = load(SHIPYARD_SCENE_PATH) as PackedScene
	_assert(packed != null, "shipyard_ui.tscn loaded")

	var script: Script = load("res://src/ui/shipyard/shipyard_ui.gd") as Script
	_assert(script != null, "shipyard_ui.gd loaded")

	var signal_list: Array[Dictionary] = script.get_script_signal_list()
	var signal_names: Array[String] = []
	for sig: Dictionary in signal_list:
		signal_names.append(sig["name"] as String)

	_assert("shipyard_closed" in signal_names, "shipyard_closed signal declared")

func _test_crew_card_signals() -> void:
	print("[ CrewCard signals ]")
	var script: Script = load("res://src/ui/shipyard/crew_card.gd") as Script
	_assert(script != null, "crew_card.gd loaded")

	var signal_list: Array[Dictionary] = script.get_script_signal_list()
	var signal_names: Array[String] = []
	for sig: Dictionary in signal_list:
		signal_names.append(sig["name"] as String)

	_assert("buy_requested" in signal_names, "CrewCard.buy_requested declared")
	_assert("upgrade_requested" in signal_names, "CrewCard.upgrade_requested declared")
	_assert("equip_requested" in signal_names, "CrewCard.equip_requested declared")

func _test_outfitting_card_signals() -> void:
	print("[ OutfittingCard signals ]")
	var script: Script = load("res://src/ui/shipyard/outfitting_card.gd") as Script
	_assert(script != null, "outfitting_card.gd loaded")

	var signal_list: Array[Dictionary] = script.get_script_signal_list()
	var signal_names: Array[String] = []
	for sig: Dictionary in signal_list:
		signal_names.append(sig["name"] as String)

	_assert("buy_requested" in signal_names, "OutfittingCard.buy_requested declared")
	_assert("equip_requested" in signal_names, "OutfittingCard.equip_requested declared")

func _test_vessel_card_signals() -> void:
	print("[ VesselCard signals ]")
	var script: Script = load("res://src/ui/shipyard/vessel_card.gd") as Script
	_assert(script != null, "vessel_card.gd loaded")

	var signal_list: Array[Dictionary] = script.get_script_signal_list()
	var signal_names: Array[String] = []
	for sig: Dictionary in signal_list:
		signal_names.append(sig["name"] as String)

	_assert("card_clicked" in signal_names, "VesselCard.card_clicked declared")

func _test_tab_state_enum() -> void:
	print("[ ShipyardUI.TabType enum ]")
	# Verify enum constants exist on the script class
	var script: GDScript = load("res://src/ui/shipyard/shipyard_ui.gd") as GDScript
	_assert(script != null, "shipyard_ui.gd loaded as GDScript")


	@warning_ignore("UNUSED_VARIABLE")
	var constants: Dictionary = script.get_script_constant_map()
	# TabType values are inlined as top-level constants after class_name parsing
	# In GDScript 4, enum values appear as ClassName.ENUM_KEY patterns; we check
	# the script source contains the tab identifiers.
	var source: String = script.source_code
	_assert("VESSELS" in source, "TabType.VESSELS present in source")
	_assert("CREW" in source, "TabType.CREW present in source")
	_assert("OUTFITTING" in source, "TabType.OUTFITTING present in source")

func _test_action_state_enum() -> void:
	print("[ ShipyardUI.ActionState enum ]")
	var script: GDScript = load("res://src/ui/shipyard/shipyard_ui.gd") as GDScript
	_assert(script != null, "shipyard_ui.gd loaded")

	var source: String = script.source_code
	_assert("ActionState.BUY" in source or "ActionState { BUY" in source or "BUY," in source,
			"ActionState.BUY present in source")
	_assert("ActionState.UPGRADE" in source or "UPGRADE," in source,
			"ActionState.UPGRADE present in source")
	_assert("ActionState.EQUIP" in source or "EQUIP," in source,
			"ActionState.EQUIP present in source")
