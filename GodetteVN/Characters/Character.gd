extends AnimatedSprite
class_name Character


# Exports
# Character metadata
export(String) var display_name
export(String) var unique_id
export(Color) var name_color = null
export(bool) var in_all = true
export(bool) var apply_highlight = true
export(bool) var fade_on_change = false
export(float, 0.1, 1) var fade_time = 0.5
export(bool) var use_character_font = false
export(String, FILE, '*.tres') var normal_font = ''
export(String, FILE, '*.tres') var bold_font = ''
export(String, FILE, '*.tres') var italics_font = ''
export(String, FILE, '*.tres') var bold_italics_font = ''

var rng = RandomNumberGenerator.new()
var _fading:bool = false
#-----------------------------------------------------
# Character attributes
var loc:Vector2 = Vector2()
var current_expression : String

#-------------------------------------------------------------------------------


func change_expression(e : String, in_fadein:bool=false) -> bool:
	if e == "": e = 'default'
	if in_fadein: self.modulate.a = 0
	var expFrames = self.get_sprite_frames()
	if expFrames.has_animation(e) or e == "flip" or e == "flipv":
		var prev_exp = current_expression
		if e == "flip" or e == "flipv":
			if e == "flip": self.flip_h = !self.flip_h
			elif e == "flipv": self.flip_v = !self.flip_v
		else:
			play(e)
		current_expression = e
		if in_fadein == false and _fading == false: # during fading, no dummy fadeout
			_dummy_fadeout(expFrames, prev_exp)
		return true
	else:
		print("!!! Warning: " + e + ' not found for character with uid ' + unique_id +"---")
		print("!!! Nothing is done.")
		return false

func shake(amount: float, time : float, mode = 0):
	# 0 : regular shake
	# 1 : vpunch
	# 2 : hpunch
	var _objTimer = ObjectTimer.new(self,time,0.02,"_shake_action", [mode,amount])
	add_child(_objTimer)
	
func _shake_action(params):
	rng.randomize()
	# params[0] = mode, params[1] = amount
	match params[0]:
		0:self.position = loc + 0.02*Vector2(rng.randf_range(-params[1], params[1]), rng.randf_range(-params[1], params[1]))
		1:self.position = loc + 0.02*Vector2(loc.x, rng.randf_range(-params[1], params[1]))
		2:self.position = loc + 0.02*Vector2(rng.randf_range(-params[1], params[1]), loc.y)
		
func jump(direc:Vector2, amount:float, time:float):
	var step : float = amount/(time/0.04)
	var _objTimer = ObjectTimer.new(self,time,0.02,"_jump_action", [direc,step], true)
	add_child(_objTimer)

func _jump_action(params):
	# params[0] = jump_dir, params[1] = step_size, params[-1] = total_counts, params[-2] = counter
	var size = params.size()
	if params[size-2] >= params[size-1]/2:
		self.position -= params[1] * params[0]
	else:
		self.position += params[1] * params[0]


func fadein(time : float, expression:String=""):
	var _e = change_expression(expression, true)
	_fading = true
	var tween = OneShotTween.new(self, "set", ["_fading", false])
	add_child(tween)
	tween.interpolate_property(self, "modulate", Color(0,0,0,0), vn.DIM, time,
		Tween.TRANS_LINEAR, Tween.EASE_IN_OUT)
	tween.start()
	
func fadeout(time : float):
	var expFrames = self.get_sprite_frames()
	var expr = current_expression
	if current_expression in ["flip","flipv"]:
		expr = "default"
	vn.Utils.after_image(self.position, self.scale, self.modulate, self.flip_h, self.flip_v, self.rotation_degrees, expFrames.get_frame(expr,0), time, self)
	
func spin(sdir:int,deg:float,t:float,type:String="linear"):
	if sdir > 0: 
		sdir = 1
	else: 
		sdir = -1
	deg = (sdir*deg)
	var m = vn.Utils.movement_type(type)
	var tween = OneShotTween.new()
	add_child(tween)
	tween.interpolate_property(self,'rotation_degrees',self.rotation_degrees, self.rotation_degrees+deg,t,\
		m,Tween.EASE_IN_OUT)
	tween.start()
	

func _dummy_fadeout(expFrames, prev_exp:String):
	if fade_on_change and prev_exp != "":
		if prev_exp in ["flip","flipv"]:
			prev_exp = current_expression
			
		vn.Utils.after_image(self.position, self.scale, self.modulate, self.flip_h, self.flip_v, self.rotation_degrees, expFrames.get_frame(prev_exp,0), fade_time)


#----------------------------------------------------------------------------
# Explanation on this somewhat awkward character movement code
#
# Q: Why are you using a dummy? You can directly use a tween to change your position.
# A: Of course, that is a solution. However, that's imperfect for the following reason:
# Suppose you want to jump your character and move along x-axis at the same time,
# then if you do move first, then jump, then jump will not happen. Why?
# tween.interpolate_property(self,"position",position,loca,time,m,Tween.EASE_IN_OUT)
# Will move the character from position to loca, but what happens if during the tween,
# the character's position get changed by another tween? 
# You should test it out. The answer is one of the tweens will be nullified somehow.
# So to make jump and move compatible, I cannot use just a tween here.
#
# Q: Well, you can use your objectTimer to move the character, and update displacement
# when timer times out. That's easy, right?
# A: But then how are you going to implement a movement type? Movement is used so commonly
# that we should expect the user to be creative and use different movement types than
# linear. By following this fakeWalker, we can create a fake quadratic movement type
# if type = quad. 
#
# This is the best I can come up with for now...

func change_pos_2(loca:Vector2, time:float, type:String="linear", expr:String=''):
	self.loc = loca
	var m = vn.Utils.movement_type(type)
	var fake = FakeWalker.new()
	fake.name = "_dummy"
	fake.position = position
	stage.add_child(fake)
	var fake_tween = Tween.new()
	fake.add_child(fake_tween)
	fake_tween.interpolate_property(fake,"position",position,loca,time,m,Tween.EASE_IN_OUT)
	var _objTimer = ObjectTimer.new(self,time,0.01,"_follow_fake",[fake])
	add_child(_objTimer)
	fake_tween.start()
	fake_tween.connect("tween_completed", self, "clear_dummy")
	if expr != '':
		yield(get_tree().create_timer(time), 'timeout')
		var _err = change_expression(expr)

func _follow_fake(params):
	var fake = params[0]
	if is_instance_valid(fake):
		position += fake.get_disp()
#----------------------------------------------------------------------------

func clear_dummy(ob:Object, _k: NodePath):
	# This ob will be the dummy created by some method above
	ob.call_deferred('free')
	
func is_fading():
	return _fading
