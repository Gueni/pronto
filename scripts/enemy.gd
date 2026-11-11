extends Node2D
## All the baddies. Origin is 16px (times the scale) above the feet.
## kind: pinky (walker), grump (rock thrower), slime, slime_purple (fast, 2 hits),
##       spiky (slime you must NOT stomp), bat (flies in waves), charger (rushes at heroes),
##       queen (QUEEN SLIME, boss), boss (KING PINKY, final boss).
## Bosses run a small state machine with telegraphed attacks and three phases (see _boss).

const Rock = preload("res://scripts/rock.gd")
const Wave = preload("res://scripts/wave.gd")
const SCALES = {"boss": 2.0, "queen": 3.0, "bat": 0.85, "bomber": 0.9, "splitter": 1.7}
# What they shout. spot = sees a hero, hurt = got hit, win = hurt a hero.
const LINES = {
	"pinky": {"spot": ["HEY! YOU!", "GET HIM!", "INTRUDER!"], "hurt": ["OW!"], "win": ["HA!", "GOT YOU!"]},
	"grump": {"spot": ["GET OFF MY LAWN!", "KIDS THESE DAYS..."], "hurt": ["MY BACK!"], "win": ["BULLSEYE."]},
	"charger": {"spot": ["RAAAAH!", "CHAAARGE!"], "hurt": ["GRR!"], "win": ["SMASH!"]},
	"slime": {"spot": ["BLUB?"], "win": ["BLUB!"]},
	"slime_purple": {"spot": ["BLUB BLUB!"], "win": ["BLUB!"]},
	"spiky": {"spot": ["TOUCH ME. I DARE YOU."], "win": ["TOLD YOU."]},
	"splitter": {"spot": ["WE ARE MANY."], "hurt": ["WE ARE... MORE."]},
	"hopper": {"spot": ["BOING!", "WHEEE!"], "hurt": ["OOF!"], "win": ["BOING BOING!"]},
	"shield": {"spot": ["NONE SHALL PASS!", "HALT!"], "hurt": ["MY HELMET!"], "win": ["BEGONE."]},
	"bat": {"spot": ["SKREEE!"]},
	"bomber": {"spot": ["BOMBS AWAY!", "LOOK UP!"], "win": ["DIRECT HIT!"]},
	"ghost": {"spot": ["...", "BOO."], "win": ["HEHEHE..."]},
	"kamikaze": {"spot": ["FOR THE KING!!", "WITNESS ME!"], "win": ["WORTH IT!"]},
	"shaman": {"spot": ["OOGA.", "THE SPIRITS SEE YOU."], "hurt": ["BAD OMEN!"], "win": ["CURSED."]},
	"sniper": {"spot": ["TARGET ACQUIRED.", "HOLD STILL."], "hurt": ["MISSED?!"], "win": ["HEADSHOT."]},
	"queen": {"spot": ["WHO DARES?!"], "hurt": ["MY CROWN!", "INSOLENT!"], "win": ["SQUISHED!"]},
	"boss": {"spot": ["BOW TO YOUR KING!"], "hurt": ["GUARDS!!", "THAT HURT, PEASANT!"], "win": ["KNEEL!", "HAHAHA!"]},
}
const BOSS_NAMES = {"boss": "KING PINKY", "queen": "QUEEN SLIME"}
const GOLD = {"slime": 1, "pinky": 2, "bat": 2, "hopper": 2, "slime_purple": 3, "grump": 3, "spiky": 3, "bomber": 3,
	"kamikaze": 3, "splitter": 3, "charger": 4, "shield": 4, "ghost": 4, "sniper": 5, "shaman": 6, "queen": 60, "boss": 100}
const PLANS = {
	"queen": [["hops", "spit", "big", "summon"], ["hops", "big", "spit", "big", "summon"], ["big", "spit", "big", "hops", "summon"]],
	"boss": [["walk", "charge", "walk", "leap"], ["walk", "charge", "leap", "rain"], ["charge", "leap", "rain", "summon", "charge"]],
}

@export var kind = "pinky"

var speed = 45.0
var max_speed = 0.0
var hp = 1
var max_hp = 1
var score_value = 200
var direction = -1
var dead = false
var invuln = 0.0
var use_ledges = false
var frames_alive = 0
var throw_range = 0.0
var throw_interval = 2.4
var throw_timer = 1.5
var is_slime = false
var is_boss = false
var fly = false
var charging = false
var awake = true
var home = Vector2.ZERO
var t = 0.0
var hit_size = Vector2(13, 22)
var elite = false       # set before entering the tree: bigger, tougher, richer
var stun = 0.0          # seconds of doing nothing (Shee's decree, Gueni's smoke)
var ward = false        # a shaman's ward: absorbs one hit
var fly_range = 56.0
var act_t = 1.5         # timer of the kind's special action
var hopping = false
var lit = false         # kamikaze fuse
var fuse = 0.0
var solid = true        # ghosts are untouchable while not solid
var aim_t = 0.0         # sniper: time left before the shot
var aim_at = Vector2.ZERO
var spotted = false
var bubble: Label
var bubble_t = 0.0
var deco: Node2D

