extends StaticBody2D
## Blocks you hit from below. kind: coin, multi, fruit, rock, life, crate.

const TILESET = preload("res://assets/sprites/world_tileset.png")
const COIN = preload("res://assets/sprites/coin.png")
const Pickup = preload("res://scripts/pickup.gd")

var kind = "coin"
var atlas_coords = Vector2i(0, 2)
var used = false
var uses = 1
var sprite: Sprite2D


func _ready():
	if kind == "crate":
		atlas_coords = Vector2i(7, 3)
	elif kind == "multi":
		uses = 6
	sprite = Sprite2D.new()
	sprite.texture = TILESET
	sprite.region_enabled = true
	sprite.region_rect = Rect2(atlas_coords.x * 16, atlas_coords.y * 16, 16, 16)
	add_child(sprite)
	var c = CollisionShape2D.new()
	var r = RectangleShape2D.new()
	r.size = Vector2(16, 16)
	c.shape = r
	add_child(c)


func bump(player):
	_knock_enemies()
	if kind == "crate":
		_break()
		return
	if used:
		return
	var tw = create_tween()
	tw.tween_property(sprite, "position:y", -5.0, 0.07)
	tw.tween_property(sprite, "position:y", 0.0, 0.09)
	match kind:
		"coin", "multi":
			Game.add_coin(global_position, true)
			if player:
				player.add_mana(3)
			_coin_fx()
		_:
			var p = Pickup.new()
			p.kind = kind
			p.emerge = true
			p.position = position
			if player:
				p.dir = 1 if player.global_position.x <= global_position.x else -1
			get_parent().add_child(p)
			Game.sfx("power_up", 1.2, -4.0)
	uses -= 1
	if uses <= 0:
		used = true
		sprite.modulate = Color(0.5, 0.45, 0.45)


func _knock_enemies():
	for e in get_tree().get_nodes_in_group("enemies"):
		var feet = e.global_position.y + 16 * e.scale.y
		if abs(e.global_position.x - global_position.x) < 14 and abs(feet - (global_position.y - 8)) < 7:
			e.hit_by_rock()


func _coin_fx():
	var s = Sprite2D.new()
	s.texture = COIN
	s.region_enabled = true
	s.region_rect = Rect2(0, 0, 16, 16)
	s.position = position + Vector2(0, -12)
	s.z_index = 4
	get_parent().add_child(s)
	var tw = s.create_tween()
	tw.tween_property(s, "position:y", s.position.y - 22, 0.2).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "position:y", s.position.y - 10, 0.15)
	tw.tween_callback(s.queue_free)


func _break():
	Game.sfx("explosion", 1.5, -10.0)
	Game.add_score(50)
	for i in 4:
		var s = Sprite2D.new()
		s.texture = TILESET
		s.region_enabled = true
		s.region_rect = Rect2(atlas_coords.x * 16 + (i % 2) * 8, atlas_coords.y * 16 + (i / 2) * 8, 8, 8)
		s.position = position + Vector2((i % 2) * 8 - 4, (i / 2) * 8 - 4)
		s.z_index = 6
		get_parent().add_child(s)
		var target = s.position + Vector2(((i % 2) * 2 - 1) * (14 + randf() * 10), 30 - (1 - i / 2) * 20)
		var tw = s.create_tween()
		tw.tween_property(s, "position", target, 0.45)
		tw.parallel().tween_property(s, "rotation", randf_range(-4.0, 4.0), 0.45)
		tw.parallel().tween_property(s, "modulate:a", 0.0, 0.45)
		tw.tween_callback(s.queue_free)
	queue_free()
