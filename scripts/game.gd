extends Node
## Autoload "Game": the roguelike run (map, stages, boons), the permanent camp upgrades,
## characters, input schemes, sounds, scene transitions and the HUD.
##
## A run = 3 acts. Each act is a branching map of nodes (fights, ambushes, elites, minigames,
## taverns) ending in a boss. Clearing a node lets you pick a boon. When the run ends you
## keep DINARS, which buy permanent upgrades at the camp: every run starts a little stronger.

signal stats_changed
signal coin_collected
signal boss_changed(hp, max_hp)
signal banner(text)

const LevelData = preload("res://scripts/level_data.gd")
const RunGen = preload("res://scripts/run_gen.gd")
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
const TAVERN_SCENE = "res://scenes/tavern.tscn"
const SHMUP_SCENE = "res://scenes/shmup.tscn"
const GALLERY_SCENE = "res://scenes/gallery.tscn"
const MAP_SCENE = "res://scenes/map.tscn"
const CAMP_SCENE = "res://scenes/camp.tscn"
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
const MAX_PLAYERS = 4
const MAX_MANA = 100.0
const MANA_REGEN = 1.0

# The three acts of a run.
const ACTS = [
	{"name": "THE GREEN COAST", "themes": ["grass", "autumn", "medina", "swamp"], "boss": "queen", "music": "fight0"},
	{"name": "THE DEEP SOUTH", "themes": ["sahara", "night", "ice", "sky"], "boss": "sky", "music": "fight1"},
	{"name": "PINKY'S KEEP", "themes": ["cave", "space", "castle"], "boss": "boss", "music": "fight2"},
]

# Boons: found during a run (one after every cleared node, or bought in a tavern). Lost when the run ends.
const BOONS = [
	{"id": "heart", "name": "CHECHIA", "max": 5, "desc": "A FINE RED HAT. +1 MAX HEART FOR EVERYONE."},
	{"id": "couscous", "name": "COUSCOUS", "max": 1, "desc": "A HUGE PLATE. +2 MAX HEARTS, BUT YOU RUN A LITTLE SLOWER."},
	{"id": "mana", "name": "JASMINE", "max": 3, "desc": "SMELLS LIKE SUMMER. MANA REFILLS 50% FASTER."},
	{"id": "ult", "name": "BOUKHA", "max": 2, "desc": "FIG SPIRIT. ULTIMATES COST 25% LESS MANA."},
	{"id": "brik", "name": "BRIK", "max": 1, "desc": "CRISPY. EVERY KILL GIVES DOUBLE MANA."},
	{"id": "boots", "name": "BALGHA", "max": 2, "desc": "POINTY SLIPPERS. STOMPS DEAL +1 DAMAGE."},
	{"id": "shoes", "name": "CLOUD SHOES", "max": 2, "desc": "ONE MORE JUMP IN MID-AIR."},
	{"id": "dash", "name": "KAHWA ARBI", "max": 2, "desc": "STRONG COFFEE. YOUR MOVE RECHARGES 25% FASTER AND YOU RUN FASTER."},
	{"id": "shleka", "name": "IRON SHLEKA", "max": 2, "desc": "YOUR THROWN SANDALS DEAL +1 DAMAGE."},
	{"id": "rapid", "name": "DOUBLE SHLEKA", "max": 1, "desc": "BOTH SANDALS: YOU THROW TWICE AS FAST."},
	{"id": "harissa", "name": "HARISSA", "max": 1, "desc": "TOO SPICY. YOUR MOVE BURNS EVERY ENEMY NEAR YOU."},
	{"id": "thorns", "name": "HENDI", "max": 1, "desc": "PRICKLY PEAR. ENEMIES THAT HURT YOU TAKE 2 DAMAGE."},
	{"id": "guard", "name": "CARTHAGE SHIELD", "max": 1, "desc": "BLOCKS THE FIRST HIT YOU TAKE IN EVERY STAGE."},
	{"id": "makroudh", "name": "MAKROUDH", "max": 2, "desc": "SWEET. HEALS 1 HEART AT THE START OF EVERY STAGE."},
	{"id": "vamp", "name": "LABLABI", "max": 1, "desc": "HEARTY SOUP. EVERY 10 KILLS HEAL 1 HEART."},
	{"id": "magnet", "name": "KHOMSA", "max": 2, "desc": "LUCKY HAND. ENEMIES DROP 50% MORE GOLD."},
]

