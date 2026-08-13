extends Node
class_name EnergySystem

## Energy is the life force that powers every action. It drains continuously
## (based on the character's total mass) and extra per movement/fight action,
## and is restored by food/drinks that are used from the inventory.
## Design: doc/resources/energy.md · task: tasks/task5.md.

@export var player_node : CharacterBody3D
@export var inventory_system : InventorySystem

## Strength attribute placeholder until the attributes system lands. Body mass
## is strength / 10 kg (450 → 45 kg).
@export var strength : float = 450.0

@export var max_energy : float = 500.0
var current_energy : float

## Rest mode (R toggles it): the character cannot move or fight, only rest and
## open the inventory. Drain is 3x cheaper than standing.
var resting : bool = false

signal energy_updated(current : float, max : float)
signal rest_toggled(resting : bool)
## Emitted on discrete paid actions (attack/jump/dodge/throw/pickup/drop/fall)
## so debug tools can show "how much each action cost".
signal spent_report(amount : float, label : String)

## Read by the debug HUD: the per-second drain and its mode ("stand", "walk",
## "stairs up", "climb up", "rest", ...) from the last physics frame.
var last_drain_per_sec : float = 0.0
var last_drain_mode : String = "stand"

var _digest_total : float = 0.0
var _digest_time : float = 0.0
var _digest_elapsed : float = 0.0

## Fall tracking: jumping is paid as a one-shot (600% step) so landing after a
## jump must not charge the fall cost too.
var _airborne := false
var _just_jumped := false
var _last_y : float

func _ready():
	current_energy = max_energy
	if player_node:
		_last_y = player_node.global_position.y
		player_node.jump_started.connect(_on_jump_started)
		player_node.dodge_started.connect(_on_dodge_started)
		player_node.attack_started.connect(_on_attack_started)
		player_node.throw_started.connect(_on_throw_started)
	if inventory_system:
		inventory_system.item_used.connect(_on_item_used)

# ------------------------------------------------------------------ Mass

func body_mass() -> float:
	return strength / 10.0

## One hand (used as the base mass of whatever is being swung/held).
func arm_mass() -> float:
	return body_mass() * 0.05

func equipment_mass() -> float:
	var total := 0.0
	if inventory_system:
		for slot in inventory_system.equipment:
			var item: ItemResource = inventory_system.equipment[slot]
			if item:
				total += item.weight
	return total

func inventory_mass() -> float:
	var total := 0.0
	if inventory_system:
		for item: ItemResource in inventory_system.inventory:
			if item:
				total += item.weight * maxi(item.count, 1)
	return total

func total_mass() -> float:
	return body_mass() + equipment_mass() + inventory_mass()

func hand_item() -> ItemResource:
	return inventory_system.equipment.get("RightHand") if inventory_system else null

func shield_item() -> ItemResource:
	return inventory_system.equipment.get("LeftHand") if inventory_system else null

# ------------------------------------------------------------------ Costs

## One step = 1 second of movement at the current total mass.
func step_cost() -> float:
	return total_mass() / 100.0

## One swing uses the mass in the hand: arm (5% body) + item weight.
func swing_cost() -> float:
	var w := hand_item().weight if hand_item() else 0.0
	return (arm_mass() + w) / 50.0

func block_cost() -> float:
	var w := shield_item().weight if shield_item() else 0.0
	return (arm_mass() + w) / 100.0

func standing_drain() -> float:
	return total_mass() / 1000.0

# ------------------------------------------------------------------ Thresholds

## Below ~2 swings worth of energy the character cannot attack.
func can_attack() -> bool:
	return current_energy >= 2.0 * swing_cost()

## Below ~5 seconds of shield holding the character cannot block.
func can_block() -> bool:
	return current_energy >= 5.0 * block_cost()

## Below ~5 steps worth of energy at the current mass the character cannot
## move. Losing gear lowers the mass, the step cost and therefore the threshold.
func can_move() -> bool:
	return current_energy >= 5.0 * step_cost()

# ------------------------------------------------------------------ Spending

