extends GeneralDialog

var starter = [
	{'bg':'condo.jpg'},
	{'':'In this clickable test scene, you will see how to implement a basic '+\
	"investigation scene for your VN."},
	{'':'Pay attention to the code while you are trying it out.'},
	{'':'Find the two clickable objects and click them.'}
]

var obj1 = [
	{"dvar":"obj1 = true"},
	{"" :"You found this Linux penguin. Good job."},
	{'condition':'obj2=false', '':'You have one more to go.'},
	{'sys':'clear'},
	{"condition": ['obj1', 'obj2'], '': "Congratz, you've found all items."},
	{"condition": ['obj1', 'obj2'], 'then':'inv_end'}
	# go to inv_end if both obj1 and obj2 are true (clicked). This condition is equivalent
	# to found > 1, but I just want to show different ways you can do this
]

var obj2 = [
	{"dvar":"obj2 = true"},
	{"" :"You found the Santa!"},
	{"": "Rememeber, it's always Chirstmas season!"},
	{'condition':'obj1=false', '':'You have one more to go.'},
	{'sys':'clear'},
	{"condition": ['obj1', 'obj2'], '': "Congratz, you've found all items."},
	{"condition": ['obj1', 'obj2'], 'then':'inv_end'}
]

var investigation_end = [
	{"":"This is the end of the investigation. You can use a GDscene change to "+\
	"go to another scene"},
	{"":"Here, we will just go back to the title screen."},
	{'GDscene':vn.ending_scene_path}
]

var dialog_blocks = {'starter':starter,'obj1':obj1,'obj2':obj2, 'inv_end':investigation_end}


func _ready():
	start_scene(dialog_blocks, {},{})
