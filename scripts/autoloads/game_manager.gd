extends Node
## GameManager autoload — global game state for Ashes of the Forge.
## Tracks player health, resources, level, and handles respawn logic.

# --- Signals ---
signal health_changed(current_hp: int, max_hp: int)
signal resources_changed(slime_cores: int, bone_shards: int)
signal player_died
signal player_level_changed(new_level: int)
signal room_changed(room_name: String)
signal boss_defeated

# --- Constants ---
const DEFAULT_HP: int = 6
const DEFAULT_MAX_HP: int = 12

# --- Player Stats ---
## Health in half-hearts (start at max for prototype)
var current_hp: int = DEFAULT_MAX_HP
var max_hp: int = DEFAULT_MAX_HP

## Resources
var slime_cores: int = 0
var bone_shards: int = 0

## Player level (1-3)
var player_level: int = 1

## Boss state
var is_boss_defeated: bool = false

# --- Room Management ---
var current_room_name: String = "Vila"
var _pending_spawn: Vector2 = Vector2(160, 90)

# --- Health ---

func damage_player(amount: int) -> void:
	current_hp = maxi(current_hp - amount, 0)
	health_changed.emit(current_hp, max_hp)
	if current_hp <= 0:
		player_died.emit()


func heal_player(amount: int) -> void:
	current_hp = mini(current_hp + amount, max_hp)
	health_changed.emit(current_hp, max_hp)


# --- Resources ---

func add_resource(type: String, amount: int) -> void:
	match type:
		"slime_core":
			slime_cores += amount
		"bone_shard":
			bone_shards += amount
		_:
			push_warning("GameManager: Unknown resource type '%s'" % type)
			return
	AudioManager.play_sfx("pickup")
	resources_changed.emit(slime_cores, bone_shards)


# --- Level ---

func set_player_level(new_level: int) -> void:
	var clamped_level: int = clampi(new_level, 1, 3)
	if clamped_level != player_level:
		player_level = clamped_level
		player_level_changed.emit(player_level)


# --- Room Management ---

func change_room(room_path: String, spawn_position: Vector2) -> void:
	_pending_spawn = spawn_position
	get_tree().call_deferred("change_scene_to_file", room_path)


func set_room_name(room_name: String) -> void:
	current_room_name = room_name
	room_changed.emit(room_name)


func get_spawn_position() -> Vector2:
	return _pending_spawn


# --- Boss ---

const VICTORY_SCENE_PATH: String = "res://scenes/ui/victory.tscn"

func defeat_boss() -> void:
	is_boss_defeated = true
	boss_defeated.emit()
	# Show victory screen after a brief delay
	get_tree().create_timer(1.0).timeout.connect(_show_victory)


func _show_victory() -> void:
	var victory_scene: PackedScene = load(VICTORY_SCENE_PATH)
	if victory_scene:
		var victory_instance: Node = victory_scene.instantiate()
		get_tree().current_scene.add_child(victory_instance)


# --- Respawn ---

func respawn_player() -> void:
	current_hp = max_hp
	health_changed.emit(current_hp, max_hp)
	# Keep level and resources on respawn
