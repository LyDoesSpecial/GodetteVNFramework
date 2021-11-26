extends Sprite


func _ready():
	get_node("AnimationPlayer").play("rotate")

func _on_AnimationPlayer_animation_finished(_anim_name):
	self.queue_free()
