extends Node

func dvar_initialization():
	var temp = get_node("RegisteredDvars")
	var temp_node = Node.new()
	var ban_list = {"Script Variables":false}
	for p in temp_node.get_property_list():
		ban_list[p['name']] = false
	temp_node.queue_free()
	for dv in temp.get_property_list():
		var n = dv['name']
		if ban_list.has(n):
			continue
		
		if not n.is_valid_identifier():
			push_error("A valid dvar name should only contain letters, digits, and underscores and the "+\
		"first character should not be a digit.")
		
		if n in vn.BAD_NAMES:
			push_error("The name %s cannot be used as a dvar name." % [n])
			
		var val = temp.get(n)
		if typeof(val) in [TYPE_ARRAY, TYPE_DICTIONARY]:
			vn.dvar[n] = val.duplicate(true)
		else:
			vn.dvar[n] = temp.get(n)
	
	print("Intialized all dvars.")
