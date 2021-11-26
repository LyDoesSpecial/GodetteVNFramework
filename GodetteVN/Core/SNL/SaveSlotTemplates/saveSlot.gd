extends TextureButton

signal save_made
signal load_ready

var mode:int = 0 # 0: in save, 1 in load
var path:String = ""

func _on_saveSlot_pressed():
	if mode == 0: # if we are accessing this in the save screen
		if self.path != "":
			vn.Notifs.show("override")
			var override_choice = vn.Notifs.get_current_notif()
			override_choice.connect("decision", self, "override_save")
		else:
			# self.path == ""
			make_save(self.path)
			emit_signal("save_made")
	
	else: # we are accessing this in the load screen
		if self.path != "":
			var success = vn.Files.readSave(self)
			if success:
				emit_signal('load_ready')
			else:
				# warning, save loading failed
				vn.error('Loading failed. (Unknown reason.)')


#---------------------Functionalities Related to Save--------------------------

func override_save(yes: bool):
	if yes:
		make_save(self.path)


func make_save(save_path): # called when an empty save is clicked

	var data = vn.Utils.gather_save_data()
	_setup(data)
	var dir = Directory.new()
	if !dir.dir_exists(vn.SAVE_DIR):
		dir.make_dir_recursive(vn.SAVE_DIR)
		
	if save_path == "":
		save_path = vn.SAVE_DIR + 'save' + str(OS.get_system_time_msecs()) + '.dat'
		self.path = save_path
	
	vn.Utils.write_to_save(save_path, data)	


func set_description(text):
	get_node("HBoxContainer/VBoxContainer/saveInfo").bbcode_text = "[center]"+ text +"[/center]"

func set_datetime(dt):
	get_node("HBoxContainer/VBoxContainer/saveTime").text = dt

# used when loading save files in the save/load screen
func setup_for_scene(data:Dictionary, m:int, p:String):
	self.mode = m
	self.path = p
	_setup(data)
	
func _setup(data:Dictionary):
	var tn = data['thumbnail']
	if typeof(tn) == TYPE_STRING:
		if tn == "res://gui/default_save_thumbnail.png":
			$HBoxContainer/thumbnail.texture = load(tn)
	else:
		$HBoxContainer/thumbnail.texture = vn.Files.data2Thumbnail(tn)
		
	set_description(data['currentSaveDesc'])
	set_datetime(data['datetime'])




