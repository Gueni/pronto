extends Node2D
## Base script for every level (attach to the level root).
## Spawns the heroes, the shared camera, goal flag and checkpoints, and runs the clock.
## Hand-made levels only need a node called "player" as the start position.

const PlayerScene = preload("res://scenes/player.tscn")
const GameCamera = preload("res://scripts/game_camera.gd")
const Goal = preload("res://scripts/goal.gd")
const Checkpoint = preload("res://scripts/checkpoint.gd")
const OFFSETS = [0, -14, 14, -28]

@export var goal_position = Vector2.ZERO
@export var checkpoint_positions: Array[Vector2] = []
@export var time_limit = 300

var players = []
var camera: Camera2D
var finished = false
var time_up = false
var kill_y = INF
var slip = 1.0
var grav = 1.0   # gravity multiplier for the heroes (low on the moon)
var scroll = 0.0  # auto-scroll speed in px/s (0 = the camera follows the heroes)
var scroll_x = 0.0
var scroll_wait = 2.5
var spawn_point = Vector2.ZERO
var limits = null  # Rect2 of the level, or null for "no limits"


func _ready():
	build()
	setup()


## Overridden by generated levels.
func build():
	pass


func setup():
	Game.ensure_players()
	Game.level_node = self
	var base = get_node_or_null("player")
	var limit_bottom = 10000000
	if base:
		spawn_point = base.position
		var old_cam = base.get_node_or_null("Camera2D")
		if old_cam:
			limit_bottom = old_cam.limit_bottom
			old_cam.free()

	var start = spawn_point if Game.checkpoint == null else Game.checkpoint
	scroll_x = start.x
	for slot in Game.players.size():
		var p
		if slot == 0 and base:
			p = base
		else:
			p = PlayerScene.instantiate()
			p.slot = slot
			add_child(p)
		p.position = start + Vector2(OFFSETS[slot], 0)
		p.level = self
		players.append(p)

	if goal_position != Vector2.ZERO:
		add_goal(goal_position)
	for c in checkpoint_positions:
		add_checkpoint(c)

	camera = GameCamera.new()
	camera.level = self
	if limits != null:
		camera.limit_left = int(limits.position.x)
		camera.limit_top = int(limits.position.y)
		camera.limit_right = int(limits.end.x)
		camera.limit_bottom = int(limits.end.y)
	else:
		camera.limit_bottom = limit_bottom
	add_child(camera)
	camera.make_current()

	Game.time_left = time_limit
	Game.stats_changed.emit()


func add_goal(pos):
	var g = Goal.new()
	g.position = pos
	add_child(g)


func add_checkpoint(pos):
	var c = Checkpoint.new()
	c.position = pos
	add_child(c)


func _process(delta):
	if finished or Game.busy:
		return
	Game.time_left -= delta
	if scroll > 0:
		scroll_wait -= delta
		if scroll_wait <= 0:
			scroll_x += scroll * delta
	if Game.time_left <= 0 and not time_up:
		time_up = true
		Game.banner.emit("TIME UP!")
		for p in players:
			p.die()
	for p in players:
		if not p.dead and p.global_position.y > kill_y:
			p.die()


func living():
	return players.filter(func(p): return not p.dead)


## [min x, max x] this hero may walk to without leaving friends off-screen.
func x_limits(p):
	if scroll > 0:
		return [scroll_left() - 20.0, scroll_left() + camera.view_width() - 8.0]
	var lo = -INF
	var hi = INF
	var spread = camera.max_spread()
	for q in players:
		if q != p and not q.dead:
			lo = max(lo, q.global_position.x - spread)
			hi = min(hi, q.global_position.x + spread)
	return [lo, hi]


## World x of the left edge of the screen in an auto-scrolling level.
func scroll_left():
	return camera.get_screen_center_position().x - camera.view_width() * 0.5


func player_dying(p):
	for q in players:
		if q != p and not q.dead:
			q.say("mock")


func player_died(p):
	if finished:
		return
	var others = players.filter(func(q): return not q.dead or q.respawning)
	if others.is_empty():
		Game.all_dead()
		return
	if time_up:
		return
	if Game.lives <= 0:
		Game.players[p.slot].out = true
		p.visible = false
		Game.stats_changed.emit()
		return
	Game.lives -= 1
	Game.stats_changed.emit()
	p.respawning = true
	p.visible = false
	await get_tree().create_timer(1.2, false).timeout
	var alive = living()
	var pos = spawn_point if Game.checkpoint == null else Game.checkpoint
	if not alive.is_empty():
		pos = alive[0].global_position + Vector2(0, -40)
	elif scroll > 0:
		pos = Vector2(camera.get_screen_center_position().x, 40)
	p.respawn(pos)


## Goal reached / boss beaten.
func complete():
	if finished:
		return
	finished = true
	for p in players:
		p.locked = true
		if not p.dead:
			p.say("win", 1.0)
	Game.level_complete()
