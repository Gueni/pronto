extends Control
## The run map: pick the next stop of the journey.
## If a reward is waiting (Game.pending), the team first chooses a boon.

const INFO = {
	"fight": ["FIGHT", "!", Color(0.95, 0.45, 0.35), "A ROAD FULL OF ENEMIES. REACH THE FLAG."],
	"arena": ["AMBUSH", "X", Color(0.8, 0.25, 0.3), "A CLOSED ARENA. SURVIVE THREE WAVES."],
	"elite": ["ELITE", "E", Color(1.0, 0.8, 0.25), "TOUGHER ENEMIES, ONE MORE BOON TO CHOOSE FROM."],
	"gallery": ["GALLERY", "+", Color(0.4, 0.7, 1.0), "MINIGAME: FIRST-PERSON SHOOTING RANGE. SCORE = GOLD, A GOOD SCORE = A BOON."],
	"sky": ["SKY DUEL", "~", Color(0.45, 0.9, 0.95), "MINIGAME: FLY AND SHOOT DOWN BARON BAT FOR GOLD AND A BOON."],
	"tavern": ["TAVERN", "T", Color(0.5, 0.9, 0.5), "HEAL, BUY BOONS, PLACE A BET."],
	"boss": ["BOSS", "B", Color(0.85, 0.45, 1.0), "THE BOSS OF THIS ACT."],
	"boss_sky": ["BOSS", "B", Color(0.85, 0.45, 1.0), "BARON BAT RULES THE SKY OF THE SOUTH. A DUEL IN THE AIR."],
}

var choices = []       # lanes of the next row the team can walk to
var index = 0
var boons = []         # boons offered as a reward (empty = no reward)
var boon_index = 0
var t = 0.0
var grace = 0.4


func _ready():
	Game.ensure_players()
	Game.hud.visible = false
	Music.play_track("map")
	var sky = Game.sky(Color(0.06, 0.07, 0.2), Color(0.25, 0.2, 0.4))
	add_child(sky)
	sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sky.show_behind_parent = true
	if Game.map.is_empty():
		Game._new_map()
	if Game.pending != null:
		boons = Game.roll_boons(Game.pending.boons)
		if boons.is_empty():
			Game.pending = null
	if Game.map_row < 0:
		for node in Game.map[0]:
			if node != null:
				choices.append(node.lane)
	else:
		choices = Game.map[Game.map_row][Game.map_lane].links.duplicate()
	index = clamp(choices.find(Game.map_lane), 0, max(choices.size() - 1, 0))


func _process(delta):
	t += delta
	queue_redraw()
	if Game.busy:
		return
	if grace > 0:
		grace -= delta
		return
	var move = 0
	if Input.is_action_just_pressed("m_down"):
		move = 1
	elif Input.is_action_just_pressed("m_up"):
		move = -1
	var ok = Input.is_action_just_pressed("m_ok")
	if not boons.is_empty():
		var n = boons.size() + 1   # last entry = skip
		if move != 0:
			boon_index = (boon_index + move + n) % n
			Game.sfx("tap")
		if ok:
			if boon_index < boons.size():
				Game.add_boon(boons[boon_index].id)
				Game.sfx("power_up")
			else:
				Game.gold += 15
				Game.sfx("coin")
			boons = []
			Game.pending = null
			grace = 0.3
		return
	if choices.is_empty():
		return
	if move != 0:
		index = (index + move + choices.size()) % choices.size()
		Game.sfx("tap")
	if ok:
		Game.sfx("tap", 1.3)
		Game.enter_node(choices[index])


func _node_pos(row, lane):
	var w = size.x
	var h = size.y
	var cols = Game.map.size()
	return Vector2(w * 0.1 + (w * 0.8) * row / float(cols - 1), h * 0.32 + lane * h * 0.17)


func _text(pos, text, font_size, color, width = -1.0, bold = false):
	var font = Game.FONT_BOLD if bold else Game.FONT
	var align = HORIZONTAL_ALIGNMENT_LEFT if width < 0 else HORIZONTAL_ALIGNMENT_CENTER
	draw_string_outline(font, pos, text, align, width, font_size, max(2, font_size / 4), Color(0.05, 0.05, 0.12))
	draw_string(font, pos, text, align, width, font_size, color)


