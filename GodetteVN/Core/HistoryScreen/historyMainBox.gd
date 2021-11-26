extends ScrollContainer

var atBottom = false

# Called when the node enters the scene tree for the first time.
func _ready():
	for i in vn.Pgs.history.size():
		var textbox = vn.Pre.HIST_SLOT.instance()
		var temp = vn.Pgs.history[i]
		
		if vn.Chs.all_chara.has(temp[0]): # temp[0] = uid
			var c = vn.Chs.all_chara[temp[0]] 
			textbox.setName(c["display_name"], c["name_color"])
		else:
			textbox.setName(temp[0])
		textbox.setText(temp[1])
		if temp.size()>= 3:
			var vb = load("res://GodetteVN/Core/_Details/voiceButton.tscn").instance()
			vb.path = temp[-1]
			textbox.get_node("box/VBoxContainer").add_child(vb)
		$textContainer.add_child(textbox)

func _process(_delta):
	if not atBottom:
		var bar = get_v_scrollbar()
		set_v_scroll(bar.max_value)
		atBottom = true
		set_process(false)
