extends Node
## Autoload "Game": global state, characters, input schemes, sounds,
## scene transitions and the HUD.

signal stats_changed
signal coin_collected
signal boss_changed(hp, max_hp)
signal banner(text)

const LevelData = preload("res://scripts/level_data.gd")
const Hud = preload("res://scripts/hud.gd")
const FONT = preload("res://assets/fonts/PixelOperator8.ttf")
const FONT_BOLD = preload("res://assets/fonts/PixelOperator8-Bold.ttf")
const FRUITS = preload("res://assets/sprites/fruit.png")
const ROCK_BIG = preload("res://assets/sprites/3 Dude_Monster/Rock2.png")

const DUDE = "res://assets/sprites/3 Dude_Monster/Dude_Monster"
const OWLET = "res://assets/sprites/2 Owlet_Monster/Owlet_Monster"
const PINK = "res://assets/sprites/1 Pink_Monster/Pink_Monster"

const TITLE_SCENE = "res://scenes/title.tscn"
const SELECT_SCENE = "res://scenes/select.tscn"
const END_SCENE = "res://scenes/end_screen.tscn"
const ASCII_SCENE = "res://scenes/ascii_level.tscn"
const SAVE_PATH = "user://save.cfg"

const SOUNDS = {
	"jump": preload("res://assets/sounds/jump.wav"),
	"coin": preload("res://assets/sounds/coin.wav"),
	"hurt": preload("res://assets/sounds/hurt.wav"),
	"explosion": preload("res://assets/sounds/explosion.wav"),
	"power_up": preload("res://assets/sounds/power_up.wav"),
	"tap": preload("res://assets/sounds/tap.wav"),
}

# name, [file suffix, frame count, fps, loop]
const ANIMS = {
	"idle": ["Idle_4", 4, 8, true],
	"run": ["Run_6", 6, 12, true],
	"walk": ["Walk_6", 6, 10, true],
	"jump": ["Jump_8", 8, 10, false],
	"hurt": ["Hurt_4", 4, 10, false],
	"death": ["Death_8", 8, 10, false],
	"throw": ["Throw_4", 4, 14, false],
}

const DEVICES = ["kl", "kr", "pad0", "pad1", "pad2", "pad3"]
const DEVICE_NAMES = {
	"kl": "KEYS A/D/W", "kr": "ARROW KEYS", "solo": "KEYBOARD",
	"pad0": "GAMEPAD 1", "pad1": "GAMEPAD 2", "pad2": "GAMEPAD 3", "pad3": "GAMEPAD 4",
}
const MAX_PLAYERS = 4

var PLAYER_COLORS = [Color(0.35, 0.75, 1.0), Color(1.0, 0.45, 0.4), Color(0.5, 0.9, 0.45), Color(1.0, 0.85, 0.3)]

