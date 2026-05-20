extends CharacterBody2D
## Dragon boss enemy.
## Uses a custom 5x3 sprite sheet (dragon.png) for animations.

# --- Enums ---
enum Direction { DOWN = 0, LEFT = 1, RIGHT = 2, UP = 3 }
enum AIState { IDLE, WANDER, CHASE, ATTACK, HURT, DEATH }

# --- Constants ---
const SPRITE_PATH: String = "res://assets/rpg/sprites/enemies/dragon.png"

# Animation frame counts (using 4x3 sheet)
const IDLE_FRAMES: int = 2
const WALK_FRAMES: int = 4
const ATTACK_FRAMES: int = 4
const HURT_FRAMES: int = 2
const DEATH_FRAMES: int = 2

# Animation cycle durations in seconds
const IDLE_CYCLE: float = 0.6
const WALK_CYCLE: float = 0.6
const ATTACK_CYCLE: float = 0.5
const HURT_CYCLE: float = 0.3
const DEATH_CYCLE: float = 1.0

# AI Timings
const IDLE_TIME_MIN: float = 1.0
const IDLE_TIME_MAX: float = 2.0
const WANDER_TIME_MIN: float = 1.0
const WANDER_TIME_MAX: float = 2.0

# --- Export Variables ---
@export_group("Stats")
@export var max_hp: int = 12
@export var damage: int = 2
@export var speed: float = 45.0
@export var aggro_range: float = 999.0
@export var attack_range: float = 80.0
@export var attack_cooldown: float = 1.2

@export_group("Drops")
@export var drop_resource: String = "iron_ore"
@export var drop_chance: float = 1.0

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

# Animation
var anim_timer: float = 0.0
var current_anim_frame: int = 0
var _current_hframes: int = 4
var _current_row: int = 0

# AI Timers
var state_timer: float = 0.0
var wander_direction: Vector2 = Vector2.ZERO
var attack_cooldown_timer: float = 0.0
var _target_player: CharacterBody2D = null


# --- Lifecycle ---

func _ready() -> void:
	current_hp = max_hp
	
	# Load texture
	var tex = load(SPRITE_PATH)
	if tex:
		sprite.texture = tex
	sprite.hframes = 4
	sprite.vframes = 3
	
	# Initial animation
	_set_anim(0, IDLE_FRAMES)
	
	# Configure aggro range
	var aggro_circle = aggro_shape.shape as CircleShape2D
	if aggro_circle:
		aggro_circle.radius = aggro_range
		
	# Disable hitbox shape initially
	hitbox_shape.disabled = true
	hitbox.set_meta("damage", damage)
	hitbox.add_to_group("enemy_hitbox")
	
	# Connect signals
	hurtbox.area_entered.connect(_on_hurtbox_area_entered)
	aggro_area.body_entered.connect(_on_aggro_body_entered)
	aggro_area.body_exited.connect(_on_aggro_body_exited)
	
	# Start idle
	state_timer = randf_range(IDLE_TIME_MIN, IDLE_TIME_MAX)


func _physics_process(delta: float) -> void:
	if _is_dead:
		_animate(delta)
		return
		
	# Update cooldown timer
	if attack_cooldown_timer > 0.0:
		attack_cooldown_timer -= delta
		
	# State machine
	match current_state:
		AIState.IDLE:
			_process_idle(delta)
		AIState.WANDER:
			_process_wander(delta)
		AIState.CHASE:
			_process_chase(delta)
		AIState.ATTACK:
			_process_attack(delta)
		AIState.HURT:
			_process_hurt(delta)
		AIState.DEATH:
			pass
			
	# Update hitbox position based on facing direction
	_update_hitbox_position()
	
	# Animate
	_animate(delta)


# --- AI State Processing ---

func _process_idle(delta: float) -> void:
	velocity = Vector2.ZERO
	state_timer -= delta
	
	# Check if player in aggro range
	if _target_player != null:
		_enter_chase()
		return
		
	if state_timer <= 0.0:
		_enter_wander()


func _process_wander(delta: float) -> void:
	velocity = wander_direction * speed
	move_and_slide()
	state_timer -= delta
	
	if _target_player != null:
		_enter_chase()
		return
		
	if state_timer <= 0.0:
		_enter_idle()


func _process_chase(_delta: float) -> void:
	if not is_instance_valid(_target_player) or _target_player == null:
		_enter_idle()
		return
		
	var dist = global_position.distance_to(_target_player.global_position)
	
	# Check if in attack range and cooldown ready
	if dist <= attack_range and attack_cooldown_timer <= 0.0:
		_enter_attack()
		return
		
	# Keep moving towards player
	var dir = global_position.direction_to(_target_player.global_position)
	velocity = dir * speed
	_update_facing_from_velocity(dir)
	move_and_slide()


func _process_attack(delta: float) -> void:
	velocity = Vector2.ZERO
	state_timer -= delta
	
	# Enable hitbox on fire breath active frames (2 and 3)
	if current_anim_frame >= 2 and current_anim_frame <= 3:
		hitbox_shape.disabled = false
	else:
		hitbox_shape.disabled = true
		
	if state_timer <= 0.0:
		hitbox_shape.disabled = true
		attack_cooldown_timer = attack_cooldown
		if _target_player != null:
			_enter_chase()
		else:
			_enter_idle()


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
	_set_anim(0, IDLE_FRAMES)


