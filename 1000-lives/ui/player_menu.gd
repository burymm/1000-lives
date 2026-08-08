extends Control

@export var player_node : CharacterBody3D
@export var inventory_system : InventorySystem

var selected_index : int = -1
var selected_button : Button

var item_grid : Control
var slot_buttons : Dictionary = {}
var cell_size : int = 64
var use_button : Button
var equip_button : Button
var drop_button : Button

var inventory_tab : HBoxContainer
var equipment_tab : VBoxContainer
var status_tab : VBoxContainer

var char_slots : Dictionary = {}
var char_icons : Dictionary = {}

var notice_label : Label
var notice_timer : SceneTreeTimer

const SLOT_DEFS : Dictionary = {
	"Head":      Vector4(100, 24, 56, 56),
	"Torso":     Vector4(86, 100, 84, 100),
	"RightHand": Vector4(28, 102, 44, 104),
	"LeftHand":  Vector4(184, 102, 44, 104),
	"Belt":      Vector4(100, 214, 56, 38),
	"Legs":      Vector4(86, 272, 84, 120),
}

var tab_buttons : Dictionary = {}
var equipment_labels : Dictionary = {}

## Draws the translucent white grid backdrop behind the inventory slots so
## items are easier to place and drag around.
class GridBackdrop extends Control:
	var cols : int = 10
	var rows : int = 5
	var cell : int = 64

	func _ready():
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw():
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.07), true)
		var line_color := Color(1, 1, 1, 0.28)
		for y in range(rows + 1):
			draw_line(Vector2(0, y * cell), Vector2(size.x, y * cell), line_color, 1.0)
		for x in range(cols + 1):
			draw_line(Vector2(x * cell, 0), Vector2(x * cell, size.y), line_color, 1.0)

func _ready():
	visible = false
	_build_ui()
	if inventory_system:
		inventory_system.inventory_updated.connect(_on_inventory_updated)
		inventory_system.equipment_changed.connect(_on_equipment_changed)
		inventory_system.inventory_error.connect(_on_inventory_error)
	_refresh_grid()
	_refresh_char_slots()

