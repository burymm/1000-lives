extends TextureRect

## Fills the death card with the run survival time and the best time on player death.
## Data comes from the RunTimer autoload, which persists the best time across runs.

@export var signaling_node : Node
@onready var run_time_label : Label = $RunTimeLabel
@onready var best_time_label : Label = $BestTimeLabel

func _ready():
	run_time_label.text = ""
	best_time_label.text = ""
	if signaling_node and signaling_node.has_signal("death_started"):
		signaling_node.connect("death_started", _on_death_started)

func _on_death_started():
	run_time_label.text = "SURVIVED  " + RunTimer.format_time(RunTimer.elapsed)
	best_time_label.text = "BEST  " + RunTimer.format_time(RunTimer.best_time)
