extends Node
## Drives one scripted scene for README GIFs. Run with Godot's movie writer:
##   godot --path . --write-movie out/f.png --fixed-fps 30 res://tools_tmp/capture.tscn -- shot=level

var shot = "title"
var length = 8.0


func _ready():
	if get_tree().current_scene == self:   # survive scene changes: re-launch as a root sibling
		get_tree().root.add_child.call_deferred(get_script().new())
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("shot="):
			shot = a.substr(5)
		elif a.begins_with("len="):
			length = float(a.substr(4))
	seed(hash(shot) + 7)
	Game.settings.mode = 1
	Game.settings.res = 1
	Game.settings.music = 0
	Game.settings.sfx = 0
	Game.apply_settings()
	Game.saved_run = null
	Game.difficulty = 0
	run()


func wait(t):
	await get_tree().create_timer(t, true, false, true).timeout


var held = {}


func send(action, on):
	var e = InputEventAction.new()
	e.action = action
	e.pressed = on
	e.strength = 1.0 if on else 0.0
	Input.parse_input_event(e)


func tap(action, t = 0.1):
	send(action, true)
	await wait(t)
	send(action, false)
	held.erase(action)


func hold(action, on):
	if held.get(action, false) == on:
		return
	held[action] = on
	send(action, on)


func idle():
	await wait(0.2)
	while Game.busy:
		await wait(0.1)


func team(list):
	Game.new_game(list)
	await idle()


func shield():
	if Game.level_node:
		for p in Game.level_node.players:
			p.shield = 9999.0


func play_stage(type, act = 0):
	Game.act = act
	Game._new_map()
	Game.map_row = 0
	Game.stage = Game.RunGen.make_stage(act, 1, type, randi(), 3)
	Game.start_level()
	await wait(0.3)
	await idle()


func run():
	await wait(0.5)
	match shot:
		"title":
			Game.goto_scene(Game.TITLE_SCENE)
			await idle()
			await wait(1.5)
			for i in 2:
				tap("m_down"); await wait(0.7)
			tap("m_up"); await wait(0.7)
			tap("m_up"); await wait(0.6)
			tap("m_ok"); await wait(0.9)
			tap("m_down"); await wait(0.7)
			tap("m_down"); await wait(0.7)
			tap("m_up"); await wait(1.2)
		"select":
			Game.goto_scene(Game.SELECT_SCENE)
			await idle()
			await wait(0.8)
			for d in ["kl", "kr", "pad0", "pad1"]:
				tap(d + "_jump"); await wait(0.35)
			for step in [["kr", 1], ["pad0", 1], ["pad1", 1], ["kr", 1], ["pad0", 1], ["pad1", -1], ["kl", -1]]:
				tap(step[0] + ("_right" if step[1] > 0 else "_left")); await wait(0.4)
			await wait(0.6)
			for d in ["kl", "kr", "pad0", "pad1"]:
				tap(d + "_jump"); await wait(0.4)
			await wait(1.0)
		"map":
			await team([{"char": 0, "input": "kl"}, {"char": 3, "input": "kr"}, {"char": 4, "input": "pad0"}])
			Game.pending = {"gold": 20, "boons": 3}
			Game.goto_scene(Game.MAP_SCENE)
			await idle()
			await wait(1.0)
			tap("m_down"); await wait(0.6)
			tap("m_down"); await wait(0.6)
			tap("m_ok"); await wait(1.2)
			for m in ["m_down", "m_down", "m_up"]:
				tap(m); await wait(0.6)
			await wait(1.0)
		"level", "level2", "level3":
			await team([{"char": 0, "input": "kl"}, {"char": 1, "input": "kr"}, {"char": 3, "input": "pad0"}])
			await play_stage("fight", {"level": 0, "level2": 2, "level3": 1}[shot])
			shield()
			await brawl(length)
		"boss":
			await team([{"char": 2, "input": "kl"}, {"char": 4, "input": "kr"}, {"char": 0, "input": "pad0"}])
			await play_stage("boss", 0)
			shield()
			await brawl(length)
		"sky":
			await team([{"char": 0, "input": "kl"}, {"char": 1, "input": "kr"}])
			Game.stage = {"name": "1-3", "kind": "sky"}
			Game.goto_scene(Game.SHMUP_SCENE)
			await idle()
			var t = 0.0
			while t < length:
				hold("kl_up", int(t * 1.3) % 2 == 0); hold("kl_down", int(t * 1.3) % 2 == 1)
				hold("kr_down", int(t * 0.9) % 2 == 0); hold("kr_up", int(t * 0.9) % 2 == 1)
				hold("kl_right", fmod(t, 3.0) < 1.0); hold("kr_left", fmod(t, 4.0) < 0.6)
				if fmod(t, 1.7) < 0.1:
					tap("kl_dash")
				await wait(0.1); t += 0.1
		"gallery":
			await team([{"char": 0, "input": "kl"}, {"char": 4, "input": "kr"}])
			Game.goto_scene(Game.GALLERY_SCENE)
			await idle()
			var g = get_tree().current_scene
			var t = 0.0
			while t < length:
				for pair in [["kl", 0], ["kr", 1]]:
					var dirs = ["_left", "_right", "_up", "_down"]
					for d in dirs:
						hold(pair[0] + d, false)
					var k = int(t * 2.0 + pair[1] * 3) % 4
					hold(pair[0] + dirs[k], true)
				if fmod(t, 0.4) < 0.1:
					tap("kl_action"); tap("kr_action")
				await wait(0.1); t += 0.1
		"tavern":
			await team([{"char": 0, "input": "kl"}, {"char": 1, "input": "kr"}, {"char": 3, "input": "pad0"}, {"char": 4, "input": "pad1"}])
			Game.gold = 250
			Game.goto_scene(Game.TAVERN_SCENE)
			await idle()
			await wait(1.0)
			for m in ["m_down", "m_down", "m_down", "m_up", "m_down", "m_down"]:
				tap(m); await wait(0.6)
			await wait(1.0)
		"camp":
			Game.dinars = 320
			Game.goto_scene(Game.CAMP_SCENE)
			await idle()
			await wait(1.0)
			for m in ["m_down", "m_down", "m_down", "m_down", "m_up"]:
				tap(m); await wait(0.6)
			await wait(1.0)
	get_tree().quit()


## Every hero runs right, jumps, throws, dashes, and fires their ultimate now and then.
func brawl(seconds):
	var lv = Game.level_node
	var t = 0.0
	var ins = ["kl", "kr", "pad0"]
	while t < seconds:
		for i in ins.size():
			var inp = ins[i]
			var phase = t + i * 0.37
			var back = fmod(phase, 5.0) > 4.3
			hold(inp + "_right", not back)
			hold(inp + "_left", back)
			hold(inp + "_action", fmod(phase, 2.0) < 1.2)
			if fmod(phase, 0.9) < 0.1:
				tap(inp + "_jump", 0.25)
			if fmod(phase, 0.6) < 0.1:
				tap(inp + "_action")
			if fmod(phase, 2.3) < 0.1:
				tap(inp + "_dash")
		if fmod(t, 3.0) < 0.1 and lv and is_instance_valid(lv):
			var k = int(t / 3.0) % Game.players.size()
			Game.players[k].mana = 100.0
			tap(ins[k] + "_ult")
		await wait(0.1)
		t += 0.1
