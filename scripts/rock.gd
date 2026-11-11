extends Area2D
## Anything thrown: rocks, Iheb's bottles and the heroes' sandals (look = "shleka").
## Player projectiles hurt enemies, enemy projectiles hurt players.

var velocity = Vector2.ZERO
var from_player = true
var big = false
var power = 1
var tint = Color.WHITE
var look = "rock"   # rock, shleka (sandal), bottle
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
	position += velocity * delta
	rotation += 12.0 * delta
	life -= delta
	if life <= 0:
		queue_free()


func _on_body(body):
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
		queue_free()


func _draw():
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
