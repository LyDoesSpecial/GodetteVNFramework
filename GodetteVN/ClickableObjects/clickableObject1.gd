extends ClickableObject

# My customization for hover... It's best to make sure noMouse = true when
# mouse enters and when it exits.
func _on_object1_mouse_entered():
	vn.noMouse = true # This is unnecessary if you use GDscene:idle to pause the 
	# game.
	self.material = load("res://GodetteVN/Shaders/sprite_outline.tres")

func _on_object1_mouse_exited():
	vn.noMouse = false
	self.material = null
