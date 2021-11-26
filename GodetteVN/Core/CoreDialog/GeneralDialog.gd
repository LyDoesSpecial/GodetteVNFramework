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
var current_block = null
var all_blocks = null
var all_choices = null
var all_conditions = null
# Other
var latest_voice = null
var idle : bool = false
var _nullify_prev_yield : bool = false
# Only used in rollback
var _cur_bgm = null
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
var _propagate_dvar_list = {}
#----------------------
# Important components
onready var bg = $background
onready var QM = $VNUI/quickMenu
onready var dialogbox = $VNUI/dialogBox/dialogBoxCore
onready var speaker = $VNUI/nameBox/speaker
onready var choiceContainer = $VNUI/choiceContainer
onready var camera = screen.get_node('camera')

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
					return
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
	var ev = event.duplicate(true)
	if debug_mode:
		var msg = "Debug :" + str(ev)
		print(msg)
	
	# Pre-parse, keep this at minimum
	if ev.has('loc'): ev['loc'] = _parse_loc(ev['loc'], ev)
	if ev.has('params'): ev['params'] = _parse_params(ev['params'],ev)
	if ev.has('color'): ev['color'] = _parse_color(ev['color'], ev)
	if ev.has('nvl'): ev['nvl'] = _parse_nvl(ev['nvl'])
	if ev.has('scale'): ev['scale'] = _parse_loc(ev['scale'], ev)
	if ev.has('dir'): ev['dir'] = _parse_dir(ev['dir'], ev)
	# End of pre-parse. Actual match event
	match ev:
		{"condition", "then", "else",..}: conditional_branch(ev)
		{"condition",..}:
			if check_condition(ev['condition']):
				ev.erase('condition')
				continue
			else: # condition fails.
				auto_load_next()
		{"screen",..}: screen_effects(ev)
		{"bg",..}: change_background(ev)
		{"chara",..}: character_event(ev)
		{"weather"}: change_weather(ev['weather'])
		{"camera", ..}: camera_effect(ev)
		{"express"}: express(ev['express'])
		{"bgm",..}: play_bgm(ev)
		{'audio',..}: play_sound(ev)
		{'dvar'}: set_dvar(ev)
		{'sfx',..}: sfx_player(ev)
		{'then',..}: then(ev)
		{'extend', ..}, {'ext', ..}:extend(ev)
		{'premade'}:
			if debug_mode: print("!!! PREMADE EVENT:")
			interpret_events(vn.Utils.call_premade_events(ev['premade']))
		{"system"},{"sys"}: system(ev)
		{'side'}: sideImageChange(ev)
		{'choice',..}: generate_choices(ev)
		{'wait'}: wait(ev['wait'])
		{'nvl'}: set_nvl(ev)
		{'GDscene'}: change_scene_to(ev['GDscene'])
		{'history', ..}: history_manipulation(ev)
		{'float', 'wait',..}: flt_text(ev)
		{'voice'}:voice(ev['voice'])
		{'id'}, {}:auto_load_next()
		{'call', ..}: call_method(ev)
		{'center',..}: set_center(ev)
		_: speech_parse(ev)
				

#----------------------- on ready, new game, load, set up, end -----------------
func auto_start(start_block:String="starter", start_id=null):
	var load_instruction = vn.Pgs.load_instruction
	print("!!! Beta Notice: auto_start currently only works if you use json files for dialog. ---")
	if load_instruction != "new_game" and load_instruction != "load_game":
		print("!!! Unknown load instruction. It can either be new_game or load_game.")
		return false
	
	if self.dialog_json == "":
		print("!!! For auto_start, you need to provide a dialog json file.")
		return false
	else:
		var dialog_data = vn.Files.load_json(dialog_json)
		if dialog_data.has('Dialogs') and dialog_data.has('Choices'):
			if dialog_data.has('Conditions'):
				start_scene(dialog_data['Dialogs'],dialog_data['Choices'],dialog_data['Conditions'], load_instruction,\
					start_block, start_id)
			else:
				start_scene(dialog_data['Dialogs'],dialog_data['Choices'],{}, load_instruction,\
					start_block, start_id)
			return true
		else:
			print("Dialog json file must contain 'Dialogs' and 'Choices' (even if empty).")
			return false
			
func get_all_dialog_blocks():
	return all_blocks
		
