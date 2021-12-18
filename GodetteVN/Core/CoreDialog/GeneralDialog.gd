extends Node2D
class_name GeneralDialog

export(String, FILE, "*.json") var dialog_json 
export(bool) var debug_mode
export(String) var scene_description

export(String, FILE, "*.tscn") var choice_bar = ''
export(String, FILE, "*.tscn") var float_text = ''
export(bool) var allow_rollback = true
export(bool) var refresh_game_ctrl_state = true

# Core data
var current_index : int = 0
var current_block: Array
var all_blocks:Dictionary
var all_choices:Dictionary
var all_conditions:Dictionary
# Other
var latest_voice:String = ''
var idle : bool = false
var _nullify_prev_yield : bool = false
# Only used in rollback
var _cur_bgm:String = ''
# State controls
var nvl : bool = false
var centered : bool = false
var waiting_acc : bool = false
var waiting_cho : bool = false
var just_loaded : bool = false
var hide_all_boxes : bool = false
var hide_vnui : bool = false
var no_scroll : bool = false
var no_right_click : bool = false
var one_time_font_change : bool = false
# Dvar Propagation
var _propagate_dvar_list:Dictionary = {}
#----------------------
# Important components
onready var bg = $background
onready var QM = $VNUI/quickMenu
onready var dialogbox = $VNUI/dialogBox/dialogBoxCore
onready var speaker = $VNUI/nameBox/speaker
onready var choiceContainer = $VNUI/choiceContainer
onready var camera = screen.get_node('camera')
onready var _u : Node = MyUtils

var nvlBox = null # dynamic. The NVL component is only instanced when in nvl mode.
#-----------------------
# signals
signal player_accept(npv)
signal dvar_set

#--------------------------------------------------------------------------------
func _ready():
	vn.Files.load_config()
	var _error = self.connect("player_accept", self, '_yield_check')
	if refresh_game_ctrl_state:
		vn.Pgs.resetControlStates()

# Useless?
func set_bg_path(node_path:String):
	bg = get_node(node_path)
	
func _input(ev):
	if ev.is_action_pressed('vn_rollback') and (waiting_acc or idle) and not vn.inSetting \
	and not vn.inNotif and not vn.skipping and allow_rollback:
		on_rollback()
			
	if ev.is_action_pressed('vn_upscroll') and not vn.inSetting and not vn.inNotif and not no_scroll:
		QM.on_historyButton_pressed() # bad name... but lol
		return
	# QM hiding means that quick menu is being hidden. If that is the case,
	# then the user probably wants to disable access to main menu too.
	if ev.is_action_pressed('ui_cancel') and not vn.inSetting and not vn.inNotif and not QM.hiding:
		add_child(vn.MAIN_MENU.instance())
		return
	
	if waiting_cho:
		# Waiting for a choice. Do nothing. Any input will be nullified.
		# In a choice event, game resumes only when a choice button is selected.
		return
		
	if ev.is_action_pressed('vn_cancel') and not vn.inNotif and not vn.inSetting and not no_right_click:
		hide_UI()

	# Can I simplify this?
	if (ev.is_action_pressed("ui_accept") or ev.is_action_pressed('vn_accept')) and waiting_acc:
		if hide_vnui: # Show UI
			hide_UI(true)
		# vn_accept is mouse left click
		if ev.is_action_pressed('vn_accept'):
			if vn.auto_on or vn.skipping:
				if not vn.noMouse:
					QM.reset_auto_skip()
			else:
				if not vn.noMouse and not vn.inNotif and not vn.inSetting:
					check_dialog()
		else: # not mouse
			if vn.auto_on or vn.skipping:
				QM.reset_auto_skip()
			elif not vn.inNotif and not vn.inSetting:
				check_dialog()
	
#--------------------------------- Interpretor ----------------------------------

func load_event_at_index(ind : int) -> void:
	if ind >= current_block.size():
		print("Reached the end of block %s, entering an idle state." %[vn.Pgs.currentBlock])
		idle = true
		if self.nvl: nvl_off()
	else:
		if debug_mode:print("Debug: current event index is " + str(current_index))
		interpret_events(current_block[ind])

func interpret_events(event):
	# Try to keep the code under each case <=3 lines
	# Also keep the number of cases small. Try to repeat the use of key words.
	var ev:Dictionary = event.duplicate(true)
	if debug_mode: print("Debug :" + str(ev))
	
	# Pre-parse, keep this at minimum
	if ev.has('loc'): ev['loc'] = _parse_loc(ev['loc'], ev)
	if ev.has('params'): ev['params'] = vn.Utils.read(ev['params'])
	if ev.has('color'): ev['color'] = _parse_color(ev['color'], ev)
	if ev.has('nvl'): ev['nvl'] = _parse_nvl(ev['nvl'])
	if ev.has('scale'): ev['scale'] = _parse_loc(ev['scale'], ev)
	if ev.has('dir'): ev['dir'] = _parse_dir(ev['dir'], ev)
	# End of pre-parse. Actual match event
	match vn.event_reader(ev):
		0: conditional_branch(ev)
		1:
			if check_condition(ev['condition']):
				var _err = ev.erase('condition')
				continue
			else: auto_load_next()
		2: screen_effects(ev)
		3: change_background(ev)
		4: character_event(ev)
		5: change_weather(ev['weather'])
		6: camera_effect(ev)
		7: express(ev['express'])
		8: play_bgm(ev)
		9: play_sound(ev)
		10: set_dvar(ev)
		11: sfx_player(ev)
		12: then(ev)
		13:extend(ev)
		14:
			if debug_mode: print("!!! PREMADE EVENT:")
			interpret_events(vn.Utils.call_premade_events(ev['premade']))
		15: system(ev)
		16: sideImageChange(ev)
		17: generate_choices(ev)
		18: wait(ev['wait'])
		19: set_nvl(ev)
		20: change_scene_to(ev['GDscene'])
		21: history_manipulation(ev)
		22: flt_text(ev)
		23: voice(ev['voice'])
		24: auto_load_next()
		25: call_method(ev)
		26: set_center(ev)
		_: speech_parse(ev)

#----------------------- on ready, new game, load, set up, end -----------------
func auto_start(start_block:String="starter", start_id=null):
	var load_instr:String = vn.Pgs.load_instruction
	print("!!! Beta Notice: auto_start currently only works if you use json files for dialog. ---")
	if not (load_instr in ["new_game", "load_game"]):
		print("!!! Unknown load instruction. It can either be new_game or load_game.")
		return false
	
	if self.dialog_json == "":
		print("!!! For auto_start, you need to provide a dialog json file.")
		return false
	else:
		var dialog_data = vn.Files.load_json(dialog_json)
		if dialog_data.has('Dialogs') and dialog_data.has('Choices'):
			if dialog_data.has('Conditions'):
				start_scene(dialog_data['Dialogs'],dialog_data['Choices'],dialog_data['Conditions'], load_instr,\
					start_block, start_id)
			else:
				start_scene(dialog_data['Dialogs'],dialog_data['Choices'],{}, load_instr,\
					start_block, start_id)
			return true
		else:
			print("Dialog json file must contain 'Dialogs' and 'Choices' (even if empty).")
			return false
			
