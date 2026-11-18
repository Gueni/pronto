extends Node2D
## Everything that makes a stage feel alive and is not gameplay:
## a sky with sun, moon, stars and moving light shafts; three parallax layers of hand-drawn
## silhouettes (medina roofs, dunes and palms, castle towers, crystals...); drifting clouds;
## weather in the air (pollen, leaves, sand, snow, embers, fireflies); grass that sways and
## torches that flicker on top of the ground.

const T = 16

const AIR = {   # amount, lifetime, direction, speed min / max, gravity, colour, size min / max
	"pollen": [34, 9.0, Vector2(1, -0.3), 4, 14, Vector2(0, -2), Color(1, 1, 0.9, 0.7), 1.0, 2.0],
	"leaves": [28, 7.0, Vector2(-1, 1), 10, 30, Vector2(8, 22), Color(0.95, 0.55, 0.2, 0.9), 2.0, 3.5],
	"petals": [26, 8.0, Vector2(-1, 0.6), 6, 18, Vector2(-5, 12), Color(1.0, 0.85, 0.92, 0.9), 1.5, 3.0],
	"fireflies": [30, 5.0, Vector2(0, -1), 3, 12, Vector2(0, 0), Color(0.8, 1.0, 0.4, 0.95), 1.5, 2.5],
	"sand": [70, 2.4, Vector2(1, 0.06), 150, 260, Vector2(0, 0), Color(1.0, 0.9, 0.6, 0.5), 1.0, 2.2],
	"snow": [80, 7.0, Vector2(-0.3, 1), 6, 18, Vector2(-8, 26), Color(1, 1, 1, 0.9), 1.0, 2.5],
	"dust": [34, 8.0, Vector2(0.4, -1), 2, 8, Vector2(0, -1), Color(0.75, 0.6, 1.0, 0.55), 1.0, 2.0],
	"stardust": [36, 9.0, Vector2(-1, 0.1), 6, 22, Vector2(0, 0), Color(0.9, 0.95, 1.0, 0.8), 1.0, 2.0],
	"bubbles": [46, 7.0, Vector2(0, -1), 14, 40, Vector2(0, -6), Color(1, 1, 1, 0.55), 0.06, 0.16],
	"embers": [46, 4.5, Vector2(0.2, -1), 10, 34, Vector2(4, -26), Color(1.0, 0.55, 0.15, 0.95), 1.0, 2.5],
}

var level
var theme
var layers = []        # [node, parallax factor, drift speed]
var t = 0.0
var air: CPUParticles2D
var grass


