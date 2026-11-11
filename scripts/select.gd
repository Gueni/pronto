extends Control
## Hero select + join screen for same-screen multiplayer.
## Every input device (two keyboard halves, four gamepads) can join as one player.

const CARD_W = 226

var slots = []       # [{device, char, ready}]
var tag_boxes = []
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
	box.add_theme_constant_override("separation", 10)
	center.add_child(box)

	var title = Game.label("CHOOSE YOUR HERO", 32, Color(1.0, 0.92, 0.4), true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	# One card per hero: looks, size, passive and ultimate.
	var stage = Control.new()
	stage.custom_minimum_size = Vector2(CARD_W * Game.CHARACTERS.size(), 452)
	box.add_child(stage)
	for i in Game.CHARACTERS.size():
		var ch = Game.CHARACTERS[i]
		var cx = CARD_W * i + CARD_W / 2
		var panel = ColorRect.new()
		panel.color = Color(0.03, 0.05, 0.18, 0.45)
		panel.position = Vector2(CARD_W * i + 4, 0)
		panel.size = Vector2(CARD_W - 8, 452)
		stage.add_child(panel)
		var s = Game.char_sprite(ch, "idle", 3.2)
		Game.stand(s, Vector2(cx, 112))
		stage.add_child(s)
		sprites.append(s)

		var card = VBoxContainer.new()
		card.position = Vector2(CARD_W * i + 10, 116)
		card.custom_minimum_size = Vector2(CARD_W - 20, 0)
		card.size = Vector2(CARD_W - 20, 0)
		card.add_theme_constant_override("separation", 5)
		stage.add_child(card)
		_line(card, ch.name, 24, ch.color, true)
		_line(card, ch.blurb, 16, Color.WHITE)
		_line(card, "SIZE: %s    HEARTS: %d" % [_size_name(ch.get("size", 1.0)), ch.get("hearts", 3)], 8, Color(0.8, 0.88, 1.0))
		_line(card, "- PASSIVE -", 8, Color(0.5, 1.0, 0.6))
		_line(card, ch.passive, 8, Color.WHITE)
		_line(card, "- SPECIAL MOVE -", 8, Color(0.5, 0.85, 1.0))
		_line(card, ch.move.name, 16, Color(0.5, 0.85, 1.0), true)
		_line(card, ch.move.desc, 8, Color.WHITE)
		_line(card, "- ULTIMATE (FULL MANA) -", 8, Color(1.0, 0.85, 0.3))
		_line(card, ch.ult.name, 16, Color(1.0, 0.85, 0.3), true)
		_line(card, ch.ult.desc, 8, Color.WHITE)
		var tags = VBoxContainer.new()
		tags.custom_minimum_size = Vector2(CARD_W - 20, 0)
		card.add_child(tags)
		tag_boxes.append(tags)

	status = Game.label("", 16, Color(1.0, 0.92, 0.4))
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(status)
	var help = Game.label(
		"LEFT / RIGHT: PICK  -  JUMP: READY  -  ACTION: BACK  -  ESC: TITLE\n\n" +
		"KEYS 1:  A D S MOVE - W JUMP - F SANDAL - LEFT SHIFT MOVE - E ULTIMATE\n" +
		"KEYS 2:  ARROWS - UP JUMP - ENTER SANDAL - RIGHT SHIFT MOVE - RIGHT CTRL ULTIMATE\n" +
		"GAMEPAD:  STICK - (A) JUMP - (X) SANDAL - (B) MOVE - (Y) ULTIMATE",
		8, Color.WHITE)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(help)
	_refresh()


func _line(parent, text, font_size, color, bold = false):
	var l = Game.label(text, font_size, color, bold)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.custom_minimum_size = Vector2(CARD_W - 20, 0)
	parent.add_child(l)
	return l


func _size_name(s):
	if s < 0.9:
		return "SMALL"
	if s < 1.1:
		return "MEDIUM"
	if s < 1.3:
		return "BIG"
	return "HUGE"


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
	Game.new_game(list)