func get_all_dialog_blocks():
	return all_blocks
		
func start_scene(blocks : Dictionary, choices: Dictionary, conditions: Dictionary,\
	load_instr:String = "new_game", start_block:String="starter", start_id=null) -> void:
	vn.Scene = self
	get_tree().set_auto_accept_quit(false)
	vn.Pgs.currentSaveDesc = scene_description
	vn.Pgs.currentNodePath = get_tree().current_scene.filename
	all_blocks = blocks
	all_choices = choices
	all_conditions = conditions
	dialogbox.connect('load_next', self, 'trigger_accept')
	if load_instr == "new_game":
		if start_id:
			current_index = get_target_index(start_block,start_id)
		else:
			current_index = 0
		if blocks.has(start_block):
			current_block = blocks[start_block]
		else:
			push_error("Start block %s not found." % start_block)
		
		vn.Pgs.currentIndex = current_index
		vn.Pgs.currentBlock = start_block # this is the name corresponding to the array
	elif load_instr == "load_game":
		vn.Pgs.load_instruction = "new_game" # reset after loading
		current_index = vn.Pgs.currentIndex
		current_block = all_blocks[vn.Pgs.currentBlock]
		load_playback(vn.Pgs.playback_events)
	else:
		push_error("Unknow loading instruction")
	
	if music.bgm != '':
		_cur_bgm = music.bgm
	if debug_mode: print("Debug: current block is " + vn.Pgs.currentBlock)
	load_event_at_index(current_index)


func auto_load_next(forw:bool=true):
	if forw:
		current_index += 1
		vn.Pgs.currentIndex = current_index
		if vn.skipping:
			yield(get_tree(), "idle_frame")
			if not vn.Pgs.checkSkippable():
				QM.reset_skip()
		load_event_at_index(current_index)

#------------------------ Related to Dialog Progression ------------------------
# Cleaned this shit up. Either on / off, or true/false. Don't mix.
func set_nvl(ev: Dictionary, auto_forw = true):
	if typeof(ev['nvl']) == TYPE_BOOL:
		self.nvl = ev['nvl']
		if self.nvl:
			if ev.has('font'):
				nvl_on(ev['font'])
			else:
				nvl_on()
		else:
			nvl_off()
		auto_load_next(auto_forw)
	elif ev['nvl'] == 'clear':
		nvlBox.clear()
		auto_load_next(auto_forw)
	else:
		print("!!! Wrong nvl event format : %s" %ev)
		push_error('nvl expects a boolean or the keyword clear.')
	
func set_center(ev: Dictionary):
	self.centered = true
	if ev.has('font'):
		set_nvl({'nvl': true,'font':ev['font']}, false)
	else:
		set_nvl({'nvl': true}, false)
	var w = _u._has_or_default(ev,"who","")
	if ev.has('speed'):
		say(w, ev['center'], ev['speed'])
	else:
		say(w, ev['center'])
	var _has_voice:bool = _check_latest_voice(ev)

func speech_parse(ev : Dictionary) -> void:
	# Voice first
	var _has_voice:bool = _check_latest_voice(ev)
	# one time font change
	one_time_font_change = ev.has('font')
	if one_time_font_change:
		var path:String = vn.FONT_DIR + ev['font']
		dialogbox.add_font_override('normal_font', load(path))

	# Speech
	var combine:String = "_"
	for k in ev: # k is not voice, not speed, means it has to be "uid expression"
		if not (k in ['voice', 'speed']):
			combine = k # combine=unique_id and expression combined
			break
	if combine == "_":
		print("!!! Speech event uid format error: " + str(ev))
		push_error("Speech event requires a valid character/narrator.")
	
	if ev.has('speed'):
		if (vn.cps_map.has(ev['speed'])):
			say(combine, ev[combine],vn.cps_map[ev['speed']] )
		else:
			print("!!! Unknown speed value in " + str(ev))
			push_error("Unknown speed value.")
		# Should I allow other values?
	else:
		say(combine, ev[combine])

func generate_choices(ev: Dictionary):
	# make a say event
	if self.nvl: nvl_off()
	else:
		clear_boxes()
	if vn.auto_on or vn.skipping:
		QM.disable_skip_auto()
	
	var _has_voice:bool = _check_latest_voice(ev)
	one_time_font_change = ev.has('font')
	if one_time_font_change:
		var path:String = vn.FONT_DIR + ev['font']
		dialogbox.add_font_override('normal_font', load(path))
	var combine:String = "_"
	for k in ev:
		if not (k in ['choice','voice','id']):
			combine = k
			break
	if combine != "_":
		say(combine, ev[combine], vn.cps, true)
	
	if ev['choice'] in ['','url']: 
		# Intentionally left blank
		return
	# Actual choices
	var options:Array = all_choices[ev['choice']]
	waiting_cho = true
	for i in options.size():
		var ev2:Dictionary = options[i]
		match ev2.size():
			1: pass
			2: 
				if ev2.has('condition'):
					if not check_condition(ev2['condition']):
						continue # skip to the next choice if condition not met
				else:
					push_error('If a choice is size 2, then it has to have a condition.')
			_: push_error('Only size 1 or 2 dict will be accepted as choice.')
		var choice_text:String = ''
		for k in ev2:
			if k != "condition":
				choice_text = k # grab the key not equal to condition
				break
		
		var choice_ev:Dictionary = ev2[choice_text] # the choice action
		choice_text = vn.Utils.MarkUp(choice_text)
		# Preload?
		var choice:Node = load(choice_bar).instance()
		choice.setup_choice(choice_text,choice_ev,vn.show_chosen_choices)
		var _e:int = choice.connect("choice_made", self, "on_choice_made")
		choiceContainer.add_child(choice)
		# waiting for user choice
		
	choiceContainer.visible = true # make it visible now
	
