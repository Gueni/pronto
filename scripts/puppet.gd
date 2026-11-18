extends Node2D
## Every character in the game: heroes, enemies, bosses. A puppet has a `look` (see LOOKS).
##
## Most looks are a sprite sheet from assets/chars (packed out of the character packs by
## tools_tmp/pack_sprites.gd), recoloured with a tint so one sheet can play several parts.
## The creatures the packs do not have (slimes, bats, ghosts, the mimic) are drawn here
## with polygons in the same cartoon style.
##
## It mimics the bits of AnimatedSprite2D the rest of the game uses (play, flip_h,
## animation_finished...). The origin is the middle of the body with the feet 16 units
## below, and `h` is how tall the idle pose stands in those units.

signal animation_finished

const ONE_SHOT = {"throw": 0.32, "hurt": 0.4, "death": 0.8}
const FPS = {"idle": 9.0, "run": 15.0, "walk": 10.0}
# which sheet animation plays each game animation: first one the sheet has
const FALLBACK = {
	"idle": ["idle"],
	"run": ["run", "walk"],
	"walk": ["walk", "run"],
	"jump": ["jump", "glide", "idle"],
	"throw": ["throw", "attack", "melee", "shoot", "idle"],
	"hurt": ["hurt", "idle"],
	"death": ["dead", "idle"],
}

const DARK = Color(0.13, 0.09, 0.16)
const WHITE = Color(1, 1, 1)
const GOLD = Color(1.0, 0.82, 0.25)

const LOOKS = {
	# heroes
	"pronto": {"sheet": "boy", "h": 30},
	"elli": {"sheet": "ninjagirl", "h": 29},
	"shee": {"sheet": "ninja", "h": 31},
	"gueni": {"sheet": "cat", "h": 27},
	"iheb": {"sheet": "explorer", "h": 31},
	# people
	"keeper": {"sheet": "santa", "h": 30},
	# enemies
	"pinky": {"sheet": "zombiegirl", "h": 24},
	"grump": {"sheet": "zombie", "h": 26},
	"zombie": {"sheet": "zombie", "h": 25, "tint": Color(0.7, 1.0, 0.65)},
	"charger": {"sheet": "dog", "h": 24, "tint": Color(1.0, 0.72, 0.68)},
	"hopper": {"sheet": "jack", "h": 23},
	"shield": {"sheet": "knight", "h": 27, "tint": Color(0.72, 0.78, 1.0)},
	"kamikaze": {"sheet": "robot", "h": 25, "tint": Color(1.0, 0.55, 0.5)},
	"sniper": {"sheet": "advgirl", "h": 25, "tint": Color(0.72, 1.0, 0.7)},
	"shaman": {"sheet": "cutegirl", "h": 25, "tint": Color(0.82, 0.7, 1.0)},
	# bosses
	"queen": {"sheet": "dino_big", "h": 21},
	"boss": {"sheet": "knight_big", "h": 31, "tint": Color(1.0, 0.62, 0.8)},
	# drawn by hand
	"slime": {"rig": "blob", "color": Color(0.4, 0.85, 0.4)},
	"slime_purple": {"rig": "blob", "color": Color(0.68, 0.42, 0.95)},
	"spiky": {"rig": "blob", "color": Color(0.25, 0.72, 0.74)},
	"splitter": {"rig": "blob", "color": Color(0.88, 0.8, 0.28)},
	"bat": {"rig": "bat", "color": Color(0.42, 0.3, 0.6)},
	"bomber": {"rig": "bat", "color": Color(0.62, 0.3, 0.25)},
	"baron": {"rig": "bat", "color": Color(0.36, 0.24, 0.5)},
	"ghost": {"rig": "ghost", "color": Color(0.86, 0.94, 1.0)},
	"mimic": {"rig": "mimic", "color": Color(0.66, 0.42, 0.2)},
	# sea creatures: one picture each (Kenney Fish Pack, CC0), animated here
	"fish": {"img": "fish_orange_outline", "h": 22},
	"fish_b": {"img": "fish_green_outline", "h": 22},
	"fish_c": {"img": "fish_pink_outline", "h": 19},
	"fish_d": {"img": "fish_blue_outline", "h": 22},
	"piranha": {"img": "fish_red_outline", "h": 27},
	"skelefish": {"img": "fish_orange_skeleton_outline", "h": 24},
	"puffer": {"img": "fish_brown_outline", "h": 26},
	"eel": {"img": "fish_grey_long_a_outline", "h": 34, "wave": 1.0},
	"puffer_king": {"img": "fish_brown_outline", "h": 34},
	"stalker": {"rig": "shade", "color": Color(0.13, 0.08, 0.22)},
	"ghoula": {"rig": "shade", "color": Color(0.16, 0.07, 0.2)},
}

