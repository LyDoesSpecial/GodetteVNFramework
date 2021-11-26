tool
extends EditorPlugin

var editor_path = preload("res://addons/VNScriptEditor/scriptEditor.tscn")
var editor_instance

func _enter_tree():
	editor_instance = editor_path.instance()
	get_editor_interface().get_editor_viewport().add_child(editor_instance)
	make_visible(false)


func _exit_tree():
	if editor_instance:
		editor_instance.queue_free()

func has_main_screen():
	return true
	
func get_plugin_name():
	return "VNScript"
	
func get_plugin_icon():
	return get_editor_interface().get_base_control().get_icon("Script", "EditorIcons")

func make_visible(visible):
	if editor_instance:
		editor_instance.visible = visible
