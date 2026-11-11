extends Control
## The camp: spend dinars (earned by every run, win or lose) on upgrades you keep forever.

const Menu = preload("res://scripts/menu.gd")

var menu
var items = []
var dinars_l: Label
var desc_l: Label
var message = ""
var message_time = 0.0


func _ready():
	Game.hud.visible = false
	Music.play_track("camp")
	var sky = Game.sky(Color(0.04, 0.05, 0.16), Color(0.45, 0.25, 0.3))
	add_child(sky)
	sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var fire = Fire.new()
	add_child(fire)
	fire.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var vs = get_viewport_rect().size
	for i in Game.CHARACTERS.size():
		var s = Game.char_sprite(Game.CHARACTERS[i], "idle", 3.0)
		s.flip_h = i >= 3
		Game.stand(s, Vector2(vs.x * 0.5 + [-250, -170, -100, 110, 200][i], vs.y - 70))
		add_child(s)

	var center = CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_bottom = -150
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	center.add_child(box)
	var title = Game.label("THE CAMP", 32, Color(1.0, 0.85, 0.35), true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	dinars_l = Game.label("", 24, Color(0.6, 0.95, 1.0))
	dinars_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(dinars_l)
	menu = Menu.new()
	box.add_child(menu)
	menu.chosen.connect(_on_chosen)
	desc_l = Game.label("", 16, Color.WHITE)
	desc_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_l.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_l.custom_minimum_size = Vector2(760, 48)
	box.add_child(desc_l)
	_build(0)


func _build(keep):
	items = Game.META.duplicate()
	var texts = []
	for it in items:
		var level = Game.meta_level(it.id)
		if level >= it.max:
			texts.append("%s   %d/%d   MAXED" % [it.name, level, it.max])
		else:
			texts.append("%s   %d/%d   %d D" % [it.name, level, it.max, it.cost * (level + 1)])
	texts.append("START A RUN")
	texts.append("BACK TO TITLE")
	menu.setup(texts, 16)
	menu.index = keep
	menu._refresh()


func _on_chosen(i):
	if Game.busy:
		return
	if i == items.size():
		Game.goto_scene(Game.SELECT_SCENE)
	elif i > items.size():
		Game.goto_scene(Game.TITLE_SCENE)
	elif Game.meta_level(items[i].id) >= items[i].max:
		_say("ALREADY MAXED.")
	elif Game.buy_meta(items[i]):
		Game.sfx("power_up")
		_say("%s UPGRADED!" % items[i].name)
		_build(i)
	else:
		Game.sfx("tap", 0.5)
		_say("NOT ENOUGH DINARS. GO DIE A LITTLE FURTHER.")


func _say(text):
	message = text
	message_time = 2.5


func _process(delta):
	dinars_l.text = "DINARS  %d        BEST DEPTH  %d        WINS  %d" % [Game.dinars, Game.best_depth, Game.wins]
	message_time -= delta
	if message_time > 0:
		desc_l.text = message
	elif menu.index < items.size():
		desc_l.text = items[menu.index].desc
	else:
		desc_l.text = "DINARS ARE PAID AT THE END OF EVERY RUN: THE DEEPER YOU GET, THE MORE YOU EARN."
	if not Game.busy and Input.is_action_just_pressed("m_back"):
		Game.goto_scene(Game.TITLE_SCENE)


## Ground, tents and a flickering campfire.
class Fire extends Control:
	var t = 0.0

	func _ready():
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta):
		t += delta
		queue_redraw()

	func _draw():
		var w = size.x
		var h = size.y
		draw_rect(Rect2(0, h - 70, w, 70), Color(0.2, 0.14, 0.12))
		for x in [w * 0.12, w * 0.86]:
			draw_colored_polygon(PackedVector2Array([Vector2(x - 90, h - 70), Vector2(x, h - 190), Vector2(x + 90, h - 70)]), Color(0.75, 0.7, 0.6))
			draw_colored_polygon(PackedVector2Array([Vector2(x - 18, h - 70), Vector2(x, h - 130), Vector2(x + 18, h - 70)]), Color(0.15, 0.1, 0.1))
		var c = Vector2(w * 0.5, h - 74)
		draw_circle(c + Vector2(0, -20), 120 + sin(t * 9.0) * 8.0, Color(1.0, 0.6, 0.2, 0.10))
		draw_line(c + Vector2(-34, 4), c + Vector2(34, -6), Color(0.3, 0.18, 0.1), 9.0)
		draw_line(c + Vector2(-34, -6), c + Vector2(34, 4), Color(0.25, 0.15, 0.08), 9.0)
		for i in 5:
			var fx = (i - 2) * 11.0
			var fh = 38.0 + sin(t * (9.0 + i * 2.3) + i) * 14.0
			draw_colored_polygon(PackedVector2Array([c + Vector2(fx - 11, 0), c + Vector2(fx + sin(t * 7.0 + i) * 4.0, -fh), c + Vector2(fx + 11, 0)]),
					Color(1.0, 0.55 + 0.08 * i, 0.15, 0.9))
