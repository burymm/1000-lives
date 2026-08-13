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

## Currently selected slot index (-1 = none). The weight/energy/digest spinboxes
## edit that slot's item in place (items are scene-local copies, see
## _make_local_copy).
var selected_index := -1
var _loading_props := false
var weight_spin: SpinBox
var energy_spin: SpinBox
var digest_spin: SpinBox

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

	var props_box := VBoxContainer.new()
	props_box.add_theme_constant_override("separation", 4)
	add_child(props_box)
	var props_title := Label.new()
	props_title.text = "Selected item"
	props_title.add_theme_font_size_override("font_size", 13)
	props_box.add_child(props_title)
	weight_spin = _add_spin_prop(props_box, "Weight (kg)", 0.0, 100000.0, 0.1)
	energy_spin = _add_spin_prop(props_box, "Energy", 0.0, 100000.0, 1.0)
	digest_spin = _add_spin_prop(props_box, "Digest time (s)", 0.0, 3600.0, 0.1)

	_rebuild_items()

func _add_spin_prop(_parent: Node, _title: String, _min: float, _max: float, _step: float) -> SpinBox:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_parent.add_child(row)
	var label := Label.new()
	label.text = _title
	label.custom_minimum_size = Vector2(120, 0)
	row.add_child(label)
	var spin := SpinBox.new()
	spin.min_value = _min
	spin.max_value = _max
	spin.step = _step
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin.value_changed.connect(_on_prop_changed.bind(spin))
	row.add_child(spin)
	return spin

func _item_at(_index: int) -> ItemResource:
	if chest == null or _index < 0 or _index >= chest.starter_items.size():
		return null
	return chest.starter_items[_index]

func _select_slot(_index: int) -> void:
	if _index < 0 or _item_at(_index) == null:
		selected_index = -1
	else:
		selected_index = _index
	for i in item_buttons.size():
		if is_instance_valid(item_buttons[i]):
			item_buttons[i].modulate = Color(1.3, 1.3, 0.9) if i == selected_index else Color.WHITE
	var item := _item_at(selected_index)
	if weight_spin == null:
		return
	_loading_props = true
	weight_spin.editable = item != null
	energy_spin.editable = item != null
	digest_spin.editable = item != null
	if item:
		weight_spin.value = item.weight
		energy_spin.value = item.energy
		digest_spin.value = item.digest_time
	_loading_props = false

func _on_prop_changed(_value: float, _spin: SpinBox) -> void:
	if _loading_props:
		return
	var item := _item_at(selected_index)
	if item == null:
		return
	if _spin == weight_spin:
		item.weight = _value
	elif _spin == energy_spin:
		item.energy = _value
	elif _spin == digest_spin:
		item.digest_time = _value
	_mark_dirty()

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
		btn.pressed.connect(_on_item_clicked.bind(i))
		btn.gui_input.connect(_on_item_gui_input.bind(i))
		btn.set_drag_forwarding(Callable(), _can_drop_files.bind(i), _drop_files.bind(i))
		grid_area.add_child(btn)
		item_buttons.append(btn)
	grid_canvas.items = sim.inventory.duplicate()
	grid_canvas.queue_redraw()
	if overflow > 0:
		status_label.text = "%d item(s) don't fit in the 5x5 grid." % overflow
	_select_slot(selected_index)

func _on_add_pressed() -> void:
	_open_dialog(-1)

## Left-click selects the slot so its weight/energy/digest_time can be edited
## in the spinboxes below the grid. Replacing an item still works via
## drag-and-drop or a double-click.
func _on_item_clicked(_index: int) -> void:
	_select_slot(_index)

func _on_item_gui_input(event: InputEvent, _index: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_remove_item(_index)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
		_open_dialog(_index)
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
	var copy := _make_local_copy(_res)
	if _index >= arr.size():
		arr.append(copy)
	else:
		arr[_index] = copy
	chest.starter_items = arr

func _append(_res: ItemResource) -> void:
	if chest == null:
		return
	var arr: Array[ItemResource] = chest.starter_items.duplicate()
	arr.append(_make_local_copy(_res))
	chest.starter_items = arr

## Items placed in a chest keep their own independent copy (resource_local_to_scene)
## so that energy / digest_time / weight can be tweaked per chest item from the
## map editor without affecting the shared .tres the copy came from. See
## tasks/task5.md ("Редактор карт (chest_editor)").
func _make_local_copy(_res: ItemResource) -> ItemResource:
	var copy: ItemResource = _res.clone_item()
	copy.resource_local_to_scene = true
	return copy

func _mark_dirty() -> void:
	if chest != null:
		chest.notify_property_list_changed()
	EditorInterface.mark_scene_as_unsaved()

func _after_change() -> void:
	_mark_dirty()
	_rebuild_items()