func setup(level_node, theme_def, tops):
	level = level_node
	theme = theme_def
	z_index = -20
	var back = CanvasLayer.new()
	back.layer = -10
	add_child(back)
	var sky = Game.sky(theme.sky[0], theme.sky[1])
	back.add_child(sky)
	sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var heaven = Heaven.new()
	heaven.look = theme
	back.add_child(heaven)
	heaven.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var span = level.width * T
	if theme.get("clouds", null) != null:
		_layer("clouds", theme.clouds, 0.12, span, 3, 7.0)
	_layer("hills", theme.far, 0.2, span, 11, 0.0)
	_layer(theme.get("skyline", "hills"), theme.near, 0.4, span, 23, 0.0)
	_layer("hills_low", theme.near.darkened(0.22), 0.62, span, 37, 0.0)

	if theme.get("grass", null) != null or theme.get("torch", false) or theme.get("weeds", false):
		grass = Grass.new()
		grass.level = level
		grass.color = theme.get("grass", Color.WHITE)
		grass.blades = theme.get("grass", null) != null
		grass.torch = theme.get("torch", false)
		if theme.get("weeds", false):
			grass.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			for n in ["seaweed_green_a", "seaweed_green_b", "seaweed_green_c", "seaweed_green_d", "seaweed_pink_a", "seaweed_pink_b", "seaweed_pink_c", "seaweed_pink_d", "seaweed_orange_a", "seaweed_orange_b", "rock_a", "rock_b"]:
				grass.weeds.append(load("res://assets/ocean/%s.png" % n))
		for c in tops:
			if not grass.columns.has(c.x):
				grass.columns[c.x] = []
			grass.columns[c.x].append(c.y)
		grass.z_index = 21   # relative to this node: just in front of the ground
		add_child(grass)

	var kind = theme.get("air", "")
	if AIR.has(kind):
		var front = CanvasLayer.new()
		front.layer = 2
		add_child(front)
		var a = AIR[kind]
		air = CPUParticles2D.new()
		air.amount = a[0]
		air.lifetime = a[1]
		air.preprocess = a[1]
		air.direction = a[2]
		air.spread = 180.0 if kind == "fireflies" else 25.0
		air.initial_velocity_min = a[3]
		air.initial_velocity_max = a[4]
		air.gravity = a[5]
		air.color = a[6]
		air.scale_amount_min = a[7]
		air.scale_amount_max = a[8]
		air.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		var fade = Gradient.new()
		fade.set_color(0, Color(1, 1, 1, 0))
		fade.add_point(0.2, Color(1, 1, 1, 1))
		fade.add_point(0.8, Color(1, 1, 1, 1))
		fade.set_color(fade.get_point_count() - 1, Color(1, 1, 1, 0))
		air.color_ramp = fade
		if kind == "bubbles":
			air.texture = load("res://assets/ocean/bubble_a.png")
			air.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		front.add_child(air)
		_fit_air()
		get_viewport().size_changed.connect(_fit_air)


func _fit_air():
	var vs = get_viewport_rect().size
	air.position = vs * 0.5
	air.emission_rect_extents = vs * 0.55


func _layer(style, color, factor, span, layer_seed, drift):
	var l = Layer.new()
	l.style = style
	l.color = color
	l.span = span * factor + 900.0
	l.layer_seed = layer_seed
	add_child(l)
	layers.append([l, factor, drift])


func _process(delta):
	t += delta
	if level == null or level.camera == null:
		return
	var c = level.camera.get_screen_center_position()
	var z = level.zones[level.zone_i]
	var bottom = (z.y0 + z.h) * T
	for l in layers:
		var f = l[1]
		l[0].position = Vector2(c.x * (1.0 - f) - 450.0 - fmod(t * l[2], 120.0), bottom + (c.y - (bottom - 110.0)) * (1.0 - f) * 0.6)


## Sun, moon, stars and slow shafts of light, drawn on the sky itself.
class Heaven extends Control:
	var look
	var t = 0.0

	func _ready():
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta):
		t += delta
		queue_redraw()

	func _draw():
		var w = size.x
		var h = size.y
		if look.get("stars", false):
			var rng = RandomNumberGenerator.new()
			rng.seed = 42
			for i in 110:
				var p = Vector2(rng.randf() * w, rng.randf() * h * 0.8)
				var a = 0.45 + 0.45 * sin(t * (0.8 + rng.randf() * 2.0) + i)
				draw_rect(Rect2(p, Vector2(2, 2) if i % 7 == 0 else Vector2(1.5, 1.5)), Color(1, 1, 0.9, a))
		if look.get("sun", false):
			var c = Vector2(w * 0.78, h * 0.28)
			draw_circle(c, 84 + sin(t * 1.5) * 4.0, Color(1.0, 1.0, 0.8, 0.14))
			draw_circle(c, 56, Color(1.0, 0.97, 0.75, 0.92))
		if look.get("moon", false):
			var c = Vector2(w * 0.2, h * 0.22)
			draw_circle(c, 70, Color(0.8, 0.85, 1.0, 0.1))
			draw_circle(c, 44, Color(0.92, 0.94, 1.0))
			draw_circle(c + Vector2(-12, -8), 9, Color(0.8, 0.83, 0.93))
			draw_circle(c + Vector2(14, 10), 6, Color(0.8, 0.83, 0.93))
			draw_circle(c + Vector2(6, -18), 4, Color(0.8, 0.83, 0.93))
		if look.get("rays", false):
			for i in 5:
				var x = w * (0.15 + i * 0.19) + sin(t * 0.2 + i) * 40.0
				var a = 0.05 + 0.04 * sin(t * 0.7 + i * 1.7)
				draw_colored_polygon(PackedVector2Array([
					Vector2(x, -10), Vector2(x + 70, -10), Vector2(x - 160, h + 10), Vector2(x - 300, h + 10)]), Color(1, 1, 0.85, a))


