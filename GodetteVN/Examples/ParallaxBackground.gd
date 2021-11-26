extends ParallaxBackground

var moon_speed
var uniform_speed

# If you want, you can choose a different self-moving speed for all your layers
# in your parallax. Here every layer is moving at the same speed except moon.

func _ready():
	# Everything but moonLayer will have speed -25
	moon_speed = -15
	
	# Do this in _ready because if you do it outside, there will be a dvar
	# not exist error (because of the load order)
	uniform_speed = vn.dvar['parallax_speed']

func _process(delta)->void:
	for p in get_children():
		if p.name == "moonLayer":
			p.motion_offset.x += moon_speed * delta
		else:
			p.motion_offset.x += uniform_speed * delta

# When the dvar parallax_speed changed, this function will be called
func parallax_speed_change(new_speed):
	uniform_speed = new_speed
	
func dvar_speed():
	pass