static var _sheets = {}   # sheet name -> {tex, h, anims}

var look = "pronto":
	set(v):
		look = v
		_data = null
var flip_h = false
var animation = "idle"
var frame = 0
var speed_scale = 1.0
var sprite_frames = null   # unused, kept so old code can still assign it
var frozen = false         # after-images: keep the pose
var t = 0.0
var anim_t = 0.0
var _done = false
var _manual = false
var _data = null


func _init():
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


static func sheet(sheet_name):
	if not _sheets.has(sheet_name):
		var data = load("res://assets/chars/%s.json" % sheet_name).data
		var img = load("res://assets/chars/%s.png" % sheet_name).get_image()
		if img.is_compressed():
			img.decompress()
		img.generate_mipmaps()
		_sheets[sheet_name] = {"tex": ImageTexture.create_from_image(img), "h": float(data.h), "anims": data.anims}
	return _sheets[sheet_name]


func play(anim = "idle"):
	if anim != animation:
		animation = anim
		anim_t = 0.0
		_done = false
		_manual = false


func set_frame_and_progress(f, _progress = 0.0):
	frame = f
	_manual = true


func _process(delta):
	if frozen:
		return
	t += delta * speed_scale
	anim_t += delta
	if ONE_SHOT.has(animation) and not _done and anim_t >= ONE_SHOT[animation]:
		_done = true
		animation_finished.emit()
	queue_redraw()


func _draw():
	var L = LOOKS.get(look, LOOKS["pinky"])
	if L.has("sheet"):
		_draw_sheet(L)
		return
	if L.has("img"):
		_draw_img(L)
		return
	var f = -1.0 if flip_h else 1.0
	var squash = Vector2(f, 1)
	if animation == "jump":
		squash = Vector2(f * 0.93, 1.07)
	draw_set_transform(Vector2(0, 16), 0.0, squash)
	var flash = animation == "hurt" and int(anim_t * 20) % 2 == 0
	var c = L.color.lerp(WHITE, 0.6) if flash else L.color
	match L.rig:
		"blob":
			_blob(c)
		"bat":
			_bat(c)
		"ghost":
			_ghost(c)
		"mimic":
			_mimic(c)
		"shade":
			_shade(c)


# ---------------------------------------------------------------- sprite sheets

func _draw_sheet(L):
	if _data == null:
		_data = sheet(L.sheet)
	var frames = null
	for a in FALLBACK.get(animation, ["idle"]):
		if _data.anims.has(a):
			frames = _data.anims[a]
			break
	if frames == null:
		frames = _data.anims["idle"]
	var n = frames.size()
	var i = 0
	if ONE_SHOT.has(animation):
		i = int(anim_t / ONE_SHOT[animation] * n)
		if animation == "hurt" and not _data.anims.has("hurt"):
			i = 0
	elif animation == "jump":
		if _manual:
			i = int(n * {3: 0.25, 4: 0.5, 5: 0.8}.get(frame, 0.5))
		else:
			i = int(anim_t * 12.0)
	else:
		i = int(t * FPS.get(animation, 10.0)) % n
	var fr = frames[clamp(i, 0, n - 1)]
	var k = L.h / _data.h
	var col = L.get("tint", WHITE)
	if animation == "hurt" and int(anim_t * 20) % 2 == 0:
		col = Color(3.0, 3.0, 3.0)
	draw_set_transform(Vector2(0, 16), 0.0, Vector2(-k if flip_h else k, k))
	draw_texture_rect_region(_data.tex, Rect2(fr[4], fr[5], fr[2], fr[3]), Rect2(fr[0], fr[1], fr[2], fr[3]), col)
	if look == "gueni" and animation != "death":
		# there is always a little cloud over his head
		draw_set_transform(Vector2(0, 16), 0.0, Vector2(-1 if flip_h else 1, 1))
		for j in 3:
			var p = fmod(t * 0.5 + j / 3.0, 1.0)
			draw_circle(Vector2(-7 + sin(p * 8.0 + j) * 2.0, -L.h - p * 12.0), 1.2 + p * 2.2, Color(0.8, 1.0, 0.8, 0.45 * (1.0 - p)))


