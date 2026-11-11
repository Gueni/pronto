extends Camera2D
## Shared camera. Normally it follows the middle of all living heroes and zooms out when
## they spread apart. In auto-scrolling levels (level.scroll > 0) it glides to the right on
## its own with a fixed zoom, and the heroes have to keep up.

const BASE_ZOOM = 4.0
const SCROLL_ZOOM_TEAM = 3.5

var level
var min_zoom = 2.5
var snapped = false
var shake = 0.0
var goal_zoom = BASE_ZOOM


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


## Width of the visible part of the level, in world pixels.
func view_width():
	return get_viewport_rect().size.x / zoom.x


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
	var vs = get_viewport_rect().size
	var center = global_position
	var z = goal_zoom
	if level.scroll > 0:
		z = BASE_ZOOM if level.players.size() <= 1 else SCROLL_ZOOM_TEAM
		center.x = level.scroll_x + vs.x / z * 0.2
		if any:
			center.y = (lo.y + hi.y) * 0.5 - 16.0
	elif any:
		center = (lo + hi) * 0.5 + Vector2(0, -16)
		# Zoom only reacts to real distance between heroes: a jump, a spring or an
		# ultimate must not make the whole screen pump in and out.
		var want = min(vs.x / (hi.x - lo.x + 150.0), vs.y / (max(hi.y - lo.y - 60.0, 0.0) + 150.0))
		want = clamp(want, min_zoom, BASE_ZOOM)
		if abs(want - goal_zoom) > 0.08 * goal_zoom or want == BASE_ZOOM:
			goal_zoom = want
		z = goal_zoom
	else:
		return
	if not snapped:
		snapped = true
		global_position = center
		zoom = Vector2(z, z)
		reset_smoothing()
		return
	if level.scroll > 0:
		global_position.x = center.x
		global_position.y = lerp(global_position.y, center.y, 1.0 - exp(-5.0 * delta))
	else:
		global_position = global_position.lerp(center, 1.0 - exp(-9.0 * delta))
	# Zoom out quickly (nobody may leave the screen), zoom back in gently.
	var rate = 6.0 if z < zoom.x else 1.6
	zoom = zoom.lerp(Vector2(z, z), 1.0 - exp(-rate * delta))
	# Screen shake (ultimates, bosses).
	if shake > 0.05:
		offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake
		shake = lerp(shake, 0.0, 1.0 - exp(-9.0 * delta))
	else:
		offset = Vector2.ZERO
