extends CharacterBody2D
## Player controller for Ashes of the Forge.
## Uses Sprite2D with manual frame stepping for sprite sheet animation.

# --- Signals ---
signal health_changed(current_hp: int, max_hp: int)
signal player_died

# --- Enums ---
enum Direction { DOWN = 0, LEFT = 1, RIGHT = 2, UP = 3 }

enum State { IDLE, WALK, ATTACK, HURT, DEATH }

# --- Constants ---
const SPRITE_BASE_PATH: String = "res://assets/rpg/sprites/player/Swordsman_lvl1/Without_shadow/"

## Texture paths for each animation state
const TEXTURE_PATHS: Dictionary = {
	State.IDLE: SPRITE_BASE_PATH + "Swordsman_lvl1_Idle_without_shadow.png",
	State.WALK: SPRITE_BASE_PATH + "Swordsman_lvl1_Walk_without_shadow.png",
	State.ATTACK: SPRITE_BASE_PATH + "Swordsman_lvl1_attack_without_shadow.png",
	State.HURT: SPRITE_BASE_PATH + "Swordsman_lvl1_Hurt_without_shadow.png",
	State.DEATH: SPRITE_BASE_PATH + "Swordsman_lvl1_Death_without_shadow.png",
}

## Frame counts per animation (columns in each sheet)
const FRAME_COUNTS: Dictionary = {
	State.IDLE: 12,
	State.WALK: 6,
	State.ATTACK: 8,
	State.HURT: 5,
	State.DEATH: 7,
}

## Idle UP direction only has 4 frames
const IDLE_UP_FRAME_COUNT: int = 4

## Animation cycle durations in seconds
const CYCLE_DURATIONS: Dictionary = {
	State.IDLE: 1.0,
	State.WALK: 0.6,
	State.ATTACK: 0.4,
	State.HURT: 0.3,
	State.DEATH: 0.7,
}

## Pivot rotation per direction (radians)
const PIVOT_ROTATIONS: Dictionary = {
	Direction.DOWN: PI / 2.0,
	Direction.LEFT: PI,
	Direction.RIGHT: 0.0,
	Direction.UP: -PI / 2.0,
}

# --- Export Variables ---
@export_group("Movement")
@export var speed: float = 80.0

@export_group("Combat")
@export var attack_damage: int = 1
@export var attack_duration: float = 0.3
@export var attack_cooldown: float = 0.4
@export var invincibility_duration: float = 1.0
@export var stun_duration: float = 0.3

# --- Node References ---
@onready var sprite: Sprite2D = $Sprite
@onready var hitbox_pivot: Node2D = $HitboxPivot
@onready var hitbox: Area2D = $HitboxPivot/Hitbox
@onready var hitbox_shape: CollisionShape2D = $HitboxPivot/Hitbox/HitboxShape
@onready var hurtbox: Area2D = $Hurtbox
@onready var camera: Camera2D = $Camera

# --- State ---
var current_state: State = State.IDLE
var facing: Direction = Direction.DOWN
var anim_timer: float = 0.0
var current_anim_frame: int = 0

## Combat timers
var attack_timer: float = 0.0
var attack_cooldown_timer: float = 0.0
var invincibility_timer: float = 0.0
var stun_timer: float = 0.0

## Cached textures (loaded once)
var _textures: Dictionary = {}

## Track if player is dead
var _is_dead: bool = false

# --- Lifecycle ---

func _ready() -> void:
	# Pre-load all textures
	for state: int in TEXTURE_PATHS:
		_textures[state] = load(TEXTURE_PATHS[state])

	# Set initial texture
	_set_animation_state(State.IDLE)

	# Update hitbox pivot rotation
	_update_hitbox_pivot()

	# Connect hurtbox signal
	hurtbox.area_entered.connect(_on_hurtbox_area_entered)

	# Add hitbox to group for enemy detection
	hitbox.add_to_group("player_hitbox")

	# Set damage metadata so enemies can read it
	hitbox.set_meta("damage", attack_damage)

	# Add hurtbox to group so enemies can poll contact damage
	hurtbox.add_to_group("player_hurtbox")

	# Set position from GameManager spawn point
	global_position = GameManager.get_spawn_position()


