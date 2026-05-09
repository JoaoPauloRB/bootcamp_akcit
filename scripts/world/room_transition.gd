class_name RoomTransition
extends Area2D
## Triggers a room change when the player enters this area.

@export var target_room_path: String = ""
@export var target_spawn: Vector2 = Vector2(160, 90)
@export var direction: String = "right"

var _triggered: bool = false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # Detect player body
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _triggered:
		return
	if body.collision_layer & 2:  # Player layer
		_triggered = true
		GameManager.change_room(target_room_path, target_spawn)
