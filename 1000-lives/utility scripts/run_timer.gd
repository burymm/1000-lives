extends Node
## Survival run timer (autoload).
## Counts time since the current run started and records the best (longest) run.
## The best time is persisted in user:// so it survives scene reloads and game restarts.
## Per design: no on-screen timer during a run (UI is hidden), only the death card shows times.

const SAVE_PATH := "user://run_timer.cfg"
const CONFIG_SECTION := "run"
const CONFIG_KEY := "best_time"

var elapsed := 0.0
var running := false
var best_time := 0.0

func _ready():
	load_best_time()

func _process(delta):
	if running:
		elapsed += delta

## Resets and starts counting a new run.
func start_run():
	elapsed = 0.0
	running = true

## Stops the timer and stores a new best time if this run beat the record.
func on_player_death():
	running = false
	if elapsed > best_time:
		best_time = elapsed
		save_best_time()

func load_best_time():
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		best_time = config.get_value(CONFIG_SECTION, CONFIG_KEY, 0.0)

func save_best_time():
	var config := ConfigFile.new()
	config.set_value(CONFIG_SECTION, CONFIG_KEY, best_time)
	config.save(SAVE_PATH)

## Adaptive format: MM:SS, HH:MM:SS or DD:HH:MM:SS as the run grows longer.
static func format_time(seconds : float) -> String:
	var total := int(seconds)
	var days := total / 86400
	var hours := total % 86400 / 3600
	var minutes := total % 3600 / 60
	var secs := total % 60
	if days > 0:
		return "%02d:%02d:%02d:%02d" % [days, hours, minutes, secs]
	if hours > 0:
		return "%02d:%02d:%02d" % [hours, minutes, secs]
	return "%02d:%02d" % [minutes, secs]
