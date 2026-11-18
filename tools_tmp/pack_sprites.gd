extends SceneTree
## Turns the big loose PNG frames of the character packs (assets/sprites/*.zip, unzipped
## somewhere) into one small trimmed sprite sheet + a .json per character in assets/chars.
##
##   godot --headless --path . -s tools_tmp/pack_sprites.gd -- <folder with the unzipped packs> [only_this_name]
##
## Every frame is cropped to its pixels and scaled so the idle pose is `h` pixels tall.
## The json holds, per animation, a list of [x, y, w, h, ox, oy]: the frame's place in the
## sheet and where its top-left corner sits relative to the feet.

const MAX_FRAMES = 8
const SHEET_W = 2048

# name: [folder inside the unzip dir, idle height in sheet pixels]
const SETS = {
	"boy": ["flatboy/png", 150],
	"cutegirl": ["cutegirlfiles/png", 150],
	"advgirl": ["adventure_girl/png", 150],
	"ninja": ["ninjaadventurenew/png", 150],
	"ninjagirl": ["ninjagirlnew/png", 150],
	"explorer": ["templerun", 150],
	"robot": ["robotfree/png", 150],
	"knight": ["freeknight/png", 150],
	"jack": ["jackfree/png", 150],
	"santa": ["santasprites/png", 150],
	"dino": ["freedinosprite/png", 150],
	"cat": ["catndog/png/cat", 150],
	"dog": ["catndog/png/dog", 150],
	"zombie": ["zombiefiles/png/male", 150],
	"zombiegirl": ["zombiefiles/png/female", 150],
	"dino_big": ["freedinosprite/png", 330],
	"knight_big": ["freeknight/png", 330],
	"santa_big": ["santasprites/png", 330],
	"robot_big": ["robotfree/png", 330],
}
const KEEP = ["idle", "run", "walk", "jump", "dead", "attack", "throw", "melee", "shoot", "slide", "glide", "hurt"]
const BIG_KEEP = ["idle", "run", "walk", "jump", "dead", "attack", "melee", "shoot"]


func _init():
	var args = OS.get_cmdline_user_args()
	if args.is_empty():
		print("usage: -- <unzipped folder> [name]")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/chars"))
	for n in SETS:
		if args.size() > 1 and args[1] != n:
			continue
		_pack(n, args[0].path_join(SETS[n][0]), SETS[n][1])
	quit()


func _pack(set_name, dir, height):
	var anims = {}   # anim -> [[number, path]]
	var d = DirAccess.open(dir)
	if d == null:
		print("MISSING ", dir)
		return
	var re = RegEx.new()
	re.compile("^([A-Za-z_]+?)[ _]*\\(?(\\d+)\\)?\\.png$")
	for f in d.get_files():
		var m = re.search(f)
		if m == null:
			continue
		var a = m.get_string(1).to_lower()
		if not (a in (BIG_KEEP if set_name.ends_with("_big") else KEEP)):
			continue
		if not anims.has(a):
			anims[a] = []
		anims[a].append([int(m.get_string(2)), dir.path_join(f)])
	if not anims.has("idle"):
		print("NO IDLE in ", dir)
		return
	var same_canvas = true
	var canvas = Vector2i.ZERO
	var frames = {}  # anim -> [Image]
	for a in anims:
		anims[a].sort_custom(func(x, y): return x[0] < y[0])
		var list = anims[a]
		var n = min(MAX_FRAMES, list.size())
		frames[a] = []
		for i in n:
			var img = Image.load_from_file(list[int(round(i * (list.size() - 1) / float(max(1, n - 1))))][1])
			img.convert(Image.FORMAT_RGBA8)
			if canvas == Vector2i.ZERO:
				canvas = img.get_size()
			elif canvas != img.get_size():
				same_canvas = false
			frames[a].append(img)
	var idle_box = _union(frames["idle"])
	var k = height / float(idle_box.size.y)
	var out = []     # [anim, Image, ox, oy]
	for a in frames:
		var box = _union(frames[a])
		# where the feet are in this animation's canvas
		var anchor = Vector2(idle_box.position.x + idle_box.size.x * 0.5, idle_box.end.y)
		if not same_canvas:
			var first = frames[a][0].get_used_rect()
			anchor = Vector2(first.position.x + first.size.x * 0.5, box.end.y)
			if a == "idle":
				anchor.x = box.position.x + box.size.x * 0.5
		for img in frames[a]:
			var r = img.get_used_rect()
			if r.size.x == 0:
				r = Rect2i(0, 0, 1, 1)
			var cut = img.get_region(r)
			cut.fix_alpha_edges()
			var w = max(1, int(round(r.size.x * k)))
			var h = max(1, int(round(r.size.y * k)))
			cut.resize(w, h, Image.INTERPOLATE_LANCZOS)
			out.append([a, cut, int(round((r.position.x - anchor.x) * k)), int(round((r.position.y - anchor.y) * k))])
	# shelf packing
	var x = 0
	var y = 0
	var row_h = 0
	var places = []
	for o in out:
		var s = o[1].get_size()
		if x + s.x + 2 > SHEET_W:
			x = 0
			y += row_h + 2
			row_h = 0
		places.append(Vector2i(x, y))
		x += s.x + 2
		row_h = max(row_h, s.y)
	var sheet = Image.create(SHEET_W, y + row_h, false, Image.FORMAT_RGBA8)
	var data = {"h": height, "anims": {}}
	for i in out.size():
		var o = out[i]
		var s = o[1].get_size()
		sheet.blit_rect(o[1], Rect2i(Vector2i.ZERO, s), places[i])
		if not data.anims.has(o[0]):
			data.anims[o[0]] = []
		data.anims[o[0]].append([places[i].x, places[i].y, s.x, s.y, o[2], o[3]])
	sheet.save_png("res://assets/chars/%s.png" % set_name)
	var f = FileAccess.open("res://assets/chars/%s.json" % set_name, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	print("%s: %d frames, sheet %dx%d, same canvas %s, anims %s" % [set_name, out.size(), SHEET_W, y + row_h, same_canvas, ", ".join(frames.keys())])


func _union(list):
	var box = Rect2i()
	for img in list:
		var r = img.get_used_rect()
		box = r if box.size.x == 0 else box.merge(r)
	return box