# boss brain
var state = ""
var state_t = 0.0
var step = 0
var plan_i = -1
var phase = 0
var arena_l = 0.0
var arena_r = 0.0
var jump_from = 0.0
var jump_to = 0.0
var jump_h = 0.0
var jump_time = 1.0
var slam = false

var sprite: AnimatedSprite2D
var hitbox: Area2D
var hit_shape: CollisionShape2D
var rays = {}


func _ready():
	add_to_group("enemies")
	sprite = AnimatedSprite2D.new()
	add_child(sprite)
	var s = SCALES.get(kind, 1.0)
	scale = Vector2(s, s)
	var hit_pos = Vector2(-0.5, 4)
	match kind:
		"slime", "slime_purple", "queen", "spiky", "splitter":
			is_slime = true
			var purple = kind == "slime_purple" or kind == "queen"
			sprite.sprite_frames = Game.slime_frames("res://assets/sprites/slime_purple.png" if purple else "res://assets/sprites/slime_green.png")
			sprite.position = Vector2(0, 4)
			sprite.play("walk")
			speed = 55.0 if purple else 24.0
			hp = 2 if purple else 1
			score_value = 300 if purple else 100
			hit_size = Vector2(13, 11)
			hit_pos = Vector2(0, 10)
			if kind == "queen":
				sprite.material = Game.hue_material(0.42)
				speed = 0.0
				hp = 12
				score_value = 3000
			elif kind == "spiky":
				sprite.material = Game.hue_material(0.62)
				score_value = 300
			elif kind == "splitter":
				sprite.material = Game.hue_material(0.2)
				hp = 2
				speed = 20.0
				score_value = 300
		"grump":
			sprite.sprite_frames = Game.frames_for(Game.PINK)
			sprite.material = Game.hue_material(0.14)
			sprite.play("idle")
			sprite.animation_finished.connect(func(): if not dead: sprite.play("idle"))
			speed = 0.0
			score_value = 400
			throw_range = 150.0
		"bat":
			fly = true
			sprite.sprite_frames = Game.frames_for(Game.OWLET)
			sprite.material = Game.hue_material(0.62)
			sprite.play("run")
			speed = 40.0
			score_value = 300
			hit_size = Vector2(14, 16)
			hit_pos = Vector2(0, 6)
		"charger":
			sprite.sprite_frames = Game.frames_for(Game.PINK)
			sprite.material = Game.hue_material(0.5)
			sprite.play("walk")
			speed = 30.0
			hp = 2
			score_value = 400
		"hopper":
			sprite.sprite_frames = Game.frames_for(Game.DUDE)
			sprite.material = Game.hue_material(0.3)
			sprite.play("idle")
			speed = 0.0
			score_value = 250
			arena_l = -1000000.0
			arena_r = 1000000.0
		"shield":
			sprite.sprite_frames = Game.frames_for(Game.PINK)
			sprite.material = Game.hue_material(0.3)
			sprite.play("walk")
			speed = 28.0
			hp = 2
			score_value = 400
		"bomber":
			fly = true
			fly_range = 96.0
			sprite.sprite_frames = Game.frames_for(Game.OWLET)
			sprite.material = Game.hue_material(0.9)
			sprite.play("run")
			speed = 48.0
			score_value = 350
			hit_size = Vector2(14, 16)
			hit_pos = Vector2(0, 6)
		"ghost":
			sprite.sprite_frames = Game.frames_for(Game.OWLET)
			sprite.material = Game.hue_material(0.55)
			sprite.play("idle")
			speed = 24.0
			hp = 2
			score_value = 400
		"kamikaze":
			sprite.sprite_frames = Game.frames_for(Game.DUDE)
			sprite.material = Game.hue_material(0.45)
			sprite.play("walk")
			speed = 32.0
			score_value = 300
		"shaman":
			sprite.sprite_frames = Game.frames_for(Game.OWLET)
			sprite.material = Game.hue_material(0.4)
			sprite.play("idle")
			speed = 0.0
			hp = 2
			score_value = 500
			act_t = 2.0
		"sniper":
			sprite.sprite_frames = Game.frames_for(Game.PINK)
			sprite.material = Game.hue_material(0.7)
			sprite.play("idle")
			speed = 0.0
			score_value = 450
		"boss":
			sprite.sprite_frames = Game.frames_for(Game.PINK)
			sprite.play("idle")
			speed = 0.0
			hp = 16
			score_value = 5000
			throw_range = 260.0
			throw_interval = 1.5
		_:
			sprite.sprite_frames = Game.frames_for(Game.PINK)
			sprite.play("walk")
	is_boss = BOSS_NAMES.has(kind)
	if not is_boss:
		# The deeper the run, the quicker, meaner and tougher everything gets.
		var d = Game.danger()
		speed *= 1.0 + 0.02 * d
		throw_interval *= max(0.55, 1.0 - 0.03 * d)
		hp += int(d / 8.0)
		if elite:
			scale *= 1.3
			hp = hp * 2 + 1
			speed *= 1.15
			score_value *= 3
	else:
		hp = max(hp - 2 * Game.meta_level("muscle"), 4) + 2 * (Game.players.size() - 1)
	max_hp = hp
	max_speed = speed * 2.2
	home = position

	hitbox = Area2D.new()
	hitbox.collision_layer = 4
	hitbox.collision_mask = 2
	hit_shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = hit_size
	hit_shape.shape = rect
	hit_shape.position = hit_pos
	hitbox.add_child(hit_shape)
	add_child(hitbox)

	_ray("wall1", Vector2(0, 6), Vector2(11, 0))
	_ray("wall-1", Vector2(0, 6), Vector2(-11, 0))
	_ray("ledge1", Vector2(9, 8), Vector2(0, 13))
	_ray("ledge-1", Vector2(-9, 8), Vector2(0, 13))
	_ray("floor", Vector2(0, 8), Vector2(0, 13))
	deco = Deco.new()
	deco.enemy = self
	deco.z_index = 1
	add_child(deco)
	if is_boss:
		awake = false