# The heroes. speed / jump are multipliers, fall < 1 means floaty.
var CHARACTERS = [
	{
		"name": "PRONTO", "sheet": DUDE, "hue": 0.0, "tint": Color.WHITE,
		"color": Color(0.3, 0.72, 1.0), "blurb": "FAST AND LOUD", "quote": "PRONTO! PRONTO!",
		"speed": 1.12, "talk": 0.85, "laugh": true,
		"lines": {
			"start": ["PRONTO! PRONTO!", "LET'S GO, PRONTO!", "TRY TO KEEP UP! HAHA"],
			"stomp": ["HAHAHA! PRONTO!", "TOO SLOW! HAHA", "SQUISH! PRONTO!", "IS THAT ALL? HAHA"],
			"hurt": ["HEY! NOT PRONTO!", "OW! WHO DID THAT?!", "THAT TICKLES! HAHA"],
			"mock": ["HAHAHA! NICE ONE!", "GET UP, PRONTO! HAHA", "MY GRANDMA JUMPS BETTER!", "AGAIN?! HAHAHA"],
			"power": ["OH YES! PRONTO!", "MINE! ALL MINE! HAHA"],
			"win": ["TOO EASY! PRONTO!", "WHO'S THE BEST? PRONTO!"],
			"idle": ["PRONTO PRONTO PRONTO...", "ARE WE SLEEPING? HAHA", "HELLO?! MOVE, PRONTO!"],
			"death": ["PRONTOOOOO...", "I MEANT TO DO THAT!"],
		},
	},
	{
		"name": "ELI", "sheet": OWLET, "hue": 0.0, "tint": Color.WHITE,
		"color": Color(0.88, 0.92, 1.0), "blurb": "HIGH JUMPER", "quote": "EASY.",
		"jump": 1.08,
		"lines": {
			"start": ["READY."], "stomp": ["EASY.", "GOT IT."], "hurt": ["OUCH."],
			"mock": ["YOU OK?"], "power": ["NICE."], "win": ["WELL PLAYED."],
			"idle": ["..."], "death": ["NOT AGAIN..."],
		},
	},
	{
		"name": "SHEE", "sheet": DUDE, "hue": 0.2, "tint": Color.WHITE,
		"color": Color(0.72, 0.5, 1.0), "blurb": "FLOATY GLIDER", "quote": "LET'S FLY!",
		"fall": 0.72,
		"lines": {
			"start": ["LET'S FLY!"], "stomp": ["BYE BYE!", "BOOP!"], "hurt": ["HEY!"],
			"mock": ["OOPS!"], "power": ["YAY!"], "win": ["WE DID IT!"],
			"idle": ["LA LA LA..."], "death": ["NOOO!"],
		},
	},
	{
		"name": "GUENI", "sheet": DUDE, "hue": -0.22, "tint": Color.WHITE,
		"color": Color(0.45, 0.9, 0.5), "blurb": "EXTRA HEART", "quote": "IT'S A FEATURE.",
		"hearts": 4,
		"lines": {
			"start": ["I MADE THIS LEVEL."], "stomp": ["BUG FIXED.", "DEBUGGED!"],
			"hurt": ["THAT'S A FEATURE."], "mock": ["SKILL ISSUE."], "power": ["UPGRADE!"],
			"win": ["SA77IT!"], "idle": ["COMPILING..."], "death": ["CTRL+Z! CTRL+Z!"],
		},
	},
	{
		"name": "IHEB", "sheet": OWLET, "hue": 0.0, "tint": Color(1.0, 0.72, 0.42),
		"color": Color(1.0, 0.7, 0.35), "blurb": "ROCK THROWER", "quote": "YALLA!",
		"always_rocks": true,
		"lines": {
			"start": ["YALLA!"], "stomp": ["BOOM!", "NEXT!"], "hurt": ["AY!"],
			"mock": ["HAHA, YALLA!"], "power": ["ROCK ON!"], "win": ["YALLA! SA77IT!"],
			"idle": ["YALLA YALLA..."], "death": ["AYAYAY..."],
		},
	},
]

# --- run state ---
var players = []          # [{char, input, hearts, rocks, out}]
var score = 0
var coins = 0
var lives = 3
var level_index = 0
var time_left = 0.0
var checkpoint = null     # Vector2 or null
var best_score = 0
var max_level = 0
var pending_start_level = 0
var end_mode = "gameover"
var busy = false
var level_node = null

var hud
var _fade: ColorRect
var _card: Label
var _frames = {}
var _mats = {}
var _hue_shader: Shader
var _sfx_players = []
var _sfx_next = 0


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	randomize()
	_setup_input()
	_load()
	_hue_shader = Shader.new()
	_hue_shader.code = """
shader_type canvas_item;
uniform float shift = 0.0;
vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 1e-10)), d / (q.x + 1e-10), q.x);
}
vec3 hsv2rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 hsv = rgb2hsv(c.rgb);
	hsv.x = fract(hsv.x + shift);
	COLOR = vec4(hsv2rgb(hsv), c.a);
}
"""
	for i in 10:
		var p = AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_sfx_players.append(p)

	hud = Hud.new()
	hud.visible = false
	add_child(hud)

	var overlay = CanvasLayer.new()
	overlay.layer = 100
	add_child(overlay)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(_fade)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card = label("", 32)
	_card.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.visible = false
	overlay.add_child(_card)
	_card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_M:
			AudioServer.set_bus_mute(0, not AudioServer.is_bus_mute(0))
		elif event.physical_keycode == KEY_F11:
			var full = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)


# ---------------------------------------------------------------- input

func _setup_input():
	_scheme("kl", [KEY_A], [KEY_D], [KEY_W, KEY_SPACE], [KEY_F, KEY_G, KEY_SHIFT], -2)
	_scheme("kr", [KEY_LEFT], [KEY_RIGHT], [KEY_UP], [KEY_ENTER, KEY_KP_ENTER, KEY_KP_0, KEY_CTRL], -2)
	for i in 4:
		_scheme("pad%d" % i, [], [], [], [], i)
	_scheme("solo", [KEY_A, KEY_LEFT], [KEY_D, KEY_RIGHT], [KEY_W, KEY_SPACE, KEY_UP],
			[KEY_F, KEY_G, KEY_SHIFT, KEY_X, KEY_J, KEY_CTRL, KEY_KP_0], 0)
	_action("m_up", [KEY_UP, KEY_W], [JOY_BUTTON_DPAD_UP])
	_action("m_down", [KEY_DOWN, KEY_S], [JOY_BUTTON_DPAD_DOWN])
	_action("m_ok", [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE], [JOY_BUTTON_A])
	_action("m_back", [KEY_ESCAPE], [])
	_action("pause", [KEY_ESCAPE, KEY_P], [JOY_BUTTON_START])


