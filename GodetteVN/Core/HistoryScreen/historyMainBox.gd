extends ScrollContainer

var atBottom:bool = false

# Called when the node enters the scene tree for the first time.
func _ready():
	for i in vn.Pgs.history.size():
		var textbox:Node = vn.Pre.HIST_SLOT.instance()
		var temp:PoolStringArray = vn.Pgs.history[i]
		
		if vn.Chs.all_chara.has(temp[0]): # temp[0] = uid
			var c:Dictionary = vn.Chs.all_chara[temp[0]] 
			textbox.setName(c["display_name"], c["name_color"])
		else:
			textbox.setName(temp[0])
		textbox.setText(temp[1])
		if temp.size()>= 3:
			var vb:Node = load("res://GodetteVN/Core/_Details/voiceButton.tscn").instance()
			vb.path = temp[-1]
			textbox.get_node("box/VBoxContainer").add_child(vb)
		$textContainer.add_child(textbox)

func _process(_delta):
	if atBottom == false:
		set_v_scroll(int(get_v_scrollbar().max_value))
		atBottom = true
		set_process(false)