# ---------------------------------------------------------------- swimming pictures

static func picture(img_name):
	if not _sheets.has("img:" + img_name):
		var img = load("res://assets/ocean/%s.png" % img_name).get_image()
		if img.is_compressed():
			img.decompress()
		img.generate_mipmaps()
		_sheets["img:" + img_name] = ImageTexture.create_from_image(img)
	return _sheets["img:" + img_name]


## A fish is one picture cut into vertical strips; a wave runs along the strips from the
## head (still) to the tail (wide), so it really swims. Faster while "running".
## The picture is centred a little below the origin, where the flying enemies' body is.
func _draw_img(L):
	var tex = picture(L.img)
	var h = float(L.h)
	var col = L.get("tint", WHITE)
	if animation == "hurt" and int(anim_t * 20) % 2 == 0:
		col = Color(3.0, 3.0, 3.0)
	var dead_fish = animation == "death"
	var beat = 15.0 if animation == "run" else 9.0
	var puff = 1.0
	if look == "puffer" or look == "puffer_king":
		puff = 1.0 + 0.07 * sin(t * 4.0)   # breathing in and out
	var bob = sin(t * 2.4) * 0.04 * h
	# belly up when dead
	draw_set_transform(Vector2(0, 6.0 + bob), sin(t * 3.0) * 0.05, Vector2((-1.0 if flip_h else 1.0) * puff, (-1.0 if dead_fish else 1.0) * puff))
	var n = 10
	var size = Vector2(tex.get_width(), tex.get_height())
	for i in n:
		var k = 1.0 - i / float(n - 1)          # 1 at the tail (left edge of the picture), 0 at the head
		var amp = 0.0 if dead_fish else h * 0.075 * max(k * k, L.get("wave", 0.0) * 0.6)
		var dy = sin(t * beat - i * 0.75) * amp
		draw_texture_rect_region(tex, Rect2(-h * 0.5 + h * i / n, -h * 0.5 + dy, h / n + 0.05, h), Rect2(size.x * i / n, 0, size.x / n, size.y), col)


# ---------------------------------------------------------------- hand-drawn creatures
# All of them are drawn with the feet at (0, 0), facing +x, y up is negative.

func _oval(center, rx, ry, color, outline = true, steps = 20):
	var pts = PackedVector2Array()
	for i in steps:
		var a = TAU * i / steps
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	_shape(pts, color, outline)


func _shape(pts, color, outline = true):
	draw_colored_polygon(pts, color)
	if outline:
		var loop = PackedVector2Array(pts)
		loop.append(pts[0])
		draw_polyline(loop, DARK, 0.9, true)


func _eye(pos, r, angry = false, iris = DARK):
	_oval(pos, r, r * 1.15, WHITE, true, 12)
	draw_circle(pos + Vector2(r * 0.35, r * 0.1), r * 0.5, iris)
	draw_circle(pos + Vector2(r * 0.15, -r * 0.3), r * 0.2, WHITE)
	if angry:
		draw_line(pos + Vector2(-r * 1.2, -r * 1.5), pos + Vector2(r * 1.1, -r * 0.7), DARK, 1.0, true)


