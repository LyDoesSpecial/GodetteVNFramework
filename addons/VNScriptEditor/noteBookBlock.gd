tool
extends VBoxContainer

var text_visible = true
var int_type = 0
# int types
# -1 : comment block
# 0 : dialog block
# 1 : choice block
# 2 : condition block

onready var default_y = self.rect_size.y
onready var default_y_min = self.rect_min_size.y

func _on_delete_pressed():
	self.queue_free()

func _on_up_pressed():
	var organizer = get_parent()
	var idx = get_index()
	if idx > 0:
		var siblings = organizer.get_children()
		var prev = idx - 1
		organizer.move_child(self,prev)
		
		
func _on_down_pressed():
	var organizer = get_parent()
	var idx = get_index()
	var siblings = organizer.get_children()
	if idx < siblings.size() - 1:
		var next = idx + 1
		organizer.move_child(self,next)

func get_name()->String:
	return $header/blockName.text.replace(" ", "_")

func set_content(t:String):
	$MarginContainer/TextEdit.text = t

func get_plain_text()->String:
	return $MarginContainer/TextEdit.text

func set_block_name(na:String):
	$header/blockName.text = na

func disable_delete_button():
	$header/list/delete.disabled = true

func disable_name_edit():
	$header/blockName.editable = false

func _on_visible_pressed():
	text_visible = !text_visible
	$MarginContainer.visible = text_visible
	if text_visible:
		$header/list/visible.texture_normal = load("res://addons/EditorGUI/GuiVisibilityVisible.png")
		self.rect_min_size.y = default_y_min
		self.rect_size.y = default_y
	else:
		$header/list/visible.texture_normal = load("res://addons/EditorGUI/GuiVisibilityHidden.png")
		self.rect_min_size.y = 150
		self.rect_size.y = 150
		
		
		
#------------------------ Parsing -------------------------------
func block_to_json() -> Array:
	var events = []
	var ev_list = $MarginContainer/TextEdit.text.split("\n")
	for i in range(ev_list.size()):
		var line = ev_list[i].strip_edges()
		if line == "": continue
		if line[0] == "#": continue
		if int_type == 0:
			events.push_back(line_to_event(line, i+1))
		elif int_type == 1:
			events.push_back(line_to_choice(line, i+1))
		
	return events
	
func block_to_cond() -> Dictionary:
	var all_conditions = {}
	var cond_list = $MarginContainer/TextEdit.text.split("\n")
	for i in range(cond_list.size()):
		var line = cond_list[i].strip_edges()
		var output = line_to_cond(line, i+1)
		if output:
			all_conditions[output[0]] = output[1]
	
	return all_conditions
	
func line_to_event(line:String, num:int)->Dictionary:
	var ev : Dictionary = {}
	var sm_split = line.split(";")
	if sm_split[sm_split.size()-1] == "":
		sm_split.remove(sm_split.size()-1)
	else:
		print("!!! Error when parsing at line: " + line)
		push_error("Possibly missing ';' at end of line number " + str(num))
		$MarginContainer/TextEdit.cursor_set_line(num)
	
	for term in sm_split:
		var temp = term.split("::")
		if temp.size() == 2:
			var key = _prepare_text(temp[0])
			var val = _prepare_text(temp[1])
			if val.is_valid_float():
				val = float(val)
			elif key == "condition":
				val = _cond_to_array(val)
			elif key == "params":
				val = _parse_params(val)
			ev[key] = val
		else:
			print("!!! Expecting to see a key value pair separated by :: and ended with a ;")
			push_error("Incorrect format: " + term + " at line number " + str(num))
			$MarginContainer/TextEdit.cursor_set_line(num)
	
	return ev
	
func line_to_cond(line:String, num:int):
	# A condition line should be like: name_of_cond :: cond ;
	
	var sm_split = line.split(";")
	if sm_split[sm_split.size()-1] == "":
		sm_split.remove(sm_split.size()-1)
	else:
		print("!!! Error when parsing at line: " + line)
		push_error("Possibly missing ';' at end of line number " + str(num))
		
	if sm_split.size() == 1:
		var term = (sm_split[0]).split("::")
		var left = _prepare_text(term[0])
		var right = _prepare_text(term[1])
		right = _cond_to_array(right)
		return [left,right]

	return null
	
func line_to_choice(line:String, num:int) -> Dictionary:
	var ev : Dictionary = {}
	var sm_split = line.split(";")
	var l = sm_split.size() - 1
	if sm_split[l] == "":
		sm_split.remove(l)
	else:
		print("!!! Error when parsing at line: " + line)
		push_error("Possibly missing ; at the end of line %s" % [num])
		$MarginContainer/TextEdit.cursor_set_line(num)
		
	if l <= 2:
		for term in sm_split:
			var t = term.split("::")
			var left = _prepare_text(t[0])
			var right = _prepare_text(t[1])
			if left == "condition":
				right = _cond_to_array(right)
				ev[left] = right
			else:
				var temp = JSON.parse(right).result
				if typeof(temp) == TYPE_DICTIONARY:
					match temp: # pass = pass the check, good pun
						{"dvar"}: pass
						{}: pass
						{"then"}: pass
						{"then", "target id"}: pass
						_:
							push_error("Invalid choice event. Choice event can only be "+\
							"a dvar event, or a then event, or empty.")
							$MarginContainer/TextEdit.cursor_set_line(num)
							
					ev[left] = temp
				else:
					push_error("You must put a dictionary as your choice event.")
					$MarginContainer/TextEdit.cursor_set_line(num)

	else:
		push_error("Too many fields in the choice event: %s." %[line])
		$MarginContainer/TextEdit.cursor_set_line(num)
		
	return ev
	
func _prepare_text(input:String):
	input = input.strip_edges()
	return input.replace('\t','')
	
func _cond_to_array(cond:String):
	cond = cond.strip_edges()
	if "," in cond and cond[0]=='[' and cond[cond.length()-1] == "]":
		cond = cond.replace(" ", '')
		cond = cond.replace("[", "[\"")
		cond = cond.replace("]", "\"]")
		cond = cond.replace(",", "\",\"")
		var new_str : String = ""
		for i in cond.length():
			var letter = cond[i]
			if letter == "\"":
				if cond[i+1] != "[" and (cond[i+1] != "]" or cond[i-1] != "]")\
				and (cond[i+1] != "," or cond[i-1] != "]"):
					new_str += letter
			else:
				new_str += letter
		
		print(new_str)
		return JSON.parse(new_str).result
	else:
		# treat this condition as a literal string
		return cond
		
func _parse_params(pa : String):
	if pa.is_valid_float():
		return float(pa)
	if pa.to_lower() == "true":
		return true
	if pa.to_lower() == "false":
		return false
	var test = JSON.parse(pa).result
	if test == null:
		push_error("The param field %s cannot be parsed." % [pa])
	else:
		return test

