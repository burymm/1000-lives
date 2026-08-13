extends Control

@export var player_node : CharacterBody3D
@export var inventory_system : InventorySystem

var selected_index : int = -1
var selected_button : Button
## Equipment slot selected on the character silhouette ("" = none). Lets the
## Drop/Use buttons act on the item worn in that slot.
var selected_slot : String = ""

var item_grid : Control
var slot_buttons : Dictionary = {}
var cell_size : int = 64
var use_button : Button
var equip_button : Button
var drop_button : Button

## Chest (container) panel shown to the right of the inventory while a chest is
## open. Mirrors the item grid but its items live in the chest's own storage.
var chest_panel : PanelContainer
var chest_grid : Control
var chest_slot_buttons : Dictionary = {}
var chest_inventory : ChestInventory

var inventory_tab : HBoxContainer
var equipment_tab : VBoxContainer
var status_tab : VBoxContainer

var char_slots : Dictionary = {}
var char_icons : Dictionary = {}

var notice_label : Label
var notice_timer : SceneTreeTimer

## Energy readouts on the Status tab (see tasks/task5.md).
var energy_label : Label
var drain_label : Label

const SLOT_DEFS : Dictionary = {
	"Head":      Vector4(235, 170, 60, 56),
	"Torso":     Vector4(202, 260, 120, 120),
	"RightHand": Vector4(100, 280, 66, 140),
	"LeftHand":  Vector4(355, 280, 66, 140),
	"Belt":      Vector4(202, 400, 120, 40),
	"Legs":      Vector4(180, 480, 168, 240),
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
	ItemIcons.icon_ready.connect(_on_icon_ready)
	_refresh_grid()
	_refresh_char_slots()

## Item icons are generated asynchronously at startup; rebuild the shown icons
## once they arrive.
func _on_icon_ready():
	if visible:
		_refresh_grid()
		_refresh_char_slots()
		_refresh_chest_grid()

## Live energy readout while the menu is open.
func _process(_delta):
	if visible:
		_refresh_status()

func _refresh_status():
	var es = player_node.energy_system if player_node else null
	if energy_label == null or es == null:
		return
	energy_label.text = "Energy: %d / %d" % [int(es.current_energy), int(es.max_energy)]
	drain_label.text = "Drain while standing: %.1f / s" % es.standing_drain()

func _build_ui():
	var background = ColorRect.new()
	background.name = "Background"
	background.color = Color(0.04, 0.04, 0.05, 0.82)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

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
	window.custom_minimum_size = Vector2(1350, 660)
	window.set_anchors_preset(Control.PRESET_FULL_RECT)
	window.offset_left = 24
	window.offset_top = 24
	window.offset_right = -24
	window.offset_bottom = -24
	add_child(window)

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
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
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

	chest_panel = PanelContainer.new()
	chest_panel.name = "ChestPanel"
	chest_panel.custom_minimum_size = Vector2(360, 0)
	chest_panel.visible = false
	inventory_tab.add_child(chest_panel)
	var chest_margin = MarginContainer.new()
	chest_margin.add_theme_constant_override("margin_top", 12)
	chest_margin.add_theme_constant_override("margin_bottom", 12)
	chest_margin.add_theme_constant_override("margin_left", 12)
	chest_margin.add_theme_constant_override("margin_right", 12)
	chest_panel.add_child(chest_margin)
	var chest_box = VBoxContainer.new()
	chest_box.add_theme_constant_override("separation", 10)
	chest_margin.add_child(chest_box)
	var chest_header = HBoxContainer.new()
	chest_box.add_child(chest_header)
	var chest_title = Label.new()
	chest_title.text = "Chest"
	chest_title.add_theme_font_size_override("font_size", 18)
	chest_header.add_child(chest_title)
	chest_grid = Control.new()
	chest_grid.name = "ChestGrid"
	chest_grid.set_drag_forwarding(_get_drag_data, _can_drop_data, _drop_data)
	chest_box.add_child(chest_grid)

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
	var status_title = Label.new()
	status_title.text = "Status"
	status_title.add_theme_font_size_override("font_size", 20)
	status_tab.add_child(status_title)
	energy_label = Label.new()
	energy_label.add_theme_font_size_override("font_size", 16)
	status_tab.add_child(energy_label)
	drain_label = Label.new()
	drain_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	status_tab.add_child(drain_label)

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
	close_chest()
	visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

## Shows the chest storage panel next to the inventory. `_chest` is the opened
## chest object exposing a `storage` ChestInventory.
func open_chest(_chest):
	if chest_inventory and chest_inventory.inventory_updated.is_connected(_on_chest_updated):
		chest_inventory.inventory_updated.disconnect(_on_chest_updated)
	chest_inventory = _chest.storage if "storage" in _chest else null
	if chest_inventory == null:
		close_chest()
		return
	chest_inventory.inventory_updated.connect(_on_chest_updated)
	chest_panel.visible = true
	_refresh_chest_grid()
	open_menu()

## Hides the chest panel and forgets the open chest. The chest keeps its
## contents — nothing is distributed automatically.
func close_chest():
	if chest_inventory and chest_inventory.inventory_updated.is_connected(_on_chest_updated):
		chest_inventory.inventory_updated.disconnect(_on_chest_updated)
	chest_inventory = null
	chest_slot_buttons.clear()
	if chest_panel:
		chest_panel.visible = false

func _on_chest_updated(_inventory):
	_refresh_chest_grid()

func _refresh_chest_grid():
	if chest_grid == null:
		return
	for child in chest_grid.get_children():
		child.free()
	chest_slot_buttons.clear()
	if chest_inventory == null:
		return
	var cols = chest_inventory.inv_columns
	var rows = chest_inventory.inv_rows
	chest_grid.custom_minimum_size = Vector2(cols * cell_size, rows * cell_size)
	chest_grid.size = Vector2(cols * cell_size, rows * cell_size)
	var backdrop := GridBackdrop.new()
	backdrop.cols = cols
	backdrop.rows = rows
	backdrop.cell = cell_size
	backdrop.custom_minimum_size = Vector2(cols * cell_size, rows * cell_size)
	backdrop.size = Vector2(cols * cell_size, rows * cell_size)
	chest_grid.add_child(backdrop)
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
			chest_grid.add_child(cell)
	for i in range(chest_inventory.inventory.size()):
		var item = chest_inventory.inventory[i]
		var button = Button.new()
		button.position = Vector2(item.grid_x * cell_size, item.grid_y * cell_size)
		button.custom_minimum_size = Vector2(item.inv_width * cell_size, item.inv_height * cell_size)
		button.size = Vector2(item.inv_width * cell_size, item.inv_height * cell_size)
		button.focus_mode = Control.FOCUS_NONE
		button.tooltip_text = item.item_name
		button.modulate = Color(0.9, 0.95, 1.0)
		var icon := ItemIcons.get_icon(item)
		if icon:
			button.icon = icon
			button.expand_icon = true
		button.set_drag_forwarding(_get_drag_data, _can_drop_data, _drop_data)
		chest_grid.add_child(button)
		chest_slot_buttons[i] = button

func _on_inventory_updated(_inventory):
	_refresh_grid()

func _refresh_grid():
	for child in item_grid.get_children():
		child.free()
	slot_buttons.clear()
	selected_index = -1
	selected_button = null
	selected_slot = ""
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
	var icon := ItemIcons.get_icon(_item)
	if icon:
		button.icon = icon
		button.expand_icon = true
	button.pressed.connect(_on_slot_pressed.bind(_index))
	button.set_drag_forwarding(_get_drag_data, _can_drop_data, _drop_data)
	return button

func _on_empty_pressed():
	if selected_button:
		selected_button.modulate = Color(0.9, 0.95, 1.0)
	selected_index = -1
	selected_button = null
	selected_slot = ""
	_update_action_buttons()

func _on_slot_pressed(_index):
	if selected_button:
		selected_button.modulate = Color(0.9, 0.95, 1.0)
	selected_index = _index
	selected_button = slot_buttons.get(_index)
	selected_slot = ""
	if selected_button:
		selected_button.modulate = Color(1.0, 0.82, 0.35)
	_update_action_buttons()

## Selects the equipment slot clicked on the silhouette so the action buttons
## (Drop) apply to the worn item.
func _on_char_slot_pressed(_slot):
	if selected_button:
		selected_button.modulate = Color(0.9, 0.95, 1.0)
	selected_index = -1
	selected_button = null
	selected_slot = _slot
	_update_action_buttons()

func _update_action_buttons():
	var item = _selected_item()
	if item == null and selected_slot != "" and inventory_system:
		item = inventory_system.equipment.get(selected_slot, null)
	if item == null:
		use_button.disabled = true
		equip_button.disabled = true
		drop_button.disabled = true
		return
	use_button.disabled = item.object_type != "DRINK" and item.object_type != "THROWN"
	equip_button.disabled = selected_slot != ""
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
	if selected_slot != "" and inventory_system and inventory_system.equipment.has(selected_slot):
		inventory_system.drop_equipped(selected_slot)
		selected_slot = ""
		return
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
	panel.custom_minimum_size = Vector2(560, 470)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
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
	figure.custom_minimum_size = Vector2(512, 440)
	figure.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	figure.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(figure)
	_build_silhouette(figure)
	return panel

func _build_silhouette(_figure):
	var bg_texture := load("res://assets/menu/user-bg.png") as Texture2D
	if bg_texture:
		var bg = TextureRect.new()
		bg.name = "CharacterBg"
		bg.texture = bg_texture
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_figure.add_child(bg)
	var body_color = Color(0.5, 0.46, 0.42, 0.9)
	var limb_color = Color(0.42, 0.38, 0.35, 0.9)
	# The silhouette is drawn from the same SLOT_DEFS the interactive slots use,
	# so adjusting a slot position always moves its visible cell too.
	var body_slots := ["Head", "Torso", "Belt", "Legs"]
	for slot in SLOT_DEFS:
		var def = SLOT_DEFS[slot]
		var rect = ColorRect.new()
		rect.position = Vector2(def.x, def.y)
		rect.size = Vector2(def.z, def.w)
		rect.color = body_color if slot in body_slots else limb_color
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
		btn.pressed.connect(_on_char_slot_pressed.bind(slot))
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
		var item_icon := ItemIcons.get_icon(item) if item else null
		if item and item_icon:
			icon.texture = item_icon
			icon.visible = true
			_size_slot_icon(icon, item_icon, slot)
		else:
			icon.texture = null
			icon.visible = false
			icon.scale = Vector2.ONE
			icon.set_anchors_preset(Control.PRESET_FULL_RECT)
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var btn : Button = char_slots[slot]
		if item and slot == selected_slot:
			btn.modulate = Color(1.0, 0.82, 0.35)
		else:
			btn.modulate = Color(1, 1, 1, 1.0) if item else Color(1, 1, 1, 0.2)
		btn.tooltip_text = slot + (" — " + item.item_name if item else "")

func _on_equipment_changed(_slot):
	_refresh_char_slots()
	_refresh_equipment_tab()

## Sizes a character-slot icon from the slot geometry in SLOT_DEFS and the
## icon's actual pixel size: scale = min(slot_w / icon_w, slot_h / icon_h), so
## the item's longest side fits the slot, then centers it. An extra
## SLOT_ICON_SHRINK factor keeps icons slightly smaller than the slot so they
## read as props (0.8 tuned on the head; a single factor keeps all slots in
## the same visual style).
const SLOT_ICON_SHRINK := 0.8;

func _size_slot_icon(_icon : TextureRect, _texture : Texture2D, _slot : String):
	var def = SLOT_DEFS[_slot]
	var slot_w : float = def.z
	var slot_h : float = def.w
	var tex_w : float = _texture.get_width()
	var tex_h : float = _texture.get_height()
	var s := 1.0
	if tex_w > 0 and tex_h > 0:
		s = minf(slot_w / tex_w, slot_h / tex_h) * SLOT_ICON_SHRINK
	# Without IGNORE_SIZE the TextureRect's minimum size is the texture's native
	# size, so a computed smaller rect gets clamped back up and SLOT_ICON_SHRINK
	# stops having any effect.
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_icon.size = Vector2(tex_w * s, tex_h * s)
	_icon.position = Vector2((slot_w - _icon.size.x) * 0.5, (slot_h - _icon.size.y) * 0.5)
	_icon.stretch_mode = TextureRect.STRETCH_SCALE
	_icon.scale = Vector2.ONE
	_icon.pivot_offset = Vector2.ZERO

func _get_drag_data(at_position):
	if inventory_system == null:
		return null
	var mp = get_global_mouse_position()
	for i in slot_buttons:
		if slot_buttons[i].get_global_rect().has_point(mp):
			var item = inventory_system.inventory[i]
			if item:
				set_drag_preview(_drag_preview(item))
			return {"type": "inventory", "index": i}
	if chest_inventory != null:
		for i in chest_slot_buttons:
			if chest_slot_buttons[i].get_global_rect().has_point(mp):
				var item = chest_inventory.inventory[i]
				if item:
					set_drag_preview(_drag_preview(item))
				return {"type": "chest", "index": i}
	for slot in char_slots:
		if char_slots[slot].get_global_rect().has_point(mp):
			var item = inventory_system.equipment.get(slot)
			if item:
				set_drag_preview(_drag_preview(item))
			return {"type": "equipment", "slot": slot}
	return null

func _can_drop_data(at_position, data):
	if typeof(data) != TYPE_DICTIONARY or not data.has("type"):
		return false
	var on_char := _slot_at_mouse() != ""
	var on_chest := _over_chest_panel()
	var on_grid := _over_inventory_grid()
	match data["type"]:
		"inventory":
			return on_char or on_chest or on_grid
		"equipment":
			return true
		"chest":
			return on_char or on_grid or on_chest
	return false

func _drop_data(at_position, data):
	if inventory_system == null:
		return
	if typeof(data) != TYPE_DICTIONARY or not data.has("type"):
		return
	var slot = _slot_at_mouse()
	var on_chest := _over_chest_panel()
	var on_grid := _over_inventory_grid()
	match data["type"]:
		"inventory":
			if slot != "":
				inventory_system.equip_item(data["index"], slot)
			elif on_chest:
				_move_grid_to_chest(data["index"])
			elif on_grid:
				_move_within_grid(data["index"])
		"equipment":
			if on_chest:
				_move_equipment_to_chest(data["slot"])
			elif slot != "":
				inventory_system.move_equipped(data["slot"], slot)
			elif on_grid:
				var cell := _grid_cell_at_mouse(item_grid)
				inventory_system.unequip_item_at(data["slot"], cell.x, cell.y)
			else:
				inventory_system.unequip_item(data["slot"])
		"chest":
			if slot != "":
				_move_chest_to_equipment(data["index"], slot)
			elif on_grid:
				_move_chest_to_grid(data["index"])
			elif on_chest:
				_move_within_chest(data["index"])

## Relocates a player-inventory item to the grid cell under the mouse.
func _move_within_grid(_index):
	if inventory_system == null:
		return
	var cell := _grid_cell_at_mouse(item_grid)
	if not inventory_system.move_item(_index, cell.x, cell.y):
		_on_inventory_error("Can't place item here")

## Relocates a chest item to the chest grid cell under the mouse.
func _move_within_chest(_index):
	if chest_inventory == null:
		return
	var cell := _grid_cell_at_mouse(chest_grid)
	if not chest_inventory.move_item(_index, cell.x, cell.y):
		_on_inventory_error("Can't place item here")

## The cell of `_grid` currently under the mouse (in cell coordinates).
func _grid_cell_at_mouse(_grid : Control) -> Vector2i:
	var local := _grid.get_global_transform_with_canvas().affine_inverse() * get_global_mouse_position()
	return Vector2i(floor(local.x / cell_size), floor(local.y / cell_size))

## True while the mouse is over the visible chest panel.
func _over_chest_panel() -> bool:
	if chest_panel == null or not chest_panel.visible or chest_inventory == null:
		return false
	return chest_panel.get_global_rect().has_point(get_global_mouse_position())

## True while the mouse is over the player's inventory grid.
func _over_inventory_grid() -> bool:
	if item_grid == null or not item_grid.is_visible_in_tree():
		return false
	return item_grid.get_global_rect().has_point(get_global_mouse_position())

func _move_grid_to_chest(_index):
	if chest_inventory == null or _index < 0 or _index >= inventory_system.inventory.size():
		return
	var item = inventory_system.inventory[_index]
	if item == null:
		return
	if not chest_inventory.can_fit(item):
		_on_inventory_error("No room in chest")
		return
	chest_inventory.add_item(item)
	inventory_system.remove_item(_index)

func _move_chest_to_grid(_index):
	if chest_inventory == null or _index < 0 or _index >= chest_inventory.inventory.size():
		return
	var item = chest_inventory.inventory[_index]
	if item == null:
		return
	if not inventory_system.can_fit(item):
		_on_inventory_error("No room in inventory")
		return
	inventory_system.add_item(item)
	chest_inventory.remove_item(_index)

func _move_equipment_to_chest(_slot):
	if chest_inventory == null or not inventory_system.equipment.has(_slot):
		return
	var item = inventory_system.equipment[_slot]
	if item == null:
		return
	if not chest_inventory.can_fit(item):
		_on_inventory_error("No room in chest")
		return
	chest_inventory.add_item(item)
	inventory_system.take_equipped(_slot)

func _move_chest_to_equipment(_index, _slot):
	if chest_inventory == null or _index < 0 or _index >= chest_inventory.inventory.size():
		return
	var item = chest_inventory.inventory[_index]
	if item == null:
		return
	if not inventory_system.equip_external(item, _slot):
		return
	chest_inventory.remove_item(_index)

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

## Drag preview: a silhouette of the item's grid footprint with its icon
## rendered inside, so the player sees exactly what is being moved and how much
## space it occupies before the drop.
func _drag_preview(_item) -> Control:
	var preview = Control.new()
	var w : int = _item.inv_width * cell_size
	var h : int = _item.inv_height * cell_size
	preview.custom_minimum_size = Vector2(w, h)
	preview.size = Vector2(w, h)

	var footprint = ColorRect.new()
	footprint.name = "Footprint"
	footprint.set_anchors_preset(Control.PRESET_FULL_RECT)
	footprint.color = Color(0.1, 0.1, 0.15, 0.55)
	footprint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.add_child(footprint)

	var icon := ItemIcons.get_icon(_item)
	if icon:
		var icon_rect = TextureRect.new()
		icon_rect.name = "Icon"
		icon_rect.texture = icon
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		preview.add_child(icon_rect)

	var name_label = Label.new()
	name_label.name = "Name"
	name_label.text = _item.item_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	name_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	name_label.add_theme_constant_override("outline_size", 4)
	preview.add_child(name_label)
	return preview