func _ray(ray_name, from, to):
	var r = RayCast2D.new()
	r.position = from
	r.target_position = to
	r.collision_mask = 1
	add_child(r)
	rays[ray_name] = r


func _physics_process(delta):
	if dead:
		return
	if not awake:
		# Bosses wait until a hero walks into their arena.
		var p = _nearest_player()
		if p == null or abs(p.global_position.x - global_position.x) > 250:
			return
		awake = true
		_find_arena()
		Game.boss_name = BOSS_NAMES[kind]
		Game.boss_changed.emit(hp, max_hp)
		Game.sfx("explosion", 0.6)
		Game.shake(5.0)
		_set_state("rest")
		state_t = -0.6
		say("spot", 1.0)
	frames_alive += 1
	t += delta
	deco.queue_redraw()
	if bubble_t > 0:
		bubble_t -= delta
		if bubble_t <= 0:
			bubble.visible = false
	if not spotted and frames_alive % 10 == 0:
		var seen = _nearest_player()
		if seen != null and seen.global_position.distance_to(global_position) < 110.0:
			spotted = true
			say("spot")
	if frames_alive == 3 and not fly:
		# Only patrol ledges when actually standing on something.
		use_ledges = rays["floor"].is_colliding()
	if invuln > 0:
		invuln -= delta
		sprite.modulate = Color(1, 0.5, 0.5) if int(invuln * 16) % 2 == 0 else Color.WHITE
		if invuln <= 0:
			sprite.modulate = Color.WHITE

	if stun > 0:
		# Dizzy: no moving, no attacking. Still safe to stomp.
		stun -= delta
		for body in hitbox.get_overlapping_bodies():
			if body.has_method("hurt"):
				_touch(body)
		return

	if is_boss:
		_boss(delta)
	elif fly:
		_fly(delta)
		if kind == "bomber":
			_bomb(delta)
	elif kind == "charger":
		_charge(delta)
	elif kind == "hopper":
		_hop(delta)
	elif kind == "ghost":
		_haunt(delta)
	elif kind == "kamikaze":
		_kamikaze(delta)
	elif kind == "shaman":
		_shaman(delta)
	elif kind == "sniper":
		_snipe(delta)
	elif speed > 0:
		var key = str(direction)
		if rays["wall" + key].is_colliding() or (use_ledges and not rays["ledge" + key].is_colliding()):
			direction = -direction
		position.x += direction * speed * delta
		sprite.flip_h = direction < 0

	if throw_range > 0 and not is_boss:
		_think_throw(delta)

	for body in hitbox.get_overlapping_bodies():
		if body.has_method("hurt"):
			_touch(body)


## Bats glide back and forth around their home, bobbing up and down.
func _fly(delta):
	if rays["wall" + str(direction)].is_colliding() or abs(position.x + direction * 2.0 - home.x) > fly_range:
		direction = -direction
	position.x += direction * speed * delta
	position.y = home.y + sin(t * 3.0) * 18.0
	sprite.flip_h = direction < 0
	queue_redraw()


## Chargers stroll around until a hero is in front of them, then run at them.
func _charge(delta):
	var p = _nearest_player()
	var was = charging
	charging = false
	if p != null:
		var d = p.global_position - global_position
		if abs(d.x) < 120 and abs(d.y - 16) < 30:
			charging = true
			direction = 1 if d.x > 0 else -1
	if charging and not was:
		Game.popup("!", global_position + Vector2(0, -8), Color(1.0, 0.4, 0.3))
	var key = str(direction)
	var blocked = rays["wall" + key].is_colliding() or (use_ledges and not rays["ledge" + key].is_colliding())
	if blocked:
		if not charging:
			direction = -direction
	else:
		position.x += direction * (speed * 3.2 if charging else speed) * delta
	sprite.flip_h = direction < 0
	sprite.speed_scale = 2.0 if charging else 1.0