# Camp upgrades: bought with dinars, kept forever. Level n costs cost * (n + 1).
const META = [
	{"id": "vigor", "name": "VIGOR", "max": 3, "cost": 40, "desc": "+1 MAX HEART AT THE START OF EVERY RUN."},
	{"id": "purse", "name": "FAT PURSE", "max": 4, "cost": 25, "desc": "START EVERY RUN WITH 25 MORE GOLD."},
	{"id": "focus", "name": "FOCUS", "max": 3, "cost": 35, "desc": "START EVERY STAGE WITH 25 MORE MANA."},
	{"id": "muscle", "name": "MUSCLE", "max": 2, "cost": 80, "desc": "BOSSES START WITH 2 LESS HEALTH."},
	{"id": "revive", "name": "SECOND WIND", "max": 2, "cost": 70, "desc": "+1 LIFE PER RUN."},
	{"id": "luck", "name": "BARAKA", "max": 1, "cost": 150, "desc": "CHOOSE BETWEEN 4 BOONS INSTEAD OF 3."},
	{"id": "greed", "name": "HAGGLER", "max": 3, "cost": 50, "desc": "EARN 20% MORE DINARS."},
]

var PLAYER_COLORS = [Color(0.35, 0.75, 1.0), Color(1.0, 0.45, 0.4), Color(0.5, 0.9, 0.45), Color(1.0, 0.85, 0.3)]

