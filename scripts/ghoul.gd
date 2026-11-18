extends Node2D
## THE SHADOW: nobody knows what it is. Some time into a stage it appears behind the
## team and drifts after them, straight through walls.
##   - It is shy: while the hero it hunts LOOKS at it, it fades and barely moves.
##     Turn your back and it rushes in.
##   - Touching it hurts. A sandal makes it vanish and come back somewhere else.
##   - Hit it enough times and it is gone for good, leaving a chest behind.
## In the last act you find out what it really is.

var level
var hp = 5
var stun = 0.0          # ice sandals freeze it like anything else
var is_boss = false
var dead = false
var gone = 0.0          # seconds until it comes back
var t = 0.0
var sprite
var area: Area2D


func _ready():
	z_index = 7
	add_to_group("stalkers")
	hp = 4 + Game.act + Game.players.size()
	sprite = Game.puppet("stalker", 1.25, "walk")
	add_child(sprite)
	area = Area2D.new()
	area.collision_layer = 4
	area.collision_mask = 0
	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 12.0
	shape.shape = circle
	area.add_child(shape)
	add_child(area)
	_appear()


func _target():
	var best = null
	for p in get_tree().get_nodes_in_group("players"):
		if p.dead:
			continue
		if best == null or p.global_position.distance_to(global_position) < best.global_position.distance_to(global_position):
			best = p
	return best


## Comes out of nowhere, behind somebody's back.
func _appear():
	var heroes = get_tree().get_nodes_in_group("players").filter(func(p): return not p.dead)
	if heroes.is_empty():
		gone = 2.0
		return
	var p = heroes[randi() % heroes.size()]
	global_position = p.global_position + Vector2(-p.facing * 170.0, -50.0)
	visible = true
	area.collision_layer = 4
	sprite.modulate.a = 0.0
	Game.ring(global_position, 22.0, Color(0.6, 0.35, 0.9), 0.5)
	Game.sfx("explosion", 0.35, -6.0)


func _process(delta):
	t += delta
	if dead:
		return
	if gone > 0:
		gone -= delta
		if gone <= 0:
			_appear()
		return
	if stun > 0:
		stun -= delta
		sprite.modulate = Color(0.6, 0.9, 1.0, 0.9)
		return
	var p = _target()
	if p == null:
		return
	var to = p.global_position + Vector2(0, -14) - global_position
	var watched = -to.x * p.facing > 0 and abs(to.y) < 90.0
	var speed = 14.0 if watched else 62.0 + 6.0 * Game.act
	if to.length() > 2.0:
		global_position += to.normalized() * speed * delta
	sprite.flip_h = to.x < 0
	sprite.speed_scale = 0.4 if watched else 1.4
	var a = move_toward(sprite.modulate.a, 0.3 if watched else 0.95, delta * 1.6)
	sprite.modulate = Color(1, 1, 1, a)
	global_position.y += sin(t * 2.2) * 6.0 * delta
	for q in get_tree().get_nodes_in_group("players"):
		if q.dead or q.global_position.distance_to(global_position + Vector2(0, 14)) > 15.0:
			continue
		if q.star > 0:
			hit_by_rock(3)
			return
		q.hurt(global_position.x)


func hit_by_rock(power = 1, _from_x = null):
	if dead or gone > 0:
		return
	hp -= power
	Game.sfx("hurt", 0.6, -2.0)
	Game.ring(global_position, 26.0, Color(0.6, 0.35, 0.9), 0.4)
	if hp <= 0:
		dead = true
		area.collision_layer = 0
		Game.popup("THE SHADOW IS GONE... FOR NOW", global_position + Vector2(0, -26), Color(0.8, 0.6, 1.0))
		Game.flash(Color(0.6, 0.35, 0.9), 0.3)
		Game.add_gold(20 + 6 * Game.act, global_position)
		if level:
			level.spawn_chest(global_position)
		sprite.play("death")
		var tw = create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.8)
		tw.tween_callback(queue_free)
		return
	Game.popup(["...", "HSSSS", "?!"][randi() % 3], global_position + Vector2(0, -26), Color(0.8, 0.6, 1.0))
	gone = 3.5
	visible = false
	area.collision_layer = 0