## One parallax strip of silhouettes. The ground line is y = 0; everything below is filled.
class Layer extends Node2D:
	var style = "hills"
	var color = Color.WHITE
	var span = 2000.0
	var layer_seed = 1
	var t = 0.0

	func _process(delta):
		if style in ["castle", "crystals", "planets", "medina", "reef"]:
			t += delta
			queue_redraw()

	func _hills(amp, waves, lift):
		var pts = PackedVector2Array()
		var n = int(span / 16.0) + 1
		for i in n + 1:
			var x = i * 16.0
			var k = x / 320.0 * TAU
			pts.append(Vector2(x, -lift - amp - sin(k * waves + layer_seed) * amp - sin(k * (waves + 2) + 1.3) * amp * 0.35))
		pts.append(Vector2(n * 16.0, 600))
		pts.append(Vector2(0, 600))
		draw_colored_polygon(pts, color)

	func _draw():
		var rng = RandomNumberGenerator.new()
		rng.seed = layer_seed
		var dark = color.darkened(0.2)
		match style:
			"clouds":
				var x = 0.0
				while x < span + 400.0:
					var p = Vector2(x + rng.randf_range(0, 50), rng.randf_range(-210, -110))
					var s = rng.randf_range(0.7, 1.4)
					for blob in [[Vector2(0, 0), 18, 8], [Vector2(-13, 3), 11, 6], [Vector2(14, 3), 12, 6], [Vector2(3, -6), 10, 7]]:
						_ellipse(p + blob[0] * s, blob[1] * s, blob[2] * s, color)
					x += 120.0
			"hills":
				_hills(26.0, 2, 44.0)
			"hills_low":
				_hills(12.0, 3, 4.0)
			"trees":
				_hills(10.0, 2, 14.0)
				var x = 0.0
				while x < span:
					var hgt = rng.randf_range(34, 62)
					draw_rect(Rect2(x - 2, -hgt, 4, hgt), dark)
					draw_circle(Vector2(x, -hgt), rng.randf_range(13, 20), color)
					draw_circle(Vector2(x - 9, -hgt + 7), 10, color)
					draw_circle(Vector2(x + 9, -hgt + 6), 11, color)
					x += rng.randf_range(34, 70)
			"pines":
				_hills(8.0, 2, 10.0)
				var x = 0.0
				while x < span:
					var hgt = rng.randf_range(40, 78)
					for k in 3:
						var y = -hgt * (0.3 + k * 0.28)
						var half = 8.0 + k * 5.0
						draw_colored_polygon(PackedVector2Array([Vector2(x, y - 20), Vector2(x + half, y + 8), Vector2(x - half, y + 8)]), color)
					x += rng.randf_range(22, 52)
			"dead_trees":
				_hills(8.0, 3, 8.0)
				var x = 0.0
				while x < span:
					var hgt = rng.randf_range(36, 66)
					draw_line(Vector2(x, 0), Vector2(x + 3, -hgt), dark, 4.0)
					draw_line(Vector2(x + 2, -hgt * 0.5), Vector2(x - 14, -hgt * 0.8), dark, 2.0)
					draw_line(Vector2(x + 3, -hgt * 0.7), Vector2(x + 18, -hgt * 0.95), dark, 2.0)
					draw_line(Vector2(x + 3, -hgt), Vector2(x - 6, -hgt - 12), dark, 2.0)
					x += rng.randf_range(50, 110)
			"medina":
				# white houses, blue doors, domes and a minaret now and then
				var blue = Color(0.15, 0.4, 0.85)
				var x = 0.0
				var i = 0
				while x < span:
					var w = rng.randf_range(28, 52)
					var hgt = rng.randf_range(26, 64)
					draw_rect(Rect2(x, -hgt, w, hgt + 600), color)
					draw_rect(Rect2(x, -hgt, w, 3), color.darkened(0.08))
					draw_rect(Rect2(x + w * 0.5 - 4, -12, 8, 12), blue)
					draw_rect(Rect2(x + 5, -hgt + 8, 6, 8), blue)
					if w > 40:
						draw_rect(Rect2(x + w - 12, -hgt + 8, 6, 8), blue)
					if i % 3 == 1:
						draw_circle(Vector2(x + w * 0.5, -hgt), w * 0.32, color)
						draw_rect(Rect2(x + w * 0.5 - 1, -hgt - w * 0.32 - 6, 2, 6), blue)
					if i % 5 == 3:
						draw_rect(Rect2(x + 4, -hgt - 46, 10, 46), color)
						draw_rect(Rect2(x + 2, -hgt - 30, 14, 3), blue)
						draw_circle(Vector2(x + 9, -hgt - 46), 6, blue)
						draw_rect(Rect2(x + 8, -hgt - 58, 2, 8), Color(1.0, 0.85, 0.3))
					x += w + rng.randf_range(0, 6)
					i += 1
			"dunes":
				_hills(22.0, 1, 10.0)
				var x = 60.0
				while x < span:
					var hgt = rng.randf_range(44, 70)
					var top = Vector2(x + 10, -hgt - 20)
					draw_line(Vector2(x, -10), Vector2(x + 4, -hgt * 0.5 - 15), dark, 4.0)
					draw_line(Vector2(x + 4, -hgt * 0.5 - 15), top, dark, 3.0)
					for a in [-2.6, -2.0, -1.2, -0.5, 0.2]:
						var tip = top + Vector2(cos(a), sin(a) * 0.6) * 22.0 + Vector2(0, 8)
						draw_line(top, top + (tip - top) * 0.6 + Vector2(0, -6), dark, 3.0)
						draw_line(top + (tip - top) * 0.6 + Vector2(0, -6), tip, dark, 2.0)
					x += rng.randf_range(120, 260)
			"peaks":
				var x = -40.0
				while x < span:
					var w = rng.randf_range(90, 150)
					var hgt = rng.randf_range(70, 130)
					draw_colored_polygon(PackedVector2Array([Vector2(x, 600), Vector2(x, 0), Vector2(x + w * 0.5, -hgt), Vector2(x + w, 0), Vector2(x + w, 600)]), color)
					draw_colored_polygon(PackedVector2Array([Vector2(x + w * 0.5, -hgt), Vector2(x + w * 0.62, -hgt * 0.72), Vector2(x + w * 0.5, -hgt * 0.8), Vector2(x + w * 0.4, -hgt * 0.7)]), Color(1, 1, 1))
					x += w * 0.7
			"islands":
				var x = 40.0
				while x < span:
					var y = rng.randf_range(-150, -40)
					var w = rng.randf_range(40, 80)
					draw_colored_polygon(PackedVector2Array([Vector2(x - w * 0.5, y), Vector2(x + w * 0.5, y), Vector2(x + w * 0.15, y + w * 0.5), Vector2(x - w * 0.1, y + w * 0.38)]), dark)
					draw_rect(Rect2(x - w * 0.5, y - 5, w, 6), color)
					draw_circle(Vector2(x - w * 0.15, y - 12), 9, color)
					x += rng.randf_range(110, 200)
			"crystals":
				var x = 0.0
				var i = 0
				while x < span:
					var hgt = rng.randf_range(18, 60)
					draw_colored_polygon(PackedVector2Array([Vector2(x - 12, 600), Vector2(x - 12, 0), Vector2(x, -hgt), Vector2(x + 12, 0), Vector2(x + 12, 600)]), color)
					draw_colored_polygon(PackedVector2Array([Vector2(x - 10, -330), Vector2(x, -330 + hgt * 1.4), Vector2(x + 10, -330)]), color)
					if i % 3 == 0:
						var glow = 0.55 + 0.35 * sin(t * 2.0 + i)
						var c = Color(0.5, 0.9, 1.0, glow) if i % 2 == 0 else Color(1.0, 0.5, 0.9, glow)
						var b = Vector2(x + 16, -4)
						draw_colored_polygon(PackedVector2Array([b + Vector2(-5, 0), b + Vector2(-2, -22), b + Vector2(3, -26), b + Vector2(6, 0)]), c)
						draw_circle(b + Vector2(0, -12), 18, Color(c.r, c.g, c.b, glow * 0.12))
					x += rng.randf_range(26, 60)
					i += 1
			"planets":
				var x = 80.0
				var i = 0
				while x < span:
					var y = rng.randf_range(-200, -90)
					var r = rng.randf_range(16, 40)
					var c = [Color(0.85, 0.5, 0.35), Color(0.4, 0.6, 0.9), Color(0.75, 0.7, 0.5)][i % 3]
					draw_circle(Vector2(x, y), r, c)
					draw_circle(Vector2(x - r * 0.3, y - r * 0.3), r * 0.55, c.lightened(0.18))
					if i % 2 == 0:
						draw_arc(Vector2(x, y), r * 1.6, -0.3 + sin(t * 0.2) * 0.1, PI + 0.3, 24, Color(1, 1, 1, 0.5), 2.0)
					x += rng.randf_range(220, 380)
					i += 1
				_hills(10.0, 2, 0.0)
			"reef":
				# rocks and tall weeds standing on a sandy rise, far away in the blue
				_hills(9.0, 2, 4.0)
				var light = color.lightened(0.22)
				var x = 0.0
				var i = 0
				while x < span:
					var base = Vector2(x, -8)
					if rng.randf() < 0.3:
						var w = rng.randf_range(24, 46)
						var hgt = rng.randf_range(16, 34)
						draw_colored_polygon(PackedVector2Array([base + Vector2(-w * 0.5, 8), base + Vector2(-w * 0.32, -hgt * 0.7),
							base + Vector2(w * 0.05, -hgt), base + Vector2(w * 0.4, -hgt * 0.55), base + Vector2(w * 0.5, 8)]), light)
					else:
						for stem in 2 + rng.randi() % 3:
							var hgt = rng.randf_range(34, 84)
							var sx = (stem - 1.5) * 9.0 + rng.randf_range(-3, 3)
							var pts = PackedVector2Array()
							for k in 7:
								var u = k / 6.0
								pts.append(base + Vector2(sx + sin(u * 5.0 + t * 0.9 + i + stem) * 5.0 * u, 8 - hgt * u))
							draw_polyline(pts, light, 5.0, true)
							draw_circle(pts[6], 2.5, light)
					x += rng.randf_range(30, 100)
					i += 1
			"castle":
				var x = 0.0
				var i = 0
				while x < span:
					var w = rng.randf_range(30, 56)
					var hgt = rng.randf_range(50, 120)
					draw_rect(Rect2(x, -hgt, w, hgt + 600), color)
					var k = 0.0
					while k < w - 4:
						draw_rect(Rect2(x + k, -hgt - 7, 6, 7), color)
						k += 11.0
					var lit = 0.5 + 0.5 * sin(t * (2.0 + i % 3) + i * 1.3)
					draw_rect(Rect2(x + w * 0.5 - 3, -hgt + 16, 6, 10), Color(1.0, 0.7, 0.25, 0.35 + 0.5 * lit))
					if hgt > 85:
						draw_rect(Rect2(x + w * 0.5 - 3, -hgt + 46, 6, 10), Color(1.0, 0.7, 0.25, 0.6 - 0.3 * lit))
					x += w + rng.randf_range(4, 30)
					i += 1
			_:
				_hills(18.0, 2, 20.0)

	func _ellipse(center, rx, ry, c):
		var pts = PackedVector2Array()
		for i in 14:
			var a = TAU * i / 14.0
			pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
		draw_colored_polygon(pts, c)


