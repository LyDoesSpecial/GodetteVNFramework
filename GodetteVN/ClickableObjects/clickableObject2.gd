extends ClickableObject


func _on_object2_mouse_entered():
	vn.noMouse = true
	# game.
	self.material = load("res://GodetteVN/Shaders/sprite_outline.tres")

func _on_object2_mouse_exited():
	vn.noMouse = false
	self.material = null
