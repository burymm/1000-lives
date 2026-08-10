@tool
extends EditorInspectorPlugin

const CHEST_SCRIPT = preload("res://interactable objects/chest/chest_object.gd")
const GridEditor = preload("chest_grid_editor.gd")

func _can_handle(object) -> bool:
	return object != null and object.get_script() == CHEST_SCRIPT

func _parse_begin(object) -> void:
	var editor := GridEditor.new()
	editor.chest = object
	add_custom_control(editor)
