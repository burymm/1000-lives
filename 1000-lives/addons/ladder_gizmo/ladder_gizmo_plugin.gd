@tool
extends EditorPlugin

const LadderGizmo := preload("res://addons/ladder_gizmo/ladder_gizmo.gd")

var _gizmo: EditorNode3DGizmoPlugin

func _enter_tree() -> void:
	_gizmo = LadderGizmo.new()
	_gizmo.editor_plugin = self
	add_node_3d_gizmo_plugin(_gizmo)

func _exit_tree() -> void:
	if _gizmo:
		remove_node_3d_gizmo_plugin(_gizmo)
		_gizmo = null
