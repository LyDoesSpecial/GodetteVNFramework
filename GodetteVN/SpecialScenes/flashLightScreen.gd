extends Light2D

# Called when the node enters the scene tree for the first time.
func _ready():
	position = get_viewport().get_mouse_position()

func _process(_delta):
	if not vn.inSetting and not vn.inNotif:
		position = get_viewport().get_mouse_position()
