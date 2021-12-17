extends Timer
class_name ObjectTimer

signal call_func(params)

var _counter:int = 0
var _total:int = 1
var _params = null

# This var means whether params should include counter and total
# Counter will be at the position size() - 2 of params, and total
# will be at size() - 1.
var _include:bool = false

# Object timers are timers that will do the following:
# 1. Will become a subnode of an object, and thus only affects its parent
# 2. Calls func_name of its parent every interval of time
# and for every period counter += 1
# 3. Self destroy when counter >= total

func _init(par:Node, total_time:float, interval:float, func_name:String, params:Array=[], include:bool=false):
	total_time = stepify(total_time, 0.1)
	self._total = int(round(total_time/interval))
	self.wait_time = interval
	self._params = params
	if include:
		_include = true
		_params.push_back(_counter)
		_params.push_back(_total)
	var _e:int = self.connect("call_func", par, func_name)
	_e = self.connect("timeout", self, "_timeout")
	autostart = true

func _timeout():
	_counter += 1
	if _include: _params[_params.size()-2] = _counter
	if _counter >= _total:
		emit_signal("call_func", _params)
		queue_free()
	else:
		emit_signal("call_func", _params)
