extends TextureButton

var path : String

func _on_voiceButton_pressed():
	if path != "":
		music.play_voice(vn.VOICE_DIR + path)