# The heroes. speed / jump are multipliers, size scales the body.
var CHARACTERS = [
	{
		"name": "PRONTO", "sheet": DUDE, "hue": 0.0, "tint": Color.WHITE,
		"color": Color(0.3, 0.72, 1.0), "blurb": "FUN, RUDE, LOUD", "quote": "PRONTO! PRONTO!",
		"speed": 1.12, "talk": 0.95, "laugh": true, "size": 1.0,
		"passive": "NEVER SHUTS UP. RUNS FASTER THAN EVERYONE ELSE.",
		"move": {"id": "dash", "name": "TURBO DASH", "cd": 0.7,
			"desc": "A BURST OF SPEED, ON THE GROUND OR IN THE AIR. NOTHING CAN HIT HIM WHILE DASHING."},
		"ult": {"id": "rush", "name": "PRONTO RUSH", "cost": 100,
			"desc": "3 SECONDS OF UNSTOPPABLE SPEED. EVERYTHING HE TOUCHES GOES FLYING."},
		"lines": {
			"start": ["PRONTO! PRONTO!", "MOVE IT, GRANDPAS!", "TRY TO KEEP UP, LOSERS! HAHA", "I CARRY THIS TEAM."],
			"stomp": ["HAHAHA! SIT DOWN!", "TOO SLOW, UGLY!", "SQUISH! PRONTO!", "YOUR MOM JUMPS BETTER!", "NEXT CLOWN!"],
			"hurt": ["HEY! RUDE!", "OW! WHO DID THAT?!", "I'LL REMEMBER YOUR FACE!", "THAT TICKLES, IDIOT!"],
			"mock": ["HAHAHA! NICE ONE, GENIUS!", "GET UP, PRONTO! HAHA", "MY GRANDMA JUMPS BETTER!", "AGAIN?! HAHAHA", "WOW. JUST WOW."],
			"power": ["MINE! ALL MINE! HAHA", "FINDERS KEEPERS!"],
			"win": ["TOO EASY! PRONTO!", "WHO'S THE BEST? ME. PRONTO!", "YOU'RE WELCOME, NOBODIES."],
			"idle": ["PRONTO PRONTO PRONTO...", "ARE WE SLEEPING? HAHA", "HELLO?! MOVE!", "DID I TELL YOU ABOUT THE TIME I...", "BORING. BORING. BORING."],
			"death": ["PRONTOOOOO...", "I MEANT TO DO THAT!", "LAG! IT WAS LAG!"],
			"ult": ["PRONTO RUUUUSH!", "CATCH ME, SNAILS! HAHAHA!"],
		},
	},
	{
		"name": "ELLI", "sheet": OWLET, "hue": 0.0, "tint": Color.WHITE,
		"color": Color(1.0, 0.55, 0.5), "blurb": "SMALL AND ANGRY", "quote": "WHAT ARE YOU LOOKING AT?!",
		"jump": 1.1, "size": 0.72, "talk": 0.5, "rage": true,
		"passive": "RAGE: GETTING HURT MAKES ELLI FURIOUS FOR 6 SECONDS (FASTER, DOUBLE DAMAGE). CLINGS TO WALLS AND JUMPS OFF THEM.",
		"move": {"id": "dive", "name": "DIVE KICK", "cd": 0.5,
			"desc": "IN THE AIR: A DIAGONAL KICK THAT BOUNCES OFF ENEMIES."},
		"ult": {"id": "slam", "name": "TANTRUM", "cost": 100,
			"desc": "ROCKETS INTO THE SKY THEN CRASHES DOWN SCREAMING. THE SHOCKWAVE SMASHES EVERYTHING NEARBY."},
		"lines": {
			"start": ["WHAT?!", "LET'S GET THIS OVER WITH!", "DON'T CALL ME SMALL!"],
			"stomp": ["STAY DOWN!", "WHO'S SMALL NOW?!", "GRRRR!", "AND STAY THERE!"],
			"hurt": ["THAT'S IT!!!", "OH YOU'RE DEAD!", "AAAARGH!", "NOW I'M ANGRY!"],
			"mock": ["USELESS!", "GET UP!!", "SERIOUSLY?!"], "power": ["GIVE ME THAT!"],
			"win": ["FINALLY!", "I'M STILL ANGRY."], "idle": ["HURRY UP!!", "I HATE WAITING!", "GRRR..."],
			"death": ["THIS ISN'T OVER!", "AAAAAAARGH!"], "ult": ["RAAAAAAAAGH!!!", "I SAID DON'T CALL ME SMALL!"],
		},
	},
	{
		"name": "SHEE", "sheet": DUDE, "hue": 0.2, "tint": Color.WHITE,
		"color": Color(0.72, 0.5, 1.0), "blurb": "COOL DICTATOR", "quote": "MY PEOPLE LOVE ME.",
		"fall": 0.72, "size": 0.95, "talk": 0.45, "shades": true,
		"passive": "TOO COOL TO FALL: HOLD JUMP IN THE AIR TO GLIDE. NEVER TAKES OFF THE SUNGLASSES.",
		"move": {"id": "blink", "name": "VIP ENTRANCE", "cd": 1.2,
			"desc": "TELEPORTS A SHORT WAY IN ANY DIRECTION, EVEN STRAIGHT UP OR THROUGH ENEMIES."},
		"ult": {"id": "decree", "name": "THE DECREE", "cost": 100,
			"desc": "A SUPREME ORDER: EVERY ENEMY ON SCREEN FREEZES AND SALUTES FOR 4 SECONDS, AND TAKES 1 DAMAGE."},
		"lines": {
			"start": ["MY PEOPLE LOVE ME.", "THE SUPREME LEADER HAS ARRIVED.", "ROLL OUT THE CARPET."],
			"stomp": ["EXILED.", "BY DECREE.", "TREASON IS PUNISHED.", "KNEEL."],
			"hurt": ["A COUP?!", "GUARDS! ...GUARDS?", "THIS WILL BE ERASED FROM HISTORY."],
			"mock": ["YOU ARE DISMISSED.", "NO MEDAL FOR YOU.", "I'VE SEEN BETTER COUPS."],
			"power": ["A GIFT FROM MY PEOPLE.", "NATIONALIZED."],
			"win": ["99.8% OF THE VOTE. AS USUAL.", "BUILD ME A STATUE."],
			"idle": ["I COULD RULE THIS PLACE.", "WHERE IS MY TENT?", "A FOUR HOUR SPEECH, PERHAPS?"],
			"death": ["I'LL BE BACK. FOR LIFE.", "HISTORY WILL ABSOLVE ME."],
			"ult": ["BY SUPREME DECREE: FREEZE!", "ALL OF YOU. SALUTE."],
		},
	},
	{
		"name": "GUENI", "sheet": DUDE, "hue": -0.22, "tint": Color.WHITE,
		"color": Color(0.45, 0.9, 0.5), "blurb": "HIGH ENGINEER", "quote": "IT WORKS ON MY BENCH.",
		"hearts": 5, "speed": 0.92, "size": 1.35, "talk": 0.4, "smoke": true,
		"passive": "SENIOR HARDWARE ENGINEER, VERY RELAXED. 5 HEARTS. DOWN IN THE AIR = GROUND POUND.",
		"move": {"id": "smoke", "name": "SMOKE BREAK", "cd": 3.0,
			"desc": "PUFFS A BIG GREEN CLOUD. ENEMIES INSIDE GET DIZZY AND FORGET WHAT THEY WERE DOING."},
		"ult": {"id": "firewall", "name": "SHORT CIRCUIT", "cost": 100,
			"desc": "OVERVOLTAGE! FULLY HEALS THE TEAM, SHIELDS EVERYONE FOR 4 SECONDS AND ZAPS NEARBY ENEMIES."},
		"lines": {
			"start": ["IT WORKS ON MY BENCH.", "DUUUDE. WHERE ARE WE?", "I ROUTED THIS LEVEL MYSELF."],
			"stomp": ["BUG FIXED.", "THAT'S A SHORT.", "DEBUGGED, MAN.", "PULL-DOWN RESISTOR."],
			"hurt": ["WHOA. NOT COOL.", "THAT'S A FEATURE.", "WHO TOUCHED MY PROBE?"],
			"mock": ["SKILL ISSUE, BRO.", "DID YOU READ THE DATASHEET?", "HEHEHE... SORRY."],
			"power": ["FREE SAMPLES!", "UPGRADE!"],
			"win": ["SA77IT!", "SHIP IT.", "TIME FOR A BREAK."],
			"idle": ["I NEED A BREAK...", "IS IT 4:20 YET?", "THE GROUND PLANE IS SO... GREEN.", "I'M HUNGRY."],
			"death": ["CTRL+Z! CTRL+Z!", "MAGIC SMOKE ESCAPED..."],
			"ult": ["OVERVOLTAGE, BABY!", "LET THE MAGIC SMOKE OUT!"],
		},
	},
	{
		"name": "IHEB", "sheet": OWLET, "hue": 0.0, "tint": Color(1.0, 0.72, 0.42),
		"color": Color(1.0, 0.7, 0.35), "blurb": "VILLAGE AND BEER", "quote": "SALUTE!",
		"always_rocks": true, "size": 1.15, "talk": 0.5, "beer": true,
		"passive": "ALWAYS HAS A BEER IN HAND: THROWS BOTTLES IN AN ARC, FASTER THAN ANYONE THROWS SANDALS.",
		"move": {"id": "rockjump", "name": "FOAM JUMP", "cd": 1.0,
			"desc": "SHAKES THE BOTTLE, POINTS IT DOWN AND RIDES THE FOAM UPWARDS. WORKS IN MID-AIR."},
		"ult": {"id": "storm", "name": "BIRRA STORM", "cost": 100,
			"desc": "A WHOLE CRATE RAINS FROM THE SKY IN FRONT OF HIM. EACH BOTTLE HITS TWICE AS HARD."},
		"lines": {
			"start": ["ANDIAMO, RAGAZZI!", "SALUTE!", "IN MY VILLAGE THIS IS NOTHING."],
			"stomp": ["MAMMA MIA!", "ARRIVEDERCI!", "BASTA!", "CIAO CIAO!"],
			"hurt": ["PORCA MISERIA!", "MY BEER!!", "AY! ATTENZIONE!"],
			"mock": ["CHE DISASTRO! HAHA", "HAI BEVUTO TROPPO?"], "power": ["BELLISSIMO!", "GRAZIE MILLE!"],
			"win": ["PERFETTO! UN'ALTRA BIRRA!", "SALUTE A TUTTI!"],
			"idle": ["UNA BIRRA, PER FAVORE...", "IN MY VILLAGE WE HAVE ONE GOAT.", "DOLCE FAR NIENTE..."],
			"death": ["MAMMA MIAAAA...", "THE BEER... SAVE THE BEER..."],
			"ult": ["BIRRA PER TUTTI!!", "OFFRO IO!"],
		},
	},
]

