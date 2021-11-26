extends Node

#-------------Game Control State---------------------------
var control_state = {
	'right_click': true,
	'quick_menu':true,
	'boxes': true,
	'scroll':true
}
#----------------------------------------------------------
# 
var currentNodePath = null

# Current time line 
var currentBlock = null

# Current index in the block
var currentIndex = null

# Current save description, if there is one
var currentSaveDesc = ""

# Playback/lasting events are defined as events that should be remembered when loading
# back from a save. Example: weather effects. If it's raining and player saves, then when
# loading back, the player should see the rain too.

# If player saves in the middle of nvl mode,
# then when loading back, we need to restore all the nvl text.
var nvl_text = ''

var playback_events = {'bg':'', 'bgm':{'bgm':''}, 'charas':[], 'nvl': '','speech':'', 'control_state': control_state}

func get_latest_onstage():
	playback_events['charas'] = stage.all_on_stage()

func get_latest_nvl():
	playback_events['nvl'] = nvl_text


#-------------------------------------------------------------------------------
# "new_game" = start from new
# "load_game" = start from given dialog block and index.
var load_instruction = "new_game"
#-------------------------------------------------------------------------------

#------------------------------------------------------
# List of history entries
var history = []


#-------------Rollback Helper---------------------------
# List of rollback records
var rollback_records = []

#------------------------------------------------------
# Utility functions

# hist_data is an array [uid, text, voice(optional)]
func updateHistory(hist_data:PoolStringArray):
	if (history.size() > vn.max_history_size):
		history.remove(0)
		
	hist_data[1] = hist_data[1].strip_edges()
	history.push_back(hist_data)
	
func updateRollback():
	get_latest_nvl() # get current nvl text.
	get_latest_onstage() # get current on stage characters.
	if rollback_records.size() > vn.max_rollback_steps:
		rollback_records.remove(0)
	
	var cur_playback = playback_events.duplicate(true)
	var rollback_data = {'currentBlock': currentBlock, 'currentIndex': currentIndex, \
	'currentSaveDesc': currentSaveDesc, 'playback': cur_playback, 'dvar':vn.dvar.duplicate(),
	'name_patches':vn.Chs.chara_name_patch.duplicate()}
	rollback_records.push_back(rollback_data)
	

func checkSkippable()->bool:
	if vn.Files.system_data.has(currentNodePath):
		#print("Current index is %s" %game.currentIndex)
		#print("Max index is %s" %fileRelated.system_data[game.currentNodePath][game.currentBlock])
		if currentIndex > vn.Files.system_data[currentNodePath][currentBlock]:
			return false
		else:
			return true
	else:
		return true

func makeSnapshot():
	updateRollback()
	if checkSkippable() == false:
		vn.Filles.system_data[currentNodePath][currentBlock] = currentIndex

func resetControlStates(to:bool=true):
	# By default, resets everything back to true
	for k in control_state.keys():
		control_state[k] = to

# Suppose player A returns to main without saving, then the state of playback events should be
# refreshed.
func resetPlayback():
	resetControlStates()
	rollback_records = []
	playback_events = {'bg':'', 'bgm':{'bgm':''}, 'charas':[], 'nvl': '','speech':'', 'control_state': control_state}
