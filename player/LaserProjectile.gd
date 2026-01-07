extends Area3D

# Weapon properties
@export var damage: int = 15
@export var speed: float = 50.0
@export var lifetime: float = 3.0

var velocity: Vector3 = Vector3()
var timer: float = 0.0

func _ready():
	# Set up visual appearance
	var mesh = CylinderMesh.new()
	mesh.top_radius = 0.05
	mesh.bottom_radius = 0.05
	mesh.height = 1.0
	
	var material = StandardMaterial3D.new()
	material.emission_enabled = true
	material.emission = Color(0, 1, 1)  # Cyan laser
	material.emission_energy_multiplier = 2.0
	
	$MeshInstance3D.mesh = mesh
	$MeshInstance3D.material_override = material
	
	# Connect collision signal
	body_entered.connect(_on_body_entered)

func _physics_process(delta):
	# Move the projectile
	position += velocity * delta
	
	# Update lifetime
	timer += delta
	if timer >= lifetime:
		queue_free()

func _on_body_entered(body):
	# Hit something
	if body.has_method("take_damage"):
		body.take_damage(damage)
	queue_free()

func set_velocity(direction: Vector3, ship_velocity: Vector3 = Vector3()):
	velocity = direction.normalized() * speed + ship_velocity