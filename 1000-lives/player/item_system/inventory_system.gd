extends Node
class_name InventorySystem

## Inventory lives for a single life. By the game's lore, death means starting
## the ascent anew, so the inventory is refilled with starter items on each spawn.

@export var signaling_node : Node3D
@export var change_item_signal : String = "item_change_started"
@export var use_item_signal  : String = "item_used"

## Grid inventory: items occupy cells, each item takes inv_width x inv_height cells.
@export var inv_columns : int = 10
@export var inv_rows : int = 5

## Character equipment slots. Any item can be dragged into any slot — the player
## experiments with what goes where.
const SLOTS : Array = ["Head", "Torso", "RightHand", "LeftHand", "Belt", "Legs"]
var equipment : Dictionary = {}

@onready var inventory : Array = []
@export var starter_item : ItemResource
@export var starter_item2 : ItemResource
## Equipment the player starts a life with, worn directly in the matching slot
## instead of living in the grid.
@export var starting_weapon : ItemResource
@export var starting_shield : ItemResource
@onready var current_item

signal item_used
signal inventory_updated(Array)
signal equipment_changed(slot_name)
## Emitted when an equipment action is rejected (e.g. no room to return the
## displaced item to the grid). The UI surfaces this to the player.
signal inventory_error(message: String)

func _ready():
	if signaling_node:
		signaling_node.connect(change_item_signal,_on_change_item_signal)
		signaling_node.connect(use_item_signal, _on_item_used_signal)

	restock_for_new_life()

func restock_for_new_life():
	for starter in [starter_item, starter_item2]:
		if starter:
			add_item(starter)
	if not equipment.has("RightHand") and starting_weapon:
		equipment["RightHand"] = starting_weapon.clone_item()
		equipment_changed.emit("RightHand")
	if not equipment.has("LeftHand") and starting_shield:
		equipment["LeftHand"] = starting_shield.clone_item()
		equipment_changed.emit("LeftHand")

func add_item(_new_item: ItemResource):
	if _new_item == null:
		return
	var stack = _new_item.clone_item()
	stack.count = 1
	if not can_fit(stack):
		return
	_find_spot(stack)
	inventory.append(stack)
	current_item = inventory[0]
	inventory_updated.emit(inventory)

func _cells_used() -> int:
	var used := 0
	for entry in inventory:
		used += entry.inv_width * entry.inv_height
	return used

func can_fit(_item) -> bool:
	if _item == null:
		return false
	return _cells_used() + _item.inv_width * _item.inv_height <= inv_columns * inv_rows

func _find_spot(_item):
	var occupied : Dictionary = {}
	for entry in inventory:
		for yy in range(entry.inv_height):
			for xx in range(entry.inv_width):
				occupied[Vector2i(entry.grid_x + xx, entry.grid_y + yy)] = true
	for y in range(inv_rows):
		for x in range(inv_columns):
			var fits = true
			for yy in range(_item.inv_height):
				for xx in range(_item.inv_width):
					if y + yy >= inv_rows or x + xx >= inv_columns or occupied.has(Vector2i(x + xx, y + yy)):
						fits = false
						break
				if not fits:
					break
			if fits:
				_item.grid_x = x
				_item.grid_y = y
				return

func remove_item(_index) -> ItemResource:
	if _index < 0 or _index >= inventory.size():
		return null
	var former_item = inventory[_index]
	inventory.remove_at(_index)
	current_item = inventory[0] if inventory.size() > 0 else null
	inventory_updated.emit(inventory)
	return former_item

func drop_item(_index) -> bool:
	if _index < 0 or _index >= inventory.size():
		return false
	var item = inventory[_index]
	if item.physical_instance == null:
		return false
	var world_item = item.physical_instance.instantiate()
	if world_item is RigidBody3D:
		world_item.freeze = false
	var parent = get_tree().current_scene
	parent.add_child(world_item)
	var drop_transform = signaling_node.global_transform.translated(signaling_node.global_transform.basis.z * 1.5).translated(Vector3.UP)
	world_item.global_transform = drop_transform
	item.count -= 1
	if item.count <= 0:
		remove_item(_index)
	else:
		inventory_updated.emit(inventory)
	return true

