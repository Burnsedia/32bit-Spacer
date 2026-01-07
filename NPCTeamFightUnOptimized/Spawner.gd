extends Node3D

@export var item_path = ""
@export var x_count = 1
@export var y_count = 1
@export var z_count = 1
@export var spacing = 1

#TODO:refactor not to be not to be O(N^3) time complexity
func _ready():
	var obj = load(item_path)
	for x in range(x_count):
		for y in range(y_count):
			for z in range(z_count):
				var inst = obj.instantiate()
				add_child(inst)
				inst.transform.origin = Vector3(x, y, z) * spacing
