extends AnimatableBody2D
## One-way platform gliding back and forth along `travel`.

const TEX = preload("res://assets/sprites/platforms.png")

var travel = Vector2(80, 0)
var period = 4.0
var phase = 0.0
var style_row = 0
var origin = Vector2.ZERO
var t = 0.0


func _ready():
	origin = position
	t = phase * period
	var s = Sprite2D.new()
	s.texture = TEX
	s.region_enabled = true
	s.region_rect = Rect2(16, style_row * 16, 32, 10)
	add_child(s)
	var c = CollisionShape2D.new()
	var r = RectangleShape2D.new()
	r.size = Vector2(31, 7)
	c.shape = r
	c.position = Vector2(0, -0.5)
	c.one_way_collision = true
	add_child(c)
	position = origin + travel * (0.5 - 0.5 * cos(t * TAU / period))


func _physics_process(delta):
	t += delta
	position = origin + travel * (0.5 - 0.5 * cos(t * TAU / period))
