extends Camera3d


# Declare member variables here. Examples:
# var a = 2
# var b = "text"
@onready var target = get_parent()

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	look_at(target, Vector3.UP)
