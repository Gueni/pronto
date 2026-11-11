extends Control
## Title screen.

const Menu = preload("res://scripts/menu.gd")

var items = []


func _ready():
	Game.hud.visible = false
	var sky = Game.sky(Color(0.2, 0.45, 0.9), Color(0.75, 0.92, 1.0))
	add_child(sky)
	sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center = CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	center.add_child(box)

	var title = Game.label("MR BLUE", 96, Color(0.3, 0.72, 1.0), true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub = Game.label("A ROGUELIKE ROAD TRIP: PRONTO AND FRIENDS VS KING PINKY", 16, Color(1.0, 0.92, 0.5))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)

	# The whole gang, running on the spot.
	var stage_center = CenterContainer.new()
	box.add_child(stage_center)
	var stage = Control.new()
	stage.custom_minimum_size = Vector2(700, 140)
	stage_center.add_child(stage)
	for i in Game.CHARACTERS.size():
		var s = Game.char_sprite(Game.CHARACTERS[i], "run" if i == 0 else "idle", 3.4)
		Game.stand(s, Vector2(70 + i * 140, 134))
		stage.add_child(s)

	var menu = Menu.new()
	box.add_child(menu)
	Music.play_track("title")
	items = ["START A RUN", "CAMP  (%d DINARS)" % Game.dinars, "QUIT"]
	menu.setup(items)
	menu.chosen.connect(_on_chosen)

	var best = Game.label("BEST DEPTH  %d      WINS  %d      BEST SCORE  %06d" % [Game.best_depth, Game.wins, Game.best_score], 16, Color(1, 1, 1))
	best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(best)
	var help = Game.label("1-4 PLAYERS ON ONE SCREEN     M: MUTE     F11: WINDOW / FULLSCREEN", 16, Color(0.15, 0.25, 0.5))
	help.add_theme_constant_override("outline_size", 0)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(help)


func _on_chosen(i):
	var choice = items[i]
	if choice == "QUIT":
		get_tree().quit()
		return
	Game.goto_scene(Game.CAMP_SCENE if choice.begins_with("CAMP") else Game.SELECT_SCENE)
