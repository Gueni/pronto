extends Control
## SKY DUEL: a flying boss fight (tavern minigame).
## Every hero flies and shoots on their own; move in all four directions to dodge the
## bullet patterns of BARON BAT. The dash button is a short invincible roll.
## Winning pays gold for every heart the team has left.

const SHIP_SPEED = 340.0
const SHIP_R = 11.0
const BOSS_R = 70.0

var ships = []      # {slot, pos, hp, inv, fire, roll, roll_cd, sprite}
var bullets = []    # the heroes' shots: Vector2
var shots = []      # the baron's shots: {pos, vel, r, col}
var events = []     # scheduled attacks: {t, fn}
var boss_pos = Vector2.ZERO
var boss_hp = 100.0
var boss_max = 100.0
var boss_hit = 0.0
var boss_sprite: AnimatedSprite2D
var time = 0.0
var next_pattern = 2.5
var pattern = 0
var over = false
var result = ""
var vs = Vector2(1152, 648)


func _ready():
	Game.ensure_players()
	Game.hud.visible = false
	vs = get_viewport_rect().size
	var sky = Game.sky(Color(0.95, 0.5, 0.35), Color(1.0, 0.85, 0.55))
	add_child(sky)
	sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sky.show_behind_parent = true
	for i in Game.players.size():
		var s = Game.char_sprite(Game.char_of(i), "jump", 2.4)
		s.z_index = 2
		add_child(s)
		ships.append({"slot": i, "pos": Vector2(160, vs.y * (i + 1) / (Game.players.size() + 1.0)),
				"hp": 3, "inv": 2.0, "fire": 0.0, "roll": 0.0, "roll_cd": 0.0, "sprite": s})
	boss_sprite = AnimatedSprite2D.new()
	boss_sprite.sprite_frames = Game.frames_for(Game.OWLET)
	boss_sprite.material = Game.hue_material(0.62)
	boss_sprite.scale = Vector2(7, 7)
	boss_sprite.flip_h = true
	boss_sprite.z_index = 1
	boss_sprite.play("run")
	add_child(boss_sprite)
	boss_max = 150.0 + 70.0 * Game.players.size()
	boss_hp = boss_max
	boss_pos = Vector2(vs.x - 180, vs.y * 0.5)


func _alive():
	return ships.filter(func(s): return s.hp > 0)


func _process(delta):
	time += delta
	queue_redraw()
	boss_hit -= delta
	boss_pos = Vector2(vs.x - 180 + sin(time * 0.6) * 50.0, vs.y * 0.5 + sin(time * 0.9) * vs.y * 0.3)
	boss_sprite.position = boss_pos
	boss_sprite.modulate = Color(1, 0.5, 0.5) if boss_hit > 0 else Color.WHITE
	boss_sprite.visible = boss_hp > 0

	for s in ships:
		s.sprite.visible = s.hp > 0 and (s.inv <= 0 or int(s.inv * 16) % 2 == 0)
		if s.hp <= 0:
			continue
		var inp = Game.players[s.slot].input
		var dir = Vector2(Input.get_axis(inp + "_left", inp + "_right"), Input.get_axis(inp + "_up", inp + "_down"))
		if dir.length() > 1.0:
			dir = dir.normalized()
		s.inv -= delta
		s.roll -= delta
		s.roll_cd -= delta
		s.fire -= delta
		if not over and Input.is_action_just_pressed(inp + "_dash") and s.roll_cd <= 0:
			s.roll = 0.35
			s.roll_cd = 1.2
			s.inv = max(s.inv, 0.35)
			Game.sfx("jump", 1.6, -4.0)
		s.pos += dir * SHIP_SPEED * (1.7 if s.roll > 0 else 1.0) * delta
		s.pos = s.pos.clamp(Vector2(30, 70), Vector2(vs.x * 0.62, vs.y - 30))
		s.sprite.position = s.pos
		s.sprite.rotation = (0.35 - s.roll) / 0.35 * TAU if s.roll > 0 else 0.0
		if not over and s.fire <= 0:
			s.fire = 0.15
			bullets.append(s.pos + Vector2(24, 0))
	if over:
		return

	# the heroes' shots
	for i in range(bullets.size() - 1, -1, -1):
		var b = bullets[i]
		b.x += 820.0 * delta
		bullets[i] = b
		if bullets[i].distance_to(boss_pos) < BOSS_R:
			bullets.remove_at(i)
			boss_hp -= 1.0
			boss_hit = 0.06
			if boss_hp <= 0:
				_finish(true)
				return
		elif bullets[i].x > vs.x + 20:
			bullets.remove_at(i)

	# the baron's attacks
	next_pattern -= delta
	if next_pattern <= 0:
		var angry = boss_hp < boss_max * 0.5
		next_pattern = 2.3 if angry else 3.2
		pattern = (pattern + 1) % (4 if angry else 3)
		_attack(pattern, angry)
	for i in range(events.size() - 1, -1, -1):
		if events[i].t <= time:
			var e = events[i]
			events.remove_at(i)
			e.fn.call()
	for i in range(shots.size() - 1, -1, -1):
		var sh = shots[i]
		sh.pos += sh.vel * delta
		if sh.pos.x < -40 or sh.pos.y < -40 or sh.pos.y > vs.y + 40 or sh.pos.x > vs.x + 60:
			shots.remove_at(i)
			continue
		for s in ships:
			if s.hp > 0 and s.inv <= 0 and s.pos.distance_to(sh.pos) < SHIP_R + sh.r:
				_hit(s)
				shots.remove_at(i)
				break
	for s in ships:
		if s.hp > 0 and s.inv <= 0 and s.pos.distance_to(boss_pos) < BOSS_R:
			_hit(s)
	if _alive().is_empty():
		_finish(false)


