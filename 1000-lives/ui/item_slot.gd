extends Control

## A very crude inventory system UI. It waits for a signal from whatever node 
## you choose, that signal should pass the currently held inventory. This node
## looks at the first item in that inventory array, hecks the item count, and 
## texture and updates it on screen.

@export var signaling_node : Node
@export var update_signal : String = "inventory_updated"

@onready var item_texture = $ItemTexture
@onready var item_count = $ItemCount

var _last_inventory : Array = []

# Called when the node enters the scene tree for the first time.
func _ready():
	if signaling_node:
		signaling_node.connect(update_signal,_on_update_signal)
	ItemIcons.icon_ready.connect(_on_icon_ready)

func _on_update_signal(inventory):
	_last_inventory = inventory
	if inventory.is_empty():
		item_count.text = str(0)
		item_texture.texture = null
		return
	var current_item = inventory[0]
	if current_item:
		item_count.text = str(current_item.count)
		item_texture.texture = ItemIcons.get_icon(current_item)
	else:
		item_count.text = str(0)
		item_texture.texture = null

## Icons are generated asynchronously at startup, so refresh the slot whenever a
## new one finishes rendering.
func _on_icon_ready():
	if not _last_inventory.is_empty():
		_on_update_signal(_last_inventory)