func _build_ui():
	var background = ColorRect.new()
	background.name = "Background"
	background.color = Color(0.04, 0.04, 0.05, 0.82)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var center = CenterContainer.new()
	center.name = "Center"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	notice_label = Label.new()
	notice_label.name = "NoticeLabel"
	notice_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	notice_label.offset_top = 40
	notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	notice_label.add_theme_font_size_override("font_size", 24)
	notice_label.add_theme_color_override("font_color", Color(1, 0.35, 0.3))
	notice_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	notice_label.add_theme_constant_override("outline_size", 5)
	notice_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notice_label.visible = false
	add_child(notice_label)

	var window = PanelContainer.new()
	window.name = "Window"
	window.custom_minimum_size = Vector2(900, 620)
	center.add_child(window)

	var window_margin = MarginContainer.new()
	window_margin.add_theme_constant_override("margin_left", 24)
	window_margin.add_theme_constant_override("margin_top", 16)
	window_margin.add_theme_constant_override("margin_right", 24)
	window_margin.add_theme_constant_override("margin_bottom", 16)
	window.add_child(window_margin)

	var root_box = VBoxContainer.new()
	root_box.name = "RootBox"
	root_box.add_theme_constant_override("separation", 12)
	window_margin.add_child(root_box)

	var header = HBoxContainer.new()
	root_box.add_child(header)
	var title = Label.new()
	title.text = "1000 LIVES"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.85, 0.7, 0.3))
	header.add_child(title)
	var header_spacer = Control.new()
	header_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_spacer)
	var close_button = Button.new()
	close_button.text = "X"
	close_button.custom_minimum_size = Vector2(38, 38)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(close_menu)
	header.add_child(close_button)

	var tabs = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	root_box.add_child(tabs)
	var tab_inventory = Button.new()
	tab_inventory.text = "Inventory"
	tab_inventory.toggle_mode = true
	tab_inventory.button_pressed = true
	tab_inventory.pressed.connect(_show_tab.bind("inventory"))
	tabs.add_child(tab_inventory)
	var tab_equipment = Button.new()
	tab_equipment.text = "Equipment"
	tab_equipment.toggle_mode = true
	tab_equipment.pressed.connect(_show_tab.bind("equipment"))
	tabs.add_child(tab_equipment)
	var tab_status = Button.new()
	tab_status.text = "Status"
	tab_status.toggle_mode = true
	tab_status.pressed.connect(_show_tab.bind("status"))
	tabs.add_child(tab_status)
	tab_buttons = {"inventory": tab_inventory, "equipment": tab_equipment, "status": tab_status}

	var content = PanelContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_box.add_child(content)
	var content_margin = MarginContainer.new()
	content_margin.add_theme_constant_override("margin_left", 16)
	content_margin.add_theme_constant_override("margin_top", 16)
	content_margin.add_theme_constant_override("margin_right", 16)
	content_margin.add_theme_constant_override("margin_bottom", 16)
	content.add_child(content_margin)

	inventory_tab = HBoxContainer.new()
	inventory_tab.add_theme_constant_override("separation", 16)
	content_margin.add_child(inventory_tab)

	var char_panel = _build_character_panel()
	inventory_tab.add_child(char_panel)

	var right_box = VBoxContainer.new()
	right_box.add_theme_constant_override("separation", 10)
	right_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory_tab.add_child(right_box)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_box.add_child(scroll)
	item_grid = Control.new()
	item_grid.name = "ItemGrid"
	item_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_grid.set_drag_forwarding(_get_drag_data, _can_drop_data, _drop_data)
	scroll.add_child(item_grid)

	var action_bar = HBoxContainer.new()
	action_bar.add_theme_constant_override("separation", 8)
	right_box.add_child(action_bar)
	var action_spacer = Control.new()
	action_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_bar.add_child(action_spacer)
	use_button = Button.new()
	use_button.text = "Use"
	use_button.focus_mode = Control.FOCUS_NONE
	use_button.pressed.connect(_on_use_pressed)
	action_bar.add_child(use_button)
	equip_button = Button.new()
	equip_button.text = "Equip"
	equip_button.focus_mode = Control.FOCUS_NONE
	equip_button.pressed.connect(_on_equip_pressed)
	action_bar.add_child(equip_button)
	drop_button = Button.new()
	drop_button.text = "Drop"
	drop_button.focus_mode = Control.FOCUS_NONE
	drop_button.pressed.connect(_on_drop_pressed)
	action_bar.add_child(drop_button)

	equipment_tab = VBoxContainer.new()
	equipment_tab.add_theme_constant_override("separation", 10)
	equipment_tab.visible = false
	content_margin.add_child(equipment_tab)
	var equip_title = Label.new()
	equip_title.text = "Equipment"
	equip_title.add_theme_font_size_override("font_size", 20)
	equipment_tab.add_child(equip_title)
	_equip_row("Right Hand", "RightHand")
	_equip_row("Left Hand", "LeftHand")
	_equip_row("Active Item", "ActiveItem")

	status_tab = VBoxContainer.new()
	status_tab.visible = false
	content_margin.add_child(status_tab)
	var status_label = Label.new()
	status_label.text = "Status"
	status_tab.add_child(status_label)

	_update_action_buttons()

func _equip_row(_label_text, _key):
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	equipment_tab.add_child(row)
	var name_label = Label.new()
	name_label.text = _label_text
	name_label.custom_minimum_size = Vector2(180, 0)
	row.add_child(name_label)
	var value_label = Label.new()
	value_label.text = "-"
	row.add_child(value_label)
	equipment_labels[_key] = value_label

func _show_tab(_tab : String):
	for key in tab_buttons:
		tab_buttons[key].button_pressed = (key == _tab)
	inventory_tab.visible = (_tab == "inventory")
	equipment_tab.visible = (_tab == "equipment")
	status_tab.visible = (_tab == "status")
	if _tab == "equipment":
		_refresh_equipment_tab()

func toggle_menu():
	if visible:
		close_menu()
	else:
		open_menu()

func open_menu():
	visible = true
	_refresh_grid()
	_refresh_char_slots()
	_refresh_equipment_tab()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func close_menu():
	visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_inventory_updated(_inventory):
	_refresh_grid()

