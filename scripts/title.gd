extends Control
## Title screen: a dark, slowly drifting skyline with embers in the air, the logo on the
## left and a short menu under it.

const Scenery = preload("res://scripts/scenery.gd")

var items = []          # the menu; CONTINUE RUN comes first when a run is saved
var picking = false     # choosing how spicy the new run is
var mode_i = 1

var index = 0
var t = 0.0
var grace = 0.35
var locked = false     # the settings overlay is open
var layers = []
var hero


func _ready():
	Game.hud.visible = false
	mode_i = Game.difficulty
	items = ["NEW RUN", "THE CAMP", "SETTINGS", "QUIT"]
	if Game.saved_run != null:
		items.insert(0, "CONTINUE RUN")
	Music.play_track("title")
	var sky = Game.sky(Color(0.05, 0.04, 0.12), Color(0.55, 0.2, 0.22))
	add_child(sky)
	sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sky.show_behind_parent = true
	var vs = get_viewport_rect().size
	# three strips of silhouettes drifting at different speeds
	for spec in [["hills", Color(0.25, 0.1, 0.2), 6.0, 0.62, 1.6], ["medina", Color(0.13, 0.07, 0.15), 14.0, 0.8, 2.0], ["hills_low", Color(0.05, 0.03, 0.08), 30.0, 1.0, 2.4]]:
		var l = Scenery.Layer.new()
		l.style = spec[0]
		l.color = spec[1]
		l.span = 6000.0
		l.layer_seed = 5 + layers.size() * 7
		l.scale = Vector2(spec[4], spec[4])
		l.position.y = vs.y * spec[3]
		l.show_behind_parent = true
		add_child(l)
		layers.append([l, spec[2]])
	# embers
	var p = CPUParticles2D.new()
	p.amount = 60
	p.lifetime = 6.0
	p.preprocess = 6.0
	p.direction = Vector2(0.3, -1)
	p.spread = 30.0
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 60.0
	p.gravity = Vector2(6, -14)
	p.color = Color(1.0, 0.55, 0.2, 0.9)
	p.scale_amount_min = 1.5
	p.scale_amount_max = 4.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(vs.x * 0.6, 20)
	p.position = Vector2(vs.x * 0.5, vs.y + 10)
	p.show_behind_parent = true
	add_child(p)
	# one of the gang on the cliff, a different one every time
	hero = Game.char_sprite(Game.CHARACTERS[randi() % Game.CHARACTERS.size()], "idle", 9.0)
	hero.flip_h = true
	Game.stand(hero, Vector2(vs.x * 0.78, vs.y * 0.86))
	add_child(hero)


func _process(delta):
	t += delta
	queue_redraw()
	for l in layers:
		l[0].position.x = -fmod(t * l[1], 2000.0) - 200.0
	if locked or Game.busy:
		return
	if grace > 0:
		grace -= delta
		return
	if picking:
		_pick_mode()
		return
	if Input.is_action_just_pressed("m_down"):
		index = (index + 1) % items.size()
		Game.sfx("tap")
	elif Input.is_action_just_pressed("m_up"):
		index = (index - 1 + items.size()) % items.size()
		Game.sfx("tap")
	elif Input.is_action_just_pressed("m_back"):
		index = items.size() - 1   # circle: down to QUIT
		Game.sfx("tap", 0.7)
	elif Input.is_action_just_pressed("m_ok"):
		Game.sfx("tap", 1.3)
		match items[index]:
			"CONTINUE RUN":
				Game.continue_run()
			"NEW RUN":
				picking = true
				grace = 0.15
			"THE CAMP":
				Game.goto_scene(Game.CAMP_SCENE)
			"SETTINGS":
				locked = true
				var s = Game.open_settings(self)
				s.closed.connect(func():
					locked = false
					grace = 0.2)
			"QUIT":
				get_tree().quit()


## HOW SPICY? Up / down, OK to start choosing heroes, back to return to the menu.
func _pick_mode():
	var n = Game.MODES.size()
	if Input.is_action_just_pressed("m_down"):
		mode_i = (mode_i + 1) % n
		Game.sfx("tap")
	elif Input.is_action_just_pressed("m_up"):
		mode_i = (mode_i - 1 + n) % n
		Game.sfx("tap")
	elif Input.is_action_just_pressed("m_back"):
		picking = false
		grace = 0.15
		Game.sfx("tap", 0.7)
	elif Input.is_action_just_pressed("m_ok"):
		Game.sfx("power_up", 1.2, -4.0)
		Game.difficulty = mode_i
		Game.save_game()
		Game.goto_scene(Game.SELECT_SCENE)


