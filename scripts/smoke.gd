extends Node2D
## Gueni's smoke break: a green cloud. Enemies inside are dizzy (stunned) as long as it lasts.

const RADIUS = 46.0

var life = 4.0
var t = 0.0
var puffs = []


func _ready():
	z_index = 7
	for i in 9:
		puffs.append([Vector2(randf_range(-30, 30), randf_range(-22, 14)), randf_range(14, 24), randf() * TAU])


func _physics_process(delta):
	t += delta
	queue_redraw()
	if t >= life:
		queue_free()
		return
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.dead or e.is_boss or not e.awake:
			continue
		if e.global_position.distance_to(global_position) < RADIUS + 8.0 * e.scale.x:
			e.stun = max(e.stun, 0.6)


func _draw():
	var a = clamp(t * 4.0, 0.0, 1.0) * clamp((life - t) * 1.5, 0.0, 1.0)
	for p in puffs:
		var o = p[0] + Vector2(sin(t * 1.3 + p[2]) * 5.0, cos(t * 1.1 + p[2]) * 4.0 - t * 2.0)
		draw_circle(o, p[1], Color(0.55, 0.8, 0.5, 0.22 * a))
		draw_circle(o + Vector2(-3, -3), p[1] * 0.6, Color(0.8, 0.95, 0.75, 0.16 * a))
