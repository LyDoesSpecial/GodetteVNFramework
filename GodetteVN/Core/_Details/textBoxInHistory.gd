extends Control

func setName(name:String, color:Color = Color(0,0,0,1)):
	$box/VBoxContainer/speaker.set("custom_colors/font_color", color)
	$box/VBoxContainer/speaker.text = name + ": "
	
func setText(text):
	$box/HBoxContainer/text.bbcode_text = text
	
