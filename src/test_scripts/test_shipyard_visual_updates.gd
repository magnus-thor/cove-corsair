@tool
extends Node

func _ready() -> void:
	print("--- Running Shipyard Visual Updates Tests ---")
	_test_vessel_order()
	_test_vessel_card_contrast()
	_test_crew_badge_font_size()
	_test_outfitting_cards_reorganization()
	_test_vessel_textures()
	print("--- ALL SHIPYARD VISUAL UPDATES TESTS PASSED! ---")
	get_tree().quit(0)

func _test_vessel_order() -> void:
	var shipyard_scene: PackedScene = preload("res://src/ui/shipyard/shipyard_ui.tscn")
	var shipyard: ShipyardUI = shipyard_scene.instantiate() as ShipyardUI
	add_child(shipyard)

	assert(shipyard.vessel_ids.size() == 4, "Should have 4 vessels")
	assert(shipyard.vessel_ids[0] == "dinghy", "0 should be dinghy")
	assert(shipyard.vessel_ids[1] == "sloop", "1 should be sloop")
	assert(shipyard.vessel_ids[2] == "bombard_skiff", "2 should be bombard_skiff")
	assert(shipyard.vessel_ids[3] == "ironclad", "3 should be ironclad (last vessel)")
	print("[PASS] Vessel order verified: ", shipyard.vessel_ids)
	shipyard.queue_free()

func _test_vessel_card_contrast() -> void:
	var vcard_scene: PackedScene = preload("res://src/ui/shipyard/vessel_card.tscn")
	var card: VesselCard = vcard_scene.instantiate() as VesselCard
	add_child(card)
	card.setup_vessel("sloop", 2)

	# Verify index badge was removed
	assert(card.get_node_or_null("%IndexBadge") == null, "IndexBadge node must be removed from VesselCard")

	# Test normal unselected state
	card.set_selected(false)
	var title_normal_color: Color = card.title_label.get_theme_color("font_color")
	assert(title_normal_color.r > 0.8 and title_normal_color.g > 0.8, "Normal title color must be light cream for dark card contrast")

	# Test selected state
	card.set_selected(true)
	var title_selected_color: Color = card.title_label.get_theme_color("font_color")
	assert(title_selected_color.r > 0.9 and title_selected_color.g > 0.9, "Selected title color must be bright gold/cream")

	# Verify Tier Badge contrast
	var tier_font_color: Color = card.tier_badge_label.get_theme_color("font_color")
	assert(tier_font_color.r > 0.9 and tier_font_color.g > 0.8, "Tier badge font color must be bright gold for clear contrast")
	print("[PASS] Vessel card text contrast, index removal, and tier badge contrast verified!")
	card.queue_free()

func _test_crew_badge_font_size() -> void:
	var crew_card_scene: PackedScene = preload("res://src/ui/shipyard/crew_card.tscn")
	var card: CrewCard = crew_card_scene.instantiate() as CrewCard
	add_child(card)
	var font_size: int = card.role_badge_label.get_theme_font_size("font_size")
	assert(font_size == 12, "RoleBadgeLabel font size should be 12 (reduced by 4 from 16), got %d" % font_size)
	print("[PASS] Crew badge font size verified as 12!")
	card.queue_free()

func _test_outfitting_cards_reorganization() -> void:
	var shipyard_scene: PackedScene = preload("res://src/ui/shipyard/shipyard_ui.tscn")
	var shipyard: ShipyardUI = shipyard_scene.instantiate() as ShipyardUI
	add_child(shipyard)

	shipyard._build_outfitting_cards()
	assert(shipyard.outfitting_card_instances.size() >= 8, "Must generate all 8 outfitting cards")

	# Check that outfitting card has no category badge in tree
	var first_card: OutfittingCard = shipyard.outfitting_card_instances["standard_iron"] as OutfittingCard
	assert(first_card.get_node_or_null("%CategoryBadge") == null, "CategoryBadge node should be removed from OutfittingCard")

	# Check that section headers were inserted into grid_container
	var found_headers: int = 0
	for child: Node in shipyard.grid_container.get_children():
		if child is PanelContainer and child != first_card:
			for sub_child: Node in child.get_children():
				if sub_child is Label and ("AMMUNITION" in (sub_child as Label).text or "PLATING" in (sub_child as Label).text):
					found_headers += 1
	assert(found_headers >= 2, "Expected at least 2 section header panels in grid, found %d" % found_headers)
	print("[PASS] Outfitting cards reorganization and section headers verified!")
	shipyard.queue_free()

func _test_vessel_textures() -> void:
	var bombard_path: String = GameState.VESSEL_CATALOG["bombard_skiff"]["preview_texture"]
	var ironclad_path: String = GameState.VESSEL_CATALOG["ironclad"]["preview_texture"]
	assert(ResourceLoader.exists(bombard_path), "Bombard preview texture must exist")
	assert(ResourceLoader.exists(ironclad_path), "Ironclad preview texture must exist")
	var bombard_tex: Texture2D = load(bombard_path) as Texture2D
	var ironclad_tex: Texture2D = load(ironclad_path) as Texture2D
	assert(bombard_tex != null, "Bombard texture should load")
	assert(ironclad_tex != null, "Ironclad texture should load")
	print("[PASS] Vessel textures verified: Bombard size=%s, Ironclad size=%s" % [bombard_tex.get_size(), ironclad_tex.get_size()])
