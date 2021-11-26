extends Camera2D

onready var shakeTimer = $Timer

var shake_amount = 200
var rng = RandomNumberGenerator.new()
var type : int
const default_offset = Vector2(0,0)

var target_degree = self.rotation_degrees
var target_zoom = self.zoom
var target_offset = self.offset



func _ready():
	set_process(false)
	
func _process(delta):
	var shake_vec = Vector2()
	if type == 0: # regular
		shake_vec = Vector2(rng.randf_range(-shake_amount, shake_amount),\
		rng.randf_range(-shake_amount, shake_amount))
	elif type == 1: #vpunch
		shake_vec = Vector2(0, rng.randf_range(-shake_amount, shake_amount))
	elif type == 2: # hpunch
		shake_vec = Vector2(rng.randf_range(-shake_amount, shake_amount), 0)
	else: # currently, else means nothing
		shake_vec = Vector2(0,0)
	
	self.offset = shake_vec * delta + default_offset
	
	
func shake(amount, time):
	shake_amount = amount
	if time < 0.5:
		shakeTimer.wait_time = 0.5
	else:
		shakeTimer.wait_time = time
		 
	type = 0
	set_process(true)
	shakeTimer.start()
	

func vpunch():
	shake_amount = 600
	shakeTimer.wait_time = 0.9
	type = 1
	set_process(true)
	shakeTimer.start()
	
func hpunch():
	shake_amount = 600
	shakeTimer.wait_time = 0.9
	type = 2
	set_process(true)
	shakeTimer.start()
	

func _on_Timer_timeout():
	shake_amount = 200
	type = 0
	set_process(false)
	self.offset = default_offset
	
func camera_spin(sdir:int, deg:float, t:float, mode = "linear"):
	if sdir > 0:
		sdir = 1
	else:
		sdir = -1
	deg = (sdir*deg)
	target_degree = self.rotation_degrees+deg
	var m = vn.Utils.movement_type(mode)
	var tween = OneShotTween.new()
	add_child(tween)
	tween.interpolate_property(self, "rotation_degrees", self.rotation_degrees, target_degree, t,
		m, Tween.EASE_IN_OUT)
	tween.start()
		
	
func camera_move(off:Vector2, t:float, mode = 'linear'):
	target_offset = off
	if t <= 0.05:
		self.offset = off
	else:
		var m = vn.Utils.movement_type(mode)
		var tween = OneShotTween.new()
		add_child(tween)
		tween.interpolate_property(self, "offset", self.offset, off, t,
			m, Tween.EASE_IN_OUT)
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
		if child.get_class() == "Tween":
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
