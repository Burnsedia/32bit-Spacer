extends KinematicBody


# Declare member variables here. Examples:
# var a = 2
# var b = "text"
onready var path = get_parent()
onready var detect_npcs_area = $Area


var move_speed = 3
var cur_attack_time = 0.0
var health = 5
var target = null
var nearby_allies = []
var nearby_enemies = []
var cur_target : Spatial

var underAttact = false

enum STATE { patrole, attack, flee}
enum TEAM {human, xeno}

export(TEAM) var team
export(STATE) var state 

export var speed = 42
export var attack_range = 2.0
export var attack_rate = 0.5
# Called when the node enters the scene tree for the first time.
func _ready():
	state = STATE.patrole
	team = randi() % 2
	


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	update_cur_target()

func _physics_process(delta):
	match state:
		STATE.patrole:
			patroleState(delta)

func patroleState(delta):
	path.offset += speed * delta
#	if in_attack_range_of_cur_target():
##		state = STATE.attack
#
#
#func attactState(detla):
#	var target_pos = cur_target.global_transform.origin - global_transform.origin
#	move_and_slide(target_pos, Vector3.UP)
#	if !cur_target:
#		state = STATE.patrole
#
#func fleeState(delta):
#	if !underAttact:
#		state = STATE.patrole
#
#


func _on_Area_body_entered(body):
	var vec_to_body	= body.transform.orgin - self.transform.origin
	pass
	
