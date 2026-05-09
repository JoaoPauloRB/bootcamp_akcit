extends CharacterBody2D
## Skeleton enemy with optional boss variant (Skeleton Warrior).
## Side-view sprites only — uses flip_h for left/right direction.
## Different frame sizes per animation: Idle=32x32, Run=64x64, Death varies.

# --- Enums ---
enum AIState { IDLE, PATROL, CHASE, HURT, DEATH }

# --- Constants ---
const BASE_SPRITE_PATH: String = "res://assets/rpg/sprites/enemies/pixel-crawler/Skeleton Crew/"

## Skeleton Base texture paths
const BASE_TEXTURES: Dictionary = {
	"idle": BASE_SPRITE_PATH + "Skeleton - Base/Idle/Idle-Sheet.png",
	"run": BASE_SPRITE_PATH + "Skeleton - Base/Run/Run-Sheet.png",
	"death": BASE_SPRITE_PATH + "Skeleton - Base/Death/Death-Sheet.png",
}

## Skeleton Warrior (Boss) texture paths
const WARRIOR_TEXTURES: Dictionary = {
	"idle": BASE_SPRITE_PATH + "Skeleton - Warrior/Idle/Idle-Sheet.png",
	"run": BASE_SPRITE_PATH + "Skeleton - Warrior/Run/Run-Sheet.png",
	"death": BASE_SPRITE_PATH + "Skeleton - Warrior/Death/Death-Sheet.png",
}

## Frame layout per animation: [hframes, vframes, used_frames]
## Base skeleton
const BASE_FRAMES: Dictionary = {
	"idle": [4, 1, 4],
	"run": [6, 1, 6],
	"death": [12, 1, 8],
}

## Warrior skeleton (boss)
const WARRIOR_FRAMES: Dictionary = {
	"idle": [4, 1, 4],
	"run": [6, 1, 6],
	"death": [8, 1, 8],
}

## Animation cycle durations in seconds
const IDLE_CYCLE: float = 0.8
const RUN_CYCLE: float = 0.6
const HURT_CYCLE: float = 0.2
const DEATH_CYCLE: float = 0.8

## Patrol timing
const IDLE_TIME_MIN: float = 1.0
const IDLE_TIME_MAX: float = 2.5
const PATROL_TIME_MIN: float = 1.5
const PATROL_TIME_MAX: float = 3.0

## Contact damage re-hit cooldown
const CONTACT_DAMAGE_INTERVAL: float = 1.0

# --- Export Variables ---
@export_group("Variant")
@export var is_boss: bool = false

@export_group("Stats")
@export var max_hp: int = 4
@export var damage: int = 2
@export var speed: float = 50.0
@export var aggro_range: float = 96.0

@export_group("Drops")
@export var drop_resource: String = "bone_shard"
@export var drop_chance: float = 0.6

# --- Node References ---
@onready var sprite: Sprite2D = $Sprite
@onready var hurtbox: Area2D = $Hurtbox
@onready var hitbox: Area2D = $Hitbox
@onready var hitbox_shape: CollisionShape2D = $Hitbox/HitboxShape
@onready var aggro_area: Area2D = $AggroRange
@onready var aggro_shape: CollisionShape2D = $AggroRange/AggroShape

# --- State ---
var current_state: AIState = AIState.IDLE
var current_hp: int = 0
var _is_dead: bool = false

## Animation
var anim_timer: float = 0.0
var current_anim_frame: int = 0
var _current_used_frames: int = 4
var _current_anim_name: String = "idle"

## AI timers
var state_timer: float = 0.0
var patrol_direction: float = 1.0
var contact_damage_timer: float = 0.0

## Cached textures
var _tex_idle: Texture2D
var _tex_run: Texture2D
var _tex_death: Texture2D

## Frame data reference
var _frame_data: Dictionary = {}

## Player reference for chase
var _target_player: CharacterBody2D = null


# --- Lifecycle ---

func _ready() -> void:
	current_hp = max_hp

	# Load textures based on variant
	_load_textures()

	# Apply boss scaling (2x for all — boss is visually the same sprite set)
	sprite.scale = Vector2(2, 2)

	# Set initial animation
	_set_anim("idle")

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
		AIState.PATROL:
			_process_patrol(delta)
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
		_enter_patrol()


func _process_patrol(delta: float) -> void:
	velocity = Vector2(patrol_direction * speed, 0.0)
	sprite.flip_h = patrol_direction < 0.0
	move_and_slide()
	state_timer -= delta

	if state_timer <= 0.0:
		_enter_idle()


