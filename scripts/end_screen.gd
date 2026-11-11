extends Control
## Game over / victory screen (Game.end_mode).

const Menu = preload("res://scripts/menu.gd")


func _ready():
	Game.hud.visible = false
	var win = Game.end_mode == "victory"
	var sky = Game.sky(Color(0.95, 0.55, 0.4), Color(1.0, 0.9, 0.6)) if win else Game.sky(Color(0.05, 0.04, 0.1), Color(0.25, 0.08, 0.12))
	add_child(sky)
	sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center = CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 22)
	center.add_child(box)

	_line(box, "SA77IT !  YOU WIN !" if win else "THE RUN IS OVER", 64, Color(0.3, 0.72, 1.0) if win else Color(1.0, 0.35, 0.35), true)
	_line(box, "QUEEN SLIME, BARON BAT AND KING PINKY ARE DEFEATED!" if win else "KING PINKY LAUGHS AT YOU... BUT YOU KEEP YOUR DINARS.", 16, Color.WHITE)

	var stage_center = CenterContainer.new()
	box.add_child(stage_center)
	var stage = Control.new()
	var n = max(Game.players.size(), 1)
	stage.custom_minimum_size = Vector2(150 * n, 140)
	stage_center.add_child(stage)
	var pronto_here = false
	for i in Game.players.size():
		var ch = Game.char_of(i)
		pronto_here = pronto_here or ch.get("laugh", false)
		var s = Game.char_sprite(ch, "run" if win else "hurt", 3.4)
		if not win:
			s.sprite_frames = s.sprite_frames.duplicate()
			s.sprite_frames.set_animation_loop("hurt", true)
			s.sprite_frames.set_animation_speed("hurt", 5)
			s.play("hurt")
		Game.stand(s, Vector2(75 + i * 150, 134))
		stage.add_child(s)
	if pronto_here:
		_line(box, "PRONTO: \"TOO EASY! PRONTO! HAHAHA!\"" if win else "PRONTO: \"I MEANT TO DO THAT. PRONTO.\"", 16, Game.CHARACTERS[0].color)
		Game.laugh()

	var record = Game.score >= Game.best_score and Game.score > 0
	_line(box, "SCORE  %06d%s" % [Game.score, "   NEW BEST!" if record else ""], 24, Color(1.0, 0.92, 0.4))
	_line(box, "REACHED ACT %d  -  %d STAGES CLEARED  -  BEST %d" % [min(Game.act + 1, Game.ACTS.size()), Game.depth, Game.best_depth], 16, Color.WHITE)
	_line(box, "+%d DINARS   (YOU HAVE %d)" % [Game.earned, Game.dinars], 24, Color(0.6, 0.95, 1.0))
	Music.play_track("camp")

	var menu = Menu.new()
	box.add_child(menu)
	menu.setup(["TO THE CAMP", "NEW RUN", "TITLE SCREEN"])
	menu.chosen.connect(_on_chosen)
	Game.sfx("power_up" if win else "explosion", 1.0 if win else 0.6)


func _line(box, text, font_size, color, bold = false):
	var l = Game.label(text, font_size, color, bold)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(l)


func _on_chosen(i):
	if i == 0:
		Game.goto_scene(Game.CAMP_SCENE)
	elif i == 1:
		Game.goto_scene(Game.SELECT_SCENE)
	else:
		Game.goto_scene(Game.TITLE_SCENE)
