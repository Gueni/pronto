extends CharacterBody2D
## A hero. `slot` selects which entry of Game.players (character + input device) drives it.
## Every hero has a size, a passive, a special move (dash button), a mana bar and an
## ultimate (see Game.CHARACTERS).

const Rock = preload("res://scripts/rock.gd")

const WALK_SPEED = 130.0
const RUN_SPEED = 185.0
const JUMP_VELOCITY = -300.0
const AIR_JUMP_VELOCITY = -235.0
const COYOTE_TIME = 0.1
const JUMP_BUFFER = 0.12
const INVULN_TIME = 1.6
const Smoke = preload("res://scripts/smoke.gd")
const ULT_COLORS = {
	"decree": Color(1.0, 0.85, 0.3),
	"rush": Color(0.35, 0.8, 1.0), "slam": Color(1.0, 1.0, 1.0), "wings": Color(0.8, 0.55, 1.0),
	"firewall": Color(0.45, 1.0, 0.55), "storm": Color(1.0, 0.7, 0.3),
}

var slot = 0
var level = null

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

var dead = false
var respawning = false
var locked = false
var invuln = 0.0
var coyote = 0.0
var buffer = 0.0
var air_jumps = 1
var anim_lock = 0.0
var throw_cd = 0.0
var facing = 1
var idle_time = 0.0
var bubble_time = 0.0
var ch
var inp = "solo"
var bubble: Label
var size = 1.0
var shield = 0.0       # seconds left of Gueni's firewall
var ult = ""           # id of the ultimate currently running
var ult_time = 0.0
var ult_tick = 0.0
var ult_dir = 1
var slam_falling = false
var fx_time = 0.0
var dash_cd = 0.0      # cooldown of the hero's special move
var dash_time = 0.0
var dash_vec = Vector2.ZERO
var air_dash = true    # one air move per jump
var diving = false
var dive_dir = 1
var pounding = false
var wall_time = 0.0
var wall_dir = 0
var wall_lock = 0.0
var rage = 0.0         # Elli: seconds of fury left
var guard_used = false # Carthage shield: one free hit per stage
var props: Node2D

@onready var animated_sprite = $AnimatedSprite2D
@onready var shape = $CollisionShape2D


func _ready():
	add_to_group("players")
	Game.ensure_players()
	slot = min(slot, Game.players.size() - 1)
	ch = Game.char_of(slot)
	inp = Game.players[slot].input
	animated_sprite.sprite_frames = Game.frames_for(ch.sheet)
	Game.apply_look(animated_sprite, ch)
	animated_sprite.play("idle")

	# Every hero has their own size. The body stays under one tile so nobody gets stuck.
	size = ch.get("size", 1.0)
	animated_sprite.scale = Vector2(size, size)
	animated_sprite.position = Vector2(1, -16) * size
	var circle = CircleShape2D.new()
	circle.radius = min(7.07 * size, 7.8)
	shape.shape = circle
	shape.position = Vector2(0, -circle.radius - 0.9)
	var head = -24.0 * size
	props = Props.new()
	props.hero = self
	props.z_index = 1
	add_child(props)

	bubble = Game.label("", 8, ch.color)
	bubble.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bubble.size = Vector2(160, 10)
	bubble.position = Vector2(-80, head - 28 - slot * 9 if Game.players.size() > 1 else head - 18)
	bubble.z_index = 30
	bubble.visible = false
	add_child(bubble)
	if Game.players.size() > 1:
		var tag = Game.label("P%d" % (slot + 1), 8, Game.PLAYER_COLORS[slot])
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.size = Vector2(40, 10)
		tag.position = Vector2(-20, head - 18)
		add_child(tag)
	if Game.players[slot].out:
		dead = true
		visible = false
		shape.set_deferred("disabled", true)
	else:
		get_tree().create_timer(0.4 + slot * 0.5, false).timeout.connect(func(): say("start", 1.0))


