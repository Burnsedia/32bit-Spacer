extends Node

@export var max_health: int = 50
@export var health: int = 50

var parent_node = get_parent()

#remove the entiy from the scenetree
func die(args):
   	parent_node.queue_free()

func take_damage(damage):
	health =- damage

func heal(healPoints):
	if health < max_health:
		health += healPoints
