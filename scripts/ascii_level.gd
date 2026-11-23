extends "res://scripts/level.gd"
## Builds a whole stage from text chunks (legend in level_data.gd).
##
## A stage is a list of ZONES stacked on top of each other in one big grid: roads that run
## to the right or to the left, and towers you climb up or down. The end of every zone is a
## PORTAL to the start of the next one, which also becomes the checkpoint. The camera and
## the death line follow the zone the team is in. The last zone ends with the goal flag
## (or a boss, or an ambush).
##
## It also dresses the world: layered animated backgrounds, weather, swaying grass, torches;
## hands the HUD a minimap; and runs chests and their little minigames (see events.gd).

const TILESET_TEX = preload("res://assets/sprites/world_tileset.png")
const CoinScene = preload("res://scenes/coin.tscn")
const Enemy = preload("res://scripts/enemy.gd")
const Block = preload("res://scripts/block.gd")
const Hazard = preload("res://scripts/hazard.gd")
const MovingPlatform = preload("res://scripts/moving_platform.gd")
const Spring = preload("res://scripts/spring.gd")
const ManaOrb = preload("res://scripts/mana_orb.gd")
const Crumble = preload("res://scripts/crumble.gd")
const Portal = preload("res://scripts/portal.gd")
const Chest = preload("res://scripts/chest.gd")
const Door = preload("res://scripts/door.gd")
const Ghoul = preload("res://scripts/ghoul.gd")
const Pickup = preload("res://scripts/pickup.gd")
const Scenery = preload("res://scripts/scenery.gd")

const ROWS = 14        # height of a road chunk
const T = 16
const ZONE_GAP = 10    # empty rows between two zones

const TILES = {
	"green": {"top": Vector2i(0, 0), "fill": Vector2i(0, 1), "brick_top": Vector2i(1, 0), "brick": Vector2i(1, 1),
		"question": Vector2i(0, 2), "tree": [Vector2i(0, 5), Vector2i(0, 4), Vector2i(0, 3)],
		"bush": Vector2i(1, 5), "mushroom": Vector2i(7, 5), "bridge": 0, "platform": 0},
	"orange": {"top": Vector2i(4, 0), "fill": Vector2i(4, 1), "brick_top": Vector2i(5, 0), "brick": Vector2i(5, 1),
		"question": Vector2i(4, 2), "tree": [Vector2i(5, 5), Vector2i(5, 4), Vector2i(5, 3)],
		"bush": Vector2i(5, 7), "mushroom": Vector2i(7, 6), "bridge": 2, "platform": 2},
	"ice": {"top": Vector2i(7, 0), "fill": Vector2i(6, 2), "brick_top": Vector2i(8, 0), "brick": Vector2i(8, 1),
		"question": Vector2i(7, 2), "tree": [Vector2i(6, 5), Vector2i(6, 4), Vector2i(6, 3)],
		"bush": Vector2i(6, 7), "mushroom": Vector2i(7, 8), "bridge": 1, "platform": 3},
	"stone": {"top": Vector2i(8, 0), "fill": Vector2i(8, 1), "brick_top": Vector2i(6, 1), "brick": Vector2i(6, 1),
		"question": Vector2i(7, 2), "tree": [Vector2i(7, 7), Vector2i(7, 7), Vector2i(7, 7)],
		"bush": Vector2i(8, 7), "mushroom": Vector2i(7, 7), "bridge": 2, "platform": 1},
}

