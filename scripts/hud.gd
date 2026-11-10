extends CanvasLayer
## In-game HUD + pause menu. Created by the Game autoload.

const Menu = preload("res://scripts/menu.gd")

var score_l: Label
var coin_l: Label
var world_l: Label
var time_l: Label
var lives_l: Label
var players_box: HBoxContainer
var banner_l: Label
var boss_box: VBoxContainer
var boss_bar: ProgressBar
var pause_panel: ColorRect
var heart_tex
var rock_tex


func _ready():
	layer = 50
	heart_tex = Game.atlas(Game.FRUITS, Rect2(0, 48, 16, 16))
	rock_tex = Game.ROCK_BIG

	var root = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var top = HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 24
	top.offset_right = -24
	top.offset_top = 12
	score_l = _column(top)
	coin_l = _column(top)
	world_l = _column(top)
	time_l = _column(top)
	lives_l = _column(top)

	players_box = HBoxContainer.new()
	players_box.add_theme_constant_override("separation", 36)
	players_box.position = Vector2(24, 66)
	players_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(players_box)

	banner_l = Game.label("", 32, Color(1.0, 0.92, 0.4), true)
	banner_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(banner_l)
	banner_l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	boss_box = VBoxContainer.new()
	boss_box.visible = false
	root.add_child(boss_box)
	boss_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	boss_box.offset_left = -220
	boss_box.offset_right = 220
	boss_box.offset_top = -70
	boss_box.offset_bottom = -24
	var boss_name = Game.label("KING PINKY", 16, Color(1.0, 0.6, 0.85))
	boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_box.add_child(boss_name)
	boss_bar = ProgressBar.new()
	boss_bar.custom_minimum_size = Vector2(440, 16)
	boss_bar.show_percentage = false
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.05, 0.12)
	bg.set_border_width_all(2)
	bg.border_color = Color(0.05, 0.05, 0.1)
	var fill = StyleBoxFlat.new()
	fill.bg_color = Color(1.0, 0.4, 0.75)
	boss_bar.add_theme_stylebox_override("background", bg)
	boss_bar.add_theme_stylebox_override("fill", fill)
	boss_box.add_child(boss_bar)

	pause_panel = ColorRect.new()
	pause_panel.color = Color(0, 0, 0.05, 0.7)
	pause_panel.visible = false
	root.add_child(pause_panel)
	pause_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center = CenterContainer.new()
	pause_panel.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 40)
	center.add_child(box)
	var title = Game.label("PAUSED", 48, Color(0.35, 0.75, 1.0), true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var menu = Menu.new()
	box.add_child(menu)
	menu.setup(["RESUME", "RESTART LEVEL", "QUIT TO TITLE"])
	menu.chosen.connect(_on_pause_choice)
	var hint = Game.label("M: MUTE     F11: FULLSCREEN", 16, Color(0.7, 0.75, 0.85))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)

	Game.stats_changed.connect(refresh)
	Game.banner.connect(func(text): banner_l.text = text)
	Game.boss_changed.connect(_on_boss)


func _column(parent):
	var l = Game.label("", 16)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _icon(tex, color = Color.WHITE):
	var r = TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.custom_minimum_size = Vector2(24, 24)
	r.modulate = color
	return r


func refresh():
	score_l.text = "SCORE\n%06d" % Game.score
	coin_l.text = "COINS\nx%02d" % Game.coins
	world_l.text = "WORLD\n%s" % Game.level_def().name
	lives_l.text = "LIVES\nx%d" % Game.lives
	for c in players_box.get_children():
		c.queue_free()
	for i in Game.players.size():
		var p = Game.players[i]
		var ch = Game.char_of(i)
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		var title = ch.name if Game.players.size() == 1 else "P%d %s" % [i + 1, ch.name]
		var name_l = Game.label(title + " ", 16, Game.PLAYER_COLORS[i] if Game.players.size() > 1 else ch.color)
		row.add_child(name_l)
		if p.out:
			row.add_child(Game.label("OUT", 16, Color(0.6, 0.6, 0.6)))
		else:
			for h in Game.max_hearts(i):
				row.add_child(_icon(heart_tex, Color.WHITE if h < p.hearts else Color(0.1, 0.1, 0.15, 0.7)))
			if p.rocks:
				row.add_child(_icon(rock_tex))
		players_box.add_child(row)


func _on_boss(hp, max_hp):
	boss_box.visible = max_hp > 0 and hp > 0
	if max_hp > 0:
		boss_bar.max_value = max_hp
		boss_bar.value = hp


func _process(_delta):
	if not visible:
		pause_panel.visible = false
		return
	var t = int(ceil(max(Game.time_left, 0.0)))
	time_l.text = "TIME\n%03d" % t
	time_l.add_theme_color_override("font_color", Color(1.0, 0.4, 0.35) if t <= 30 else Color.WHITE)
	if not Game.busy and Input.is_action_just_pressed("pause"):
		_set_paused(not get_tree().paused)


func _set_paused(value):
	get_tree().paused = value
	pause_panel.visible = value
	Game.sfx("tap")


func _on_pause_choice(i):
	if not pause_panel.visible:
		return
	_set_paused(false)
	if i == 1:
		Game.start_level(Game.level_index)
	elif i == 2:
		Game.goto_scene(Game.TITLE_SCENE)
