extends "res://scripts/level.gd"
## Builds a whole level from the text chunks in level_data.gd (see the legend there).

const TILESET_TEX = preload("res://assets/sprites/world_tileset.png")
const CoinScene = preload("res://scenes/coin.tscn")
const Enemy = preload("res://scripts/enemy.gd")
const Block = preload("res://scripts/block.gd")
const Hazard = preload("res://scripts/hazard.gd")
const MovingPlatform = preload("res://scripts/moving_platform.gd")
const Spring = preload("res://scripts/spring.gd")
const ManaOrb = preload("res://scripts/mana_orb.gd")
const Crumble = preload("res://scripts/crumble.gd")

const ROWS = 14
const T = 16

var THEMES = {
	"grass": {
		"top": Vector2i(0, 0), "fill": Vector2i(0, 1), "brick_top": Vector2i(1, 0), "brick": Vector2i(1, 1),
		"question": Vector2i(0, 2), "tree": [Vector2i(0, 5), Vector2i(0, 4), Vector2i(0, 3)],
		"bush": Vector2i(1, 5), "mushroom": Vector2i(7, 5), "sign": Vector2i(8, 3), "bridge": 0, "platform": 0,
		"sky": [Color(0.33, 0.62, 0.93), Color(0.78, 0.92, 1.0)],
		"hills": Color(0.42, 0.75, 0.55), "far": Color(0.6, 0.85, 0.8), "clouds": Color(1, 1, 1, 0.9),
	},
	"autumn": {
		"top": Vector2i(4, 0), "fill": Vector2i(4, 1), "brick_top": Vector2i(5, 0), "brick": Vector2i(5, 1),
		"question": Vector2i(4, 2), "tree": [Vector2i(5, 5), Vector2i(5, 4), Vector2i(5, 3)],
		"bush": Vector2i(5, 7), "mushroom": Vector2i(7, 6), "sign": Vector2i(8, 4), "bridge": 2, "platform": 2,
		"sky": [Color(0.95, 0.5, 0.45), Color(1.0, 0.86, 0.62)],
		"hills": Color(0.78, 0.4, 0.42), "far": Color(0.95, 0.62, 0.5), "clouds": Color(1, 0.93, 0.85, 0.85),
	},
	"ice": {
		"top": Vector2i(7, 0), "fill": Vector2i(6, 2), "brick_top": Vector2i(8, 0), "brick": Vector2i(8, 1),
		"question": Vector2i(7, 2), "tree": [Vector2i(6, 5), Vector2i(6, 4), Vector2i(6, 3)],
		"bush": Vector2i(6, 7), "mushroom": Vector2i(7, 8), "sign": Vector2i(8, 3), "bridge": 1, "platform": 3,
		"sky": [Color(0.4, 0.55, 0.85), Color(0.86, 0.94, 1.0)],
		"hills": Color(0.82, 0.9, 0.98), "far": Color(0.68, 0.8, 0.95), "clouds": Color(1, 1, 1, 0.9),
	},
	"castle": {
		"top": Vector2i(8, 0), "fill": Vector2i(8, 1), "brick_top": Vector2i(6, 1), "brick": Vector2i(6, 1),
		"question": Vector2i(7, 2), "tree": [Vector2i(7, 7), Vector2i(7, 7), Vector2i(7, 7)],
		"bush": Vector2i(8, 7), "mushroom": Vector2i(7, 7), "sign": Vector2i(8, 4), "bridge": 2, "platform": 1,
		"sky": [Color(0.07, 0.05, 0.12), Color(0.3, 0.1, 0.12)],
		"hills": Color(0.16, 0.1, 0.17), "far": Color(0.12, 0.07, 0.14), "clouds": null,
	},
	"sahara": {
		"top": Vector2i(4, 0), "fill": Vector2i(4, 1), "brick_top": Vector2i(5, 0), "brick": Vector2i(5, 1),
		"question": Vector2i(4, 2), "tree": [Vector2i(5, 5), Vector2i(5, 4), Vector2i(5, 3)],
		"bush": Vector2i(5, 7), "mushroom": Vector2i(7, 6), "sign": Vector2i(8, 4), "bridge": 2, "platform": 2,
		"sky": [Color(1.0, 0.62, 0.3), Color(1.0, 0.92, 0.65)], "tint": Color(1.0, 0.9, 0.62), "sun": true,
		"hills": Color(0.93, 0.72, 0.4), "far": Color(0.98, 0.83, 0.52), "clouds": null,
		"plank": Color(0.85, 0.65, 0.35),
	},
	"medina": {
		"top": Vector2i(7, 0), "fill": Vector2i(6, 2), "brick_top": Vector2i(8, 0), "brick": Vector2i(8, 1),
		"question": Vector2i(7, 2), "tree": [Vector2i(0, 5), Vector2i(0, 4), Vector2i(0, 3)],
		"bush": Vector2i(1, 5), "mushroom": Vector2i(7, 5), "sign": Vector2i(8, 3), "bridge": 1, "platform": 3,
		"sky": [Color(0.1, 0.4, 0.9), Color(0.6, 0.85, 1.0)], "tint": Color(1.0, 1.0, 1.0), "sun": true,
		"hills": Color(0.97, 0.97, 1.0), "far": Color(0.25, 0.55, 0.95), "clouds": Color(1, 1, 1, 0.9),
		"plank": Color(0.2, 0.45, 0.9),
	},
	"night": {
		"top": Vector2i(0, 0), "fill": Vector2i(0, 1), "brick_top": Vector2i(1, 0), "brick": Vector2i(1, 1),
		"question": Vector2i(0, 2), "tree": [Vector2i(0, 5), Vector2i(0, 4), Vector2i(0, 3)],
		"bush": Vector2i(1, 5), "mushroom": Vector2i(7, 5), "sign": Vector2i(8, 3), "bridge": 0, "platform": 0,
		"sky": [Color(0.04, 0.05, 0.16), Color(0.16, 0.2, 0.45)], "stars": true, "tint": Color(0.62, 0.68, 0.95),
		"hills": Color(0.1, 0.16, 0.3), "far": Color(0.13, 0.2, 0.4), "clouds": Color(0.6, 0.65, 0.9, 0.25),
		"plank": Color(0.45, 0.4, 0.6),
	},
	"swamp": {
		"top": Vector2i(0, 0), "fill": Vector2i(0, 1), "brick_top": Vector2i(1, 0), "brick": Vector2i(1, 1),
		"question": Vector2i(0, 2), "tree": [Vector2i(0, 5), Vector2i(0, 4), Vector2i(0, 3)],
		"bush": Vector2i(1, 5), "mushroom": Vector2i(7, 5), "sign": Vector2i(8, 3), "bridge": 0, "platform": 0,
		"sky": [Color(0.16, 0.26, 0.24), Color(0.5, 0.62, 0.4)], "tint": Color(0.72, 0.9, 0.68),
		"hills": Color(0.2, 0.36, 0.26), "far": Color(0.3, 0.46, 0.34), "clouds": Color(0.8, 0.9, 0.7, 0.35),
		"plank": Color(0.5, 0.55, 0.3),
	},
	"cave": {
		"top": Vector2i(8, 0), "fill": Vector2i(8, 1), "brick_top": Vector2i(6, 1), "brick": Vector2i(6, 1),
		"question": Vector2i(7, 2), "tree": [Vector2i(7, 7), Vector2i(7, 7), Vector2i(7, 7)],
		"bush": Vector2i(8, 7), "mushroom": Vector2i(7, 7), "sign": Vector2i(8, 4), "bridge": 1, "platform": 3,
		"sky": [Color(0.05, 0.04, 0.14), Color(0.16, 0.1, 0.32)], "tint": Color(0.8, 0.75, 1.0),
		"hills": Color(0.13, 0.09, 0.26), "far": Color(0.1, 0.07, 0.2), "clouds": null,
		"plank": Color(0.5, 0.45, 0.75),
	},
	"sky": {
		"top": Vector2i(7, 0), "fill": Vector2i(6, 2), "brick_top": Vector2i(8, 0), "brick": Vector2i(8, 1),
		"question": Vector2i(7, 2), "tree": [Vector2i(6, 5), Vector2i(6, 4), Vector2i(6, 3)],
		"bush": Vector2i(6, 7), "mushroom": Vector2i(7, 8), "sign": Vector2i(8, 3), "bridge": 1, "platform": 3,
		"sky": [Color(0.25, 0.5, 0.95), Color(1.0, 0.85, 0.8)], "tint": Color(1.0, 0.95, 1.0),
		"hills": Color(1.0, 1.0, 1.0, 0.75), "far": Color(1.0, 0.92, 0.95, 0.55), "clouds": Color(1, 1, 1, 0.95),
		"plank": Color(0.95, 0.95, 1.0),
	},
	"space": {
		"top": Vector2i(8, 0), "fill": Vector2i(8, 1), "brick_top": Vector2i(6, 1), "brick": Vector2i(6, 1),
		"question": Vector2i(7, 2), "tree": [Vector2i(7, 7), Vector2i(7, 7), Vector2i(7, 7)],
		"bush": Vector2i(8, 7), "mushroom": Vector2i(7, 7), "sign": Vector2i(8, 4), "bridge": 1, "platform": 1,
		"sky": [Color(0.01, 0.01, 0.05), Color(0.12, 0.05, 0.25)], "stars": true, "tint": Color(0.75, 0.85, 1.0),
		"hills": Color(0.2, 0.2, 0.3), "far": Color(0.12, 0.12, 0.2), "clouds": null,
		"plank": Color(0.5, 0.8, 1.0),
	},
}

