extends Control
## Hero select. Up to four players, one panel each: press JUMP on your device (keyboard
## half or gamepad) to take a panel, LEFT / RIGHT to flip through the heroes, JUMP again
## when you are ready. The run starts when everyone who joined is ready.

const DEVICE_NAMES = {
	"kl": "KEYS  A D W", "kr": "ARROW KEYS", "pad0": "GAMEPAD 1", "pad1": "GAMEPAD 2", "pad2": "GAMEPAD 3", "pad3": "GAMEPAD 4",
}

var slots = []       # [{device, char, ready}]
var puppets = []     # one per panel
var starting = false
var grace = 0.3
var t = 0.0


func _ready():
	Game.hud.visible = false
	Music.play_track("map")
	var sky = Game.sky(Color(0.05, 0.05, 0.14), Color(0.2, 0.14, 0.32))
	add_child(sky)
	sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sky.show_behind_parent = true
	for i in Game.MAX_PLAYERS:
		var p = Game.puppet("pronto", 3.6)
		p.visible = false
		add_child(p)
		puppets.append(p)


func _find(device):
	for s in slots:
		if s.device == device:
			return s
	return null


func _free_char():
	for i in Game.CHARACTERS.size():
		if not slots.any(func(s): return s.char == i):
			return i
	return 0


func _process(delta):
	t += delta
	queue_redraw()
	_place()
	if starting or Game.busy:
		return
	if grace > 0:
		grace -= delta
		return
	var changed = false
	var left = false   # somebody used their back button to leave a panel
	for device in Game.DEVICES:
		var s = _find(device)
		if Input.is_action_just_pressed(device + "_jump"):
			if s == null:
				if slots.size() < Game.MAX_PLAYERS:
					slots.append({"device": device, "char": _free_char(), "ready": false})
					Game.sfx("coin")
					Music.play_track("hero%d" % slots[-1].char)
					changed = true
			elif not s.ready:
				s.ready = true
				Game.sfx("power_up", 1.4, -4.0)
				changed = true
		elif s != null:
			if Input.is_action_just_pressed(device + "_action") or Input.is_action_just_pressed(device + "_dash"):
				if s.ready:
					s.ready = false
				else:
					slots.erase(s)
				left = true
				Game.sfx("tap", 0.7)
				changed = true
			elif not s.ready:
				var move = 0
				if Input.is_action_just_pressed(device + "_left"):
					move = -1
				elif Input.is_action_just_pressed(device + "_right"):
					move = 1
				if move != 0:
					s.char = (s.char + move + Game.CHARACTERS.size()) % Game.CHARACTERS.size()
					Game.sfx("tap")
					Music.play_track("hero%d" % s.char)   # every hero has a theme
					if Game.CHARACTERS[s.char].get("laugh", false):
						Game.laugh()
					changed = true
	# ESC, or circle when it did not just take somebody out of a panel: back to the title
	if not left and Input.is_action_just_pressed("m_back"):
		Game.goto_scene(Game.TITLE_SCENE)
		return
	if changed and not slots.is_empty() and slots.all(func(s): return s.ready):
		_start()


func _start():
	starting = true
	var list = []
	for s in slots:
		list.append({"char": s.char, "input": s.device})
	if list.size() == 1 and not list[0].input.begins_with("pad"):
		list[0].input = "solo"   # alone on the keyboard: every key works
	await get_tree().create_timer(0.7).timeout
	Game.new_game(list)


func _panel(i):
	var gap = 18.0
	var pw = min(280.0, (size.x - 80.0 - gap * 3) / 4.0)
	var x = (size.x - (pw * 4 + gap * 3)) * 0.5 + i * (pw + gap)
	return Rect2(x, 96, pw, size.y - 96 - 86)


## Keeps each panel's puppet showing the right hero in the right place.
func _place():
	for i in puppets.size():
		var p = puppets[i]
		p.visible = i < slots.size()
		if not p.visible:
			continue
		var s = slots[i]
		var ch = Game.CHARACTERS[s.char]
		var r = _panel(i)
		p.look = ch.look
		var k = 3.6 * ch.get("size", 1.0)
		p.scale = Vector2(k, k)
		p.play("run" if s.ready else "idle")
		Game.stand(p, Vector2(r.position.x + r.size.x * 0.5, r.position.y + 184))


func _text(pos, text, font_size, color, width, bold = false):
	draw_string(Game.FONT_BOLD if bold else Game.FONT, pos, text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, color)


func _bar(x, y, label, value, color, pw):
	draw_string(Game.FONT, Vector2(x, y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.7, 0.72, 0.82))
	var bx = x + 64
	var cell = (pw - 40 - 64) / 5.0
	for k in 5:
		draw_rect(Rect2(bx + k * cell, y - 8, cell - 3, 8), color if k < value else Color(0.16, 0.17, 0.27))


