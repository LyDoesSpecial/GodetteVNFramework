tool
extends PanelContainer

const image_exts = ['png', 'jpg', 'jpeg']
const chara_dir = "res://assets/actors/"
const chara_scdir = "res://GodetteVN/Characters/"

var cur_uid = ""
var dname = ""
var temp_dict = {}
var anim_dict = {}
var sc = Vector2(1,1)
var found = false
var _ready_to_generate = false

var parent

#var counter = 0
#var speed = 30
#var displacement = Vector2()
#var sp = null


func _on_Button_pressed():
	$hbox/editOptions/assetInfo/spriteInfo/spriteOptions.clear()
	$hbox/editOptions/assetInfo/animInfo/animOptions.clear()
	cur_uid = $hbox/editOptions/main/LineEdit.text
	if cur_uid == "":
		found = false
		return
	
	temp_dict = {}
	anim_dict = {}
	# Expression data
	var index = -1
	var exp_list = _get_chara_sprites(cur_uid)
	for i in range(exp_list.size()):
		var temp = exp_list[i].split(".")[0]
		temp = temp.split("_")
		temp_dict[temp[1]] = exp_list[i]
		$hbox/editOptions/assetInfo/spriteInfo/spriteOptions.add_item(temp[1])
		if temp[1] == "default":
			index = i
			$hbox/preview.texture = load(chara_dir+temp_dict[temp[1]])

	# There has to be a static sprite called default.
	if index == -1:
		_fail_to_find()
		push_error("Unable to find a default expression for %s." %[cur_uid])
		return
	else:
		found = true
		
	$hbox/editOptions/assetInfo/spriteInfo/spriteOptions.select(index)
	
	var anim_lists = _get_chara_sprites(cur_uid, "anim")
	for e in anim_lists:
		var temp = e.split(".")[0]
		temp = temp.split("_")
		anim_dict[temp[1]] = e
		$hbox/editOptions/assetInfo/animInfo/animOptions.add_item(temp[1])
		
	$hbox/editOptions/main/LineEdit.release_focus()
		
func _fail_to_find():
	found = false
	$hbox/editOptions/assetInfo/spriteInfo/spriteOptions.clear()
	$hbox/preview.texture = null
	

func _on_generateButton_pressed():
	if found == false:
		return
	_ready_to_generate = true
	$charaGenPopup.dialog_text = ("You are about to generate a character scene for uid: {0}" +\
	", which will have the path:\n\n {1}.").format({0:cur_uid,1:(chara_scdir+cur_uid+".tscn")})
	$charaGenPopup.dialog_text += "\n\nYou can pick a name color and do more customization for the "+\
	 "character in the generated scene."
	$charaGenPopup.popup_centered()


func _on_charaGenPopup_confirmed():
	if _ready_to_generate == false:
		return
	else:
		var packed_scene = PackedScene.new()
		var ch = (load("res://addons/ActorEditor/CharacterTemplate.tscn")).instance()
		var expSheet = SpriteFrames.new()
		for ex in temp_dict.keys():
			var t = load(chara_dir + temp_dict[ex])
			if expSheet.has_animation(ex):
				expSheet.remove_animation(ex)
			expSheet.add_animation(ex)
			expSheet.add_frame(ex, t)
			expSheet.set_animation_loop(ex, false)
			
		for an in anim_dict.keys():
			if expSheet.has_animation(an):
				expSheet.remove_animation(an)
			expSheet.add_animation(an)
			expSheet.set_animation_loop(an, false)
		
		var sheetName = chara_scdir+cur_uid+"_expressionSheet.tres"
		var error = ResourceSaver.save(sheetName, expSheet)
		if error == OK:
			print("Expression sheet for %s saved." %[cur_uid])
		else:
			print("Some error occurred when trying to save spriteSheet.")
		
		ch.name = cur_uid
		ch.set_sprite_frames(load(sheetName))
		ch.unique_id = cur_uid
		packed_scene.pack(ch)
		var chara_scene_path = chara_scdir+cur_uid+".tscn"
		error = ResourceSaver.save(chara_scdir+cur_uid+".tscn", packed_scene)
		if error == OK:
			print("Character successfully saved to scene.")
		else:
			print("Some error occurred when trying to save as scene.")
		
		_ready_to_generate = false
		
		parent.get_editor_interface().open_scene_from_path(chara_scene_path)


# -------------------------------------------------------------------------

func _get_chara_sprites(uid, which = "sprite"):
	# This method should only be used in development phase.
	# The exported project won't work with dir calls depending on
	# what kind of paths are passed.
	var sprites = []
	var dir = Directory.new()
	if which == "anim" or which == "animation" or which == "spritesheet":
		which = "res://assets/actors/spritesheet/"
	else:
		which = chara_dir
		
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

func _on_spriteOptions_item_selected(index):
	if found:
		var expr = $hbox/editOptions/assetInfo/spriteInfo/spriteOptions.get_item_text(index)
		$hbox/preview.texture = load(chara_dir+temp_dict[expr])
