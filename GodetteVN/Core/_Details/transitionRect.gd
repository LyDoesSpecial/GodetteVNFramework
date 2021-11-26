extends ColorRect

func pixelate_in(t:float):
	var transition_player = get_node("AnimationPlayer")
	self.material = load("res://GodetteVN/Shaders/pixelate.tres")
	var animation = Animation.new()
	var track_index = animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track_index, ":material:shader_param/time")
	animation.set_length(t)
	animation.track_insert_key(track_index, 0, 0.0)
	animation.track_insert_key(track_index, t, 1.562)
	transition_player.add_animation("pixel_in", animation)
	transition_player.play("pixel_in")
	
func pixelate_out(t:float):
	var transition_player = get_node("AnimationPlayer")
	self.material = load("res://GodetteVN/Shaders/pixelate.tres")
	var animation = Animation.new()
	var track_index = animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track_index, ":material:shader_param/time")
	animation.set_length(t)
	animation.track_insert_key(track_index, 0, 1.562)
	animation.track_insert_key(track_index, t, 0)
	transition_player.add_animation("pixel_out", animation)
	transition_player.play("pixel_out")
	

func _on_AnimationPlayer_animation_finished(anim_name):
	
	if anim_name == "pixel_in":
		get_parent().emit_signal('transition_mid_point_reached')
		self.queue_free()
		
	if anim_name == "self_destruct":
		get_parent().emit_signal('transition_finished')
		call_deferred('free')
	else:
		var c = self.color
		var animation = Animation.new()
		var transition_player = get_node("AnimationPlayer")
		var track_index = animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(track_index, ":color")
		animation.set_length(0.05)
		animation.track_insert_key(track_index, 0, c)
		animation.track_insert_key(track_index, 0.05, Color(0,0,0,0))
		transition_player.add_animation("self_destruct", animation)
		transition_player.play("self_destruct")