# --- permanent (saved) ---
var dinars = 0
var meta = {}             # camp upgrade id -> level
var best_depth = 0
var best_score = 0
var wins = 0

# --- run state ---
var players = []          # [{char, input, hearts, rocks, out, mana}]
var score = 0
var gold = 0
var lives = 1
var upgrades = {}         # boon id -> how many
var act = 0
var depth = 0             # nodes cleared in this run
var kills = 0
var map = []              # rows of nodes: {type, lane, links, seed}
var map_row = -1          # row of the node the team stands on (-1 = before the first row)
var map_lane = 1
var stage = {}            # definition of the stage being played (see RunGen.make_stage)
var pending = null        # reward waiting to be picked on the map: {"gold", "boons"}
var earned = 0            # dinars paid out when the run ended
var time_left = 0.0
var checkpoint = null     # Vector2 or null
var end_mode = "gameover"
var busy = false
var level_node = null
var boss_name = ""

var hud
var _fade: ColorRect
var _card: Label
var _flash: ColorRect
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
	stage = RunGen.make_stage(0, 0, "fight", randi(), 0)
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
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(_flash)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	_scheme("kl", {"left": [KEY_A], "right": [KEY_D], "up": [KEY_W], "down": [KEY_S], "jump": [KEY_W, KEY_SPACE],
			"action": [KEY_F], "dash": [[KEY_SHIFT, KEY_LOCATION_LEFT], KEY_G], "ult": [KEY_E, KEY_Q]}, -2)
	_scheme("kr", {"left": [KEY_LEFT], "right": [KEY_RIGHT], "up": [KEY_UP], "down": [KEY_DOWN], "jump": [KEY_UP],
			"action": [KEY_ENTER, KEY_KP_ENTER, KEY_KP_0], "dash": [[KEY_SHIFT, KEY_LOCATION_RIGHT], KEY_KP_2],
			"ult": [[KEY_CTRL, KEY_LOCATION_RIGHT], KEY_KP_1]}, -2)
	for i in 4:
		_scheme("pad%d" % i, {}, i)
	_scheme("solo", {"left": [KEY_A, KEY_LEFT], "right": [KEY_D, KEY_RIGHT], "up": [KEY_W, KEY_UP], "down": [KEY_S, KEY_DOWN],
			"jump": [KEY_W, KEY_SPACE, KEY_UP], "action": [KEY_F, KEY_J, KEY_ENTER, KEY_KP_0],
			"dash": [KEY_SHIFT, KEY_G, KEY_X, KEY_KP_2], "ult": [KEY_E, KEY_Q, KEY_R, KEY_K, KEY_CTRL, KEY_KP_1]}, 0)
	_action("m_up", [KEY_UP, KEY_W], [JOY_BUTTON_DPAD_UP])
	_action("m_down", [KEY_DOWN, KEY_S], [JOY_BUTTON_DPAD_DOWN])
	_action("m_ok", [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE], [JOY_BUTTON_A])
	_action("m_back", [KEY_ESCAPE], [])
	_action("pause", [KEY_ESCAPE, KEY_P], [JOY_BUTTON_START])
	# Menus also listen to every gamepad's left stick.
	for side in [[-1.0, "m_up"], [1.0, "m_down"]]:
		var e = InputEventJoypadMotion.new()
		e.device = -1
		e.axis = JOY_AXIS_LEFT_Y
		e.axis_value = side[0]
		InputMap.action_add_event(side[1], e)


