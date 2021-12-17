extends TextureButton
class_name VNTextureButton

func _ready():
	var _e:int = self.connect("mouse_entered", vn.Utils, "no_mouse")
	_e = self.connect("mouse_exited", vn.Utils, "yes_mouse")

