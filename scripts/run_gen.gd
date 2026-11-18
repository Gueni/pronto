extends RefCounted
## Generates a run: the branching map of an act and the stages behind its nodes.

const LevelData = preload("res://scripts/level_data.gd")

const MAP_ROWS = 8      # rows of nodes before the boss
const LANES = 3

# Who shows up in each act (random spawns and ambush waves).
const ROSTER = [
	["pinky", "slime", "hopper", "grump", "bat", "spiky", "shield", "slime_purple"],
	["fish", "fish", "fish", "piranha", "skelefish", "puffer", "puffer", "eel", "grump", "pinky", "spiky"],
	["pinky", "hopper", "charger", "bomber", "kamikaze", "splitter", "ghost", "grump", "shield", "spiky"],
	["charger", "kamikaze", "shaman", "sniper", "ghost", "bomber", "shield", "splitter", "slime_purple", "hopper"],
	["ghost", "ghost", "shaman", "sniper", "kamikaze", "charger", "bomber", "bat", "shield", "spiky", "splitter"],
]

const TITLES = {
	"grass": ["PRONTO MEADOWS", "GOAT PASTURE", "THE LONG LAWN"],
	"autumn": ["SUNSET RIDGE", "OLIVE GROVE", "HARVEST ROAD"],
	"medina": ["SIDI BOU ROOFTOPS", "THE BLUE MEDINA", "SOUK ALLEYS"],
	"swamp": ["SLIME MARSH", "THE GREEN BOG"],
	"ocean": ["THE SUNKEN MEDINA", "CORAL GARDENS", "KERKENNAH DEEP", "THE BLUE HOLE"],
	"sahara": ["DUNES OF DOUZ", "THE GREAT ERG", "CAMEL ROAD"],
	"night": ["MOONLIT WOODS", "MIDNIGHT OASIS"],
	"ice": ["FROSTY PEAKS", "CHAAMBI SUMMIT"],
	"sky": ["SKY HIGH", "ABOVE THE CLOUDS"],
	"cave": ["CRYSTAL CAVERN", "MATMATA DEPTHS"],
	"space": ["STARLIGHT ROAD", "LOW ORBIT"],
	"castle": ["THE KEEP", "PINKY'S DUNGEON", "LAVA HALLS"],
}

static var _mids = null   # [[tier, lines]] cache


## rows[row][lane] = node or null. A node links to lanes of the next row.
static func make_map(act, map_seed):
	var rng = RandomNumberGenerator.new()
	rng.seed = map_seed
	var rows = []
	for r in MAP_ROWS:
		var row = []
		var missing = -1
		if r > 0 and r < MAP_ROWS - 1 and rng.randf() < 0.6:
			missing = rng.randi() % LANES
		for lane in LANES:
			if lane == missing:
				row.append(null)
				continue
			row.append({"type": _node_type(act, r, rng), "lane": lane, "links": [], "seed": rng.randi()})
		rows.append(row)
	# guaranteed stops: a tavern in the middle, a minigame early on
	_force(rows[3], "tavern", rng)
	_force(rows[1 + rng.randi() % 2], "gallery" if Game.ACTS[act].boss == "sky" or rng.randf() < 0.5 else "sky", rng)
	var boss_type = "boss_sky" if Game.ACTS[act].boss == "sky" else "boss"
	rows.append([null, {"type": boss_type, "lane": 1, "links": [], "seed": rng.randi()}, null])
	for r in rows.size() - 1:
		for node in rows[r]:
			if node == null:
				continue
			for lane in LANES:
				if rows[r + 1][lane] != null and (abs(lane - node.lane) <= 1 or r == rows.size() - 2):
					node.links.append(lane)
	return rows


static func _force(row, type, rng):
	var nodes = row.filter(func(n): return n != null)
	nodes[rng.randi() % nodes.size()].type = type


static func _node_type(act, r, rng):
	if r == 0:
		return "fight"
	if r == MAP_ROWS - 1:
		return "tavern"
	var roll = rng.randf()
	if roll < 0.46:
		return "fight"
	if roll < 0.68:
		return "arena"
	if roll < 0.84:
		return "elite" if r >= 2 else "fight"
	if roll < 0.89:
		return "gallery"
	if roll < 0.95:
		return "event"
	return "sky" if Game.ACTS[act].boss != "sky" else "gallery"