func _draw():
	if dead:
		return
	if elite:
		draw_circle(Vector2(0, 6), 15.0 + sin(t * 6.0) * 1.5, Color(1.0, 0.85, 0.3, 0.28))
	if fly:
		var flap = sin(t * 18.0) * 6.0
		for side in [-1, 1]:
			draw_colored_polygon(PackedVector2Array([
				Vector2(side * 4, 2), Vector2(side * 19, -6 + flap), Vector2(side * 13, 7 + flap * 0.3)]),
				Color(0.2, 0.12, 0.3))
	elif kind == "spiky":
		for i in 4:
			var x = -7.0 + i * 3.6
			draw_colored_polygon(PackedVector2Array([Vector2(x, 9), Vector2(x + 1.8, 0), Vector2(x + 3.6, 9)]), Color(0.92, 0.92, 1.0))
			draw_line(Vector2(x, 9), Vector2(x + 1.8, 0), Color(0.15, 0.1, 0.2), 0.8)
			draw_line(Vector2(x + 1.8, 0), Vector2(x + 3.6, 9), Color(0.15, 0.1, 0.2), 0.8)


func _nearest_player():
	var best = null
	for p in get_tree().get_nodes_in_group("players"):
		if p.dead:
			continue
		if best == null or abs(p.global_position.x - global_position.x) < abs(best.global_position.x - global_position.x):
			best = p
	return best


func _think_throw(delta):
	var target = _nearest_player()
	if target == null:
		return
	var d = target.global_position - global_position
	if speed == 0 and not is_boss:
		sprite.flip_h = d.x < 0
	throw_timer -= delta
	if throw_timer <= 0 and abs(d.x) < throw_range and abs(d.y) < 130:
		throw_timer = throw_interval
		if speed == 0 and not is_boss:
			sprite.play("throw")
		_throw_rock(Vector2(clamp(d.x * 1.1, -210.0, 210.0), -230.0))
		if is_boss and phase > 0:
			# Angry king: a second, shorter throw.
			_throw_rock(Vector2(clamp(d.x * 0.55, -120.0, 120.0), -280.0))


func _throw_rock(vel, tint = Color.WHITE):
	var r = Rock.new()
	r.from_player = false
	r.big = is_boss
	r.tint = tint
	r.velocity = vel
	get_parent().add_child(r)
	r.global_position = global_position + Vector2(0, -6 * scale.y)


func _touch(p):
	if p.dead or dead or not solid:
		return
	var top = hit_shape.global_position.y - hit_size.y * 0.5 * scale.y
	if p.velocity.y > 0 and p.global_position.y < top + 9 * scale.y:
		if kind == "spiky" and not p.protected():
			# Ouch: spikes. Use rocks, moves or ultimates instead.
			p.hurt(global_position.x)
			return
		var power = p.stomp_power()
		p.bounce()
		damage(true, power)
	elif stun <= 0 and (invuln <= 0 or is_boss):
		var before = Game.players[p.slot].hearts
		p.hurt(global_position.x)
		if Game.players[p.slot].hearts < before:
			say("win")
			if Game.up("thorns") > 0:
				damage(false, 2)


## from_x: where the projectile is, so shield guys can block what comes from the front.
func hit_by_rock(power = 1, from_x = null):
	if kind == "shield" and from_x != null and stun <= 0 and (from_x - global_position.x) * direction > 0:
		Game.popup("CLANG!", global_position, Color(0.8, 0.85, 1.0))
		Game.sfx("tap", 1.8, -4.0)
		return
	damage(false, power)


func damage(stomped, amount = 1):
	if dead or invuln > 0 or not solid:
		return
	if ward:
		ward = false
		invuln = 0.4
		Game.popup("WARDED!", global_position, Color(0.6, 0.8, 1.0))
		Game.sfx("tap", 1.6, -2.0)
		return
	if is_boss:
		amount = 1   # no shortcuts: every hit on a boss counts for one
	hp -= amount
	if is_boss:
		Game.boss_changed.emit(max(hp, 0), max_hp)
		Game.shake(3.0)
		_check_phase()
	if hp <= 0:
		_die(stomped)
		return
	Game.sfx("tap", 0.6, 4.0)
	say("hurt")
	invuln = 1.0 if is_boss else 0.5
	if not is_boss:
		speed = min(speed * 1.15, max_speed)
		throw_interval *= 0.9