func _physics_process(delta):
	if bubble_time > 0:
		bubble_time -= delta
		if bubble_time <= 0:
			bubble.visible = false
	if dead or slot >= Game.players.size():
		return

	fx_time += delta
	props.queue_redraw()
	if rage > 0:
		rage -= delta
		animated_sprite.modulate = Color(1.0, 0.5, 0.45) if rage > 0 else ch.tint
	if shield > 0:
		shield -= delta
	if ult != "":
		_ult_process(delta)
	elif not locked:
		add_mana(Game.MANA_REGEN * (1.0 + 0.5 * Game.up("mana")) * delta)
	queue_redraw()

	if invuln > 0:
		invuln -= delta
		animated_sprite.visible = invuln <= 0 or int(invuln * 20) % 2 == 0
	throw_cd -= delta
	buffer -= delta
	dash_cd -= delta
	wall_time -= delta
	wall_lock -= delta

	var on_floor = is_on_floor()
	if on_floor:
		coyote = COYOTE_TIME
		air_jumps = 1 + Game.up("shoes")
		air_dash = true
		diving = false
		if pounding:
			_pound_land()
	else:
		coyote -= delta
		var g = gravity * (level.grav if level else 1.0)
		if velocity.y > 0:
			g *= ch.get("fall", 1.0)
		if ult == "wings":
			g *= 0.4
		velocity.y += g * delta
		if ult == "wings":
			velocity.y = min(velocity.y, 70.0)
	if ult == "slam":
		if not slam_falling and velocity.y >= 0:
			slam_falling = true
		if slam_falling:
			velocity.y = 620.0

	# Get the input direction: -1, 0, 1
	var direction = 0.0
	var running = false
	if not locked:
		var axis = Input.get_axis(inp + "_left", inp + "_right")
		if abs(axis) > 0.3:
			direction = sign(axis)
		running = Input.is_action_pressed(inp + "_action") or ult == "rush"
		if Input.is_action_just_pressed(inp + "_jump"):
			buffer = JUMP_BUFFER
		if Input.is_action_just_released(inp + "_jump") and velocity.y < -120 and ult != "slam":
			velocity.y *= 0.5
		if Input.is_action_just_pressed(inp + "_action"):
			_throw()
		if Input.is_action_just_pressed(inp + "_ult"):
			_ultimate()
		if Input.is_action_just_pressed(inp + "_dash"):
			_move()
		# Down in the air: drop fast (Gueni turns it into a ground pound).
		if Input.is_action_just_pressed(inp + "_down") and not on_floor and ult == "" and not pounding:
			if ch.move.id == "smoke":
				pounding = true
				Game.sfx("tap", 0.5)
			else:
				velocity.y = max(velocity.y, 320.0)
		# Shee glides while jump is held.
		if ch.move.id == "blink" and not on_floor and ult == "" and velocity.y > 30.0 and Input.is_action_pressed(inp + "_jump"):
			velocity.y = 30.0
		# Eli clings to walls and can jump off them.
		if ch.move.id == "dive" and not on_floor and is_on_wall() and direction != 0 and direction == -sign(get_wall_normal().x):
			velocity.y = min(velocity.y, 40.0)
			wall_time = 0.12
			wall_dir = int(sign(get_wall_normal().x))
			diving = false
	if pounding:
		velocity.y = 540.0

	# Handle jump (with coyote time, jump buffering and one air jump).
	if buffer > 0 and ult != "slam":
		if wall_time > 0 and coyote <= 0:
			velocity = Vector2(wall_dir * 210.0, JUMP_VELOCITY * ch.get("jump", 1.0))
			facing = wall_dir
			wall_time = 0
			wall_lock = 0.16
			buffer = 0
			air_jumps = 1 + Game.up("shoes")
			Game.sfx("jump", 1.2)
			_dust()
		elif coyote > 0:
			velocity.y = JUMP_VELOCITY * ch.get("jump", 1.0)
			coyote = 0
			buffer = 0
			Game.sfx("jump")
		elif air_jumps > 0 or ult == "wings":
			if ult != "wings":
				air_jumps -= 1
			velocity.y = AIR_JUMP_VELOCITY * ch.get("jump", 1.0)
			buffer = 0
			Game.sfx("jump", 1.35)
			_dust()

	# Apply movement
	var target = direction * (RUN_SPEED if running else WALK_SPEED) * ch.get("speed", 1.0)
	target *= (1.0 + 0.06 * Game.up("dash")) * (0.93 if Game.up("couscous") > 0 else 1.0) * (1.25 if rage > 0 else 1.0)
	var accel = 650.0
	if on_floor:
		accel = (1000.0 if direction != 0 else 1300.0) * (level.slip if level else 1.0)
	if ult == "rush":
		target *= 1.8
		accel = 2400.0
	elif ult == "slam":
		target *= 0.5
	if wall_lock > 0:
		accel = 150.0
	velocity.x = move_toward(velocity.x, target, accel * delta)

	# Special moves that take over the movement for a moment.
	if dash_time > 0:
		dash_time -= delta
		if ch.move.id == "charge":
			velocity.x = dash_vec.x
			_blast(14.0 * size + 4.0, 1)
		else:
			velocity = dash_vec
		if dash_time <= 0:
			velocity.x *= 0.45
		elif int(dash_time * 60) % 3 == 0:
			_afterimage()
	if diving:
		velocity = Vector2(dive_dir * 250.0, 340.0)

	# Same-screen multiplayer: don't run away from your friends.
	if level and (level.players.size() > 1 or level.scroll > 0):
		var lim = level.x_limits(self)
		if (global_position.x <= lim[0] and velocity.x < 0) or (global_position.x >= lim[1] and velocity.x > 0):
			velocity.x = 0

	move_and_slide()
	if ult == "slam" and slam_falling and is_on_floor():
		_slam_land()
	# Auto-scrolling levels: the left edge of the screen shoves you along, or squashes you.
	if level and level.scroll > 0:
		var edge = level.scroll_left()
		if global_position.x < edge - 14.0:
			die()
			return
		if global_position.x < edge + 4.0:
			velocity.x = max(velocity.x, level.scroll + 60.0)

	# Bump blocks from below.
	for i in get_slide_collision_count():
		var c = get_slide_collision(i)
		if c.get_normal().y > 0.7:
			var body = c.get_collider()
			if body and body.has_method("bump"):
				body.bump(self)
		elif dash_time > 0 and ch.move.id == "charge" and abs(c.get_normal().x) > 0.7:
			var crate = c.get_collider()
			if crate and crate.get("kind") == "crate":
				crate.bump(self)

	# Flip the Sprite
	if direction > 0:
		facing = 1
	elif direction < 0:
		facing = -1
	animated_sprite.flip_h = facing < 0

	# Play animations
	if anim_lock > 0:
		anim_lock -= delta
	elif on_floor:
		if direction == 0 and abs(velocity.x) < 20:
			animated_sprite.play("idle")
		else:
			animated_sprite.play("run")
	else:
		var f = 5
		if velocity.y < -150:
			f = 3
		elif velocity.y < 0:
			f = 4
		animated_sprite.play("jump")
		animated_sprite.set_frame_and_progress(f, 0.0)

	# Idle chatter
	if on_floor and direction == 0 and not locked:
		idle_time += delta
		if idle_time > 7.0:
			idle_time = 0.0
			say("idle", 1.0 if ch.get("laugh", false) else 0.4)
	else:
		idle_time = 0.0


