extends Camera2D
## Shared camera. It follows the middle of all living heroes (with a little look-ahead) and
## zooms out when they spread apart. In auto-scrolling levels (level.scroll > 0) it glides
## to the right on its own with a fixed zoom, and the heroes have to keep up.
##
## How much of the world you see does not depend on the window: the zoom is computed from
## the size of the screen so that a fixed number of tiles fits top to bottom (the CAMERA
## setting: far / normal / close). Any resolution or aspect ratio shows the same game.

var level
var min_zoom = 1.5
var snapped = false
var shake = 0.0
var goal_zoom = 3.0
var bounds = null      # Rect2 the camera may show (the current zone)
var look = 0.0         # look-ahead, in pixels


func _ready():
	get_viewport().size_changed.connect(_refit)
	_refit()
	zoom = Vector2(base_zoom(), base_zoom())
	goal_zoom = base_zoom()


## The zoom at which the chosen number of tiles fits the height of the screen.
func base_zoom():
	var vs = get_viewport_rect().size
	var tiles = Game.VIEW_TILES[clamp(Game.settings.zoom, 0, Game.VIEW_TILES.size() - 1)]
	var z = vs.y / (tiles * 16.0)
	return max(z, _fit_zoom())


## The smallest zoom that still keeps the screen inside the zone.
func _fit_zoom():
	if bounds == null:
		return 0.5
	var vs = get_viewport_rect().size
	return max(vs.x / bounds.size.x, vs.y / bounds.size.y)


func _refit():
	min_zoom = max(base_zoom() * 0.62, _fit_zoom())


## The team entered another zone (or the level just started).
func set_limits(rect):
	bounds = rect
	limit_left = int(rect.position.x)
	limit_top = int(rect.position.y)
	limit_right = int(rect.end.x)
	limit_bottom = int(rect.end.y)
	_refit()
	snapped = false


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
	var facing = 0.0
	for p in level.players:
		if p.dead:
			continue
		any = true
		lo = lo.min(p.global_position)
		hi = hi.max(p.global_position)
		facing += p.facing
	var vs = get_viewport_rect().size
	var base = base_zoom()
	var center = global_position
	var z = goal_zoom
	if level.scroll > 0:
		z = base if level.players.size() <= 1 else max(base * 0.88, min_zoom)
		center.x = level.scroll_x + vs.x / z * 0.2
		if any:
			center.y = (lo.y + hi.y) * 0.5 - 16.0
	elif any:
		# A little look-ahead in the direction the team is facing.
		look = lerp(look, clamp(facing, -1.0, 1.0) * 26.0, 1.0 - exp(-2.5 * delta))
		center = (lo + hi) * 0.5 + Vector2(look, -20)
		# Zoom only reacts to real distance between heroes: a jump, a spring or an
		# ultimate must not make the whole screen pump in and out.
		var want = min(vs.x / (hi.x - lo.x + 190.0), vs.y / (max(hi.y - lo.y - 60.0, 0.0) + 190.0))
		want = clamp(want, min_zoom, base)
		if abs(want - goal_zoom) > 0.08 * goal_zoom or want == base:
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
		global_position.y = lerp(global_position.y, center.y, 1.0 - exp(-8.0 * delta))
	else:
		global_position = global_position.lerp(center, 1.0 - exp(-16.0 * delta))
	# Zoom out quickly (nobody may leave the screen), zoom back in a bit slower.
	var rate = 9.0 if z < zoom.x else 3.5
	zoom = zoom.lerp(Vector2(z, z), 1.0 - exp(-rate * delta))
	# Screen shake (ultimates, bosses).
	if shake > 0.05:
		offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake
		shake = lerp(shake, 0.0, 1.0 - exp(-9.0 * delta))
	else:
		offset = Vector2.ZERO
