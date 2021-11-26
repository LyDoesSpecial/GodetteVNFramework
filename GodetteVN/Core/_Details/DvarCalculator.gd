extends Object
class_name DvarCalculator

# converts evaluates string of arithmetic expression

const p = ["(", ")"]
const prec = {"(":0 , "+":1, "-": 1, "*":2, "/":2, "^":3}
const operators = ["+", "-", "*", "^", "/", "("]
const left = "("
const right = ")"


func calculate(expression:String):
	var postfix = _infix_postfix(expression)
	return _eval_a(postfix)


func _paren_check(st : String) -> bool:
	var stack = []
	for s in st:
		if s == left:
			stack.push_back(s)
			
		if s == right:
			var t = stack.pop_back()
			if t != left:
				return false
	
	if stack.size() == 0:
		return true
	else:
		return false
		
func _format_expression(ex):
	var output = []
	for e in ex:
		if e.is_valid_float() or vn.dvar.has(e):
			output.push_back(e)
		else: 
			# not number
			e = e.replace(" ", "") # remove all whitespace
			for a in e:
				output.push_back(a)

	return output

func _infix_postfix(ex:String):
	if _paren_check(ex):
		var regexMatch = "(\\d+\\.?\\d*)|(\\+)|(-)|(\\*)|(\\^)|(\\()|(\\))|(/)"
		for v in vn.dvar.keys():
			if typeof(vn.dvar[v]) in [TYPE_INT, TYPE_REAL]:
				if v in ex:
					regexMatch += "|("+v+")"
				
		var regex = RegEx.new()
		regex.compile(regexMatch)
		var results = []
		for result in regex.search_all(ex):
			results.push_back(result.get_string())
		
		results = _format_expression(results)
		var output = []
		var stack = []
		for le in results:
			if le.is_valid_float() or vn.dvar.has(le):
				output.push_back(le)
			elif le == left:
				stack.push_back(le)
			elif le == right:
				var top = stack.pop_back()
				while top != left:
					output.push_back(top)
					top = stack.pop_back()
					
			elif le in operators:
				while (stack.size()!=0) and prec[stack[stack.size()-1]]>=prec[le]:
					output.push_back(stack.pop_back())
					
				stack.push_back(le)
				
		while stack.size() > 0:
			output.push_back(stack.pop_back())
			
		return output
		
	else:
		push_error("Parenthesis!")
		
func _eval_a(ex_arr) -> float:
	
	var stack = []
	for e in ex_arr:
		if e.is_valid_float():
			stack.push_back(float(e))
		elif vn.dvar.has(e):
			if typeof(vn.dvar[e]) in [TYPE_REAL, TYPE_INT]:
				stack.push_back(vn.dvar[e])
			else:
				push_error("The type of dvar {0} is not number. Cannot evaluate.".format({0:e}))
		else:
			var second = stack.pop_back()
			var first = stack.pop_back()
			if e == "+":
				stack.push_back(first+second)
				#print("Doing {0}+{1}".format({0:first,1:second}))
			elif e == "-":
				if first == null:
					stack.push_back(-second)
				else:
					stack.push_back(first-second)
				#print("Doing {0}-{1}".format({0:first,1:second}))
			elif e == "*":
				stack.push_back(first*second)
				#print("Doing {0}*{1}".format({0:first,1:second}))
			elif e == "^":
				stack.push_back(pow(first,second))
				#print("Doing {0}^{1}".format({0:first,1:second}))
			elif e == "/":
				stack.push_back(first/second)
				#print("Doing {0}/{1}".format({0:first,1:second}))
			else:
				push_error("Unrecognized operator " + e)

	return stack.pop_back()