## Every reusable middle chunk, cleaned up: no start, goal, checkpoint, signs or ceilings.
static func mids():
	if _mids != null:
		return _mids
	_mids = []
	for li in LevelData.LEVELS.size():
		var tier = 0 if li <= 3 else (1 if li <= 6 else 2)
		for chunk in LevelData.LEVELS[li].chunks:
			_add_mid(tier, chunk)
	for entry in LevelData.NEW_MIDS:
		_add_mid(entry[0], entry[1])
	return _mids


static func _add_mid(tier, chunk):
	var lines = []
	for line in chunk.strip_edges().split("\n"):
		lines.append(line.strip_edges())
	if lines.size() != 14 or lines[0].length() != 24:
		return
	for y in 14:
		var out = ""
		for ch in lines[y]:
			out += "." if (ch == "c" or ch.is_valid_int()) else ch
		lines[y] = out
	var text = "\n".join(lines)
	if text.contains("P") or text.contains("G") or text.contains("K") or text.contains("Q"):
		return
	# ceilings only make sense in a whole cave level
	for y in 2:
		if lines[y] == "X".repeat(24):
			lines[y] = ".".repeat(24)
	# must be enterable and leavable at ground level
	if not (lines[12].begins_with("###") and lines[12].ends_with("###")):
		return
	for y in range(8, 12):
		if not lines[y][0] in ".ob" or not lines[y][23] in ".ob":
			return
	_mids.append([tier, "\n".join(lines)])


static func make_stage(act, row, type, stage_seed, depth):
	var rng = RandomNumberGenerator.new()
	rng.seed = stage_seed
	var themes = Game.ACTS[act].themes
	var theme = themes[rng.randi() % themes.size()]
	var stage = {
		"name": "%d-%d" % [act + 1, row + 1], "kind": type, "theme": theme, "seed": stage_seed,
		"roster": ROSTER[act], "notes": [], "extra": 0, "elites": 0, "pay": 8 + 3 * act,
	}
	var names = TITLES.get(theme, ["SOMEWHERE"])
	stage.title = names[rng.randi() % names.size()]
	if theme == "ocean":
		stage.water = true
		stage.notes.append("UNDER WATER: JUMP TO SWIM!")
	if theme == "ice":
		stage.slip = 0.3
		stage.notes.append("SLIPPERY!")
	if theme == "space":
		stage.gravity = 0.6
		stage.notes.append("LOW GRAVITY: JUMP HIGH!")

	if type == "boss":
		var kind = Game.ACTS[act].boss
		var arena = LevelData.BOSS_ARENAS.get(kind, LevelData.BOSS_ARENAS["boss"])
		if kind == "ghoula":
			arena = arena.replace("K", "W")
		elif kind == "puffer_king":
			arena = arena.replace("K", "U")
		stage.theme = {"queen": "swamp", "ghoula": "night", "puffer_king": "ocean"}.get(kind, "castle")
		stage.title = {"queen": "MAMA REX'S NEST", "ghoula": "THE GHOULA'S LAIR", "puffer_king": "SIDI PUFFER'S REEF"}.get(kind, "KING PINKY'S THRONE")
		stage.chunks = [LevelData.START, arena]
		stage.time = 300
		stage.pay = 40 + 20 * act
		stage.erase("slip")
		stage.erase("gravity")
		stage.notes = ["BOSS!"]
		if stage.theme != "ocean":
			stage.erase("water")
		return stage
	if type == "arena":
		stage.kind = "arena"
		stage.title = "AMBUSH: " + stage.title
		stage.chunks = [LevelData.ARENAS[rng.randi() % LevelData.ARENAS.size()]]
		stage.time = 180
		stage.waves = []
		for w in 3:
			var wave = []
			for i in 4 + act + w + depth / 4:
				wave.append(ROSTER[act][rng.randi() % ROSTER[act].size()])
			stage.waves.append(wave)
		stage.notes.append("SURVIVE 3 WAVES!")
		stage.pay += 4
		return stage

	# fight / elite: zones stacked on top of each other and linked by portals:
	# roads to the right, roads to the left, towers to climb or to descend.
	var count = 3 + act + (1 if rng.randf() < 0.4 else 0)
	stage.extra = 5 + act * 2 + depth / 3
	stage.captain = type == "elite" or rng.randf() < 0.35
	if type == "elite":
		stage.title = "ELITE PATROL: " + stage.title
		stage.elites = 3 + act
		stage.extra += 1
		stage.pay += 8
		stage.notes.append("ELITE ENEMIES. BETTER REWARD.")
	elif theme != "space" and rng.randf() < 0.16:
		# one long road and a screen that will not wait
		stage.scroll = 26.0 + 3.0 * act
		stage.zones = [_road(rng, act, 1, count)]
		stage.time = 150 + 35 * count
		stage.notes.append("THE SCREEN MOVES ON ITS OWN - KEEP UP!")
		return stage
	var first = max(1, count / 2)
	var floors = 4 + rng.randi() % 3
	match rng.randi() % 5:
		0:
			stage.zones = [_road(rng, act, 1, first), _road(rng, act, -1, count - first)]
		1:
			stage.zones = [_road(rng, act, 1, first), tower(true, floors), _road(rng, act, -1, max(count - first, 1))]
		2:
			stage.zones = [tower(false, floors), _road(rng, act, 1, count - 1)]
		3:
			stage.zones = [_road(rng, act, 1, first), tower(false, floors), _road(rng, act, 1, max(count - first, 1))]
		_:
			stage.zones = [_road(rng, act, -1, first), tower(true, floors), _road(rng, act, 1, max(count - first, 1))]
	stage.time = 170 + 35 * count + 25 * stage.zones.size()
	if stage.captain:
		stage.notes.append("A CAPTAIN GUARDS THE END. HE CARRIES A CHEST.")
	return stage