var theme
var rows = []
var width = 0
var tileset: TileSet
var source: TileSetAtlasSource
var ground: TileMapLayer
var decor: TileMapLayer
var texts = []
var platform_count = 0
var scenery = []
var waves = []          # ambush stages: lists of enemy kinds
var wave_i = 0
var wave_wait = 2.0
var spawn_rng = RandomNumberGenerator.new()


func build():
	var def = Game.level_def()
	if not def.has("chunks"):
		def = Game.RunGen.make_stage(0, 0, "fight", randi(), 0)
		Game.stage = def
	waves = def.get("waves", [])
	spawn_rng.seed = def.get("seed", 1) + 99
	theme = THEMES[def.get("theme", "grass")]
	time_limit = def.get("time", 300)
	slip = def.get("slip", 1.0)
	grav = def.get("gravity", 1.0)
	scroll = def.get("scroll", 0.0)
	texts = def.get("texts", [])
	rows = assemble(def.chunks)
	width = rows[0].length()
	limits = Rect2(0, -64, width * T, ROWS * T + 64)
	kill_y = ROWS * T + 32

	_background()

	tileset = TileSet.new()
	tileset.tile_size = Vector2i(T, T)
	tileset.add_physics_layer()
	tileset.set_physics_layer_collision_layer(0, 1)
	source = TileSetAtlasSource.new()
	source.texture = TILESET_TEX
	source.texture_region_size = Vector2i(T, T)
	tileset.add_source(source, 0)
	decor = TileMapLayer.new()
	decor.tile_set = tileset
	decor.z_index = -1
	add_child(decor)
	ground = TileMapLayer.new()
	ground.tile_set = tileset
	add_child(ground)
	ground.modulate = theme.get("tint", Color.WHITE)
	decor.modulate = theme.get("tint", Color.WHITE)

	var backing = Backing.new()
	backing.z_index = -2
	add_child(backing)
	for y in ROWS:
		for x in width:
			var c = rows[y][x]
			if c == "#" or c == "X":
				backing.cells.append([Vector2i(x, y), _at(x, y - 1) != c])
			_spawn(c, x, y)

	_random_spawns(def)

	# Invisible walls at both ends of the level.
	var walls = StaticBody2D.new()
	for wx in [-8.0, width * T + 8.0]:
		var c = CollisionShape2D.new()
		var r = RectangleShape2D.new()
		r.size = Vector2(16, 2000)
		c.shape = r
		c.position = Vector2(wx, 0)
		walls.add_child(c)
	add_child(walls)


