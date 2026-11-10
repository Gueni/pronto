extends Area2D
## The flagpole at the end of a level. Origin is at ground level.

var flag_y = -18.0
var reached = false


func _ready():
	collision_layer = 0
	collision_mask = 2
	var c = CollisionShape2D.new()
	var r = RectangleShape2D.new()
	r.size = Vector2(10, 96)
	c.shape = r
	c.position = Vector2(0, -48)
	add_child(c)
	body_entered.connect(_on_body)


func _draw():
	draw_rect(Rect2(-6, -4, 12, 4), Color(0.25, 0.27, 0.35))
	draw_rect(Rect2(-1, -72, 2, 68), Color(0.85, 0.88, 0.95))
	draw_circle(Vector2(0, -74), 3, Color(1.0, 0.85, 0.3))
	var col = Color(0.3, 0.7, 1.0) if reached else Color(0.95, 0.3, 0.35)
	draw_colored_polygon(PackedVector2Array([Vector2(1, flag_y), Vector2(16, flag_y + 5), Vector2(1, flag_y + 10)]), col)


func _process(_delta):
	if reached:
		queue_redraw()


func _on_body(body):
	if reached or not body.has_method("hurt") or body.dead:
		return
	var level = Game.level_node
	if level == null or level.finished:
		return
	reached = true
	create_tween().tween_property(self, "flag_y", -70.0, 0.8)
	level.complete()