func _action(action, keys, buttons, device = -1):
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.4)
	for k in keys:
		var e = InputEventKey.new()
		if k is Array:   # [key, left or right side of the keyboard]
			e.physical_keycode = k[0]
			e.location = k[1]
		else:
			e.physical_keycode = k
		InputMap.action_add_event(action, e)
	for b in buttons:
		var e = InputEventJoypadButton.new()
		e.device = device
		e.button_index = b
		InputMap.action_add_event(action, e)


func _scheme(prefix, keys, pad):
	var buttons = {
		"left": [JOY_BUTTON_DPAD_LEFT], "right": [JOY_BUTTON_DPAD_RIGHT], "up": [JOY_BUTTON_DPAD_UP],
		"down": [JOY_BUTTON_DPAD_DOWN], "jump": [JOY_BUTTON_A], "action": [JOY_BUTTON_X],
		"dash": [JOY_BUTTON_B, JOY_BUTTON_LEFT_SHOULDER], "ult": [JOY_BUTTON_Y, JOY_BUTTON_RIGHT_SHOULDER],
	}
	for name in buttons:
		_action(prefix + "_" + name, keys.get(name, []), buttons[name] if pad >= 0 else [], pad)
	if pad >= 0:
		for side in [[JOY_AXIS_LEFT_X, -1.0, "_left"], [JOY_AXIS_LEFT_X, 1.0, "_right"],
				[JOY_AXIS_LEFT_Y, -1.0, "_up"], [JOY_AXIS_LEFT_Y, 1.0, "_down"]]:
			var e = InputEventJoypadMotion.new()
			e.device = pad
			e.axis = side[0]
			e.axis_value = side[1]
			InputMap.action_add_event(prefix + side[2], e)


