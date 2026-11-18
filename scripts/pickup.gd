extends CharacterBody2D
## Power-ups: fruit (+1 heart), rock (throw rocks), life (1UP), and the three drawn here:
##   fire  FIRE FLOWER: your sandals become bouncing fireballs, until you get hurt
##   ice   ICE CRYSTAL: your sandals freeze what they hit, until you get hurt
##   star  STAR: a few seconds of being untouchable; whatever you run into dies
##   jet   JETPACK: hold JUMP in the air to fly, while the fuel lasts
##   buddy FALCON: a hunting falcon follows you for a while and attacks what comes close

const POWERS = ["fire", "ice", "star", "jet", "buddy"]

var kind = "fruit"
var emerge = false
var dir = 1
var active = false
var taken = false
var t = 0.0
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")


func _ready():
	z_index = 4
	collision_layer = 0
	collision_mask = 1
	var s = Sprite2D.new()
	match kind:
		"rock":
			s.texture = Game.ROCK_BIG
		"fire", "ice", "star", "jet", "buddy":
			pass   # see _draw
		"life":
			s.texture = Game.atlas(Game.FRUITS, Rect2(0, 0, 16, 16))
		_:
			s.texture = Game.atlas(Game.FRUITS, Rect2(0, 48, 16, 16))
	add_child(s)
	var c = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 6.0
	c.shape = circle
	c.position = Vector2(0, 2)
	add_child(c)
	var area = Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 2
	var ac = CollisionShape2D.new()
	var acircle = CircleShape2D.new()
	acircle.radius = 8.0
	ac.shape = acircle
	area.add_child(ac)
	add_child(area)
	area.body_entered.connect(_collect)
	if emerge:
		var tw = create_tween()
		tw.tween_property(self, "position:y", position.y - 16, 0.4)
		tw.tween_callback(func(): active = true)
	else:
		active = true


func _physics_process(delta):
	t += delta
	if kind in POWERS:
		queue_redraw()
	if not active:
		return
	velocity.y += gravity * delta
	velocity.x = 0.0 if kind in ["rock", "fire", "ice", "jet", "buddy"] else dir * (70.0 if kind == "star" else 42.0)
	if kind == "star" and is_on_floor():
		velocity.y = -230.0
	move_and_slide()
	if is_on_wall():
		dir = -dir
	if position.y > 2000:
		queue_free()


func _collect(body):
	if taken or not body.has_method("heal") or body.dead:
		return
	taken = true
	match kind:
		"rock":
			body.give_rocks()
			Game.popup("ROCKS!", global_position, Color(0.8, 0.85, 1.0))
		"fire", "ice":
			body.give_power(kind)
			Game.popup("FIRE SANDALS!" if kind == "fire" else "ICE SANDALS!", global_position, Color(1.0, 0.6, 0.2) if kind == "fire" else Color(0.55, 0.9, 1.0))
		"jet":
			body.jet = 7.0
			Game.popup("JETPACK! HOLD JUMP", global_position, Color(1.0, 0.7, 0.3))
		"buddy":
			body.buddy = 28.0
			Game.popup("A FALCON JOINS YOU!", global_position, Color(0.95, 0.85, 0.6))
		"star":
			body.star = 9.0
			Game.popup("UNTOUCHABLE!", global_position, Color(1.0, 0.95, 0.4))
			Game.flash(Color(1.0, 0.95, 0.5), 0.25)
		"life":
			Game.lives += 1
			Game.popup("1UP!", global_position, Color(0.5, 1.0, 0.5))
		_:
			if body.heal():
				Game.popup("+1 HEART", global_position, Color(1.0, 0.5, 0.5))
			else:
				Game.popup("1000", global_position)
				Game.score += 500
	Game.score += 500
	Game.stats_changed.emit()
	Game.sfx("power_up")
	body.say("power", 0.9)
	queue_free()


func _draw():
	var dark = Color(0.13, 0.09, 0.16)
	if kind == "fire":
		# a flower with a flame for petals
		draw_line(Vector2(0, 8), Vector2(0, 1), Color(0.25, 0.7, 0.3), 2.0)
		draw_colored_polygon(PackedVector2Array([Vector2(0, 5), Vector2(5, 2), Vector2(1, 6)]), Color(0.3, 0.8, 0.35))
		for i in 6:
			var a = TAU * i / 6.0 + t * 1.5
			draw_circle(Vector2(cos(a), sin(a)) * 4.0 + Vector2(0, -2), 2.6, Color(1.0, 0.45, 0.1))
		draw_circle(Vector2(0, -2), 3.2, Color(1.0, 0.85, 0.25))
		draw_circle(Vector2(0, -2), 1.5 + sin(t * 10.0) * 0.4, Color(1, 1, 0.9))
	elif kind == "ice":
		var bob = sin(t * 4.0)
		var pts = PackedVector2Array([Vector2(0, -8 + bob), Vector2(5, -1 + bob), Vector2(0, 7 + bob), Vector2(-5, -1 + bob)])
		draw_colored_polygon(pts, Color(0.55, 0.9, 1.0))
		draw_colored_polygon(PackedVector2Array([pts[0], pts[1], Vector2(0, -1 + bob)]), Color(0.85, 0.98, 1.0))
		pts.append(pts[0])
		draw_polyline(pts, dark, 0.9, true)
	elif kind == "jet":
		# two tanks, a strap, a flame under each
		for x in [-4.0, 1.0]:
			draw_rect(Rect2(x, -7, 4, 11), Color(0.75, 0.78, 0.86))
			draw_rect(Rect2(x, -7, 4, 3), Color(0.9, 0.25, 0.25))
			draw_rect(Rect2(x, -7, 4, 11), dark, false, 0.8)
			var f = 3.0 + sin(t * 20.0 + x) * 1.5
			draw_colored_polygon(PackedVector2Array([Vector2(x + 0.5, 4), Vector2(x + 3.5, 4), Vector2(x + 2, 4 + f)]), Color(1.0, 0.6, 0.15))
	elif kind == "buddy":
		var flap = sin(t * 12.0) * 4.0
		draw_colored_polygon(PackedVector2Array([Vector2(-1, -1), Vector2(-8, -5 + flap), Vector2(-3, 2)]), Color(0.45, 0.3, 0.18))
		draw_colored_polygon(PackedVector2Array([Vector2(1, -1), Vector2(8, -5 + flap), Vector2(3, 2)]), Color(0.45, 0.3, 0.18))
		draw_circle(Vector2(0, 1), 3.6, Color(0.62, 0.44, 0.26))
		draw_circle(Vector2(0, -3), 2.6, Color(0.95, 0.9, 0.8))
		draw_colored_polygon(PackedVector2Array([Vector2(-1, -2.5), Vector2(1, -2.5), Vector2(0, 0)]), Color(1.0, 0.75, 0.2))
		draw_circle(Vector2(-1.1, -3.6), 0.5, dark)
		draw_circle(Vector2(1.1, -3.6), 0.5, dark)
	elif kind == "star":
		var pts = PackedVector2Array()
		for i in 10:
			var a = -PI / 2 + TAU * i / 10.0 + sin(t * 6.0) * 0.2
			pts.append(Vector2(cos(a), sin(a)) * (8.0 if i % 2 == 0 else 3.6))
		draw_colored_polygon(pts, Color.from_hsv(fmod(t * 0.8, 1.0), 0.35, 1.0))
		pts.append(pts[0])
		draw_polyline(pts, dark, 0.9, true)
		draw_rect(Rect2(-2.5, -2, 1.2, 3), dark)
		draw_rect(Rect2(1.3, -2, 1.2, 3), dark)