func _action(action, keys, buttons, device = -1):
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.4)
	for k in keys:
		var e = InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(action, e)
	for b in buttons:
		var e = InputEventJoypadButton.new()
		e.device = device
		e.button_index = b
		InputMap.action_add_event(action, e)


func _scheme(prefix, left, right, jump, act, pad):
	_action(prefix + "_left", left, [JOY_BUTTON_DPAD_LEFT] if pad >= 0 else [], pad)
	_action(prefix + "_right", right, [JOY_BUTTON_DPAD_RIGHT] if pad >= 0 else [], pad)
	_action(prefix + "_jump", jump, [JOY_BUTTON_A] if pad >= 0 else [], pad)
	_action(prefix + "_action", act, [JOY_BUTTON_X, JOY_BUTTON_B] if pad >= 0 else [], pad)
	if pad >= 0:
		for side in [[-1.0, "_left"], [1.0, "_right"]]:
			var e = InputEventJoypadMotion.new()
			e.device = pad
			e.axis = JOY_AXIS_LEFT_X
			e.axis_value = side[0]
			InputMap.action_add_event(prefix + side[1], e)


# ---------------------------------------------------------------- game flow

func level_def():
	return LevelData.LEVELS[clamp(level_index, 0, LevelData.LEVELS.size() - 1)]


func char_of(slot):
	return CHARACTERS[players[slot].char]


func max_hearts(slot):
	return char_of(slot).get("hearts", 3)


## Makes sure there is at least one player (when a level is run directly from the editor).
func ensure_players():
	if players.is_empty():
		players = [{"char": 0, "input": "solo", "hearts": 3, "rocks": false, "out": false}]
		lives = 3
		# figure out which level we are in
		var path = get_tree().current_scene.scene_file_path if get_tree().current_scene else ""
		for i in LevelData.LEVELS.size():
			if LevelData.LEVELS[i].get("scene", "") == path:
				level_index = i
		hud.visible = true
		hud.refresh()


func new_game(list, start_level_index = 0):
	players = []
	for p in list:
		players.append({"char": p.char, "input": p.input, "hearts": 3, "rocks": false, "out": false})
	score = 0
	coins = 0
	lives = 3
	checkpoint = null
	start_level(start_level_index)


func _reset_players():
	for i in players.size():
		players[i].hearts = max_hearts(i)
		players[i].rocks = char_of(i).get("always_rocks", false)
		players[i].out = false


func start_level(index):
	if busy:
		return
	busy = true
	await _fade_to(1.0)
	get_tree().paused = true
	if index != level_index:
		checkpoint = null
	level_index = index
	_reset_players()
	banner.emit("")
	boss_changed.emit(0, 0)
	var def = level_def()
	hud.visible = false
	_card.text = "WORLD %s\n\n%s\n\n\nLIVES x %d" % [def.name, def.title, lives]
	_card.visible = true
	get_tree().change_scene_to_file(def.get("scene", ASCII_SCENE))
	await get_tree().create_timer(1.7).timeout
	_card.visible = false
	hud.visible = true
	hud.refresh()
	get_tree().paused = false
	await _fade_to(0.0)
	busy = false


func goto_scene(path):
	if busy:
		return
	busy = true
	await _fade_to(1.0)
	get_tree().paused = false
	hud.visible = false
	banner.emit("")
	get_tree().change_scene_to_file(path)
	await get_tree().create_timer(0.1).timeout
	await _fade_to(0.0)
	busy = false


func _fade_to(alpha, time = 0.3):
	var tw = create_tween()
	tw.tween_property(_fade, "color:a", alpha, time)
	await tw.finished


## Every hero is down. Costs a life, or ends the run.
func all_dead():
	if busy:
		return
	if lives > 0:
		lives -= 1
		start_level(level_index)
	else:
		_end("gameover")


func level_complete():
	if busy:
		return
	busy = true
	sfx("power_up")
	banner.emit("COURSE CLEAR!")
	await get_tree().create_timer(1.2).timeout
	var bonus = int(max(time_left, 0.0)) * 10
	score += bonus
	stats_changed.emit()
	sfx("coin")
	banner.emit("COURSE CLEAR!\n\nTIME BONUS  %d" % bonus)
	await get_tree().create_timer(2.2).timeout
	checkpoint = null
	busy = false
	if level_index + 1 >= LevelData.LEVELS.size():
		_end("victory")
	else:
		max_level = max(max_level, level_index + 1)
		_save()
		start_level(level_index + 1)