# ---------------------------------------------------------------- the run

## The stage being played (theme, chunks, modifiers...).
func level_def():
	return stage


func char_of(slot):
	return CHARACTERS[players[slot].char]


func max_hearts(slot):
	return char_of(slot).get("hearts", 3) + up("heart") + 2 * up("couscous") + meta_level("vigor")


## How many of a boon the team holds.
func up(id):
	return upgrades.get(id, 0)


func meta_level(id):
	return meta.get(id, 0)


func ult_cost(slot):
	return char_of(slot).ult.cost * (1.0 - 0.25 * up("ult"))


## How dangerous the world is right now: enemies scale with it.
func danger():
	return depth + act * 2.0


## Makes sure there is at least one player (when a scene is run directly from the editor).
func ensure_players():
	if players.is_empty():
		players = [{"char": 0, "input": "solo", "hearts": 3, "rocks": false, "out": false, "mana": MAX_MANA}]
		lives = 1


func new_game(list):
	players = []
	for p in list:
		players.append({"char": p.char, "input": p.input, "hearts": 3, "rocks": false, "out": false, "mana": 0.0})
	score = 0
	upgrades = {}
	gold = 25 * meta_level("purse")
	lives = 1 + meta_level("revive")
	act = 0
	depth = 0
	kills = 0
	pending = null
	checkpoint = null
	for i in players.size():
		players[i].hearts = max_hearts(i)
	_new_map()
	goto_scene(MAP_SCENE)


func _new_map():
	map = RunGen.make_map(act, randi())
	map_row = -1
	map_lane = 1


