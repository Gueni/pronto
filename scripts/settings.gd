extends Control
## The settings screen: an overlay opened from the title screen or the pause menu
## (Game.open_settings). Up / down to pick a line, left / right to change it.
## Everything is applied at once and saved with the rest of the save file.

signal closed

const ROWS = [
	{"key": "mode", "name": "DISPLAY", "values": ["FULLSCREEN", "WINDOW"]},
	{"key": "res", "name": "WINDOW SIZE", "values": []},     # filled from Game.RESOLUTIONS
	{"key": "zoom", "name": "CAMERA", "values": ["FAR", "NORMAL", "CLOSE"]},
	{"key": "vsync", "name": "VSYNC", "values": ["OFF", "ON"]},
	{"key": "music", "name": "MUSIC", "values": 10},
	{"key": "sfx", "name": "SOUND", "values": 10},
	{"key": "shake", "name": "SCREEN SHAKE", "values": ["OFF", "ON"]},
	{"key": "minimap", "name": "MINIMAP", "values": ["OFF", "ON"]},
]

var index = 0
var grace = 0.25
var t = 0.0


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 100
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _values(row):
	if row.key == "res":
		var out = []
		for r in Game.RESOLUTIONS:
			out.append("%d x %d" % [r.x, r.y])
		return out
	return row.values


func _process(delta):
	t += delta
	queue_redraw()
	if grace > 0:
		grace -= delta
		return
	var count = ROWS.size() + 1
	if Input.is_action_just_pressed("m_down"):
		index = (index + 1) % count
		Game.sfx("tap")
	elif Input.is_action_just_pressed("m_up"):
		index = (index - 1 + count) % count
		Game.sfx("tap")
	var step = 0
	if Input.is_action_just_pressed("m_right"):
		step = 1
	elif Input.is_action_just_pressed("m_left"):
		step = -1
	if index == ROWS.size():
		if Input.is_action_just_pressed("m_ok"):
			_close()
	elif step != 0 or Input.is_action_just_pressed("m_ok"):
		if step == 0:
			step = 1
		var row = ROWS[index]
		var values = _values(row)
		var cur = int(Game.settings[row.key])
		if values is Array:
			cur = (cur + step + values.size()) % values.size()
		else:
			cur = clamp(cur + step, 0, values)
		Game.settings[row.key] = cur
		Game.apply_settings()
		Game.sfx("tap", 1.3)
	if Input.is_action_just_pressed("m_back"):
		_close()


func _close():
	Game.save_game()
	Game.sfx("tap", 0.7)
	closed.emit()
	queue_free()


func _text(pos, text, font_size, color, width = -1.0, bold = false, align = HORIZONTAL_ALIGNMENT_LEFT):
	draw_string(Game.FONT_BOLD if bold else Game.FONT, pos, text, align, width, font_size, color)


func _draw():
	var w = size.x
	var h = size.y
	draw_rect(Rect2(0, 0, w, h), Color(0.02, 0.02, 0.06, 0.88))
	var pw = min(760.0, w - 80.0)
	var x = (w - pw) * 0.5
	var y = h * 0.5 - 250
	draw_rect(Rect2(x, y, pw, 500), Color(0.08, 0.09, 0.16, 0.96))
	draw_rect(Rect2(x, y, pw, 500), Color(1.0, 0.82, 0.3), false, 3.0)
	_text(Vector2(x, y + 52), "SETTINGS", 32, Color(1.0, 0.82, 0.3), pw, true, HORIZONTAL_ALIGNMENT_CENTER)
	var ry = y + 108
	for i in ROWS.size() + 1:
		var sel = i == index
		if sel:
			draw_rect(Rect2(x + 16, ry - 26, pw - 32, 36), Color(1.0, 0.82, 0.3, 0.16))
			draw_rect(Rect2(x + 16, ry - 26, 5, 36), Color(1.0, 0.82, 0.3))
		var col = Color.WHITE if sel else Color(0.7, 0.72, 0.8)
		if i == ROWS.size():
			_text(Vector2(x, ry), "BACK", 16, col, pw, false, HORIZONTAL_ALIGNMENT_CENTER)
			break
		var row = ROWS[i]
		var values = _values(row)
		var cur = int(Game.settings[row.key])
		_text(Vector2(x + 40, ry), row.name, 16, col)
		if values is Array:
			var dim = row.key == "res" and Game.settings.mode == 0
			_text(Vector2(x + pw * 0.5, ry), ("<  %s  >" if sel else "%s") % values[cur], 16,
					Color(0.5, 0.5, 0.55) if dim else Color(1.0, 0.9, 0.5) if sel else col, pw * 0.5 - 40, false, HORIZONTAL_ALIGNMENT_CENTER)
		else:
			var bx = x + pw * 0.5 + 30
			for k in values:
				draw_rect(Rect2(bx + k * 26, ry - 16, 20, 16), Color(1.0, 0.82, 0.3) if k < cur else Color(0.2, 0.22, 0.32))
		ry += 44
	_text(Vector2(x, y + 478), "UP / DOWN: CHOOSE      LEFT / RIGHT: CHANGE      ESC: BACK", 8, Color(0.6, 0.62, 0.72), pw, false, HORIZONTAL_ALIGNMENT_CENTER)
