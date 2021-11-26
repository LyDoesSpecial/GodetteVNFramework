extends Tween
class_name OneShotTween

var call_back_node: Node
var call_method: String
var call_arg: Array

func _init(node:Node=null, method:String="", arg:Array=[]):
	self.call_back_node = node
	self.call_method = method
	self.call_arg = arg
	var _err = self.connect("tween_all_completed", self, "queue_free")
	
func queue_free():
	if call_back_node and call_method != "":
		call_back_node.callv(call_method, call_arg)
	.queue_free()

