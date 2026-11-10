extends VBoxContainer
## Tiny retro menu: up/down to move, Enter/Space/(A) to choose. Mouse works too.

signal chosen(index)

var labels = []
var texts = []
var index = 0
var cooldown = 0.25


func setup(items, font_size = 24):
	for l in labels:
		l.queue_free()
	labels = []
	texts = items
	index = 0
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 14)
	for i in items.size():
		var l = Game.label(items[i], font_size)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_STOP
		l.mouse_entered.connect(_hover.bind(i))
		l.gui_input.connect(_click.bind(i))
		add_child(l)
		labels.append(l)
	_refresh()


func _hover(i):
	if index != i:
		index = i
		_refresh()


func _click(event, i):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and cooldown <= 0:
		index = i
		Game.sfx("tap")
		chosen.emit(i)


func _refresh():
	for i in labels.size():
		var selected = i == index
		labels[i].text = ("> %s <" % texts[i]) if selected else texts[i]
		labels[i].add_theme_color_override("font_color", Color(1.0, 0.9, 0.3) if selected else Color.WHITE)


func _process(delta):
	if not is_visible_in_tree() or labels.is_empty():
		cooldown = 0.25
		return
	if cooldown > 0:
		cooldown -= delta
		return
	if Game.busy:
		return
	if Input.is_action_just_pressed("m_down"):
		index = (index + 1) % labels.size()
		Game.sfx("tap")
		_refresh()
	elif Input.is_action_just_pressed("m_up"):
		index = (index - 1 + labels.size()) % labels.size()
		Game.sfx("tap")
		_refresh()
	elif Input.is_action_just_pressed("m_ok"):
		Game.sfx("tap", 1.3)
		chosen.emit(index)
