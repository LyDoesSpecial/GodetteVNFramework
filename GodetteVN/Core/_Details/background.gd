extends TextureRect

func bg_change(path: String):
	if path == '':
		texture = null
	else:
		texture = load(vn.BG_DIR + path)
