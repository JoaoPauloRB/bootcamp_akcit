extends CharacterBody2D
## Slime enemy with variant support (Green, Blue, Red).
## Uses Sprite2D with manual frame stepping for sprite sheet animation.

# --- Enums ---
enum Direction { DOWN = 0, LEFT = 1, RIGHT = 2, UP = 3 }

enum AIState { IDLE, WANDER, CHASE, HURT, DEATH }

# --- Constants ---
const SPRITE_BASE_PATH: String = "res://assets/rpg/sprites/enemies/Slime%d/Without_shadow/"

## Frame counts per animation action [idle, walk, attack, hurt, death]
## Indexed by variant (1-indexed, so index 0 is unused)
const ATTACK_FRAME_COUNTS: Array[int] = [10, 10, 11, 9]

## Standard frame counts (same for all variants)
const IDLE_FRAMES: int = 6
const WALK_FRAMES: int = 8
const HURT_FRAMES: int = 5
const DEATH_FRAMES: int = 10

## Animation cycle durations in seconds
const IDLE_CYCLE: float = 0.8
const WALK_CYCLE: float = 0.6
const HURT_CYCLE: float = 0.3
const DEATH_CYCLE: float = 0.8

## Wander timing
const IDLE_TIME_MIN: float = 1.0
const IDLE_TIME_MAX: float = 3.0
const WANDER_TIME_MIN: float = 1.0
const WANDER_TIME_MAX: float = 2.0

## Contact damage re-hit cooldown
const CONTACT_DAMAGE_INTERVAL: float = 1.0

## Sprite row mapping: Slime uses DOWN=0, RIGHT=1, LEFT=2, UP=3 (LEFT/RIGHT swapped vs Player)
const SPRITE_ROW_MAP: Array[int] = [0, 2, 1, 3]

# --- Export Variables ---
@export_group("Variant")
@export_range(1, 3) var slime_variant: int = 1

@export_group("Stats")
@export var max_hp: int = 2
@export var damage: int = 1
@export var speed: float = 30.0
@export var aggro_range: float = 96.0

@export_group("Drops")
@export var drop_resource: String = "slime_core"
@export var drop_chance: float = 0.8

# --- Node References ---
@onready var sprite: Sprite2D = $Sprite
@onready var hurtbox: Area2D = $Hurtbox
@onready var hitbox: Area2D = $Hitbox
@onready var hitbox_shape: CollisionShape2D = $Hitbox/HitboxShape
@onready var aggro_area: Area2D = $AggroRange
@onready var aggro_shape: CollisionShape2D = $AggroRange/AggroShape

# --- State ---
var current_state: AIState = AIState.IDLE
var facing: Direction = Direction.DOWN
var current_hp: int = 0
var _is_dead: bool = false

## Animation
var anim_timer: float = 0.0
var current_anim_frame: int = 0
var _current_hframes: int = 6

## AI timers
var state_timer: float = 0.0
var wander_direction: Vector2 = Vector2.ZERO
var contact_damage_timer: float = 0.0

## Cached textures
var _tex_idle: Texture2D
var _tex_walk: Texture2D
var _tex_attack: Texture2D
var _tex_hurt: Texture2D
var _tex_death: Texture2D

## Player reference for chase
var _target_player: CharacterBody2D = null


# --- Lifecycle ---

func _ready() -> void:
	current_hp = max_hp

	# Load textures for variant
	_load_variant_textures()

	# Set initial animation
	_set_anim_texture(_tex_idle, IDLE_FRAMES)

	# Configure aggro range
	var aggro_circle: CircleShape2D = aggro_shape.shape as CircleShape2D
	if aggro_circle:
		aggro_circle.radius = aggro_range

	# Set damage metadata on hitbox for player detection
	hitbox.set_meta("damage", damage)
	hitbox.add_to_group("enemy_hitbox")

	# Connect signals
	hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	aggro_area.body_entered.connect(_on_aggro_body_entered)
	aggro_area.body_exited.connect(_on_aggro_body_exited)

	# Start with random idle duration
	state_timer = randf_range(IDLE_TIME_MIN, IDLE_TIME_MAX)