func say(combine : String, words : String, cps = 50, ques:bool = false) -> void:
	var uid:String = express(combine, false, true)
	words = preprocess(words)
	if vn.skipping: cps = 0
	if self.nvl: # little awkward. But stable for now.
		if just_loaded:
			just_loaded = false
			if centered:
				nvlBox.set_dialog(uid, words, cps, true)
			else:
				nvlBox.visible_characters = nvlBox.text.length()
		else:
			if centered:
				nvlBox.set_dialog(uid, words, cps, true)
				vn.Pgs.nvl_text = ''
			else:
				nvlBox.set_dialog(uid, words, cps)
				vn.Pgs.nvl_text = nvlBox.get_text()
			_voice_to_hist((latest_voice!='') and vn.voice_to_history, uid, nvlBox.get_text())
	
	else:
		if not _hide_namebox(uid):
			$VNUI.namebox_follow_chara(uid)
			var info:Dictionary = vn.Chs.all_chara[uid]
			speaker.set("custom_colors/default_color", info["name_color"])
			speaker.bbcode_text = info["display_name"]
			if info.has('font') and info['font'] and not one_time_font_change:
				var fonts:Dictionary = {'normal_font': info['normal_font'],
				'bold_font': info['bold_font'],
				'italics_font':info['italics_font'],
				'bold_italics_font':info['bold_italics_font']}
				dialogbox.set_chara_fonts(fonts)
			elif not one_time_font_change:
				dialogbox.reset_fonts()
		
		if just_loaded:
			dialogbox.set_dialog(words)
			just_loaded = false
		else:
			dialogbox.set_dialog(words, cps)
			var new_text:String = dialogbox.bbcode_text
			_voice_to_hist((latest_voice!='') and vn.voice_to_history, uid, new_text)
			vn.Pgs.playback_events['speech'] = new_text
		
		stage.set_highlight(uid)
	
	wait_for_accept(ques)
	# If this is a question, then displaying the text is all we need.

func extend(ev:Dictionary):
	# Cannot use extend with a choice, extend doesn't support font
	if vn.Pgs.playback_events['speech'] == '' or self.nvl or self.waiting_cho:
		print("!!! Warning: you're getting his warning either because you're in nvl mode")
		print("!!! Or because you're using extend without a previous speech event.")
		print("!!! Or because you're waiting for a choice to be made.")
		print("!!! In all cases, nothing is done.")
		auto_load_next()
	else:
		# get previous speaker from history
		# you will get an error by using extend as the first sentence
		var prev_speaker:String = vn.Pgs.history[-1][0]
		if not _hide_namebox(prev_speaker):
			$VNUI.namebox_follow_chara(prev_speaker)
			var info = vn.Chs.all_chara[prev_speaker]
			speaker.set("custom_colors/default_color", info["name_color"])
			speaker.bbcode_text = info["display_name"]
			
		var ext:String = 'extend'
		if ev.has('ext'): ext = 'ext'

		var words:String = preprocess(ev[ext])
		var cps:float = 50.0
		if ev.has('speed'):
			if (vn.cps_map.has(ev['speed'])):
				cps = vn.cps_map[ev['speed']]
		
		_voice_to_hist(_check_latest_voice(ev) and vn.voice_to_history, prev_speaker, words)
		if just_loaded:
			just_loaded = false
			dialogbox.set_dialog(vn.Pgs.playback_events['speech'], 50)
			vn.Pgs.history.pop_back()
		else:
			dialogbox.bbcode_text = vn.Pgs.playback_events['speech']
			dialogbox.set_dialog(words, cps, true)
			vn.Pgs.playback_events['speech'] += " " + words
			
		stage.set_highlight(prev_speaker)
		# wait for accept
		wait_for_accept(false)

func wait_for_accept(ques:bool = false):
	waiting_acc = true
	if not ques:
		yield(self, "player_accept")
		if _nullify_prev_yield == false: # if this is false, then it's natural dialog progression
			if allow_rollback: vn.Pgs.makeSnapshot()
			music.stop_voice()
			if centered:
				nvl_off()
				centered = false
			if not self.nvl: stage.remove_highlight()
			waiting_acc = false
			auto_load_next()
		else: # The yield has been nullified, that means some outside code is trying to change dialog blocks
			# back to default
			_nullify_prev_yield = false


#------------------------ Related to Music and Sound ---------------------------
func play_bgm(ev : Dictionary, auto_forw=true) -> void:
	var path:String = ev['bgm']
	if (path in ["","off"]) and ev.size() == 1:
		music.stop_bgm()
		vn.Pgs.playback_events['bgm'] = {'bgm':''}
		auto_load_next(auto_forw)
		return
		
	#if path == "pause":
	#	music.pause_bgm()
	#	auto_load_next()
	#	return
	#elif path == "resume":
	#	music.resume_bgm()
	#	auto_load_next()
	#	return
		
	# Deal with fadeout first
	if path == "" and ev.size() > 1: # must be a fadeout
		if ev.has('fadeout'):
			music.fadeout(ev['fadeout'])
			vn.Pgs.playback_events['bgm'] = {'bgm':''}
			auto_load_next(auto_forw)
			return
		else:
			push_error('Expecting a fadeout field with time as its value.')
	# Now we're sure it's either play bgm or fadein bgm
	var vol:float = _u._has_or_default(ev,'vol',0.0)
	_cur_bgm = path
	music.bgm = path
	var music_path:String = vn.BGM_DIR + path
	if not ev.has('fadein'): # has path or volume
		music.play_bgm(music_path, vol)
		vn.Pgs.playback_events['bgm'] = ev
		auto_load_next(auto_forw)
		return
			
	if ev.has('fadein'):
		music.fadein(music_path, ev['fadein'], vol)
		vn.Pgs.playback_events['bgm'] = ev
		auto_load_next(auto_forw)
		return
	else:
		push_error('Expecting a fadein field with time as its value.')
	
func play_sound(ev :Dictionary) -> void:
	music.play_sound(vn.AUDIO_DIR+ev['audio'], _u._has_or_default(ev, "vol", 0))
	auto_load_next()
	
func voice(path:String, auto_forw:bool = true) -> void:
	music.play_voice(vn.VOICE_DIR+path)
	auto_load_next(auto_forw)
	
#------------------- Related to Background and Godot Scene Change ----------------------

func change_background(ev : Dictionary, auto_forw=true) -> void:
	var path:String = ev['bg']
	if ev.size() == 1 or vn.skipping or vn.inLoading:
		bg.bg_change(path)
	else: # size > 1
		var eff_name:String=""
		for k in ev.keys():
			if k in vn.TRANSITIONS:
				eff_name = k
				break
		if eff_name == "":
			print("!!! Unknown transition at " + str(ev))
			push_error("Unknown transition type given in bg change event.")
		var eff_dur:float = float(ev[eff_name])/2 # transition effect total duration / 2
		var color:Color = _u._has_or_default(ev, 'color', Color.black)
		screen.screen_transition("full",eff_name,color,eff_dur,path)
		yield(screen, "transition_finished")
	
	vn.Pgs.playback_events['bg'] = path
	auto_load_next(!vn.inLoading and auto_forw)

