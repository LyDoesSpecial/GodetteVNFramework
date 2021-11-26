extends Node

# A collection of functions that are used repeatedly globally



#-------------------------------------------------------------------------
# Premade event sections:
# What are premade events? If you have an event like
# {chara : j fadein, loc : '1600 900', time : 1}
# which you know you will be using many times, then you can make it 
# into an premade event putting it here with a unique key so that you
# can retrieve it anytime without typing all the commands. All you need 
# to type is that {premade: your_name_for_the_event }
var premade_events = {
	"EXAMPLE" : {"" : "Hello World!"},
}



func call_premade_events(key:String) -> Dictionary:
	if premade_events.has(key):
		return premade_events[key]
	else:
		vn.error("Premade event cannot be found. Check spelling.")
		return {}

# End of premade events section
#-------------------------------------------------------------------------
# Other functions that might be used globally

func movement_type(type:String)-> int:
	var m = 0
	match type:
		"linear": m = 0
		"sine": m = 1
		"quint": m = 2
		"quart": m = 3
		"quad": m = 4
		"expo": m = 5
		"elastic": m = 6
		"cubic": m = 7
		"circ": m = 8
		"bounce": m = 9
		"back" : m = 10
		_: m = 0
		
	return m

#----------------------------------------------------------------
func random_vec(x:Vector2, y:Vector2):
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var rndv = Vector2(rng.randf_range(x.x, x.y),rng.randf_range(y.x, y.y))
	rng.call_deferred('free')
	return rndv
	
func calculate(what:String):
	# what means what to calculate, should be an algebraic expression
	# only dvars are allowed
	var calculator = DvarCalculator.new()
	var result =  calculator.calculate(what)
	calculator.call_deferred('free')
	return result

#----------------------------------------------------------------------
# creates an after image. Used for fadeout effects / other fancy effects

