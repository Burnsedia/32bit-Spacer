extends CharacterBody3D

# Ship movement constants
const MAX_SPEED = 25.0
const ACCELERATION = 15.0
const FRICTION = 8.0
const BOOST_MULTIPLIER = 2.5
const BRAKE_MULTIPLIER = 0.3

# Ship rotation constants
const MOUSE_SENSITIVITY = 0.002
const ROTATION_SPEED = 2.0
const MAX_PITCH = deg_to_rad(60)
const MAX_ROLL = deg_to_rad(45)

# Ship stats
@export var health: int = 100
@export var max_health: int = 100
@export var level: int = 1
@export var xp: int = 0
@export var xp_to_next_level: int = 100

# Movement variables
var input_vector = Vector3()
var is_boosting = false
var is_braking = false

# Rotation variables
var rotation_target = Vector3()
var camera_rotation = Vector3()

# Weapon system (will be expanded)
var weapon_cooldown = 0.0
const WEAPON_COOLDOWN_TIME = 0.2

# Signals
signal health_changed(new_health)
signal level_up(new_level)
signal xp_gained(amount)

@onready var camera = $Camera3D if has_node("Camera3D") else null

func _ready():
	add_to_group("player")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if camera:
		camera_rotation = camera.rotation

func _input(event):
	if event is InputEventMouseMotion:
		# Mouse look for aiming
		var mouse_delta = event.relative * MOUSE_SENSITIVITY
		rotation_target.y -= mouse_delta.x
		rotation_target.x -= mouse_delta.y
		rotation_target.x = clamp(rotation_target.x, -MAX_PITCH, MAX_PITCH)

func _physics_process(delta):
	handle_input()
	handle_movement(delta)
	handle_rotation(delta)
	handle_weapon_system(delta)

func handle_input():
	# Movement input
	input_vector = Vector3()
	if Input.is_action_pressed("move_forward"):
		input_vector.z -= 1
	if Input.is_action_pressed("move_backward"):
		input_vector.z += 1
	if Input.is_action_pressed("move_left"):
		input_vector.x -= 1
	if Input.is_action_pressed("move_right"):
		input_vector.x += 1
	if Input.is_action_pressed("move_up"):
		input_vector.y += 1
	if Input.is_action_pressed("move_down"):
		input_vector.y -= 1

	input_vector = input_vector.normalized()

	# Boost and brake
	is_boosting = Input.is_action_pressed("boost")
	is_braking = Input.is_action_pressed("brake")

func handle_movement(delta):
	var target_speed = MAX_SPEED
	if is_boosting:
		target_speed *= BOOST_MULTIPLIER
	elif is_braking:
		target_speed *= BRAKE_MULTIPLIER

	# Apply acceleration in ship-local space
	var local_acceleration = input_vector * ACCELERATION * delta
	velocity += transform.basis * local_acceleration

	# Apply friction
	var friction_force = velocity.normalized() * FRICTION * delta
	if velocity.length() > friction_force.length():
		velocity -= friction_force
	else:
		velocity = Vector3()

	# Clamp velocity to max speed
	if velocity.length() > target_speed:
		velocity = velocity.normalized() * target_speed

	# Move the ship
	set_velocity(velocity)
	move_and_slide()

func handle_rotation(delta):
	# Smooth rotation towards target
	rotation.y = lerp_angle(rotation.y, rotation_target.y, ROTATION_SPEED * delta)
	rotation.x = lerp_angle(rotation.x, rotation_target.x, ROTATION_SPEED * delta)

	# Add roll based on horizontal input
	var roll_target = input_vector.x * MAX_ROLL
	rotation.z = lerp_angle(rotation.z, roll_target, ROTATION_SPEED * delta)

func handle_weapon_system(delta):
	weapon_cooldown -= delta
	if Input.is_action_pressed("fire_weapon") and weapon_cooldown <= 0:
		fire_weapon()
		weapon_cooldown = WEAPON_COOLDOWN_TIME

func fire_weapon():
	# Spawn laser projectile
	var projectile_scene = preload("res://player/LaserProjectile.tscn")
	var projectile = projectile_scene.instantiate()
	
	# Position at ship muzzle (approximate)
	projectile.position = global_position + transform.basis.z * 2
	
	# Set velocity based on ship facing direction
	var ship_velocity = velocity * 0.5  # Add some ship momentum
	projectile.set_velocity(-transform.basis.z, ship_velocity)
	
	# Add to scene
	get_parent().add_child(projectile)
	print("Pew! Firing weapon")

func take_damage(amount: int):
	health -= amount
	health = max(0, health)
	health_changed.emit(health)
	if health <= 0:
		die()

func heal(amount: int):
	health += amount
	health = min(max_health, health)
	health_changed.emit(health)

func gain_xp(amount: int):
	xp += amount
	xp_gained.emit(amount)

	while xp >= xp_to_next_level:
		level_up_ship()

func level_up_ship():
	xp -= xp_to_next_level
	level += 1
	xp_to_next_level = level * 100

	# Level up bonuses
	max_health += 10
	health = max_health  # Full heal on level up

	level_up.emit(level)
	print("Leveled up to level ", level)

func die():
	print("Ship destroyed!")
	# TODO: Game over logic