func change_scene_to(path : String):
	stage.clean_up()
	change_weather('', false) # NOT screen.weather_off because we need to tell the sys
	# remove record of weather, which is only done in change_weather()
	QM.reset_auto_skip()
	print("You are changing scene. Rollback will be cleared. It's a good idea to explain "+\
	"to the player the rules about rollback.")
	vn.Pgs.rollback_records.clear()
	if path in [vn.title_screen_path, vn.ending_scene_path]:
		music.stop_bgm()
		var _err:int = get_tree().change_scene(vn.ROOT_DIR + path)
	elif path == "free":
		music.stop_bgm()
		queue_free()
	else:
		var _err:int = get_tree().change_scene(vn.ROOT_DIR + path)

#------------------------------ Related to Dvar --------------------------------
func set_dvar(ev : Dictionary) -> void:
	var og:String = ev['dvar']
	# The order is crucial, = has to be at the end.
	var separators:Array = ["+=","-=","*=","/=", "^=", "="]
	var sep:String = ""
	var splitted:PoolStringArray
	var left:String
	var right:String
	
	# Worse than if else chains, but whatever...
	for s in separators:
		if s in og:
			sep = s
			splitted = og.split(s)
			left = splitted[0].strip_edges()
			right = splitted[1].strip_edges()
			break
	
	if sep == "":
		print("!!! Dvar error: " + str(ev))
		push_error("No assignment found.")
		
	if vn.dvar.has(left):
		if typeof(vn.dvar[left])== TYPE_STRING:
			# If we get string, just set it to RHS
			vn.dvar[left] = right
		else:
			var result = vn.Utils.read(right)
			if result: # result not null
				vn.dvar[left] = result
			else:
				match sep:
					"=": vn.dvar[left] = vn.Utils.calculate(right)
					"+=": vn.dvar[left] += vn.Utils.calculate(right)
					"-=": vn.dvar[left] -= vn.Utils.calculate(right)
					"*=": vn.dvar[left] *= vn.Utils.calculate(right)
					"/=": vn.dvar[left] /= vn.Utils.calculate(right)
					"^=": vn.dvar[left] = pow(vn.dvar[left], vn.Utils.calculate(right))
			
	else:
		print("!!! Dvar error: " + str(ev))
		push_error("Dvar {0} not found".format({0:left}))
	
	emit_signal("dvar_set")
	propagate_dvar_calls(left)
	auto_load_next()
	
func check_condition(cond_list) -> bool:
	if typeof(cond_list) == TYPE_STRING: # if this is a string, not a list
		cond_list = [cond_list]
	var final_result:bool = true # start by assuming final_result is true
	var is_or:bool = false
	while cond_list.size() > 0:
		var result:bool = false
		var cond = cond_list.pop_front()
		if all_conditions.has(cond):
			cond = all_conditions[cond]
		var type:int = typeof(cond)
		if type == TYPE_STRING:
			if cond in ["or","||"]:
				is_or = true
				continue
			elif vn.dvar.has(cond) and typeof(vn.dvar[cond]) == TYPE_BOOL:
				result = vn.dvar[cond]
				final_result = _a_what_b(is_or, final_result, result)
				is_or = false
				continue

			var parsed:PoolStringArray = split_equation(cond)
			var front = parsed[0]
			var rel= parsed[1]
			var back= parsed[2]
			front = vn.Utils.calculate(front)
			back = vn.Utils.calculate(back)
			match rel:
				"=", "==": result = (front == back)
				"<=": result = (front <= back)
				">=": result = (front >= back)
				"<": result = (front < back)
				">": result = (front > back)
				"!=": result = (front!= back)
				_: push_error("Unknown relation %s" %rel)
			
			final_result = _a_what_b(is_or, final_result, result)
		elif type == TYPE_ARRAY: # array type
			final_result = _a_what_b(is_or, final_result, check_condition(cond))
		else:
			push_error("Unknown entry in the condition array %s." %cond_list)

		is_or = false
	# If for loop ends, then all conditions must be passed. 
	return final_result
	
func _a_what_b(is_or:bool, a:bool, b:bool)->bool:
	if is_or: return (a or b)
	else: return (a and b)
#--------------- Related to transition and other screen effects-----------------
func screen_effects(ev: Dictionary, auto_forw=true):
	var temp:Array = ev['screen'].split(" ")
	var ef:String = temp[0]
	match ef:
		"", "off": 
			screen.removeLasting()
			vn.Pgs.playback_events.erase('screen')
		"tint": tint(ev)
		"tintwave": tint(ev)
		"flashlight": flashlight(ev)
		_:
			if temp.size()==2 and not vn.skipping:
				var mode:String = temp[1]
				var c:Color = _u._has_or_default(ev, "color", Color.black)
				var t:float = _u._has_or_default(ev,"time",1.0)
				if ef in vn.TRANSITIONS:
					if mode == "out": # this might be a bit counter-intuitive
						# but we have to stick with this
						screen.screen_transition('in',ef,c,t)
						yield(screen, "transition_mid_point_reached")
					elif mode == "in":
						screen.screen_transition('out',ef,c,t)
						yield(screen, "transition_finished")
				screen.reset()
	
	auto_load_next(!vn.inLoading and auto_forw)

func flashlight(ev:Dictionary):
	screen.flashlight(_u._has_or_default(ev, 'scale', Vector2(1,1)))
	vn.Pgs.playback_events['screen'] = ev

func tint(ev : Dictionary) -> void:
	if ev.has('color'):
		if ev['screen'] == 'tintwave':
			screen.tintWave(ev['color'], _u._has_or_default(ev,'time',1.0))
		elif ev['screen'] == 'tint':
			screen.tint(ev['color'], _u._has_or_default(ev,'time',1.0))
			# When saving to playback, no need to replay the fadein effect
			ev['time'] = 0.05
		vn.Pgs.playback_events['screen'] = ev
	else:
		print("!!! Screen tint event format error.")
		push_error("Tint or tintwave requires a color field.")

# Scene animations/special effects
func sfx_player(ev : Dictionary) -> void:
	var target_scene:Node = load(vn.ROOT_DIR + ev['sfx']).instance()
	if ev.has('loc'):
		target_scene.set("position", ev['loc'])
	if ev.has('params'):
		target_scene.set("params", ev['params'])
	add_child(target_scene)
	if ev.has('anim'):
		var a:AnimationPlayer = target_scene.get_node_or_null('AnimationPlayer')
		if a and a.has_animation(ev['anim']):
			a.play(ev['anim'])
		else:
			print("!!! Warning: your target scene either has no AnimationPlayer subnode or it has no "+\
			"animation named %s. Nothing is done." %ev['anim'])
			print("!!! Your animation player must be named 'AnimationPlayer' for the system to recognize it.")
	auto_load_next()

