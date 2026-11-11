extends Node

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	run()

func wait(t):
	await get_tree().create_timer(t, true, false, true).timeout

func idle():
	await wait(0.3)
	while Game.busy:
		await wait(0.2)
	await wait(0.3)

func scene_name():
	return get_tree().current_scene.scene_file_path.get_file() if get_tree().current_scene else "none"

func check_pools():
	var bad = 0
	var tiers = [0, 0, 0]
	for m in Game.RunGen.mids():
		tiers[m[0]] += 1
	print("mids per tier: ", tiers)
	var known = ".#X=oC?MFRL*HVESD^~psuwBrQKPcGTbmkf"
	for act in 3:
		for i in 60:
			for type in ["fight", "elite", "arena", "boss"]:
				var st = Game.RunGen.make_stage(act, i % 6, type, randi(), i)
				var starts = 0
				var exits = 0
				for chunk in st.chunks:
					var lines = chunk.strip_edges().split("\n")
					if lines.size() != 14:
						bad += 1; print("rows ", lines.size(), " in ", type)
					for y in lines.size():
						if lines[y].length() != lines[0].length():
							bad += 1; print("width in ", type, " row ", y)
						for ch in lines[y]:
							if not known.contains(ch):
								bad += 1; print("unknown ", ch)
							if ch == "P": starts += 1
							if ch in "GKQ": exits += 1
				if starts != 1 or exits != (0 if type == "arena" else 1):
					bad += 1; print("starts/exits ", starts, exits, " ", type)
	for act in 3:
		var map = Game.RunGen.make_map(act, randi())
		for r in map.size() - 1:
			for node in map[r]:
				if node != null and node.links.is_empty():
					bad += 1; print("dead end in map")
	print("POOL CHECK problems: ", bad)

func run():
	await wait(1.0)
	check_pools()
	for s in [Game.TITLE_SCENE, Game.CAMP_SCENE, Game.SELECT_SCENE]:
		Game.goto_scene(s)
		await idle()
		print("scene ok ", scene_name())
	Game.dinars = 0
	Game.meta = {}
	Game.new_game([{"char": 0, "input": "pad2"}, {"char": 1, "input": "pad3"}, {"char": 2, "input": "pad2"}, {"char": 3, "input": "pad3"}])
	await idle()
	# make room for a 5th hero test later; walk the whole run
	var steps = 0
	while steps < 40:
		steps += 1
		var sc = get_tree().current_scene
		var name = scene_name()
		if name == "end_screen.tscn":
			break
		if name != "map.tscn":
			print("UNEXPECTED scene ", name); break
		if not sc.boons.is_empty():
			Game.add_boon(sc.boons[0].id)
			sc.boons = []
			Game.pending = null
		var lane = sc.choices[steps % sc.choices.size()]
		var type = Game.map[Game.map_row + 1][lane].type
		Game.enter_node(lane)
		await idle()
		name = scene_name()
		var info = "act %d row %d %s -> %s" % [Game.act + 1, Game.map_row + 1, type, name]
		match name:
			"tavern.tscn":
				var tv = get_tree().current_scene
				Game.gold += 200
				for i in tv.items.size() - 1:
					if i < tv.items.size() - 1:
						tv.items[i].act.call()
				await wait(0.2)
				tv = get_tree().current_scene
				tv.items[tv.items.size() - 1].act.call()
			"gallery.tscn":
				var g = get_tree().current_scene
				g.score = 30 if steps % 2 == 0 else 3
				g.time_left = 1.0
				await wait(5.0)
			"shmup.tscn":
				var g = get_tree().current_scene
				await wait(3.0)
				g.boss_hp = 1
				g.ships[0].pos = Vector2(200, g.boss_pos.y)
				await wait(5.0)
			"ascii_level.tscn":
				var lv = Game.level_node
				var en = get_tree().get_nodes_in_group("enemies")
				var kinds = {}
				for e in en:
					kinds[e.kind] = kinds.get(e.kind, 0) + 1
				info += "  %s theme=%s width=%d enemies=%s" % [Game.stage.title, Game.stage.theme, lv.width, kinds]
				# heroes act
				for p in lv.players:
					p._throw()
					p._move()
					Game.players[p.slot].mana = 100.0
					p._ultimate()
				Engine.time_scale = 3.0
				await wait(2.0)
				if Game.stage.kind == "arena":
					for round in 40:
						for e in get_tree().get_nodes_in_group("enemies"):
							if not e.dead:
								e.solid = true; e.ward = false; e.invuln = 0
								e.damage(false, 99)
						await wait(0.3)
						if lv.finished:
							break
					info += "  arena finished=%s waves=%d" % [lv.finished, lv.wave_i]
				elif Game.stage.kind == "boss":
					var boss = null
					for e in get_tree().get_nodes_in_group("enemies"):
						if e.is_boss:
							boss = e
					for p in lv.players:
						p.global_position = boss.global_position + Vector2(-120, 16 * boss.scale.y - 2)
						p.shield = 9999.0
					await wait(4.0)
					info += "  boss state=%s hp=%d" % [boss.state, boss.hp]
					boss.invuln = 0; boss.hp = 1; boss.stun = 0
					boss.damage(false, 1)
					await wait(1.5)
				else:
					await wait(1.5)
					for p in lv.players:
						p.shield = 0
					lv.complete()
				Engine.time_scale = 1.0
				await wait(1.0)
		print(info)
		await idle()
		await wait(4.5)
		await idle()
	print("RUN END scene=%s mode=%s depth=%d act=%d earned=%d dinars=%d boons=%s" % [scene_name(), Game.end_mode, Game.depth, Game.act, Game.earned, Game.dinars, Game.upgrades])

	# every enemy kind + 5th hero, in one stage
	Game.dinars = 500
	Game.goto_scene(Game.CAMP_SCENE)
	await idle()
	var camp = get_tree().current_scene
	for i in Game.META.size():
		camp._on_chosen(i)
	print("camp: meta=", Game.meta, " dinars=", Game.dinars)
	Game.new_game([{"char": 4, "input": "pad2"}, {"char": 1, "input": "pad3"}])
	await idle()
	Game.act = 2
	Game.depth = 9
	Game._new_map()
	Game.goto_scene(Game.MAP_SCENE)
	await idle()
	var sc2 = get_tree().current_scene
	Game.map[0][sc2.choices[0]].type = "fight"
	Game.enter_node(sc2.choices[0])
	await idle()
	var lv2 = Game.level_node
	var Enemy = load("res://scripts/enemy.gd")
	var x = 60
	for kind in Enemy.GOLD.keys():
		if kind in ["queen", "boss"]:
			continue
		lv2._enemy(kind, Vector2(lv2.players[0].global_position.x + x, 192), x % 80 == 0)
		x += 20
	for p in lv2.players:
		p.shield = 0
	Engine.time_scale = 3.0
	for round in 14:
		await wait(0.5)
		for p in lv2.players:
			if not p.dead:
				p._throw()
				if round == 4:
					p.dash_cd = 0; p._move()
					Game.players[p.slot].mana = 100.0; p._ultimate()
	Engine.time_scale = 1.0
	var left = {}
	for e in get_tree().get_nodes_in_group("enemies"):
		if not e.dead:
			left[e.kind] = left.get(e.kind, 0) + 1
	var st = ""
	for p in lv2.players:
		st += "%s dead=%s hp=%d rage=%.1f | " % [p.ch.name, p.dead, Game.players[p.slot].hearts, p.rage]
	print("zoo: ", st, " alive enemies: ", left, " kills=", Game.kills)
	await idle()
	print("TEST DONE")
	get_tree().quit()