# tiles, sky (top, bottom), far / near silhouette colours, and what lives in the air.
var THEMES = {
	"grass": {"tiles": "green", "sky": [Color(0.25, 0.55, 0.92), Color(0.8, 0.93, 1.0)], "far": Color(0.55, 0.8, 0.78), "near": Color(0.36, 0.68, 0.5),
		"skyline": "trees", "clouds": Color(1, 1, 1, 0.9), "sun": true, "rays": true, "air": "pollen", "grass": Color(0.35, 0.8, 0.3), "plank": Color(0.72, 0.5, 0.3)},
	"autumn": {"tiles": "orange", "sky": [Color(0.93, 0.45, 0.4), Color(1.0, 0.85, 0.6)], "far": Color(0.93, 0.6, 0.48), "near": Color(0.74, 0.38, 0.4),
		"skyline": "trees", "clouds": Color(1, 0.93, 0.85, 0.85), "sun": true, "air": "leaves", "grass": Color(0.9, 0.6, 0.2), "plank": Color(0.72, 0.5, 0.3)},
	"medina": {"tiles": "ice", "sky": [Color(0.08, 0.38, 0.9), Color(0.6, 0.85, 1.0)], "far": Color(0.3, 0.58, 0.95), "near": Color(0.97, 0.97, 1.0),
		"skyline": "medina", "clouds": Color(1, 1, 1, 0.9), "sun": true, "rays": true, "air": "petals", "grass": Color(0.95, 0.4, 0.6), "plank": Color(0.2, 0.45, 0.9)},
	"swamp": {"tiles": "green", "sky": [Color(0.14, 0.24, 0.22), Color(0.48, 0.6, 0.4)], "tint": Color(0.72, 0.9, 0.68), "far": Color(0.28, 0.44, 0.33), "near": Color(0.18, 0.33, 0.24),
		"skyline": "dead_trees", "clouds": Color(0.8, 0.9, 0.7, 0.3), "rays": true, "air": "fireflies", "grass": Color(0.3, 0.6, 0.3), "plank": Color(0.5, 0.55, 0.3)},
	"ocean": {"tiles": "orange", "sky": [Color(0.16, 0.62, 0.86), Color(0.02, 0.14, 0.4)], "tint": Color(0.8, 0.95, 1.0), "far": Color(0.07, 0.36, 0.62), "near": Color(0.04, 0.26, 0.5),
		"skyline": "reef", "rays": true, "air": "bubbles", "weeds": true, "plank": Color(0.6, 0.8, 0.9)},
	"sahara": {"tiles": "orange", "sky": [Color(1.0, 0.6, 0.28), Color(1.0, 0.92, 0.65)], "tint": Color(1.0, 0.9, 0.62), "far": Color(0.98, 0.83, 0.52), "near": Color(0.92, 0.7, 0.38),
		"skyline": "dunes", "sun": true, "air": "sand", "grass": Color(0.8, 0.7, 0.3), "plank": Color(0.85, 0.65, 0.35)},
	"night": {"tiles": "green", "sky": [Color(0.03, 0.04, 0.15), Color(0.15, 0.2, 0.45)], "tint": Color(0.62, 0.68, 0.95), "far": Color(0.12, 0.19, 0.4), "near": Color(0.08, 0.13, 0.28),
		"skyline": "pines", "clouds": Color(0.6, 0.65, 0.9, 0.22), "stars": true, "moon": true, "air": "fireflies", "grass": Color(0.25, 0.45, 0.6), "plank": Color(0.45, 0.4, 0.6)},
	"ice": {"tiles": "ice", "sky": [Color(0.38, 0.52, 0.85), Color(0.86, 0.94, 1.0)], "far": Color(0.68, 0.8, 0.95), "near": Color(0.85, 0.92, 1.0),
		"skyline": "peaks", "clouds": Color(1, 1, 1, 0.9), "air": "snow", "plank": Color(0.75, 0.85, 1.0)},
	"sky": {"tiles": "ice", "sky": [Color(0.22, 0.48, 0.95), Color(1.0, 0.85, 0.8)], "far": Color(1.0, 0.92, 0.95, 0.6), "near": Color(1.0, 1.0, 1.0, 0.8),
		"skyline": "islands", "clouds": Color(1, 1, 1, 0.95), "sun": true, "rays": true, "air": "pollen", "plank": Color(0.95, 0.95, 1.0)},
	"cave": {"tiles": "stone", "sky": [Color(0.04, 0.03, 0.12), Color(0.16, 0.1, 0.32)], "tint": Color(0.8, 0.75, 1.0), "far": Color(0.1, 0.07, 0.22), "near": Color(0.14, 0.1, 0.28),
		"skyline": "crystals", "rays": true, "air": "dust", "torch": true, "plank": Color(0.5, 0.45, 0.75)},
	"space": {"tiles": "stone", "sky": [Color(0.01, 0.01, 0.05), Color(0.12, 0.05, 0.25)], "tint": Color(0.75, 0.85, 1.0), "far": Color(0.12, 0.12, 0.22), "near": Color(0.2, 0.2, 0.32),
		"skyline": "planets", "stars": true, "air": "stardust", "plank": Color(0.5, 0.8, 1.0)},
	"castle": {"tiles": "stone", "sky": [Color(0.06, 0.04, 0.11), Color(0.32, 0.1, 0.12)], "far": Color(0.13, 0.08, 0.15), "near": Color(0.18, 0.11, 0.18),
		"skyline": "castle", "air": "embers", "torch": true, "plank": Color(0.5, 0.35, 0.3)},
}

