extends ColorRect

func _ready():
	music.play_sound('res://audio/thunder.wav')
	$AnimationPlayer.play('flash')

func _on_AnimationPlayer_animation_finished(_anim_name):
	self.queue_free()
