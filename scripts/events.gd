extends Node2D
## Chest minigames: short surprises that happen right inside the level, picked at random.
##   COIN RAIN       DAN falls from the sky for a few seconds: catch it.
##   TARGET PRACTICE targets pop up around the chest: hit them with your sandal.
##   MIMIC           the chest was alive. And hungry.
##   LUCKY WHEEL     a wheel of prizes spins and stops on its own.
##   ZOMBIE TV       a cursed TV pulls you into a zombie film: survive until the credits.
## Events.start(level, position, hero who opened the chest) launches one.

const KINDS = ["rain", "targets", "mimic", "wheel", "zombies"]
const NAMES = {"rain": "COIN RAIN!", "targets": "TARGET PRACTICE!", "mimic": "IT'S A MIMIC!", "wheel": "LUCKY WHEEL!", "zombies": "ZOMBIE TV!"}
const PRIZES = ["10 DAN", "HEART", "25 DAN", "NOTHING", "60 DAN", "MANA"]

var kind = "rain"
var level
var opener
var t = 0.0
var length = 8.0
var tick = 0.0
var score = 0
var things = []        # targets / the mimic / zombies
var slot = 0           # lucky wheel
var spin = 0.05
var stopped = false
var overlay: ColorRect
var done = false


static func start(level_node, pos, hero, forced = ""):
	var e = new()
	e.kind = forced if forced != "" else KINDS[randi() % KINDS.size()]
	e.level = level_node
	e.opener = hero
	e.position = pos
	level_node.events += 1
	level_node.add_child(e)
	return e


func _ready():
	z_index = 25
	Game.sfx("power_up", 0.8)
	Game.flash(Color(1.0, 0.9, 0.4), 0.25)
	match kind:
		"rain":
			length = 7.0
		"targets":
			length = 10.0
			for i in 6:
				var tg = Target.new()
				tg.event = self
				tg.position = Vector2((40.0 + i * 16.0) * (1 if i % 2 == 0 else -1), -24.0 - (i * 37) % 60)
				add_child(tg)
				things.append(tg)
		"mimic":
			length = 30.0
			var m = level._enemy("mimic", global_position)
			things.append(m)
		"wheel":
			length = 6.0
		"zombies":
			length = 13.0
			var layer = CanvasLayer.new()
			layer.layer = 3
			add_child(layer)
			overlay = ColorRect.new()
			overlay.color = Color(0.2, 0.9, 0.3, 0.14)
			overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
			layer.add_child(overlay)
			overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _physics_process(delta):
	if done:
		return
	t += delta
	tick -= delta
	queue_redraw()
	match kind:
		"rain":
			if tick <= 0 and t < length - 1.0:
				tick = 0.16
				var d = Dan.new()
				d.position = Vector2(randf_range(-110, 110), -150)
				add_child(d)
		"targets":
			if things.all(func(x): return not is_instance_valid(x)):
				_pay(20, "PERFECT!")
				for p in level.players:
					if not p.dead:
						p.heal()
				_finish()
				return
		"mimic":
			if not is_instance_valid(things[0]) or things[0].dead:
				_finish()
				return
		"wheel":
			if not stopped and tick <= 0:
				slot = (slot + 1) % PRIZES.size()
				spin *= 1.16
				tick = spin
				Game.sfx("tap", 1.5, -6.0)
				if spin > 0.5:
					stopped = true
					length = t + 1.4
					_prize(PRIZES[slot])
		"zombies":
			overlay.color.a = 0.12 + 0.05 * sin(t * 30.0)
			if tick <= 0 and t < length - 4.0:
				tick = 1.3
				var spots = level._spots(level.zone_i)
				for attempt in (10 if not spots.is_empty() else 0):
					var cell = spots[randi() % spots.size()]
					var feet = Vector2(cell.x * 16 + 8, cell.y * 16)
					var d = abs(feet.x - global_position.x)
					if d > 50 and d < 190 and abs(feet.y - global_position.y) < 40:
						things.append(level._enemy("zombie", feet))
						Game.ring(feet + Vector2(0, -8), 14.0, Color(0.4, 1.0, 0.4), 0.3)
						break
	if t >= length:
		if kind == "zombies":
			for z in things:
				if is_instance_valid(z) and not z.dead:
					z.damage(false, 99)
			_pay(25, "THE END. YOU SURVIVED!")
			for p in level.players:
				if not p.dead:
					p.add_mana(50)
		elif kind == "targets":
			_pay(0, "TIME!")
		_finish()


func _pay(amount, text):
	if amount > 0:
		Game.add_gold(amount, global_position + Vector2(0, -20))
	Game.popup(text, global_position + Vector2(0, -34), Color(1.0, 0.9, 0.4))


