@tool
extends VBoxContainer
## Editor-only control shown in the inspector when a chest object is selected.
## Renders the chest's 5x5 grid from `starter_items` and lets you click cells to
## add, replace or remove item resources. Layout mirrors ChestInventory so the
## preview matches the in-game chest.

const COLS := 5
const ROWS := 5
const CELL := 42
const GAP := 4

var chest: Node
var grid_area: Control
var grid_canvas: Control
var status_label: Label
var item_buttons: Array[Button] = []
var dialog: EditorFileDialog
var dialog_attached := false
var dialog_index := -1

## Draws the 5x5 cell lines and item rectangles; transparent buttons on top
## handle clicks and drops.
class GridCanvas extends Control:
	const COLS := 5
	const ROWS := 5
	const CELL := 42
	const GAP := 4
	var items: Array = []

	func _draw() -> void:
		var step := CELL + GAP
		var line := Color(1, 1, 1, 0.35)
		for i in range(ROWS + 1):
			draw_line(Vector2(0, i * step), Vector2(size.x, i * step), line)
		for i in range(COLS + 1):
			draw_line(Vector2(i * step, 0), Vector2(i * step, size.y), line)
		for it in items:
			var rect := Rect2(it.grid_x * step, it.grid_y * step, \
				it.inv_width * CELL + (it.inv_width - 1) * GAP, \
				it.inv_height * CELL + (it.inv_height - 1) * GAP)
			draw_rect(rect, Color(0.3, 0.5, 0.9, 0.22), true)
			draw_rect(rect, Color(0.75, 0.85, 1.0, 0.9), false, 2.0)

func _ready() -> void:
	add_theme_constant_override("separation", 6)

	var title := Label.new()
	title.text = "Chest contents"
	title.add_theme_font_size_override("font_size", 14)
	add_child(title)

	var grid_size := Vector2(COLS * CELL + (COLS - 1) * GAP, ROWS * CELL + (ROWS - 1) * GAP)
	grid_area = Control.new()
	grid_area.custom_minimum_size = grid_size
	add_child(grid_area)
	grid_canvas = GridCanvas.new()
	grid_canvas.custom_minimum_size = grid_size
	grid_canvas.size = grid_size
	grid_area.add_child(grid_canvas)
	_build_cells()
	grid_area.set_drag_forwarding(Callable(), _can_drop_files.bind(-1), _drop_files.bind(-1))

	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 11)
	status_label.add_theme_color_override("font_color", Color(1, 0.7, 0.3))
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status_label)

	var hint := Label.new()
	hint.text = "Left-click cell: add / replace item. Right-click a filled cell: remove."
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(hint)

	_rebuild_items()

func _exit_tree() -> void:
	if dialog != null and dialog_attached and is_instance_valid(dialog):
		dialog.queue_free()

func _build_cells() -> void:
	for y in ROWS:
		for x in COLS:
			var cell := Button.new()
			cell.flat = true
			cell.focus_mode = Control.FOCUS_NONE
			cell.position = Vector2(x * (CELL + GAP), y * (CELL + GAP))
			cell.custom_minimum_size = Vector2(CELL, CELL)
			cell.pressed.connect(_on_add_pressed)
			cell.set_drag_forwarding(Callable(), _can_drop_files.bind(-1), _drop_files.bind(-1))
			grid_area.add_child(cell)

