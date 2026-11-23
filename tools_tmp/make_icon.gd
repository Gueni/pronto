extends Node
## Renders the game icon (a pan of chakchouka) and saves it as PNGs for the .ico.
##   godot --path . res://tools_tmp/make_icon.tscn -- <out dir>

var frames = 0
var vp: SubViewport


class Pan extends Node2D:
	func _draw():
		var c = Vector2(116, 136)
		# handle
		draw_rect(Rect2(196, 122, 58, 28), Color(0.1, 0.07, 0.09))
		draw_rect(Rect2(200, 126, 50, 20), Color(0.24, 0.17, 0.19))
		# pan, sauce, eggs
		draw_circle(c, 110, Color(0.1, 0.07, 0.09))
		draw_circle(c, 100, Color(0.26, 0.2, 0.22))
		draw_circle(c, 89, Color(0.86, 0.22, 0.12))
		draw_circle(c + Vector2(-30, -34), 32, Color(0.94, 0.33, 0.16))
		for e in [Vector2(-34, -14), Vector2(34, 28), Vector2(20, -42)]:
			draw_circle(c + e, 32, Color(1, 1, 1))
			draw_circle(c + e + Vector2(2, 3), 14, Color(1.0, 0.72, 0.1))
			draw_circle(c + e + Vector2(-3, -2), 5, Color(1.0, 0.92, 0.6))
		# parsley and a chili
		for g in [Vector2(-62, 42), Vector2(-12, 64), Vector2(62, -18), Vector2(-56, -56)]:
			draw_circle(c + g, 7, Color(0.25, 0.7, 0.3))
		draw_colored_polygon(PackedVector2Array([c + Vector2(-8, 20), c + Vector2(6, 15), c + Vector2(-26, 64), c + Vector2(-31, 58)]), Color(0.65, 0.04, 0.04))


func _ready():
	vp = SubViewport.new()
	vp.size = Vector2i(256, 256)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.add_child(Pan.new())
	add_child(vp)


func _process(_delta):
	frames += 1
	if frames == 6:
		var out = OS.get_cmdline_user_args()[0]
		var img = vp.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		for s in [256, 128, 64, 48, 32, 16]:
			var copy = img.duplicate()
			copy.resize(s, s, Image.INTERPOLATE_LANCZOS)
			copy.save_png(out.path_join("icon_%d.png" % s))
		get_tree().quit()
