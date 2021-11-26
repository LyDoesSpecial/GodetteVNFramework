extends Node

var system_data = {}
const CONFIG_PATH = "user://config.json"
const image_exts = ['png', 'jpg', 'jpeg']
const _default_config_vars = {'bgm_volume':0, 'eff_volume':0,\
 'voice_volume':0,'auto_speed':1}

func _ready():
	load_config()
#------------------------------------------------------------------------------
func get_save_files():
	
	var files = []
	var dir = Directory.new()
	if !dir.dir_exists(vn.SAVE_DIR):
			dir.make_dir_recursive(vn.SAVE_DIR)
	
	dir.open(vn.SAVE_DIR)
	dir.list_dir_begin()
	
	while true:
		var file = dir.get_next()
		if file == "":
			break
		elif not file.begins_with("."):
			if file.get_extension() == 'dat':
				files.append(file)
				
	dir.list_dir_end()
	dir.call_deferred('free')
	return files

func data2Thumbnail(img_data:PoolByteArray) -> ImageTexture:
	
	var img = Image.new()
	img.create_from_data(vn.THUMBNAIL_WIDTH, vn.THUMBNAIL_HEIGHT,\
	false, vn.ThumbnailFormat, img_data)
	# Creates a texture according to the imageTexture data
	var texture = ImageTexture.new()
	texture.create_from_image(img)
	return texture
	
func readSave(save) -> bool:
	var success = false
	var file = File.new()
	var error = file.open_encrypted_with_pass(save.path, File.READ, vn.PASSWORD)
	if error == OK:
		var data = file.get_var()
		vn.Pgs.currentSaveDesc = data['currentSaveDesc']
		vn.Pgs.currentIndex = data['currentIndex']
		vn.Pgs.currentNodePath = data['currentNodePath']
		vn.Pgs.currentBlock = data['currentBlock']
		vn.Pgs.history = data['history']
		vn.Pgs.rollback_records = data['rollback']
		vn.Pgs.playback_events = data['playback']
		vn.Pgs.load_instruction = "load_game"
		vn.Chs.chara_pointer = data['chara_pointer']
		vn.Chs.chara_name_patch = data['name_patches']
		vn.Chs.patch_display_names()
		vn.dvar = data['dvar']
		success = true
		file.close()
	else:
		# load save failed. The save is corrupted or removed.
		push_error(error)
	
	return success

#-------------------------------------------------------------------------------
func get_chara_sprites(uid, which = "sprite"):
	# This method should only be used in development phase.
	# The exported project won't work with dir calls depending on
	# what kind of paths are passed.
	var sprites = []
	var dir = Directory.new()
	if which == "anim" or which == "animation" or which == "spritesheet":
		which = vn.CHARA_ANIM
	elif which == "side" or which == "side_image" or which == "side image":
		which = vn.CHARA_SIDE
	else:
		which = vn.CHARA_DIR
		
	if !dir.dir_exists(which):
		dir.make_dir_recursive(which)
	
	dir.open(which)
	dir.list_dir_begin()
	
	while true:
		var pic = dir.get_next()
		if pic == "":
			break
		elif not pic.begins_with("."):
			var temp = pic.split(".")
			var ext = temp[temp.size()-1]
			if ext in image_exts:
				var pic_id = (temp[0].split("_"))[0]
				if pic_id == uid:
					sprites.append(pic)
				
	dir.list_dir_end()
	return sprites

func get_backgrounds():
	# This method should only be used in development phase.
	# The exported project won't work with dir calls depending on
	# what kind of paths are passed.
	var bgs = []
	var dir = Directory.new()
	if !dir.dir_exists(vn.BG_DIR):
		dir.make_dir_recursive(vn.BG_DIR)
	
	dir.open(vn.BG_DIR)
	dir.list_dir_begin()
	
	while true:
		var pic = dir.get_next()
		if pic == "":
			break
		elif not pic.begins_with("."):
			var temp = pic.split(".")
			var ext = temp[temp.size()-1]
			if ext in image_exts:
				bgs.append(pic)
				
	dir.list_dir_end()
	return bgs


#-------------------------------------------------------------------------------
func path_valid(path : String) -> bool:
	# This method should only be used in development phase.
	# Path checks might not work because of 
	# the way paths are encoded.
	var file = File.new()
	var exists = file.file_exists(path)
	file.close()
	return exists
#------------------------ Loading Json -------------------------------

func load_json(path: String):
	var f = File.new()
	var error = f.open(path, File.READ)
	if error == OK:
		var t = JSON.parse(f.get_as_text()).get_result()
		f.close()
		return t
	else:
		vn.error("Error: %s." % error)
		
func load_config_with_pass():
	var directory = Directory.new();
	if not directory.file_exists(CONFIG_PATH):
		var file = File.new()
		var error = file.open_encrypted_with_pass(CONFIG_PATH, File.WRITE, vn.PASSWORD)
		if error == OK:
			file.store_line(JSON.print(_default_config_vars,'\t'))
			file.close()
		else:
			vn.error('Error when opening config: %s' %error)

	
	var f = File.new()
	var error = f.open_encrypted_with_pass(CONFIG_PATH, File.READ, vn.PASSWORD)
	if error == OK:
		var t = JSON.parse(f.get_as_text()).get_result()
		f.close()
		return t
	else:
		vn.error("Error: %s." % error)

#------------------------ Config, Volume, etc. -------------------------------

func write_to_config():
	var directory = Directory.new();
	if directory.file_exists(CONFIG_PATH):
		var file = File.new()
		var error = file.open_encrypted_with_pass(CONFIG_PATH, File.WRITE,vn.PASSWORD)
		if error == OK:
			file.store_line(JSON.print(system_data,'\t'))
			file.close()
		else:
			push_error(error)
			
func load_config():
	system_data = load_config_with_pass()
	AudioServer.set_bus_volume_db(1, system_data["bgm_volume"])
	AudioServer.set_bus_volume_db(2, system_data["eff_volume"])
	AudioServer.set_bus_volume_db(3, system_data["voice_volume"])
	vn.auto_bound = (7 - (system_data['auto_speed'] + 1) * 2) * 20

func make_spoilerproof(scene_path:String, all_dialog_blocks):
	if system_data.has(scene_path) == false:
		var ev = {}
		for block in all_dialog_blocks.keys():
			ev[block] = -1
			
		system_data[scene_path] = ev
		
func reset_all_spoilerproof():
	var regex = RegEx.new()
	regex.compile("^(res://)(.+)(\\.tscn)$")
	for k in system_data.keys():
		if regex.search(k):
			reset_spoilerproof(k)

func reset_spoilerproof(scene_path:String):
	if system_data.has(scene_path):
		for key in system_data[scene_path].keys():
			system_data[scene_path][key] = -1
			
func remove_spoilerproof(scene_path:String):
	if system_data.has(scene_path):
		system_data.erase(scene_path)

func _exit_tree():
	write_to_config()
