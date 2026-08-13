@tool
extends Node3D

## Which rock shape from the rocks.glb pack is shown. Normally derived from the
## weight of the parent pickup's item_resource (small weight -> small rock).
@export_range(1, 5) var rock_variant := 1:
	set(value):
		rock_variant = clampi(value, 1, 5)
		if is_inside_tree():
			_setup()

# Quick lookup map to find the correct rock index based on its physical weight
const WEIGHT_TO_INDEX := {
	0.5: 1,
	1.0: 2,
	2.5: 3,
	5.0: 4,
	10.0: 5
}

## The collision box is fitted to the visible rock, slightly smaller than the
## mesh so the rock visually "overhangs" its physics bounds instead of the other
## way around.
const COLLISION_FIT := 0.9

func _ready():
	_setup()

func _setup():
	var weight := 1.0
	var parent := get_parent()

	# Fetch weight from the parent if available (respects per-pickup overrides)
	if parent and "item_resource" in parent and parent.item_resource is ItemResource:
		weight = parent.effective_weight() if parent.has_method("effective_weight") else parent.item_resource.weight

	# 1. Determine the rock variant index. Fallback to inspector property if weight is missing
	var variant: int = WEIGHT_TO_INDEX.get(weight, rock_variant)

	# 2. Toggle visibility of the targeted mesh node inside the pack hierarchy
	var rocks_node := get_node_or_null("RootNode")
	var target: MeshInstance3D = null
	if rocks_node:
		for child in rocks_node.get_children():
			var is_target := child.name == "Rock_%d" % variant
			child.visible = is_target
			if is_target and child is MeshInstance3D:
				target = child
	if target == null or target.mesh == null:
		return

	# 3. In the editor show the rock at its native (baked) size so it is clearly
	# visible in the 3D viewport. In the game scale it so its longest axis is ~1m
	# at weight 10 and grows with the cube root of the weight.
	var editor := Engine.is_editor_hint()
	var s := 1.0
	if not editor:
		var rendered_longest: float = target.mesh.get_aabb().get_longest_axis_size() * target.scale.x
		s = pow(weight / 10.0, 1.0 / 3.0) / maxf(rendered_longest, 0.001)
	scale = Vector3(s, s, s)
	position = Vector3.ZERO

	# 4. Fit the yellow bounding box (CollisionShape3D) to the actual visible rock
	var cs := get_node_or_null("../CollisionShape3D") as CollisionShape3D
	if cs:
		var box := BoxShape3D.new()
		var size := target.mesh.get_aabb().size * target.scale.x * s * COLLISION_FIT
		box.size = Vector3(maxf(size.x, 0.01), maxf(size.y, 0.01), maxf(size.z, 0.01))
		cs.shape = box

	if parent is RigidBody3D:
		parent.mass = weight
