extends Node3D

@onready var player_boat: CharacterBody3D = $PlayerBoat

# Preloaded Weapon Resources
var weapon_bow_chaser: WeaponData = preload("res://src/data/resources/weapon_bow_chaser.tres")
var weapon_port_swivel: WeaponData = preload("res://src/data/resources/weapon_port_swivel.tres")
var weapon_starboard_swivel: WeaponData = preload("res://src/data/resources/weapon_starboard_swivel.tres")
var weapon_deckhand_sniper: WeaponData = preload("res://src/data/resources/weapon_deckhand_sniper.tres")
var weapon_aft_mortar: WeaponData = preload("res://src/data/resources/weapon_aft_mortar.tres")

# UI Button References
@onready var btn_bow: Button = %btn_bow
@onready var btn_clear_bow: Button = %btn_clear_bow
@onready var btn_port: Button = %btn_port
@onready var btn_starboard: Button = %btn_starboard
@onready var btn_monkey: Button = %btn_monkey
@onready var btn_mortar: Button = %btn_mortar
@onready var btn_fire_toggle: Button = %btn_fire_toggle
@onready var btn_clear_all: Button = %btn_clear_all

func _ready() -> void:
	# Ensure game state is active for physics and weapon interactions
	GameState.is_game_active = true
	
	# Disable input movement and swerve so boat remains stationary at origin
	if player_boat:
		player_boat.is_calibration_mode = true
		player_boat.global_position = Vector3.ZERO
		player_boat.is_shooting_enabled = false

	# Connect button pressed signals
	if btn_bow:
		btn_bow.pressed.connect(_on_btn_bow_pressed)
	if btn_clear_bow:
		btn_clear_bow.pressed.connect(_on_btn_clear_bow_pressed)
	if btn_port:
		btn_port.pressed.connect(_on_btn_port_pressed)
	if btn_starboard:
		btn_starboard.pressed.connect(_on_btn_starboard_pressed)
	if btn_monkey:
		btn_monkey.pressed.connect(_on_btn_monkey_pressed)
	if btn_mortar:
		btn_mortar.pressed.connect(_on_btn_mortar_pressed)
	if btn_fire_toggle:
		btn_fire_toggle.pressed.connect(_on_btn_fire_toggle_pressed)
		_update_fire_toggle_button()
	if btn_clear_all:
		btn_clear_all.pressed.connect(_on_btn_clear_all_pressed)

func _on_btn_bow_pressed() -> void:
	if player_boat:
		player_boat.equip_weapon_to_socket("BowMount", weapon_bow_chaser)

func _on_btn_clear_bow_pressed() -> void:
	if player_boat:
		player_boat.equip_weapon_to_socket("BowMount", null)

func _on_btn_port_pressed() -> void:
	if player_boat:
		player_boat.equip_weapon_to_socket("PortSwivelMount", weapon_port_swivel)

func _on_btn_starboard_pressed() -> void:
	if player_boat:
		player_boat.equip_weapon_to_socket("StarboardSwivelMount", weapon_starboard_swivel)

func _on_btn_monkey_pressed() -> void:
	if player_boat:
		player_boat.equip_weapon_to_socket("AftMortarMount", weapon_deckhand_sniper)

func _on_btn_mortar_pressed() -> void:
	if player_boat:
		player_boat.equip_weapon_to_socket("AftMortarMount", weapon_aft_mortar)

func _on_btn_fire_toggle_pressed() -> void:
	if player_boat:
		player_boat.is_shooting_enabled = not player_boat.is_shooting_enabled
		_update_fire_toggle_button()

func _on_btn_clear_all_pressed() -> void:
	if player_boat:
		player_boat.clear_all_weapons()

func _update_fire_toggle_button() -> void:
	if btn_fire_toggle and player_boat:
		var status = "ON" if player_boat.is_shooting_enabled else "OFF"
		btn_fire_toggle.text = "Auto-Fire: " + status
