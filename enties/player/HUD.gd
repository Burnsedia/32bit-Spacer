extends CanvasLayer

@onready var health_bar = $HealthBar
@onready var health_label = $HealthLabel
@onready var xp_bar = $XPBar
@onready var xp_label = $XPLabel
@onready var level_label = $LevelLabel
@onready var weapon_status = $WeaponStatus

var player: Node3D = null

func _ready():
	# Find player in scene
	player = get_tree().get_first_node_in_group("player")
	if player:
		player.health_changed.connect(_on_player_health_changed)
		player.level_up.connect(_on_player_level_up)
		player.xp_gained.connect(_on_player_xp_gained)
		update_display()

func _process(_delta):
	if player:
		update_display()

func update_display():
	if not player:
		return

	# Update health
	health_bar.max_value = player.max_health
	health_bar.value = player.health
	health_label.text = "%d/%d HP" % [player.health, player.max_health]

	# Update XP
	xp_bar.max_value = player.xp_to_next_level
	xp_bar.value = player.xp
	xp_label.text = "%d/%d XP" % [player.xp, player.xp_to_next_level]

	# Update level
	level_label.text = "Level %d" % player.level

	# Update weapon status (placeholder)
	weapon_status.text = "Weapon: Ready"

func _on_player_health_changed(new_health):
	update_display()

func _on_player_level_up(new_level):
	update_display()

func _on_player_xp_gained(amount):
	update_display()