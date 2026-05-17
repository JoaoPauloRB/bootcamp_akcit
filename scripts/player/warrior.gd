extends CharacterBody2D
## Standalone Warrior script for Ashes of the Forge.
## This script does not inherit from player.gd and manages its own state and animations.

# --- Signals ---
signal health_changed(current_hp: int, max_hp: int)

# --- Enums ---
enum Direction { DOWN = 0, LEFT = 1, RIGHT = 2, UP = 3 }
enum State { IDLE, WALK, ATTACK, HURT, DEATH }

# --- Constants ---
const FRAME_COUNT: int = 4
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
	sprite.vframes = 1
	
	# Connect to GameManager if available for spawn
	if Engine.has_singleton("GameManager") or has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		global_position = gm.get_spawn_position()

func _physics_process(delta: float) -> void:
	_handle_movement(delta)
	_animate(delta)

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
	
	# Flip sprite when moving left
	if facing == Direction.LEFT:
		sprite.flip_h = true
	elif facing == Direction.RIGHT:
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
	# Asset only has 1 row, so we just use the animation frame
	sprite.frame = clampi(current_anim_frame, 0, FRAME_COUNT - 1)
