extends CharacterBody2D
## Standalone Warrior script for Ashes of the Forge.
## This script does not inherit from player.gd and manages its own state and animations.

# --- Signals ---
signal health_changed(current_hp: int, max_hp: int)
signal player_died

# --- Enums ---
enum Direction { DOWN = 0, LEFT = 1, RIGHT = 2, UP = 3 }
enum State { IDLE, WALK, ATTACK, HURT, DEATH }

# --- Constants ---
const FRAME_COUNT: int = 6
const CYCLE_DURATION: float = 0.6
const WALK_TEXTURE_PATH: String = "res://assets/rpg/sprites/player/warrior/warrior_walk.png"
const ATTACK_TEXTURE_PATH: String = "res://assets/rpg/sprites/player/warrior/warrior_attack.png"

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
@export var god_mode: bool = false

# --- Node References ---
@onready var sprite: Sprite2D = $Sprite
@onready var camera: Camera2D = $Camera
@onready var hitbox_pivot: Node2D = $HitboxPivot
@onready var hitbox: Area2D = $HitboxPivot/Hitbox
@onready var hitbox_shape: CollisionShape2D = $HitboxPivot/Hitbox/HitboxShape
@onready var hurtbox: Area2D = $Hurtbox

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

## Cached textures
var _walk_texture: Texture2D
var _attack_texture: Texture2D

## Track if player is dead
var _is_dead: bool = false

func _ready() -> void:
	# Load textures
	_walk_texture = load(WALK_TEXTURE_PATH)
	_attack_texture = load(ATTACK_TEXTURE_PATH)
	
	# Initial setup
	sprite.texture = _walk_texture
	sprite.hframes = FRAME_COUNT
	sprite.vframes = 4
	
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

	# Connect to GameManager if available for spawn
	if Engine.has_singleton("GameManager") or has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		global_position = gm.get_spawn_position()

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

func _process_idle(_delta: float) -> void:
	# Check for attack input
	if Input.is_action_just_pressed("attack") and attack_cooldown_timer <= 0.0:
		_start_attack()
		return

	# Check for movement
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_dir.length_squared() > 0.01:
		_update_facing(input_dir)
		velocity = input_dir.normalized() * speed
		current_state = State.WALK
		move_and_slide()
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
		_update_facing(input_dir)
		velocity = input_dir.normalized() * speed
		move_and_slide()
	else:
		velocity = Vector2.ZERO
		current_state = State.IDLE

func _process_attack(_delta: float) -> void:
	# Wait for attack animation to finish
	if attack_timer <= 0.0:
		_end_attack()

func _process_hurt(_delta: float) -> void:
	# Wait for stun to finish
	if stun_timer <= 0.0:
		velocity = Vector2.ZERO
		current_state = State.IDLE

func _update_facing(input_dir: Vector2) -> void:
	var new_facing: Direction = facing
	if absf(input_dir.x) > absf(input_dir.y):
		if input_dir.x > 0.0: new_facing = Direction.RIGHT
		else: new_facing = Direction.LEFT
	else:
		if input_dir.y > 0.0: new_facing = Direction.DOWN
		else: new_facing = Direction.UP
	
	if new_facing != facing:
		facing = new_facing
		_update_hitbox_pivot()
	
	# With 4 rows (one for each direction), we do not flip the sprite
	sprite.flip_h = false

func _update_hitbox_pivot() -> void:
	hitbox_pivot.rotation = PIVOT_ROTATIONS.get(facing, 0.0)

func _animate(delta: float) -> void:
	if current_state == State.IDLE:
		anim_timer = 0.0
		current_anim_frame = 0
		_update_sprite_frame()
		return

	anim_timer += delta
	
	if current_state == State.ATTACK:
		# One-shot animation
		current_anim_frame = mini(int((anim_timer / attack_duration) * FRAME_COUNT), FRAME_COUNT - 1)
	elif current_state == State.DEATH or current_state == State.HURT:
		# One-shot / freeze frame
		current_anim_frame = mini(int((anim_timer / CYCLE_DURATION) * FRAME_COUNT), FRAME_COUNT - 1)
	else:
		# Looping walk animation
		if anim_timer >= CYCLE_DURATION:
			anim_timer -= CYCLE_DURATION
		current_anim_frame = int((anim_timer / CYCLE_DURATION) * FRAME_COUNT)
		current_anim_frame = clampi(current_anim_frame, 0, FRAME_COUNT - 1)

	_update_sprite_frame()

func _update_sprite_frame() -> void:
	var row: int = facing as int
	# Swap left (1) and right (2) rows because they are inverted in the sprite sheet
	if row == 1:
		row = 2
	elif row == 2:
		row = 1
	sprite.frame = (row * sprite.hframes) + clampi(current_anim_frame, 0, sprite.hframes - 1)

func _start_attack() -> void:
	current_state = State.ATTACK
	anim_timer = 0.0
	current_anim_frame = 0
	sprite.texture = _attack_texture
	sprite.hframes = FRAME_COUNT
	sprite.vframes = 4
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

	current_state = State.IDLE
	sprite.texture = _walk_texture
	sprite.hframes = FRAME_COUNT
	sprite.vframes = 4

func take_damage(amount: int, from_position: Vector2) -> void:
	if god_mode:
		return
	if _is_dead:
		return
	if invincibility_timer > 0.0:
		return

	# Apply damage via GameManager
	if Engine.has_singleton("GameManager") or has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		gm.damage_player(amount)
		health_changed.emit(gm.current_hp, gm.max_hp)

		if gm.current_hp <= 0:
			_die()
			return

	AudioManager.play_sfx("player_hurt")

	# Cancel attack if attacking
	if current_state == State.ATTACK:
		_end_attack()

	# Enter hurt state
	current_state = State.HURT
	sprite.texture = _walk_texture
	sprite.hframes = FRAME_COUNT
	sprite.vframes = 4
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
	sprite.texture = _walk_texture
	sprite.hframes = FRAME_COUNT
	sprite.vframes = 4
	velocity = Vector2.ZERO

	# Disable all collision
	hitbox_shape.set_deferred("disabled", true)
	hitbox.monitoring = false

	player_died.emit()

	# Respawn after death animation + brief pause
	get_tree().create_timer(1.5).timeout.connect(_respawn)

func _respawn() -> void:
	if Engine.has_singleton("GameManager") or has_node("/root/GameManager"):
		var gm = get_node("/root/GameManager")
		gm.respawn_player()
		gm.change_room("res://scenes/world/vila.tscn", Vector2(512, 384))

func _flash_damage() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(1.0, 0.3, 0.3, 1.0), 0.05)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
	tween.tween_property(sprite, "modulate", Color(1.0, 0.3, 0.3, 1.0), 0.05)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)

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



func _on_hurtbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemy_hitbox"):
		var dmg: int = 1
		if area.has_meta("damage"):
			dmg = area.get_meta("damage") as int
		elif area.has_method("get_damage"):
			dmg = area.get_damage()
		take_damage(dmg, area.global_position)