## The team walks to a node of the next row of the map.
func enter_node(lane):
	if busy:
		return
	map_row += 1
	map_lane = lane
	var node = map[map_row][lane]
	match node.type:
		"tavern":
			goto_scene(TAVERN_SCENE)
		"gallery":
			goto_scene(GALLERY_SCENE)
		"sky", "boss_sky":
			stage = {"name": "%d-%d" % [act + 1, map_row + 1], "kind": node.type}
			goto_scene(SHMUP_SCENE)
		_:
			stage = RunGen.make_stage(act, map_row, node.type, node.seed, depth)
			checkpoint = null
			start_level()


## The node the team is on is finished. reward: {"gold": n, "boons": how many to pick from} or null.
func node_done(reward = null, was_boss = false):
	depth += 1
	best_depth = max(best_depth, depth)
	checkpoint = null
	if reward != null:
		gold += reward.get("gold", 0)
		if reward.get("boons", 0) > 0:
			pending = reward
	if was_boss:
		act += 1
		if act >= ACTS.size():
			_end("victory")
			return
		_new_map()
	_save()
	goto_scene(MAP_SCENE)


## `count` random boons the team can still take.
func roll_boons(count):
	var pool = BOONS.filter(func(b): return up(b.id) < b.max)
	pool.shuffle()
	return pool.slice(0, count)


func add_boon(id):
	upgrades[id] = up(id) + 1
	if id == "heart" or id == "couscous":
		for i in players.size():
			players[i].hearts = min(players[i].hearts + (2 if id == "couscous" else 1), max_hearts(i))
	stats_changed.emit()


## Hearts carry over between stages. Fallen heroes come back at full health.
func _reset_players():
	for i in players.size():
		if players[i].hearts <= 0:
			players[i].hearts = max_hearts(i)
		players[i].hearts = min(players[i].hearts + up("makroudh"), max_hearts(i))
		players[i].rocks = false
		players[i].out = false
		players[i].mana = max(players[i].mana, 25.0 * meta_level("focus"))


func start_level():
	if busy:
		return
	busy = true
	await _fade_to(1.0)
	get_tree().paused = true
	_reset_players()
	banner.emit("")
	boss_changed.emit(0, 0)
	boss_name = ""
	hud.visible = false
	_card.text = "%s  %s\n\n%s\n\n\nLIVES x %d" % [ACTS[act].name, stage.name, stage.title, lives]
	for m in stage.get("notes", []):
		_card.text += "\n\n" + m
	_card.visible = true
	Music.play_track("boss" if stage.kind == "boss" else ACTS[act].music)
	get_tree().change_scene_to_file(ASCII_SCENE)
	await get_tree().create_timer(1.9).timeout
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
		start_level()
	else:
		_end("gameover")


func level_complete():
	if busy:
		return
	busy = true
	sfx("power_up")
	banner.emit("STAGE CLEAR!")
	await get_tree().create_timer(1.2).timeout
	var bonus = int(max(time_left, 0.0)) * 10
	var pay = stage.get("pay", 10) + int(max(time_left, 0.0)) / 20
	score += bonus
	stats_changed.emit()
	sfx("coin")
	banner.emit("STAGE CLEAR!\n\nTIME BONUS  %d\n\n+%d GOLD" % [bonus, pay])
	await get_tree().create_timer(2.0).timeout
	busy = false
	var choices = 3 + meta_level("luck") + (1 if stage.kind == "elite" else 0)
	node_done({"gold": pay, "boons": choices}, stage.kind == "boss")


## The run is over: pay out dinars for the camp.
func _end(mode):
	end_mode = mode
	best_score = max(best_score, score)
	earned = depth * 4 + act * 25 + gold / 10 + (80 if mode == "victory" else 0)
	earned = int(earned * (1.0 + 0.2 * meta_level("greed")))
	dinars += earned
	if mode == "victory":
		wins += 1
	_save()
	goto_scene(END_SCENE)


func buy_meta(item):
	var level = meta_level(item.id)
	var cost = item.cost * (level + 1)
	if level >= item.max or dinars < cost:
		return false
	dinars -= cost
	meta[item.id] = level + 1
	_save()
	return true


func add_score(amount, pos = null):
	score += amount
	stats_changed.emit()
	if pos != null:
		popup(str(amount), pos)


