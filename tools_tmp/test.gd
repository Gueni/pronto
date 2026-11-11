extends Node

func _ready():
	var r = load("res://tools_tmp/runner.gd").new()
	get_tree().root.add_child.call_deferred(r)
