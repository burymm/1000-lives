extends Node

func _ready():
	var paths := {
		"Bread": "res://player/item_system/items/bread.tres",
		"Rock": "res://player/item_system/items/rock.tres",
		"Boulder": "res://player/item_system/items/rock_boulder.tres",
		"Sword": "res://player/item_system/items/sword.tres",
		"Shield": "res://player/item_system/items/shield.tres",
		"Potion": "res://player/item_system/items/potion.tres",
	}
	for i in range(800):
		var all_ready := true
		for p in paths.values():
			if ItemIcons.get_icon(load(p)) == null:
				all_ready = false
				break
		if all_ready:
			break
		await get_tree().process_frame
	for label in paths:
		_stat(label, ItemIcons.get_icon(load(paths[label])))
	get_tree().quit()

func _stat(label: String, tex) -> void:
	if tex == null:
		print(label, ": NULL")
		return
	var img: Image = tex.get_image()
	var n := 0
	var sum := 0.0
	var brightest := 0.0
	for x in range(img.get_width()):
		for y in range(img.get_height()):
			var c: Color = img.get_pixel(x, y)
			if c.a > 0.2:
				var lum: float = c.get_luminance()
				sum += lum
				brightest = maxf(brightest, lum)
				n += 1
	print(label, " avg_lum=%.2f max_lum=%.2f n=%d" % [sum / float(n) if n > 0 else 0.0, brightest, n])