# Refactor
func camera_effect(ev : Dictionary) -> void:
	var ef_name:String = ev['camera']
	match ef_name:
		"vpunch": camera.vpunch()
		"hpunch": camera.hpunch()
		"reset", '': camera.reset()
		"zoom":
			QM.reset_skip()
			if ev.has('scale'):
				var type:String = _u._has_or_default(ev,'type','linear')
				if type == 'instant' or vn.skipping:
					camera.zoom(ev['scale'], _u._has_or_default(ev,'loc',Vector2(0,0)))
				else:
					camera.zoom_timed(ev['scale'], _u._has_or_default(ev,'time',1), type,\
						_u._has_or_default(ev,'loc',Vector2(0,0)))
				vn.Pgs.playback_events['camera'] = {'zoom':camera.target_zoom, 'offset':camera.target_offset,\
				'deg':camera.target_degree}
			else:
				print("!!! Wrong camera zoom format: %s" %ev)
				push_error('Camera zoom expects a scale.')
		"move":
			QM.reset_skip()
			var time:float = _u._has_or_default(ev, 'time', 1)
			var type:String = _u._has_or_default(ev, 'type', 'linear')
			if ev.has('loc'):
				if vn.skipping or type == "instant": time = 0
				camera.camera_move(ev['loc'], time, type)
				vn.Pgs.playback_events['camera'] = {'zoom':camera.target_zoom, 'offset':camera.target_offset, 'deg':camera.target_degree}
			else:
				print("!!! Wrong camera event format: " + str(ev))
				push_error("Camera move expects a loc and time, and type (optional)")
		"shake":
			if not vn.skipping: # min shake time is 0.5, default 2.0
				camera.shake(_u._has_or_default(ev,'amount',250), max(_u._has_or_default(ev,'time',2.0),0.5))
		"spin":
			if ev.has('deg'):
				var type:String = _u._has_or_default(ev,'type','linear')
				var sdir:int = _u._has_or_default(ev,'sdir', 1)
				if vn.skipping or type == "instant":
					camera.rotation_degrees += (sdir*ev['deg'])
					camera.target_degree = camera.rotation_degrees
					vn.Pgs.playback_events['camera'] = {'zoom':camera.target_zoom, 'offset':camera.target_offset,\
					'deg':camera.target_degree}
				else:
					camera.camera_spin(sdir,ev['deg'], _u._has_or_default(ev,'time',1.0), type)
					vn.Pgs.playback_events['camera'] = {'zoom':camera.target_zoom, 'offset':camera.target_offset,\
					 'deg':camera.target_degree}
				
			else:
				print("!!! Event format error: " + str(ev))
				push_error("Camera spin event must have a 'deg' degree field.")
		_:
			print("!!! Unknown camera event: " + str(ev))
			push_error("Camera effect not found.")
			
	auto_load_next()
#----------------------------- Related to Character ----------------------------
func character_event(ev : Dictionary) -> void:
	var temp:PoolStringArray = ev['chara'].split(" ")
	if temp.size() != 2:
		push_error('Expecting a uid and an effect name separated by a space.')
	var uid:String = vn.Chs.forward_uid(temp[0]) # uid of the character
	var ef:String = temp[1] # what character effect
	if uid == 'all' or stage.is_on_stage(uid):
		var valid:bool = true
		match ef: # jump and shake will be ignored during skipping
			"shake", "vpunch", "hpunch":
				var modes:Dictionary = {"shake":0, "vpunch":1,"hpunch":2}
				ev['mode'] = modes[ef]
				ef = "shake"
			"leave","fadeout","spin","jump", "scale","add":
				pass 
			'move': 
				if ev.has('amount'):
					ev['loc'] = _parse_loc(ev['amount']) + stage.get_chara_pos(uid)
			_: 
				valid = false
				push_error('Unknown character event/action: %s' % ev)
		if valid: stage.call("character_%s"%ef, uid, ev)
		auto_load_next()
	else: # uid is not all, and character not on stage, must be join or fadein
		if ev.has('loc'):
			if ef in ['join','fadein']:
				stage.call("character_%s"%ef, uid, ev)
				auto_load_next(!vn.inLoading)
			else:
				print("!!! Unknown event: %s"%ev)
				push_error("Unknown character event.")
		else:
			print("!!! Wrong character join/fadein format.")
			push_error("Character join/fadein must have a loc field.")

func express(combine : String, auto_forw:bool = true, ret_uid:bool = false):
	var temp:PoolStringArray = combine.split(" ")
	var uid:String = vn.Chs.forward_uid(temp[0])
	match temp.size():
		1:pass
		2:stage.change_expression(uid,temp[1])
		_: push_error("Wrong express event format.")
	auto_load_next(auto_forw)
	if ret_uid: return uid

#--------------------------------- Weather -------------------------------------
func change_weather(we:String, auto_forw = true):
	if !vn.inLoading:
		if we in ["", "off"]:
			vn.Pgs.playback_events.erase('weather')
		else:
			screen.show_weather(we) # If given weather doesn't exist, nothing will happen
			vn.Pgs.playback_events['weather'] = {'weather':we}
		auto_load_next(auto_forw)

#--------------------------------- History -------------------------------------
func history_manipulation(ev: Dictionary):
	# WARNING: 
	# THIS DOES NOT WORK WELL WITH CURRENT IMPLEMENTATION OF ROLLBACK
	var what:String = ev['history']
	if what == "push":
		if ev.size() != 2:
			print("!!! History event format error " + str(ev))
			push_error("History push should have only two fields.")
		
		for k in ev:
			if k != 'history':
				vn.Pgs.updateHistory(PoolStringArray([k, vn.Utils.MarkUp(ev[k])]))
				break
	elif what == "pop":
		vn.Pgs.history.pop_back()
	else:
		print("!!! History event format error " + str(ev))
		push_error("History expects only push or pop.")
	auto_load_next()
	
#--------------------------------- Utility -------------------------------------
func conditional_branch(ev : Dictionary) -> void:
	if check_condition(ev['condition']):
		change_block_to(ev['then'],0)
	else:
		change_block_to(ev['else'],0)

func then(ev : Dictionary) -> void:
	if vn.Files.system_data.has(vn.Pgs.currentNodePath):
		if vn.Pgs.currentIndex > vn.Files.system_data[vn.Pgs.currentNodePath][vn.Pgs.currentBlock]:
			vn.Files.system_data[vn.Pgs.currentNodePath][vn.Pgs.currentBlock] = vn.Pgs.currentIndex
	if ev.has('target id'):
		change_block_to(ev['then'], 1 + get_target_index(ev['then'], ev['target id']))
	else:
		change_block_to(ev['then'],0)
		