var theme
var tiles
var rows = []          # the whole world, one string per row of tiles
var width = 0
var zones = []         # {y0, w, h, dir, entry, rect}
var zone_i = 0
var tileset: TileSet
var source: TileSetAtlasSource
var ground: TileMapLayer
var decor: TileMapLayer
var platform_count = 0
var scenery
var waves = []         # ambush stages: lists of enemy kinds
var wave_i = 0
var wave_wait = 2.0
var spawn_rng = RandomNumberGenerator.new()
var minimap: ImageTexture
var portals = []       # world positions, for the minimap
var goal_pos = null
var stalker_t = -1.0   # seconds until THE SHADOW shows up (-1: not in this stage)
var chests_left = 0    # unopened chests
var events = 0         # chest minigames still running
var boss_down = false
var boss_timer = 0.0


func build():
	var def = Game.level_def()
	if not def.has("chunks") and not def.has("zones"):
		def = Game.RunGen.make_stage(0, 0, "fight", randi(), 0)
		Game.stage = def
	theme = THEMES[def.get("theme", "grass")]
	tiles = TILES[theme.tiles]
	time_limit = def.get("time", 300)
	slip = def.get("slip", 1.0)
	grav = def.get("gravity", 1.0)
	water = def.get("water", false)
	scroll = def.get("scroll", 0.0)
	waves = def.get("waves", [])
	spawn_rng.seed = def.get("seed", 1) + 99
	if def.get("kind", "") in ["fight", "elite"] and (Game.act >= Game.ACTS.size() - 1 or randf() < 0.4):
		stalker_t = randf_range(14.0, 30.0)
	_make_world(def)

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
	var tops = []
	for y in rows.size():
		for x in width:
			var c = rows[y][x]
			if c == "#" or c == "X":
				backing.cells.append([Vector2i(x, y), _at(x, y - 1) != c])
				if c == "#" and _at(x, y - 1) in ".ob*":
					tops.append(Vector2i(x, y))
			_spawn(c, x, y)

	# Invisible walls at both ends of every zone, and a lid a few tiles above it.
	# They must stay inside the zone's own rows plus half of the gap above it: zones are
	# stacked and have different widths, so anything taller pokes into the neighbouring
	# zone as an invisible block you bump into or stand on.
	var walls = StaticBody2D.new()
	var lid = ZONE_GAP / 2
	for z in zones:
		var top = (z.y0 - lid) * T
		var bottom = (z.y0 + z.h) * T
		for wx in [-8.0, z.w * T + 8.0]:
			var c = CollisionShape2D.new()
			var r = RectangleShape2D.new()
			r.size = Vector2(16, bottom - top)
			c.shape = r
			c.position = Vector2(wx, (top + bottom) * 0.5)
			walls.add_child(c)
		# the lid: no flying, swimming or jetpacking out of the top of a zone
		var cap = CollisionShape2D.new()
		var cr = RectangleShape2D.new()
		cr.size = Vector2(z.w * T + 32, 16)
		cap.shape = cr
		cap.position = Vector2(z.w * T * 0.5, top - 8)
		walls.add_child(cap)
	add_child(walls)

	_random_spawns(def)
	_make_minimap()
	scenery = Scenery.new()
	add_child(scenery)
	scenery.setup(self, theme, tops)

	# start in the zone of the last checkpoint
	zone_i = 0
	if Game.checkpoint != null:
		for i in zones.size():
			if zones[i].rect.has_point(Game.checkpoint):
				zone_i = i
	_apply_zone()


