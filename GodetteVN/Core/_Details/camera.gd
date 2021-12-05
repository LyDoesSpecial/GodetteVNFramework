extends Camera2D

var shake_amount = 250
var type : int
const default_offset:Vector2 = Vector2(0,0)

var target_degree:float = self.rotation_degrees
var target_zoom:Vector2 = self.zoom
var target_offset:Vector2 = self.offset

func _ready():
	set_process(false)
	
func _process(delta):
	var shake_vec = Vector2()
	match type:
		0: shake_vec = vn.Utils.random_vec(Vector2(-shake_amount,shake_amount),\
			Vector2(-shake_amount, shake_amount))
		1: shake_vec = Vector2(0, vn.Utils.random_num(-shake_amount, shake_amount))
		2: shake_vec = Vector2(vn.Utils.random_num(-shake_amount, shake_amount), 0)
		_: shake_vec = Vector2(0,0)
	
	# 0: regular, 1 shake horizontally, 2 shake vertically
	self.offset = shake_vec * delta + default_offset

func shake_off():
	shake_amount = 250
	type = 0
	set_process(false)
	self.offset = default_offset

func shake(amount, time):
	shake_amount = amount
	if time < 0.5 and time > 0:
		time = 0.5
	type = 0
	set_process(true)
	if time > 0:
		vn.Utils.schedule_job(self,"shake_off",time,[])
	
	# Time < 0 means shake until shake_off is called manually. negative time
	# can only be entered from code, and not vn script. By default, vn script
	# will force the value to be positive.

func vpunch(amount:float=600, t:float=0.9):
	shake_amount = amount
	type = 1
	set_process(true)
	vn.Utils.schedule_job(self,"shake_off",t,[])
	
func hpunch(amount:float=600, t:float=0.9):
	shake_amount = amount
	type = 2
	set_process(true)
	vn.Utils.schedule_job(self,"shake_off",t,[])

func camera_spin(sdir:int, deg:float, t:float, mode = "linear"):
	if sdir > 0:
		sdir = 1
	else:
		sdir = -1
	deg = (sdir*deg)
	target_degree = self.rotation_degrees+deg
	var tween = OneShotTween.new()
	add_child(tween)
	tween.interpolate_property(self, "rotation_degrees", self.rotation_degrees, target_degree, t,
		vn.Utils.movement_type(mode), Tween.EASE_IN_OUT)
	tween.start()
		
	
func camera_move(off:Vector2, t:float, mode = 'linear'):
	target_offset = off
	if t <= 0.05:
		self.offset = off
	else:
		var tween = OneShotTween.new()
		add_child(tween)
		tween.interpolate_property(self, "offset", self.offset, off, t,
			vn.Utils.movement_type(mode), Tween.EASE_IN_OUT)
		tween.start()
		
func zoom_timed(zm:Vector2, t:float, mode:String, off = Vector2(1,1)):
	target_zoom = zm
	target_offset = off
	var m = vn.Utils.movement_type(mode)
	var tween1 = OneShotTween.new()
	var tween2 = OneShotTween.new()
	add_child(tween1)
	add_child(tween2)
	tween1.interpolate_property(self, "offset", self.offset, off, t,
		m, Tween.EASE_IN_OUT)
	tween2.interpolate_property(self, "zoom", self.zoom, zm, t,
		m, Tween.EASE_IN_OUT)
	tween1.start()
	tween2.start()

func zoom(zm:Vector2, off = Vector2(1,1)):
	# by default, zoom is instant
	self.offset = off
	self.zoom = zm
	target_offset = off
	target_zoom = zm
	
func reset():
	for child in get_children():
		if child.get_class() == "Tween": # base class will be returned
			child.remove_all()
	
	self.offset = default_offset
	self.rotation_degrees = 0
	self.zoom = Vector2(1,1)
	target_degree = 0
	target_zoom = self.zoom
	target_offset = default_offset

func get_camera_data() -> Dictionary:
	return {'offset': target_offset, 'zoom': target_zoom, 'deg':target_degree}
	
func set_camera(d: Dictionary):
	zoom(d['zoom'], d['offset'])
	target_offset = d['offset']
	target_zoom = d['zoom']
	if d.has('deg'):
		target_degree = d['deg']
		rotation_degrees = d['deg']