## Glue the chunks together into ROWS strings of equal length.
static func assemble(chunks):
	var out = []
	for i in ROWS:
		out.append("")
	for ci in chunks.size():
		var lines = []
		for line in chunks[ci].strip_edges().split("\n"):
			lines.append(line.strip_edges())
		if lines.size() != ROWS:
			push_error("Level chunk %d has %d rows instead of %d" % [ci, lines.size(), ROWS])
		var w = 0
		for line in lines:
			w = max(w, line.length())
		for y in ROWS:
			var line = lines[y] if y < lines.size() else ""
			if line.length() != w:
				push_warning("Level chunk %d row %d is %d wide, expected %d" % [ci, y, line.length(), w])
			out[y] += line.rpad(w, ".")
	return out


func _at(x, y):
	if x < 0 or y < 0 or x >= width or y >= ROWS:
		return "."
	return rows[y][x]


func _tile(coords: Vector2i, mode = 0):
	# mode 0: no collision, 1: solid, 2: thin one-way top
	if not source.has_tile(coords):
		source.create_tile(coords)
		if mode > 0:
			var td = source.get_tile_data(coords, 0)
			td.add_collision_polygon(0)
			if mode == 1:
				td.set_collision_polygon_points(0, 0, PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)]))
			else:
				td.set_collision_polygon_points(0, 0, PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, -2), Vector2(-8, -2)]))
				td.set_collision_polygon_one_way(0, 0, true)
	return coords


