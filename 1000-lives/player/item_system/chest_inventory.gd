@tool
extends GridInventory
class_name ChestInventory

## Grid container for chest contents (5x5). Standalone so any chest can hold its
## own items without the player's baggage (starter items, equipment slots,
## current_item). Placement and fit logic lives in GridInventory.

func _init():
	inv_columns = 5
	inv_rows = 5