func _enter_wander() -> void:
	current_state = AIState.WANDER
	state_timer = randf_range(WANDER_TIME_MIN, WANDER_TIME_MAX)
	
	# Pick random direction
	var angle = randf() * TAU
	wander_direction = Vector2(cos(angle), sin(angle))
	_update_facing_from_velocity(wander_direction)
	_set_walk_anim()


func _enter_chase() -> void:
	current_state = AIState.CHASE
	_set_walk_anim()


func _enter_attack() -> void:
	current_state = AIState.ATTACK
	state_timer = ATTACK_CYCLE
	velocity = Vector2.ZERO
	
	# Lock facing direction towards player
	if _target_player != null:
		var dir = global_position.direction_to(_target_player.global_position)
		_update_facing_from_velocity(dir)
		
	_set_anim(2, ATTACK_FRAMES)


func _enter_hurt(from_position: Vector2) -> void:
	current_state = AIState.HURT
	state_timer = HURT_CYCLE
	hitbox_shape.set_deferred("disabled", true)
	
	# Knockback
	var knockback_dir = from_position.direction_to(global_position)
	velocity = knockback_dir * speed * 2.0
	move_and_slide()
	
	_flash_damage()
	_set_anim(0, HURT_FRAMES) # Flash on Idle pose


func _enter_death() -> void:
	_is_dead = true
	current_state = AIState.DEATH
	velocity = Vector2.ZERO
	hitbox_shape.set_deferred("disabled", true)
	
	# Disable collision shapes
	for child in hurtbox.get_children():
		if child is CollisionShape2D:
			child.set_deferred("disabled", true)
			
	for child in hitbox.get_children():
		if child is CollisionShape2D:
			child.set_deferred("disabled", true)
			
	$BodyCollision.set_deferred("disabled", true)
	
	_set_anim(0, DEATH_FRAMES)
	
	_try_drop_resource()
	
	# Trigger boss victory notification
	if GameManager:
		GameManager.defeat_boss()
	
	# Fade out and queue_free
	var tween = create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, DEATH_CYCLE)
	tween.tween_callback(queue_free)


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


func _try_drop_resource() -> void:
	if randf() <= drop_chance:
		if GameManager:
			GameManager.add_resource(drop_resource, 1)


func _flash_damage() -> void:
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(1.0, 0.3, 0.3, 1.0), 0.05)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
	tween.tween_property(sprite, "modulate", Color(1.0, 0.3, 0.3, 1.0), 0.05)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)


# --- Animation & Orientation ---

func _set_anim(row: int, hframes: int) -> void:
	_current_row = row
	_current_hframes = hframes
	anim_timer = 0.0
	current_anim_frame = 0
	_update_sprite_frame()


func _set_walk_anim() -> void:
	_set_anim(1, WALK_FRAMES)


func _animate(delta: float) -> void:
	var frame_count: int = _current_hframes
	var cycle_duration: float = _get_cycle_duration()
	
	anim_timer += delta
	
	if current_state == AIState.DEATH or current_state == AIState.HURT:
		current_anim_frame = mini(int(anim_timer / cycle_duration * frame_count), frame_count - 1)
	else:
		if anim_timer >= cycle_duration:
			anim_timer -= cycle_duration
		current_anim_frame = int((anim_timer / cycle_duration) * frame_count)
		current_anim_frame = clampi(current_anim_frame, 0, frame_count - 1)
		
	_update_sprite_frame()


func _update_sprite_frame() -> void:
	sprite.frame = (_current_row * sprite.hframes) + clampi(current_anim_frame, 0, _current_hframes - 1)


func _get_cycle_duration() -> float:
	match current_state:
		AIState.IDLE:
			return IDLE_CYCLE
		AIState.WANDER, AIState.CHASE:
			return WALK_CYCLE
		AIState.ATTACK:
			return ATTACK_CYCLE
		AIState.HURT:
			return HURT_CYCLE
		AIState.DEATH:
			return DEATH_CYCLE
	return IDLE_CYCLE


func _update_facing_from_velocity(dir: Vector2) -> void:
	if dir.length_squared() < 0.01:
		return
		
	var new_facing: Direction = facing
	
	if dir.x > 0.0:
		new_facing = Direction.RIGHT
		sprite.flip_h = false
	elif dir.x < 0.0:
		new_facing = Direction.LEFT
		sprite.flip_h = true
		
	var changed = (facing != new_facing)
	facing = new_facing
	
	if (current_state == AIState.WANDER or current_state == AIState.CHASE) and changed:
		_set_walk_anim()


func _update_hitbox_position() -> void:
	# Large hitbox for a boss
	if sprite.flip_h:
		hitbox.position = Vector2(-140, 0)
	else:
		hitbox.position = Vector2(140, 0)


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
		if current_state != AIState.HURT and current_state != AIState.DEATH and current_state != AIState.ATTACK:
			_enter_chase()


func _on_aggro_body_exited(body: Node2D) -> void:
	if body == _target_player:
		_target_player = null
		if current_state == AIState.CHASE:
			_enter_idle()
