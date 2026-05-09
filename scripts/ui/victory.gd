extends CanvasLayer
## Victory screen shown when the Skeleton Warrior Boss is defeated.
## Pauses the game and returns to Vila after a delay.

const RETURN_DELAY: float = 4.0

@onready var title_label: Label = $Overlay/VBox/TitleLabel
@onready var subtitle_label: Label = $Overlay/VBox/SubtitleLabel


func _ready() -> void:
	# Pause the game tree (this node stays active via process_mode)
	get_tree().paused = true

	# Fade in
	var overlay: ColorRect = $Overlay
	overlay.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var tween: Tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(overlay, "modulate", Color.WHITE, 0.5)

	# Auto-return to Vila after delay
	get_tree().create_timer(RETURN_DELAY, true, false, true).timeout.connect(_return_to_vila)


func _return_to_vila() -> void:
	get_tree().paused = false
	GameManager.change_room("res://scenes/world/vila.tscn", Vector2(160, 90))
	queue_free()