## The action button: everyone throws a SHLEKA (sandal), the Tunisian way. Iheb throws bottles.
func _throw():
	if throw_cd > 0 or ult == "slam":
		return
	var beer = ch.get("beer", false)
	throw_cd = 0.4 if beer else 0.7
	if Game.up("rapid") > 0:
		throw_cd *= 0.5
	if Game.players[slot].rocks:   # rock block: fast hands until you get hurt
		throw_cd *= 0.6
	anim_lock = 0.25
	animated_sprite.play("throw")
	var r = Rock.new()
	r.from_player = true
	r.power = (1 + Game.up("shleka")) * (2 if rage > 0 else 1)
	if beer:
		r.look = "bottle"
		r.velocity = Vector2(facing * 230.0 + velocity.x * 0.3, -120.0)
	else:
		r.look = "shleka"
		r.grav = 70.0
		r.life = 0.6
		r.velocity = Vector2(facing * 270.0 + velocity.x * 0.3, -25.0)
	get_parent().add_child(r)
	r.global_position = global_position + Vector2(facing * 8, -12 * size)
	Game.sfx("tap", 0.8)


func _dust():
	var s = AnimatedSprite2D.new()
	var sf = SpriteFrames.new()
	var tex = load("res://assets/sprites/3 Dude_Monster/Double_Jump_Dust_5.png")
	sf.set_animation_loop("default", false)
	sf.set_animation_speed("default", 16)
	for i in 5:
		sf.add_frame("default", Game.atlas(tex, Rect2(i * 32, 0, 32, 32)))
	s.sprite_frames = sf
	get_parent().add_child(s)
	s.global_position = global_position + Vector2(0, -14)
	s.play("default")
	s.animation_finished.connect(s.queue_free)


