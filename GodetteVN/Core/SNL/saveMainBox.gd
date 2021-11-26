extends ScrollContainer

# Make this multithreaded in the future
func _ready():
	var saves = vn.Files.get_save_files()
	var file = File.new()
	for i in range(saves.size()):
		var saveSlot = vn.Pre.SAVE_SLOT.instance()
		var path = vn.SAVE_DIR + saves[i]
		var error = file.open_encrypted_with_pass(path, File.READ, vn.PASSWORD)
		if error == OK:
			var data = file.get_var()
			saveSlot.setup_for_scene(data,0,path)
			$allSaves.add_child(saveSlot)
		else:
			print(error)
			push_error("Loading save file %s failed." %saves[i])
	
	file.close()

	for i in 3: # always provide some empty slots
		make_empty_save()


func make_empty_save():
	var newSlot = vn.Pre.SAVE_SLOT.instance()
	newSlot.connect("save_made", self, "make_empty_save")
	$allSaves.add_child(newSlot)
