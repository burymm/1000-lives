extends Node
class_name GridInventory
## Shared grid container logic for the player inventory (10x5) and chests (5x5):
## cell-fit checks and greedy top-left placement. Subclasses configure
## inv_columns / inv_rows (chests via _init) and may add their own signals and
## helpers.

signal inventory_updated(Array)

@export var inv_columns : int = 10
@export var inv_rows : int = 5

var inventory : Array = []

## Adds a clone of `_new_item` to the first free spot. Returns false (without
## touching the inventory) if it does not fit on the grid.
func add_item(_new_item: ItemResource) -> bool:
	if _new_item == null:
		return false
	var stack = _new_item.clone_item()
	stack.count = 1
	if not can_fit(stack):
		return false
	if not _find_spot(stack):
		return false
	inventory.append(stack)
	inventory_updated.emit(inventory)
	return true

## True when `_item` fits entirely at cell (_x, _y) without overlapping anything
## already in the grid.
func can_place_at(_item, _x: int, _y: int) -> bool:
	if _item == null:
		return false
	if _x < 0 or _y < 0 or _x + _item.inv_width > inv_columns or _y + _item.inv_height > inv_rows:
		return false
	for entry in inventory:
		if _rects_overlap(entry, _x, _y, _item.inv_width, _item.inv_height):
			return false
	return true

func _rects_overlap(_entry, _x: int, _y: int, _w: int, _h: int) -> bool:
	return _entry.grid_x < _x + _w and _x < _entry.grid_x + _entry.inv_width \
		and _entry.grid_y < _y + _h and _y < _entry.grid_y + _entry.inv_height

## Adds a clone of `_new_item` at the exact cell (_x, _y). Returns false if that
## cell is outside the grid or occupied.
func add_item_at(_new_item: ItemResource, _x: int, _y: int) -> bool:
	if _new_item == null:
		return false
	if not can_place_at(_new_item, _x, _y):
		return false
	var stack = _new_item.clone_item()
	stack.count = 1
	stack.grid_x = _x
	stack.grid_y = _y
	inventory.append(stack)
	inventory_updated.emit(inventory)
	return true

func _cells_used() -> int:
	var used := 0
	for entry in inventory:
		used += entry.inv_width * entry.inv_height
	return used

func can_fit(_item) -> bool:
	if _item == null:
		return false
	return _cells_used() + _item.inv_width * _item.inv_height <= inv_columns * inv_rows

## Finds the first free rectangle for `_item`. Returns false when the free cells
## are too fragmented to fit its shape, even if the total cell count fits.
func _find_spot(_item) -> bool:
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
				return true
	return false

func remove_item(_index) -> ItemResource:
	if _index < 0 or _index >= inventory.size():
		return null
	var former_item = inventory[_index]
	inventory.remove_at(_index)
	inventory_updated.emit(inventory)
	return former_item