func change_block_to(bname : String, bindex:int = 0) -> void:
	idle = false
	if all_blocks.has(bname):
		current_block = all_blocks[bname]
		if bindex >= current_block.size()-1:
			push_error("Cannot go back to the last event of block " + bname + ".")
		else:
			vn.Pgs.currentBlock = bname
			vn.Pgs.currentIndex = bindex
			current_index = bindex 
			if debug_mode:
				print("Debug: current block is " + bname)
				print("Debug: current index is " + str(bindex))
			load_event_at_index(current_index)
	else:
		push_error('Cannot find block with the name ' + bname)

func get_target_index(bname : String, target_id):
	for i in range(all_blocks[bname].size()):
		var ev:Dictionary = all_blocks[bname][i]
		if ev.has('id') and (ev['id'] == target_id):
			return i
	print('!!! Cannot find event with id %s in %s, defaulted to index 0.' % [target_id, bname])
	return 0
	
func sideImageChange(ev:Dictionary, auto_forw:bool = true):
	var path:String = ev['side']
	var sideImage:Sprite = stage.get_node('other/sideImage')
	if path == "":
		sideImage.texture = null
		vn.Pgs.playback_events.erase('side')
	else:
		sideImage.texture = load(vn.SIDE_IMAGE+path)
		vn.Pgs.playback_events['side'] = ev
		stage.set_sideImage(_u._has_or_default(ev,'scale',Vector2(1,1)),\
			_u._has_or_default(ev,'loc',Vector2(-35, 530)))
	auto_load_next(auto_forw)

func check_dialog():
	if not QM.hiding: QM.visible = true
	hide_vnui = false
	if hide_vnui:
		hide_vnui = false
		if self.nvl:
			nvlBox.visible = true
			if self.centered:
				dimming(vn.CENTER_DIM)
			else:
				dimming(vn.NVL_DIM)
		else:
			show_boxes()
	
	if self.nvl and nvlBox.adding:
		nvlBox.force_finish()
	elif not self.nvl and dialogbox.adding:
		dialogbox.force_finish()
	else:
		emit_signal("player_accept", false)

func generate_nullify():
	# Suppose you're in an invetigation scene. Speaker A says something, then 
	# the dialog will enter an yield state and if a player_accept signal comes in, 
	# it will continue. If the signal is generated by generate_nullify(), then
	# the previous yield state will be 'nullified'.
	emit_signal("player_accept", true)

func clear_boxes():
	speaker.bbcode_text = ''
	dialogbox.bbcode_text = ''

func wait(time : float) -> void:
	if just_loaded: just_loaded = false
	if not vn.skipping and time >= 0.05:
		time = stepify(time, 0.1)
		yield(get_tree().create_timer(time), "timeout")
	auto_load_next()
	

func on_choice_made(ev : Dictionary, rollback_to_choice = true) -> void:
	# rollback_to_choice is only used when called externally.
	QM.enable_skip_auto()
	_u.free_children(choiceContainer)
	
	if allow_rollback:
		if rollback_to_choice:
			vn.Pgs.makeSnapshot()
		else:
			vn.Pgs.rollback_records.clear()
	
	waiting_cho = false
	choiceContainer.visible = false
	if ev.size() == 0:
		auto_load_next()
	else:
		interpret_events(ev)

func _yield_check(npy : bool): # npy = nullily_previous_yield
	_nullify_prev_yield = npy

func on_rollback():
	#-------Prepare to rollback
	QM.reset_auto_skip()
	if vn.Pgs.rollback_records.size() >= 1:
		waiting_acc = false
		if idle: # This if branch is needed because of how just_loaded works.
			# Notice (waiting_acc or idle). Ususally player can only rollback when waiting_acc, but
			# idle is the exception. So here we need to treat this a little differently.
			idle = false
		else:
			vn.Pgs.history.pop_back()
		screen.clean_up()
		stage.set_sideImage()
		camera.reset()
		waiting_cho = false
		centered = false
		nvl_off()
		# choiceContainer.propagate_call('queue_free') Will 
		_u.free_children(choiceContainer)
		generate_nullify()
	else: # Show to readers that they cannot rollback further
		vn.Notifs.show('rollback')
		return
	
	#--------Actually rollback
	var last:Dictionary = vn.Pgs.rollback_records.pop_back()
	vn.dvar = last['dvar']
	propagate_dvar_calls()
	vn.Pgs.currentSaveDesc = last['currentSaveDesc']
	vn.Pgs.currentIndex = last['currentIndex']
	vn.Pgs.currentBlock = last['currentBlock']
	vn.Pgs.playback_events = last['playback']	
	vn.Chs.chara_name_patch = last['name_patches']
	vn.Chs.patch_display_names()
	current_index = vn.Pgs.currentIndex
	current_block = all_blocks[vn.Pgs.currentBlock]
	load_playback(vn.Pgs.playback_events, true)
	load_event_at_index(current_index)


func load_playback(play_back:Dictionary, RBM:bool = false): # Roll Back Mode
	vn.inLoading = true
	if play_back.has('bg'):
		bg.bg_change(play_back['bg'])
	if play_back.has('bgm'):
		var bgm = play_back['bgm']
		if RBM:
			if _cur_bgm != bgm['bgm']:
				play_bgm(bgm, false)
		else:
			play_bgm(play_back['bgm'], false)
	if play_back.has('screen'):
		screen_effects(play_back['screen'], false)
	if play_back.has('camera'):
		camera.set_camera(play_back['camera'])
	if play_back.has('weather'):
		change_weather(play_back['weather']['weather'], false)
	if play_back.has('side'):
		sideImageChange(play_back['side'], false)
		
	var ctrl_state:Dictionary = play_back['control_state']
	for k in ctrl_state:
		if ctrl_state[k] == false:
			system({'system': k + " off"})
		else:
			system({'system': k + " on"})
	
	var onStageCharas:Array = []
	for d in play_back['charas']:
		if RBM:
			onStageCharas.push_back(d['uid'])
			if stage.is_on_stage(d['uid']):
				stage.character_move(d['uid'], {'loc':_parse_loc(d['loc'])})
				stage.change_expression(d['uid'], d['expression'])
			else:
				stage.character_join(d['uid'],{'loc': d['loc'], 'expression':d['expression']})
		else:
			stage.character_join(d['uid'],{'loc':d['loc'], 'expression':d['expression']})
		
		stage.set_flip(d['uid'],d['fliph'],d['flipv'])
		stage.character_scale(d['uid'],{'scale':d['scale'], 'type':"instant"})
	
	if RBM: stage.remove_on_rollback(onStageCharas)
	
	if play_back['nvl'] != '':
		nvl_on()
		vn.Pgs.nvl_text = play_back['nvl']
		nvlBox.bbcode_text = vn.Pgs.nvl_text
	
	vn.inLoading = false
	just_loaded = true