func _rebuild_items() -> void:
	if grid_area == null:
		return
	for btn in item_buttons:
		if is_instance_valid(btn):
			btn.queue_free()
	item_buttons.clear()
	if status_label:
		status_label.text = ""
		status_label.add_theme_color_override("font_color", Color(1, 0.7, 0.3))
	if grid_canvas:
		grid_canvas.items.clear()
		grid_canvas.queue_redraw()
	if chest == null:
		return
	var sim := ChestInventory.new()
	var overflow := 0
	for item in chest.starter_items:
		if not sim.add_item(item):
			overflow += 1
	for i in sim.inventory.size():
		var placed: ItemResource = sim.inventory[i]
		var btn := Button.new()
		btn.flat = true
		btn.focus_mode = Control.FOCUS_NONE
		btn.text = placed.item_name
		btn.tooltip_text = placed.item_name
		btn.position = Vector2(placed.grid_x * (CELL + GAP), placed.grid_y * (CELL + GAP))
		var w := placed.inv_width * CELL + (placed.inv_width - 1) * GAP
		var h := placed.inv_height * CELL + (placed.inv_height - 1) * GAP
		btn.custom_minimum_size = Vector2(w, h)
		btn.size = Vector2(w, h)
		btn.pressed.connect(_on_replace_pressed.bind(i))
		btn.gui_input.connect(_on_item_gui_input.bind(i))
		btn.set_drag_forwarding(Callable(), _can_drop_files.bind(i), _drop_files.bind(i))
		grid_area.add_child(btn)
		item_buttons.append(btn)
	grid_canvas.items = sim.inventory.duplicate()
	grid_canvas.queue_redraw()
	if overflow > 0:
		status_label.text = "%d item(s) don't fit in the 5x5 grid." % overflow

func _on_add_pressed() -> void:
	_open_dialog(-1)

func _on_replace_pressed(_index: int) -> void:
	_open_dialog(_index)

func _on_item_gui_input(event: InputEvent, _index: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_remove_item(_index)
		accept_event()

func _open_dialog(_index: int) -> void:
	dialog_index = _index
	if dialog == null:
		dialog = EditorFileDialog.new()
		dialog.title = "Pick an item resource (*.tres)"
		dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
		dialog.add_filter("*.tres", "Item resources")
		dialog.access = EditorFileDialog.ACCESS_RESOURCES
		dialog.file_selected.connect(_on_item_selected)
		var base := EditorInterface.get_base_control()
		if base != null:
			base.add_child(dialog)
			dialog_attached = true
	if dialog_attached:
		dialog.popup_centered_ratio(0.5)

func _on_item_selected(_path: String) -> void:
	var res: Resource = load(_path)
	if res == null or not (res is ItemResource):
		push_warning("Chest Editor: '%s' is not an ItemResource." % _path)
		return
	if chest == null:
		return
	if dialog_index >= 0:
		_set_at(dialog_index, res)
	else:
		_append(res)
	_after_change()

func _remove_item(_index: int) -> void:
	if chest == null or _index < 0 or _index >= chest.starter_items.size():
		return
	var arr: Array[ItemResource] = chest.starter_items.duplicate()
	arr.remove_at(_index)
	chest.starter_items = arr
	_after_change()

## Accepts files dragged from the editor's FileSystem dock.
func _can_drop_files(_at_position: Vector2, _data: Variant, _index: int) -> bool:
	return typeof(_data) == TYPE_DICTIONARY \
		and _data.get("type") == "files" \
		and _data.get("files", []) is Array \
		and _data["files"].size() > 0

## Drops dragged .tres files into starter_items. Dropping on a filled item
## replaces that slot with the first valid file; the rest are appended.
func _drop_files(_at_position: Vector2, _data: Variant, _index: int) -> void:
	if chest == null or typeof(_data) != TYPE_DICTIONARY or not _data.has("files"):
		return
	var replaced := false
	for path in _data["files"]:
		if typeof(path) != TYPE_STRING:
			continue
		var res: Resource = load(path)
		if res == null or not (res is ItemResource):
			push_warning("Chest Editor: '%s' is not an ItemResource." % str(path))
			continue
		if not replaced and _index >= 0:
			_set_at(_index, res)
			replaced = true
		else:
			_append(res)
	_after_change()

func _set_at(_index: int, _res: ItemResource) -> void:
	if chest == null:
		return
	var arr: Array[ItemResource] = chest.starter_items.duplicate()
	if _index >= arr.size():
		arr.append(_res)
	else:
		arr[_index] = _res
	chest.starter_items = arr

func _append(_res: ItemResource) -> void:
	if chest == null:
		return
	var arr: Array[ItemResource] = chest.starter_items.duplicate()
	arr.append(_res)
	chest.starter_items = arr

func _after_change() -> void:
	if chest != null:
		chest.notify_property_list_changed()
	EditorInterface.mark_scene_as_unsaved()
	_rebuild_items()
