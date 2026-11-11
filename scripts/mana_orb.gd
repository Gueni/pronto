extends Area2D
## Floating blue orb: fills a big chunk of the mana bar. Origin is the centre of a tile.

const AMOUNT = 40

var t = 0.0
var taken = false


func _ready():
	z_index = 4
	collision_layer = 0
	collision_mask = 2
	var c = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 7.0
	c.shape = circle
	add_child(c)
	body_entered.connect(_on_body)
	t = position.x * 0.05


func _process(delta):
	t += delta
	queue_redraw()


func _draw():
	var o = Vector2(0, sin(t * 3.0) * 2.0)
	draw_circle(o, 7.0 + sin(t * 6.0), Color(0.3, 0.6, 1.0, 0.25))
	draw_circle(o, 4.5, Color(0.25, 0.55, 1.0))
	draw_circle(o, 3.0, Color(0.55, 0.85, 1.0))
	draw_circle(o + Vector2(-1.5, -1.5), 1.0, Color.WHITE)


func _on_body(body):
	if taken or not body.has_method("add_mana") or body.dead:
		return
	taken = true
	body.add_mana(AMOUNT)
	Game.popup("+MANA", global_position, Color(0.5, 0.8, 1.0))
	Game.sfx("coin", 0.6)
	queue_free()