func split_equation(line:String):
	var front_var:String = ''
	var back_var:String = ''
	var rel:String = ''
	var presymbol:bool = true
	for i in line.length():
		var le:String = line[i]
		if le != " ":
			var is_symbol:bool = _u._has_or_default({'>':true,'<':true, '=':true
					,'!':true, '+':true, '-':true, '*':true, '/':true},le,false)
			if is_symbol:
				presymbol = false
				rel += le
			if not (is_symbol) and presymbol:
				front_var += le
			if not (is_symbol) and not presymbol:
				back_var += le
	# Check if back var is an expression or a variable
	return PoolStringArray([front_var, rel, back_var])

func flt_text(ev: Dictionary) -> void:
	var wt:float = ev['wait']
	ev['float'] = vn.Utils.MarkUp(ev['float'])
	var loc:Vector2 = _u._has_or_default(ev,'loc', Vector2(600,300))
	var in_t:float = _u._has_or_default(ev, 'fadein', 1)
	var f:Node = load(float_text).instance()
	if ev.has('font') and ev['font'] != "" and ev['font'] != "default":
		f.set_font(vn.ROOT_DIR+ev['font'])
	if ev.has('dir'):
		f.set_movement(ev['dir'], _u._has_or_default(ev,'speed', 30))
	add_child(f)
	if ev.has('time') and ev['time'] > wt:
		f.display(ev['float'], ev['time'], in_t, loc)
	else:
		f.display(ev['float'], wt, in_t, loc)
	
	var has_voice:bool = _check_latest_voice(ev)
	if ev.has('hist') and (_parse_true_false(ev['hist'])):
		_voice_to_hist((has_voice and vn.voice_to_history), _u._has_or_default(ev,'who',''), ev['float'] )
	wait(wt)

func nvl_off():
	show_boxes()
	if nvlBox != null:
		nvlBox.clear() # will queue free
	nvlBox = null
	get_node('background').modulate = Color(1,1,1,1)
	stage.set_modulate_4_all(Color(0.86,0.86,0.86,1))
	self.nvl = false

func nvl_on(center_font:String=''):
	stage.set_modulate_4_all(vn.DIM)
	if centered: nvl_off()
	clear_boxes()
	hide_boxes()
	nvlBox = load(vn.DEFAULT_NVL).instance()
	nvlBox.connect('load_next', self, 'trigger_accept')
	$VNUI.add_child(nvlBox)
	if centered:
		nvlBox.center_mode()
		if center_font != '':
			nvlBox.add_font_override('normal_font', load(vn.ROOT_DIR+center_font))
		get_node('background').modulate = vn.CENTER_DIM
		stage.set_modulate_4_all(vn.CENTER_DIM)
	else:
		get_node('background').modulate = vn.NVL_DIM
		stage.set_modulate_4_all(vn.NVL_DIM)
	self.nvl = true

func trigger_accept():
	if not waiting_cho:
		emit_signal("player_accept", false)
		if hide_vnui:
			if not QM.hiding: QM.visible = true
			if self.nvl:
				nvlBox.visible = true
				if self.centered:
					dimming(vn.CENTER_DIM)
				else:
					dimming(vn.NVL_DIM)
			else:
				show_boxes()
		
func hide_UI(show=false):
	if show:
		hide_vnui = false
	else:
		hide_vnui = ! hide_vnui 
	if hide_vnui:
		QM.visible = false
		hide_boxes()
		if self.nvl:
			nvlBox.visible = false
			dimming(Color(1,1,1,1))
	else:
		if not QM.hiding: QM.visible = true
		if self.nvl:
			nvlBox.visible = true
			if self.centered: dimming(vn.CENTER_DIM)
			else: dimming(vn.NVL_DIM)
		else:
			show_boxes()

func hide_boxes():
	hide_all_boxes = true
	$VNUI/dialogBox.visible = false
	$VNUI/nameBox.visible = false
	
func show_boxes():
	if hide_all_boxes:
		$VNUI/dialogBox.visible = true
		$VNUI/nameBox.visible = true
		hide_all_boxes = false
		
func _hide_namebox(uid:String):
	if hide_all_boxes == false:
		$VNUI/nameBox.visible = true
	if vn.Chs.all_chara.has(uid):
		var info:Dictionary = vn.Chs.all_chara[uid]
		if info.has('no_nb') and info['no_nb']:
			$VNUI/nameBox.visible = false
			return true
	return false
	
# checks if the dict has something, if so, return the value of the field. Else return the
# given default val
#func _has_or_default(ev:Dictionary, fname:String , default):
#	if ev.has(fname): return ev[fname]
#	else: return default

# Check this event for latest voice... If there is a voice field,
# play the voice and then return true
func _check_latest_voice(ev:Dictionary)->bool:
	if ev.has('voice'):
		latest_voice = ev['voice']
		if not vn.skipping:
			voice(ev['voice'], false)
			return true
	else:
		latest_voice = ''
	return false
	
func _voice_to_hist(has_v:bool, who:String, text:String)->void:
	if has_v: vn.Pgs.updateHistory(PoolStringArray([who, text, latest_voice]))
	else: vn.Pgs.updateHistory(PoolStringArray([who, text]))

func dimming(c : Color):
	$background.modulate = c
	stage.set_modulate_4_all(c)
	
func call_method(ev:Dictionary, auto_forw:bool = true):
	# rollback and save are not taken care of by default because
	# there is no way to predict what the method will do
	if ev.has('params'): callv(ev['call'], ev['params'])
	else: callv(ev['call'], [])
	auto_load_next(auto_forw)

func register_dvar_propagation(method_name:String, dvar_name:String)->void:
	if vn.dvar.has(dvar_name):
		_propagate_dvar_list[method_name] = dvar_name
	else:
		print("The dvar %s cannot be found. Nothing is done." % dvar_name)

func propagate_dvar_calls(dvar_name:String='')->void:
	# propagate to call all methods that should be called when a dvar is changed. 
	if dvar_name == '':
		for k in _propagate_dvar_list.keys():
			propagate_call(k, [vn.dvar[_propagate_dvar_list[k]]], true)
	else:
		for k in _propagate_dvar_list.keys():
			if _propagate_dvar_list[k] == dvar_name:
				propagate_call(k, [vn.dvar[dvar_name]], true)

