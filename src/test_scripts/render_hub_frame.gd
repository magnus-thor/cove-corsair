@tool
extends Node

func _ready() -> void:
	var hub_scene: PackedScene = preload("res://scenes/cove_hub/cove_main_hub.tscn")
	var hub: CoveMainHub = hub_scene.instantiate() as CoveMainHub
	add_child(hub)

	await get_tree().process_frame
	await get_tree().process_frame

	var vp: Viewport = get_viewport()
	var img: Image = vp.get_texture().get_image()
	if img:
		img.save_png("res://hub_mobile_initial.png")
		print("Saved initial mobile hub preview to res://hub_mobile_initial.png")

	# Now unlock buildings to verify their placement
	hub.set_plot_unlocked("shipyard", true)
	hub.set_plot_unlocked("skull_outpost", true)

	await get_tree().process_frame
	await get_tree().process_frame

	img = vp.get_texture().get_image()
	if img:
		img.save_png("res://hub_mobile_unlocked.png")
		print("Saved unlocked mobile hub preview to res://hub_mobile_unlocked.png")

	get_tree().quit(0)
