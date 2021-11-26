extends Node

var all_chara = {
	# Narrator, the key empty string "" is its UID!
	"":{"uid":'', "display_name":"","name_color":Color(0,0,0,1),'font':false}
}


var chara_pointer = {}
var chara_name_patch = {}


func _ready():
	var registeredCharas = get_node("RegisteredCharacters")
	for ch in registeredCharas.stage_characters:
		stage_character(ch)
	for ch in registeredCharas.spriteless_characters:
		spriteless_character(ch)


# Keep a record of the path to the scene of the stage character
func stage_character(uid:String) -> void:
	if uid in vn.BAD_UIDS:
		if uid == "":
			vn.error("The empty string uid is preserved for the narrator." % [uid])
		else:
			vn.error("The uid %s is not allowed." % [uid])
	
	var path = vn.CHARA_SCDIR+uid+".tscn"
	var ch_scene = load(path)
	if ch_scene == null:
		vn.error("The character scene cannot be found.")
	var c = ch_scene.instance()
	var info = {"uid":c.unique_id,"display_name":c.display_name,"name_color":c.name_color,"path":path}
	if c.use_character_font:
		info['font'] = true
		info['normal_font'] = c.normal_font
		info['italics_font'] = c.italics_font
		info['bold_font'] = c.bold_font
		info['bold_italics_font'] = c.bold_italics_font
	else:
		info['font'] = false
	
	all_chara[uid] = info
	c.call_deferred('free')

# Difference is that stage character also has a path field.

func spriteless_character(cdata:Dictionary)->void:
	if cdata.has("uid") and cdata.has("display_name"):
		var uid = cdata['uid']
		if uid in vn.BAD_UIDS:
			push_error("!!! %s is a bad uid choice. Choose another one." % uid)
		if not cdata.has("name_color"): 
			cdata['name_color'] = Color.black
		
		all_chara[uid] = cdata
	else:
		push_error("!!! Wrong spriteless character format. Need at least uid and display_name fields.")

func get_character_info(uid:String):
	if all_chara.has(uid):
		return all_chara[uid]
	else:
		push_error("No character with this uid %s is found" % uid )


# Use case of point_uid_to
# Suppose you have prepared a male ver and female ver of your protagonist's
# character. The character scenes are named a.tscn and b.tscn, and male
# has uid a, and female has uid b.
# In your dialog script, you want to only use a.  
# Before the first VN scenes starts, you ask the player to choose
# male or female. Once the choice is given, in that script, you can call
# chara.point_uid_to("a", "b")
# From this point on, if you have a line like 
# a happy: "Hello!"
# It will be interpreted as b happy: "Hello!"
# This works with save system, and will be different depending on the player's
# choice in each save.
# This is not transitive and only works with two uids.
func point_uid_to(uid:String, to:String):
	chara_pointer[uid] = to
	
func forward_uid(uid:String) -> String:
	if chara_pointer.has(uid):
		return chara_pointer[uid]
	else:
		return uid
#------------------------------------------------------------------------

# Hide the name box when the character is speaking. 
func set_noname(uid:String):
	if all_chara.has(uid):
		all_chara[uid]['no_nb'] = true
	else:
		push_error("The uid %s has not been regiestered when this line is executed. Might also be a typo." % [uid])

func set_new_display_name(uid:String, new_dname:String):
	if all_chara.has(uid):
		all_chara[uid]['display_name'] = new_dname
		chara_name_patch[uid] = new_dname
	else:
		push_error("The uid %s has not been regiestered when this line is executed. Might also be a typo." % [uid])
		
func patch_display_names():
	if chara_name_patch.size()>0:
		for uid in chara_name_patch.keys():
			set_new_display_name(uid,chara_name_patch[uid])

