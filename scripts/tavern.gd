extends Control
## THE TIPSY SLIME: a tavern stop on the run map.
## Spend the gold of this run on boons, food, drinks, an extra life or a bet.

const Menu = preload("res://scripts/menu.gd")

const RUMORS = [
	"THE QUEEN LEAPS ON YOU. JUMP OVER THE SHOCKWAVES WHEN SHE LANDS.",
	"THE KING IS DIZZY AFTER HE RAMS A WALL. THAT'S YOUR MOMENT.",
	"SPIKY SLIMES: SANDAL, NEVER STOMP.",
	"SHIELD GUYS BLOCK WHAT COMES FROM THE FRONT. JUMP ON THEIR HEADS.",
	"GHOSTS CAN ONLY BE HIT WHILE THEY ARE SOLID. SO CAN YOU.",
	"A SHAMAN WARDS HIS FRIENDS. KILL HIM FIRST.",
	"RED LINE ON THE GROUND? A SNIPER IS AIMING. MOVE.",
	"THE ONES WITH A FUSE ON THEIR HEAD BLOW UP THEIR OWN FRIENDS TOO.",
	"DINARS ARE PAID WHEN THE RUN ENDS. SPEND THEM AT THE CAMP.",
]

var menu
var items = []
var stock = []       # boons for sale
var gold_l: Label
var team_l: Label
var desc_l: Label
var message = ""
var message_time = 0.0