func _draw():
	var w = size.x
	var h = size.y
	_text(Vector2(0, 62), "WHO IS COMING?", 32, Color(1.0, 0.86, 0.35), w, true)
	for i in Game.MAX_PLAYERS:
		var r = _panel(i)
		var pc = Game.PLAYER_COLORS[i]
		var joined = i < slots.size()
		draw_rect(r, Color(0.07, 0.08, 0.16, 0.92))
		draw_rect(Rect2(r.position, Vector2(r.size.x, 5)), pc if joined else Color(0.25, 0.27, 0.38))
		var x = r.position.x
		var y = r.position.y
		var pw = r.size.x
		_text(Vector2(x, y + 28), "PLAYER %d" % (i + 1), 16, pc if joined else Color(0.45, 0.47, 0.58), pw, true)
		if not joined:
			var a = 0.55 + 0.45 * sin(t * 4.0 + i)
			_text(Vector2(x, y + r.size.y * 0.45), "PRESS JUMP", 16, Color(1, 1, 1, a), pw)
			_text(Vector2(x, y + r.size.y * 0.45 + 26), "TO JOIN", 16, Color(1, 1, 1, a), pw)
			_text(Vector2(x, y + r.size.y * 0.45 + 60), "W / UP ARROW / (A)", 8, Color(0.6, 0.62, 0.72), pw)
			continue
		var s = slots[i]
		var ch = Game.CHARACTERS[s.char]
		_text(Vector2(x, y + 44), DEVICE_NAMES.get(s.device, s.device), 8, Color(0.6, 0.62, 0.72), pw)
		# spotlight under the hero
		draw_circle(Vector2(x + pw * 0.5, y + 184), 44, Color(pc.r, pc.g, pc.b, 0.10))
		draw_rect(Rect2(x + pw * 0.5 - 46, y + 184, 92, 3), Color(pc.r, pc.g, pc.b, 0.5))
		if not s.ready:
			var bob = sin(t * 6.0) * 3.0
			_text(Vector2(x + 6 - bob, y + 130), "<", 24, Color.WHITE, 30, true)
			_text(Vector2(x + pw - 36 + bob, y + 130), ">", 24, Color.WHITE, 30, true)
		_text(Vector2(x, y + 218), ch.name, 24, ch.color, pw, true)
		_text(Vector2(x, y + 236), ch.blurb, 8, Color(0.85, 0.87, 0.95), pw)
		var by = y + 262
		_bar(x + 20, by, "SPEED", int(round((ch.get("speed", 1.0) - 0.84) / 0.07)), Color(0.4, 0.8, 1.0), pw)
		_bar(x + 20, by + 14, "JUMP", int(round((ch.get("jump", 1.0) - 0.85) / 0.06)), Color(0.5, 1.0, 0.6), pw)
		_bar(x + 20, by + 28, "HEARTS", ch.get("hearts", 3), Color(1.0, 0.45, 0.45), pw)
		_bar(x + 20, by + 42, "SIZE", int(round(ch.get("size", 1.0) * 3.4 - 0.6)), Color(1.0, 0.8, 0.4), pw)
		var ty = by + 62
		_text(Vector2(x, ty), "SPECIAL MOVE", 8, Color(0.5, 0.85, 1.0), pw)
		_text(Vector2(x, ty + 18), ch.move.name, 16, Color(0.5, 0.85, 1.0), pw, true)
		_text(Vector2(x, ty + 38), "ULTIMATE", 8, Color(1.0, 0.85, 0.3), pw)
		_text(Vector2(x, ty + 56), ch.ult.name, 16, Color(1.0, 0.85, 0.3), pw, true)
		# the story of the move the cursor is not on changes every few seconds
		var which = int(t / 4.0) % 3
		var story = [ch.passive, ch.move.desc, ch.ult.desc][which]
		var head = ["ABOUT", "THE MOVE", "THE ULTIMATE"][which]
		_text(Vector2(x, ty + 74), head, 8, Color(0.6, 0.62, 0.72), pw)
		draw_multiline_string(Game.FONT, Vector2(x + 14, ty + 88), story, HORIZONTAL_ALIGNMENT_CENTER, pw - 28, 8, 3, Color(0.9, 0.9, 0.95))
		if s.ready:
			draw_rect(Rect2(x, y + r.size.y - 44, pw, 44), pc)
			_text(Vector2(x, y + r.size.y - 14), "READY!", 24, Color(0.05, 0.05, 0.12), pw, true)
		else:
			_text(Vector2(x, y + r.size.y - 8), "JUMP: READY     CIRCLE: LEAVE", 8, Color(0.6, 0.62, 0.72), pw)

	var status = "PRESS JUMP TO JOIN"
	if not slots.is_empty():
		var waiting = slots.filter(func(s): return not s.ready).size()
		status = "%d IN  -  %s" % [slots.size(), "WAITING FOR %d" % waiting if waiting > 0 else "LET'S GO!"]
	_text(Vector2(0, h - 62), status, 16, Color(1.0, 0.86, 0.35), w)
	_text(Vector2(0, h - 38), "KEYS 1:  A D MOVE - W JUMP - F SANDAL - LEFT SHIFT MOVE - E ULTIMATE        KEYS 2:  ARROWS - UP JUMP - ENTER SANDAL - RIGHT SHIFT MOVE - RIGHT CTRL ULTIMATE", 8, Color(0.6, 0.62, 0.72), w)
	_text(Vector2(0, h - 22), "GAMEPAD:  STICK - (A) JUMP - (X) SANDAL - (B) MOVE - (Y) ULTIMATE        ESC / CIRCLE (B): BACK", 8, Color(0.6, 0.62, 0.72), w)
