class_name Room
extends Node2D
## Base class for all game rooms.

@export var room_name: String = "Unknown"
@export var room_size: Vector2 = Vector2(320, 180)
@export var player_spawn: Vector2 = Vector2(160, 90)
@export var music_track: String = ""


func _ready() -> void:
	GameManager.set_room_name(room_name)

	# Play room music
	if music_track != "":
		AudioManager.play_music(music_track)

	# Set camera limits on the player's Camera2D
	await get_tree().process_frame
	var player: Node = get_node_or_null("Player")
	if player:
		var camera: Camera2D = player.get_node_or_null("Camera") as Camera2D
		if camera:
			camera.limit_left = 0
			camera.limit_top = 0
			camera.limit_right = int(room_size.x)
			camera.limit_bottom = int(room_size.y)