func _hit(s):
	s.hp -= 1
	s.inv = 1.6
	Game.sfx("hurt")
	Game.flash(Color(1, 0.3, 0.3), 0.2, 0.2)


func _shot(pos, vel, r = 8.0, col = Color(1.0, 0.35, 0.5)):
	shots.append({"pos": pos, "vel": vel, "r": r, "col": col})


func _later(wait, fn):
	events.append({"t": time + wait, "fn": fn})


func _attack(which, angry):
	match which:
		0:
			# fans aimed at a hero
			for k in (4 if angry else 3):
				_later(k * 0.35, func():
					var alive = _alive()
					if alive.is_empty():
						return
					var aim = (alive[randi() % alive.size()].pos - boss_pos).angle()
					for a in [-0.22, 0.0, 0.22]:
						_shot(boss_pos, Vector2.from_angle(aim + a) * 340.0)
					Game.sfx("tap", 1.2, -6.0))
		1:
			# rings
			for k in (2 if angry else 1):
				_later(k * 0.5, func():
					var off = randf() * TAU
					for j in 18:
						_shot(boss_pos, Vector2.from_angle(off + TAU * j / 18.0) * 230.0, 7.0, Color(1.0, 0.75, 0.3))
					Game.sfx("explosion", 1.5, -8.0))
		2:
			# a wall with one gap to fly through
			var gap = randf_range(110.0, vs.y - 110.0)
			var y = 20.0
			while y < vs.y:
				if abs(y - gap) > 85.0:
					_shot(Vector2(vs.x + 20, y), Vector2(-250.0 if not angry else -300.0, 0), 9.0, Color(0.7, 0.5, 1.0))
				y += 34.0
			Game.sfx("explosion", 0.8, -6.0)
		3:
			# slow drifting mines from above and below
			for j in 7:
				var x = randf_range(60.0, vs.x * 0.65)
				_shot(Vector2(x, -20), Vector2(randf_range(-40, 40), 170.0), 12.0, Color(0.4, 0.9, 0.5))
				_shot(Vector2(x + 60, vs.y + 20), Vector2(randf_range(-40, 40), -170.0), 12.0, Color(0.4, 0.9, 0.5))


func _finish(won):
	if over:
		return
	over = true
	shots.clear()
	events.clear()
	var hearts = 0
	for s in ships:
		hearts += max(s.hp, 0)
	var pay = 25 + 8 * hearts if won else 5
	Game.gold += pay
	result = ("BARON BAT IS DOWN!\n\n+%d GOLD" if won else "SHOT DOWN...\n\n+%d GOLD FOR TRYING") % pay
	Game.sfx("power_up" if won else "explosion", 1.0 if won else 0.6)
	if won:
		Game.flash(Color.WHITE, 0.6, 0.6)
	await get_tree().create_timer(3.0).timeout
	Game.goto_scene(Game.TAVERN_SCENE)