func _ready():
	Game.ensure_players()
	Game.hud.visible = false
	Music.play_track("tavern")
	stock = Game.roll_boons(3)
	var back = Backdrop.new()
	add_child(back)
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var vs = get_viewport_rect().size
	# The barkeeper behind his counter, the heroes at the door.
	var keeper = AnimatedSprite2D.new()
	keeper.sprite_frames = Game.frames_for(Game.PINK)
	keeper.material = Game.hue_material(0.14)
	keeper.scale = Vector2(6, 6)
	keeper.flip_h = true
	keeper.position = Vector2(vs.x - 190, vs.y - 262)
	keeper.play("idle")
	add_child(keeper)
	var counter = ColorRect.new()
	counter.color = Color(0.36, 0.2, 0.12)
	counter.position = Vector2(vs.x - 380, vs.y - 230)
	counter.size = Vector2(380, 130)
	add_child(counter)
	var top = ColorRect.new()
	top.color = Color(0.55, 0.33, 0.18)
	top.position = Vector2(vs.x - 396, vs.y - 242)
	top.size = Vector2(396, 18)
	add_child(top)
	for i in Game.players.size():
		var s = Game.char_sprite(Game.char_of(i), "idle", 3.4)
		Game.stand(s, Vector2(90 + i * 84, vs.y - 100))
		add_child(s)

	var center = CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.05, 0.05, 0.82)
	style.border_color = Color(0.75, 0.55, 0.25)
	style.set_border_width_all(4)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.custom_minimum_size = Vector2(600, 0)
	panel.add_child(box)

	var title = Game.label("THE TIPSY SLIME", 32, Color(1.0, 0.85, 0.35), true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	gold_l = Game.label("", 24, Color(1.0, 0.85, 0.3))
	gold_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(gold_l)
	team_l = Game.label("", 16, Color(0.85, 0.9, 1.0))
	team_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(team_l)
	menu = Menu.new()
	box.add_child(menu)
	menu.chosen.connect(_on_chosen)
	desc_l = Game.label("", 16, Color.WHITE)
	desc_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_l.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_l.custom_minimum_size = Vector2(600, 64)
	box.add_child(desc_l)
	_build(0)
	_say("WELCOME, HEROES! WHAT WILL IT BE?")


func _price():
	return 40 + 10 * Game.act


func _item(text, desc, act):
	items.append({"text": text, "desc": desc, "act": act})


func _build(keep):
	items = []
	for b in stock:
		_item("%s   %d G" % [b.name, _price()], b.desc, _buy_boon.bind(b))
	_item("FRUIT PIE   12 G", "HEALS EVERY HERO COMPLETELY.", _pie)
	_item("PRONTO PUNCH   15 G", "EVERYONE GETS A FULL MANA BAR.", _punch)
	_item("EXTRA LIFE   50 G", "ONE MORE TRY. YOU HAVE %d." % Game.lives, _life)
	_item("DOUBLE OR NOTHING   10 G", "BET 10 GOLD ON THE BARKEEPER'S DICE. WIN 20.", _bet)
	_item("RUMOR   FREE", "THE BARKEEPER HEARS THINGS.", func(): _say(RUMORS[randi() % RUMORS.size()]))
	_item("BACK ON THE ROAD", "LEAVE THE TAVERN.", func(): Game.node_done())
	var texts = []
	for it in items:
		texts.append(it.text)
	menu.setup(texts, 16)
	menu.index = clamp(keep, 0, items.size() - 1)
	menu._refresh()


func _on_chosen(i):
	if Game.busy or i >= items.size():
		return
	items[i].act.call()


func _pay(price):
	if Game.gold < price:
		_say("NOT ENOUGH GOLD. COME BACK RICHER!")
		Game.sfx("tap", 0.5)
		return false
	Game.gold -= price
	Game.sfx("coin")
	return true


func _buy_boon(b):
	if _pay(_price()):
		Game.add_boon(b.id)
		stock.erase(b)
		Game.sfx("power_up")
		_say("%s! A FINE CHOICE." % b.name)
		_build(menu.index)


func _pie():
	var hurt = false
	for i in Game.players.size():
		hurt = hurt or Game.players[i].hearts < Game.max_hearts(i)
	if not hurt:
		_say("YOU ALL LOOK HEALTHY TO ME.")
	elif _pay(12):
		for i in Game.players.size():
			Game.players[i].hearts = Game.max_hearts(i)
		_say("FRESH FROM THE OVEN. EVERYONE IS HEALED!")


func _punch():
	if Game.players.all(func(p): return p.mana >= Game.MAX_MANA):
		_say("YOU'RE ALREADY BUZZING WITH MANA.")
	elif _pay(15):
		for p in Game.players:
			p.mana = Game.MAX_MANA
		_say("PRONTO PUNCH! YOUR ULTIMATES ARE READY.")


func _life():
	if _pay(50):
		Game.lives += 1
		_say("ONE EXTRA LIFE. TRY NOT TO NEED IT.")
		_build(menu.index)


func _bet():
	if _pay(10):
		if randf() < 0.45:
			Game.gold += 20
			Game.sfx("power_up", 1.3)
			_say("SIX! YOU WIN 20 GOLD. BEGINNER'S LUCK...")
		else:
			Game.sfx("hurt", 0.8)
			_say("ONE. THE HOUSE WINS. HEHEHE.")


func _say(text):
	message = text
	message_time = 3.5


func _process(delta):
	gold_l.text = "GOLD  %d" % Game.gold
	var parts = []
	for i in Game.players.size():
		parts.append("%s %d/%d" % [Game.char_of(i).name, Game.players[i].hearts, Game.max_hearts(i)])
	team_l.text = "LIVES x%d     HEARTS:  %s" % [Game.lives, "   ".join(parts)]
	message_time -= delta
	if message_time > 0:
		desc_l.text = "\"%s\"" % message
		desc_l.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	elif menu.index < items.size():
		desc_l.text = items[menu.index].desc
		desc_l.add_theme_color_override("font_color", Color.WHITE)


## Wooden walls, shelves full of bottles, lanterns and a window: all drawn by hand.
class Backdrop extends Control:
	var t = 0.0

	func _process(delta):
		t += delta
		queue_redraw()

	func _draw():
		var w = size.x
		var h = size.y
		draw_rect(Rect2(0, 0, w, h), Color(0.22, 0.13, 0.1))
		var x = 0.0
		while x < w:
			draw_rect(Rect2(x, 0, 2, h - 100), Color(0.15, 0.08, 0.06))
			x += 64.0
		draw_rect(Rect2(0, h - 100, w, 100), Color(0.3, 0.19, 0.12))
		x = 0.0
		while x < w:
			draw_rect(Rect2(x, h - 100, 3, 100), Color(0.2, 0.12, 0.08))
			x += 120.0
		draw_rect(Rect2(0, h - 104, w, 6), Color(0.12, 0.07, 0.05))
		# window with the night outside
		draw_rect(Rect2(70, 90, 190, 150), Color(0.12, 0.07, 0.05))
		draw_rect(Rect2(80, 100, 170, 130), Color(0.08, 0.1, 0.28))
		draw_circle(Vector2(210, 135), 16, Color(1.0, 0.95, 0.75))
		draw_rect(Rect2(162, 100, 6, 130), Color(0.12, 0.07, 0.05))
		draw_rect(Rect2(80, 162, 170, 6), Color(0.12, 0.07, 0.05))
		# shelves and bottles behind the bar
		var colors = [Color(0.4, 0.8, 0.5), Color(0.9, 0.5, 0.3), Color(0.5, 0.6, 1.0), Color(0.9, 0.8, 0.3), Color(0.8, 0.4, 0.8)]
		for row in 2:
			var y = 150.0 + row * 80.0
			draw_rect(Rect2(w - 360, y, 320, 8), Color(0.45, 0.27, 0.15))
			for i in 9:
				var bx = w - 345 + i * 34.0
				var c = colors[(i + row * 2) % colors.size()]
				draw_rect(Rect2(bx, y - 34, 16, 34), c)
				draw_rect(Rect2(bx + 5, y - 46, 6, 12), c.darkened(0.3))
				draw_rect(Rect2(bx + 3, y - 28, 3, 18), Color(1, 1, 1, 0.35))
		# lanterns
		for lx in [w * 0.3, w * 0.5, w * 0.7]:
			var glow = 0.75 + 0.2 * sin(t * 5.0 + lx)
			draw_line(Vector2(lx, 0), Vector2(lx, 50), Color(0.1, 0.06, 0.05), 3.0)
			draw_circle(Vector2(lx, 62), 46 * glow, Color(1.0, 0.75, 0.3, 0.12))
			draw_rect(Rect2(lx - 10, 50, 20, 24), Color(1.0, 0.8, 0.35, glow))
			draw_rect(Rect2(lx - 12, 46, 24, 5), Color(0.1, 0.06, 0.05))