func start_scene(blocks : Dictionary, choices: Dictionary, conditions: Dictionary,\
	load_instruction : String = "new_game", start_block:String="starter", start_id=null) -> void:
	vn.Scene = self
	get_tree().set_auto_accept_quit(false)
	vn.Pgs.currentSaveDesc = scene_description
	vn.Pgs.currentNodePath = get_tree().current_scene.filename
	all_blocks = blocks
	all_choices = choices
	all_conditions = conditions
	dialogbox.connect('load_next', self, 'trigger_accept')
	if load_instruction == "new_game":
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
	elif load_instruction == "load_game":
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


func auto_load_next():
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
		
		if auto_forw: auto_load_next()
	elif ev['nvl'] == 'clear':
		nvlBox.clear()
		if auto_forw: auto_load_next()
	else:
		vn.error('nvl expects a boolean or the keyword clear.', ev)
	
func set_center(ev: Dictionary):
	self.centered = true
	if ev.has('font'):
		set_nvl({'nvl': true,'font':ev['font']}, false)
	else:
		set_nvl({'nvl': true}, false)
	var u = _has_or_default(ev,"who","")
	if ev.has('speed'):
		say(u, ev['center'], ev['speed'])
	else:
		say(u, ev['center'])
	var _has_voice = _check_latest_voice(ev)

func speech_parse(ev : Dictionary) -> void:
	# Voice first
	var _has_voice = _check_latest_voice(ev)
	# one time font change
	one_time_font_change = ev.has('font')
	if one_time_font_change:
		var path = vn.FONT_DIR + ev['font']
		dialogbox.add_font_override('normal_font', load(path))

	# Speech
	var combine = "wwttff123"
	for k in ev.keys(): # k is not voice, not speed, means it has to be "uid expression"
		if k != 'voice' and k != 'speed':
			combine = k # combine=unique_id and expression combined
			break
	if combine == "wwttff123": # for loop ends without setting combine
		vn.error("Speech event requires a valid character/narrator." ,ev)
	
	if ev.has('speed'):
		if (vn.cps_map.has(ev['speed'])):
			say(combine, ev[combine],vn.cps_map[ev['speed']] )
		else:
			print("!!! Unknown speed value in " + str(ev))
			push_error("Unknown speed value.")
		# Should I allow other values?
		#elif typeof(ev['speed']) == TYPE_INT or typeof(ev['speed']) == TYPE_REAL:
		#	say(combine, ev[combine], ev['speed'])
	else:
		say(combine, ev[combine])

func generate_choices(ev: Dictionary):
	# make a say event
	if self.nvl: nvl_off()
	else:
		dialogbox.text = ""
		speaker.text = ""
	if vn.auto_on or vn.skipping:
		QM.disable_skip_auto()
	
	var _has_voice = _check_latest_voice(ev)
	one_time_font_change = ev.has('font')
	if one_time_font_change:
		var path = vn.FONT_DIR + ev['font']
		dialogbox.add_font_override('normal_font', load(path))
	var combine
	for k in ev.keys():
		if k != 'id' and k != 'choice' and k != 'voice':
			combine = k
			break
	if combine: # if not null
		say(combine, ev[combine], 0, true)
	
	if ev['choice'] == '' or ev['choice'] == 'url': 
		# This is for url (in-line, textbased) choices
		# Unimplemented
		return
	# Actual choices
	var options = all_choices[ev['choice']]
	waiting_cho = true
	for i in options.size():
		var ev2 = options[i]
		if ev2.size()>2: 
			vn.error('Only size 1 or 2 dict will be accepted as choice.')
		elif ev2.size() == 2:
			if ev2.has('condition'):
				if not check_condition(ev2['condition']):
					continue # skip to the next choice if condition not met
			else:
				vn.error('If a choice is size 2, then it has to have a condition.')
					
		var choice_text = ''
		for k in ev2.keys():
			if k != "condition":
				choice_text = k # grab the key not equal to condition
				break
		
		var choice_ev = ev2[choice_text] # the choice action
		choice_text = vn.Utils.MarkUp(choice_text)
		# Preload?
		var choice = load(choice_bar).instance()
		choice.setup_choice(choice_text,choice_ev,vn.show_chosen_choices)
		choice.connect("choice_made", self, "on_choice_made")
		choiceContainer.add_child(choice)
		# waiting for user choice
		
	choiceContainer.visible = true # make it visible now
	