func spend(amount : float, label : String = ""):
	if amount <= 0.0:
		return
	current_energy = maxf(current_energy - amount, 0.0)
	energy_updated.emit(current_energy, max_energy)
	if label != "":
		spent_report.emit(amount, label)
	if current_energy <= 0.0 and player_node and not player_node.is_dead:
		player_node.death()

func spend_swings(count : float, item_weight : float = 0.0, label : String = ""):
	spend(count * (arm_mass() + item_weight) / 50.0, label)

func spend_steps(count : float, label : String = ""):
	spend(count * step_cost(), label)

func restore(amount : float):
	if amount <= 0.0:
		return
	current_energy = minf(current_energy + amount, max_energy)
	energy_updated.emit(current_energy, max_energy)

func toggle_rest() -> bool:
	if player_node and player_node.is_dead:
		return false
	resting = not resting
	rest_toggled.emit(resting)
	return resting

# ------------------------------------------------------------------ One-shots

func _on_jump_started():
	_just_jumped = true
	spend_steps(6.0, "jump") # 600% of a step

func _on_dodge_started():
	spend_steps(4.0, "dodge") # 400% of a step

func _on_attack_started():
	spend(swing_cost(), "attack")

func _on_throw_started():
	var w := hand_item().weight if hand_item() else 0.0
	spend(5.0 * (arm_mass() + w) / 50.0, "throw") # like 5 swings

# ------------------------------------------------------------------ Drain loop

func _physics_process(delta):
	if player_node == null or player_node.is_dead:
		return
	var p := player_node
	var m := total_mass()
	var per_sec := 0.0

	if resting:
		per_sec = m / 3000.0
		last_drain_mode = "rest"
	elif p.current_state == p.state.CLIMB:
		last_drain_mode = "on ladder"
		per_sec = step_cost() * (3.0 if p.input_dir.y < -0.1 else (2.0 if p.input_dir.y > 0.1 else 1.0 / 10.0))
		if p.input_dir.y < -0.1:
			last_drain_mode = "climb up"
		elif p.input_dir.y > 0.1:
			last_drain_mode = "climb down"
		if p.sprinting:
			per_sec *= 2.0
			last_drain_mode += " (sprint)"
	elif p.is_on_floor() and p.input_dir.length_squared() > 0.0 and p.current_state == p.state.FREE:
		var dy := p.global_position.y - _last_y
		last_drain_mode = "walk"
		var tm := 1.0
		if dy > 0.01:
			tm = 1.5
			last_drain_mode = "stairs up"
		elif dy < -0.01:
			tm = 1.15
			last_drain_mode = "stairs down"
		per_sec = step_cost() * tm
		if p.sprinting:
			per_sec *= 2.0
			last_drain_mode += " (sprint)"
	else:
		per_sec = standing_drain()
		last_drain_mode = "stand"

	if p.guarding:
		per_sec += block_cost()
		last_drain_mode += " + guard"

	last_drain_per_sec = per_sec
	spend(per_sec * delta)
	_update_fall()
	_update_digest(delta)
	_last_y = p.global_position.y

func _update_fall():
	var p := player_node
	if p.current_state == p.state.CLIMB:
		_airborne = false
		_just_jumped = false
		return
	if p.is_on_floor():
		_airborne = false
		return
	if not _airborne:
		_airborne = true
		if not _just_jumped:
			spend_steps(2.0, "fall") # jump down / fall off 200% of a step
	_just_jumped = false

# ------------------------------------------------------------------ Recovery

## Food/water is consumed from the inventory; its energy flows back slowly over
## digest_time seconds.
func _on_item_used(item):
	if item and item.energy > 0.0:
		_digest_total = item.energy
		_digest_time = maxf(item.digest_time, 0.01)
		_digest_elapsed = 0.0

func _update_digest(delta):
	if _digest_time <= 0.0:
		return
	_digest_elapsed += delta
	if _digest_elapsed >= _digest_time:
		restore(_digest_total)
		_digest_time = 0.0
	else:
		restore(_digest_total * delta / _digest_time)
