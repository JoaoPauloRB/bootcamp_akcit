extends CanvasLayer
## HUD overlay — displays hearts, room name, and resource counters.
## Connects to GameManager signals to stay in sync with game state.

@onready var hearts_container: HBoxContainer = $Hearts
@onready var room_label: Label = $RoomLabel
@onready var cores_label: Label = $CoresLabel
@onready var shards_label: Label = $ShardsLabel

var heart_full_tex: Texture2D
var heart_half_tex: Texture2D
var heart_empty_tex: Texture2D


func _ready() -> void:
	# Load heart textures
	heart_full_tex = preload("res://assets/ui/heart_full.png")
	heart_half_tex = preload("res://assets/ui/heart_half.png")
	heart_empty_tex = preload("res://assets/ui/heart_empty.png")

	# Connect to GameManager signals
	GameManager.health_changed.connect(_on_health_changed)
	GameManager.resources_changed.connect(_on_resources_changed)
	GameManager.room_changed.connect(_on_room_changed)

	# Initial update
	_update_hearts(GameManager.current_hp, GameManager.max_hp)
	_update_resources(GameManager.slime_cores, GameManager.bone_shards)
	room_label.text = GameManager.current_room_name


func _update_hearts(current_hp: int, max_hp: int) -> void:
	# Clear existing hearts
	for child in hearts_container.get_children():
		child.queue_free()

	# max_hp is in half-hearts, so full hearts = max_hp / 2
	var full_hearts: int = int(max_hp / 2.0)
	var current_half: int = current_hp

	for i in range(full_hearts):
		var heart := TextureRect.new()
		heart.stretch_mode = TextureRect.STRETCH_KEEP
		heart.custom_minimum_size = Vector2(16, 16)
		heart.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

		var half_hearts_for_this: int = current_half - (i * 2)
		if half_hearts_for_this >= 2:
			heart.texture = heart_full_tex
		elif half_hearts_for_this == 1:
			heart.texture = heart_half_tex
		else:
			heart.texture = heart_empty_tex

		hearts_container.add_child(heart)


func _update_resources(slime_cores: int, bone_shards: int) -> void:
	cores_label.text = "Cores: %d" % slime_cores
	shards_label.text = "Shards: %d" % bone_shards


func _on_health_changed(current_hp: int, max_hp: int) -> void:
	_update_hearts(current_hp, max_hp)


func _on_resources_changed(slime_cores: int, bone_shards: int) -> void:
	_update_resources(slime_cores, bone_shards)


func _on_room_changed(room_name: String) -> void:
	room_label.text = room_name