## Hit by an enemy / hazard. Loses a heart, or dies.
func hurt(from_x = null):
	if dead or invuln > 0 or locked or protected():
		return
	if Game.up("guard") > 0 and not guard_used:
		guard_used = true
		invuln = 1.0
		Game.popup("BLOCKED!", global_position + Vector2(0, -24 * size), Color(0.9, 0.8, 0.5))
		Game.ring(global_position + Vector2(0, -10 * size), 22.0, Color(0.9, 0.8, 0.5))
		Game.sfx("tap", 1.7)
		return
	if ch.get("rage", false):
		rage = 6.0
	var p = Game.players[slot]
	p.hearts -= 1
	p.rocks = ch.get("always_rocks", false)
	Game.stats_changed.emit()
	if p.hearts <= 0:
		die()
		return
	Game.sfx("hurt")
	invuln = INVULN_TIME
	var away = -facing
	if from_x != null:
		away = 1 if global_position.x >= from_x else -1
	velocity = Vector2(away * 150, -210)
	anim_lock = 0.4
	animated_sprite.play("hurt")
	say("hurt")


func die():
	if dead or locked:
		return
	dead = true
	invuln = 0
	ult = ""
	dash_time = 0.0
	diving = false
	pounding = false
	shield = 0.0
	queue_redraw()
	animated_sprite.visible = true
	Game.players[slot].hearts = 0
	Game.players[slot].rocks = ch.get("always_rocks", false)
	Game.stats_changed.emit()
	Game.sfx("hurt", 0.7)
	velocity = Vector2.ZERO
	shape.set_deferred("disabled", true)
	animated_sprite.play("death")
	say("death", 1.0)
	if level:
		level.player_dying(self)
	await get_tree().create_timer(1.3, false).timeout
	if level and is_instance_valid(level):
		level.player_died(self)


func respawn(pos):
	global_position = pos
	velocity = Vector2.ZERO
	dead = false
	respawning = false
	visible = true
	shape.set_deferred("disabled", false)
	Game.players[slot].hearts = Game.max_hearts(slot)
	Game.stats_changed.emit()
	invuln = 2.5
	animated_sprite.play("idle")
	Game.sfx("power_up", 1.5, -6.0)
	say("start", 1.0)


## Called when stomping an enemy.
func bounce():
	velocity.y = -330.0 if Input.is_action_pressed(inp + "_jump") else -230.0
	air_jumps = 1 + Game.up("shoes")
	air_dash = true
	diving = false
	pounding = false
	add_mana(6)
	say("stomp")


## Launched by a spring pad. Returns false if the hero ignores it.
func spring():
	if ult == "slam":
		return false
	velocity.y = -470.0
	air_jumps = 1 + Game.up("shoes")
	air_dash = true
	diving = false
	pounding = false
	coyote = 0
	return true


func heal():
	var p = Game.players[slot]
	if p.hearts < Game.max_hearts(slot):
		p.hearts += 1
		Game.stats_changed.emit()
		return true
	return false


func give_rocks():
	Game.players[slot].rocks = true
	Game.stats_changed.emit()


## Speech bubble. chance < 0 uses the character's own chattiness.
func say(event, chance = -1.0):
	var lines = ch.lines.get(event, [])
	if lines.is_empty():
		return
	if chance < 0:
		chance = ch.get("talk", 0.3)
	if randf() > chance:
		return
	bubble.text = lines[randi() % lines.size()]
	bubble.visible = true
	bubble_time = 1.8
	if ch.get("laugh", false) and event in ["mock", "stomp", "win", "ult"]:
		Game.laugh()


# ---------------------------------------------------------------- mana + ultimates

