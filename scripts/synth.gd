extends Node
## Autoload "Music": a tiny chiptune tracker. Every track is composed from a seed
## (scale, chord progression, drum style) and rendered to a looping sample in a
## background thread when the game starts, so there are no music files to ship.
## Several tracks use the Hijaz scale and a darbouka rhythm for a Tunisian flavour.
##
## Music.play_track("fight0") switches track; the same name twice does nothing.

const RATE = 11025
const BARS = 8

const HIJAZ = [0, 1, 4, 5, 7, 8, 10]
const MINOR = [0, 2, 3, 5, 7, 8, 10]
const DORIAN = [0, 2, 3, 5, 7, 9, 10]
const PHRYGIAN = [0, 1, 3, 5, 7, 8, 10]
const MAJOR = [0, 2, 4, 5, 7, 9, 11]

# bpm, root (midi note), scale, chord progression (scale degrees), drum style, seed, density of the melody
const SONGS = {
	"title": {"bpm": 104, "root": 50, "scale": HIJAZ, "prog": [0, 0, 3, 4], "drums": "maqsum", "seed": 11, "density": 0.6},
	"map": {"bpm": 96, "root": 48, "scale": DORIAN, "prog": [0, 3, 0, 4], "drums": "soft", "seed": 5, "density": 0.5},
	"fight0": {"bpm": 140, "root": 48, "scale": MAJOR, "prog": [0, 5, 3, 4], "drums": "rock", "seed": 3, "density": 0.75},
	"tavern": {"bpm": 126, "root": 52, "scale": HIJAZ, "prog": [0, 1, 0, 6], "drums": "maqsum", "seed": 21, "density": 0.8},
	"camp": {"bpm": 84, "root": 45, "scale": MINOR, "prog": [0, 5, 3, 4], "drums": "soft", "seed": 9, "density": 0.45},
	"game": {"bpm": 158, "root": 55, "scale": MAJOR, "prog": [0, 3, 4, 0], "drums": "rock", "seed": 23, "density": 0.85},
	"fight1": {"bpm": 132, "root": 50, "scale": HIJAZ, "prog": [0, 3, 1, 0], "drums": "maqsum", "seed": 7, "density": 0.8},
	"boss": {"bpm": 166, "root": 43, "scale": HIJAZ, "prog": [0, 1, 0, 4], "drums": "drive", "seed": 17, "density": 0.9},
	"fight2": {"bpm": 150, "root": 45, "scale": PHRYGIAN, "prog": [0, 5, 6, 4], "drums": "drive", "seed": 13, "density": 0.8},
}

var player: AudioStreamPlayer
var cache = {}
var current = ""
var playing = ""
var thread: Thread
var quitting = false


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	player = AudioStreamPlayer.new()
	player.bus = "Music"
	player.volume_db = -9.0
	add_child(player)
	thread = Thread.new()
	thread.start(_render_all)
	play_track("title")


func _exit_tree():
	quitting = true
	if thread and thread.is_started():
		thread.wait_to_finish()


func play_track(track):
	if not SONGS.has(track) or track == current:
		return
	current = track
	_start()


func _start():
	if cache.has(current) and playing != current:
		playing = current
		player.stream = cache[current]
		player.play()


func _track_ready(track, stream):
	cache[track] = stream
	_start()


func _render_all():
	for track in SONGS:
		if quitting:
			return
		_track_ready.call_deferred(track, _render(SONGS[track]))


# ---------------------------------------------------------------- composing

func _freq(song, degree):
	var scale = song.scale
	var n = scale.size()
	var midi = song.root + 12 * int(floor(degree / float(n))) + scale[posmod(degree, n)]
	return 440.0 * pow(2.0, (midi - 69) / 12.0)


## A two-bar melody (16 eighth notes) as [degree or null, ...]: a random walk that
## likes chord tones on the beat.
func _phrase(rng, density):
	var out = []
	var deg = [0, 2, 4][rng.randi() % 3] + 7
	for e in 16:
		if rng.randf() > density and e % 4 != 0:
			out.append(null)
			continue
		deg += [-2, -1, -1, 0, 1, 1, 2, 3][rng.randi() % 8]
		if e % 4 == 0 and rng.randf() < 0.6:
			deg = int(round(deg / 2.0)) * 2
		deg = clamp(deg, 4, 14)
		out.append(deg)
	return out