func _refresh_grid():
	for child in item_grid.get_children():
		child.free()
	slot_buttons.clear()
	selected_index = -1
	selected_button = null
	if inventory_system == null:
		return
	var cols = inventory_system.inv_columns
	var rows = inventory_system.inv_rows
	item_grid.custom_minimum_size = Vector2(cols * cell_size, rows * cell_size)
	item_grid.size = Vector2(cols * cell_size, rows * cell_size)
	var backdrop := GridBackdrop.new()
	backdrop.cols = cols
	backdrop.rows = rows
	backdrop.cell = cell_size
	backdrop.custom_minimum_size = Vector2(cols * cell_size, rows * cell_size)
	backdrop.size = Vector2(cols * cell_size, rows * cell_size)
	item_grid.add_child(backdrop)
	for y in range(rows):
		for x in range(cols):
			var cell = Button.new()
			cell.flat = true
			cell.custom_minimum_size = Vector2(cell_size, cell_size)
			cell.position = Vector2(x * cell_size, y * cell_size)
			cell.size = Vector2(cell_size, cell_size)
			cell.focus_mode = Control.FOCUS_NONE
			cell.modulate = Color(1, 1, 1, 0.07)
			cell.pressed.connect(_on_empty_pressed)
			cell.set_drag_forwarding(_get_drag_data, _can_drop_data, _drop_data)
			item_grid.add_child(cell)
	for i in range(inventory_system.inventory.size()):
		var button = _make_slot(inventory_system.inventory[i], i)
		item_grid.add_child(button)
		slot_buttons[i] = button
	_refresh_char_slots()
	_update_action_buttons()

func _make_slot(_item, _index):
	var button = Button.new()
	button.position = Vector2(_item.grid_x * cell_size, _item.grid_y * cell_size)
	button.custom_minimum_size = Vector2(_item.inv_width * cell_size, _item.inv_height * cell_size)
	button.size = Vector2(_item.inv_width * cell_size, _item.inv_height * cell_size)
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = _item.item_name
	button.modulate = Color(0.9, 0.95, 1.0)
	if _item.texture:
		button.icon = _item.texture
		button.expand_icon = true
	button.pressed.connect(_on_slot_pressed.bind(_index))
	button.set_drag_forwarding(_get_drag_data, _can_drop_data, _drop_data)
	return button

func _on_empty_pressed():
	if selected_button:
		selected_button.modulate = Color(0.9, 0.95, 1.0)
	selected_index = -1
	selected_button = null
	_update_action_buttons()

func _on_slot_pressed(_index):
	if selected_button:
		selected_button.modulate = Color(0.9, 0.95, 1.0)
	selected_index = _index
	selected_button = slot_buttons.get(_index)
	if selected_button:
		selected_button.modulate = Color(1.0, 0.82, 0.35)
	_update_action_buttons()

func _update_action_buttons():
	var item = _selected_item()
	if item == null:
		use_button.disabled = true
		equip_button.disabled = true
		drop_button.disabled = true
		return
	use_button.disabled = item.object_type != "DRINK" and item.object_type != "THROWN"
	equip_button.disabled = false
	drop_button.disabled = item.physical_instance == null

func _selected_item():
	if selected_index < 0 or inventory_system == null:
		return null
	if selected_index >= inventory_system.inventory.size():
		return null
	return inventory_system.inventory[selected_index]

func _on_use_pressed():
	var item = _selected_item()
	if item == null:
		return
	inventory_system.current_item = item
	player_node.use_item()

func _on_drop_pressed():
	if _selected_item() == null:
		return
	inventory_system.drop_item(selected_index)

func _on_equip_pressed():
	var item = _selected_item()
	if item == null:
		return
	if item.object_type == "WEAPON":
		inventory_system.equip_item(selected_index, "RightHand")
	else:
		inventory_system.change_item(selected_index, 0)

func _refresh_equipment_tab():
	if not is_instance_valid(player_node):
		return
	for slot in ["RightHand", "LeftHand"]:
		if equipment_labels.has(slot):
			if inventory_system:
				var item = inventory_system.equipment.get(slot)
				equipment_labels[slot].text = item.item_name if item else "-"
			else:
				equipment_labels[slot].text = "-"
	if equipment_labels.has("ActiveItem"):
		if inventory_system and inventory_system.current_item:
			equipment_labels["ActiveItem"].text = inventory_system.current_item.item_name
		else:
			equipment_labels["ActiveItem"].text = "-"

func _build_character_panel():
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(290, 470)
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	panel.add_child(margin)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)
	var title = Label.new()
	title.text = "Character"
	title.add_theme_font_size_override("font_size", 18)
	box.add_child(title)
	var figure = Control.new()
	figure.custom_minimum_size = Vector2(256, 440)
	figure.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	figure.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(figure)
	_build_silhouette(figure)
	return panel

