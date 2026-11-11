extends Control
## SHOOTING GALLERY: first-person target practice (tavern minigame).
## You look down a range with three rows of hedges. Baddies pop up behind them; far ones are
## small and worth more. Move = aim your crosshair, jump / action = shoot.
## Grumps throw rocks straight at your face: shoot them down. Never shoot a friend!

const DURATION = 40.0
const ROWS = [   # depth rows, far to near: ground y (fraction of the screen), sprite scale, spread, points
	{"y": 0.52, "scale": 2.6, "spread": 0.28, "points": 3},
	{"y": 0.66, "scale": 4.2, "spread": 0.36, "points": 2},
	{"y": 0.84, "scale": 6.5, "spread": 0.44, "points": 1},
]

var vs = Vector2(1152, 648)
var cross = []      # {slot, pos, cd, kick}
var targets = []    # {row, lane, kind, t, life, sprite, shot}
var rocks = []      # {from, t, x, y}
var time_left = DURATION
var spawn_in = 1.0
var score = 0
var over = false
var result = ""
var look = Vector2.ZERO
var layers = []     # one Node2D per row, so near hedges cover far targets
var overlay


func _ready():
	Game.ensure_players()
	Game.hud.visible = false
	vs = get_viewport_rect().size
	for i in ROWS.size():
		var layer = Control.new()
		layer.clip_contents = true
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.size = Vector2(vs.x, vs.y * ROWS[i].y)
		layer.z_index = i * 2 + 1
		add_child(layer)
		layers.append(layer)
		var hedge = Hedge.new()
		hedge.row = ROWS[i]
		hedge.vs = vs
		hedge.z_index = i * 2 + 2
		hedge.shade = 0.55 + 0.2 * i
		add_child(hedge)
		layers.append(hedge)
	overlay = Overlay.new()
	overlay.game = self
	overlay.z_index = 20
	add_child(overlay)
	for i in Game.players.size():
		cross.append({"slot": i, "pos": Vector2(vs.x * (i + 1) / (Game.players.size() + 1.0), vs.y * 0.55), "cd": 0.0, "kick": 0.0})


## Screen position of the feet of something standing in `row` at `lane` (-1 .. 1).
func _spot(row, lane):
	var r = ROWS[row]
	var par = look * (0.03 + 0.03 * row)
	return Vector2(vs.x * 0.5 + lane * vs.x * r.spread, vs.y * r.y) - par


func _process(delta):
	queue_redraw()
	overlay.queue_redraw()
	# The view sways a little towards where the team is aiming.
	var avg = Vector2.ZERO
	for c in cross:
		avg += c.pos
	if not cross.is_empty():
		look = look.lerp(avg / cross.size() - vs * 0.5, 1.0 - exp(-4.0 * delta))
	for i in ROWS.size():
		layers[i * 2 + 1].position = -look * (0.03 + 0.03 * i)
		layers[i * 2].size.y = vs.y * ROWS[i].y - look.y * (0.03 + 0.03 * i)

	for c in cross:
		var inp = Game.players[c.slot].input
		var dir = Vector2(Input.get_axis(inp + "_left", inp + "_right"), Input.get_axis(inp + "_up", inp + "_down"))
		if dir.length() > 1.0:
			dir = dir.normalized()
		c.pos = (c.pos + dir * 560.0 * delta).clamp(Vector2(20, 60), vs - Vector2(20, 20))
		c.cd -= delta
		c.kick = max(c.kick - delta * 5.0, 0.0)
		if not over and c.cd <= 0 and (Input.is_action_just_pressed(inp + "_jump") or Input.is_action_just_pressed(inp + "_action")):
			c.cd = 0.22
			c.kick = 1.0
			_shoot(c)

	# targets rise, wait and sink again
	for i in range(targets.size() - 1, -1, -1):
		var tg = targets[i]
		tg.t += delta
		var up = clamp(tg.t / 0.2, 0.0, 1.0) * clamp((tg.life - tg.t) / 0.2, 0.0, 1.0)
		var r = ROWS[tg.row]
		var feet = _spot(tg.row, tg.lane)
		var h = 32.0 * r.scale
		tg.sprite.position = feet + Vector2(0, -h * 0.5 + (1.0 - up) * h * 0.8)
		if tg.shot:
			tg.sprite.modulate.a = max(tg.sprite.modulate.a - delta * 5.0, 0.0)
		if tg.kind == "grump" and not tg.shot and not tg.threw and tg.t > 0.7:
			tg.threw = true
			tg.sprite.play("throw")
			rocks.append({"from": tg.sprite.position, "t": 0.0})
		if tg.t >= tg.life:
			tg.sprite.queue_free()
			targets.remove_at(i)
	# rocks flying at the camera
	for i in range(rocks.size() - 1, -1, -1):
		rocks[i].t += delta
		if rocks[i].t >= 1.4:
			rocks.remove_at(i)
			if not over:
				score = max(score - 3, 0)
				Game.sfx("hurt")
				Game.flash(Color(1, 0.2, 0.2), 0.45, 0.4)
	if over:
		return
	time_left -= delta
	spawn_in -= delta
	if spawn_in <= 0:
		var progress = 1.0 - time_left / DURATION
		spawn_in = lerp(0.9, 0.38, progress) / (1.0 + 0.25 * (cross.size() - 1))
		_spawn(progress)
	if time_left <= 0:
		_finish()


