extends Area3D

## Gap between the player and the wall face when standing on the ladder.
const CLIMB_DIST := 0.5
## How far to probe for the wall the ladder leans against.
const PROBE_DIST := 2.0

## Climbable height of this ladder. The collider box and the visual panel are
## resized to match on _ready(), so just change this number per instance.
@export_range(1.0, 30.0, 0.1) var ladder_height := 5.0

func _ready():
	add_to_group("interactable")
	collision_layer = 9
	collision_mask = 2
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_apply_height()

## Resizes the ladder's collider box and visual panel to ladder_height. The
## shapes are shared sub-resources, so duplicate them to keep this instance
## independent from the others.
func _apply_height():
	var col := get_node_or_null("LadderCol") as CollisionShape3D
	if col:
		var box := col.shape as BoxShape3D
		if box:
			var new_box: BoxShape3D = box.duplicate()
			new_box.size.y = ladder_height
			col.shape = new_box
	var visual := get_node_or_null("LadderCol/Visual") as MeshInstance3D
	if visual:
		var mesh := visual.mesh as QuadMesh
		if mesh:
			var orig_size := mesh.size.y
			var new_mesh: QuadMesh = mesh.duplicate()
			new_mesh.size.y = ladder_height - 0.1
			visual.mesh = new_mesh
			# Re-tile the texture instead of stretching it: keep every tile the
			# same size and just repeat it more/fewer times. Duplicate the
			# material too, so other ladders are unaffected.
			var mat := visual.get_surface_override_material(0) as StandardMaterial3D
			if mat and orig_size > 0.0:
				var new_mat: StandardMaterial3D = mat.duplicate()
				var scale: Vector3 = new_mat.uv1_scale
				scale.y = new_mesh.size.y * mat.uv1_scale.y / orig_size
				new_mat.uv1_scale = scale
				visual.set_surface_override_material(0, new_mat)
func activate(player: CharacterBody3D):
	player.current_state = player.state.STATIC
	var at_bottom := player.global_position.distance_to(global_position) < 2
	var target := global_transform
	var wall := _find_lean_wall(player)
	if not wall.is_empty():
		# Stand the player in front of the wall it found. The character faces
		# the wall along -Z while climbing, so point -Z at it (player +Z away).
		var origin: Vector3 = wall.hit_position - wall.direction * CLIMB_DIST
		origin.y = player.global_position.y + .5 if at_bottom else player.global_position.y - 1.2
		target.origin = origin
		var look_target := Vector3(wall.hit_position.x, origin.y, wall.hit_position.z)
		target.basis = Basis.looking_at(origin - look_target, Vector3.UP)
	else:
		# No wall nearby: stand in front of the ladder's own face (local +Z),
		# facing it, so the climb looks right regardless of approach direction.
		var front := global_transform.basis.z
		front.y = 0
		var stand_origin: Vector3 = global_position + front.normalized() * .6
		stand_origin.y = player.global_position.y + .5 if at_bottom else player.global_position.y - 1.2
		target.origin = stand_origin
		var look_point := Vector3(global_position.x, stand_origin.y, global_position.z)
		target.basis = Basis.looking_at(stand_origin - look_point, Vector3.UP)
	var tween = create_tween()
	tween.tween_property(player,"global_transform",target,.3)
	await tween.finished
	
	# Tell the player where the climb magnet pins it and where the ladder top
	# is, so set_root_climb() can release exactly there. The climb ends at the
	# top of the ladder's collider box: instances can raise LadderCol and the
	# box height is editable, so derive it from the shape instead of hardcoding.
	var climb_top := global_position.y + 5.0
	var col := get_node_or_null("LadderCol") as CollisionShape3D
	if col:
		var box := col.shape as BoxShape3D
		if box:
			climb_top = global_position.y + col.position.y + box.size.y / 2.0
	player.climb_anchor = Vector2(target.origin.x, target.origin.z)
	player.climb_top_y = climb_top
	#player.start_climb()
	player.climb_started.emit()

## Casts horizontal rays around the ladder and returns the nearest wall hit
## (position + direction toward it). Empty dict means no wall found nearby.
func _find_lean_wall(player: CharacterBody3D) -> Dictionary:
	var space := get_world_3d().direct_space_state
	var origin := global_position + Vector3.UP
	var best := {}
	var best_dist := INF
	for dir in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * PROBE_DIST, 1)
		query.exclude = [player, self]
		var result := space.intersect_ray(query)
		if result.is_empty():
			continue
		var d := origin.distance_to(result.position)
		if d < best_dist:
			best_dist = d
			best = {"direction": dir, "hit_position": result.position, "distance": d}
	return best

func _on_body_entered(body):
	if body.is_in_group("player"):
		body.ladder = self

func _on_body_exited(body):
	if body.is_in_group("player"):
		body.ladder = null