func _build_silhouette(_figure):
	var body_color = Color(0.5, 0.46, 0.42, 0.9)
	var limb_color = Color(0.42, 0.38, 0.35, 0.9)
	var shapes = [
		[Vector2(100, 24), Vector2(56, 56), body_color],
		[Vector2(86, 100), Vector2(84, 100), body_color],
		[Vector2(28, 102), Vector2(44, 104), limb_color],
		[Vector2(184, 102), Vector2(44, 104), limb_color],
		[Vector2(100, 214), Vector2(56, 38), body_color],
		[Vector2(86, 272), Vector2(84, 120), body_color],
	]
	for shape in shapes:
		var rect = ColorRect.new()
		rect.position = shape[0]
		rect.size = shape[1]
		rect.color = shape[2]
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_figure.add_child(rect)
	for slot in SLOT_DEFS:
		var def = SLOT_DEFS[slot]
		var btn = Button.new()
		btn.name = "Slot_" + slot
		btn.position = Vector2(def.x, def.y)
		btn.size = Vector2(def.z, def.w)
		btn.custom_minimum_size = Vector2(def.z, def.w)
		btn.flat = true
		btn.focus_mode = Control.FOCUS_NONE
		btn.modulate = Color(1, 1, 1, 0.2)
		btn.tooltip_text = slot
		btn.set_drag_forwarding(_get_drag_data, _can_drop_data, _drop_data)
		var icon = TextureRect.new()
		icon.name = "Icon"
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.visible = false
		btn.add_child(icon)
		var lbl = Label.new()
		lbl.name = "NameLabel"
		lbl.text = slot
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
		lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(lbl)
		_figure.add_child(btn)
		char_slots[slot] = btn
		char_icons[slot] = icon

func _refresh_char_slots():
	if inventory_system == null:
		return
	for slot in char_icons:
		var item = inventory_system.equipment.get(slot)
		var icon : TextureRect = char_icons[slot]
		if item and item.texture:
			icon.texture = item.texture
			icon.visible = true
		else:
			icon.texture = null
			icon.visible = false
		var btn : Button = char_slots[slot]
		btn.tooltip_text = slot + (" — " + item.item_name if item else "")

func _on_equipment_changed(_slot):
	_refresh_char_slots()
	_refresh_equipment_tab()

func _get_drag_data(at_position):
	if inventory_system == null:
		return null
	var mp = get_global_mouse_position()
	for i in slot_buttons:
		if slot_buttons[i].get_global_rect().has_point(mp):
			var item = inventory_system.inventory[i]
			if item:
				set_drag_preview(_drag_preview(item.item_name))
			return {"type": "inventory", "index": i}
	for slot in char_slots:
		if char_slots[slot].get_global_rect().has_point(mp):
			var item = inventory_system.equipment.get(slot)
			if item:
				set_drag_preview(_drag_preview(item.item_name))
			return {"type": "equipment", "slot": slot}
	return null

func _can_drop_data(at_position, data):
	if typeof(data) != TYPE_DICTIONARY or not data.has("type"):
		return false
	if data["type"] == "inventory":
		return _slot_at_mouse() != ""
	return data["type"] == "equipment"

func _drop_data(at_position, data):
	if inventory_system == null:
		return
	if typeof(data) != TYPE_DICTIONARY or not data.has("type"):
		return
	if data["type"] == "inventory":
		var slot = _slot_at_mouse()
		if slot != "":
			inventory_system.equip_item(data["index"], slot)
	elif data["type"] == "equipment":
		var slot = _slot_at_mouse()
		if slot != "":
			inventory_system.move_equipped(data["slot"], slot)
		else:
			inventory_system.unequip_item(data["slot"])

func _slot_at_mouse() -> String:
	var mp = get_global_mouse_position()
	for slot in char_slots:
		if char_slots[slot].get_global_rect().has_point(mp):
			return slot
	return ""

func _on_inventory_error(_message):
	if not is_instance_valid(notice_label):
		return
	notice_label.text = _message
	notice_label.visible = true
	notice_timer = get_tree().create_timer(2.0)
	notice_timer.timeout.connect(_hide_notice.bind(notice_timer))

func _hide_notice(_timer):
	if is_instance_valid(notice_label) and _timer == notice_timer:
		notice_label.visible = false

func _drag_preview(_text) -> Label:
	var preview = Label.new()
	preview.text = _text
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.1, 0.15, 0.9)
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_left = 4
	sb.corner_radius_bottom_right = 4
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5
	preview.add_theme_stylebox_override("normal", sb)
	return preview
