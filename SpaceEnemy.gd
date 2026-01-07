extends CharacterBody3D

@export var max_health: int = 50
@export var health: int = 50
@export var damage: int = 10
@export var xp_value: int = 25

var player: Node3D = null

@onready var mesh = $MeshInstance3D

func _ready():
	# Find player
	player = get_tree().get_first_node_in_group("player")
	
	# Set up enemy appearance
	if mesh:
		var material = StandardMaterial3D.new()
		material.albedo_color = Color(1, 0.2, 0.2)  # Red enemy
		mesh.material_override = material

func _physics_process(delta):
	if not player:
		return
	
	# Simple AI: Move toward player
	var direction = (player.global_position - global_position).normalized()
	velocity = direction * 10.0  # Move speed
	move_and_slide()

func take_damage(amount: int):
	health -= amount
	print("Enemy took ", amount, " damage, health now: ", health)
	
	if health <= 0:
		die()

func die():
	# Award XP to player
	if player and player.has_method("gain_xp"):
		player.gain_xp(xp_value)
	
	# Visual effect
	if mesh:
		var material = mesh.material_override
		if material:
			material.emission_enabled = true
			material.emission = Color(1, 0.5, 0)  # Orange explosion effect
	
	# Remove after short delay
	await get_tree().create_timer(0.5).timeout
	queue_free()
	print("Enemy destroyed!")