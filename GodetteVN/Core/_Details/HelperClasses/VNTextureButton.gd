extends TextureButton
class_name VNTextureButton

func _ready():
	var _err1 = self.connect("mouse_entered", vn.Utils, "no_mouse")
	var _err2 = self.connect("mouse_exited", vn.Utils, "yes_mouse")

