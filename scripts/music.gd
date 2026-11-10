extends AudioStreamPlayer
## Background music autoload: keeps looping through every scene and pause.

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	finished.connect(play)
