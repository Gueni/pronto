extends Node2D
## A mystery door standing somewhere in a zone. Stand in front of it and press DOWN to
## go in: most of the time a minigame starts (see events.gd), sometimes it is a quiet
## room with a power-up, DAN or hearts. One visit per door.
## The origin is the middle of the doorstep.

const Events = preload("res://scripts/events.gd")
const Pickup = preload("res://scripts/pickup.gd")

var level
var used = false
var near = false
var t = 0.0


func _ready():
	z_index = 1
	add_to_group("doors")


func _process(delta):
	t += delta
	queue_redraw()
	near = false
	if used:
		return
	for p in get_tree().get_nodes_in_group("players"):
		if p.dead or p.locked:
			continue
		var d = p.global_position - global_position
		if abs(d.x) < 13.0 and abs(d.y) < 22.0:
			near = true
			if p.is_on_floor() and Input.is_action_just_pressed(p.inp + "_down"):
				_enter(p)
				return


func _enter(p):
	used = true
	near = false
	remove_from_group("doors")
	Game.sfx("power_up", 0.8)
	Game.ring(global_position + Vector2(0, -12), 26.0, Color(0.75, 0.5, 1.0), 0.4)
	var top = global_position + Vector2(0, -30)
	var roll = randf()
	if roll < 0.55 and level:
		Events.start(level, global_position, p)
	elif roll < 0.78:
		var k = Pickup.new()
		k.kind = Pickup.POWERS[randi() % Pickup.POWERS.size()]
		k.position = position + Vector2(0, -22)
		get_parent().add_child(k)
		Game.popup("A GIFT!", top, Color(1.0, 0.9, 0.4))
	elif roll < 0.92:
		Game.add_gold(15 + randi() % 20 + 6 * Game.act, top)
		p.say("power", 0.7)
	else:
		for q in get_tree().get_nodes_in_group("players"):
			if not q.dead:
				q.heal()
		Game.popup("A QUIET ROOM. HEARTS!", top, Color(1.0, 0.5, 0.5))


func _draw():
	var stone = Color(0.42, 0.4, 0.5)
	var glow = Color(0.75, 0.5, 1.0)
	if not used:
		draw_circle(Vector2(0, -14), 20.0 + sin(t * 3.0) * 2.0, Color(glow.r, glow.g, glow.b, 0.12))
	# stone arch
	var arch = PackedVector2Array([Vector2(-11, 0), Vector2(-11, -20)])
	for i in 9:
		var a = PI + PI * i / 8.0
		arch.append(Vector2(cos(a) * 11.0, -20 + sin(a) * 10.0))
	arch.append(Vector2(11, 0))
	draw_colored_polygon(arch, stone)
	# what is behind it
	var inside = PackedVector2Array([Vector2(-8, 0), Vector2(-8, -19)])
	for i in 9:
		var a = PI + PI * i / 8.0
		inside.append(Vector2(cos(a) * 8.0, -19 + sin(a) * 8.0))
	inside.append(Vector2(8, 0))
	if used:
		draw_colored_polygon(inside, Color(0.05, 0.03, 0.08))
	else:
		draw_colored_polygon(inside, Color(0.45, 0.27, 0.13))
		draw_line(Vector2(0, 0), Vector2(0, -27), Color(0.25, 0.14, 0.07), 1.0)
		for y in [-6.0, -17.0]:
			draw_line(Vector2(-8, y), Vector2(8, y), Color(0.3, 0.3, 0.38), 1.5)
		draw_circle(Vector2(2.5, -11), 1.2, Color(1.0, 0.82, 0.25))
		# light leaking out from under the door
		draw_rect(Rect2(-8, -1, 16, 1), Color(glow.r, glow.g, glow.b, 0.6 + 0.4 * sin(t * 5.0)))
		var bob = sin(t * 3.0) * 1.5
		draw_string(Game.FONT_BOLD, Vector2(-10, -34 + bob), "?", HORIZONTAL_ALIGNMENT_CENTER, 20, 8, glow.lightened(0.3))
	draw_polyline(arch, Color(0.13, 0.09, 0.16), 1.0, true)
	if near:
		draw_string(Game.FONT, Vector2(-40, -46), "DOWN: ENTER", HORIZONTAL_ALIGNMENT_CENTER, 80, 8, Color.WHITE)
