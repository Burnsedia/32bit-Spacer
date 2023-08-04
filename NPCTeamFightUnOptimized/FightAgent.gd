extends KinematicBody


enum TEAMS {SOLDIERS, BANDITS}
export(TEAMS) var team

var nearby_allies = []
var nearby_enemies = []
var cur_target : Spatial

var move_speed = 3
export var attack_range = 2.0
export var attack_rate = 0.5
var cur_attack_time = 0.0
var health = 5

onready var detect_npcs_area = $Area

func _ready():
	team = randi() % 2
	if team == TEAMS.SOLDIERS:
		show_red()
	else:
		show_yellow()

func _process(delta):
	update_cur_target()

func _physics_process(delta):
	if !is_instance_valid(cur_target):
		return
	
	if in_attack_range_of_cur_target():
		cur_attack_time += delta
		if cur_attack_time >= attack_rate:
			cur_attack_time = 0.0
			cur_target.damage()
	else:
		var move_vec = cur_target.global_transform.origin - global_transform.origin
		move_vec.y = 0.0
		move_vec = move_vec.normalized()
		move_and_collide(move_speed * delta * move_vec)

func damage():
	health -= 1
	if health <= 0:
		queue_free()

func in_attack_range_of_cur_target():
	var dist = global_transform.origin.distance_squared_to(cur_target.global_transform.origin)
	return dist < attack_range * attack_range

func update_nearby_npcs():
	nearby_allies = []
	nearby_enemies = []
	for npc in detect_npcs_area.get_overlapping_bodies():
		if !is_instance_valid(npc) or !"team" in npc:
			continue
		if npc.team == team:
			nearby_allies.append(npc)
		else:
			nearby_enemies.append(npc)

func update_cur_target():
	update_nearby_npcs()
	cur_target = get_closest_enemy()
	if is_instance_valid(cur_target):
		return
	for ally in nearby_allies:
		if is_instance_valid(ally) and is_instance_valid(ally.cur_target):
			cur_target = ally.cur_target
			return

func get_closest_enemy():
	var closest_enemy = null
	var dist = -1
	for enemy in nearby_enemies:
		if !is_instance_valid(enemy):
			continue
		var d = global_transform.origin.distance_squared_to(enemy.global_transform.origin)
		if dist < 0.0 or d < dist:
			dist = d
			closest_enemy = enemy
	return closest_enemy

func show_red():
	$Graphics/Red.show()
	$Graphics/Yellow.hide()

func show_yellow():
	$Graphics/Red.hide()
	$Graphics/Yellow.show()