func _die(stomped):
	dead = true
	hitbox.set_deferred("monitoring", false)
	hitbox.collision_layer = 0
	sprite.modulate = Color.WHITE
	queue_redraw()
	Game.add_score(score_value, global_position)
	var loot = GOLD.get(kind, 1) * (4 if elite else 1) * (1.0 + 0.5 * Game.up("magnet"))
	Game.add_gold(int(ceil(loot)), global_position)
	Game.add_kill()
	if bubble:
		bubble.visible = false
	if is_boss:
		_boss_death()
		return
	Game.give_mana_all(6 * (2 if Game.up("brik") > 0 else 1))
	if kind == "splitter":
		for dx in [-9, 9]:
			var e = get_script().new()
			e.kind = "slime"
			e.direction = 1 if dx > 0 else -1
			e.position = Vector2(position.x + dx, position.y + 16 * scale.y - 16)
			get_parent().add_child.call_deferred(e)
	if stomped:
		Game.sfx("tap", 0.75, 3.0)
	else:
		Game.sfx("explosion", 1.4, -8.0)
	if is_slime or stomped:
		var tw = create_tween()
		tw.tween_property(self, "scale", Vector2(1.3, 0.25) * scale, 0.1)
		tw.parallel().tween_property(self, "position:y", position.y + 12 * scale.y, 0.1)
		tw.tween_interval(0.3)
		tw.tween_callback(queue_free)
	else:
		sprite.play("death")
		var tw = create_tween()
		tw.tween_interval(0.85)
		tw.tween_callback(queue_free)


func _boss_death():
	# Minions go down with their boss.
	for e in get_tree().get_nodes_in_group("enemies"):
		if e != self and not e.dead:
			e.invuln = 0.0
			e.damage(false, 99)
	sprite.scale = Vector2.ONE
	if not is_slime:
		sprite.play("hurt")
	for i in 6:
		Game.sfx("explosion", 0.8 + randf() * 0.6, -4.0)
		Game.shake(5.0)
		sprite.modulate = Color(1, 0.4, 0.4) if i % 2 == 0 else Color.WHITE
		await get_tree().create_timer(0.22, false).timeout
	sprite.modulate = Color.WHITE
	if is_slime:
		var tw = create_tween()
		tw.tween_property(self, "scale", Vector2(1.3, 0.1) * scale, 0.5)
		tw.parallel().tween_property(self, "position:y", home.y + 14 * scale.y, 0.5)
	else:
		sprite.play("death")
	await get_tree().create_timer(0.9, false).timeout
	visible = false
	if Game.level_node and is_instance_valid(Game.level_node):
		Game.level_node.complete()


# ---------------------------------------------------------------- characters

## Small speech bubble over the enemy's head.
func say(event, chance = 0.6):
	var lines = LINES.get(kind, {}).get(event, [])
	if lines.is_empty() or dead or randf() > chance:
		return
	if bubble == null:
		bubble = Game.label("", 8, Color(1.0, 0.8, 0.8))
		bubble.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bubble.size = Vector2(160, 10)
		bubble.scale = Vector2.ONE / scale
		bubble.position = Vector2(-80 / scale.x, -14 - 12 / scale.y)
		bubble.z_index = 30
		add_child(bubble)
	bubble.text = lines[randi() % lines.size()]
	bubble.visible = true
	bubble_t = 1.6


func _walk(delta, pace):
	var key = str(direction)
	if rays["wall" + key].is_colliding() or (use_ledges and not rays["ledge" + key].is_colliding()):
		return false
	position.x += direction * pace * delta
	return true


## Is there floor at x, and nothing in the way?
func _can_land(x):
	var space = get_world_2d().direct_space_state
	var feet = home.y + 16 * scale.y
	var down = space.intersect_ray(PhysicsRayQueryParameters2D.create(Vector2(x, feet - 6), Vector2(x, feet + 6), 1))
	var side = space.intersect_ray(PhysicsRayQueryParameters2D.create(Vector2(position.x, feet - 8), Vector2(x, feet - 8), 1))
	return not down.is_empty() and side.is_empty()


## Hoppers leap at the heroes in little arcs.
func _hop(delta):
	if hopping:
		state_t += delta
		if _jump_step(state_t):
			hopping = false
			act_t = 0.55
			sprite.play("idle")
		return
	act_t -= delta
	if act_t > 0:
		return
	var p = _nearest_player()
	var dx = 0.0
	if p != null and abs(p.global_position.x - global_position.x) < 170:
		dx = clamp(p.global_position.x - position.x, -46.0, 46.0)
	if not _can_land(position.x + dx):
		dx = 0.0
	_start_jump(position.x + dx, 30.0, 0.5)
	sprite.play("jump")
	state_t = 0.0
	hopping = true


## Bombers drop rocks when a hero walks underneath.
func _bomb(delta):
	act_t -= delta
	var p = _nearest_player()
	if p != null and act_t <= 0 and abs(p.global_position.x - global_position.x) < 14 and p.global_position.y > global_position.y:
		act_t = 1.5
		var r = Rock.new()
		r.from_player = false
		r.velocity = Vector2(0, 40.0)
		get_parent().add_child(r)
		r.global_position = global_position + Vector2(0, 10)
		Game.sfx("tap", 0.6, -4.0)


