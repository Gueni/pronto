extends Camera2D
## Shared camera: follows the middle of all living heroes and zooms out when they spread.

const BASE_ZOOM = 4.0

var level
var min_zoom = 2.5
var snapped = false


func _ready():
	zoom = Vector2(BASE_ZOOM, BASE_ZOOM)
	var vs = get_viewport_rect().size
	if limit_bottom < 100000 and limit_top > -100000:
		min_zoom = max(min_zoom, vs.y / float(limit_bottom - limit_top))
	if limit_right < 100000 and limit_left > -100000:
		min_zoom = max(min_zoom, vs.x / float(limit_right - limit_left))
	min_zoom = min(min_zoom, BASE_ZOOM)


## How far apart heroes may get before the screen can't hold them.
func max_spread():
	return get_viewport_rect().size.x / min_zoom - 48.0


func _process(delta):
	if level == null:
		return
	var lo = Vector2(INF, INF)
	var hi = Vector2(-INF, -INF)
	var any = false
	for p in level.players:
		if p.dead:
			continue
		any = true
		lo = lo.min(p.global_position)
		hi = hi.max(p.global_position)
	if not any:
		return
	var center = (lo + hi) * 0.5 + Vector2(0, -16)
	var vs = get_viewport_rect().size
	var z = min(vs.x / (hi.x - lo.x + 150.0), vs.y / (hi.y - lo.y + 120.0))
	z = clamp(z, min_zoom, BASE_ZOOM)
	if not snapped:
		snapped = true
		global_position = center
		zoom = Vector2(z, z)
		reset_smoothing()
		return
	global_position = global_position.lerp(center, 1.0 - exp(-9.0 * delta))
	zoom = zoom.lerp(Vector2(z, z), 1.0 - exp(-4.0 * delta))