func _on_item_used_signal():
	if current_item != null and current_item.count > 0:
		current_item.count -= 1
		item_used.emit(current_item)
		if current_item.count <= 0:
			remove_item(inventory.find(current_item))
			current_item = null
		else:
			inventory_updated.emit(inventory)
	else:
		item_used.emit(null)

## Returns the item equipped in the leading hand (RightHand slot), or null.
func get_hand_item() -> ItemResource:
	return equipment.get("RightHand", null)

## Removes the item from the leading hand (RightHand slot) after it is thrown.
func consume_hand_item():
	if not equipment.has("RightHand"):
		return
	equipment.erase("RightHand")
	equipment_changed.emit("RightHand")

func _on_change_item_signal():
	if inventory.size() > 0:
		change_item(0,inventory.size()-1)

func change_item(_start_index,_destination_index):
	if _start_index < 0 or _start_index >= inventory.size():
		return
	if _destination_index < 0 or _destination_index >= inventory.size():
		return
	var start_item = inventory[_start_index]
	var dest_item = inventory[_destination_index]
	inventory[_start_index] = dest_item
	inventory[_destination_index] = start_item
	current_item = inventory[0]

	inventory_updated.emit(inventory)

func restack_inventory():
	if inventory.is_empty():
		return
	inventory_updated.emit(inventory)

## Moves the item at grid _index into equipment slot _slot. If the slot was
## occupied, the previous occupant is returned to the grid (aborts if it no
## longer fits). Any item may go into any slot — the player experiments.
func equip_item(_index : int, _slot : String) -> bool:
	if _slot not in SLOTS:
		return false
	if _index < 0 or _index >= inventory.size():
		return false
	var item = inventory[_index]
	if equipment.has(_slot):
		var prev = equipment[_slot]
		if not can_fit(prev):
			inventory_error.emit("No space in inventory")
			return false
		equipment.erase(_slot)
		_find_spot(prev)
		inventory.append(prev)
	inventory.remove_at(_index)
	equipment[_slot] = item
	current_item = inventory[0] if inventory.size() > 0 else null
	inventory_updated.emit(inventory)
	equipment_changed.emit(_slot)
	return true

## Returns the item in equipment _slot back to the grid. Aborts if it no longer fits.
func unequip_item(_slot : String) -> bool:
	if _slot not in SLOTS or not equipment.has(_slot):
		return false
	var item = equipment[_slot]
	if not can_fit(item):
		inventory_error.emit("No space in inventory")
		return false
	equipment.erase(_slot)
	_find_spot(item)
	inventory.append(item)
	current_item = inventory[0] if inventory.size() > 0 else null
	inventory_updated.emit(inventory)
	equipment_changed.emit(_slot)
	return true

## Transfers an equipped item between slots. If the target slot is occupied its
## occupant is returned to the grid first.
func move_equipped(_from_slot : String, _to_slot : String) -> bool:
	if _from_slot not in SLOTS or _to_slot not in SLOTS:
		return false
	if not equipment.has(_from_slot):
		return false
	if _from_slot == _to_slot:
		return true
	var item = equipment[_from_slot]
	if equipment.has(_to_slot):
		var other = equipment[_to_slot]
		if not can_fit(other):
			inventory_error.emit("No space in inventory")
			return false
		equipment.erase(_to_slot)
		_find_spot(other)
		inventory.append(other)
	equipment.erase(_from_slot)
	equipment[_to_slot] = item
	current_item = inventory[0] if inventory.size() > 0 else null
	inventory_updated.emit(inventory)
	equipment_changed.emit(_from_slot)
	equipment_changed.emit(_to_slot)
	return true
