extends CharacterBody2D
## A hero. `slot` selects which entry of Game.players (character + input device) drives it.

const Rock = preload("res://scripts/rock.gd")

const WALK_SPEED = 130.0
const RUN_SPEED = 185.0
const JUMP_VELOCITY = -300.0
const AIR_JUMP_VELOCITY = -235.0
const COYOTE_TIME = 0.1
const JUMP_BUFFER = 0.12
const INVULN_TIME = 1.6

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

	bubble = Game.label("", 8, ch.color)
	bubble.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bubble.size = Vector2(160, 10)
	bubble.position = Vector2(-80, -46 - slot * 9 if Game.players.size() > 1 else -40)
	bubble.z_index = 30
	bubble.visible = false
	add_child(bubble)
	if Game.players.size() > 1:
		var tag = Game.label("P%d" % (slot + 1), 8, Game.PLAYER_COLORS[slot])
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.size = Vector2(40, 10)
		tag.position = Vector2(-20, -36)
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
	if dead:
		return

	if invuln > 0:
		invuln -= delta
		animated_sprite.visible = invuln <= 0 or int(invuln * 20) % 2 == 0
	throw_cd -= delta
	buffer -= delta

	var on_floor = is_on_floor()
	if on_floor:
		coyote = COYOTE_TIME
		air_jumps = 1
	else:
		coyote -= delta
		var g = gravity
		if velocity.y > 0:
			g *= ch.get("fall", 1.0)
		velocity.y += g * delta

	# Get the input direction: -1, 0, 1
	var direction = 0.0
	var running = false
	if not locked:
		var axis = Input.get_axis(inp + "_left", inp + "_right")
		if abs(axis) > 0.3:
			direction = sign(axis)
		running = Input.is_action_pressed(inp + "_action")
		if Input.is_action_just_pressed(inp + "_jump"):
			buffer = JUMP_BUFFER
		if Input.is_action_just_released(inp + "_jump") and velocity.y < -120:
			velocity.y *= 0.5
		if Input.is_action_just_pressed(inp + "_action"):
			_throw()

	# Handle jump (with coyote time, jump buffering and one air jump).
	if buffer > 0:
		if coyote > 0:
			velocity.y = JUMP_VELOCITY * ch.get("jump", 1.0)
			coyote = 0
			buffer = 0
			Game.sfx("jump")
		elif air_jumps > 0:
			air_jumps -= 1
			velocity.y = AIR_JUMP_VELOCITY * ch.get("jump", 1.0)
			buffer = 0
			Game.sfx("jump", 1.35)
			_dust()

	# Apply movement
	var target = direction * (RUN_SPEED if running else WALK_SPEED) * ch.get("speed", 1.0)
	var accel = 650.0
	if on_floor:
		accel = (1000.0 if direction != 0 else 1300.0) * (level.slip if level else 1.0)
	velocity.x = move_toward(velocity.x, target, accel * delta)

	# Same-screen multiplayer: don't run away from your friends.
	if level and level.players.size() > 1:
		var lim = level.x_limits(self)
		if (global_position.x <= lim[0] and velocity.x < 0) or (global_position.x >= lim[1] and velocity.x > 0):
			velocity.x = 0

	move_and_slide()

	# Bump blocks from below.
	for i in get_slide_collision_count():
		var c = get_slide_collision(i)
		if c.get_normal().y > 0.7:
			var body = c.get_collider()
			if body and body.has_method("bump"):
				body.bump(self)

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


func _throw():
	if not Game.players[slot].rocks or throw_cd > 0:
		return
	throw_cd = 0.35
	anim_lock = 0.25
	animated_sprite.play("throw")
	var r = Rock.new()
	r.from_player = true
	r.velocity = Vector2(facing * 250.0 + velocity.x * 0.3, -90.0)
	get_parent().add_child(r)
	r.global_position = global_position + Vector2(facing * 8, -12)
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
	if dead or invuln > 0 or locked:
		return
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
	air_jumps = 1
	say("stomp")


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
	if ch.get("laugh", false) and event in ["mock", "stomp", "win"]:
		Game.laugh()