func _spawn(progress):
	var row = randi() % ROWS.size()
	var lane = randf_range(-1.0, 1.0)
	for tg in targets:
		if tg.row == row and abs(tg.lane - lane) < 0.3:
			return
	var roll = randf()
	var kind = "pinky"
	if roll < 0.14:
		kind = "friend"
	elif roll < 0.14 + 0.12 + 0.14 * progress:
		kind = "grump"
	var s = AnimatedSprite2D.new()
	s.sprite_frames = Game.frames_for(Game.DUDE if kind == "friend" else Game.PINK)
	if kind == "grump":
		s.material = Game.hue_material(0.14)
	var k = ROWS[row].scale
	s.scale = Vector2(k, k)
	s.flip_h = lane > 0
	s.play("idle")
	layers[row * 2].add_child(s)
	targets.append({"row": row, "lane": lane, "kind": kind, "t": 0.0, "life": lerp(2.0, 1.25, progress),
			"sprite": s, "shot": false, "threw": false})


func _rock_pos(rk):
	var k = clamp(rk.t / 1.4, 0.0, 1.0)
	return rk.from.lerp(Vector2(vs.x * 0.5, vs.y * 0.6), k * k) + Vector2(0, -90.0 * sin(k * PI))


func _shoot(c):
	Game.sfx("tap", 1.5)
	# rocks first: they are closest to the camera
	for i in range(rocks.size() - 1, -1, -1):
		var k = clamp(rocks[i].t / 1.4, 0.0, 1.0)
		if c.pos.distance_to(_rock_pos(rocks[i])) < 14.0 + 60.0 * k * k:
			rocks.remove_at(i)
			score += 1
			Game.sfx("explosion", 1.6, -6.0)
			return
	# then the nearest row first
	for row in range(ROWS.size() - 1, -1, -1):
		for tg in targets:
			if tg.row != row or tg.shot or tg.t > tg.life - 0.15:
				continue
			var k = ROWS[row].scale
			var p = tg.sprite.position
			var hedge_top = vs.y * ROWS[row].y - 32.0 * k * 0.28 - look.y * (0.03 + 0.03 * row)
			if abs(c.pos.x - p.x) < 9.0 * k and c.pos.y > p.y - 9.0 * k and c.pos.y < hedge_top + 4.0:
				tg.shot = true
				tg.life = tg.t + 0.3
				tg.sprite.play("hurt")
				if tg.kind == "friend":
					score = max(score - 3, 0)
					Game.sfx("hurt", 1.3)
					overlay.note("-3  THAT WAS A FRIEND!", c.pos, Color(1.0, 0.4, 0.4))
				else:
					var pts = ROWS[row].points + (1 if tg.kind == "grump" else 0)
					score += pts
					Game.sfx("coin", 1.0 + 0.15 * pts)
					overlay.note("+%d" % pts, c.pos, Color(1.0, 0.9, 0.3))
				return


func _finish():
	over = true
	rocks.clear()
	Game.gold += score
	result = "TIME!\n\n%d GOLD WON" % score
	Game.sfx("power_up")
	await get_tree().create_timer(3.0).timeout
	Game.goto_scene(Game.TAVERN_SCENE)


## Sky, hills and the floor of the range with lines running to the horizon.
func _draw():
	var horizon = vs.y * 0.44 - look.y * 0.02
	draw_rect(Rect2(0, 0, vs.x, horizon), Color(0.45, 0.72, 0.98))
	draw_rect(Rect2(0, horizon - 60, vs.x, 60), Color(0.7, 0.86, 1.0))
	for i in 7:
		var hx = i * vs.x / 6.0 - look.x * 0.02
		draw_colored_polygon(PackedVector2Array([Vector2(hx - 190, horizon), Vector2(hx, horizon - 70 - (i % 3) * 25), Vector2(hx + 190, horizon)]), Color(0.42, 0.68, 0.6))
	draw_rect(Rect2(0, horizon, vs.x, vs.y - horizon), Color(0.42, 0.72, 0.36))
	var vanish = Vector2(vs.x * 0.5 - look.x * 0.02, horizon)
	for i in range(-8, 9):
		draw_line(vanish, Vector2(vs.x * 0.5 + i * vs.x * 0.16 - look.x * 0.12, vs.y), Color(0.34, 0.62, 0.3), 2.0)
	for i in 6:
		var k = pow(i / 6.0, 2.0)
		var y = lerp(horizon, vs.y, k)
		draw_line(Vector2(0, y), Vector2(vs.x, y), Color(0.34, 0.62, 0.3), 2.0)


