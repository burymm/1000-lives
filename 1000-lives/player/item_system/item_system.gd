extends Node3D
class_name ItemSystem

## This class is tied very closely to the Inventory system. It's purpose is to 
## place the current inventory item on the player's hip whenever items are changed
## it also manages throwing objects when the item used is a throwable.

@export var player_node : CharacterBody3D
@onready var hand_bone = $HandBone
@onready var mount_point = $HandBone/HandPivot

@onready var storage_bone = $StorageBone
@onready var storage_mount = $StorageBone/HipPivot

@export var signaling_node : Node
@export var use_item_signal : String = "item_used"
@export var throw_strength = 15

signal item_thrown
signal item_drunk

# Called when the node enters the scene tree for the first time.
func _ready():
	if signaling_node:
		if signaling_node.has_signal(use_item_signal):
			signaling_node.connect(use_item_signal, _on_item_used_signal)
		if signaling_node.has_signal("inventory_updated"):
			signaling_node.connect("inventory_updated", _on_inventory_updated)
		
func _on_inventory_updated(inventory):
	# This simply adds a visual version to your hip when you change/use items.
	var thekids = storage_mount.get_children()
	for kid in thekids:
		#print(kid)
		kid.queue_free()
	
	if inventory.is_empty():
		return
	var current_item = inventory[0]
	if current_item.count > 0:
			if current_item.physical_instance:
				var item_instance = current_item.physical_instance
				var new_item :RigidBody3D = item_instance.instantiate()
				if "mounted" in new_item:
					new_item.mounted = true
				# pass ItemResource data to this new physical object
				storage_mount.call_deferred("add_child",new_item)
			
			

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _on_item_used_signal(_current_item : ItemResource):
	if _current_item != null:
		if _current_item.physical_instance:
			var item_instance = _current_item.physical_instance
			var new_item :RigidBody3D = item_instance.instantiate()
			if "mounted" in new_item:
				new_item.mounted = true
			# pass ItemResource data to this new physical object
			new_item.object_type = _current_item.object_type
			new_item.player_node = player_node
			mount_point.call_deferred("add_child",new_item)
			
			await get_tree().create_timer(.8).timeout
			new_item.activate()
			if new_item.object_type == "THROWN":
				item_thrown.emit()
				var force_dir = player_node.global_transform.basis.z
				#force_dir.y += .1
				new_item.apply_impulse(force_dir * throw_strength, mount_point.global_position)
			elif new_item.object_type == "DRINK":
				item_drunk.emit()

## Throws the given item from the hand regardless of its object_type. Used by
## the dedicated throw input so an equipped item can always be hurled into the
## world and picked up again.
func throw_current_item(_current_item : ItemResource):
	if _current_item == null or _current_item.physical_instance == null:
		return
	var item_instance = _current_item.physical_instance
	var new_item :RigidBody3D = item_instance.instantiate()
	if "mounted" in new_item:
		new_item.mounted = true
	if "object_type" in new_item:
		new_item.object_type = _current_item.object_type
	if "player_node" in new_item:
		new_item.player_node = player_node
	if "item_resource" in new_item:
		new_item.item_resource = _current_item
	if "throw_me" in new_item:
		new_item.throw_me = true
	if "thrown" in new_item:
		new_item.thrown = true
	if "power" in new_item:
		new_item.power = int(_current_item.weight * 2)
	mount_point.call_deferred("add_child",new_item)

	await get_tree().create_timer(.8).timeout
	if is_instance_valid(new_item) and new_item.has_method("activate"):
		new_item.activate()
	item_thrown.emit()
	var force_dir = player_node.global_transform.basis.z
	## Heavier objects fly shorter: impulse = base_strength / weight.
	var impulse = throw_strength / maxf(_current_item.weight, 0.1)
	new_item.apply_impulse(force_dir * impulse, mount_point.global_position)
