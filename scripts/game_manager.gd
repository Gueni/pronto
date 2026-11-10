extends Node
## Counts the coins collected in this level and shows them on the sign at the end.

var score = 0

@onready var score_label: Label = $ScoreLabel

func _ready():
	score_label.text = "Coins :  0"
	Game.coin_collected.connect(add_point)

func add_point():
	score += 1
	score_label.text = "Coins :  " + str(score)