# ---------------------------------------------------------------- the world grid

## Glue chunks together left to right into ROWS strings of equal length.
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
			out[y] += line.rpad(w, ".")
	return out


static func mirror(grid):
	var out = []
	for line in grid:
		var s = ""
		for i in range(line.length() - 1, -1, -1):
			s += line[i]
		out.append(s)
	return out


func _make_world(def):
	var specs = def.get("zones", [])
	if specs.is_empty():
		specs = [{"type": "road", "dir": 1, "chunks": def.chunks}]
	var grids = []
	width = 0
	for z in specs:
		var g = z.rows if z.type == "tower" else assemble(z.chunks)
		if z.get("dir", 1) < 0:
			g = mirror(g)
		grids.append(g)
		width = max(width, g[0].length())
	rows = []
	zones = []
	for i in grids.size():
		var g = grids[i]
		var zone = {"y0": rows.size(), "w": g[0].length(), "h": g.size(), "dir": specs[i].get("dir", 1), "entry": Vector2.ZERO}
		zone.rect = Rect2(0, zone.y0 * T - 64, zone.w * T, zone.h * T + 64)
		zones.append(zone)
		for line in g:
			rows.append(line.rpad(width, "."))
		if i < grids.size() - 1:
			for k in ZONE_GAP:
				rows.append(".".repeat(width))


func _zone_of(y):
	for i in zones.size():
		if y >= zones[i].y0 and y < zones[i].y0 + zones[i].h:
			return i
	return 0


func _at(x, y):
	if x < 0 or y < 0 or x >= width or y >= rows.size():
		return "."
	return rows[y][x]


## Camera limits and death line of the zone the team is in.
func _apply_zone():
	var z = zones[zone_i]
	limits = z.rect
	kill_y = (z.y0 + z.h) * T + 32
	if camera:
		camera.set_limits(z.rect)


## A portal was entered: the whole team jumps to the start of zone `i`.
func warp(i):
	if finished or i >= zones.size():
		return
	zone_i = i
	_apply_zone()
	var pos = zones[i].entry
	Game.checkpoint = pos
	for p in players:
		if not p.dead:
			p.global_position = pos + Vector2(OFFSETS[p.slot], -2)
			p.velocity = Vector2.ZERO
			p.invuln = max(p.invuln, 1.2)
	Game.flash(Color(0.55, 0.9, 1.0), 0.55, 0.45)
	Game.sfx("power_up", 1.7, -4.0)
	Game.ring(pos + Vector2(0, -12), 40.0, Color(0.55, 0.9, 1.0), 0.5)
	Game.popup("CHECKPOINT!", pos + Vector2(0, -30), Color(0.5, 0.9, 1.0))


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
			ground.set_cell(cell, 0, _tile(tiles.fill if _at(x, y - 1) == "#" else tiles.top, 1))
		"X":
			ground.set_cell(cell, 0, _tile(tiles.brick if _at(x, y - 1) == "X" else tiles.brick_top, 1))
		"=":
			ground.set_cell(cell, 0, _tile(Vector2i(9 + x % 6, tiles.bridge), 2))
		"~":
			decor.set_cell(cell, 0, _tile(Vector2i(4, 14) if _at(x, y - 1) == "~" else Vector2i(4, 13)))
			if _at(x, y - 1) != "~":
				_hazard("lava", center)
		"^":
			_hazard("spike", center)
		"f":
			_hazard("fire", center)
		"o":
			_add(CoinScene.instantiate(), center)
		"?":
			_block(_power_roll("coin", 0.08), center)
		"M":
			_block("multi", center)
		"F":
			_block("fruit", center)
		"R":
			_block(_power_roll("rock", 0.65), center)
		"L":
			_block("life", center)
		"C":
			_block("crate", center)
		"H":
			_platform(center, Vector2(80 * zones[_zone_of(y)].dir, 0))
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
		"p":
			_enemy("pinky", feet)
		"w":
			_enemy("grump", feet)
		"s":
			_enemy("slime", feet)
		"u":
			_enemy("slime_purple", feet)
		"B":
			_enemy("bat", feet + Vector2(0, 40))
		"r":
			_enemy("charger", feet)
		"k":
			_enemy("spiky", feet)
		"Q":
			_enemy("queen", feet)
		"K":
			_enemy("boss", feet)
		"W":
			_enemy("ghoula", feet)
		"U":
			_enemy("puffer_king", feet)
		"P":
			# the way into this zone: where the run starts, or where the portal drops you
			var zi = _zone_of(y)
			zones[zi].entry = feet
			if zi == 0:
				spawn_point = feet
			else:
				var pad = Portal.new()
				pad.target = -1
				_add(pad, feet)
		"G":
			# the way out: a portal to the next zone, or the goal flag at the very end
			var zi = _zone_of(y)
			if zi < zones.size() - 1:
				var portal = Portal.new()
				portal.target = zi + 1
				_add(portal, feet)
				portals.append(feet)
			else:
				add_goal(feet)
				goal_pos = feet
		"T":
			for i in 3:
				decor.set_cell(cell - Vector2i(0, i), 0, _tile(tiles.tree[i]))
		"b":
			decor.set_cell(cell, 0, _tile(tiles.bush))
		"m":
			decor.set_cell(cell, 0, _tile(tiles.mushroom))
		_:
			pass