## Ghosts drift through walls towards the heroes. Only solid (and dangerous) part of the time.
func _haunt(delta):
	solid = fmod(t, 5.0) > 2.6
	sprite.modulate.a = 0.95 if solid else 0.28
	var p = _nearest_player()
	if p == null:
		return
	var to = p.global_position + Vector2(0, -10) - global_position
	if to.length() < 220 and to.length() > 4:
		position += to.normalized() * speed * (1.0 if solid else 1.6) * delta
		sprite.flip_h = to.x < 0


## Kamikazes light their fuse when they see a hero, run at them and blow up.
func _kamikaze(delta):
	var p = _nearest_player()
	if not lit:
		if p != null:
			var d = p.global_position - global_position
			if abs(d.x) < 95 and abs(d.y - 16) < 32:
				lit = true
				fuse = 1.3
				say("spot", 1.0)
				sprite.speed_scale = 2.2
		if not _walk(delta, speed):
			direction = -direction
		sprite.flip_h = direction < 0
		return
	fuse -= delta
	if p != null:
		direction = 1 if p.global_position.x > global_position.x else -1
	_walk(delta, 112.0)
	sprite.flip_h = direction < 0
	sprite.modulate = Color(1, 0.4, 0.3) if int(fuse * 14) % 2 == 0 else Color.WHITE
	if fuse <= 0:
		_explode()


func _explode():
	Game.ring(global_position, 34.0, Color(1.0, 0.6, 0.2), 0.3)
	Game.sfx("explosion", 1.1)
	Game.shake(4.0)
	for p in get_tree().get_nodes_in_group("players"):
		if not p.dead and p.global_position.distance_to(global_position + Vector2(0, 8)) < 32:
			p.hurt(global_position.x)
	for e in get_tree().get_nodes_in_group("enemies"):
		if e != self and not e.dead and e.global_position.distance_to(global_position) < 34:
			e.damage(false, 2)
	hp = 0
	_die(false)


## Shamans ward their friends and throw slow curses.
func _shaman(delta):
	var p = _nearest_player()
	if p != null:
		sprite.flip_h = p.global_position.x < global_position.x
	act_t -= delta
	if act_t > 0:
		return
	act_t = 3.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e != self and not e.dead and not e.ward and not e.is_boss and e.kind != "shaman" and e.global_position.distance_to(global_position) < 150:
			e.ward = true
			Game.ring(e.global_position, 18.0, Color(0.5, 0.7, 1.0), 0.3)
			sprite.play("throw")
			Game.sfx("power_up", 0.7, -8.0)
			return
	if p != null and p.global_position.distance_to(global_position) < 180:
		var r = Rock.new()
		r.from_player = false
		r.grav = 0.0
		r.life = 3.5
		r.tint = Color(0.8, 0.4, 1.0)
		r.big = true
		r.velocity = (p.global_position + Vector2(0, -10) - global_position).normalized() * 70.0
		get_parent().add_child(r)
		r.global_position = global_position
		sprite.play("throw")


## Snipers show a red line, then fire along it.
func _snipe(delta):
	var p = _nearest_player()
	if aim_t > 0:
		aim_t -= delta
		if p != null and aim_t > 0.3:
			aim_at = p.global_position + Vector2(0, -10)
			sprite.flip_h = aim_at.x < global_position.x
		if aim_t <= 0:
			var r = Rock.new()
			r.from_player = false
			r.grav = 0.0
			r.life = 1.3
			r.tint = Color(1.0, 0.4, 0.4)
			r.velocity = (aim_at - global_position).normalized() * 300.0
			get_parent().add_child(r)
			r.global_position = global_position
			Game.sfx("tap", 1.9)
			act_t = 2.2
		return
	act_t -= delta
	if p != null and act_t <= 0:
		var d = p.global_position - global_position
		if abs(d.x) < 200 and abs(d.y) < 80:
			aim_t = 0.9
			aim_at = p.global_position + Vector2(0, -10)


## Everything drawn in front of the sprite: wards, shields, hats, stars, laser lines.
func draw_deco(c):
	if dead:
		return
	if stun > 0:
		for i in 3:
			var a = t * 6.0 + i * TAU / 3.0
			c.draw_circle(Vector2(cos(a) * 8.0, -9 + sin(a) * 2.5), 1.6, Color(1.0, 0.95, 0.4))
	if ward:
		c.draw_arc(Vector2(0, 5), 14.0, 0, TAU, 24, Color(0.5, 0.75, 1.0, 0.9), 1.5)
	if elite:
		for i in 3:
			var x = -5.0 + i * 5.0
			c.draw_colored_polygon(PackedVector2Array([Vector2(x - 2.5, -8), Vector2(x, -13), Vector2(x + 2.5, -8)]), Color(1.0, 0.85, 0.25))
	match kind:
		"shield":
			c.draw_rect(Rect2(direction * 7 - 2, -3, 4, 15), Color(0.7, 0.75, 0.85))
			c.draw_rect(Rect2(direction * 7 - 2, -3, 4, 15), Color(0.15, 0.15, 0.25), false, 1.0)
		"shaman":
			c.draw_colored_polygon(PackedVector2Array([Vector2(-6, -5), Vector2(0, -17), Vector2(6, -5)]), Color(0.45, 0.2, 0.6))
			c.draw_rect(Rect2(-8, -6, 16, 2), Color(0.3, 0.12, 0.42))
		"kamikaze":
			c.draw_line(Vector2(0, -6), Vector2(2, -11), Color(0.2, 0.15, 0.1), 1.0)
			if lit:
				c.draw_circle(Vector2(2, -12), 2.0 + sin(t * 40.0), Color(1.0, 0.8, 0.2))
		"sniper":
			c.draw_rect(Rect2(-6, -8, 12, 3), Color(0.2, 0.3, 0.2))
			if aim_t > 0:
				var to = (aim_at - global_position) / scale
				c.draw_line(Vector2.ZERO, to.normalized() * 400.0, Color(1.0, 0.2, 0.2, 0.35 + 0.4 * (1.0 - aim_t / 0.9)), 1.0)


