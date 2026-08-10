extends StaticBody3D

## All interactables function similarly. They have a function called "activate"
## that takes in the player node as an argument. Typically the interactable
## forces the player to a STATIC state, moves the player into a ready postiion,
## triggers the interact on the player while making any changes needed here.

@onready var opened = false
@onready var chest_anim_player :AnimationPlayer = $ChestAnimPlayer
@export var locked : bool = false
@export var player_offset : Vector3 = Vector3(0,0,1)
## Items the chest is filled with, editable per chest instance in the level
## editor. Empty list = empty chest. Content survives the session (closing and
## reopening the chest keeps whatever the player stored inside).
@export var starter_items : Array[ItemResource] = []
@onready var interact_type = "CHEST"
@export var anim_delay : float = .2
var anim
## Grid storage for the chest contents (5x5).
var storage : ChestInventory
var player_node : CharacterBody3D
signal interactable_activated

func _ready():
	add_to_group("interactable")
	collision_layer = 9
	storage = ChestInventory.new()
	storage.name = "ChestStorage"
	add_child(storage)
	for entry in starter_items:
		storage.add_item(entry)


func activate(player: CharacterBody3D):
	player_node = player
	if locked:
		shake_chest()
		
	else:
		interactable_activated.emit()
		
		var new_translation = global_transform.translated_local(player_offset).rotated_local(Vector3.UP,PI)

		var tween = create_tween()
		tween.tween_property(player,"global_transform", new_translation,.2)
		await tween.finished
		
		if opened == false:
			player.trigger_interact(interact_type)
			await get_tree().create_timer(anim_delay).timeout
			open_chest()
		else:
			open_storage_ui()

func shake_chest():
	chest_anim_player.play("Locked")
	
func open_chest():
	anim = "open"
	chest_anim_player.play(anim)
	opened = true
	open_storage_ui()

## Shows the chest storage panel next to the inventory. Reached both on the
## first open (after the lid animation) and on every later interaction.
func open_storage_ui():
	if is_instance_valid(player_node) and player_node.has_method("open_chest_ui"):
		player_node.open_chest_ui(self)
