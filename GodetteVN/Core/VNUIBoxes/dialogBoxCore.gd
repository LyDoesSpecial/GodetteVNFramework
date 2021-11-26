extends RichTextLabel

# Not implemented yet because I cannot find any resource
export(bool) var noise_on = false
export(String) var noise_file_path = ''

onready var timer = $Timer

var autoCounter = 0
var skipCounter = 0
var adding = false
var nw = false

var _target_leng = 0

var FONTS = {}
const ft = ['normal', 'bold', 'italics', 'bold_italics']

signal load_next

func _ready():
	for f in ft:
		FONTS[f] = get('custom_fonts/%s_font'%f)
		
	var _err = vn.get_node("GlobalTimer").connect("timeout",self, "_on_global_timeout")
	var sb = get_v_scroll()
	var _err2 = sb.connect("mouse_entered", vn.Utils, "no_mouse")
	var _err3 = sb.connect("mouse_exited", vn.Utils, "yes_mouse")

func reset_fonts():
	for f in ft:
		add_font_override('%s_font'%f, FONTS[f])


func set_chara_fonts(ev:Dictionary):
	for key in ev.keys():
		ev[key] = ev[key].strip_edges()
		if ev[key] != '':
			add_font_override(key, load(ev[key]))

func set_dialog(words : String, cps = vn.cps, extend = false):
	# words will be already preprocessed
	if extend:
		visible_characters = self.text.length()
		bbcode_text += " " +words
	else:
		visible_characters = 0
		bbcode_text = words
		
	_target_leng = self.text.length()
	
	match cps:
		25: timer.wait_time = 0.04
		0:
			visible_characters = -1
			adding = false
			if nw:
				nw = false
				emit_signal("load_next")
			return
		10: timer.wait_time = 0.1
		_: timer.wait_time = 0.02
	
	adding = true
	timer.start()

	
func force_finish():
	if adding:
		visible_characters = _target_leng
		adding = false
		timer.stop()
		if nw:
			nw = false
			if not vn.skipping:
				emit_signal("load_next")

func _on_Timer_timeout():
	visible_characters += 1
	if visible_characters >= _target_leng:
		adding = false
		timer.stop()
		if nw:
			nw = false
			emit_signal("load_next")

func _on_global_timeout():
	if get_parent().visible == false:
		return
	if vn.skipping:
		force_finish()
		skipCounter = (skipCounter + 1)%(vn.SKIP_SPEED)
		if skipCounter == 1:
			emit_signal("load_next")
	else:
		# Auto forwarding
		if not adding and vn.auto_on: 
			autoCounter += 1
			if autoCounter >= vn.auto_bound:
				autoCounter = 0
				if not nw:
					emit_signal("load_next")
		else:
			autoCounter = 0
		skipCounter = 0
	
