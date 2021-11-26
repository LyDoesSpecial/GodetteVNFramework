extends TextureButton
class_name ClickableObject

export(String) var change_to_on_click = ''

func _ready():
	var _error = self.connect('pressed', self, '_on_pressed')
	
func _on_pressed():
	# This will give us the root of the vn scene. (if you also put clickable
	# objects as subnodes in clickables node.)
	var dialog_node = get_parent().get_parent()
	if dialog_node.allow_rollback:
		vn.Pgs.makeSnapshot()
	dialog_node.generate_nullify()
	dialog_node.change_block_to(change_to_on_click, 0)

