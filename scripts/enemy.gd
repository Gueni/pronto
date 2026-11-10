extends Node2D
## All the baddies. Origin is 16px above the feet (the centre of a 32px monster frame).
## kind: pinky (walker), grump (rock thrower), slime, slime_purple (fast, 2 hits), boss.

const Rock = preload("res://scripts/rock.gd")

@export var kind = "pinky"

var speed = 45.0
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
var awake = true
var hit_size = Vector2(13, 22)

var sprite: AnimatedSprite2D
var hitbox: Area2D
var hit_shape: CollisionShape2D
var rays = {}


func _ready():
	add_to_group("enemies")
	sprite = AnimatedSprite2D.new()
	add_child(sprite)
	var hit_pos = Vector2(-0.5, 4)
	match kind:
		"slime", "slime_purple":
			is_slime = true
			var purple = kind == "slime_purple"
			sprite.sprite_frames = Game.slime_frames("res://assets/sprites/slime_purple.png" if purple else "res://assets/sprites/slime_green.png")
			sprite.position = Vector2(0, 4)
			sprite.play("walk")
			speed = 55.0 if purple else 24.0
			hp = 2 if purple else 1
			score_value = 300 if purple else 100
			hit_size = Vector2(13, 11)
			hit_pos = Vector2(0, 10)
		"grump":
			sprite.sprite_frames = Game.frames_for(Game.PINK)
			sprite.material = Game.hue_material(0.14)
			sprite.play("idle")
			sprite.animation_finished.connect(func(): if not dead: sprite.play("idle"))
			speed = 0.0
			score_value = 400
			throw_range = 150.0
		"boss":
			sprite.sprite_frames = Game.frames_for(Game.PINK)
			sprite.play("walk")
			scale = Vector2(2, 2)
			speed = 42.0
			hp = 6
			score_value = 5000
			throw_range = 260.0
			throw_interval = 2.6
		_:
			sprite.sprite_frames = Game.frames_for(Game.PINK)
			sprite.play("walk")
	max_hp = hp

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
	if kind == "boss":
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
		# The boss waits until a hero walks into his arena.
		var p = _nearest_player()
		if p == null or abs(p.global_position.x - global_position.x) > 250:
			return
		awake = true
		Game.boss_changed.emit(hp, max_hp)
		Game.sfx("explosion", 0.6)
	frames_alive += 1
	if frames_alive == 3:
		# Only patrol ledges when actually standing on something.
		use_ledges = rays["floor"].is_colliding()
	if invuln > 0:
		invuln -= delta
		sprite.modulate = Color(1, 0.5, 0.5) if int(invuln * 16) % 2 == 0 else Color.WHITE
		if invuln <= 0:
			sprite.modulate = Color.WHITE

	if speed > 0:
		var key = str(direction)
		if rays["wall" + key].is_colliding() or (use_ledges and not rays["ledge" + key].is_colliding()):
			direction = -direction
		position.x += direction * speed * delta
		sprite.flip_h = direction < 0

	if throw_range > 0:
		_think_throw(delta)

	for body in hitbox.get_overlapping_bodies():
		if body.has_method("hurt"):
			_touch(body)


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
	if speed == 0:
		sprite.flip_h = d.x < 0
	throw_timer -= delta
	if throw_timer <= 0 and abs(d.x) < throw_range and abs(d.y) < 130:
		throw_timer = throw_interval
		if speed == 0:
			sprite.play("throw")
		var r = Rock.new()
		r.from_player = false
		r.big = kind == "boss"
		r.velocity = Vector2(clamp(d.x * 1.1, -210.0, 210.0), -230.0)
		get_parent().add_child(r)
		r.global_position = global_position + Vector2(0, -6 * scale.y)


func _touch(p):
	if p.dead or dead:
		return
	var top = hit_shape.global_position.y - hit_size.y * 0.5 * scale.y
	if p.velocity.y > 0 and p.global_position.y < top + 9 * scale.y:
		p.bounce()
		damage(true)
	elif invuln <= 0 or kind == "boss":
		p.hurt(global_position.x)


func hit_by_rock():
	damage(false)


func damage(stomped):
	if dead or invuln > 0:
		return
	hp -= 1
	if kind == "boss":
		Game.boss_changed.emit(hp, max_hp)
	if hp <= 0:
		_die(stomped)
		return
	Game.sfx("tap", 0.6, 4.0)
	invuln = 1.2 if kind == "boss" else 0.5
	speed *= 1.22
	throw_interval *= 0.88


func _die(stomped):
	dead = true
	hitbox.set_deferred("monitoring", false)
	hitbox.collision_layer = 0
	sprite.modulate = Color.WHITE
	Game.add_score(score_value, global_position)
	if kind == "boss":
		_boss_death()
		return
	if stomped:
		Game.sfx("tap", 0.75, 3.0)
	else:
		Game.sfx("explosion", 1.4, -8.0)
	if is_slime or stomped:
		var tw = create_tween()
		tw.tween_property(self, "scale", Vector2(1.3, 0.25), 0.1)
		tw.parallel().tween_property(self, "position:y", position.y + 12, 0.1)
		tw.tween_interval(0.3)
		tw.tween_callback(queue_free)
	else:
		sprite.play("death")
		var tw = create_tween()
		tw.tween_interval(0.85)
		tw.tween_callback(queue_free)


func _boss_death():
	sprite.play("hurt")
	for i in 6:
		Game.sfx("explosion", 0.8 + randf() * 0.6, -4.0)
		sprite.modulate = Color(1, 0.4, 0.4) if i % 2 == 0 else Color.WHITE
		await get_tree().create_timer(0.22, false).timeout
	sprite.modulate = Color.WHITE
	sprite.play("death")
	await get_tree().create_timer(0.9, false).timeout
	visible = false
	if Game.level_node and is_instance_valid(Game.level_node):
		Game.level_node.complete()
