tool
extends TabContainer

func _on_documentation_resized():
	get_current_tab_control().get_node('doc').rect_size.x = self.rect_size.x

func _on_documentation_tab_selected(tab):
	var prev_tab:Control = get_tab_control(get_previous_tab())
	var cur_tab:Control = get_tab_control(tab)
	cur_tab.get_node('doc').rect_size.x = prev_tab.get_node('doc').rect_size.x

func _on_FileDialog_file_selected(path):
	get_current_tab_control().get_node('doc').texture = load(path)

func _on_bgPreview_pressed():
	get_current_tab_control().get_node("FileDialog").popup_centered()
