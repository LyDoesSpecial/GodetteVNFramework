extends ScrollContainer

# Multithreading only creates more problems. (If I am doing it right...)
func _ready():
	# Create the appearance
	var saves = vn.Files.get_save_files()
	var size = saves.size()
	var file = File.new()
	for i in range(size):
		var saveSlot = vn.Pre.SAVE_SLOT.instance()
		var path = vn.SAVE_DIR+saves[i]
		var error = file.open_encrypted_with_pass(path, File.READ, vn.PASSWORD)
		if error == OK:
			var data = file.get_var()
			saveSlot.setup_for_scene(data, 1, path)
			saveSlot.connect('load_ready', self, 'load_save')
			$allSaves.add_child(saveSlot)
		else:
			print(error)
			push_error("Loading save file %s failed." %saves[i])
	
	file.close()

func load_save():
	vn.reset_states() # inSetting = false
	stage.remove_chara('absolute_all')
	var error = get_tree().change_scene(vn.Pgs.currentNodePath)
	if error == OK:
		self.queue_free()