func _spawn(c, x, y):
	var cell = Vector2i(x, y)
	var center = Vector2(x * T + 8, y * T + 8)
	var feet = Vector2(x * T + 8, (y + 1) * T)
	match c:
		".", " ":
			pass
		"#":
			ground.set_cell(cell, 0, _tile(theme.fill if _at(x, y - 1) == "#" else theme.top, 1))
		"X":
			ground.set_cell(cell, 0, _tile(theme.brick if _at(x, y - 1) == "X" else theme.brick_top, 1))
		"=":
			ground.set_cell(cell, 0, _tile(Vector2i(9 + x % 6, theme.bridge), 2))
		"~":
			decor.set_cell(cell, 0, _tile(Vector2i(4, 14) if _at(x, y - 1) == "~" else Vector2i(4, 13)))
			if _at(x, y - 1) != "~":
				_hazard("lava", center)
		"^":
			_hazard("spike", center)
		"o":
			var coin = CoinScene.instantiate()
			coin.position = center
			add_child(coin)
		"?":
			_block("coin", center)
		"M":
			_block("multi", center)
		"F":
			_block("fruit", center)
		"R":
			_block("rock", center)
		"L":
			_block("life", center)
		"C":
			_block("crate", center)
		"H":
			_platform(center, Vector2(80, 0))
		"V":
			_platform(center, Vector2(0, -48))
		"E":
			_platform(center, Vector2(0, -96))
		"S":
			_add(Spring.new(), center)
		"*":
			_add(ManaOrb.new(), center)
		"D":
			var plank = Crumble.new()
			plank.tint = theme.get("plank", plank.tint)
			_add(plank, center)
		"B":
			_enemy("bat", feet)
		"k":
			_enemy("spiky", feet)
		"f":
			_hazard("fire", center)
		"r":
			_enemy("charger", feet)
		"Q":
			_enemy("queen", feet)
		"p":
			_enemy("pinky", feet)
		"w":
			_enemy("grump", feet)
		"s":
			_enemy("slime", feet)
		"u":
			_enemy("slime_purple", feet)
		"K":
			_enemy("boss", feet)
		"P":
			spawn_point = feet
		"G":
			add_goal(feet)
		"c":
			add_checkpoint(feet)
		"T":
			for i in 3:
				decor.set_cell(cell - Vector2i(0, i), 0, _tile(theme.tree[i]))
		"b":
			decor.set_cell(cell, 0, _tile(theme.bush))
		"m":
			decor.set_cell(cell, 0, _tile(theme.mushroom))
		_:
			if c.is_valid_int():
				decor.set_cell(cell, 0, _tile(theme.sign))
				var i = int(c) - 1
				if i >= 0 and i < texts.size():
					var l = Game.label(texts[i], 8, Color(1, 1, 1))
					l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
					l.autowrap_mode = TextServer.AUTOWRAP_WORD
					l.size = Vector2(120, 10)
					l.position = center + Vector2(-60, -44)
					l.z_index = -1
					add_child(l)
			else:
				push_warning("Unknown level character '%s' at %d,%d" % [c, x, y])


