extends RigidBody3D
class_name PickupObject

## A physical item that lives in the world. Pressing interact (E) while looking
## at it adds its item_resource to the inventory and removes the pickup. When
## spawned by the ItemSystem (as a thrown object or a drink visual) it is
## activated without a player argument.

@export var item_resource : ItemResource
@export var cooldown_time : float = 1.0
var object_type : String = "DRINK"
var player_node : Node3D
var throw_me : bool = false
## True when the object was launched by the dedicated throw input. A launched
## object must not trigger its effect on the thrower the moment it activates
## while still in their hand.
var thrown : bool = false
## Damage dealt when a thrown object hits an enemy. Read by the health system
## through the `power` property of the damage source.
var power : int = 0
## Bodies in this group take damage from a thrown object.
@export var damage_group : String = "targets"
## When mounted on the player (hip/hand display) collision is disabled so the
## body never pushes the player or registers as a pickable world object.
var mounted : bool = false

func _ready():
	add_to_group("interactable")
	collision_layer = 0 if mounted else 9
	freeze = true
	body_entered.connect(_on_body_entered)

func activate(player = null):
	if player != null:
		if item_resource and player.inventory_system:
			if not player.inventory_system.can_fit(item_resource):
				return
			player.inventory_system.add_item(item_resource)
		queue_free()
		return
	if throw_me:
		_launch()
	else:
		remove_from_group("interactable")
		freeze = true
		await get_tree().create_timer(0.5).timeout
		if is_inside_tree() and not is_queued_for_deletion():
			queue_free()

func _launch():
	remove_from_group("interactable")
	mounted = false
	collision_layer = 9
	freeze = false
	top_level = true
	contact_monitor = true
	max_contacts_reported = 4
	await get_tree().create_timer(cooldown_time).timeout
	if is_inside_tree() and not is_queued_for_deletion():
		add_to_group("interactable")

## A thrown object hurts the first enemy group member it physically bumps into.
## The thrower is ignored so the item doesn't hurt the player who launched it.
func _on_body_entered(body):
	if thrown and body == player_node:
		return
	if body.is_in_group(damage_group) and body.has_method("hit") and player_node:
		body.hit(player_node, self)
