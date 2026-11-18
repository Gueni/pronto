extends Area2D
## Anything thrown: rocks, Iheb's bottles and the heroes' sandals (look = "shleka").
## Player projectiles hurt enemies, enemy projectiles hurt players.

var velocity = Vector2.ZERO
var from_player = true
var big = false
var power = 1
var tint = Color.WHITE
var look = "rock"   # rock, shleka (sandal), bottle, fire (bouncing fireball), ice (freezes)
var grav = 500.0
var life = 4.0


func _ready():
	z_index = 6
	collision_layer = 0
	collision_mask = 1 | (4 if from_player else 2)
	if look == "rock":
		var s = Sprite2D.new()
		s.texture = load("res://assets/sprites/3 Dude_Monster/Rock2.png" if big else "res://assets/sprites/3 Dude_Monster/Rock1.png")
		s.modulate = tint
		add_child(s)
	var c = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 5.0 if big else 3.0
	c.shape = circle
	add_child(c)
	body_entered.connect(_on_body)
	area_entered.connect(_on_area)


func _physics_process(delta):
	velocity.y += grav * delta
	if look == "fire" or look == "ice":
		queue_redraw()
	if look == "fire" and from_player:
		# fireballs skip along the ground and die on walls
		var space = get_world_2d().direct_space_state
		var step = velocity * delta
		if velocity.y > 0:
			var floor_hit = space.intersect_ray(PhysicsRayQueryParameters2D.create(global_position, global_position + Vector2(0, step.y + 4.0), 1))
			if floor_hit:
				velocity.y = -175.0
				global_position.y = floor_hit.position.y - 4.0
		var wall = space.intersect_ray(PhysicsRayQueryParameters2D.create(global_position, global_position + Vector2(sign(velocity.x) * (abs(step.x) + 4.0), 0), 1))
		if wall:
			Game.ring(global_position, 9.0, Color(1.0, 0.6, 0.2), 0.2)
			queue_free()
			return
	position += velocity * delta
	if look == "feather":
		rotation = velocity.angle()
	else:
		rotation += 12.0 * delta
	life -= delta
	if life <= 0:
		queue_free()


func _on_body(body):
	if look == "fire" and from_player:
		return   # the rays in _physics_process deal with ground and walls
	if body.has_method("hurt"):
		if from_player:
			return
		body.hurt(global_position.x)
	queue_free()


func _on_area(area):
	if not from_player:
		return
	var e = area.get_parent()
	if e and e.has_method("hit_by_rock"):
		e.hit_by_rock(power, global_position.x - velocity.x * 0.05)
		if look == "ice" and "stun" in e:
			e.stun = max(e.stun, 0.8 if e.is_boss else 3.0)
			Game.ring(global_position, 14.0, Color(0.55, 0.9, 1.0), 0.3)
		elif look == "fire":
			Game.ring(global_position, 11.0, Color(1.0, 0.6, 0.2), 0.25)
		queue_free()


func _draw():
	if look == "fire":
		draw_circle(Vector2.ZERO, 4.5, Color(1.0, 0.4, 0.1))
		draw_circle(Vector2(1, 0), 3.0, Color(1.0, 0.75, 0.2))
		draw_circle(Vector2(1.5, 0), 1.4, Color(1, 1, 0.85))
		draw_colored_polygon(PackedVector2Array([Vector2(-3, -3), Vector2(-9, 0), Vector2(-3, 3)]), Color(1.0, 0.5, 0.1, 0.8))
		return
	if look == "feather":
		draw_line(Vector2(-5, 0), Vector2(5, 0), Color(0.95, 0.9, 0.8), 2.0)
		draw_line(Vector2(-5, 0), Vector2(1, 0), Color(0.62, 0.44, 0.26), 1.0)
		return
	if look == "ice":
		draw_colored_polygon(PackedVector2Array([Vector2(0, -5), Vector2(4, 0), Vector2(0, 5), Vector2(-4, 0)]), Color(0.55, 0.9, 1.0))
		draw_colored_polygon(PackedVector2Array([Vector2(0, -5), Vector2(4, 0), Vector2(0, 0)]), Color(0.9, 1.0, 1.0))
		return
	if look == "shleka":
		# a flip-flop: sole, strap
		draw_rect(Rect2(-5, -2, 10, 4), Color(0.25, 0.5, 0.95))
		draw_rect(Rect2(-5, -2, 10, 1), Color(0.5, 0.75, 1.0))
		draw_line(Vector2(-1, -2), Vector2(3, 1.5), Color(1.0, 0.9, 0.3), 1.2)
		draw_line(Vector2(-1, -2), Vector2(3, -2.5), Color(1.0, 0.9, 0.3), 1.2)
	elif look == "bottle":
		var k = 1.5 if big else 1.0
		draw_rect(Rect2(-2 * k, -3 * k, 4 * k, 7 * k), Color(0.55, 0.35, 0.1))
		draw_rect(Rect2(-1 * k, -6 * k, 2 * k, 3 * k), Color(0.55, 0.35, 0.1))
		draw_rect(Rect2(-2 * k, -1 * k, 4 * k, 2 * k), Color(0.95, 0.9, 0.7))