func _block(kind, pos):
	var b = Block.new()
	b.kind = kind
	b.atlas_coords = theme.question
	b.position = pos
	add_child(b)


func _add(node, pos):
	node.position = pos
	add_child(node)


func _hazard(kind, pos):
	var h = Hazard.new()
	h.kind = kind
	h.position = pos
	add_child(h)


func _enemy(kind, feet, elite = false):
	var e = Enemy.new()
	e.kind = kind
	e.elite = elite
	if kind in ["bat", "bomber", "ghost"]:
		feet.y -= 40.0
	e.position = feet - Vector2(0, 16 * Enemy.SCALES.get(kind, 1.0) * (1.3 if elite else 1.0))
	add_child(e)
	return e


## Ground cells an enemy can stand on: [Vector2i(x, y of the ground tile)].
func _spots(x0, x1):
	var out = []
	for y in range(4, ROWS):
		for x in range(max(x0, 1), min(x1, width - 1)):
			if not rows[y][x] in "#X":
				continue
			if _at(x, y - 1) != "." or _at(x, y - 2) != "." or _at(x, y - 3) != ".":
				continue
			if not _at(x - 1, y) in "#X" or not _at(x + 1, y) in "#X":
				continue
			out.append(Vector2i(x, y))
	return out


## Extra enemies sprinkled over the stage: the deeper the run, the more of them.
func _random_spawns(def):
	var count = def.get("extra", 0)
	var roster = def.get("roster", ["pinky"])
	var spots = _spots(16, width - 8)
	for i in count:
		if spots.is_empty():
			return
		var k = spawn_rng.randi() % spots.size()
		var cell = spots[k]
		spots.remove_at(k)
		_enemy(roster[spawn_rng.randi() % roster.size()], Vector2(cell.x * T + 8, cell.y * T), i < def.get("elites", 0))


## Ambush: the next wave drops in when the arena is empty.
func _waves(delta):
	for e in get_tree().get_nodes_in_group("enemies"):
		if not e.dead:
			return
	wave_wait -= delta
	if wave_wait > 0:
		return
	if wave_i >= waves.size():
		waves = []
		Game.banner.emit("")
		complete()
		return
	var spots = _spots(2, width - 2)
	for kind in waves[wave_i]:
		for attempt in 12:
			var cell = spots[spawn_rng.randi() % spots.size()]
			var feet = Vector2(cell.x * T + 8, cell.y * T)
			var far = true
			for p in players:
				if not p.dead and p.global_position.distance_to(feet) < 70:
					far = false
			if far or attempt == 11:
				var e = _enemy(kind, feet)
				Game.ring(e.position, 20.0, Color(1.0, 0.5, 0.5), 0.4)
				break
	wave_i += 1
	wave_wait = 1.2
	Game.sfx("explosion", 1.3, -6.0)
	Game.banner.emit("WAVE %d / %d" % [wave_i, waves.size()])
	get_tree().create_timer(1.3, false).timeout.connect(func(): Game.banner.emit(""))
A
rep($a, <<'A', <<'B');
func _process(delta):
	super(delta)
	if camera:
A
func _process(delta):
	super(delta)
	if not waves.is_empty() and not finished and not Game.busy:
		_waves(delta)
	if camera:


func _platform(pos, travel):
	var p = MovingPlatform.new()
	p.position = pos
	p.travel = travel
	p.style_row = theme.platform
	p.phase = 0.5 * (platform_count % 2)
	platform_count += 1
	add_child(p)


# ---------------------------------------------------------------- scenery