func _physics_process(delta: float) -> void:
	if _is_dead:
		_animate(delta)
		return

	# Update timers
	_update_timers(delta)

	# State machine
	match current_state:
		State.IDLE:
			_process_idle(delta)
		State.WALK:
			_process_walk(delta)
		State.ATTACK:
			_process_attack(delta)
		State.HURT:
			_process_hurt(delta)
		State.DEATH:
			pass

	# Animate
	_animate(delta)


# --- State Processing ---

func _process_idle(_delta: float) -> void:
	# Check for attack input
	if Input.is_action_just_pressed("attack") and attack_cooldown_timer <= 0.0:
		_start_attack()
		return

	# Check for movement
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_dir.length_squared() > 0.01:
		_update_facing_from_input(input_dir)
		velocity = input_dir.normalized() * speed
		move_and_slide()
		_set_animation_state(State.WALK)
	else:
		velocity = Vector2.ZERO


func _process_walk(_delta: float) -> void:
	# Check for attack input
	if Input.is_action_just_pressed("attack") and attack_cooldown_timer <= 0.0:
		_start_attack()
		return

	# Handle movement
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_dir.length_squared() > 0.01:
		_update_facing_from_input(input_dir)
		velocity = input_dir.normalized() * speed
		move_and_slide()
	else:
		velocity = Vector2.ZERO
		_set_animation_state(State.IDLE)


func _process_attack(_delta: float) -> void:
	# Wait for attack animation to finish
	if attack_timer <= 0.0:
		_end_attack()


func _process_hurt(_delta: float) -> void:
	# Wait for stun to finish
	if stun_timer <= 0.0:
		velocity = Vector2.ZERO
		_set_animation_state(State.IDLE)


# --- Combat ---

func _start_attack() -> void:
	current_state = State.ATTACK
	_set_animation_state(State.ATTACK)
	attack_timer = attack_duration
	attack_cooldown_timer = attack_cooldown
	velocity = Vector2.ZERO
	AudioManager.play_sfx("attack")

	# Enable hitbox
	hitbox_shape.set_deferred("disabled", false)
	hitbox.monitoring = true

	# Update pivot to face direction
	_update_hitbox_pivot()


func _end_attack() -> void:
	# Disable hitbox
	hitbox_shape.set_deferred("disabled", true)
	hitbox.monitoring = false

	_set_animation_state(State.IDLE)


## Set to true for demo/testing — player takes no damage
@export var god_mode: bool = false


func take_damage(amount: int, from_position: Vector2) -> void:
	if god_mode:
		return
	if _is_dead:
		return
	if invincibility_timer > 0.0:
		return

	# Apply damage via GameManager
	if GameManager:
		GameManager.damage_player(amount)
		var current_hp: int = GameManager.current_hp

		health_changed.emit(current_hp, GameManager.max_hp)

		if current_hp <= 0:
			_die()
			return

	AudioManager.play_sfx("player_hurt")

	# Cancel attack if attacking
	if current_state == State.ATTACK:
		_end_attack()

	# Enter hurt state
	current_state = State.HURT
	_set_animation_state(State.HURT)
	stun_timer = stun_duration
	invincibility_timer = invincibility_duration

	# Knockback away from damage source
	var knockback_dir: Vector2 = global_position.direction_to(from_position) * -1.0
	velocity = knockback_dir * speed * 1.5
	move_and_slide()

	# Hit flash effect
	_flash_damage()


func _die() -> void:
	_is_dead = true
	current_state = State.DEATH
	_set_animation_state(State.DEATH)
	velocity = Vector2.ZERO

	# Disable all collision
	hitbox_shape.set_deferred("disabled", true)
	hitbox.monitoring = false

	player_died.emit()

	# Respawn after death animation + brief pause
	get_tree().create_timer(1.5).timeout.connect(_respawn)