## A road zone: START + `count` random chunks + END. dir -1 = built mirrored, walked right to left.
static func _road(rng, act, dir, count):
	var pool = mids().filter(func(m): return m[0] <= act)
	var chunks = [LevelData.START]
	var last = -1
	for i in count:
		var pick = -1
		for attempt in 8:
			pick = rng.randi() % pool.size()
			# prefer the act's own difficulty, never the same chunk twice in a row
			if pick != last and (pool[pick][0] == act or rng.randf() < 0.45):
				break
		last = pick
		chunks.append(pool[pick][1])
	chunks.append(LevelData.END)
	return {"type": "road", "dir": dir, "chunks": chunks}


## A tower zone: floors with a gap on alternating sides. Springs throw you up through the gaps.
## up = enter at the bottom and leave at the top; otherwise the other way round.
static func tower(up, floors):
	var w = 24
	var h = floors * 4 + 6
	var grid = []
	for y in h:
		grid.append("X" + ".".repeat(w - 2) + "X")
	grid[h - 1] = "#".repeat(w)
	grid[h - 2] = "#".repeat(w)
	for k in range(1, floors + 1):
		var y = h - 2 - 4 * k
		var left = k % 2 == 1
		var gap = 2 if left else w - 7
		var line = "X"
		for x in range(1, w - 1):
			line += "." if (x >= gap and x < gap + 5) else "#"
		grid[y] = line + "X"
		# a spring right under the gap, on the floor below, and a few coins to mark the way
		var below = y + 3 if k > 1 else h - 3
		grid[below] = _put(grid[below], gap + 2, "S")
		grid[y - 1] = _put(grid[y - 1], gap + 2, "o")
		grid[y + 1] = _put(grid[y + 1], w - 1 - (gap + 2), "o")
	var top = h - 3 - 4 * floors
	var top_x = 12 if floors % 2 == 1 else 10
	grid[top] = _put(grid[top], top_x, "G" if up else "P")
	grid[h - 3] = _put(grid[h - 3], 20 if not up else 12, "P" if up else "G")
	return {"type": "tower", "dir": 1, "rows": grid}


static func _put(line, x, ch):
	return line.substr(0, x) + ch + line.substr(x + 1)