func _process_chase(_delta: float) -> void:
	if not is_instance_valid(_target_player) or _target_player == null:
		_enter_idle()
		return

	var dir: Vector2 = global_position.direction_to(_target_player.global_position)
	velocity = dir * speed

	# Flip sprite based on horizontal direction
	if absf(dir.x) > 0.01:
		sprite.flip_h = dir.x < 0.0

	move_and_slide()


func _process_hurt(delta: float) -> void:
	state_timer -= delta
	# Apply knockback deceleration
	velocity = velocity.move_toward(Vector2.ZERO, speed * 4.0 * delta)
	move_and_slide()

	if state_timer <= 0.0:
		if _target_player != null:
			_enter_chase()
		else:
			_enter_idle()


# --- State Transitions ---

func _enter_idle() -> void:
	current_state = AIState.IDLE
	state_timer = randf_range(IDLE_TIME_MIN, IDLE_TIME_MAX)
	velocity = Vector2.ZERO
	_set_anim("idle")


func _enter_patrol() -> void:
	current_state = AIState.PATROL
	state_timer = randf_range(PATROL_TIME_MIN, PATROL_TIME_MAX)

	# Alternate patrol direction
	patrol_direction = -patrol_direction
	sprite.flip_h = patrol_direction < 0.0
	_set_anim("run")


func _enter_chase() -> void:
	current_state = AIState.CHASE
	_set_anim("run")


func _enter_hurt(from_position: Vector2) -> void:
	current_state = AIState.HURT
	state_timer = 0.2

	# Knockback away from damage source
	var knockback_dir: Vector2 = from_position.direction_to(global_position)
	velocity = knockback_dir * speed * 3.0
	move_and_slide()

	# Flash red
	_flash_damage()

	# Keep current run texture during hurt (no dedicated hurt sheet)
	# Just use the idle texture as "stunned"
	_set_anim("idle")


func _enter_death() -> void:
	_is_dead = true
	current_state = AIState.DEATH
	velocity = Vector2.ZERO
	_set_anim("death")

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

	# Boss defeat notification
	if is_boss and GameManager:
		GameManager.defeat_boss()

	# Queue free after death animation
	var death_duration: float = DEATH_CYCLE + 0.3
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

func _load_textures() -> void:
	var tex_paths: Dictionary = WARRIOR_TEXTURES if is_boss else BASE_TEXTURES
	_frame_data = WARRIOR_FRAMES if is_boss else BASE_FRAMES

	_tex_idle = load(tex_paths["idle"])
	_tex_run = load(tex_paths["run"])
	_tex_death = load(tex_paths["death"])


func _set_anim(anim_name: String) -> void:
	if _current_anim_name == anim_name and current_state != AIState.HURT:
		return

	_current_anim_name = anim_name
	var frame_info: Array = _frame_data.get(anim_name, [4, 1, 4])
	var hframes_val: int = frame_info[0] as int
	var vframes_val: int = frame_info[1] as int
	_current_used_frames = frame_info[2] as int

	# Select texture
	var tex: Texture2D = _tex_idle
	match anim_name:
		"run":
			tex = _tex_run
		"death":
			tex = _tex_death

	sprite.texture = tex
	sprite.hframes = hframes_val
	sprite.vframes = vframes_val
	anim_timer = 0.0
	current_anim_frame = 0
	_update_sprite_frame()


func _animate(delta: float) -> void:
	var frame_count: int = _current_used_frames
	var cycle_duration: float = _get_cycle_duration()

	anim_timer += delta

	if current_state == AIState.DEATH:
		# Play once, freeze on last frame
		current_anim_frame = mini(int(anim_timer / cycle_duration * frame_count), frame_count - 1)
	elif current_state == AIState.HURT:
		# Brief stun — just hold first frame
		current_anim_frame = 0
	else:
		# Looping
		if anim_timer >= cycle_duration:
			anim_timer -= cycle_duration
		current_anim_frame = int((anim_timer / cycle_duration) * frame_count)
		current_anim_frame = clampi(current_anim_frame, 0, frame_count - 1)

	_update_sprite_frame()


func _update_sprite_frame() -> void:
	# Single-row sheets — frame = column index directly
	sprite.frame = clampi(current_anim_frame, 0, _current_used_frames - 1)


func _get_cycle_duration() -> float:
	match current_state:
		AIState.IDLE:
			return IDLE_CYCLE
		AIState.PATROL, AIState.CHASE:
			return RUN_CYCLE
		AIState.HURT:
			return HURT_CYCLE
		AIState.DEATH:
			return DEATH_CYCLE
	return IDLE_CYCLE


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
		if current_state != AIState.HURT and current_state != AIState.DEATH:
			_enter_chase()


func _on_aggro_body_exited(body: Node2D) -> void:
	if body == _target_player:
		_target_player = null
		if current_state == AIState.CHASE:
			_enter_idle()


func _on_death_timer() -> void:
	queue_free()