func _render(song):
	var rng = RandomNumberGenerator.new()
	rng.seed = song.seed
	var step = int(RATE * 60.0 / song.bpm / 4.0)   # one sixteenth note, in samples
	var total = step * 16 * BARS
	var buf = PackedFloat32Array()
	buf.resize(total)
	var a = _phrase(rng, song.density)
	var b = _phrase(rng, song.density)
	var form = [a, a, b, a]   # each entry covers two bars
	for bar in BARS:
		if quitting:
			break
		var chord = song.prog[bar % song.prog.size()]
		var at = bar * 16 * step
		# bass: root and fifth, an octave and a half down
		for s in [0, 6, 8, 11, 14]:
			var d = chord - 7 + (4 if s == 8 else 0)
			_tone(buf, at + s * step, step * 2, _freq(song, d) * 0.5, 0.30, 2)
		# arpeggio: chord tones in sixteenths, quiet
		for s in 16:
			if s % 2 == 0 or song.drums == "drive":
				var d = chord + [0, 2, 4, 7][s % 4]
				_tone(buf, at + s * step, step, _freq(song, d), 0.07, 1)
		# melody
		var phrase = form[(bar / 2) % form.size()]
		for e in 8:
			var note = phrase[(bar % 2) * 8 + e]
			if note != null:
				var hold = 2 if e < 7 and phrase[(bar % 2) * 8 + e + 1] == null else 1
				_tone(buf, at + e * 2 * step, step * 2 * hold, _freq(song, note + chord), 0.16, 0)
		# drums
		for s in 16:
			var p = at + s * step
			match song.drums:
				"maqsum":   # DUM tek . tek DUM . tek .
					if s == 0 or s == 8:
						_drum(buf, p, 0, 0.5, rng)
					elif s == 2 or s == 6 or s == 12:
						_drum(buf, p, 3, 0.3, rng)
					elif s == 14 and bar % 2 == 1:
						_drum(buf, p, 3, 0.2, rng)
				"rock":
					if s % 8 == 0:
						_drum(buf, p, 0, 0.5, rng)
					elif s % 8 == 4:
						_drum(buf, p, 1, 0.3, rng)
					elif s % 2 == 0:
						_drum(buf, p, 2, 0.1, rng)
				"drive":
					if s % 4 == 0:
						_drum(buf, p, 0, 0.5, rng)
					if s % 8 == 4:
						_drum(buf, p, 1, 0.3, rng)
					if s % 2 == 1:
						_drum(buf, p, 2, 0.1, rng)
				_:
					if s == 0:
						_drum(buf, p, 0, 0.35, rng)
					elif s == 8:
						_drum(buf, p, 2, 0.12, rng)
	# to 16-bit samples
	var bytes = PackedByteArray()
	bytes.resize(total * 2)
	for i in total:
		bytes.encode_s16(i * 2, int(clamp(buf[i], -1.0, 1.0) * 30000.0))
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = total
	return wav


## wave: 0 = square, 1 = thin pulse, 2 = triangle
func _tone(buf, start, length, freq, amp, wave):
	var n = buf.size()
	var inc = freq / RATE
	var phase = 0.0
	var inv = 1.0 / length
	for i in length:
		phase += inc
		phase -= floor(phase)
		var v
		if wave == 0:
			v = 1.0 if phase < 0.5 else -1.0
		elif wave == 1:
			v = 1.0 if phase < 0.22 else -1.0
		else:
			v = 4.0 * abs(phase - 0.5) - 1.0
		var env = 1.0 - i * inv
		if i < 40:
			env *= i / 40.0
		var idx = start + i
		if idx >= n:
			idx -= n
		buf[idx] += v * amp * env


## kind: 0 = kick / dum, 1 = snare, 2 = hat, 3 = tek (darbouka rim)
func _drum(buf, start, kind, amp, rng):
	var n = buf.size()
	var length = [1400, 1100, 300, 500][kind]
	var phase = 0.0
	for i in length:
		var k = 1.0 - i / float(length)
		var v
		if kind == 0:
			phase += (45.0 + 110.0 * k * k) / RATE
			v = sin(phase * TAU)
		elif kind == 3:
			phase += 620.0 / RATE
			v = sin(phase * TAU) * 0.6 + rng.randf_range(-0.4, 0.4)
		else:
			v = rng.randf_range(-1.0, 1.0)
		var idx = start + i
		if idx >= n:
			idx -= n
		buf[idx] += v * amp * k * k