func _background():
	var layer = CanvasLayer.new()
	layer.layer = -10
	add_child(layer)
	var sky = Game.sky(theme.sky[0], theme.sky[1])
	layer.add_child(sky)
	sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if theme.get("sun", false):
		var sun = Sun.new()
		layer.add_child(sun)
		sun.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if theme.get("stars", false):
		var stars = Stars.new()
		layer.add_child(stars)
		stars.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var base = ROWS * T
	if theme.clouds != null:
		var rng = RandomNumberGenerator.new()
		rng.seed = 7
		var clouds = _parallax(0.15, -22)
		for i in int(width * T * 0.15 / 96.0) + 12:
			var p = Vector2(-400 + i * 96 + rng.randf_range(0, 40), rng.randf_range(10, 120))
			var s = rng.randf_range(0.7, 1.3)
			for blob in [[Vector2(0, 0), 16, 7], [Vector2(-12, 3), 10, 5], [Vector2(13, 3), 11, 5], [Vector2(3, -5), 9, 6]]:
				clouds.add_child(_ellipse(p + blob[0] * s, blob[1] * s, blob[2] * s, theme.clouds))
	for spec in [[0.3, -21, base - 70, 26, 2, theme.far], [0.5, -20, base - 30, 18, 3, theme.hills]]:
		var layer_node = _parallax(spec[0], spec[1])
		for i in int(width * T * spec[0] / 320.0) + 5:
			var hills = _hills(spec[2], spec[3], spec[4], spec[5])
			hills.position.x = (i - 2) * 320
			layer_node.add_child(hills)


## A scenery layer that scrolls at `factor` times the camera speed (see _process).
func _parallax(factor, z):
	var n = Node2D.new()
	n.z_index = z
	add_child(n)
	scenery.append([n, factor])
	return n


func _process(delta):
	super(delta)
	if camera:
		var cx = camera.get_screen_center_position().x
		for s in scenery:
			s[0].position.x = cx * (1.0 - s[1])


func _ellipse(center, rx, ry, color):
	var poly = Polygon2D.new()
	var pts = PackedVector2Array()
	for i in 14:
		var a = TAU * i / 14.0
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	poly.polygon = pts
	poly.color = color
	return poly


func _hills(y, amp, waves, color):
	var poly = Polygon2D.new()
	var pts = PackedVector2Array()
	for i in 41:
		var x = i * 8.0
		var k = x / 320.0 * TAU
		pts.append(Vector2(x, y - amp - sin(k * waves) * amp - sin(k * (waves + 2) + 1.3) * amp * 0.35))
	pts.append(Vector2(320, y + 400))
	pts.append(Vector2(0, y + 400))
	poly.polygon = pts
	poly.color = color
	return poly


## Dark fill behind the ground so the scenery doesn't peek through the rounded tile corners.
class Backing extends Node2D:
	var cells = []

	func _draw():
		for c in cells:
			var inset = 3 if c[1] else 0
			draw_rect(Rect2(c[0].x * 16, c[0].y * 16 + inset, 16, 16 - inset), Color(0.13, 0.09, 0.13))


## Twinkling stars on the sky layer (night / space themes).
class Stars extends Control:
	var t = 0.0

	func _ready():
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta):
		t += delta
		queue_redraw()

	func _draw():
		var rng = RandomNumberGenerator.new()
		rng.seed = 42
		for i in 90:
			var p = Vector2(rng.randf() * size.x, rng.randf() * size.y * 0.8)
			var a = 0.45 + 0.4 * sin(t * (0.8 + rng.randf() * 2.0) + i)
			draw_rect(Rect2(p, Vector2(2, 2) if i % 7 == 0 else Vector2(1.5, 1.5)), Color(1, 1, 0.9, a))


## A big low sun for the Tunisian themes.
class Sun extends Control:
	func _ready():
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw():
		var c = Vector2(size.x * 0.78, size.y * 0.3)
		draw_circle(c, 78, Color(1.0, 1.0, 0.8, 0.18))
		draw_circle(c, 56, Color(1.0, 0.97, 0.75, 0.9))