func _draw():
	# drifting clouds
	for i in 9:
		var cx = fposmod(i * 311.0 - time * (40.0 + (i % 3) * 30.0), vs.x + 300.0) - 150.0
		var cy = 60.0 + (i * 97) % int(vs.y - 100)
		var a = 0.25 + 0.12 * (i % 3)
		draw_circle(Vector2(cx, cy), 34, Color(1, 1, 1, a))
		draw_circle(Vector2(cx + 36, cy + 8), 26, Color(1, 1, 1, a))
		draw_circle(Vector2(cx - 34, cy + 10), 22, Color(1, 1, 1, a))
	# the baron's wings
	if boss_hp > 0:
		var flap = sin(time * 9.0) * 34.0
		for side in [-1, 1]:
			draw_colored_polygon(PackedVector2Array([
				boss_pos + Vector2(0, side * 20), boss_pos + Vector2(60, side * (130 + flap)),
				boss_pos + Vector2(-40, side * (95 + flap * 0.5))]), Color(0.2, 0.12, 0.3))
	# heroes: little wings and a ring while rolling
	for s in ships:
		if s.hp <= 0:
			continue
		var col = Game.PLAYER_COLORS[s.slot]
		var flap = sin(time * 22.0 + s.slot) * 8.0
		for side in [-1, 1]:
			draw_colored_polygon(PackedVector2Array([
				s.pos + Vector2(-6, side * 4), s.pos + Vector2(-30, side * (22 + flap)), s.pos + Vector2(-22, side * 2)]),
				Color(1, 1, 1, 0.85))
		if s.roll > 0:
			draw_arc(s.pos, 30, 0, TAU, 24, col, 3.0)
	for b in bullets:
		draw_rect(Rect2(b.x - 9, b.y - 3, 18, 6), Color(1.0, 0.95, 0.5))
	for sh in shots:
		draw_circle(sh.pos, sh.r + 3, Color(sh.col.r, sh.col.g, sh.col.b, 0.35))
		draw_circle(sh.pos, sh.r, sh.col)
		draw_circle(sh.pos, sh.r * 0.45, Color.WHITE)
	# boss bar, hearts, hints
	var bw = vs.x * 0.5
	draw_string(Game.FONT_BOLD, Vector2(vs.x * 0.25, 30), "BARON BAT", HORIZONTAL_ALIGNMENT_CENTER, bw, 16, Color(1.0, 0.6, 0.85))
	draw_rect(Rect2(vs.x * 0.25 - 2, 38, bw + 4, 18), Color(0.08, 0.05, 0.12))
	draw_rect(Rect2(vs.x * 0.25, 40, bw * clamp(boss_hp / boss_max, 0.0, 1.0), 14), Color(1.0, 0.4, 0.75))
	for s in ships:
		var x = 24 + s.slot * 210.0
		var col = Game.PLAYER_COLORS[s.slot]
		draw_string(Game.FONT, Vector2(x, vs.y - 16), "P%d  %s" % [s.slot + 1, "%d HP" % s.hp if s.hp > 0 else "DOWN"],
				HORIZONTAL_ALIGNMENT_LEFT, -1, 16, col)
	if time < 5.0:
		draw_string(Game.FONT, Vector2(0, vs.y - 50), "MOVE: FLY     DASH BUTTON: ROLL THROUGH BULLETS     YOU SHOOT ON YOUR OWN",
				HORIZONTAL_ALIGNMENT_CENTER, vs.x, 16, Color.WHITE)
	if over:
		draw_rect(Rect2(0, vs.y * 0.3, vs.x, vs.y * 0.4), Color(0, 0, 0.05, 0.6))
		var lines = result.split("\n")
		for i in lines.size():
			draw_string(Game.FONT_BOLD, Vector2(0, vs.y * 0.42 + i * 40), lines[i], HORIZONTAL_ALIGNMENT_CENTER, vs.x, 32, Color(1.0, 0.9, 0.35))