func _add(node, pos):
	node.position = pos
	add_child(node)
	return node


## Some blocks hide a power-up instead: FIRE flower, ICE crystal or a STAR.
func _power_roll(base, chance):
	if spawn_rng.randf() < chance:
		return Pickup.POWERS[spawn_rng.randi() % Pickup.POWERS.size()]
	return base


func _block(kind, pos):
	var b = Block.new()
	b.kind = kind
	b.atlas_coords = tiles.question
	_add(b, pos)


func _hazard(kind, pos):
	var h = Hazard.new()
	h.kind = kind
	_add(h, pos)


func _enemy(kind, feet, elite = false, captain = false):
	if water:
		# under water the usual suspects are replaced by their cousins from the sea
		kind = {"bat": "fish", "bomber": "piranha", "ghost": "skelefish", "charger": "eel", "hopper": "puffer", "kamikaze": "piranha"}.get(kind, kind)
	var e = Enemy.new()
	e.kind = kind
	e.elite = elite
	e.captain = captain
	if kind in ["bat", "bomber", "ghost", "fish", "piranha", "puffer", "skelefish"]:
		feet.y -= 40.0
	var k = Enemy.SCALES.get(kind, 1.0) * (1.9 if captain else 1.3 if elite else 1.0)
	e.position = feet - Vector2(0, 16 * k)
	add_child(e)
	return e


func _platform(pos, travel):
	var p = MovingPlatform.new()
	p.position = pos
	p.travel = travel
	p.style_row = tiles.platform
	p.phase = 0.5 * (platform_count % 2)
	platform_count += 1
	add_child(p)


# ---------------------------------------------------------------- who lives here

## Ground cells of a zone an enemy can stand on, at least `clear` tiles away from its entry.
func _spots(zi, clear = 0):
	var z = zones[zi]
	var out = []
	for y in range(z.y0 + 3, z.y0 + z.h):
		for x in range(1, z.w - 1):
			if not rows[y][x] in "#X":
				continue
			if _at(x, y - 1) != "." or _at(x, y - 2) != "." or _at(x, y - 3) != ".":
				continue
			if not _at(x - 1, y) in "#X" or not _at(x + 1, y) in "#X":
				continue
			if clear > 0 and Vector2(x * T, y * T).distance_to(z.entry) < clear * T:
				continue
			out.append(Vector2i(x, y))
	return out


