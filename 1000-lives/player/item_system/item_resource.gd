@tool
extends Resource
class_name ItemResource

@export var item_name : String = "Consumable Item"
@export_enum("DRINK","THROWN","OTHER","WEAPON") var object_type : String= "DRINK"
@export var weight : float = 1.0
@export var value : int = 1
var count = 1

## How many inventory cells (out of the 10x5 grid) this item occupies.
@export var inv_width : int = 1
@export var inv_height : int = 1
## Grid placement assigned by the inventory when the item is picked up.
var grid_x : int = 0
var grid_y : int = 0

@export var max_durability : int = 10
var durability : int

@export var damage_type : String = ""
@export var min_damage : int = 1
@export var max_damage : int = 3

@export var physical_instance : PackedScene
## Optional separate scene for the "worn" model. Used for the inventory icon
## snapshot and as the fallback model mounted in a hand when the item is not
## shown by a named hand template. Lets items whose worn model differs from
## their world pickup (sword, shield) look the same in the menu as on the
## character.
@export var icon_instance : PackedScene
@export var texture : Texture2D

func _init():
	durability = max_durability

## Creates an independent copy of this item. Godot's Resource.duplicate() is
## not reliable for scripted resources (especially when _init() assigns
## properties), so every gameplay field is re-asserted from the source.
## Grid sizes (inv_width / inv_height) must survive so multi-cell items render
## and occupy the correct number of cells.
func clone_item() -> ItemResource:
	var copy : ItemResource = duplicate()
	copy.item_name = item_name
	copy.object_type = object_type
	copy.weight = weight
	copy.value = value
	copy.count = count
	copy.inv_width = inv_width
	copy.inv_height = inv_height
	copy.max_durability = max_durability
	copy.durability = durability
	copy.damage_type = damage_type
	copy.min_damage = min_damage
	copy.max_damage = max_damage
	copy.physical_instance = physical_instance
	copy.icon_instance = icon_instance
	copy.texture = texture
	return copy
