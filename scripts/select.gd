extends Control
## Hero select + join screen for same-screen multiplayer.
## Every input device (two keyboard halves, four gamepads) can join as one player.

const CARD_W = 220

var slots = []       # [{device, char, ready}]
var tag_boxes = []
var quotes = []
var sprites = []
var status: Label
var starting = false
var grace = 0.3


func _ready():
	Game.hud.visible = false
	var sky = Game.sky(Color(0.12, 0.16, 0.4), Color(0.35, 0.6, 0.95))
	add_child(sky)
	sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center = CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 22)
	center.add_child(box)

	var title = Game.label("CHOOSE YOUR HERO", 48, Color(1.0, 0.92, 0.4), true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var stage = Control.new()
	stage.custom_minimum_size = Vector2(CARD_W * Game.CHARACTERS.size(), 330)
	box.add_child(stage)
	for i in Game.CHARACTERS.size():
		var ch = Game.CHARACTERS[i]
		var cx = CARD_W * i + CARD_W / 2
		var s = Game.char_sprite(ch, "idle", 5.0)
		s.position = Vector2(cx, 70)
		stage.add_child(s)
		sprites.append(s)
		_text(stage, ch.name, 24, ch.color, cx, 160, true)
		_text(stage, ch.blurb, 16, Color.WHITE, cx, 196)
		quotes.append(_text(stage, "\"%s\"" % ch.quote, 16, Color(0.8, 0.88, 1.0), cx, 224))
		var tags = VBoxContainer.new()
		tags.position = Vector2(cx - CARD_W / 2, 258)
		tags.custom_minimum_size = Vector2(CARD_W, 0)
		stage.add_child(tags)
		tag_boxes.append(tags)

	status = Game.label("", 16, Color(1.0, 0.92, 0.4))
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(status)
	var help = Game.label(
		"LEFT / RIGHT: PICK  -  JUMP: READY  -  ACTION: BACK  -  ESC: TITLE\n\n" +
		"KEYS 1:   A  D  MOVE  +  W / SPACE  JUMP  +  F  ACTION\n" +
		"KEYS 2:   ARROWS  MOVE  +  UP  JUMP  +  ENTER  ACTION\n" +
		"GAMEPAD:   STICK  MOVE  +  (A)  JUMP  +  (X)  ACTION",
		16, Color.WHITE)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(help)
	_refresh()


func _text(parent, text, font_size, color, cx, y, bold = false):
	var l = Game.label(text, font_size, color, bold)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(CARD_W, font_size + 4)
	l.position = Vector2(cx - CARD_W / 2, y)
	parent.add_child(l)
	return l


func _find(device):
	for s in slots:
		if s.device == device:
			return s
	return null


func _process(delta):
	if starting or Game.busy:
		return
	if grace > 0:
		grace -= delta
		return
	if Input.is_action_just_pressed("m_back"):
		Game.goto_scene(Game.TITLE_SCENE)
		return
	var changed = false
	for device in Game.DEVICES:
		var s = _find(device)
		if Input.is_action_just_pressed(device + "_jump"):
			if s == null:
				if slots.size() < Game.MAX_PLAYERS:
					slots.append({"device": device, "char": _free_char(), "ready": false})
					Game.sfx("coin")
					changed = true
			elif not s.ready:
				s.ready = true
				Game.sfx("power_up", 1.4, -4.0)
				sprites[s.char].play("jump")
				changed = true
		elif s != null:
			if Input.is_action_just_pressed(device + "_action"):
				if s.ready:
					s.ready = false
				else:
					slots.erase(s)
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
					if Game.CHARACTERS[s.char].get("laugh", false):
						Game.laugh()
					changed = true
	if changed:
		_refresh()
		if not slots.is_empty() and slots.all(func(s): return s.ready):
			_start()


func _free_char():
	for i in Game.CHARACTERS.size():
		if not slots.any(func(s): return s.char == i):
			return i
	return 0


func _refresh():
	for box in tag_boxes:
		for c in box.get_children():
			c.queue_free()
	for i in sprites.size():
		if not slots.any(func(s): return s.char == i and s.ready):
			sprites[i].play("run" if slots.any(func(s): return s.char == i) else "idle")
	for i in slots.size():
		var s = slots[i]
		var text = "P%d %s" % [i + 1, "READY!" if s.ready else "< >"]
		var l = Game.label(text, 16, Game.PLAYER_COLORS[i])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag_boxes[s.char].add_child(l)
	if slots.is_empty():
		status.text = "PRESS JUMP TO JOIN!"
	else:
		var waiting = slots.filter(func(s): return not s.ready).size()
		status.text = "%d PLAYER%s IN  -  %s" % [slots.size(), "" if slots.size() == 1 else "S",
				"PRESS JUMP WHEN READY" if waiting > 0 else "LET'S GO! PRONTO!"]


func _start():
	starting = true
	var list = []
	for s in slots:
		list.append({"char": s.char, "input": s.device})
	if list.size() == 1 and not list[0].input.begins_with("pad"):
		list[0].input = "solo"   # alone on the keyboard: every key works
	await get_tree().create_timer(0.6).timeout
	Game.new_game(list, Game.pending_start_level)
