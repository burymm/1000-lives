extends Node

func _ready():
	var paths := {
		"bread": "res://player/item_system/items/bread.tres",
		"rock": "res://player/item_system/items/rock.tres",
		"boulder": "res://player/item_system/items/rock_boulder.tres",
		"sword": "res://player/item_system/items/sword.tres",
		"shield": "res://player/item_system/items/shield.tres",
		"potion": "res://player/item_system/items/potion.tres",
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
	DirAccess.make_dir_recursive_absolute("res://tools/icon_dumps")
	for label in paths:
		var tex = ItemIcons.get_icon(load(paths[label]))
		var img: Image = tex.get_image()
		img.save_png("res://tools/icon_dumps/" + label + ".png")
		print(label, " size=", img.get_width(), "x", img.get_height())
	print("SAVED")
	get_tree().quit()