## Blades of grass and flowers swaying on top of the ground, and torches where it is dark.
class Grass extends Node2D:
	var level
	var color = Color.WHITE
	var blades = true
	var torch = false
	var columns = {}   # tile x -> [tile y of every ground top in that column]
	var weeds = []     # sea floor: seaweed and rock textures (Kenney Fish Pack)
	var t = 0.0

	func _process(delta):
		t += delta
		queue_redraw()

	func _draw():
		if level == null or level.camera == null:
			return
		var c = level.camera.get_screen_center_position()
		var half = level.camera.view_width() * 0.5 + 24.0
		for x in range(int((c.x - half) / 16.0), int((c.x + half) / 16.0) + 1):
			if not columns.has(x):
				continue
			for y in columns[x]:
				var wy = y * 16.0
				if abs(wy - c.y) > 260.0:
					continue
				var hash = (x * 73 + y * 151) % 97
				if not weeds.is_empty() and hash % 5 < 2:
					# a plant rooted on the tile, swaying with the current
					var tex = weeds[hash % weeds.size()]
					var rock = hash % weeds.size() >= weeds.size() - 2
					var hgt2 = 14.0 + hash % 13
					var sway2 = 0.0 if rock else sin(t * 1.6 + x * 0.9) * 0.14
					draw_set_transform(Vector2(x * 16.0 + 8.0, wy + 1.0), sway2, Vector2(1, 1))
					draw_texture_rect(tex, Rect2(-hgt2 * 0.5, -hgt2, hgt2, hgt2), false)
					draw_set_transform(Vector2.ZERO, 0.0, Vector2(1, 1))
				if blades:
					for k in 3:
						var bx = x * 16.0 + 3.0 + k * 5.0
						var sway = sin(t * 2.2 + bx * 0.11) * 1.6
						var hgt = 3.0 + (hash + k * 5) % 4
						draw_line(Vector2(bx, wy + 1), Vector2(bx + sway, wy - hgt), color if k != 1 else color.darkened(0.2), 1.0)
					if hash % 9 == 0:
						var fx = x * 16.0 + 8.0 + sin(t * 2.2 + x) * 1.2
						draw_line(Vector2(x * 16.0 + 8.0, wy), Vector2(fx, wy - 7), color.darkened(0.3), 1.0)
						draw_rect(Rect2(fx - 1.5, wy - 9.5, 3, 3), [Color(1, 1, 1), Color(1.0, 0.85, 0.3), Color(1.0, 0.5, 0.7)][hash % 3])
				if torch and hash % 11 == 0:
					var b = Vector2(x * 16.0 + 8.0, wy)
					var fl = sin(t * 13.0 + x) * 1.5
					draw_rect(Rect2(b.x - 1, b.y - 12, 2, 12), Color(0.35, 0.22, 0.12))
					draw_circle(b + Vector2(0, -15), 26.0 + fl * 2.0, Color(1.0, 0.6, 0.2, 0.09))
					draw_colored_polygon(PackedVector2Array([b + Vector2(-3, -12), b + Vector2(fl * 0.6, -20 - fl), b + Vector2(3, -12)]), Color(1.0, 0.6, 0.15))
					draw_colored_polygon(PackedVector2Array([b + Vector2(-1.5, -12), b + Vector2(fl * 0.3, -16), b + Vector2(1.5, -12)]), Color(1.0, 0.9, 0.4))