func protected():
	return shield > 0 or ult == "rush" or ult == "slam" or dash_time > 0


## Damage dealt by landing on an enemy's head.
func stomp_power():
	return (1 + Game.up("boots")) * (2 if pounding or rage > 0 else 1)


## The hero's own movement trick (dash button).
func _move():
	if dash_cd > 0 or dead or ult == "slam" or pounding:
		return
	var on_floor = is_on_floor()
	match ch.move.id:
		"dash":
			if not on_floor and not air_dash:
				return
			air_dash = on_floor
			dash_time = 0.16
			dash_vec = Vector2(facing * 430.0, 0)
			Game.sfx("jump", 1.7)
		"dive":
			if on_floor:
				return
			diving = true
			dive_dir = facing
			Game.sfx("jump", 0.8)
		"blink":
			var dir = Vector2(Input.get_axis(inp + "_left", inp + "_right"), Input.get_axis(inp + "_up", inp + "_down"))
			if dir.length() < 0.3:
				dir = Vector2(facing, 0)
			Game.ring(global_position + Vector2(0, -10 * size), 18.0, ch.color, 0.25)
			move_and_collide(dir.normalized() * 72.0)
			Game.ring(global_position + Vector2(0, -10 * size), 24.0, ch.color, 0.25)
			velocity.y = min(velocity.y, 0.0)
			invuln = max(invuln, 0.25)
			Game.sfx("power_up", 2.2, -8.0)
		"smoke":
			var cloud = Smoke.new()
			get_parent().add_child(cloud)
			cloud.global_position = global_position + Vector2(0, -12)
			Game.sfx("jump", 0.5, -2.0)
			say("idle", 0.5)
		"charge":
			dash_time = 0.45
			dash_vec = Vector2(facing * 290.0, 0)
			Game.sfx("explosion", 1.6, -8.0)
		"rockjump":
			if not on_floor and not air_dash:
				return
			air_dash = on_floor
			velocity.y = -345.0
			coyote = 0
			var r = Rock.new()
			r.from_player = true
			r.big = true
			r.velocity = Vector2(0, 280.0)
			get_parent().add_child(r)
			r.global_position = global_position + Vector2(0, -8)
			Game.sfx("explosion", 1.8, -8.0)
			_dust()
	dash_cd = ch.move.cd * (1.0 - 0.25 * Game.up("dash"))
	if Game.up("harissa") > 0:
		Game.ring(global_position + Vector2(0, -10 * size), 36.0, Color(1.0, 0.35, 0.15), 0.3)
		_blast(36.0, 1)


func _pound_land():
	pounding = false
	Game.shake(5.0)
	Game.sfx("explosion", 0.9, -2.0)
	Game.ring(global_position, 55.0, ch.color, 0.3)
	_blast(55.0, 1)


func add_mana(amount):
	var p = Game.players[slot]
	var cost = Game.ult_cost(slot)
	var before = p.mana
	p.mana = min(p.mana + amount, Game.MAX_MANA)
	if before < cost and p.mana >= cost and not dead:
		Game.popup("ULT READY!", global_position + Vector2(0, -24 * size), Color(1.0, 0.9, 0.3))
		Game.sfx("power_up", 1.8, -8.0)


func _ultimate():
	var p = Game.players[slot]
	var info = ch.ult
	if ult != "" or dead:
		return
	if p.mana < info.cost:
		Game.sfx("tap", 0.5, -4.0)
		Game.popup("NO MANA", global_position + Vector2(0, -24 * size), Color(0.5, 0.7, 1.0))
		return
	p.mana -= info.cost
	ult = info.id
	ult_tick = 0.0
	ult_dir = facing
	var col = ULT_COLORS[ult]
	Game.flash(col)
	Game.shake(4.0)
	Game.sfx("power_up", 0.6, 2.0)
	Game.sfx("explosion", 1.3, -4.0)
	Game.ring(global_position + Vector2(0, -10 * size), 46.0, col)
	Game.popup(info.name + "!", global_position + Vector2(0, -34 * size), col)
	say("ult", 1.0)
	match ult:
		"rush":
			ult_time = 3.0
		"slam":
			ult_time = 3.0
			slam_falling = false
			velocity.y = -440.0
			coyote = 0
		"wings":
			ult_time = 5.0
			velocity.y = min(velocity.y, -200.0)
		"storm":
			ult_time = 2.4
		"decree":
			# Everyone on screen stops and salutes the supreme leader.
			ult_time = 0.6
			for e in get_tree().get_nodes_in_group("enemies"):
				if e.dead or not e.awake or e.global_position.distance_to(global_position) > 330:
					continue
				e.damage(false, 1)
				e.stun = 1.5 if e.is_boss else 4.0
				Game.popup("YES SIR!", e.global_position, col)
		"firewall":
			ult_time = 0.4
			var team = level.players if level else [self]
			for q in team:
				if q.dead:
					continue
				q.shield = 4.0
				Game.players[q.slot].hearts = Game.max_hearts(q.slot)
				Game.popup("SHIELD!", q.global_position + Vector2(0, -24 * q.size), col)
			Game.stats_changed.emit()
			_blast(85.0, 1)


