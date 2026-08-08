extends SceneTree

func _process(_delta: float) -> bool:
	var world = (load("res://demo_level/world_castle.tscn") as PackedScene).instantiate()
	root.add_child(world)
	var ladder: Node3D = world.get_node("Interactables/Ladder2")
	var player: Node3D = world.get_node("PlayerCharacterBodySoulsBase")
	player.global_position = ladder.global_position + Vector3(1.5, 0, 0)
	var wall: Dictionary = ladder._find_lean_wall(player)
	print("WALL found: ", wall)
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var base: Vector3 = ladder.global_position
	for h in [0.3, 1.5, 2.7, 3.9, 5.1, 6.3]:
		for dir in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
			var from := base + Vector3(0, h, 0)
			var q := PhysicsRayQueryParameters3D.create(from, from + dir * 4.0, 1)
			var r: Dictionary = space.intersect_ray(q)
			var info := "none"
			if not r.is_empty():
				info = str(r.collider.name) + " d=" + "%.2f" % from.distance_to(r.position)
			print("RAY h=", h, " dir=", dir, " -> ", info)
	quit(0)
	return false