## Extra enemies sprinkled over every zone (the deeper the run, the more), and the captain.
func _random_spawns(def):
	var count = int(round(def.get("extra", 0) * Game.mode().crowd))
	var roster = def.get("roster", ["pinky"])
	var elites = def.get("elites", 0)
	var total = 0.0
	for z in zones:
		total += z.w
	for zi in zones.size():
		var spots = _spots(zi, 12)
		var share = int(ceil(count * zones[zi].w / total)) if count > 0 else 0
		for i in share:
			if spots.is_empty():
				break
			var k = spawn_rng.randi() % spots.size()
			var cell = spots[k]
			spots.remove_at(k)
			_enemy(roster[spawn_rng.randi() % roster.size()], Vector2(cell.x * T + 8, cell.y * T), elites > 0)
			elites -= 1
		# a mystery door, about every other zone
		if not def.get("kind", "") in ["boss", "arena"] and not spots.is_empty() and spawn_rng.randf() < 0.55:
			var door = Door.new()
			door.level = self
			var at = spots[spawn_rng.randi() % spots.size()]
			_add(door, Vector2(at.x * T + 8, at.y * T))
	if def.get("captain", false):
		# The mini-boss guards the last stretch. He carries a chest.
		var zi = zones.size() - 1
		var spots = _spots(zi, 20)
		if spots.is_empty():
			spots = _spots(zi, 6)
		if not spots.is_empty():
			var far = spots[0]
			for c in spots:
				if Vector2(c.x * T, c.y * T).distance_to(zones[zi].entry) > Vector2(far.x * T, far.y * T).distance_to(zones[zi].entry) and spawn_rng.randf() < 0.5:
					far = c
			var walkers = roster.filter(func(k): return k in ["pinky", "charger", "shield", "hopper", "grump", "kamikaze", "shaman"])
			var kind = walkers[spawn_rng.randi() % walkers.size()] if not walkers.is_empty() else "pinky"
			_enemy(kind, Vector2(far.x * T + 8, far.y * T), false, true)


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
		spawn_chest(players[0].global_position + Vector2(40, -40))
		boss_down = true
		boss_timer = 12.0
		return
	var spots = _spots(0)
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


# ---------------------------------------------------------------- chests

## Drops a chest that lands on the ground below `pos`.
func spawn_chest(pos):
	var c = Chest.new()
	c.level = self
	c.position = pos
	add_child(c)
	chests_left += 1
	return c


## The boss is dead: five chests rain down. The stage ends when they are all open.
func boss_dead(pos):
	var z = zones[zone_i]
	for i in 5:
		var x = clamp(pos.x + (i - 2) * 44.0, 40.0, z.w * T - 40.0)
		spawn_chest(Vector2(x, pos.y - 90.0 - (i % 2) * 20.0))
	boss_down = true
	boss_timer = 30.0
	Game.banner.emit("OPEN THE CHESTS!")
	get_tree().create_timer(2.0, false).timeout.connect(func(): Game.banner.emit(""))


func _process(delta):
	super(delta)
	if stalker_t > 0 and not finished and not Game.busy:
		stalker_t -= delta
		if stalker_t <= 0:
			var s = Ghoul.new()
			s.level = self
			add_child(s)
			Game.banner.emit("YOU FEEL WATCHED...")
			get_tree().create_timer(2.5, false).timeout.connect(func(): Game.banner.emit(""))
	if not waves.is_empty() and not finished and not Game.busy:
		_waves(delta)
	if boss_down and not finished and not Game.busy:
		boss_timer -= delta
		if (chests_left <= 0 and events <= 0) or boss_timer <= 0:
			complete()


# ---------------------------------------------------------------- minimap

func _make_minimap():
	var img = Image.create(width, rows.size(), false, Image.FORMAT_RGBA8)
	for y in rows.size():
		for x in width:
			var c = rows[y][x]
			if c == "#" or c == "X":
				img.set_pixel(x, y, Color(0.82, 0.85, 0.95, 0.95))
			elif c == "=" or c == "D":
				img.set_pixel(x, y, Color(0.75, 0.55, 0.35, 0.95))
			elif c == "~" or c == "^":
				img.set_pixel(x, y, Color(0.95, 0.3, 0.2, 0.95))
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	minimap = ImageTexture.create_from_image(img)


## Dark fill behind the ground so the scenery doesn't peek through the rounded tile corners.
class Backing extends Node2D:
	var cells = []

	func _draw():
		for c in cells:
			var inset = 3 if c[1] else 0
			draw_rect(Rect2(c[0].x * 16, c[0].y * 16 + inset, 16, 16 - inset), Color(0.13, 0.09, 0.13))