func _physics_process(delta: float) -> void:
	if _is_dead:
		_animate(delta)
		return

	# Update contact damage timer
	if contact_damage_timer > 0.0:
		contact_damage_timer -= delta

	# State machine
	match current_state:
		AIState.IDLE:
			_process_idle(delta)
		AIState.WANDER:
			_process_wander(delta)
		AIState.CHASE:
			_process_chase(delta)
		AIState.HURT:
			_process_hurt(delta)
		AIState.DEATH:
			pass

	# Poll contact damage
	_poll_contact_damage()

	# Animate
	_animate(delta)


# --- AI State Processing ---

func _process_idle(delta: float) -> void:
	velocity = Vector2.ZERO
	state_timer -= delta

	if state_timer <= 0.0:
		_enter_wander()


func _process_wander(delta: float) -> void:
	velocity = wander_direction * speed
	move_and_slide()
	state_timer -= delta

	if state_timer <= 0.0:
		_enter_idle()


func _process_chase(_delta: float) -> void:
	if not is_instance_valid(_target_player) or _target_player == null:
		_enter_idle()
		return

	# Green slime (variant 1) never chases
	if slime_variant == 1:
		_enter_idle()
		return

	var dir: Vector2 = global_position.direction_to(_target_player.global_position)
	velocity = dir * speed
	_update_facing_from_velocity(dir)
	move_and_slide()


func _process_hurt(delta: float) -> void:
	state_timer -= delta
	# Apply knockback deceleration
	velocity = velocity.move_toward(Vector2.ZERO, speed * 4.0 * delta)
	move_and_slide()

	if state_timer <= 0.0:
		if _target_player != null and slime_variant > 1:
			_enter_chase()
		else:
			_enter_idle()


# --- State Transitions ---

func _enter_idle() -> void:
	current_state = AIState.IDLE
	state_timer = randf_range(IDLE_TIME_MIN, IDLE_TIME_MAX)
	velocity = Vector2.ZERO
	_set_anim_texture(_tex_idle, IDLE_FRAMES)


func _enter_wander() -> void:
	current_state = AIState.WANDER
	state_timer = randf_range(WANDER_TIME_MIN, WANDER_TIME_MAX)

	# Pick random direction
	var angle: float = randf() * TAU
	wander_direction = Vector2(cos(angle), sin(angle))
	_update_facing_from_velocity(wander_direction)
	_set_anim_texture(_tex_walk, WALK_FRAMES)


func _enter_chase() -> void:
	# Green slimes don't chase
	if slime_variant == 1:
		_enter_wander()
		return

	current_state = AIState.CHASE
	_set_anim_texture(_tex_walk, WALK_FRAMES)


func _enter_hurt(from_position: Vector2) -> void:
	current_state = AIState.HURT
	state_timer = 0.2
	_set_anim_texture(_tex_hurt, HURT_FRAMES)

	# Knockback away from damage source
	var knockback_dir: Vector2 = from_position.direction_to(global_position)
	velocity = knockback_dir * speed * 3.0
	move_and_slide()

	# Flash red
	_flash_damage()


func _enter_death() -> void:
	_is_dead = true
	current_state = AIState.DEATH
	velocity = Vector2.ZERO
	_set_anim_texture(_tex_death, DEATH_FRAMES)

	# Disable all collision
	hitbox_shape.set_deferred("disabled", true)
	hitbox.monitoring = false
	hitbox.set_deferred("monitorable", false)

	# Disable hurtbox
	for child: Node in hurtbox.get_children():
		if child is CollisionShape2D:
			(child as CollisionShape2D).set_deferred("disabled", true)

	# Drop resources
	_try_drop_resource()

	# Queue free after death animation
	var death_duration: float = DEATH_CYCLE + 0.2
	get_tree().create_timer(death_duration).timeout.connect(_on_death_timer)


# --- Combat ---

func take_damage(amount: int, from_position: Vector2) -> void:
	if _is_dead:
		return

	current_hp -= amount
	AudioManager.play_sfx("hit")
	if current_hp <= 0:
		AudioManager.play_sfx("enemy_death")
		_enter_death()
	else:
		_enter_hurt(from_position)


