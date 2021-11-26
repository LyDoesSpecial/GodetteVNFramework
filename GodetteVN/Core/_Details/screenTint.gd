extends ColorRect

func set_tint(c: Color, t: float):
	var tint_player = get_node("AnimationPlayer")
	var animation = Animation.new()
	var track_index = animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track_index, ":color")
	animation.set_length(t)
	animation.track_insert_key(track_index, 0, Color(0,0,0,0))
	animation.track_insert_key(track_index, t, c)
	tint_player.add_animation("tint", animation)
	tint_player.play("tint")
	
func set_tintwave(c:Color, t: float):
	var tint_player = get_node("AnimationPlayer")
	var animation = Animation.new()
	var track_index = animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track_index, ":color")
	animation.set_length(t)
	animation.set_loop(true)
	animation.track_insert_key(track_index, 0, Color(0,0,0,0))
	animation.track_insert_key(track_index, t/4, c)
	animation.track_insert_key(track_index, 3*t/4, c)
	animation.track_insert_key(track_index, t, Color(0,0,0,0))
	tint_player.add_animation("tintWave", animation)
	tint_player.play("tintWave")
