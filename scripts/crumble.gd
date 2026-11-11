extends StaticBody2D
## Crumbling plank: shakes when a hero stands on it, drops away, and grows back later.
## Origin is the centre of a tile.

var state = "idle"   # idle, shaking, gone
var timer = 0.0
var shape: CollisionShape2D
var sensor: Area2D
var tint = Color(0.72, 0.5, 0.3)


func _ready():
	shape = CollisionShape2D.new()
	var r = RectangleShape2D.new()
	r.size = Vector2(16, 6)
	shape.shape = r
	shape.position = Vector2(0, -5)
	shape.one_way_collision = true
	add_child(shape)
	sensor = Area2D.new()
	sensor.collision_layer = 0
	sensor.collision_mask = 2
	var c = CollisionShape2D.new()
	var sr = RectangleShape2D.new()
	sr.size = Vector2(14, 4)
	c.shape = sr
	c.position = Vector2(0, -11)
	sensor.add_child(c)
	add_child(sensor)


func _physics_process(delta):
	match state:
		"idle":
			for body in sensor.get_overlapping_bodies():
				if body.has_method("hurt") and body.is_on_floor():
					state = "shaking"
					timer = 0.5
					Game.sfx("tap", 0.5, -6.0)
					break
		"shaking":
			timer -= delta
			queue_redraw()
			if timer <= 0:
				state = "gone"
				timer = 3.0
				shape.set_deferred("disabled", true)
				Game.sfx("explosion", 1.8, -14.0)
		"gone":
			timer -= delta
			queue_redraw()
			if timer <= 0:
				state = "idle"
				shape.set_deferred("disabled", false)


func _draw():
	var o = Vector2.ZERO
	var a = 1.0
	if state == "shaking":
		o = Vector2(randf_range(-1, 1), randf_range(-0.5, 0.5))
	elif state == "gone":
		if timer > 2.7:
			o = Vector2(0, (3.0 - timer) * 60.0)
			a = (timer - 2.7) / 0.3
		elif timer < 0.4:
			a = 0.35
		else:
			return
	var c = Color(tint.r, tint.g, tint.b, a)
	var dark = Color(tint.r * 0.55, tint.g * 0.55, tint.b * 0.55, a)
	draw_rect(Rect2(o.x - 8, o.y - 8, 16, 6), c)
	draw_rect(Rect2(o.x - 8, o.y - 3, 16, 1), dark)
	draw_line(o + Vector2(-3, -8), o + Vector2(-1, -5), dark, 1.0)
	draw_line(o + Vector2(-1, -5), o + Vector2(-4, -3), dark, 1.0)
	draw_line(o + Vector2(4, -8), o + Vector2(3, -3), dark, 1.0)