func _poll_contact_damage() -> void:
	if contact_damage_timer > 0.0:
		return

	var overlapping: Array[Node2D] = hitbox.get_overlapping_bodies()
	for body: Node2D in overlapping:
		if body is CharacterBody2D and body.collision_layer & 2:
			if body.has_method("take_damage"):
				body.take_damage(damage, global_position)
				contact_damage_timer = CONTACT_DAMAGE_INTERVAL
				return


func _try_drop_resource() -> void:
	if randf() <= drop_chance:
		if GameManager:
			GameManager.add_resource(drop_resource, 1)


func _flash_damage() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(1.0, 0.3, 0.3, 1.0), 0.05)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
	tween.tween_property(sprite, "modulate", Color(1.0, 0.3, 0.3, 1.0), 0.05)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)


# --- Animation ---

func _load_variant_textures() -> void:
	var base: String = SPRITE_BASE_PATH % slime_variant
	var prefix: String = "Slime%d" % slime_variant
	_tex_idle = load(base + prefix + "_Idle_without_shadow.png")
	_tex_walk = load(base + prefix + "_Walk_without_shadow.png")
	_tex_attack = load(base + prefix + "_Attack_without_shadow.png")
	_tex_hurt = load(base + prefix + "_Hurt_without_shadow.png")
	_tex_death = load(base + prefix + "_Death_without_shadow.png")


func _set_anim_texture(tex: Texture2D, hframes: int) -> void:
	if sprite.texture == tex:
		return
	sprite.texture = tex
	sprite.hframes = hframes
	sprite.vframes = 4
	_current_hframes = hframes
	anim_timer = 0.0
	current_anim_frame = 0
	_update_sprite_frame()


func _animate(delta: float) -> void:
	var frame_count: int = _current_hframes
	var cycle_duration: float = _get_cycle_duration()

	anim_timer += delta

	if current_state == AIState.DEATH:
		# Play once, freeze on last frame
		current_anim_frame = mini(int(anim_timer / cycle_duration * frame_count), frame_count - 1)
	elif current_state == AIState.HURT:
		# One-shot
		current_anim_frame = mini(int(anim_timer / cycle_duration * frame_count), frame_count - 1)
	else:
		# Looping
		if anim_timer >= cycle_duration:
			anim_timer -= cycle_duration
		current_anim_frame = int((anim_timer / cycle_duration) * frame_count)
		current_anim_frame = clampi(current_anim_frame, 0, frame_count - 1)

	_update_sprite_frame()


func _update_sprite_frame() -> void:
	var row: int = SPRITE_ROW_MAP[facing as int]
	sprite.frame = (row * sprite.hframes) + clampi(current_anim_frame, 0, _current_hframes - 1)


func _get_cycle_duration() -> float:
	match current_state:
		AIState.IDLE:
			return IDLE_CYCLE
		AIState.WANDER, AIState.CHASE:
			return WALK_CYCLE
		AIState.HURT:
			return HURT_CYCLE
		AIState.DEATH:
			return DEATH_CYCLE
	return IDLE_CYCLE


# --- Direction ---

func _update_facing_from_velocity(dir: Vector2) -> void:
	if dir.length_squared() < 0.01:
		return

	var new_facing: Direction = facing

	if absf(dir.x) > absf(dir.y):
		if dir.x > 0.0:
			new_facing = Direction.RIGHT
		else:
			new_facing = Direction.LEFT
	else:
		if dir.y > 0.0:
			new_facing = Direction.DOWN
		else:
			new_facing = Direction.UP

	facing = new_facing


# --- Signal Callbacks ---

func _on_hurtbox_area_entered(area: Area2D) -> void:
	if area.is_in_group("player_hitbox"):
		var dmg: int = 1
		if area.has_meta("damage"):
			dmg = area.get_meta("damage") as int
		elif area.has_method("get_damage"):
			dmg = area.get_damage()
		take_damage(dmg, area.global_position)


func _on_aggro_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and body.collision_layer & 2:
		_target_player = body as CharacterBody2D
		if slime_variant > 1 and current_state != AIState.HURT and current_state != AIState.DEATH:
			_enter_chase()


func _on_aggro_body_exited(body: Node2D) -> void:
	if body == _target_player:
		_target_player = null
		if current_state == AIState.CHASE:
			_enter_idle()


func _on_death_timer() -> void:
	queue_free()
