extends RefCounted
## Generates a run: the branching map of an act and the stages behind its nodes.

const LevelData = preload("res://scripts/level_data.gd")

const MAP_ROWS = 6      # rows of nodes before the boss
const LANES = 3

# Who shows up in each act (random spawns and ambush waves).
const ROSTER = [
	["pinky", "slime", "hopper", "grump", "bat", "spiky", "shield", "slime_purple"],
	["pinky", "hopper", "charger", "bomber", "kamikaze", "splitter", "ghost", "grump", "shield", "spiky"],
	["charger", "kamikaze", "shaman", "sniper", "ghost", "bomber", "shield", "splitter", "slime_purple", "hopper"],
]

const TITLES = {
	"grass": ["PRONTO MEADOWS", "GOAT PASTURE", "THE LONG LAWN"],
	"autumn": ["SUNSET RIDGE", "OLIVE GROVE", "HARVEST ROAD"],
	"medina": ["SIDI BOU ROOFTOPS", "THE BLUE MEDINA", "SOUK ALLEYS"],
	"swamp": ["SLIME MARSH", "THE GREEN BOG"],
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
	_force(rows[1 + rng.randi() % 2], "gallery" if act == 1 or rng.randf() < 0.5 else "sky", rng)
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
	if roll < 0.93:
		return "gallery"
	return "sky" if act != 1 else "gallery"


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
	if theme == "ice":
		stage.slip = 0.3
		stage.notes.append("SLIPPERY!")
	if theme == "space":
		stage.gravity = 0.6
		stage.notes.append("LOW GRAVITY: JUMP HIGH!")

	if type == "boss":
		var kind = Game.ACTS[act].boss
		stage.theme = "swamp" if kind == "queen" else "castle"
		stage.title = "QUEEN SLIME'S SWAMP" if kind == "queen" else "KING PINKY'S THRONE"
		stage.chunks = [LevelData.START, LevelData.BOSS_ARENAS[kind]]
		stage.time = 300
		stage.pay = 40 + 20 * act
		stage.erase("slip")
		stage.erase("gravity")
		stage.notes = ["BOSS!"]
		return stage
	if type == "arena":
		stage.kind = "arena"
		stage.title = "AMBUSH: " + stage.title
		stage.chunks = [LevelData.ARENAS[rng.randi() % LevelData.ARENAS.size()]]
		stage.time = 180
		stage.waves = []
		for w in 3:
			var wave = []
			for i in 3 + act + w + depth / 5:
				wave.append(ROSTER[act][rng.randi() % ROSTER[act].size()])
			stage.waves.append(wave)
		stage.notes.append("SURVIVE 3 WAVES!")
		stage.pay += 4
		return stage

	# fight / elite: a road made of random chunks
	var pool = mids().filter(func(m): return m[0] <= act)
	var count = 3 + act + (1 if rng.randf() < 0.4 else 0)
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
	stage.chunks = chunks
	stage.time = 150 + 35 * count
	stage.extra = 3 + act * 2 + depth / 3
	if type == "elite":
		stage.title = "ELITE PATROL: " + stage.title
		stage.elites = 2 + act
		stage.extra += 1
		stage.pay += 8
		stage.notes.append("ELITE ENEMIES. BETTER REWARD.")
	elif theme != "space" and rng.randf() < 0.22:
		stage.scroll = 26.0 + 3.0 * act
		stage.notes.append("THE SCREEN MOVES ON ITS OWN - KEEP UP!")
	return stage
