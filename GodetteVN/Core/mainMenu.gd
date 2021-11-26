extends CanvasLayer

var last_hover : int = -1

# Preload to make this process faster ? Is this really necessary?
var saver = preload("res://GodetteVN/Core/SNL/saveMainBox.tscn")
var loader = preload("res://GodetteVN/Core/SNL/loadMainBox.tscn")
var setting = preload("res://GodetteVN/Core/SettingsScreen/settingMainBox.tscn")
var hist = preload("res://GodetteVN/Core/HistoryScreen/historyMainBox.tscn")
var items = [null,saver,loader,setting,hist]

const names = {
	1: "Save",
	2: "Load",
	3: "Setting",
	4: "History"
}

func _ready():
	vn.inSetting = true
	renew_content(3)

func _input(ev):
	if ev.is_action_pressed('ui_cancel') or ev.is_action_pressed('vn_cancel'):
		get_tree().set_input_as_handled()
		_on_returnButton_pressed()

func _on_returnButton_pressed():
	vn.Files.write_to_config()
	vn.inSetting = false
	self.queue_free()

func _on_quitButton_pressed():
	vn.Notifs.show("quit")

func _on_mainButton_pressed():
	vn.Notifs.show("main")

func _on_saveButton_mouse_entered():
	renew_content(1)

func _on_loadButton_mouse_entered():
	renew_content(2)

func _on_settingButton_mouse_entered():
	renew_content(3)

func _on_histButton_mouse_entered():
	renew_content(4)


func renew_content(num:int):
	if num != last_hover:
		for n in $content.get_children():
			n.queue_free()
		last_hover = num
		$currentPage.text = names[num]
		$content.add_child(items[num].instance())

