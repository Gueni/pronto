extends Area2D
## Spikes (hurt) and lava (instant death). Origin is the centre of a tile.

var kind = "spike"


func _ready():
	collision_layer = 0
	collision_mask = 2
	var c = CollisionShape2D.new()
	var r = RectangleShape2D.new()
	if kind == "lava":
		r.size = Vector2(16, 10)
		c.position = Vector2(0, 3)
	else:
		r.size = Vector2(12, 6)
		c.position = Vector2(0, 5)
	c.shape = r
	add_child(c)


func _draw():
	if kind != "spike":
		return
	for i in 3:
		var x = -8 + i * 5.33
		draw_colored_polygon(PackedVector2Array([Vector2(x, 8), Vector2(x + 2.67, -1), Vector2(x + 5.33, 8)]), Color(0.62, 0.65, 0.75))
		draw_line(Vector2(x + 2.67, -1), Vector2(x + 5.33, 8), Color(0.16, 0.14, 0.24), 1.0)
		draw_line(Vector2(x, 8), Vector2(x + 2.67, -1), Color(0.16, 0.14, 0.24), 1.0)


func _physics_process(_delta):
	for body in get_overlapping_bodies():
		if body.has_method("hurt"):
			if kind == "lava":
				body.die()
			else:
				body.hurt(null)
