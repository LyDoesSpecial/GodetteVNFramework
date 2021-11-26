extends CanvasLayer
class_name VNScreen

func _ready():
	vn.inSetting = true
	
func _on_returnButton_pressed():
	vn.inSetting = false
	self.queue_free()

func _input(ev):
	if ev.is_action_pressed('ui_cancel') or ev.is_action_pressed('vn_cancel'):
		get_tree().set_input_as_handled()
		_on_returnButton_pressed()
		
