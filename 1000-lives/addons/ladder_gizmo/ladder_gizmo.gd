@tool
extends EditorNode3DGizmoPlugin

const LadderScript := preload("res://interactable objects/ladder/ladder.gd")
const MIN_HEIGHT := 1.0
const MAX_HEIGHT := 200.0

## Set by the EditorPlugin that owns this gizmo so handle commits can undo.
var editor_plugin: EditorPlugin

var _drag_start_height := -1.0

func _get_gizmo_name() -> String:
	return "Ladder Height"

func _has_gizmo(node: Node3D) -> bool:
	return node.get_script() == LadderScript

func _init():
	var line_mat := StandardMaterial3D.new()
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_mat.vertex_color_use_as_albedo = true
	line_mat.no_depth_test = true
	add_material("ladder_lines", line_mat)
	var handle_mat := StandardMaterial3D.new()
	handle_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	handle_mat.vertex_color_use_as_albedo = true
	handle_mat.no_depth_test = true
	add_material("ladder_handles", handle_mat)

func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()
	var ladder = gizmo.get_node_3d()
	if not ladder:
		return
	var h: float = ladder.ladder_height
	gizmo.add_handles(PackedVector3Array([Vector3(0.0, h, 0.0)]), get_material("ladder_handles"), PackedInt32Array())
	var hw := 0.35
	var pts := PackedVector3Array()
	pts.push_back(Vector3(-hw, 0.0, 0.0))
	pts.push_back(Vector3(-hw, h - 0.1, 0.0))
	pts.push_back(Vector3(hw, h - 0.1, 0.0))
	pts.push_back(Vector3(hw, 0.0, 0.0))
	pts.push_back(Vector3(-hw, 0.0, 0.0))
	gizmo.add_lines(pts, get_material("ladder_lines"))

func _get_handle_name(gizmo: EditorNode3DGizmo, handle_id: int, secondary: bool) -> String:
	return "Ladder Height"

func _get_handle_value(gizmo: EditorNode3DGizmo, handle_id: int, secondary: bool) -> Variant:
	var ladder = gizmo.get_node_3d()
	return ladder.ladder_height

func _set_handle(gizmo: EditorNode3DGizmo, handle_id: int, secondary: bool, camera: Camera3D, screen_point: Vector2) -> void:
	var ladder = gizmo.get_node_3d()
	if not ladder:
		return
	if _drag_start_height < 0.0:
		_drag_start_height = ladder.ladder_height
	var ray_origin := camera.project_ray_origin(screen_point)
	var ray_dir := camera.project_ray_normal(screen_point)
	var base_y: float = ladder.global_position.y
	var hit := Plane(Vector3.UP, base_y).intersects_ray(ray_origin, ray_dir)
	if hit:
		ladder.ladder_height = clampf(hit.y - base_y, MIN_HEIGHT, MAX_HEIGHT)

func _commit_handle(gizmo: EditorNode3DGizmo, handle_id: int, secondary: bool, point: Variant, cancel: bool) -> void:
	var ladder = gizmo.get_node_3d()
	if not ladder:
		_drag_start_height = -1.0
		return
	var old_h := _drag_start_height
	_drag_start_height = -1.0
	if old_h < 0.0:
		return
	if cancel:
		ladder.ladder_height = old_h
		return
	var new_h: float = ladder.ladder_height
	if is_equal_approx(old_h, new_h):
		return
	if editor_plugin:
		var undo := editor_plugin.get_editor_interface().get_editor_undo_redo()
		undo.create_action("Resize Ladder", UndoRedo.MERGE_ALL)
		undo.add_do_property(ladder, "ladder_height", new_h)
		undo.add_undo_property(ladder, "ladder_height", old_h)
		undo.commit_action()
