extends CharacterBody2D
## Standalone Warrior script for Ashes of the Forge.
## This script does not inherit from player.gd and manages its own state and animations.

# --- Signals ---
signal health_changed(current_hp: int, max_hp: int)

# --- Enums ---
enum Direction { DOWN = 0, LEFT = 1, RIGHT = 2, UP = 3 }
enum State { IDLE, WALK, ATTACK, HURT, DEATH }

# --- Constants ---
const FRAME_COUNT: int = 6
const CYCLE_DURATION: float = 0.6

# --- Export Variables ---
@export_group("Movement")
@export var speed: float = 80.0

# --- Node References ---
@onready var sprite: Sprite2D = $Sprite
@onready var camera: Camera2D = $Camera

# --- State ---
var current_state: State = State.IDLE
var facing: Direction = Direction.DOWN
var anim_timer: float = 0.0
var current_anim_frame: int = 0

func _ready() -> void:
	# Initial setup
	sprite.hframes = FRAME_COUNT
	sprite.vframes = 4
	
	# Connect to GameManager if available for spawn
	if Engine.has_singleton("GameManager") or has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		global_position = gm.get_spawn_position()

func _physics_process(delta: float) -> void:
	_handle_movement(delta)
	_animate(delta)
	_check_map_transitions()

func _handle_movement(_delta: float) -> void:
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	if input_dir.length_squared() > 0.01:
		_update_facing(input_dir)
		velocity = input_dir.normalized() * speed
		current_state = State.WALK
		move_and_slide()
	else:
		velocity = Vector2.ZERO
		current_state = State.IDLE

func _update_facing(input_dir: Vector2) -> void:
	if absf(input_dir.x) > absf(input_dir.y):
		if input_dir.x > 0.0: facing = Direction.RIGHT
		else: facing = Direction.LEFT
	else:
		if input_dir.y > 0.0: facing = Direction.DOWN
		else: facing = Direction.UP
	
	# With 4 rows (one for each direction), we do not flip the sprite
	sprite.flip_h = false

func _animate(delta: float) -> void:
	if current_state == State.IDLE:
		anim_timer = 0.0
		current_anim_frame = 0
		_update_sprite_frame()
		return

	anim_timer += delta
	if anim_timer >= CYCLE_DURATION:
		anim_timer -= CYCLE_DURATION
	
	current_anim_frame = int((anim_timer / CYCLE_DURATION) * FRAME_COUNT)
	_update_sprite_frame()

func _update_sprite_frame() -> void:
	var row: int = facing as int
	# Swap left (1) and right (2) rows because they are inverted in the sprite sheet
	if row == 1:
		row = 2
	elif row == 2:
		row = 1
	sprite.frame = (row * sprite.hframes) + clampi(current_anim_frame, 0, FRAME_COUNT - 1)

func _check_map_transitions() -> void:
	var parent_room = get_parent()
	if parent_room and "room_size" in parent_room:
		var room_size: Vector2 = parent_room.room_size
		var transition_node: Node = null
		
		# Warrior collision shape is 40px wide (20px half-width), so we use a 24px threshold
		if global_position.x >= room_size.x - 24:
			transition_node = parent_room.get_node_or_null("ExitRight")
		elif global_position.x <= 24:
			transition_node = parent_room.get_node_or_null("ExitLeft")
		elif global_position.y <= 24:
			transition_node = parent_room.get_node_or_null("ExitTop")
		elif global_position.y >= room_size.y - 24:
			transition_node = parent_room.get_node_or_null("ExitBottom")
			
		if transition_node and "target_room_path" in transition_node:
			var target_path: String = transition_node.target_room_path
			var spawn_pos: Vector2 = transition_node.target_spawn
			if target_path != "" and (Engine.has_singleton("GameManager") or has_node("/root/GameManager")):
				var gm = get_node("/root/GameManager")
				gm.change_room(target_path, spawn_pos)