func _blob(c):
	var s = sin(t * 6.0)
	var w = 9.0 + s * 0.9      # half width
	var h = 13.0 - s * 1.3
	if animation == "death":
		w = 12.0
		h = 5.0
	var pts = PackedVector2Array()
	for i in 17:
		var a = PI * i / 16.0
		# a dome that bulges a little at the bottom
		var bulge = 1.0 + 0.12 * sin(a) * sin(a * 2.0 + t * 3.0)
		pts.append(Vector2(-cos(a) * w * bulge, -sin(a) * h))
	pts.append(Vector2(w * 0.8, 0.5))
	pts.append(Vector2(-w * 0.8, 0.5))
	if look == "spiky":
		for i in 5:
			var a = PI * (0.18 + 0.16 * i)
			var base = Vector2(-cos(a) * w, -sin(a) * h)
			var out = Vector2(-cos(a), -sin(a) * 1.2)
			var side = Vector2(out.y, -out.x) * 1.6
			_shape(PackedVector2Array([base + side, base + out * 5.0, base - side]), Color(0.95, 0.97, 1.0))
	_shape(pts, c)
	# darker belly, shine
	var belly = PackedVector2Array()
	for i in 9:
		var a = PI * i / 8.0
		belly.append(Vector2(-cos(a) * w * 0.86, -sin(a) * h * 0.3 - 0.2))
	draw_colored_polygon(belly, c.darkened(0.22))
	_oval(Vector2(-w * 0.45, -h * 0.72), 2.0, 1.2, c.lightened(0.6), false, 10)
	if look == "splitter":
		draw_polyline(PackedVector2Array([Vector2(0, -h), Vector2(-1.2, -h * 0.7), Vector2(1.0, -h * 0.45), Vector2(-0.6, -h * 0.2), Vector2(0, 0)]), c.darkened(0.45), 0.9, true)
	var angry = look == "spiky" or look == "slime_purple"
	var ey = -h * 0.55
	_eye(Vector2(1.2, ey), 2.3, angry)
	_eye(Vector2(6.0, ey), 2.0, angry)
	if angry:
		draw_line(Vector2(2.0, ey + 4.4), Vector2(6.0, ey + 3.6), DARK, 1.0, true)
	else:
		draw_arc(Vector2(3.8, ey + 3.2), 1.8, 0.2, PI - 0.2, 8, DARK, 0.9, true)


func _bat(c):
	var flap = sin(t * 18.0)
	var body = Vector2(0, -15)
	for side in [-1.0, 1.0]:
		var tip = body + Vector2(side * 17, -6 + flap * 7.0)
		var mid = body + Vector2(side * 9, -7 + flap * 3.0)
		_shape(PackedVector2Array([
			body + Vector2(side * 3, -3), mid, tip,
			tip + Vector2(-side * 3, 5), body + Vector2(side * 11, 2 + flap * 3.0),
			body + Vector2(side * 8, 5 + flap * 2.0), body + Vector2(side * 5, 2 + flap), body + Vector2(side * 3, 5)]), c.darkened(0.35))
	# ears, body
	_shape(PackedVector2Array([body + Vector2(-5, -5), body + Vector2(-5.5, -12), body + Vector2(-1, -7)]), c)
	_shape(PackedVector2Array([body + Vector2(5, -5), body + Vector2(5.5, -12), body + Vector2(1, -7)]), c)
	_oval(body, 6.5, 7.5, c)
	_oval(body + Vector2(0.5, 2.5), 4.0, 4.0, c.lightened(0.18), false, 12)
	_eye(body + Vector2(0.5, -2.5), 2.0, look != "bat", Color(0.75, 0.1, 0.15))
	_eye(body + Vector2(4.6, -2.5), 1.7, look != "bat", Color(0.75, 0.1, 0.15))
	# fangs
	draw_colored_polygon(PackedVector2Array([body + Vector2(1, 2), body + Vector2(2.4, 2), body + Vector2(1.7, 4.6)]), WHITE)
	draw_colored_polygon(PackedVector2Array([body + Vector2(4, 2), body + Vector2(5.4, 2), body + Vector2(4.7, 4.6)]), WHITE)
	if look == "bomber":
		_oval(body + Vector2(0, 11.5), 4.2, 4.2, Color(0.16, 0.16, 0.22))
		draw_circle(body + Vector2(-1.4, 10.2), 1.0, Color(0.5, 0.5, 0.6))
		draw_line(body + Vector2(0, 7.3), body + Vector2(1.5, 5.8), Color(0.6, 0.45, 0.25), 0.9)
		draw_circle(body + Vector2(1.8, 5.5), 1.0 + sin(t * 30.0) * 0.4, Color(1.0, 0.75, 0.2))
	elif look == "baron":
		# top hat, monocle, bow tie
		draw_rect(Rect2(body.x - 6.5, body.y - 9, 13, 1.8), DARK)
		draw_rect(Rect2(body.x - 4.5, body.y - 16, 9, 7), DARK)
		draw_rect(Rect2(body.x - 4.5, body.y - 11.3, 9, 1.5), Color(0.85, 0.2, 0.3))
		draw_arc(body + Vector2(4.6, -2.5), 2.6, 0, TAU, 14, GOLD, 0.8, true)
		draw_line(body + Vector2(6.6, -0.8), body + Vector2(7.5, 5.0), GOLD, 0.5, true)
		draw_colored_polygon(PackedVector2Array([body + Vector2(0, 6.5), body + Vector2(-3, 5), body + Vector2(-3, 8)]), Color(0.85, 0.2, 0.3))
		draw_colored_polygon(PackedVector2Array([body + Vector2(0, 6.5), body + Vector2(3, 5), body + Vector2(3, 8)]), Color(0.85, 0.2, 0.3))