func _respawn() -> void:
	# Reset via GameManager and go back to Vila
	if GameManager:
		GameManager.respawn_player()
	GameManager.change_room("res://scenes/world/vila.tscn", Vector2(160, 90))


func _flash_damage() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(1.0, 0.3, 0.3, 1.0), 0.05)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
	tween.tween_property(sprite, "modulate", Color(1.0, 0.3, 0.3, 1.0), 0.05)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)


# --- Animation ---

func _set_animation_state(new_state: State) -> void:
	if current_state == new_state and sprite.texture == _textures.get(new_state):
		return

	current_state = new_state
	anim_timer = 0.0
	current_anim_frame = 0

	# Swap texture and update hframes/vframes
	var tex: Texture2D = _textures.get(new_state)
	if tex:
		sprite.texture = tex
		sprite.hframes = FRAME_COUNTS[new_state]
		sprite.vframes = 4

	# Set initial frame
	_update_sprite_frame()


func _animate(delta: float) -> void:
	var frame_count: int = _get_frame_count_for_current()
	var cycle_duration: float = CYCLE_DURATIONS.get(current_state, 1.0)

	anim_timer += delta

	# Calculate current frame
	if current_state == State.DEATH:
		# Death animation: play once, freeze on last frame
		current_anim_frame = mini(int(anim_timer / cycle_duration * frame_count), frame_count - 1)
	elif current_state == State.ATTACK or current_state == State.HURT:
		# One-shot animations
		current_anim_frame = mini(int(anim_timer / cycle_duration * frame_count), frame_count - 1)
	else:
		# Looping animations
		if anim_timer >= cycle_duration:
			anim_timer -= cycle_duration
		current_anim_frame = int((anim_timer / cycle_duration) * frame_count)
		current_anim_frame = clampi(current_anim_frame, 0, frame_count - 1)

	_update_sprite_frame()


func _update_sprite_frame() -> void:
	var frame_count: int = _get_frame_count_for_current()
	var row: int = facing as int
	sprite.frame = (row * sprite.hframes) + clampi(current_anim_frame, 0, frame_count - 1)


func _get_frame_count_for_current() -> int:
	if current_state == State.IDLE and facing == Direction.UP:
		return IDLE_UP_FRAME_COUNT
	return FRAME_COUNTS.get(current_state, 12)


# --- Direction ---

func _update_facing_from_input(input_dir: Vector2) -> void:
	# Determine dominant axis for 4-direction facing
	var new_facing: Direction = facing

	if absf(input_dir.x) > absf(input_dir.y):
		if input_dir.x > 0.0:
			new_facing = Direction.RIGHT
		else:
			new_facing = Direction.LEFT
	else:
		if input_dir.y > 0.0:
			new_facing = Direction.DOWN
		else:
			new_facing = Direction.UP

	if new_facing != facing:
		facing = new_facing
		_update_hitbox_pivot()


func _update_hitbox_pivot() -> void:
	hitbox_pivot.rotation = PIVOT_ROTATIONS.get(facing, 0.0)


# --- Timers ---

func _update_timers(delta: float) -> void:
	if attack_timer > 0.0:
		attack_timer -= delta
	if attack_cooldown_timer > 0.0:
		attack_cooldown_timer -= delta
	if invincibility_timer > 0.0:
		invincibility_timer -= delta
		# Blink effect during invincibility
		sprite.visible = int(invincibility_timer * 10.0) % 2 == 0
	else:
		sprite.visible = true
	if stun_timer > 0.0:
		stun_timer -= delta


# --- Signal Callbacks ---

func _on_hurtbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemy_hitbox"):
		var dmg: int = 1
		if area.has_meta("damage"):
			dmg = area.get_meta("damage") as int
		elif area.has_method("get_damage"):
			dmg = area.get_damage()
		take_damage(dmg, area.global_position)
