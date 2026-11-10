extends CharacterBody2D
## Power-ups: fruit (+1 heart), rock (throw rocks), life (1UP).

var kind = "fruit"
var emerge = false
var dir = 1
var active = false
var taken = false
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")


func _ready():
	z_index = 4
	collision_layer = 0
	collision_mask = 1
	var s = Sprite2D.new()
	match kind:
		"rock":
			s.texture = Game.ROCK_BIG
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
	if not active:
		return
	velocity.y += gravity * delta
	velocity.x = dir * 42.0 if kind != "rock" else 0.0
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
