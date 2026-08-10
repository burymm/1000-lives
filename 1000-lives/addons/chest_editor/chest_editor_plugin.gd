@tool
extends EditorPlugin

var _inspector_plugin: EditorInspectorPlugin

func _enter_tree():
	_inspector_plugin = preload("chest_inspector.gd").new()
	add_inspector_plugin(_inspector_plugin)

func _exit_tree():
	if _inspector_plugin:
		remove_inspector_plugin(_inspector_plugin)
		_inspector_plugin = null
