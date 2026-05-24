extends Area2D
## Blue magical projectile fired by the Witch enemy.

# --- Export Variables ---
@export var speed: float = 120.0
@export var damage: int = 1

# --- State ---
var direction: Vector2 = Vector2.ZERO

# --- Node References ---
@onready var particles: CPUParticles2D = $Particles

func _ready() -> void:
	# Add to enemy hitbox group so player can detect it via hurtbox
	add_to_group("enemy_hitbox")
	set_meta("damage", damage)
	
	# Connect collision signals
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	
	# Auto-destroy after 3.0 seconds if it flies off-screen
	get_tree().create_timer(3.0).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	queue_redraw()

func _draw() -> void:
	# Draw a beautiful glowing blue magic projectile
	# Outer glow
	draw_circle(Vector2.ZERO, 8.0, Color(0.2, 0.6, 1.0, 0.4))
	# Mid glow
	draw_circle(Vector2.ZERO, 5.0, Color(0.1, 0.4, 1.0, 0.8))
	# Bright core
	draw_circle(Vector2.ZERO, 2.5, Color(0.8, 0.9, 1.0, 1.0))

func _on_body_entered(body: Node2D) -> void:
	# Hit player or world wall
	if body is CharacterBody2D and body.collision_layer & 2:
		# Player hit
		if body.has_method("take_damage"):
			body.take_damage(damage, global_position)
		_destroy()
	elif body.collision_layer & 1:
		# Hit wall/world
		_destroy()

func _on_area_entered(area: Area2D) -> void:
	# Detect player's hurtbox as well just in case
	if area.is_in_group("player_hurtbox"):
		var parent = area.get_parent()
		if parent and parent.has_method("take_damage"):
			parent.take_damage(damage, global_position)
		_destroy()

func _destroy() -> void:
	# Disable collision and wait for particles to die out
	set_physics_process(false)
	monitoring = false
	monitorable = false
	visible = false
	if particles:
		particles.emitting = false
		get_tree().create_timer(0.4).timeout.connect(queue_free)
	else:
		queue_free()
