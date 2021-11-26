extends RichTextLabel

var og_bbcode = bbcode_text

var on_hover = false

func _on_Node2D_meta_clicked(_meta):
	pass
	# print(meta)

func _on_Node2D_meta_hover_started(meta):
	
	var splitted = meta.split('%')
	if splitted[0].is_valid_integer() and splitted[1].is_valid_html_color():
		var n = int(splitted[0])
		var replacement_text = _find_replace_nth_color(og_bbcode, n, splitted[1])
		# print(replacement_text)
		bbcode_text = replacement_text


func _on_Node2D_meta_hover_ended(_meta):
	# print('exited')
	self.bbcode_text = og_bbcode
	
func _find_replace_nth_color(words : String, n : int, replace_col: String) -> String:

	var leng = words.length()
	var output = ''
	var i = 0
	var counter = 0
	while i < leng:
		var c = words[i]
		var inner = ""
		if c == '[':
			i += 1
			while words[i] != ']':
				inner += words[i]
				i += 1
				if i >= leng:
					push_error("This shouldn't be possible. Unless you're intentionally "+\
					"putting an open square bracket...")
					
			if "color=#" in inner:
				counter += 1
				if counter == n:
					inner = "color=#" + replace_col
					
			output += ("[" + inner + "]")
		else:
			output += c
			
		i += 1
	
	return output