func _ult_process(delta):
	ult_time -= delta
	ult_tick -= delta
	match ult:
		"rush":
			_blast(16.0 * size + 6.0, 2)
			if ult_tick <= 0:
				ult_tick = 0.05
				_afterimage()
		"wings":
			if ult_tick <= 0:
				ult_tick = 0.4
				var e = _nearest_enemy(170.0)
				if e:
					_bolt(e)
					e.damage(false, 1)
		"storm":
			if ult_tick <= 0:
				ult_tick = 0.2
				var r = Rock.new()
				r.from_player = true
				r.big = true
				r.power = 2
				r.look = "bottle"
				r.velocity = Vector2(ult_dir * randf_range(10.0, 70.0), 240.0)
				get_parent().add_child(r)
				r.global_position = global_position + Vector2(ult_dir * randf_range(10.0, 190.0), -125.0)
				Game.sfx("tap", 0.5, -4.0)
	if ult_time <= 0:
		ult = ""


func _slam_land():
	ult = ""
	Game.shake(9.0)
	Game.flash(Color.WHITE, 0.3, 0.2)
	Game.sfx("explosion", 0.7, 3.0)
	Game.ring(global_position, 115.0, Color.WHITE, 0.4)
	Game.ring(global_position, 70.0, ch.color, 0.3)
	_blast(115.0, 2)
	velocity.y = -160.0
	invuln = max(invuln, 0.6)


## Damages every enemy within `radius` of the hero's middle.
func _blast(radius, amount):
	var mid = global_position + Vector2(0, -10 * size)
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.dead or not e.awake:
			continue
		if e.global_position.distance_to(mid) < radius + 12.0 * e.scale.x:
			e.damage(false, amount)