class Deco extends Node2D:
	var enemy

	func _draw():
		enemy.draw_deco(self)


# ---------------------------------------------------------------- boss brain

## Finds the walls of the boss room so charges and leaps stay inside it.
func _find_arena():
	arena_l = position.x - 300.0
	arena_r = position.x + 300.0
	var space = get_world_2d().direct_space_state
	var from = global_position + Vector2(0, 16 * scale.y - 8)
	for dir in [-1, 1]:
		var q = PhysicsRayQueryParameters2D.create(from, from + Vector2(dir * 700.0, 0), 1)
		var hit = space.intersect_ray(q)
		if hit:
			if dir < 0:
				arena_l = hit.position.x + 12.0 * scale.x
			else:
				arena_r = hit.position.x - 12.0 * scale.x


func _check_phase():
	var new_phase = 0
	if hp * 4 <= max_hp:
		new_phase = 2
	elif hp * 2 <= max_hp:
		new_phase = 1
	if new_phase > phase and hp > 0:
		phase = new_phase
		plan_i = -1
		Game.popup("FURIOUS!" if phase == 2 else "ANGRY!", global_position + Vector2(0, -20 * scale.y), Color(1.0, 0.35, 0.3))
		Game.flash(Color(1.0, 0.3, 0.3), 0.3)
		Game.sfx("explosion", 0.5, 2.0)


func _set_state(s):
	state = s
	state_t = 0.0
	step = 0


func _next_state():
	var plan = PLANS[kind][phase]
	plan_i = (plan_i + 1) % plan.size()
	_set_state(plan[plan_i])


## How fast the fight runs: 1.0, then quicker in each phase.
func _tempo():
	return 1.0 + 0.2 * phase


func _face(x):
	direction = 1 if x > position.x else -1
	sprite.flip_h = direction < 0


func _start_jump(x, height, time):
	jump_from = position.x
	jump_to = clamp(x, arena_l, arena_r)
	jump_h = height
	jump_time = time
	_face(jump_to)


## Moves along the jump arc; returns true on landing.
func _jump_step(elapsed):
	var k = clamp(elapsed / jump_time, 0.0, 1.0)
	position.x = lerp(jump_from, jump_to, k)
	position.y = home.y - jump_h * 4.0 * k * (1.0 - k)
	return k >= 1.0


func _shockwave():
	Game.shake(7.0)
	Game.sfx("explosion", 0.7, 2.0)
	var feet = Vector2(position.x, home.y + 16 * scale.y)
	Game.ring(feet, 40.0, Color(1.0, 0.9, 0.6), 0.3)
	for dir in [-1, 1]:
		var w = Wave.new()
		w.dir = dir
		w.speed = 130.0 + 25.0 * phase
		w.position = feet + Vector2(dir * 10.0 * scale.x, 0)
		get_parent().add_child(w)


func _minion(minion_kind, dx):
	if get_tree().get_nodes_in_group("enemies").size() > 5:
		return
	var e = get_script().new()
	e.kind = minion_kind
	e.direction = 1 if dx > 0 else -1
	e.position = Vector2(clamp(position.x + dx, arena_l, arena_r), home.y + 16 * scale.y - 16)
	get_parent().add_child(e)
	Game.ring(e.position, 16.0, Color(1.0, 0.5, 0.8), 0.3)
	Game.sfx("tap", 0.5, 2.0)