func after_image(pos:Vector2, scale:Vector2, m:Color, fliph:bool, flipv:bool, deg:float, texture:Texture, fade_time:float, to_free:Node=null):
	if to_free: # if a to_free node is give, this node will be freed. Used in character fadeout.
		to_free.call_deferred('free')
	
	var dummy = Sprite.new()
	dummy.name = "_dummy"
	dummy.scale = scale
	dummy.position = pos
	dummy.texture = texture
	dummy.flip_h = fliph
	dummy.flip_v = flipv
	dummy.rotation_degrees = deg
	stage.add_child(dummy)
	var tween = OneShotTween.new(dummy, "queue_free")
	dummy.add_child(tween)
	tween.interpolate_property(dummy, "modulate", m, Color(m.r, m.g, m.b, 0), fade_time,
		Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
	tween.start()

#----------------------------------------------------------------------
# Make a save.

func create_thumbnail(width = vn.THUMBNAIL_WIDTH, height = vn.THUMBNAIL_HEIGHT):
	var thumbnail = get_viewport().get_texture().get_data()
	thumbnail.flip_y()
	thumbnail.convert(vn.ThumbnailFormat)
	thumbnail.resize(width, height, Image.INTERPOLATE_BILINEAR)
	# print(thumbnail.get_format())
	var dir = Directory.new()
	if !dir.dir_exists(vn.THUMBNAIL_DIR):
		dir.make_dir_recursive(vn.THUMBNAIL_DIR)
		
		
	var file = File.new()
	var save_path = vn.THUMBNAIL_DIR + 'thumbnail.dat'
	var error = file.open(save_path, File.WRITE)
	if error == OK:
		# store raw image data
		file.store_var(thumbnail.get_data())
		file.close()
		
# Need to Refactor
func make_a_save(msg = "[Quick Save] " , delay:float = 0.0, offset_by:int = 0):
	delay = abs(delay)
	if delay > 0:
		yield(get_tree().create_timer(delay), 'timeout')
		
	create_thumbnail() # delay is mostly used to control the timing of the thumbnail

	var sl = vn.Pre.SAVE_SLOT.instance() # bad. See below
	var temp = vn.Pgs.currentSaveDesc
	var curId = vn.Pgs.currentIndex
	vn.Pgs.currentIndex = vn.Pgs.currentIndex - offset_by
	vn.Pgs.currentSaveDesc = msg + temp
	sl.make_save(sl.path)# Because in reality we do not need to instance a save slot object. Only the data
	sl.queue_free()
	vn.Pgs.currentSaveDesc = temp
	vn.Pgs.currentIndex = curId
	
func gather_save_data():
	vn.Files.write_to_config()
	# appearance of save slot
	var dt = OS.get_datetime()
	dt['month'] = str(dt['month'])
	dt['day'] = str(dt['day'])
	dt['year'] = str(dt['year'])
	dt['hour'] = str(dt['hour'])
	dt['minute'] = str(dt['minute'])
	dt['second'] = str(dt['second'])
	var datetime = dt['month'] + "/" + dt['day'] + "/" + dt['year'] + \
	",  " + dt['hour'] + ":" + dt['minute'] + ':' + dt['second']
	# Actual save
	vn.Pgs.get_latest_nvl() # get current nvl text.
	vn.Pgs.get_latest_onstage() # get current on stage characters.
	var data = {'currentNodePath':vn.Pgs.currentNodePath, 'currentBlock': vn.Pgs.currentBlock,\
	'currentIndex': vn.Pgs.currentIndex, 'thumbnail': latest_thumbnail(),\
	'currentSaveDesc': vn.Pgs.currentSaveDesc, 'history':vn.Pgs.history,\
	'playback': vn.Pgs.playback_events, 'datetime': datetime,\
	'dvar':vn.dvar, 'rollback':vn.Pgs.rollback_records, 'chara_pointer':vn.Chs.chara_pointer,
	'name_patches':vn.Chs.chara_name_patch, 'control_state':vn.Pgs.control_state}
	
	return data

func latest_thumbnail():
	
	var dir = Directory.new()
	if !dir.dir_exists(vn.THUMBNAIL_DIR):
		# then go by default
		return "res://gui/default_save_thumbnail.png"

	# so directory already exists
	dir.open(vn.THUMBNAIL_DIR)
	dir.list_dir_begin()
	
	while true:
		var file_name = dir.get_next()
		if file_name == "":
			break
		elif not file_name.begins_with("."):
			if file_name == 'thumbnail.dat':
				var file = File.new()
				var error = file.open(vn.THUMBNAIL_DIR + file_name, File.READ)
				if error == OK:
					return file.get_var()
				else: # file won't open because of some error
					return "res://gui/default_save_thumbnail.png"
			else:
				return "res://gui/default_save_thumbnail.png"
		
	dir.list_dir_end()
	return

func write_to_save(path:String, data:Dictionary):
	var file = File.new()
	var error = file.open_encrypted_with_pass(path, File.WRITE, vn.PASSWORD)
	if error == OK:
		file.store_var(data)
		file.close()
	else:
		push_error('Error when loading saves. ' + str(error))

#------------------------------------------------------------------------
# Given any sentence with a [dvar] in it, 
# This will prase any dvar into their values and insert back
# to the sentence. Same with special tokens. It doesn't handle nw, and so is different
# from that in GeneralDialog.
func MarkUp(words:String):
	var leng = words.length()
	var output = ''
	var i = 0
	while i < leng:
		var c = words[i]
		var inner = ""
		if c == '[':
			i += 1
			while words[i] != ']':
				inner += words[i]
				i += 1
				if i >= leng:
					vn.error("Please do not use square brackets " +\
					"unless for bbcode or display dvar purposes.")
					
			if vn.dvar.has(inner):
				output += str(vn.dvar[inner])
			else:
				match inner:
					"sm": output += ";"
					"dc": output += "::"
					"nl": output += "\n"
					"lb": output += "["
					"rb": output += "]"
					_: output += '[' + inner + ']'
		else:
			output += c
			
		i += 1
	
	return output
	
#---------------------------------------------------------------------
# read the input and try to understand it
# If input is not string, simply return the input
# If input is a string and cannot be understood, it will return false.
func read(s, json:bool=false):
	if typeof(s) == TYPE_STRING:
		if json:
			pass
		else:
			match s.to_lower():
				"true": return true
				"false": return false
				_: 
					if vn.dvar.has(s):
						return vn.dvar[s]
					if s.is_valid_float():
						return float(s)
					else:
						return false
	else:
		return s

#---------------------------------------------------------------------
# Used if you only want your scale/zoom parameters to be between 0 and 1.
# Notice sometimes for scale, you want to allow bigger scale. (This is not
# recommended however, because this might destroy the image)
func correct_scale(v:Vector2) -> Vector2:
	return Vector2(min(1,abs(v.x)), min(1,abs(v.y)))
	
# No Mouse for control nodes
func no_mouse():
	vn.noMouse = true

func yes_mouse():
	vn.noMouse = false
#---------------------------------------------------------------------
# Global time controller