func _draw():
	var w = size.x
	var h = size.y
	var act = Game.ACTS[clamp(Game.act, 0, Game.ACTS.size() - 1)]
	_text(Vector2(0, 54), "ACT %d:  %s" % [Game.act + 1, act.name], 32, Color(1.0, 0.9, 0.4), w, true)
	var hearts = []
	for i in Game.players.size():
		hearts.append("%s %d/%d" % [Game.char_of(i).name, Game.players[i].hearts, Game.max_hearts(i)])
	_text(Vector2(0, 92), "GOLD %d     LIVES x%d     %s" % [Game.gold, Game.lives, "   ".join(hearts)], 16, Color.WHITE, w)

	# paths
	for r in Game.map.size() - 1:
		for node in Game.map[r]:
			if node == null:
				continue
			for lane in node.links:
				var walked = r < Game.map_row or (r == Game.map_row and node.lane == Game.map_lane)
				var col = Color(1, 1, 1, 0.5) if walked and r >= Game.map_row else Color(1, 1, 1, 0.14)
				draw_line(_node_pos(r, node.lane), _node_pos(r + 1, lane), col, 3.0)
	# nodes
	var picking = boons.is_empty()
	for r in Game.map.size():
		for node in Game.map[r]:
			if node == null:
				continue
			var info = INFO[node.type]
			var p = _node_pos(r, node.lane)
			var here = r == Game.map_row and node.lane == Game.map_lane
			var option = r == Game.map_row + 1 and node.lane in choices
			var selected = picking and option and choices[index] == node.lane
			var radius = 30.0 if node.type.begins_with("boss") else 22.0
			var col = info[2]
			if r <= Game.map_row and not here:
				col = col.darkened(0.6)
			elif not option and not here:
				col = col.darkened(0.25)
			if selected:
				radius += 4.0 + sin(t * 8.0) * 2.0
				draw_circle(p, radius + 6, Color(1, 1, 1, 0.9))
			draw_circle(p, radius + 3, Color(0.05, 0.05, 0.12))
			draw_circle(p, radius, col)
			_text(p + Vector2(-radius, 9), info[1], 24, Color(0.05, 0.05, 0.12), radius * 2, true)
			_text(p + Vector2(-60, radius + 18), info[0], 8, Color.WHITE if option or here else Color(0.6, 0.6, 0.7), 120)
			if here:
				draw_arc(p, radius + 9, 0, TAU, 32, Color(0.4, 1.0, 0.5), 3.0)
				_text(p + Vector2(-60, -radius - 12), "YOU", 8, Color(0.4, 1.0, 0.5), 120)

	# what the highlighted node is
	if picking and not choices.is_empty():
		var node = Game.map[Game.map_row + 1][choices[index]]
		_text(Vector2(0, h * 0.82), INFO[node.type][3], 16, Color(1.0, 0.95, 0.7), w)
		_text(Vector2(0, h * 0.87), "UP / DOWN: CHOOSE YOUR PATH        ENTER / (A): GO", 8, Color(0.75, 0.8, 0.9), w)
	var owned = []
	for b in Game.BOONS:
		if Game.up(b.id) > 0:
			owned.append(b.name if Game.up(b.id) == 1 else "%s x%d" % [b.name, Game.up(b.id)])
	_text(Vector2(0, h * 0.94), "BOONS:  " + ("NONE YET" if owned.is_empty() else ",  ".join(owned)), 8, Color(0.6, 0.9, 1.0), w)

	# reward: choose a boon
	if not boons.is_empty():
		draw_rect(Rect2(0, 0, w, h), Color(0, 0, 0.05, 0.78))
		_text(Vector2(0, h * 0.2), "CHOOSE A BOON", 32, Color(1.0, 0.9, 0.4), w, true)
		var y = h * 0.3
		for i in boons.size() + 1:
			var sel = i == boon_index
			var box = Rect2(w * 0.2, y, w * 0.6, 62)
			draw_rect(box, Color(0.2, 0.25, 0.5, 0.9) if sel else Color(0.1, 0.1, 0.2, 0.9))
			if sel:
				draw_rect(box, Color(1.0, 0.9, 0.4), false, 3.0)
			if i < boons.size():
				var b = boons[i]
				var have = Game.up(b.id)
				_text(Vector2(w * 0.2, y + 26), b.name + ("   (HAVE %d)" % have if have > 0 else ""), 16, Color(1.0, 0.9, 0.4) if sel else Color.WHITE, w * 0.6, true)
				_text(Vector2(w * 0.2, y + 48), b.desc, 8, Color(0.85, 0.9, 1.0), w * 0.6)
			else:
				_text(Vector2(w * 0.2, y + 36), "SKIP  (+15 GOLD)", 16, Color(1.0, 0.9, 0.4) if sel else Color(0.7, 0.7, 0.75), w * 0.6)
			y += 74