func _boss(delta):
	state_t += delta
	var target = _nearest_player()
	var tx = target.global_position.x if target else position.x
	var tempo = _tempo()
	sprite.scale = Vector2.ONE
	match state:
		"rest":
			if not is_slime:
				sprite.play("idle")
			_face(tx)
			if state_t > 0.7 / tempo:
				_next_state()

		# --- shared: jump onto the heroes, shockwaves on landing
		"big", "leap":
			if step == 0:
				# wind-up
				_face(tx)
				sprite.scale = Vector2(1.15, 0.75)
				sprite.modulate = Color(1.0, 0.6, 0.6) if int(state_t * 14) % 2 == 0 else Color.WHITE
				if state_t > 0.55 / tempo:
					sprite.modulate = Color.WHITE
					_start_jump(tx, 110.0 if is_slime else 95.0, 0.95 / tempo)
					if not is_slime:
						sprite.play("jump")
					Game.sfx("jump", 0.5, 2.0)
					step = 1
					state_t = 0.0
			elif _jump_step(state_t):
				_shockwave()
				_set_state("rest")

		# --- QUEEN SLIME
		"hops":
			if step % 2 == 0:
				sprite.scale = Vector2(1.1, 0.85)
				if state_t > 0.22 / tempo:
					_start_jump(position.x + clamp(tx - position.x, -90.0, 90.0), 36.0, 0.55 / tempo)
					step += 1
					state_t = 0.0
			elif _jump_step(state_t):
				Game.sfx("tap", 0.45, -2.0)
				step += 1
				state_t = 0.0
				if step >= 6 + 2 * phase:
					_set_state("rest")
		"spit":
			_face(tx)
			sprite.scale = Vector2(0.9, 1.1)
			if state_t > 0.3 / tempo:
				state_t = 0.0
				step += 1
				var d = tx - position.x
				_throw_rock(Vector2(clamp(d * 1.05, -240.0, 240.0) + randf_range(-40.0, 40.0), randf_range(-290.0, -230.0)), Color(0.5, 1.0, 0.5))
				Game.sfx("tap", 0.8, -2.0)
				if step >= 4 + 2 * phase:
					_set_state("rest")
		"summon":
			if step == 0:
				step = 1
				if is_slime:
					_minion("spiky" if phase > 0 else "slime", -50.0)
					_minion("slime_purple" if phase > 1 else "slime", 50.0)
				else:
					_minion("charger" if phase > 1 else "pinky", -60.0)
					_minion("pinky", 60.0)
			if state_t > 0.8 / tempo:
				_set_state("rest")

		# --- KING PINKY
		"walk":
			sprite.play("walk")
			_face(tx)
			if abs(tx - position.x) > 24.0:
				position.x = clamp(position.x + direction * (46.0 + 14.0 * phase) * delta, arena_l, arena_r)
			_think_throw(delta)
			if state_t > 2.4 / tempo:
				_set_state("rest")
		"charge":
			if step == 0:
				# wind-up: stamps and flashes
				_face(tx)
				sprite.play("idle")
				sprite.modulate = Color(1.0, 0.45, 0.45) if int(state_t * 16) % 2 == 0 else Color.WHITE
				if state_t > 0.7 / tempo:
					sprite.modulate = Color.WHITE
					Game.popup("!", global_position + Vector2(0, -22 * scale.y), Color(1.0, 0.4, 0.3))
					Game.sfx("explosion", 1.2, -2.0)
					step = 1
			elif step == 1:
				sprite.play("run")
				sprite.speed_scale = 1.6
				position.x += direction * (250.0 + 40.0 * phase) * delta
				if position.x <= arena_l or position.x >= arena_r:
					position.x = clamp(position.x, arena_l, arena_r)
					Game.shake(6.0)
					Game.sfx("explosion", 0.9)
					sprite.speed_scale = 1.0
					step = 2
					state_t = 0.0
			else:
				# dizzy after hitting the wall: the best moment to jump on him
				sprite.play("hurt")
				if state_t > 1.1 / tempo:
					_set_state("rest")
		"rain":
			sprite.play("throw")
			if state_t > 0.22 / tempo:
				state_t = 0.0
				step += 1
				var m = Marker.new()
				m.position = Vector2(tx + randf_range(-70.0, 70.0) if step % 2 == 0 else randf_range(arena_l, arena_r), home.y + 16 * scale.y)
				m.position.x = clamp(m.position.x, arena_l - 10.0, arena_r + 10.0)
				get_parent().add_child(m)
				if step >= 8 + 4 * phase:
					_set_state("rest")
		_:
			_set_state("rest")


## Warning mark on the floor; a boulder drops on it a moment later.
class Marker extends Node2D:
	const RockScript = preload("res://scripts/rock.gd")
	var t = 0.0
	var dropped = false

	func _physics_process(delta):
		t += delta
		queue_redraw()
		if t > 0.65 and not dropped:
			dropped = true
			var r = RockScript.new()
			r.from_player = false
			r.big = true
			r.velocity = Vector2(0, 120.0)
			get_parent().add_child(r)
			r.global_position = global_position + Vector2(0, -158.0)
		if t > 1.3:
			queue_free()

	func _draw():
		var a = 0.35 + 0.35 * sin(t * 30.0)
		if t > 0.65:
			a *= max(0.0, 1.0 - (t - 0.65) * 2.0)
		draw_rect(Rect2(-7, -2, 14, 2), Color(1.0, 0.25, 0.2, a + 0.2))
		draw_line(Vector2(0, -2), Vector2(0, -158), Color(1.0, 0.3, 0.25, a * 0.5), 1.0)