func _end(mode):
	end_mode = mode
	best_score = max(best_score, score)
	_save()
	goto_scene(END_SCENE)


func add_score(amount, pos = null):
	score += amount
	stats_changed.emit()
	if pos != null:
		popup(str(amount), pos)


func add_coin(pos = null, play_sound = false):
	coins += 1
	score += 10
	if coins >= 100:
		coins -= 100
		lives += 1
		sfx("power_up", 1.3)
		if pos != null:
			popup("1UP!", pos, Color(0.5, 1.0, 0.5))
	if play_sound:
		sfx("coin")
	coin_collected.emit()
	stats_changed.emit()


func _save():
	var cfg = ConfigFile.new()
	cfg.set_value("game", "best_score", best_score)
	cfg.set_value("game", "max_level", max_level)
	cfg.save(SAVE_PATH)


func _load():
	var cfg = ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		best_score = cfg.get_value("game", "best_score", 0)
		max_level = clamp(cfg.get_value("game", "max_level", 0), 0, LevelData.LEVELS.size() - 1)


# ---------------------------------------------------------------- helpers

func sfx(sound, pitch = 1.0, volume_db = 0.0):
	var p = _sfx_players[_sfx_next]
	_sfx_next = (_sfx_next + 1) % _sfx_players.size()
	p.stream = SOUNDS[sound]
	p.pitch_scale = pitch
	p.volume_db = volume_db
	p.play()


## Pronto's chiptune laugh.
func laugh():
	for i in 5:
		sfx("tap", 1.9 - i * 0.13, 2.0)
		await get_tree().create_timer(0.085).timeout


func label(text, font_size = 16, color = Color.WHITE, bold = false):
	var l = Label.new()
	l.text = text
	l.add_theme_font_override("font", FONT_BOLD if bold else FONT)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.12))
	l.add_theme_constant_override("outline_size", int(max(2, font_size / 4)))
	return l


## Small floating text in the level (scores, 1UP, ...).
func popup(text, pos, color = Color.WHITE):
	var scene = get_tree().current_scene
	if scene == null:
		return
	var l = label(text, 8, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(100, 10)
	l.position = pos + Vector2(-50, -22)
	l.z_index = 50
	scene.add_child(l)
	var tw = l.create_tween()
	tw.tween_property(l, "position:y", l.position.y - 18, 0.7)
	tw.tween_callback(l.queue_free)


func sky(top: Color, bottom: Color):
	var g = Gradient.new()
	g.set_color(0, top)
	g.set_color(1, bottom)
	var t = GradientTexture2D.new()
	t.gradient = g
	t.fill_from = Vector2(0, 0)
	t.fill_to = Vector2(0, 1)
	t.width = 8
	t.height = 128
	var r = TextureRect.new()
	r.texture = t
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func frames_for(sheet):
	if _frames.has(sheet):
		return _frames[sheet]
	var sf = SpriteFrames.new()
	sf.remove_animation("default")
	for anim in ANIMS:
		var info = ANIMS[anim]
		var tex = load("%s_%s.png" % [sheet, info[0]])
		sf.add_animation(anim)
		sf.set_animation_speed(anim, info[2])
		sf.set_animation_loop(anim, info[3])
		for i in info[1]:
			var at = AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(i * 32, 0, 32, 32)
			sf.add_frame(anim, at)
	_frames[sheet] = sf
	return sf


func slime_frames(path):
	if _frames.has(path):
		return _frames[path]
	var tex = load(path)
	var sf = SpriteFrames.new()
	sf.remove_animation("default")
	sf.add_animation("walk")
	sf.set_animation_speed("walk", 8)
	for i in 4:
		var at = AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * 24, 24, 24, 24)
		sf.add_frame("walk", at)
	_frames[path] = sf
	return sf


func hue_material(shift):
	if shift == 0.0:
		return null
	if not _mats.has(shift):
		var m = ShaderMaterial.new()
		m.shader = _hue_shader
		m.set_shader_parameter("shift", shift)
		_mats[shift] = m
	return _mats[shift]


func apply_look(node: CanvasItem, ch):
	node.material = hue_material(ch.hue)
	node.modulate = ch.tint


## An animated sprite of a hero, for menus.
func char_sprite(ch, anim = "idle", sprite_scale = 4.0):
	var s = AnimatedSprite2D.new()
	s.sprite_frames = frames_for(ch.sheet)
	apply_look(s, ch)
	s.scale = Vector2(sprite_scale, sprite_scale)
	s.play(anim)
	return s


func atlas(tex, region: Rect2):
	var at = AtlasTexture.new()
	at.atlas = tex
	at.region = region
	return at
