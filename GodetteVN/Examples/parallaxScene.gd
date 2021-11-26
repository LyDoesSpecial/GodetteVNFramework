extends GeneralDialog


# Typically you do not want to use any background change events in a parallax
# so you might as well hide the background node. (The parallax background is a
# complete independent thing. So all events like {bg: ..., fadein} will be pointless
# in a parallax scene. It is designed in this way because a parallax scene is 
# usually a separate scene in you game, so it should be a separate Godot scene
# as well. It makes organization cleaner. There is really no point in mixing
# parallax background and regular staic background in one Godot scene when you
# can easily switch from one to another.)

# Another note: in order for parallax to be compatible with character actions,
# it is important to make your parallax bgs self-moving. This is because we
# do not want to make the camera, nor the character positions.

#---------------------------------- Core Dialog ---------------------------------------
var main_block = [
	
	# start of content
	{"screen":"fade in", 'time':1},
	{'chara': "gt join", "loc": "1600 650"},
	{"gt": "Here we demonstrate parallax background and show that it is compatible with all character actions."},
	{"gt": "You can look at the top left corner to see the events controlling everything."},
	{"express": "gt crya"},
	{"gt": "This forest is a bit scary, isn't it?"},
	{"chara": "gt shake","time":1},
	{'wait': 1},
	{'gt default': "I see someone!"},
	{"express": "gt wavea"},
	{"chara": "gt jump"},
	{"chara": "gt move", "loc": "1000 650"},
	{'gt': "But someone doesn't see me..."},
	{'dvar':'parallax_speed = -100'},
	{"gt default": "Did you notice the background moving speed has changed?"},
	{"gt":'This is done by using a dvar to control the moving speed and a function which gets called '+\
	"whenever this dvar is changed."},
	{"gt": "See comment 1 in the code if you're curious."},
	{"gt":"Thanks a lot to saukgp on itch who provides these parallax backgrounds for free!"},
	{'wait':3},
	{"screen":"fade out", 'time':1}, # fade in means fade into darkness
	{"GDscene": vn.ending_scene_path}
	# end of content
]



#---------------------------------------------------------------------
# Do not change the key word starter. It is necessary.
var conversation_blocks = {'starter' : main_block}

var choice_blocks = {}


#---------------------------------------------------------------------
func _ready():
	register_dvar_propagation("parallax_speed_change", "parallax_speed")
	# See comment 1 below
	start_scene(conversation_blocks, choice_blocks, {})
	
# Comment 1:
# register_dvar_propagation: here we're associating the dvar
# parallax_speed with the method parallax_speed_change
# The default behavior is as follows: whenever the dvar parallax_speed is changed,
# The node will fire a propagate_call (look it up in Godot documentation if you are
# not familiar) and every subnode that has the function parallax_speed_change will
# be called automatically, and if a parent node and a child node both have this
# function, then the parent node will be called first.
# Moreover, because this is a change according to a dvar value, whenever you rollback,
# a propagate_call will also be fired.
# The format is: register_dvar_propagation("name_of_func", "dvar")
# And this dvar will be passed into the function name_of_func as argument

# You can only change one dvar at a time, so you can only associate one dvar
# in one registeration. If you have multiple functions that depend on the same
# dvar, simply register twice. If your function depends on two dvars, try to 
# separate it into two functions. (Maybe this is not the best approach?)

# Dvar propagation can be used to control the exterior scenes like this. 
# (Parallax background is exterior to the vn system. 
# Exterior: something that is not directly controlled by GeneralDialog)