func _nearest_enemy(max_dist):
	var best = null
	var best_d = max_dist
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.dead or not e.awake or e.invuln > 0:
			continue
		var d = e.global_position.distance_to(global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


func _bolt(e):
	var from = global_position + Vector2(0, -14 * size)
	var to = e.global_position
	var line = Line2D.new()
	line.width = 2.0
	line.default_color = Color(0.95, 0.85, 1.0)
	line.z_index = 20
	var n = 6
	for i in n + 1:
		var pt = from.lerp(to, i / float(n))
		if i > 0 and i < n:
			pt += Vector2(randf_range(-7, 7), randf_range(-7, 7))
		line.add_point(pt)
	get_parent().add_child(line)
	var tw = line.create_tween()
	tw.tween_property(line, "modulate:a", 0.0, 0.2)
	tw.tween_callback(line.queue_free)
	Game.sfx("tap", 2.2, -2.0)


func _afterimage():
	var s = Sprite2D.new()
	s.texture = animated_sprite.sprite_frames.get_frame_texture(animated_sprite.animation, animated_sprite.frame)
	s.flip_h = animated_sprite.flip_h
	s.scale = animated_sprite.scale
	s.material = animated_sprite.material
	s.modulate = Color(0.5, 0.85, 1.0, 0.55)
	s.z_index = 4
	get_parent().add_child(s)
	s.global_position = animated_sprite.global_position
	var tw = s.create_tween()
	tw.tween_property(s, "modulate:a", 0.0, 0.3)
	tw.tween_callback(s.queue_free)


## Mana bar over the head, shield bubble and ultimate aura.
func _draw():
	if dead or slot >= Game.players.size():
		return
	var mid = Vector2(0, -11 * size)
	if ult != "":
		var c = ULT_COLORS[ult]
		draw_circle(mid, 15.0 * size + sin(fx_time * 18.0) * 2.0, Color(c.r, c.g, c.b, 0.28))
	if ult == "wings":
		var flap = sin(fx_time * 16.0) * 5.0
		for side in [-1, 1]:
			draw_colored_polygon(PackedVector2Array([
				mid + Vector2(side * 4, -2), mid + Vector2(side * 20, -10 + flap),
				mid + Vector2(side * 15, 4 + flap * 0.4)]), Color(0.9, 0.8, 1.0, 0.85))
	if shield > 0 and (shield > 1.2 or int(shield * 12) % 2 == 0):
		var r = 16.0 * size + 2.0
		draw_circle(mid, r, Color(0.4, 1.0, 0.6, 0.16))
		draw_arc(mid, r, 0, TAU, 28, Color(0.6, 1.0, 0.7, 0.9), 1.0)
	var p = Game.players[slot]
	var cost = Game.ult_cost(slot)
	var y = -24.0 * size - 5.0
	draw_rect(Rect2(-9, y - 1, 18, 4), Color(0.04, 0.04, 0.1))
	var full = p.mana >= cost
	var col = Color(1.0, 0.85, 0.25) if full and int(fx_time * 6) % 2 == 0 else Color(0.3, 0.6, 1.0)
	draw_rect(Rect2(-8, y, 16.0 * clamp(p.mana / cost, 0.0, 1.0), 2), col)
	# Thin green line: the special move is ready when it is full.
	var cd = max(ch.move.cd, 0.01)
	draw_rect(Rect2(-8, y + 4, 16.0 * clamp(1.0 - dash_cd / cd, 0.0, 1.0), 1), Color(0.5, 1.0, 0.6))


## What makes each hero who they are, drawn in front of the sprite:
## Shee's sunglasses, Iheb's beer, Gueni's smoke, Elli's fury.
class Props extends Node2D:
	var hero

	func _draw():
		var h = hero
		if h.dead or not h.animated_sprite.visible:
			return
		var s = h.size
		var f = h.facing
		var ch = h.ch
		if ch.get("shades", false):
			draw_rect(Rect2(Vector2(1 + f * 5.5 - 5.5, -20.5) * s, Vector2(11, 3.2) * s), Color(0.03, 0.03, 0.06))
			draw_rect(Rect2(Vector2(1 + f * 8.0 - 1.0, -20.0) * s, Vector2(2, 1) * s), Color(1, 1, 1, 0.7))
		if ch.get("beer", false):
			var hand = Vector2(1 + f * 9.0, -9.0) * s
			draw_rect(Rect2(hand + Vector2(-1.5, -5) * s, Vector2(3, 6) * s), Color(0.95, 0.7, 0.15))
			draw_rect(Rect2(hand + Vector2(-1.5, -6.5) * s, Vector2(3, 2) * s), Color(1, 1, 1))
		if ch.get("smoke", false):
			var mouth = Vector2(1 + f * 9.0, -13.0) * s
			draw_line(mouth, mouth + Vector2(f * 4.0, -1.0) * s, Color(0.95, 0.95, 0.9), 1.2)
			draw_circle(mouth + Vector2(f * 4.0, -1.0) * s, 0.9, Color(1.0, 0.5, 0.2))
			for i in 3:
				var k = fmod(h.fx_time * 0.5 + i / 3.0, 1.0)
				draw_circle(mouth + Vector2(f * 5.0 + sin(k * 9.0 + i) * 3.0, -2.0 - k * 16.0) * s, 1.5 + k * 3.0, Color(0.75, 0.9, 0.7, 0.5 * (1.0 - k)))
		if h.rage > 0:
			var top = Vector2(f * -6.0, -24.0 * s - 2.0)
			for d in [Vector2(1, 1), Vector2(1, -1)]:
				draw_line(top - d * 2.5, top + d * 2.5, Color(1.0, 0.15, 0.1), 1.5)