func _ghost(c):
	var wob = sin(t * 3.0)
	var pts = PackedVector2Array()
	for i in 13:
		var a = PI + PI * i / 12.0
		pts.append(Vector2(cos(a) * 7.5, -14 + sin(a) * 9.0))
	# wavy hem
	for i in 7:
		var x = 7.5 - i * 2.5
		pts.append(Vector2(x, -1.0 + (2.2 if i % 2 == 1 else 0.0) + sin(t * 7.0 + i) * 0.8))
	_shape(pts, c)
	_oval(Vector2(-3.5, -18), 2.0, 1.2, WHITE, false, 10)
	_oval(Vector2(0.8 + wob, -15), 1.6, 2.4, DARK, false, 10)
	_oval(Vector2(4.8 + wob, -15), 1.4, 2.2, DARK, false, 10)
	_oval(Vector2(3.0 + wob, -9.5), 1.8, 1.6 + sin(t * 5.0) * 0.5, DARK, false, 10)
	# little arms
	_oval(Vector2(8.0, -11 + wob), 2.0, 1.4, c, true, 10)
	_oval(Vector2(-8.0, -10 - wob), 2.0, 1.4, c, true, 10)


func _mimic(c):
	var open = 0.25 + abs(sin(t * 8.0)) * 0.35
	if animation == "jump":
		open = 0.75
	var steel = GOLD
	# box
	_shape(PackedVector2Array([Vector2(-9, 0), Vector2(-9, -9), Vector2(9, -9), Vector2(9, 0)]), c)
	draw_rect(Rect2(-9, -3, 18, 3), c.darkened(0.3))
	draw_rect(Rect2(-9, -9, 2, 9), steel)
	draw_rect(Rect2(7, -9, 2, 9), steel)
	# mouth
	var lift = open * 9.0
	draw_rect(Rect2(-8, -9 - lift, 16, lift), Color(0.3, 0.05, 0.12))
	_oval(Vector2(2, -9 - lift * 0.3), 3.5, min(lift * 0.5, 2.5), Color(0.95, 0.4, 0.5), false, 10)
	for i in 5:
		var x = -7.5 + i * 3.4
		draw_colored_polygon(PackedVector2Array([Vector2(x, -9), Vector2(x + 2.4, -9), Vector2(x + 1.2, -9 - min(lift, 3.2))]), WHITE)
		draw_colored_polygon(PackedVector2Array([Vector2(x + 1.2, -9 - lift), Vector2(x + 3.6, -9 - lift), Vector2(x + 2.4, -9 - lift + min(lift, 3.2))]), WHITE)
	# lid
	var pts = PackedVector2Array()
	for i in 9:
		var a = PI + PI * i / 8.0
		pts.append(Vector2(cos(a) * 9.5, -9 - lift + sin(a) * 6.0))
	_shape(pts, c.lightened(0.1))
	draw_rect(Rect2(-9.5, -10.5 - lift, 19, 1.5), steel)
	_eye(Vector2(1.5, -12.5 - lift), 1.9, true, Color(0.8, 0.15, 0.1))
	_eye(Vector2(6.0, -12.5 - lift), 1.6, true, Color(0.8, 0.15, 0.1))
	_oval(Vector2(0, -6), 1.6, 1.8, steel, true, 10)