func say(combine : String, words : String, cps = 50, ques = false) -> void:
	var uid = express(combine, false, true)
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
			_voice_to_hist((latest_voice!=null) and vn.voice_to_history, uid, nvlBox.get_text())
	
	else:
		if not _hide_namebox(uid):
			$VNUI.namebox_follow_chara(uid)
			var info = vn.Chs.all_chara[uid]
			speaker.set("custom_colors/default_color", info["name_color"])
			speaker.bbcode_text = info["display_name"]
			if info.has('font') and info['font'] and not one_time_font_change:
				var fonts = {'normal_font': info['normal_font'],
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
			var new_text = dialogbox.bbcode_text
			_voice_to_hist((latest_voice!=null) and vn.voice_to_history, uid, new_text)
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
		var prev_speaker = vn.Pgs.history[-1][0]
		if not _hide_namebox(prev_speaker):
			$VNUI.namebox_follow_chara(prev_speaker)
			var info = vn.Chs.all_chara[prev_speaker]
			speaker.set("custom_colors/default_color", info["name_color"])
			speaker.bbcode_text = info["display_name"]
			
		var ext = 'extend'
		if ev.has('ext'): ext = 'ext'

		var words = preprocess(ev[ext])
		var cps = 50
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
	var path = ev['bgm']
	if (path == "" or path == "off") and ev.size() == 1:
		music.stop_bgm()
		vn.Pgs.playback_events['bgm'] = {'bgm':''}
		if auto_forw: auto_load_next()
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
			if auto_forw: auto_load_next()
			return
		else:
			vn.error('If fadeout is intended, please supply a time. Otherwise, unknown '+\
			'keyword format.', ev)
			
	# Now we're sure it's either play bgm or fadein bgm
	var vol = _has_or_default(ev,'vol',0)
	_cur_bgm = path
	music.bgm = path
	var music_path = vn.BGM_DIR + path
	if not ev.has('fadein'): # has path or volume
		music.play_bgm(music_path, vol)
		vn.Pgs.playback_events['bgm'] = ev
		if auto_forw: auto_load_next()
		return
			
	if ev.has('fadein'):
		music.fadein(music_path, ev['fadein'], vol)
		vn.Pgs.playback_events['bgm'] = ev
		if auto_forw: auto_load_next()
		return
	else:
		vn.error('If fadein is intended, please supply a time. Otherwise, unknown '+\
		'keyword format.', ev)
	
	
func play_sound(ev :Dictionary) -> void:
	var audio_path = vn.AUDIO_DIR + ev['audio']
	var vol = _has_or_default(ev, "vol", 0)
	music.play_sound(audio_path, vol)
	auto_load_next()
	
		
func voice(path:String, auto_forw:bool = true) -> void:
	var voice_path = vn.VOICE_DIR + path
	music.play_voice(voice_path)
	if auto_forw: auto_load_next()
	
#------------------- Related to Background and Godot Scene Change ----------------------
# Bad code. GET RID OF YIELD HERE.
func change_background(ev : Dictionary, auto_forw=true) -> void:
	var path = ev['bg']
	if ev.size() == 1 or vn.skipping or vn.inLoading:
		bg.bg_change(path)
	else: # size > 1
		var eff_name = ""
		for k in ev.keys():
			if k in vn.TRANSITIONS:
				eff_name = k
				break
		if eff_name == "":
			print("!!! Unknown transition at " + str(ev))
			push_error("Unknown transition type given in bg change event.")
			
		var eff_dur = float(ev[eff_name])/2 # transition effect total duration / 2
		var color = _has_or_default(ev, 'color', Color.black)
		screen.screen_transition("full",eff_name,color,eff_dur,path)
		yield(screen, "transition_finished")
	
	if !vn.inLoading and auto_forw:
		vn.Pgs.playback_events['bg'] = path
		auto_load_next()

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
	if path == "free":
		music.stop_bgm()
		self.queue_free()
	else:
		var error = get_tree().change_scene(vn.ROOT_DIR + path)
		if error == OK:
			self.queue_free()

#------------------------------ Related to Dvar --------------------------------
func set_dvar(ev : Dictionary) -> void:
	var og = ev['dvar']
	# The order is crucial, = has to be at the end.
	var separators = ["+=","-=","*=","/=", "^=", "="]
	var sep = ""
	var splitted
	var left
	var right
	
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
		var type = typeof(cond)
		if type == TYPE_STRING:
			if cond in ["or","||"]:
				is_or = true
				continue
			elif vn.dvar.has(cond) and typeof(vn.dvar[cond]) == TYPE_BOOL:
				result = vn.dvar[cond]
				final_result = _a_what_b(is_or, final_result, result)
				is_or = false
				continue

			var parsed = split_equation(cond)
			var front = parsed[0]
			var rel = parsed[1]
			var back = parsed[2]
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
	if is_or:
		return (a or b)
	else:
		return (a and b)
#--------------- Related to transition and other screen effects-----------------
func screen_effects(ev: Dictionary, auto_forw=true):
	var temp = ev['screen'].split(" ")
	var ef = temp[0]
	match ef:
		"", "off": 
			screen.removeLasting()
			vn.Pgs.playback_events.erase('screen')
		"tint": tint(ev)
		"tintwave": tint(ev)
		"flashlight": flashlight(ev)
		_:
			if temp.size()==2 and not vn.skipping:
				var mode = temp[1]
				var c = _has_or_default(ev, "color", Color.black)
				var t = _has_or_default(ev,"time",1)
				if ef in vn.TRANSITIONS:
					if mode == "out": # this might be a bit counter-intuitive
						# but we have to stick with this
						screen.screen_transition('in',ef,c,t)
						yield(screen, "transition_mid_point_reached")
					elif mode == "in":
						screen.screen_transition('out',ef,c,t)
						yield(screen, "transition_finished")
				screen.reset()
	
	if !vn.inLoading and auto_forw: auto_load_next()

func flashlight(ev:Dictionary):
	var sc = _has_or_default(ev, 'scale', Vector2(1,1))
	screen.flashlight(sc)
	vn.Pgs.playback_events['screen'] = ev

func tint(ev : Dictionary) -> void:
	if ev.has('color'):
		if ev['screen'] == 'tintwave':
			screen.tintWave(ev['color'], _has_or_default(ev,'time',1))
		elif ev['screen'] == 'tint':
			screen.tint(ev['color'], _has_or_default(ev,'time',1))
			# When saving to playback, no need to replay the fadein effect
			ev['time'] = 0.05
			
		vn.Pgs.playback_events['screen'] = ev
	else:
		vn.error("Tint or tintwave requires the color field.", ev)

# Scene animations/special effects
func sfx_player(ev : Dictionary) -> void:
	var target_scene = load(vn.ROOT_DIR + ev['sfx']).instance()
	if ev.has('loc'): target_scene.position = ev['loc']
	if ev.has('params'):target_scene.params = ev['params']
	add_child(target_scene)
	if ev.has('anim'):
		var anim = target_scene.get_node('AnimationPlayer')
		if anim.has_animation(ev['anim']):
			anim.play(ev['anim'])
		else:
			vn.error("Animation not found.", ev)

	auto_load_next()

func camera_effect(ev : Dictionary) -> void:
	var ef_name = ev['camera']
	match ef_name:
		"vpunch": if not vn.skipping: camera.vpunch()
		"hpunch": if not vn.skipping: camera.hpunch()
		"reset", '': 
			camera.reset()
			vn.Pgs.playback_events.erase('camera')
		"zoom":
			QM.reset_skip()
			if ev.has('scale'):
				var type = _has_or_default(ev,'type','linear')
				if type == 'instant' or vn.skipping:
					camera.zoom(ev['scale'], _has_or_default(ev,'loc',Vector2(0,0)))
				else:
					camera.zoom_timed(ev['scale'], _has_or_default(ev,'time',1), type, _has_or_default(ev,'loc',Vector2(0,0)))
				vn.Pgs.playback_events['camera'] = {'zoom':camera.target_zoom, 'offset':camera.target_offset,\
				'deg':camera.target_degree}
			else:
				vn.error('Camera zoom expects a scale.', ev)
		"move":
			QM.reset_skip()
			var time = _has_or_default(ev, 'time', 1)
			var type = _has_or_default(ev, 'type', 'linear')
			if ev.has('loc'):
				if vn.skipping or type == "instance": time = 0
				camera.camera_move(ev['loc'], time, type)
				vn.Pgs.playback_events['camera'] = {'zoom':camera.target_zoom, 'offset':camera.target_offset, 'deg':camera.target_degree}
			else:
				print("!!! Wrong camera event format: " + str(ev))
				push_error("Camera move expects a loc and time, and type (optional)")
		"shake":
			if not vn.skipping:
				camera.shake(_has_or_default(ev,'amount',250), _has_or_default(ev,'time',2))
		"spin":
			if ev.has('deg'):
				var type = _has_or_default(ev,'type','linear')
				var sdir = _has_or_default(ev,'sdir', 1)
				if vn.skipping or type == "instant":
					camera.rotation_degrees += (sdir*ev['deg'])
					camera.target_degree = camera.rotation_degrees
					vn.Pgs.playback_events['camera'] = {'zoom':camera.target_zoom, 'offset':camera.target_offset,\
					'deg':camera.target_degree}
				else:
					camera.camera_spin(sdir,ev['deg'], _has_or_default(ev,'time',1.0), type)
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
	# For character event, auto_load_next should be considered within
	# each individual method.
	var temp = ev['chara'].split(" ")
	if temp.size() != 2:
		vn.error('Expecting a uid and an effect name separated by a space.', ev)
	var uid = vn.Chs.forward_uid(temp[0]) # uid of the character
	var ef = temp[1] # what character effect
	if uid == 'all' or stage.is_on_stage(uid):
		match ef: # jump and shake will be ignored during skipping
			"shake", "vpunch", "hpunch": 
				if vn.skipping : 
					auto_load_next()
				else:
					if ef == "vpunch":
						character_shake(uid, ev, 1)
					elif ef == "hpunch":
						character_shake(uid, ev, 2)
					else:
						character_shake(uid, ev, 0)
			"add": character_add(uid, ev)
			"spin": character_spin(uid,ev)
			"jump": 
				if vn.skipping : 
					auto_load_next()
				else:
					character_jump(uid, ev)
			'move': 
				if uid == 'all': 
					print("!!! Warning: Attempting to move all character at once.")
					print("!!! This is currently not allowed and this event is ignored.")
					auto_load_next()
				else:
					character_move(uid, ev)
			'fadeout': 
				if vn.skipping:
					stage.remove_chara(uid)
					auto_load_next()
				else:
					character_fadeout(uid,ev)
			'leave': 
				stage.remove_chara(uid)
				auto_load_next()
			_: vn.error('Unknown character event/action.', ev)
		
		# End of the branch
		
	else: # uid is not all, and character not on stage
		var expression = _has_or_default(ev,'expression', 'default')
		if ef == 'join':
			if ev.has('loc'):
				stage.join(uid,ev['loc'], expression)
			else:
				vn.error('Character join expects a loc.', ev)
		elif ef == 'fadein':
			if ev.has('loc'): 
				stage.fadein(uid,_has_or_default(ev,'time',1), ev['loc'], expression)
			else:
				vn.error('Character fadein expects a time and a loc.', ev)
		else:
			vn.error('Unknown character event/action.', ev)
			
		if !vn.inLoading:
			auto_load_next()

# This method is here to fill in default values
func character_shake(uid:String, ev:Dictionary, mode:int=0) -> void:
	stage.shake(uid,_has_or_default(ev,'amount',250), _has_or_default(ev,'time',2), mode)
	auto_load_next()
	

func express(combine : String, auto_forw:bool = true, ret_uid:bool = false):
	var temp = combine.split(" ")
	var uid = vn.Chs.forward_uid(temp[0])
	if not (temp.size() in [1, 2]):
		vn.error("Wrong express format.")
	elif temp.size() == 2: # No expression change if temp has size 1.
		stage.change_expression(uid,temp[1])
	if auto_forw: auto_load_next()
	if ret_uid: return uid


func character_jump(uid : String, ev : Dictionary) -> void:
	stage.jump(uid, _has_or_default(ev,'dir',Vector2.UP), _has_or_default(ev,'amount',80), _has_or_default(ev,'time',0.1))
	auto_load_next()
	
# redundant? Directly call stage? No. This one has a yield, which should be here.
func character_fadeout(uid: String, ev:Dictionary):
	var time = _has_or_default(ev,'time',1)
	stage.fadeout(uid, time)
	# yield(get_tree(), "idle_frame")
	auto_load_next()


func character_move(uid:String, ev:Dictionary):
	var type = _has_or_default(ev,'type','linear')
	var expr = _has_or_default(ev,'expression','')
	if ev.has('loc'):
		if type == 'instant' or vn.skipping:
			stage.change_pos(uid, ev['loc'], expr)
		else:
			stage.change_pos_2(uid, ev['loc'], _has_or_default(ev,'time',1), type, expr)
		auto_load_next()
	else:
		vn.error("Character move expects a loc.", ev)

func character_add(uid:String, ev:Dictionary):
	if ev.has('path') and ev.has('at'):
		stage.add_to_chara_at(uid, ev['at'], vn.ROOT_DIR + ev['path'])
		auto_load_next()
	else:
		print("!!! Character add event format error.")
		push_error('Character add expects a path and an "at".')
		
func character_spin(uid:String, ev:Dictionary):
	stage.spin(uid, _has_or_default(ev,'deg',360), _has_or_default(ev,'time',1), _has_or_default(ev,'sdir',1),\
	 _has_or_default(ev,'type','linear'))
	auto_load_next()
#--------------------------------- Weather -------------------------------------
func change_weather(we:String, auto_forw = true):
	screen.show_weather(we) # If given weather doesn't exist, nothing will happen
	if !vn.inLoading:
		if we in ["", "off"]:
			vn.Pgs.playback_events.erase('weather')
		else:
			vn.Pgs.playback_events['weather'] = {'weather':we}
		if auto_forw: auto_load_next()

#--------------------------------- History -------------------------------------
func history_manipulation(ev: Dictionary):
	# WARNING: 
	# THIS DOES NOT WORK WELL WITH CURRENT IMPLEMENTATION OF ROLLBACK
	var what = ev['history']
	if what == "push":
		if ev.size() != 2:
			print("!!! History event format error " + str(ev))
			push_error("History push should have only two fields.")
		
		for k in ev.keys():
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
			vn.error("Cannot go back to the last event of block " + bname + ".")
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
		var d = all_blocks[bname][i]
		if d.has('id') and (d['id'] == target_id):
			return i
	
	print('!!! Cannot find event with id %s in %s, defaulted to index 0.' % [target_id, bname])
	return 0
	
func sideImageChange(ev:Dictionary, auto_forw:bool = true):
	var path = ev['side']
	var sideImage = stage.get_node('other/sideImage')
	if path == "":
		sideImage.texture = null
		vn.Pgs.playback_events.erase('side')
	else:
		sideImage.texture = load(vn.SIDE_IMAGE+path)
		vn.Pgs.playback_events['side'] = ev
		stage.set_sideImage(_has_or_default(ev,'scale',Vector2(1,1)),_has_or_default(ev,'loc',Vector2(-35, 530)))
	if auto_forw: auto_load_next()

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
	if vn.skipping:
		auto_load_next()
		return
	if time >= 0:
		time = stepify(time, 0.1)
		yield(get_tree().create_timer(time), "timeout")
		auto_load_next()
	else:
		print("Warning: wait time < 0 is ignored.")
		auto_load_next()

func on_choice_made(ev : Dictionary, rollback_to_choice = true) -> void:
	# rollback_to_choice is only used when called externally.
	QM.enable_skip_auto()
	for n in choiceContainer.get_children():
		n.queue_free()
	
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
		for n in choiceContainer.get_children():
			n.queue_free()
		generate_nullify()
	else: # Show to readers that they cannot rollback further
		vn.Notifs.show('rollback')
		return
	
	#--------Actually rollback
	var last = vn.Pgs.rollback_records.pop_back()
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


func load_playback(play_back, RBM = false): # Roll Back Mode
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
		
	var ctrl_state = play_back['control_state']
	for k in ctrl_state.keys():
		if ctrl_state[k] == false:
			system({'system': k + " off"})
		else:
			system({'system': k + " on"})
	
	var onStageCharas = []
	for d in play_back['charas']:
		var dkeys = d.keys()
		var loc = d['loc']
		var fliph = d['fliph']
		var flipv = d['flipv']
		dkeys.erase('loc')
		dkeys.erase('fliph')
		dkeys.erase('flipv')
		var uid = dkeys[0]
		if RBM:
			onStageCharas.push_back(uid)
			if stage.is_on_stage(uid):
				stage.change_pos(uid, _parse_loc(loc))
				stage.change_expression(uid, d[uid])
			else:
				stage.join(uid,loc,d[uid])
		else:
			stage.join(uid,loc,d[uid])
		if fliph: stage.change_expression(uid,'flip')
		if flipv: stage.change_expression(uid,'flipv')
	
	if RBM: stage.remove_on_rollback(onStageCharas)
	
	if play_back['nvl'] != '':
		nvl_on()
		vn.Pgs.nvl_text = play_back['nvl']
		nvlBox.bbcode_text = vn.Pgs.nvl_text
	
	vn.inLoading = false
	just_loaded = true

func split_equation(line:String):
	var arith_symbols = ['>','<', '=', '!', '+', '-', '*', '/']
	var front_var:String = ''
	var back_var:String = ''
	var rel:String = ''
	var presymbol:bool = true
	for i in line.length():
		var le = line[i]
		if le != " ":
			var is_symbol:bool = le in arith_symbols
			if is_symbol:
				presymbol = false
				rel += le
			if not (is_symbol) and presymbol:
				front_var += le
				
			if not (is_symbol) and not presymbol:
				back_var += le
	
	# Check if back var is an expression or a variable
	
	return [front_var, rel, back_var]

func flt_text(ev: Dictionary) -> void:
	var wt = ev['wait']
	ev['float'] = vn.Utils.MarkUp(ev['float'])
	var loc = _has_or_default(ev,'loc', Vector2(600,300))
	var in_t = _has_or_default(ev, 'fadein', 1)
	var f = load(float_text).instance()
	if ev.has('font') and ev['font'] != "" and ev['font'] != "default":
		f.set_font(vn.ROOT_DIR + ev['font'])
	if ev.has('dir'):
		var speed = _has_or_default(ev,'speed', 30)
		f.set_movement(ev['dir'], speed)
	self.add_child(f)
	if ev.has('time') and ev['time'] > wt:
		f.display(ev['float'], ev['time'], in_t, loc)
	else:
		f.display(ev['float'], wt, in_t, loc)
	
	var has_voice = _check_latest_voice(ev)
	if ev.has('hist') and (_parse_true_false(ev['hist'])):
		_voice_to_hist((has_voice and vn.voice_to_history), _has_or_default(ev,'who',''), ev['float'] )
		
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
			if self.centered:
				dimming(vn.CENTER_DIM)
			else:
				dimming(vn.NVL_DIM)
		else:
			show_boxes()


func hide_boxes():
	hide_all_boxes = true
	get_node('VNUI/dialogBox').visible = false
	get_node('VNUI/nameBox').visible = false
	
func show_boxes():
	if hide_all_boxes:
		get_node('VNUI/dialogBox').visible = true
		get_node('VNUI/nameBox').visible = true
		hide_all_boxes = false
		
func _hide_namebox(uid:String):
	if hide_all_boxes == false:
		get_node('VNUI/nameBox').visible = true
	if vn.Chs.all_chara.has(uid):
		var info = vn.Chs.all_chara[uid]
		if info.has('no_nb') and info['no_nb']:
			get_node('VNUI/nameBox').visible = false
			return true
			
	return false
	
# checks if the dict has something, if so, return the value of the field. Else return the
# given default val
func _has_or_default(ev:Dictionary, fname:String , default):
	if ev.has(fname): 
		return ev[fname]
	else: 
		return default

# Check this event for latest voice... If there is a voice field,
# play the voice and then return true
func _check_latest_voice(ev:Dictionary):
	if ev.has('voice'):
		latest_voice = ev['voice']
		if not vn.skipping:
			voice(ev['voice'], false)
			return true
	else:
		latest_voice = null
	
	return false
	
func _voice_to_hist(has_v:bool, who:String, text:String):
	if has_v:
		vn.Pgs.updateHistory(PoolStringArray([who, text, latest_voice]))
	else: # does not have voice
		vn.Pgs.updateHistory(PoolStringArray([who, text]))

func dimming(c : Color):
	get_node('background').modulate = c
	stage.set_modulate_4_all(c)
	
func call_method(ev:Dictionary, auto_forw = true):
	# rollback and save are not taken care of by default because
	# there is no way to predict what the method will do
	if ev.has('params'):
		callv(ev['call'], ev['params'])
	else:
		callv(ev['call'], [])
	if auto_forw: auto_load_next()


func register_dvar_propagation(method_name:String, dvar_name:String):
	if vn.dvar.has(dvar_name):
		_propagate_dvar_list[method_name] = dvar_name
	else:
		print("The dvar %s cannot be found. Nothing is done." % [dvar_name])

func propagate_dvar_calls(dvar_name:String=''):
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
	
	var k = ev.keys()[0]
	var temp = ev[k].split(" ")
	match temp[0]:
		"auto": # You cannot turn auto on.
			# Simply turns off dialog auto forward.
			if temp[1] == "off":
				QM.reset_auto()
			
		"skip": # same as above
			if temp[1] == "off":
				QM.reset_skip()
				
		"clear": # clears the dialog box
			clear_boxes()
			
		"rollback", "roll_back" ,"RB":
			# Example {system: RB clear} clears all rollback saves
			# {system: RB clear_3} clears last 3 rollback saves
			if temp[1] == "clear":
				vn.Pgs.rollback_records.clear()
			else:
				var splitted = temp[1].split('_')
				if splitted[0]=='clear' and splitted[1].is_valid_integer():
					var n = int(splitted[1])
					for _i in range(n):
						vn.Pgs.rollback_records.pop_back()
		"auto_save", "AS": # make a save, with 0 seconds delay, and save
			# at current index - 1 because at current index, the event is sys:auto_save
			vn.Utils.make_a_save("[Auto Save] ",0,1)
		"make_save", "MS":
			QM.reset_auto_skip()
			vn.Notifs.show("make_save")
			yield(vn.Notifs.get_current_notif(), "clicked")

		# The above are not included in 'all'.
		
		"right_click", "RC":
			if temp[1] == "on":
				self.no_right_click = false
			elif temp[1] == "off":
				self.no_right_click = true
			vn.Pgs.control_state['right_click'] = self.no_right_click
				
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

	if !vn.inLoading:
		auto_load_next()
	
#-------------------- Extra Preprocessing ----------------------
func _parse_loc(loc, ev = {}) -> Vector2:
	if typeof(loc) == TYPE_VECTOR2:
		return loc
	if typeof(loc) == TYPE_STRING and (loc == "R" or loc == "r"):
		var v = get_viewport().size
		return vn.Utils.random_vec(Vector2(100,v.x-100),Vector2(80,v.y-80))
	# If you get error here, that means the string cannot be split
	# as floats with delimiter space.
	var vec = loc.split_floats(" ")
	if vec.size() != 2:
		print("!!! Incorrect loc vector format: " + str(ev))
		push_error("2D vector should have two real numbers separated by a space.")
	return Vector2(vec[0], vec[1])
	
func _parse_dir(dir, ev = {}) -> Vector2:
	if dir in vn.DIRECTION:
		return vn.DIRECTION[dir]
	elif typeof(dir) == TYPE_STRING and (dir == "R" or dir == "r"):
		return vn.Utils.random_vec(Vector2(-1,1), Vector2(-1,1)).normalized()
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
		var color_vec = color.split_floats(" ", false)
		var s = color_vec.size()
		if s == 3 or s == 4:
			if s == 3:
				return Color(color_vec[0], color_vec[1], color_vec[2])
			else:
				return Color(color_vec[0], color_vec[1], color_vec[2], color_vec[3])
		else:
			print("!!! Error color format: " + str(ev))
			push_error("Expecting value of the form float1 float2 float3( float4) after color.")
			return Color()
			
func _parse_nvl(nvl_state):
	if typeof(nvl_state) == TYPE_BOOL:
		return nvl_state
	elif typeof(nvl_state) == TYPE_STRING:
		match nvl_state.to_lower():
			"clear": return nvl_state
			"on", "true":  return true
			"off", "false": return false
			_:
				print("!!! Format error for NVL event.")
				push_error("Expecting either boolean or 'true'/'false','on'/'off' strings.")

func _parse_true_false(truth) -> bool:
	if typeof(truth) == TYPE_BOOL: # 1 = bool
		return truth
	if typeof(truth) == TYPE_STRING:
		if truth.to_lower() == "true":
			return true
		else: # sloppy here.
			return false
	else:
		return false

func _parse_params(p, _ev = {}): # If params has a string which is a dvar,
	# then this will be replaced by the value of a dvar
	var t = typeof(p)
	if t == TYPE_REAL or t == TYPE_INT:
		return p
	if t == TYPE_STRING and vn.dvar.has(p):
		return vn.dvar[p]
	if t == TYPE_ARRAY:
		var temp = p
		for i in range(temp.size()):
			if typeof(temp[i]) == TYPE_STRING and vn.dvar.has(temp[i]):
				temp[i] = vn.dvar[temp[i]]
		return temp


func _dialog_state_reset():
	if nvl:
		nvlBox.nw = false
	else:
		dialogbox.nw = false
		
func _notification(what):
	if what == MainLoop.NOTIFICATION_WM_QUIT_REQUEST:
		vn.Notifs.show("quit")
		QM.reset_auto_skip()

func preprocess(words : String) -> String:
	_dialog_state_reset()
	var leng = words.length()
	var output = ''
	var i = 0
	while i < leng:
		var c = words[i]
		var inner = ""
		if c == '[':
			i += 1
			while words[i] != ']':
				inner += words[i]
				i += 1
				if i >= leng:
					vn.error("Please do not use square brackets " +\
					"unless for bbcode and display dvar purposes.")
					
			match inner:
				"nw":
					if not vn.skipping:
						if self.nvl:
							nvlBox.nw = true
						else:
							dialogbox.nw = true
				"sm": output += ";"
				"dc": output += "::"
				"nl": output += "\n"
				"lb": output += "["
				"rb": output += "]"
				_: 
					if vn.dvar.has(inner):
						output += str(vn.dvar[inner])
					else:
						output += '[' + inner + ']'
						
		else:
			output += c
			
		i += 1
	
	return output
	
func _exit_tree():
	vn.Scene = null
	vn.Files.write_to_config()
