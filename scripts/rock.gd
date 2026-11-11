extends Area2D
## A thrown rock. Player rocks hurt enemies, enemy rocks hurt players.

var velocity = Vector2.ZERO
var from_player = true
var big = false
var power = 1
var tint = Color.WHITE
var grav = 500.0
var life = 4.0


func _ready():
	z_index = 6
	collision_layer = 0
	collision_mask = 1 | (4 if from_player else 2)
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
		e.hit_by_rock(power)
		queue_free()