## The shadow that follows the team, and the Ghoula it turns out to be: a ragged cloak,
## horns, burning eyes, long arms.
func _shade(c):
	var sway = sin(t * 2.5)
	var arms_up = animation == "throw" or animation == "jump"
	var melt = clamp(anim_t / 0.8, 0.0, 1.0) if animation == "death" else 0.0
	var top = -30.0 * (1.0 - melt * 0.75)
	var lean = sway * 0.6 + (1.5 if animation == "run" else 0.0)
	var rim = Color(0.62, 0.38, 0.95, 0.85)
	# smoke coming off it
	for i in 4:
		var k = fmod(t * 0.4 + i / 4.0, 1.0)
		draw_circle(Vector2(-6 + i * 4 + sin(k * 7.0 + i) * 2.0, top + 6 - k * 14.0), 2.5 * (1.0 - k) + 0.5, Color(c.r, c.g, c.b, 0.5 * (1.0 - k)))
	# arms behind the cloak
	var sh = Vector2(lean, top + 13)
	for side in [-1.0, 1.0]:
		var hand = sh + Vector2(side * 13.0, 7.0 + side * sway * 2.0)
		if arms_up:
			hand = sh + Vector2(side * 12.0, -13.0)
		elif animation == "run" and side > 0:
			hand = sh + Vector2(15.0, 1.0)
		var elbow = (sh + Vector2(side * 6.0, 0) + hand) * 0.5 + Vector2(side * 2.0, -2.0)
		draw_polyline(PackedVector2Array([sh + Vector2(side * 6.0, 0), elbow, hand]), rim, 3.0, true)
		draw_polyline(PackedVector2Array([sh + Vector2(side * 6.0, 0), elbow, hand]), c, 2.0, true)
		for claw in [-1.0, 0.0, 1.0]:
			draw_line(hand, hand + Vector2(side * 2.5 + claw, 3.0 - abs(claw)), Color(0.92, 0.9, 1.0), 0.8, true)
	# horns
	for side in [-1.0, 1.0]:
		_shape(PackedVector2Array([Vector2(lean + side * 2.0, top + 3), Vector2(lean + side * 8.5, top - 6), Vector2(lean + side * 5.0, top + 5)]), c.lightened(0.18), false)
	# the cloak, with a ragged hem
	var pts = PackedVector2Array([Vector2(lean - 5, top + 4), Vector2(lean, top), Vector2(lean + 5, top + 4), Vector2(8, min(top + 14.0, -2.0)), Vector2(11, 0)])
	for i in range(1, 6):
		pts.append(Vector2(11.0 - i * 3.67, (-3.5 - sin(t * 6.0 + i) * 1.2) * (1.0 - melt) if i % 2 == 1 else 0.0))
	pts.append(Vector2(-11, 0))
	pts.append(Vector2(-8, min(top + 14.0, -2.0)))
	draw_colored_polygon(pts, c)
	var loop = PackedVector2Array(pts)
	loop.append(pts[0])
	draw_polyline(loop, rim, 0.9, true)
	if melt > 0.0:
		return
	# eyes and teeth
	var glow = 0.75 + 0.25 * sin(t * 7.0)
	for ex in [1.2, 5.6]:
		var e = Vector2(lean + ex, top + 8)
		draw_circle(e, 2.6, Color(1.0, 0.2, 0.15, 0.25 * glow))
		draw_colored_polygon(PackedVector2Array([e + Vector2(-1.8, -1.2), e + Vector2(1.8, 0.2), e + Vector2(-1.2, 1.3)]), Color(1.0, 0.3 + 0.4 * glow, 0.2))
	var teeth = PackedVector2Array()
	for i in 7:
		teeth.append(Vector2(lean - 0.5 + i * 1.2, top + 12.5 + (1.6 if i % 2 == 1 else 0.0)))
	draw_polyline(teeth, Color(0.95, 0.93, 1.0), 0.8, true)