func _prize(p):
	var top = global_position + Vector2(0, -30)
	if p.ends_with("DAN"):
		Game.add_gold(int(p), top)
		Game.sfx("coin")
	elif p == "HEART":
		for q in level.players:
			if not q.dead:
				q.heal()
		Game.popup("+1 HEART", top, Color(1.0, 0.5, 0.5))
		Game.sfx("power_up")
	elif p == "MANA":
		for q in level.players:
			if not q.dead:
				q.add_mana(Game.MAX_MANA)
		Game.popup("FULL MANA!", top, Color(0.5, 0.8, 1.0))
		Game.sfx("power_up")
	else:
		Game.popup("NOTHING. HEHEHE.", top, Color(0.7, 0.7, 0.75))
		Game.sfx("hurt", 0.7)


## A target was hit.
func hit():
	score += 1
	Game.add_gold(5, global_position + Vector2(0, -20))
	Game.sfx("coin", 1.0 + score * 0.1)


func _finish():
	if done:
		return
	done = true
	if level and is_instance_valid(level):
		level.events -= 1
	queue_free()


func _draw():
	var title = NAMES[kind]
	var w = 150.0
	draw_string_outline(Game.FONT_BOLD, Vector2(-w / 2, -64), title, HORIZONTAL_ALIGNMENT_CENTER, w, 8, 3, Color(0.05, 0.05, 0.12))
	draw_string(Game.FONT_BOLD, Vector2(-w / 2, -64), title, HORIZONTAL_ALIGNMENT_CENTER, w, 8, Color(1.0, 0.9, 0.4))
	if kind != "mimic":
		draw_rect(Rect2(-31, -60, 62, 4), Color(0.05, 0.05, 0.12))
		draw_rect(Rect2(-30, -59, 60.0 * clamp(1.0 - t / length, 0.0, 1.0), 2), Color(1.0, 0.85, 0.3))
	if kind == "wheel":
		for i in PRIZES.size():
			var x = -75.0 + i * 25.0
			var sel = i == slot
			draw_rect(Rect2(x, -52, 24, 14), Color(1.0, 0.85, 0.3) if sel else Color(0.12, 0.12, 0.25, 0.9))
			draw_string(Game.FONT, Vector2(x, -43), PRIZES[i].replace(" DAN", "D").left(5), HORIZONTAL_ALIGNMENT_CENTER, 24, 4, Color(0.05, 0.05, 0.12) if sel else Color.WHITE)
	if kind == "zombies":
		# the cursed TV
		draw_rect(Rect2(-9, -30, 18, 14), Color(0.2, 0.2, 0.25))
		draw_rect(Rect2(-7, -28, 14, 10), Color(0.3, 1.0, 0.4, 0.6 + 0.3 * sin(t * 40.0)))
		draw_line(Vector2(-4, -30), Vector2(-8, -36), Color(0.2, 0.2, 0.25), 1.0)
		draw_line(Vector2(4, -30), Vector2(8, -36), Color(0.2, 0.2, 0.25), 1.0)


## A falling coin of the coin rain.
class Dan extends Area2D:
	var vy = 40.0
	var life = 5.0

	func _ready():
		collision_layer = 0
		collision_mask = 3
		var c = CollisionShape2D.new()
		var s = CircleShape2D.new()
		s.radius = 5.0
		c.shape = s
		add_child(c)
		body_entered.connect(_on_body)

	func _physics_process(delta):
		vy = min(vy + 160.0 * delta, 130.0)
		position.y += vy * delta
		life -= delta
		if life <= 0:
			queue_free()

	func _on_body(body):
		if body.has_method("add_mana"):
			if not body.dead:
				Game.add_coin(null, true)
				Game.gold += 1
				body.add_mana(1)
				queue_free()
		else:
			life = min(life, 0.6)   # hit the ground: lie there for a moment
			vy = 0.0
			set_physics_process(false)
			get_tree().create_timer(0.8, false).timeout.connect(queue_free)

	func _draw():
		Game.draw_dan(self, Vector2.ZERO, 7.0)


## A bullseye for target practice: thrown things pop it.
class Target extends Node2D:
	var event
	var t = 0.0

	func _ready():
		var a = Area2D.new()
		a.collision_layer = 4
		a.collision_mask = 0
		var c = CollisionShape2D.new()
		var s = CircleShape2D.new()
		s.radius = 7.0
		c.shape = s
		a.add_child(c)
		add_child(a)

	func _process(delta):
		t += delta
		position.y += sin(t * 3.0 + position.x) * 6.0 * delta
		queue_redraw()

	func hit_by_rock(_power = 1, _from_x = null):
		if is_instance_valid(event):
			event.hit()
		Game.ring(global_position, 12.0, Color(1.0, 0.4, 0.3), 0.25)
		queue_free()

	func _draw():
		draw_circle(Vector2.ZERO, 7.0, Color(1, 1, 1))
		draw_circle(Vector2.ZERO, 5.0, Color(0.9, 0.2, 0.2))
		draw_circle(Vector2.ZERO, 3.0, Color(1, 1, 1))
		draw_circle(Vector2.ZERO, 1.2, Color(0.9, 0.2, 0.2))