func _draw():
	var w = size.x
	var h = size.y
	# ground under the hero, and a dark fade on the left so the menu reads well
	draw_rect(Rect2(0, h * 0.86, w, h * 0.14), Color(0.03, 0.02, 0.05))
	for i in 12:
		draw_rect(Rect2(0, 0, w * 0.55 * (1.0 - i / 12.0), h), Color(0.02, 0.01, 0.05, 0.07))
	var x = w * 0.07
	# logo: a pan of chakchouka, the name, a red slash under it
	var ly = h * 0.26
	var pan = Vector2(x + 44, ly - 96)
	draw_circle(pan, 40, Color(0.1, 0.08, 0.1))
	draw_circle(pan, 33, Color(0.85, 0.22, 0.12))
	draw_rect(Rect2(pan.x + 36, pan.y - 5, 54, 10), Color(0.1, 0.08, 0.1))
	for e in [Vector2(-12, -6), Vector2(11, 8), Vector2(6, -14)]:
		draw_circle(pan + e, 10, Color(1, 1, 1))
		draw_circle(pan + e, 4.5, Color(1.0, 0.8, 0.2))
	for i in 3:
		var k = fmod(t * 0.4 + i / 3.0, 1.0)
		draw_circle(pan + Vector2(-16 + i * 16 + sin(k * 6.0 + i) * 5.0, -40 - k * 50.0), 5.0 + k * 6.0, Color(1, 1, 1, 0.22 * (1.0 - k)))
	var font = Game.FONT_BOLD
	draw_string(font, Vector2(x + 5, ly + 5), Game.TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, 80, Color(0, 0, 0, 0.7))
	draw_string(font, Vector2(x, ly), Game.TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, 80, Color(1.0, 0.86, 0.35))
	var lw = font.get_string_size(Game.TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, 80).x
	draw_rect(Rect2(x, ly + 14, lw, 6), Color(0.9, 0.22, 0.15))
	draw_string(Game.FONT, Vector2(x, ly + 48), "A SPICY ROGUELIKE FOR 1 TO 4 FRIENDS", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.95, 0.8, 0.75))

	var y = h * 0.5
	if picking:
		draw_string(Game.FONT, Vector2(x, y - 50), "HOW SPICY DO YOU WANT IT?", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1.0, 0.86, 0.35))
		var colors = [Color(0.45, 0.85, 0.5), Color(1.0, 0.6, 0.2), Color(0.95, 0.2, 0.2)]
		for i in Game.MODES.size():
			var m = Game.MODES[i]
			var sel = i == mode_i
			if sel:
				var bw = 470.0 + sin(t * 5.0) * 6.0
				draw_rect(Rect2(x - 14, y - 30, bw, 58), Color(colors[i].r, colors[i].g, colors[i].b, 0.8))
				draw_rect(Rect2(x - 14, y - 30, 6, 58), Color(1.0, 0.86, 0.35))
			# chili peppers: one, two, three
			for c in i + 1:
				var cp = Vector2(x + (14 if sel else 0) + c * 20.0, y - 10)
				draw_colored_polygon(PackedVector2Array([cp + Vector2(0, -7), cp + Vector2(8, -5), cp + Vector2(13, 8), cp + Vector2(5, 3)]), Color(0.95, 0.15, 0.12) if not sel else Color.WHITE)
				draw_line(cp + Vector2(2, -6), cp + Vector2(-2, -11), Color(0.3, 0.8, 0.35), 2.0)
			var tx = x + (14 if sel else 0) + 74
			draw_string(font if sel else Game.FONT, Vector2(tx, y), m.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE if sel else Color(0.75, 0.7, 0.8))
			draw_string(Game.FONT, Vector2(tx, y + 18), m.tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 1, 1, 0.95) if sel else Color(0.6, 0.6, 0.7))
			y += 70.0
		draw_multiline_string(Game.FONT, Vector2(x, y + 4), Game.MODES[mode_i].desc, HORIZONTAL_ALIGNMENT_LEFT, w * 0.4, 8, 3, Color(0.95, 0.9, 0.85))
		if Game.saved_run != null:
			draw_string(Game.FONT, Vector2(x, y + 44), "A NEW RUN REPLACES THE SAVED ONE.", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1.0, 0.5, 0.45))
		draw_string(Game.FONT, Vector2(x, y + 66), "ENTER / (A): CHOOSE HEROES        ESC / CIRCLE: BACK", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.6, 0.6, 0.7))
	else:
		for i in items.size():
			var sel = i == index
			if sel:
				var bw = 360.0 + sin(t * 5.0) * 6.0
				draw_rect(Rect2(x - 14, y - 30, bw, 42), Color(0.9, 0.22, 0.15, 0.85))
				draw_rect(Rect2(x - 14, y - 30, 6, 42), Color(1.0, 0.86, 0.35))
			draw_string(font if sel else Game.FONT, Vector2(x + (14 if sel else 0), y), items[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 24,
					Color.WHITE if sel else Color(0.75, 0.7, 0.8))
			y += 52.0
		if items[index] == "CONTINUE RUN":
			draw_string(Game.FONT, Vector2(x, y + 2), Game.run_summary(), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1.0, 0.86, 0.35))

	Game.draw_dan(self, Vector2(x + 8, h - 70), 18.0, Color(0.6, 0.95, 1.0))
	draw_string(Game.FONT, Vector2(x + 28, h - 62), "BARAKA %d      BEST DEPTH %d      WINS %d" % [Game.dinars, Game.best_depth, Game.wins],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.8, 0.85, 0.95))
	draw_string(Game.FONT, Vector2(x, h - 34), "UP / DOWN + ENTER  OR  GAMEPAD        M: MUTE        F11: WINDOW / FULLSCREEN",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.6, 0.6, 0.7))
