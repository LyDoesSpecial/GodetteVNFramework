extends CanvasLayer

const notifList = ["quit", "main", "override", 'rollback', 'make_save']


func clear():
	for n in get_node("currentNotif").get_children():
		n.queue_free()

func hide():
	vn.inNotif = false
	clear()
	get_node("backgroundColor").visible = false
	
func show(which : String) -> void:
	clear()
	vn.inNotif = true
	get_node("backgroundColor").visible = true
	if which in notifList:
		var n = vn.Pre.NOTIF_BOX.instance()
		n.set_text(which)
		get_node("currentNotif").add_child(n)

func get_current_notif():
	return get_node("currentNotif").get_child(0)