func system(ev : Dictionary):
	if ev.size() != 1:
		print("--- Warning: wrong system event format for " + str(ev)+" ---")
		push_error("---System event only receives one field.---")
	
	var k:String = ev.keys()[0]
	var temp:Array = ev[k].split(" ")
	match temp[0]:
		"auto": # You cannot turn auto on.
			# Simply turns off dialog auto forward if somehow it is on.
			if temp[1] == "off": QM.reset_auto()
			
		"skip": # same as above
			if temp[1] == "off": QM.reset_skip()
				
		"clear": clear_boxes()
			
		"rollback", "roll_back" ,"RB":
			# Example {system: RB clear} clears all rollback saves
			# {system: RB clear_3} clears last 3 rollback saves
			if temp[1] == "clear":
				vn.Pgs.rollback_records.clear()
			else:
				var splitted:PoolStringArray = temp[1].split('_')
				if splitted[0] == 'clear' and splitted[1].is_valid_integer():
					for _i in range(int(splitted[1])):
						vn.Pgs.rollback_records.pop_back()
		"auto_save", "AS": # make a save, with 0 seconds delay, and save
			# at current index - 1 because the current event is sys:auto_save
			# Only place this immediately after a dialog to avoid unexpected errors.
			vn.Utils.make_a_save("[Auto Save] ",0,1)
		"make_save", "MS":
			QM.reset_auto_skip()
			vn.Notifs.show("make_save")
			yield(vn.Notifs.get_current_notif(), "clicked")

		# The above are not included in 'all'.
		"right_click", "RC":
			if temp[1] == "on":
				no_right_click = false
			elif temp[1] == "off":
				no_right_click = true
			vn.Pgs.control_state['right_click'] = no_right_click
				
		"quick_menu", "QM":
			if temp[1] == "on":
				QM.visible = true
				QM.hiding = false
				vn.Pgs.control_state['quick_menu'] = true
			elif temp[1] == "off":
				QM.visible = false
				QM.hiding = true
				vn.Pgs.control_state['quick_menu'] = false
		
		"boxes":
			if temp[1] == "on":
				show_boxes()
				vn.Pgs.control_state['boxes'] = true
			elif temp[1] == "off":
				hide_boxes()
				vn.Pgs.control_state['boxes'] = false
				
		"scroll":
			if temp[1] == "on":
				no_scroll = false
			elif temp[1] == "off":
				no_scroll = true
			vn.Pgs.control_state['scroll'] = !no_scroll 
				
		"all":
			if temp[1] == "on":
				no_scroll = false
				QM.visible = true
				QM.hiding = false
				no_right_click = false
				show_boxes()
				vn.Pgs.resetControlStates()
			elif temp[1] == "off":
				no_scroll = true
				QM.visible = false
				QM.hiding = true
				no_right_click = true
				hide_boxes()
				vn.Pgs.resetControlStates(false)

	auto_load_next(!vn.inLoading)
	
#-------------------- Extra Preprocessing ----------------------
func _parse_loc(loc, ev = {}) -> Vector2:
	var t:int = typeof(loc)
	if t == TYPE_VECTOR2: return loc
	if t == TYPE_STRING and (loc.to_lower() == "r"):
		var v:Vector2 = get_viewport().size
		return MyUtils.random_vec(Vector2(100,v.x-100),Vector2(80,v.y-80))
	# If you get error here, that means the string cannot be split
	# as floats with delimiter space.
	var vec:PoolRealArray = loc.split_floats(" ")
	if vec.size() != 2:
		print("!!! Incorrect loc vector format: " + str(ev))
		push_error("2D vector should have two real numbers separated by a space.")
	return Vector2(vec[0], vec[1])
	
func _parse_dir(dir, ev = {}) -> Vector2:
	if dir in vn.DIRECTION: return vn.DIRECTION[dir]
	elif typeof(dir) == TYPE_STRING and (dir.to_lower() == "r"):
		return MyUtils.random_vec(Vector2(-1,1), Vector2(-1,1)).normalized()
	else:
		return _parse_loc(dir, ev).normalized()

func _parse_color(color, ev = {}) -> Color:
	if typeof(color) == TYPE_COLOR:
		return color
	if color.is_valid_html_color():
		return Color(color)
	else:
		# If you get error here, that means the string cannot be split
		# as floats with delimiter space.
		var color_vec:PoolRealArray = color.split_floats(" ", false)
		var s:int = color_vec.size()
		if s in [3,4]:
			if s == 3:
				return Color(color_vec[0], color_vec[1], color_vec[2])
			else:
				return Color(color_vec[0], color_vec[1], color_vec[2], color_vec[3])
		else:
			print("!!! Error color format: " + str(ev))
			push_error("Expecting value of the form float1 float2 float3( float4) after color.")
			return Color()
			
func _parse_nvl(nvl_state):
	var t:int = typeof(nvl_state)
	if t == TYPE_BOOL:
		return nvl_state
	elif t == TYPE_STRING:
		match nvl_state.to_lower():
			"clear": return nvl_state
			"on", "true":  return true
			"off", "false": return false
			_:
				print("!!! Format error for NVL event.")
				push_error("Expecting either boolean or 'true'/'false','on'/'off' strings.")

func _parse_true_false(truth) -> bool:
	match typeof(truth):
		TYPE_BOOL: return truth
		TYPE_STRING:
			if truth.to_lower() == "true": return true
			else: return false # A little sloppy
		_: return false

func _dialog_state_reset():
	if nvl: nvlBox.nw = false
	else: dialogbox.nw = false

# Move this to somewhere else? 
func _notification(what):
	if what == MainLoop.NOTIFICATION_WM_QUIT_REQUEST:
		vn.Notifs.show("quit")
		QM.reset_auto_skip()

func preprocess(words : String) -> String:
	_dialog_state_reset()
	var leng:int = words.length()
	var output:String = ''
	var i:int = 0
	while i < leng:
		var c:String = words[i]
		var inner:String = ""
		if c == '[':
			i += 1
			while words[i] != ']':
				inner += words[i]
				i += 1
				if i >= leng:
					push_error("Please do not use [] unless for bbcode and display dvar purposes.")
			match inner:
				"nw":
					if not vn.skipping:
						if self.nvl: nvlBox.nw = true
						else: dialogbox.nw = true
				"sm": output += ";"
				"dc": output += "::"
				"nl": output += "\n"
				"lb": output += "["
				"rb": output += "]"
				_: 
					if vn.dvar.has(inner): output += str(vn.dvar[inner])
					else: output += '[' + inner + ']'
		else:
			output += c
		i += 1
	return output
	
func _exit_tree():
	vn.Scene = null
	vn.Files.write_to_config()