## A row of hedge that the targets hide behind.
class Hedge extends Node2D:
	var row
	var vs
	var shade = 1.0

	func _draw():
		var h = 32.0 * row.scale * 0.28
		var y = vs.y * row.y - h
		var w = vs.x * (row.spread * 2.0 + 0.3)
		var x = vs.x * 0.5 - w * 0.5
		draw_rect(Rect2(x, y, w, h + 8), Color(0.12 * shade, 0.42 * shade, 0.2 * shade))
		var bumps = 22
		for i in bumps:
			draw_circle(Vector2(x + w * (i + 0.5) / bumps, y), h * 0.45, Color(0.16 * shade, 0.52 * shade, 0.25 * shade))


## Crosshairs, flying rocks, guns, score: everything in front of the scene.
class Overlay extends Node2D:
	var game
	var notes = []   # floating texts {text, pos, col, t}

	func note(text, pos, col):
		notes.append({"text": text, "pos": pos, "col": col, "t": 0.0})

	func _process(delta):
		for i in range(notes.size() - 1, -1, -1):
			notes[i].t += delta
			if notes[i].t > 0.8:
				notes.remove_at(i)

	func _draw():
		var vs = game.vs
		for rk in game.rocks:
			var k = clamp(rk.t / 1.4, 0.0, 1.0)
			var p = game._rock_pos(rk)
			var r = 6.0 + 60.0 * k * k
			draw_circle(p, r, Color(0.35, 0.33, 0.4))
			draw_circle(p + Vector2(-r * 0.25, -r * 0.25), r * 0.55, Color(0.55, 0.53, 0.6))
			if k > 0.6:
				draw_arc(p, r + 6, 0, TAU, 24, Color(1, 0.3, 0.3, 0.8), 3.0)
		for c in game.cross:
			var col = Game.PLAYER_COLORS[c.slot]
			# the gun at the bottom of the screen, pointing at the crosshair
			var base = Vector2(lerp(vs.x * 0.5, c.pos.x, 0.55), vs.y + 30)
			var dir = (c.pos - base).normalized()
			var tip = base + dir * (150.0 - 26.0 * c.kick)
			draw_line(base, tip, Color(0.16, 0.16, 0.2), 30.0)
			draw_line(base + dir * 40, tip, Color(0.3, 0.3, 0.36), 16.0)
			draw_line(base, base + dir * 60, col.darkened(0.3), 38.0)
			if c.kick > 0.6:
				draw_circle(tip, 26.0 * c.kick, Color(1.0, 0.9, 0.4, 0.9))
			# crosshair
			var g = 6.0 + 8.0 * c.kick
			draw_arc(c.pos, 16, 0, TAU, 24, col, 3.0)
			for d in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
				draw_line(c.pos + d * g, c.pos + d * (g + 14), col, 3.0)
			draw_circle(c.pos, 2.5, Color.WHITE)
			draw_string(Game.FONT, c.pos + Vector2(20, -18), "P%d" % (c.slot + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col)
		for n in notes:
			draw_string(Game.FONT_BOLD, n.pos + Vector2(-100, -30 - n.t * 40), n.text, HORIZONTAL_ALIGNMENT_CENTER, 200, 16,
					Color(n.col.r, n.col.g, n.col.b, 1.0 - n.t / 0.8))
		draw_rect(Rect2(0, 0, vs.x, 50), Color(0, 0, 0.05, 0.55))
		draw_string(Game.FONT_BOLD, Vector2(24, 34), "GOLD  %d" % game.score, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1.0, 0.85, 0.3))
		draw_string(Game.FONT_BOLD, Vector2(0, 34), "TIME  %02d" % int(ceil(max(game.time_left, 0.0))), HORIZONTAL_ALIGNMENT_CENTER, vs.x, 24, Color.WHITE)
		draw_string(Game.FONT, Vector2(0, 30), "FAR = MORE GOLD    SHOOT ROCKS    BLUE = FRIEND   ", HORIZONTAL_ALIGNMENT_RIGHT, vs.x, 8, Color(0.8, 0.85, 1.0))
		if game.over:
			draw_rect(Rect2(0, vs.y * 0.3, vs.x, vs.y * 0.4), Color(0, 0, 0.05, 0.65))
			var lines = game.result.split("\n")
			for i in lines.size():
				draw_string(Game.FONT_BOLD, Vector2(0, vs.y * 0.42 + i * 40), lines[i], HORIZONTAL_ALIGNMENT_CENTER, vs.x, 32, Color(1.0, 0.9, 0.35))