## A coin is one gold piece.
func add_coin(_pos = null, play_sound = false):
	gold += 1
	score += 10
	if play_sound:
		sfx("coin")
	coin_collected.emit()
	stats_changed.emit()


func add_gold(amount, pos = null):
	gold += amount
	stats_changed.emit()
	if pos != null:
		popup("+%d G" % amount, pos + Vector2(0, -10), Color(1.0, 0.85, 0.3))


## An enemy died: counts towards the soup.
func add_kill():
	kills += 1
	if up("vamp") > 0 and kills % 10 == 0 and level_node != null and is_instance_valid(level_node):
		for p in level_node.players:
			if not p.dead:
				p.heal()


func _save():
	var cfg = ConfigFile.new()
	cfg.set_value("game", "best_score", best_score)
	cfg.set_value("meta", "dinars", dinars)
	cfg.set_value("meta", "levels", meta)
	cfg.set_value("meta", "best_depth", best_depth)
	cfg.set_value("meta", "wins", wins)
	cfg.save(SAVE_PATH)


func _load():
	var cfg = ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		best_score = cfg.get_value("game", "best_score", 0)
		dinars = cfg.get_value("meta", "dinars", 0)
		meta = cfg.get_value("meta", "levels", {})
		best_depth = cfg.get_value("meta", "best_depth", 0)
		wins = cfg.get_value("meta", "wins", 0)


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


## Small floating text in the level (scores, gold, ...).
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


## An animated sprite of a hero, for menus. Scaled by the hero's size;
## use stand() to put its feet on a line.
func char_sprite(ch, anim = "idle", sprite_scale = 4.0):
	var s = AnimatedSprite2D.new()
	s.sprite_frames = frames_for(ch.sheet)
	apply_look(s, ch)
	var k = sprite_scale * ch.get("size", 1.0)
	s.scale = Vector2(k, k)
	s.play(anim)
	return s


func atlas(tex, region: Rect2):
	var at = AtlasTexture.new()
	at.atlas = tex
	at.region = region
	return at


## Puts a char_sprite's feet at `feet` (frames are 32px tall, centred).
func stand(s: AnimatedSprite2D, feet: Vector2):
	s.position = feet - Vector2(0, 16.0 * s.scale.y)


# ---------------------------------------------------------------- mana / juice

## Mana for every living hero (enemy kills are a team effort).
func give_mana_all(amount):
	if level_node == null or not is_instance_valid(level_node):
		return
	for p in level_node.players:
		if not p.dead:
			p.add_mana(amount)


## Quick full-screen flash (ultimates, boss hits).
func flash(color: Color, alpha = 0.45, time = 0.35):
	_flash.color = Color(color.r, color.g, color.b, alpha)
	var tw = create_tween()
	tw.tween_property(_flash, "color:a", 0.0, time)


func shake(amount):
	if level_node != null and is_instance_valid(level_node) and level_node.camera:
		level_node.camera.shake = max(level_node.camera.shake, amount)


## Expanding ring in the level (shockwaves, shields).
func ring(pos, radius, color: Color, time = 0.35):
	var scene = get_tree().current_scene
	if scene == null:
		return
	var r = Ring.new()
	r.color = color
	r.max_radius = radius
	r.time = time
	r.position = pos
	r.z_index = 20
	scene.add_child(r)


class Ring extends Node2D:
	var color = Color.WHITE
	var max_radius = 60.0
	var time = 0.35
	var t = 0.0

	func _process(delta):
		t += delta
		if t >= time:
			queue_free()
		queue_redraw()

	func _draw():
		var k = clamp(t / time, 0.0, 1.0)
		var c = Color(color.r, color.g, color.b, 1.0 - k)
		draw_arc(Vector2.ZERO, max_radius * k, 0, TAU, 40, c, 3.0)
		draw_arc(Vector2.ZERO, max_radius * k * 0.7, 0, TAU, 32, Color(c.r, c.g, c.b, c.a * 0.5), 1.5)
