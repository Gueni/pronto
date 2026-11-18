extends Node2D
## A treasure chest. Mini-bosses drop one, bosses drop five. Walk up to it to open it:
## inside is DAN, hearts, mana, a boon... or a minigame (see events.gd).
## It falls until it lands; the origin is the bottom of the chest.

const Events = preload("res://scripts/events.gd")

var level
var vy = 0.0
var landed = false
var opened = false
var t = 0.0
var open_t = 0.0


func _ready():
	z_index = 4
	add_to_group("chests")


func _physics_process(delta):
	t += delta
	queue_redraw()
	if not landed:
		vy = min(vy + 600.0 * delta, 320.0)
		var step = vy * delta
		var space = get_world_2d().direct_space_state
		var hit = space.intersect_ray(PhysicsRayQueryParameters2D.create(global_position + Vector2(0, -4), global_position + Vector2(0, step + 1), 1))
		if hit:
			global_position.y = hit.position.y
			landed = true
			Game.sfx("tap", 0.6)
		else:
			position.y += step
			if position.y > 100000:
				_gone()
		return
	if opened:
		open_t += delta
		if open_t > 3.0:
			modulate.a = max(modulate.a - delta * 2.0, 0.0)
			if modulate.a <= 0:
				queue_free()
		return
	for p in get_tree().get_nodes_in_group("players"):
		if not p.dead and p.global_position.distance_to(global_position) < 15.0:
			_open(p)
			return


func _gone():
	if level and not opened:
		level.chests_left -= 1
	queue_free()


func _open(p):
	opened = true
	remove_from_group("chests")
	if level:
		level.chests_left -= 1
	Game.sfx("power_up", 1.2)
	Game.ring(global_position + Vector2(0, -8), 24.0, Color(1.0, 0.85, 0.3), 0.4)
	var top = global_position + Vector2(0, -14)
	var roll = randf()
	if roll < 0.12:
		var pickup = load("res://scripts/pickup.gd")
		var k = pickup.new()
		k.kind = pickup.POWERS[randi() % pickup.POWERS.size()]
		k.position = position + Vector2(0, -22)
		get_parent().add_child(k)
		Game.popup("POWER-UP!", top, Color(1.0, 0.9, 0.4))
	elif roll < 0.34:
		Game.add_gold(12 + randi() % 14 + 8 * Game.act, top)
		p.say("power", 0.7)
	elif roll < 0.48:
		for q in get_tree().get_nodes_in_group("players"):
			if not q.dead:
				q.heal()
		p.heal()
		Game.popup("HEARTS!", top, Color(1.0, 0.5, 0.5))
	elif roll < 0.58:
		for q in get_tree().get_nodes_in_group("players"):
			if not q.dead:
				q.add_mana(Game.MAX_MANA)
		Game.popup("FULL MANA!", top, Color(0.5, 0.8, 1.0))
	elif roll < 0.70:
		var boons = Game.roll_boons(1)
		if boons.is_empty():
			Game.add_gold(40, top)
		else:
			Game.add_boon(boons[0].id)
			Game.popup(boons[0].name + "!", top, Color(1.0, 0.9, 0.4))
			Game.flash(Color(1.0, 0.9, 0.4), 0.3)
	elif level:
		Events.start(level, global_position, p)
	else:
		Game.add_gold(20, top)


func _draw():
	var lid = 0.0 if not opened else min(open_t * 6.0, 1.0)
	var wood = Color(0.55, 0.34, 0.16)
	var gold = Color(1.0, 0.82, 0.25)
	if not opened and landed:
		draw_circle(Vector2(0, -7), 15.0 + sin(t * 4.0) * 2.0, Color(1.0, 0.85, 0.3, 0.15))
	draw_rect(Rect2(-8, -9, 16, 9), wood)
	draw_rect(Rect2(-8, -3, 16, 3), wood.darkened(0.3))
	draw_rect(Rect2(-8, -9, 2, 9), gold)
	draw_rect(Rect2(6, -9, 2, 9), gold)
	if lid > 0:
		draw_rect(Rect2(-7, -9, 14, 2), Color(0.15, 0.08, 0.05))
		draw_rect(Rect2(-5, -10, 3, 2), gold)
		draw_rect(Rect2(1, -10, 4, 2), gold.lightened(0.3))
	var ly = -14.0 - lid * 6.0
	draw_rect(Rect2(-8, ly, 16, 5), wood.lightened(0.1))
	draw_rect(Rect2(-8, ly, 16, 1), gold)
	draw_rect(Rect2(-8, ly + 4, 16, 1), gold)
	if lid <= 0:
		draw_rect(Rect2(-1.5, -11, 3, 4), gold)
