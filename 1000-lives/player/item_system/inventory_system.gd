extends GridInventory
class_name InventorySystem

## Inventory lives for a single life. By the game's lore, death means starting
## the ascent anew, so the inventory is refilled with starter items on each spawn.

@export var signaling_node : Node3D
@export var change_item_signal : String = "item_change_started"
@export var use_item_signal  : String = "item_used"

## Character equipment slots. Any item can be dragged into any slot — the player
## experiments with what goes where.
const SLOTS : Array = ["Head", "Torso", "RightHand", "LeftHand", "Belt", "Legs"]
var equipment : Dictionary = {}

@export var starter_item : ItemResource
@export var starter_item2 : ItemResource
## Equipment the player starts a life with, worn directly in the matching slot
## instead of living in the grid.
@export var starting_weapon : ItemResource
@export var starting_shield : ItemResource
@onready var current_item

signal item_used
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

func add_item(_new_item: ItemResource) -> bool:
	var ok := super.add_item(_new_item)
	if ok:
		current_item = inventory[0]
	return ok

func remove_item(_index) -> ItemResource:
	var former_item = super.remove_item(_index)
	current_item = inventory[0] if inventory.size() > 0 else null
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
		if not _find_spot(prev):
			equipment[_slot] = prev
			inventory_error.emit("No space in inventory")
			return false
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
	if not _find_spot(item):
		equipment[_slot] = item
		inventory_error.emit("No space in inventory")
		return false
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
		if not _find_spot(other):
			equipment[_to_slot] = other
			inventory_error.emit("No space in inventory")
			return false
		inventory.append(other)
	equipment.erase(_from_slot)
	equipment[_to_slot] = item
	current_item = inventory[0] if inventory.size() > 0 else null
	inventory_updated.emit(inventory)
	equipment_changed.emit(_from_slot)
	equipment_changed.emit(_to_slot)
	return true

## Equips an item that does NOT live in the grid (e.g. taken from a chest)
## directly into a slot. The displaced occupant (if any) is returned to the
## grid; returns false without changing anything if there is no room for it.
func equip_external(_item : ItemResource, _slot : String) -> bool:
	if _slot not in SLOTS or _item == null:
		return false
	if equipment.has(_slot):
		var prev = equipment[_slot]
		if not can_fit(prev):
			inventory_error.emit("No space in inventory")
			return false
		equipment.erase(_slot)
		if not _find_spot(prev):
			equipment[_slot] = prev
			inventory_error.emit("No space in inventory")
			return false
		inventory.append(prev)
	equipment[_slot] = _item
	current_item = inventory[0] if inventory.size() > 0 else null
	inventory_updated.emit(inventory)
	equipment_changed.emit(_slot)
	return true

## Removes an item from an equipment slot and returns it, WITHOUT placing it in
## the grid (used when moving it into another container such as a chest).
func take_equipped(_slot : String) -> ItemResource:
	if _slot not in SLOTS or not equipment.has(_slot):
		return null
	var item = equipment[_slot]
	equipment.erase(_slot)
	current_item = inventory[0] if inventory.size() > 0 else null
	inventory_updated.emit(inventory)
	equipment_changed.emit(_slot)
	return item
