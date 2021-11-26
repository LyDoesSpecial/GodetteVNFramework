extends Node2D

const direction = {'up': Vector2.UP, 'down': Vector2.DOWN, 'left': Vector2.LEFT, 'right': Vector2.RIGHT}



# A duplicate method only for convenience.
func get_character_info(uid:String):
	if vn.Chs.all_chara.has(uid):
		return vn.Chs.all_chara[uid]
	else:
		vn.error("No character with this uid {0} is found".format({0:uid}))

func set_sideImage(sc:Vector2 = Vector2(1,1), pos:Vector2 = Vector2(-35,530)):
	$other/sideImage.scale = sc
	$other/sideImage.position = pos


func shake(uid : String, amount:float = 250, time:float = 2, mode:int = 0):
	if uid == 'all':
		for n in $characters.get_children():
			if n.in_all: 
				n.shake(amount, time, mode)
	else:
		var c = find_chara_on_stage(uid)
		c.shake(amount, time, mode)


func jump(uid:String, dir:Vector2=Vector2.UP, amount:float = 80, time:float = 0.1):
	if uid == 'all':
		for n in $characters.get_children():
			if n.in_all:
				n.jump(dir, amount, time)
	else:
		var c = find_chara_on_stage(uid)
		c.jump(dir, amount, time)
		
func spin(uid:String, degrees:float = 360.0, time:float = 1.0, sdir:int = 1, type:String="linear"):
	if uid == 'all':
		for n in $characters.get_children():
			if n.in_all:
				n.spin(sdir,degrees, time, type)
	else:
		var c = find_chara_on_stage(uid)
		c.spin(sdir,degrees,time, type)

func change_pos(uid:String, loc:Vector2, expr:String=''): # instant position change.
	var c = find_chara_on_stage(uid)
	c.position = loc
	c.loc = loc
	if expr != '':
		c.change_expression(expr)

func change_pos_2(uid:String, loca:Vector2, time:float = 1, type:String= "linear", expr:String=''):
	var c = find_chara_on_stage(uid)
	c.change_pos_2(loca, time, type, expr)
	
func change_expression(uid:String, expression:String):
	var info = vn.Chs.all_chara[uid]
	if info.has('path'):
		var c = find_chara_on_stage(uid)
		c.change_expression(expression)

func fadein(uid: String, time: float, location: Vector2, expression:String) -> void:
	# Ignore accidental spriteless character fadein
	var info = vn.Chs.all_chara[uid]
	if info.has('path'):
		if vn.skipping:
			join(uid,location,expression)
		else:
			var c = load(info['path']).instance()
			# If load fails, there will be a bug pointing to this line
			if c.apply_highlight:
				c.modulate = vn.DIM
			else:
				c.modulate = Color(1,1,1,1)
			
			c.modulate.a = 0
			c.loc = location
			c.position = location
			$characters.add_child(c)
			c.fadein(time,expression)

func fadeout(uid: String, time: float) -> void:
	if uid == 'all':
		for n in $characters.get_children():
			if n.in_all:
				n.fadeout(time)
	else:
		var c = find_chara_on_stage(uid)
		c.fadeout(time)

func join(uid: String, loc: Vector2, expression:String="default"):
	var info = vn.Chs.all_chara[uid]
	if info.has('path'):
		var ch_scene = load(info['path'])
		# If load fails, there will be a bug pointing to this line
		var c = ch_scene.instance()
		$characters.add_child(c)
		if c.change_expression(expression):
			c.position = loc
			c.loc = loc
			c.modulate = vn.DIM

func add_to_chara_at(uid:String, pt_name:String, path:String):
	if uid == 'all':
		for c in $characters.get_children():
			for n in c.get_children():
				if n is Node2D and n.name == ('_' + pt_name):
					n.add_child(load(path).instance())
					break
	else:
		var c = find_chara_on_stage(uid)
		for n in c.get_children():
			if n is Node2D and n.name == ('_' + pt_name):
				n.add_child(load(path).instance())
				break

func set_highlight(uid : String) -> void:
	var info = vn.Chs.all_chara[uid]
	if info.has('path'):
		for n in $characters.get_children():
			if n.unique_id == uid and n.apply_highlight and not n.is_fading():
				n.modulate = Color(1,1,1,1)
				break

func remove_highlight() -> void:
	for n in $characters.get_children():
		if n.apply_highlight:
			n.modulate = vn.DIM

func remove_chara(uid : String):
	if uid == 'absolute_all':
		for n in $characters.get_children():
			n.call_deferred("free")
			
	elif uid == 'all':
		for n in $characters.get_children():
			if n.in_all:
				n.call_deferred("free")
	else:
		var c = find_chara_on_stage(uid)
		c.call_deferred("free")


func set_modulate_4_all(c : Color):
	for n in $characters.get_children():
		if n.apply_highlight:
			n.modulate = c

func find_chara_on_stage(uid:String):
	for n in $characters.get_children():
		if n.unique_id == uid:
			return n
			
	print('Warning: the character with uid {0} cannot be found or has not joined the stage.'.format({0:uid}))
	print("Depending on your event, you will get a bug or nothing will be done.")

func is_on_stage(uid : String) -> bool:
	for n in $characters.get_children():
		if n.unique_id == uid:
			return true
	return false
	
func get_chara_pos(uid:String)->Vector2:
	var output = Vector2(0,0)
	var c = find_chara_on_stage(uid)
	if c: # if c is not null
		output = c.position
	return output

func all_on_stage():
	var output = []
	for n in $characters.get_children():
		var temp = {n.unique_id: n.current_expression, 'loc': n.loc, 'fliph':n.flip_h,'flipv':n.flip_v}
		output.append(temp)
			
	return output
	
func clean_up():
	remove_chara("absolute_all")
	set_sideImage()

func remove_on_rollback(arr):
	for n in $characters.get_children():
		if not (n.unique_id in arr ):
			n.call_deferred('free')
